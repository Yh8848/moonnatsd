///|
test "parse default CLI options" {
  match parse_args(["moonnatsd"]) {
    Ok(options) => {
      assert_eq(options.config.port, 4222)
      assert_eq(options.config.max_payload, 1024 * 1024)
      assert_true(options.config.auth is None)
      assert_false(options.help)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse port and token" {
  match parse_args(["moonnatsd", "--port", "4333", "--token", "secret"]) {
    Ok(options) => {
      assert_eq(options.config.port, 4333)
      match options.config.auth {
        Some(Token(value)) => assert_eq(value, "secret")
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse user and pass" {
  match parse_args(["moonnatsd", "--user", "alice", "--pass", "pw"]) {
    Ok(options) =>
      match options.config.auth {
        Some(UserPass(user, pass)) => {
          assert_eq(user, "alice")
          assert_eq(pass, "pw")
        }
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "parse help and version" {
  match parse_args(["moonnatsd", "--help"]) {
    Ok(options) => assert_true(options.help)
    Err(_) => assert_true(false)
  }
  match parse_args(["moonnatsd", "--version"]) {
    Ok(options) => assert_true(options.version)
    Err(_) => assert_true(false)
  }
}

///|
test "parse rejects unknown and missing values" {
  match parse_args(["moonnatsd", "--nope"]) {
    Err(_) => assert_true(true)
    Ok(_) => assert_true(false)
  }
  match parse_args(["moonnatsd", "--port"]) {
    Err(_) => assert_true(true)
    Ok(_) => assert_true(false)
  }
  match parse_args(["moonnatsd", "--port", "not-a-number"]) {
    Err(_) => assert_true(true)
    Ok(_) => assert_true(false)
  }
  match parse_args(["moonnatsd", "--user", "alice"]) {
    Err(_) => assert_true(true)
    Ok(_) => assert_true(false)
  }
}
