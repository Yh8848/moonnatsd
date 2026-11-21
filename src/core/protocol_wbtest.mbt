///|
test "parse PING and PONG" {
  assert_eq(parse_client_line("PING", 1024), Ok(Ping))
  assert_eq(parse_client_line("PONG", 1024), Ok(Pong))
}

///|
test "parse PUB without reply" {
  assert_eq(parse_client_line("PUB foo 5", 1024), Ok(Pub("foo", None, 5)))
}

///|
test "parse PUB with reply" {
  assert_eq(
    parse_client_line("PUB foo _INBOX.abc 12", 1024),
    Ok(Pub("foo", Some("_INBOX.abc"), 12)),
  )
}

///|
test "parse SUB with and without queue" {
  assert_eq(parse_client_line("SUB foo 1", 1024), Ok(Sub("foo", None, "1")))
  assert_eq(
    parse_client_line("SUB foo workers 1", 1024),
    Ok(Sub("foo", Some("workers"), "1")),
  )
}

///|
test "parse UNSUB with max" {
  assert_eq(parse_client_line("UNSUB 1", 1024), Ok(Unsub("1", None)))
  assert_eq(parse_client_line("UNSUB 1 3", 1024), Ok(Unsub("1", Some(3))))
}

///|
test "parse CONNECT keeps JSON with spaces" {
  assert_eq(
    parse_client_line("CONNECT {\"verbose\":false,\"name\":\"a b\"}", 1024),
    Ok(Connect("{\"verbose\":false,\"name\":\"a b\"}")),
  )
}

///|
test "parse rejects bad input" {
  assert_eq(parse_client_line("", 1024), Err(EmptyLine))
  assert_eq(parse_client_line("WHAT", 1024), Err(UnknownOp("WHAT")))
  assert_eq(parse_client_line("PUB foo", 1024), Err(BadArity("PUB")))
  assert_eq(parse_client_line("PUB foo abc", 1024), Err(BadNumber("abc")))
  assert_eq(parse_client_line("PUB foo 2048", 1024), Err(PayloadTooLarge(2048)))
}

///|
test "subject matching" {
  assert_true(subject_matches("foo", "foo"))
  assert_false(subject_matches("foo", "bar"))
  assert_true(subject_matches("foo.*", "foo.bar"))
  assert_false(subject_matches("foo.*", "foo.bar.baz"))
  assert_true(subject_matches("foo.>", "foo.bar"))
  assert_true(subject_matches("foo.>", "foo.bar.baz"))
  assert_false(subject_matches("foo.>", "foo"))
  assert_true(subject_matches(">", "a.b.c"))
  assert_false(subject_matches("*.>", "a"))
}

///|
test "subject pattern validation" {
  assert_true(valid_subject_pattern("foo.*"))
  assert_true(valid_subject_pattern("foo.>"))
  assert_false(valid_subject_pattern(""))
  assert_false(valid_subject_pattern("foo.>.bar"))
  assert_false(valid_subject_pattern("foo..bar"))
}

///|
test "registry plain and queue selection" {
  let reg = Registry::new()
  reg.add({ sid: "1", subject: "foo", queue: None, conn_id: 1, })
  reg.add({ sid: "2", subject: "foo", queue: Some("w"), conn_id: 2, })
  reg.add({ sid: "3", subject: "foo", queue: Some("w"), conn_id: 3, })
  let first = reg.select("foo")
  assert_eq(first.length(), 2)
  let second = reg.select("foo")
  assert_eq(second.length(), 2)
  let queue_sids = []
  for sub in first {
    if sub.queue is Some(_) {
      queue_sids.push(sub.sid)
    }
  }
  for sub in second {
    if sub.queue is Some(_) {
      queue_sids.push(sub.sid)
    }
  }
  assert_eq(queue_sids.length(), 2)
  assert_true(queue_sids[0] != queue_sids[1])
}

///|
test "registry remove" {
  let reg = Registry::new()
  reg.add({ sid: "1", subject: "foo", queue: None, conn_id: 1, })
  reg.add({ sid: "2", subject: "bar", queue: None, conn_id: 1, })
  reg.remove_conn(1)
  assert_eq(reg.length(), 0)
}

///|
test "registry copies share storage" {
  let first = Registry::new()
  let second = first
  second.add({ sid: "1", subject: "foo", queue: None, conn_id: 1, })
  assert_eq(first.length(), 1)
  second.remove_conn(1)
  assert_eq(first.length(), 0)
}
