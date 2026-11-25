///|
fn test_config(port : Int32) -> ServerConfig {
  {
    host: "127.0.0.1",
    port,
    max_payload: 1024,
    max_control_line: 1024,
    max_connections: 64,
    server_name: "test",
    auth: None,
    monitor_port: None,
  }
}

///|
fn test_config_auth(port : Int32, token : String) -> ServerConfig {
  let base = test_config(port)
  {
    host: base.host,
    port: base.port,
    max_payload: base.max_payload,
    max_control_line: base.max_control_line,
    max_connections: base.max_connections,
    server_name: base.server_name,
    auth: Some(Token(token)),
    monitor_port: base.monitor_port,
  }
}

///|
async test "pub sub over tcp" {
  let config = test_config(0)
  let server = bind(config)
  let addr = server.addr
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true) <| () => { serve(server, config) }
    @async.sleep(20)
    let _ = @async.with_timeout(5000, () => {
      let client = @socket.Tcp::connect(addr)
      defer client.close()
      match client.read_until("\r\n") {
        Some(line) => assert_true(line.has_prefix("INFO "))
        None => assert_true(false)
      }
      client.write("CONNECT {}\r\n")
      client.write("SUB foo 1\r\n")
      client.write("PUB foo 2\r\nhi\r\n")
      let mut seen = false
      let mut tries = 0
      while tries < 10 {
        match client.read_until("\r\n") {
          Some(line) =>
            if line.has_prefix("MSG foo 1 2") {
              seen = true
              break
            }
          None => break
        }
        tries = tries + 1
      }
      assert_true(seen)
    }) catch {
      _ => assert_true(false)
    }
    group.return_immediately(())
  })
}

///|
async test "ping gets pong" {
  let config = test_config(0)
  let server = bind(config)
  let addr = server.addr
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true) <| () => { serve(server, config) }
    @async.sleep(20)
    let _ = @async.with_timeout(5000, () => {
      let client = @socket.Tcp::connect(addr)
      defer client.close()
      let _ = client.read_until("\r\n")
      client.write("PING\r\n")
      match client.read_until("\r\n") {
        Some(line) => assert_eq(line, "PONG")
        None => assert_true(false)
      }
    }) catch {
      _ => assert_true(false)
    }
    group.return_immediately(())
  })
}

///|
async test "token auth rejects wrong token" {
  let config = test_config_auth(0, "secret")
  let server = bind(config)
  let addr = server.addr
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true) <| () => { serve(server, config) }
    @async.sleep(20)
    let _ = @async.with_timeout(5000, () => {
      let client = @socket.Tcp::connect(addr)
      defer client.close()
      let _ = client.read_until("\r\n")
      client.write("CONNECT {\"auth_token\":\"wrong\"}\r\n")
      match client.read_until("\r\n") {
        Some(line) => assert_true(line.has_prefix("-ERR"))
        None => assert_true(false)
      }
    }) catch {
      _ => assert_true(false)
    }
    group.return_immediately(())
  })
}

///|
async test "token auth accepts correct token" {
  let config = test_config_auth(0, "secret")
  let server = bind(config)
  let addr = server.addr
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true) <| () => { serve(server, config) }
    @async.sleep(20)
    let _ = @async.with_timeout(5000, () => {
      let client = @socket.Tcp::connect(addr)
      defer client.close()
      let _ = client.read_until("\r\n")
      client.write("CONNECT {\"auth_token\":\"secret\"}\r\n")
      client.write("SUB secure 1\r\n")
      client.write("PUB secure 2\r\nok\r\n")
      let mut seen = false
      let mut tries = 0
      while tries < 10 {
        match client.read_until("\r\n") {
          Some(line) =>
            if line.has_prefix("MSG secure 1") {
              seen = true
              break
            }
          None => break
        }
        tries = tries + 1
      }
      assert_true(seen)
    }) catch {
      _ => assert_true(false)
    }
    group.return_immediately(())
  })
}
