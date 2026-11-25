///|
/// HTTP reason phrase for the two status codes this server emits.
fn http_reason(status : Int32) -> String {
  if status == 200 {
    "OK"
  } else if status == 404 {
    "Not Found"
  } else {
    "OK"
  }
}

///|
/// Minimal JSON string escaping for names and subjects.
fn json_escape(value : String) -> String {
  let mut out = ""
  for c in value {
    if c == '"' {
      out = out + "\\\""
    } else if c == '\\' {
      out = out + "\\\\"
    } else if c == '\n' {
      out = out + "\\n"
    } else if c == '\r' {
      out = out + "\\r"
    } else if c == '\t' {
      out = out + "\\t"
    } else {
      out = out + c.to_string()
    }
  }
  out
}

///|
/// Route a monitoring request to a JSON response.
fn route(state : ServerState, path : String) -> (Int32, String) {
  if path == "/healthz" {
    (200, "{\"status\":\"ok\"}")
  } else if path == "/varz" {
    let stats = state.stats.to_json()
    (
      200,
      "{\"server_id\":\"\{state.server_id}\",\"version\":\"\{@core.version()}\",\"stats\":\{stats}}",
    )
  } else if path == "/subsz" {
    (
      200,
      "{\"subscriptions\":\{state.registry.length()},\"nodes\":\{state.registry.node_count()}}",
    )
  } else if path == "/connz" {
    let mut body = "{\"connections\":["
    let mut first = true
    for entry in state.names.iter() {
      let (id, name) = entry
      if !first {
        body = body + ","
      }
      first = false
      body = body +
        "{\"id\":\{id},\"name\":\"\{json_escape(name)}\",\"authenticated\":\{is_authenticated(state, id)}}"
    }
    body = body + "]}"
    (200, body)
  } else {
    (404, "{\"error\":\"not found\"}")
  }
}

///|
async fn handle_monitor(state : ServerState, conn : @socket.Tcp) -> Unit {
  try {
    match conn.read_until("\r\n") {
      Some(request_line) => {
        while conn.read_until("\r\n") is Some(header) {
          if header.is_empty() {
            break
          }
        }
        let parts = request_line.split(" ").to_array()
        let path = if parts.length() >= 2 { parts[1].to_owned() } else { "/" }
        let (status, body) = route(state, path)
        let response = "HTTP/1.1 \{status} \{http_reason(status)}\r\nContent-Type: application/json\r\nContent-Length: \{body.length()}\r\nConnection: close\r\n\r\n\{body}"
        conn.write(response)
      }
      None => ()
    }
  } catch {
    _ => ()
  }
  conn.close()
}

///|
/// Start the monitoring listener on `port`. The listener keeps running until
/// the surrounding task group is cancelled.
async fn run_monitor(state : ServerState, port : Int32) -> Unit {
  let server = @socket.TcpServer(
    @socket.Addr::new(0x7F000001U, port),
    reuse_addr=true,
  )
  server.run_forever((conn, _) => handle_monitor(state, conn))
}
