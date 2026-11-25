///|
async test "embedded server handle" {
  let handle = start(test_config(0))
  let addr = handle.addr()
  assert_true(handle.url().has_prefix("nats://"))
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true) <| () => { handle.serve() }
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
    handle.stop()
    group.return_immediately(())
  })
}
