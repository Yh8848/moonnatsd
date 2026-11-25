///|
test "parse simple header block" {
  match
    parse_header_block("NATS/1.0\r\nNats-Msg-Id: abc\r\nX-Test: 1\r\n\r\n") {
    Ok(header) => {
      assert_eq(header.get("nats-msg-id"), Some("abc"))
      assert_eq(header.get("X-TEST"), Some("1"))
      assert_eq(header.get("missing"), None)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse status line" {
  match parse_header_block("NATS/1.0 503 No Responders\r\n\r\n") {
    Ok(header) => assert_eq(header.status, Some("503 No Responders"))
    Err(_) => assert_true(false)
  }
}

///|
test "serialize header block" {
  let header = Header::new()
  header.status = Some("100 Idle Heartbeat")
  header.set("Nats-Stream", "orders")
  header.set("Nats-Sequence", "42")
  assert_eq(
    header.to_string(),
    "NATS/1.0 100 Idle Heartbeat\r\nNats-Stream: orders\r\nNats-Sequence: 42\r\n\r\n",
  )
}

///|
test "header set replaces case-insensitively" {
  let header = Header::new()
  header.set("Nats-Msg-Id", "one")
  header.set("nats-msg-id", "two")
  assert_eq(header.get("NATS-MSG-ID"), Some("two"))
  assert_eq(header.values.length(), 1)
}

///|
test "header remove" {
  let header = Header::new()
  header.set("A", "1")
  header.set("B", "2")
  header.remove("a")
  assert_eq(header.get("A"), None)
  assert_eq(header.values.length(), 1)
}

///|
test "malformed header blocks" {
  match parse_header_block("") {
    Err(MissingVersion) => assert_true(true)
    _ => assert_true(false)
  }
  match parse_header_block("BOGUS\r\n\r\n") {
    Ok(_) => assert_true(false)
    Err(BadVersion(_)) => assert_true(true)
    Err(_) => assert_true(false)
  }
  match parse_header_block("NATS/1.0\r\nno-colon\r\n\r\n") {
    Ok(_) => assert_true(false)
    Err(MissingColon(_)) => assert_true(true)
    Err(_) => assert_true(false)
  }
  match parse_header_block("NATS/1.0\r\n: value\r\n\r\n") {
    Ok(_) => assert_true(false)
    Err(EmptyKey) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "header size includes blank line" {
  let header = Header::new()
  header.set("A", "1")
  assert_eq(header_size(header), "NATS/1.0\r\nA: 1\r\n\r\n".length())
}
