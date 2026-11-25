///|
test "json escape" {
  assert_eq(json_escape("a\"b\\c"), "a\\\"b\\\\c")
  assert_eq(json_escape("plain"), "plain")
}
