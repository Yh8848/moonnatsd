///|
test "stats counters" {
  let stats = Stats::new()
  stats.open_connection()
  stats.open_connection()
  stats.close_connection()
  stats.record_in(10)
  stats.record_out(20)
  stats.add_subscription()
  stats.add_subscription()
  stats.remove_subscriptions(1)
  assert_eq(stats.connections, 1)
  assert_eq(stats.total_connections, 2)
  assert_eq(stats.in_msgs, 1)
  assert_eq(stats.out_msgs, 1)
  assert_eq(stats.in_bytes, 10)
  assert_eq(stats.out_bytes, 20)
  assert_eq(stats.subscriptions, 1)
}

///|
test "stats never goes negative" {
  let stats = Stats::new()
  stats.close_connection()
  stats.remove_subscriptions(3)
  assert_eq(stats.connections, 0)
  assert_eq(stats.subscriptions, 0)
}

///|
test "stats json" {
  let stats = Stats::new()
  stats.open_connection()
  stats.record_in(7)
  let json = stats.to_json()
  assert_true(json.contains("\"connections\":1"))
  assert_true(json.contains("\"in_bytes\":7"))
}
