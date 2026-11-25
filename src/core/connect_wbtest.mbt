///|
test "parse connect options" {
  match
    parse_connect(
      "{\"verbose\":true,\"pedantic\":true,\"echo\":false,\"headers\":true,\"no_responders\":true,\"protocol\":1,\"name\":\"worker\",\"user\":\"alice\",\"pass\":\"secret\",\"auth_token\":\"tok\"}",
    ) {
    Ok(options) => {
      assert_true(options.verbose)
      assert_true(options.pedantic)
      assert_false(options.echo)
      assert_true(options.headers)
      assert_true(options.no_responders)
      assert_eq(options.protocol, 1)
      assert_eq(options.name, Some("worker"))
      assert_eq(options.user, Some("alice"))
      assert_eq(options.pass, Some("secret"))
      assert_eq(options.auth_token, Some("tok"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "connect defaults" {
  match parse_connect("{}") {
    Ok(options) => {
      assert_false(options.verbose)
      assert_false(options.pedantic)
      assert_true(options.echo)
      assert_false(options.headers)
      assert_false(options.no_responders)
      assert_eq(options.protocol, 1)
      assert_eq(options.name, None)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "unknown connect fields are ignored" {
  match parse_connect("{\"future_option\":42,\"echo\":false}") {
    Ok(options) => assert_false(options.echo)
    Err(_) => assert_true(false)
  }
}

///|
test "connect rejects malformed json" {
  match parse_connect("{not json") {
    Err(BadJson(_)) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "connect rejects non-object json" {
  match parse_connect("[1,2,3]") {
    Err(NotAnObject) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "connect helper methods" {
  let options = ConnectOptions::default()
  assert_false(options.is_verbose())
  assert_false(options.no_echo())
}
