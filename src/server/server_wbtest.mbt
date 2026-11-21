///|
async test "pub sub over tcp" {
  let config : ServerConfig = {
    host: "127.0.0.1",
    port: 0,
    max_payload: 1024,
    server_name: "test",
  }
  let server = bind(config)
  let addr = server.addr
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true) <| () => { serve(server, config) }
    @async.sleep(20)
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
    server.close()
  })
}

///|
async test "ping gets pong" {
  let config : ServerConfig = {
    host: "127.0.0.1",
    port: 0,
    max_payload: 1024,
    server_name: "test",
  }
  let server = bind(config)
  let addr = server.addr
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true) <| () => { serve(server, config) }
    @async.sleep(20)
    let client = @socket.Tcp::connect(addr)
    defer client.close()
    let _ = client.read_until("\r\n")
    client.write("PING\r\n")
    match client.read_until("\r\n") {
      Some(line) => assert_eq(line, "PONG")
      None => assert_true(false)
    }
    server.close()
  })
}
