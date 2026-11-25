///|
fn sub(
  sid : String,
  subject : String,
  queue : String?,
  conn_id : Int32,
) -> Subscription {
  { sid, subject, queue, conn_id, }
}

///|
test "trie exact and wildcard matching" {
  let trie = SubjectTrie::new()
  trie.insert(sub("1", "foo.bar", None, 1))
  trie.insert(sub("2", "foo.*", None, 1))
  trie.insert(sub("3", "foo.>", None, 1))
  trie.insert(sub("4", ">", None, 1))
  let matches = trie.select("foo.bar")
  assert_eq(matches.length(), 4)
  let narrow = trie.select("foo")
  assert_eq(narrow.length(), 1)
  assert_eq(narrow[0].sid, "4")
}

///|
test "trie tail wildcard requires at least one token" {
  let trie = SubjectTrie::new()
  trie.insert(sub("1", "foo.>", None, 1))
  assert_eq(trie.select("foo").length(), 0)
  assert_eq(trie.select("foo.bar").length(), 1)
  assert_eq(trie.select("foo.bar.baz").length(), 1)
}

///|
test "trie queue group round robin" {
  let trie = SubjectTrie::new()
  trie.insert(sub("a", "jobs", Some("workers"), 1))
  trie.insert(sub("b", "jobs", Some("workers"), 2))
  trie.insert(sub("c", "jobs", None, 3))
  let first = trie.select("jobs")
  let second = trie.select("jobs")
  assert_eq(first.length(), 2)
  assert_eq(second.length(), 2)
  let chosen = []
  for item in first {
    if item.queue is Some(_) {
      chosen.push(item.sid)
    }
  }
  for item in second {
    if item.queue is Some(_) {
      chosen.push(item.sid)
    }
  }
  assert_eq(chosen.length(), 2)
  assert_true(chosen[0] != chosen[1])
}

///|
test "trie remove and remove_conn" {
  let trie = SubjectTrie::new()
  trie.insert(sub("1", "a.b", None, 1))
  trie.insert(sub("2", "a.c", None, 1))
  trie.insert(sub("3", "a.b", None, 2))
  assert_eq(trie.count(), 3)
  trie.remove(1, "1")
  assert_eq(trie.count(), 2)
  assert_eq(trie.select("a.b").length(), 1)
  trie.remove_conn(1)
  assert_eq(trie.count(), 1)
  assert_eq(trie.select("a.c").length(), 0)
  trie.remove_conn(2)
  assert_eq(trie.count(), 0)
}

///|
test "trie remove_sub by subject" {
  let trie = SubjectTrie::new()
  trie.insert(sub("1", "x.y", None, 7))
  trie.remove_sub("x.y", 7, "1")
  assert_eq(trie.count(), 0)
  assert_eq(trie.select("x.y").length(), 0)
}

///|
test "trie node count" {
  let trie = SubjectTrie::new()
  assert_eq(trie.node_count(), 1)
  trie.insert(sub("1", "a.b.c", None, 1))
  assert_eq(trie.node_count(), 4)
  trie.insert(sub("2", "a.b.d", None, 1))
  assert_eq(trie.node_count(), 5)
  trie.insert(sub("3", "a.*", None, 1))
  assert_eq(trie.node_count(), 6)
}
