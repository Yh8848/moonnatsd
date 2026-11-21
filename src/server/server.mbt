///|
/// Server configuration for the single-node runtime.
pub(all) struct ServerConfig {
  host : String
  port : Int32
  max_payload : Int32
  server_name : String
}

///|
pub fn ServerConfig::new() -> ServerConfig {
  {
    host: "127.0.0.1",
    port: 4222,
    max_payload: 1024 * 1024,
    server_name: "moonnatsd",
  }
}

///|
/// One live client connection. `outbox` is the only writer of `conn`, so
/// frames from different publishers cannot interleave.
priv struct Connection {
  outbox : @aqueue.Queue[Bytes]
}

///|
/// Shared server state. This is a reference type; every connection task sees
/// the same registry and connection table.
priv struct ServerState {
  config : ServerConfig
  registry : @core.Registry
  conns : Map[Int32, Connection]
  mut next_id : Int32
  server_id : String
}

///|
fn ServerState::new(config : ServerConfig) -> ServerState {
  {
    config,
    registry: @core.Registry::new(),
    conns: Map([]),
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
async fn deliver(
  state : ServerState,
  subject : String,
  reply : String?,
  payload : Bytes,
) -> Unit {
  let targets = state.registry.select(subject)
  for sub in targets {
    match state.conns.get(sub.conn_id) {
      Some(target) => {
        let header = @core.msg_header(subject, sub.sid, reply, payload.length())
        target.outbox.put(@utf8.encode(header))
        target.outbox.put(payload)
        target.outbox.put(@utf8.encode("\r\n"))
      }
      None => ()
    }
  }
}

///|
async fn deliver_h(
  state : ServerState,
  subject : String,
  reply : String?,
  header_size : Int32,
  payload : Bytes,
) -> Unit {
  let targets = state.registry.select(subject)
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
        target.outbox.put(@utf8.encode(header))
        target.outbox.put(payload)
        target.outbox.put(@utf8.encode("\r\n"))
      }
      None => ()
    }
  }
}

///|
async fn handle_op(
  state : ServerState,
  conn_id : Int32,
  conn : @socket.Tcp,
  outbox : @aqueue.Queue[Bytes],
  op : @core.ClientOp,
) -> Unit {
  match op {
    Ping => outbox.put(@utf8.encode("PONG\r\n"))
    Pong => ()
    Connect(_) => ()
    Sub(subject, queue, sid) =>
      state.registry.add({ sid, subject, queue, conn_id, })
    Unsub(sid, _) => state.registry.remove(conn_id, sid)
    Pub(subject, reply, size) => {
      let payload = conn.read_exactly(size)
      let _ = conn.read_exactly(2)
      deliver(state, subject, reply, payload)
    }
    Hpub(subject, reply, header_size, total_size) => {
      let payload = conn.read_exactly(total_size)
      let _ = conn.read_exactly(2)
      deliver_h(state, subject, reply, header_size, payload)
    }
  }
}

///|
async fn handle_connection(state : ServerState, conn : @socket.Tcp) -> Unit {
  let conn_id = state.alloc_id()
  let outbox : @aqueue.Queue[Bytes] = @aqueue.Queue::Queue(kind=Unbounded)
  state.conns.set(conn_id, { outbox, })
  defer {
    state.conns.remove(conn_id)
    state.registry.remove_conn(conn_id)
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
    group.spawn_bg(no_wait=true) <| () => { writer_loop(conn, outbox) }
    while conn.read_until("\r\n") is Some(line) {
      match @core.parse_client_line(line, state.config.max_payload) {
        Ok(op) => handle_op(state, conn_id, conn, outbox, op)
        Err(error) =>
          outbox.put(@utf8.encode("-ERR '\{format_error(error)}'\r\n"))
      }
    }
  }) catch {
    _ => ()
  }
}

///|
/// Start the server and block until the listener stops.
pub async fn run(config : ServerConfig) -> Unit {
  let state = ServerState::new(config)
  let addr = @socket.Addr::new(0x7F000001U, config.port)
  let server = @socket.TcpServer(addr, reuse_addr=true)
  println("moonnatsd listening on \{server.addr}")
  server.run_forever((conn, _) => handle_connection(state, conn))
}
