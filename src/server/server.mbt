///|
/// Authentication modes supported by the single-node server.
pub(all) enum AuthConfig {
  Token(String)
  UserPass(String, String)
}

///|
/// Server configuration for the single-node runtime.
pub(all) struct ServerConfig {
  host : String
  port : Int32
  max_payload : Int32
  max_control_line : Int32
  max_connections : Int32
  server_name : String
  auth : AuthConfig?
  monitor_port : Int32?
}

///|
pub fn ServerConfig::new() -> ServerConfig {
  {
    host: "127.0.0.1",
    port: 4222,
    max_payload: 1024 * 1024,
    max_control_line: 1024,
    max_connections: 1024,
    server_name: "moonnatsd",
    auth: None,
    monitor_port: None,
  }
}

///|
/// One live client connection. `outbox` is the only writer of `conn`, so
/// frames from different publishers cannot interleave.
priv struct Connection {
  conn : @socket.Tcp
  outbox : @aqueue.Queue[Bytes]
}

///|
/// Shared server state. This is a reference type; every connection task sees
/// the same registry, statistics and connection table.
priv struct ServerState {
  config : ServerConfig
  registry : @core.Registry
  conns : Map[Int32, Connection]
  auth_ok : Map[Int32, Bool]
  no_responses : Map[Int32, Bool]
  names : Map[Int32, String]
  stats : @core.Stats
  mut next_id : Int32
  server_id : String
}

///|
fn ServerState::new(config : ServerConfig) -> ServerState {
  {
    config,
    registry: @core.Registry::new(),
    conns: Map([]),
    auth_ok: Map([]),
    no_responses: Map([]),
    names: Map([]),
    stats: @core.Stats::new(),
    next_id: 1,
    server_id: "moonnatsd-1",
  }
}

///|
fn ServerState::alloc_id(self : ServerState) -> Int32 {
  let id = self.next_id
  self.next_id = self.next_id + 1
  id
}

///|
fn is_authenticated(state : ServerState, conn_id : Int32) -> Bool {
  state.auth_ok.get(conn_id).unwrap_or(false)
}

///|
fn authorize(auth : AuthConfig?, options : @core.ConnectOptions) -> Bool {
  match auth {
    None => true
    Some(Token(expected)) =>
      match options.auth_token {
        Some(actual) => actual == expected
        None => false
      }
    Some(UserPass(user, pass)) =>
      options.user == Some(user) && options.pass == Some(pass)
  }
}

///|
fn format_error(error : @core.ParseError) -> String {
  match error {
    EmptyLine => "Empty control line"
    UnknownOp(_) => "Unknown Protocol Operation"
    BadArity(_) => "Parser Error"
    BadNumber(_) => "Parser Error"
    PayloadTooLarge(_) => "Maximum Payload Violation"
  }
}

///|
async fn writer_loop(conn : @socket.Tcp, outbox : @aqueue.Queue[Bytes]) -> Unit {
  try {
    while true {
      let frame = outbox.get()
      conn.write(frame)
    }
  } catch {
    _ => ()
  }
}

///|
/// Enqueue one frame without blocking. A full queue means the consumer is too
/// slow: close the socket and let the read loop clean up.
fn push_frame(target : Connection, frame : Bytes) -> Bool {
  let ok = target.outbox.try_put(frame) catch { _ => false }
  if !ok {
    target.conn.close()
  }
  ok
}

///|
fn deliver(
  state : ServerState,
  subject : String,
  reply : String?,
  payload : Bytes,
) -> Int32 {
  let targets = state.registry.select(subject)
  let count = targets.length()
  for sub in targets {
    match state.conns.get(sub.conn_id) {
      Some(target) => {
        let header = @core.msg_header(subject, sub.sid, reply, payload.length())
        if push_frame(target, @utf8.encode(header)) {
          if push_frame(target, payload) {
            let _ = push_frame(target, @utf8.encode("\r\n"))
            state.stats.record_out(payload.length())
          }
        }
      }
      None => ()
    }
  }
  count
}

///|
fn deliver_h(
  state : ServerState,
  subject : String,
  reply : String?,
  header_size : Int32,
  payload : Bytes,
) -> Int32 {
  let targets = state.registry.select(subject)
  let count = targets.length()
  for sub in targets {
    match state.conns.get(sub.conn_id) {
      Some(target) => {
        let header = @core.hmsg_header(
          subject,
          sub.sid,
          reply,
          header_size,
          payload.length(),
        )
        if push_frame(target, @utf8.encode(header)) {
          if push_frame(target, payload) {
            let _ = push_frame(target, @utf8.encode("\r\n"))
            state.stats.record_out(payload.length())
          }
        }
      }
      None => ()
    }
  }
  count
}

///|
/// NATS no-responders: a request with no matching subscriber gets a 503 status
/// header delivered to its reply subject, if the client opt-in via CONNECT.
fn send_no_responders(state : ServerState, reply : String) -> Unit {
  let payload = @utf8.encode("NATS/1.0 503\r\n\r\n")
  let _ = deliver_h(state, reply, None, payload.length(), payload)
}

