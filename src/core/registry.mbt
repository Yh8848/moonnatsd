///|
/// One subscription, owned by a connection.
pub(all) struct Subscription {
  sid : String
  subject : String
  queue : String?
  conn_id : Int32
}

///|
/// Protocol-independent subscription registry.
///
/// The registry is a thin facade over `SubjectTrie`; the server maps a
/// `conn_id` to a connection and performs delivery. All methods are synchronous
/// and are only called from the single-threaded async runtime.
pub struct Registry {
  trie : SubjectTrie
}

///|
pub fn Registry::new() -> Registry {
  { trie: SubjectTrie::new(), }
}

///|
pub fn Registry::add(self : Registry, sub : Subscription) -> Unit {
  self.trie.insert(sub)
}

///|
/// Remove a specific subscription of a connection.
pub fn Registry::remove(self : Registry, conn_id : Int32, sid : String) -> Unit {
  self.trie.remove(conn_id, sid)
}

///|
/// Remove every subscription owned by a connection (called on disconnect).
pub fn Registry::remove_conn(self : Registry, conn_id : Int32) -> Unit {
  self.trie.remove_conn(conn_id)
}

///|
/// Select the subscriptions that should receive a message published to
/// `subject`. Plain subscriptions are all selected; each queue group selects
/// exactly one member using a per-group round-robin cursor.
pub fn Registry::select(
  self : Registry,
  subject : String,
) -> Array[Subscription] {
  self.trie.select(subject)
}

///|
/// Number of subscriptions, for tests and monitoring.
pub fn Registry::length(self : Registry) -> Int32 {
  self.trie.count()
}

///|
/// Number of trie nodes, for tests and monitoring.
pub fn Registry::node_count(self : Registry) -> Int32 {
  self.trie.node_count()
}
