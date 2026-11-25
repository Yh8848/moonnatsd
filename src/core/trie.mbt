///|
/// One node in the subject trie. Nodes live in an arena (`SubjectTrie::nodes`)
/// so the structure has no recursive value types and no reference cycles.
struct TrieNode {
  children : Map[String, Int32]
  subs : Array[Subscription]
}

///|
fn TrieNode::new() -> TrieNode {
  { children: Map([]), subs: [], }
}

///|
/// A token trie for NATS subjects.
///
/// Wildcards:
/// - `*` is a child key that matches exactly one token.
/// - `>` is a child key whose subscriptions match one or more remaining tokens.
///
/// The trie is the source of truth for subscriptions; the registry only
/// forwards to it. Queue-group selection happens after matching so that each
/// group receives exactly one copy.
pub struct SubjectTrie {
  nodes : Array[TrieNode]
  cursor : Map[String, Int32]
}

///|
pub fn SubjectTrie::new() -> SubjectTrie {
  let nodes : Array[TrieNode] = [TrieNode::new()]
  { nodes, cursor: Map([]), }
}

///|
/// Insert a subscription at its subject node.
pub fn SubjectTrie::insert(self : SubjectTrie, sub : Subscription) -> Unit {
  let tokens = sub.subject.split(".").to_array()
  let mut index = 0
  for token in tokens {
    let key = token.to_owned()
    let node = self.nodes[index]
    match node.children.get(key) {
      Some(next) => index = next
      None => {
        let next = self.nodes.length()
        self.nodes.push(TrieNode::new())
        node.children.set(key, next)
        index = next
      }
    }
  }
  self.nodes[index].subs.push(sub)
}

///|
fn SubjectTrie::remove_at(
  self : SubjectTrie,
  index : Int32,
  conn_id : Int32,
  sid : String,
) -> Unit {
  let subs = self.nodes[index].subs
  let mut i = 0
  while i < subs.length() {
    let sub = subs[i]
    if sub.conn_id == conn_id && sub.sid == sid {
      let _ = subs.remove(i)
    } else {
      i = i + 1
    }
  }
}

///|
/// Remove one subscription by scanning all nodes for its `(conn_id, sid)`.
/// `sid` is only unique per connection, so both are required.
pub fn SubjectTrie::remove(
  self : SubjectTrie,
  conn_id : Int32,
  sid : String,
) -> Unit {
  for node in self.nodes {
    remove_at_node(node, conn_id, sid)
  }
}

///|
fn remove_at_node(node : TrieNode, conn_id : Int32, sid : String) -> Unit {
  let subs = node.subs
  let mut i = 0
  while i < subs.length() {
    let sub = subs[i]
    if sub.conn_id == conn_id && sub.sid == sid {
      let _ = subs.remove(i)
    } else {
      i = i + 1
    }
  }
}

///|
/// Remove a subscription by subject and sid. The subject path is required
/// because the same sid is only unique per connection.
pub fn SubjectTrie::remove_sub(
  self : SubjectTrie,
  subject : String,
  conn_id : Int32,
  sid : String,
) -> Unit {
  let tokens = subject.split(".").to_array()
  let mut index = 0
  for token in tokens {
    match self.nodes[index].children.get(token.to_owned()) {
      Some(next) => index = next
      None => return
    }
  }
  self.remove_at(index, conn_id, sid)
}

///|
/// Remove every subscription owned by a connection. Called on disconnect.
pub fn SubjectTrie::remove_conn(self : SubjectTrie, conn_id : Int32) -> Unit {
  for node in self.nodes {
    let subs = node.subs
    let mut i = 0
    while i < subs.length() {
      if subs[i].conn_id == conn_id {
        let _ = subs.remove(i)
      } else {
        i = i + 1
      }
    }
  }
}

///|
/// Select one copy per plain subscription and one member per queue group.
fn SubjectTrie::select_queue(
  self : SubjectTrie,
  matched : Array[Subscription],
) -> Array[Subscription] {
  let plain : Array[Subscription] = []
  let groups : Map[String, Array[Subscription]] = Map([])
  for sub in matched {
    match sub.queue {
      None => plain.push(sub)
      Some(queue) => {
        let bucket = match groups.get(queue) {
          Some(bucket) => bucket
          None => {
            let bucket : Array[Subscription] = []
            groups.set(queue, bucket)
            bucket
          }
        }
        bucket.push(sub)
      }
    }
  }
  for queue in groups.keys() {
    match groups.get(queue) {
      Some(bucket) =>
        if bucket.length() > 0 {
          let index = self.cursor.get_or_default(queue, 0)
          plain.push(bucket[index % bucket.length()])
          self.cursor.set(queue, index + 1)
        }
      None => ()
    }
  }
  plain
}

///|
/// Match a concrete subject against the trie.
pub fn SubjectTrie::select(
  self : SubjectTrie,
  subject : String,
) -> Array[Subscription] {
  let tokens = subject.split(".").to_array()
  let mut frontier : Array[Int32] = [0]
  let matched : Array[Subscription] = []
  let mut i = 0
  while i < tokens.length() {
    let token = tokens[i].to_owned()
    let next : Array[Int32] = []
    for index in frontier {
      let node = self.nodes[index]
      match node.children.get(token) {
        Some(child) => next.push(child)
        None => ()
      }
      match node.children.get("*") {
        Some(child) => next.push(child)
        None => ()
      }
      match node.children.get(">") {
        Some(child) =>
          for sub in self.nodes[child].subs {
            matched.push(sub)
          }
        None => ()
      }
    }
    frontier = next
    i = i + 1
  }
  for index in frontier {
    for sub in self.nodes[index].subs {
      matched.push(sub)
    }
  }
  self.select_queue(matched)
}

///|
/// Total number of subscriptions across all nodes.
pub fn SubjectTrie::count(self : SubjectTrie) -> Int32 {
  let mut total = 0
  for node in self.nodes {
    total = total + node.subs.length()
  }
  total
}

///|
/// Number of trie nodes, useful for monitoring and tests.
pub fn SubjectTrie::node_count(self : SubjectTrie) -> Int32 {
  self.nodes.length()
}