///|
async fn handle_connect(
  state : ServerState,
  conn_id : Int32,
  outbox : @aqueue.Queue[Bytes],
  json : String,
) -> Bool {
  match @core.parse_connect(json) {
    Ok(options) => {
      state.names.set(conn_id, options.name.unwrap_or(""))
      state.no_responses.set(conn_id, options.no_responders)
      if authorize(state.config.auth, options) {
        state.auth_ok.set(conn_id, true)
        true
      } else {
        outbox.put(@utf8.encode(@core.err_line("Authorization Violation")))
        false
      }
    }
    Err(_) => {
      outbox.put(@utf8.encode(@core.err_line("Parser Error")))
      false
    }
  }
}

///|
async fn reject_unauthorized(outbox : @aqueue.Queue[Bytes]) -> Bool {
  outbox.put(@utf8.encode(@core.err_line("Authorization Violation")))
  false
}

///|
async fn handle_op(
  state : ServerState,
  conn_id : Int32,
  conn : @socket.Tcp,
  outbox : @aqueue.Queue[Bytes],
  op : @core.ClientOp,
) -> Bool {
  match op {
    Ping => {
      outbox.put(@utf8.encode(@core.pong_line()))
      true
    }
    Pong => true
    Connect(json) => handle_connect(state, conn_id, outbox, json)
    Sub(subject, queue, sid) =>
      if !is_authenticated(state, conn_id) {
        reject_unauthorized(outbox)
      } else {
        state.registry.add({ sid, subject, queue, conn_id, })
        state.stats.subscriptions = state.registry.length()
        true
      }
    Unsub(sid, _) =>
      if !is_authenticated(state, conn_id) {
        reject_unauthorized(outbox)
      } else {
        state.registry.remove(conn_id, sid)
        state.stats.subscriptions = state.registry.length()
        true
      }
    Pub(subject, reply, size) =>
      if !is_authenticated(state, conn_id) {
        reject_unauthorized(outbox)
      } else {
        let payload = conn.read_exactly(size)
        let _ = conn.read_exactly(2)
        state.stats.record_in(size)
        let delivered = deliver(state, subject, reply, payload)
        if delivered == 0 {
          match reply {
            Some(reply) =>
              if state.no_responses.get(conn_id).unwrap_or(false) {
                send_no_responders(state, reply)
              }
            None => ()
          }
        }
        true
      }
    Hpub(subject, reply, header_size, total_size) =>
      if !is_authenticated(state, conn_id) {
        reject_unauthorized(outbox)
      } else {
        let payload = conn.read_exactly(total_size)
        let _ = conn.read_exactly(2)
        state.stats.record_in(total_size)
        let delivered = deliver_h(state, subject, reply, header_size, payload)
        if delivered == 0 {
          match reply {
            Some(reply) =>
              if state.no_responses.get(conn_id).unwrap_or(false) {
                send_no_responders(state, reply)
              }
            None => ()
          }
        }
        true
      }
  }
}

///|
async fn handle_connection(state : ServerState, conn : @socket.Tcp) -> Unit {
  let conn_id = state.alloc_id()
  let outbox : @aqueue.Queue[Bytes] = @aqueue.Queue::Queue(kind=Blocking(4096))
  state.conns.set(conn_id, { conn, outbox, })
  state.auth_ok.set(conn_id, state.config.auth is None)
  state.no_responses.set(conn_id, false)
  state.names.set(conn_id, "")
  state.stats.open_connection()
  defer {
    state.conns.remove(conn_id)
    state.auth_ok.remove(conn_id)
    state.no_responses.remove(conn_id)
    state.names.remove(conn_id)
    state.registry.remove_conn(conn_id)
    state.stats.close_connection()
    state.stats.subscriptions = state.registry.length()
    outbox.close()
  }
  outbox.put(
    @utf8.encode(
      @core.info_line(
        state.server_id,
        state.config.server_name,
        @core.version(),
        state.config.port,
        state.config.max_payload,
      ),
    ),
  )
  @async.with_task_group(group => {
    group.spawn_bg() <| () => { writer_loop(conn, outbox) }
    while conn.read_until("\r\n") is Some(line) {
      if line.length() > state.config.max_control_line {
        outbox.put(
          @utf8.encode(@core.err_line("Maximum Control Line Exceeded")),
        )
        break
      }
      match @core.parse_client_line(line, state.config.max_payload) {
        Ok(op) => if !handle_op(state, conn_id, conn, outbox, op) { break }
        Err(error) =>
          outbox.put(@utf8.encode(@core.err_line(format_error(error))))
      }
    }
    // Let the writer drain queued frames (for example the error just sent)
    // before the task group cancels it.
    outbox.close()
  }) catch {
    _ => ()
  }
}

///|
/// Bind a listener. Exposed for tests, which pass port 0 and use
/// `server.addr` to discover the ephemeral port.
pub async fn bind(config : ServerConfig) -> @socket.TcpServer {
  let addr = @socket.Addr::new(0x7F000001U, config.port)
  @socket.TcpServer(addr, reuse_addr=true)
}

///|
/// Serve on an already-bound listener until it is closed.
pub async fn serve(server : @socket.TcpServer, config : ServerConfig) -> Unit {
  let state = ServerState::new(config)
  @async.with_task_group(group => {
    match config.monitor_port {
      Some(port) =>
        group.spawn_bg(no_wait=true) <| () => { run_monitor(state, port) }
      None => ()
    }
    server.run_forever(
      (conn, _) => handle_connection(state, conn),
      max_connections=config.max_connections,
    )
  })
}

///|
/// Start the server and block until the listener stops.
pub async fn run(config : ServerConfig) -> Unit {
  let server = bind(config)
  println("moonnatsd listening on \{server.addr}")
  serve(server, config)
}
