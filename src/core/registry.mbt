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
/// The registry knows nothing about sockets; the server maps a `conn_id` to a
/// connection and performs delivery. All methods are synchronous and are only
/// called from the single-threaded async runtime.
pub struct Registry {
  subs : Array[Subscription]
  cursor : Map[String, Int32]
}

///|
pub fn Registry::new() -> Registry {
  { subs: [], cursor: Map([]), }
}

///|
pub fn Registry::add(self : Registry, sub : Subscription) -> Unit {
  self.subs.push(sub)
}

///|
/// Remove a specific subscription of a connection.
pub fn Registry::remove(self : Registry, conn_id : Int32, sid : String) -> Unit {
  let mut i = 0
  while i < self.subs.length() {
    let sub = self.subs[i]
    if sub.conn_id == conn_id && sub.sid == sid {
      let _ = self.subs.remove(i)
    } else {
      i = i + 1
    }
  }
}

///|
/// Remove every subscription owned by a connection (called on disconnect).
pub fn Registry::remove_conn(self : Registry, conn_id : Int32) -> Unit {
  let mut i = 0
  while i < self.subs.length() {
    if self.subs[i].conn_id == conn_id {
      let _ = self.subs.remove(i)
    } else {
      i = i + 1
    }
  }
}

///|
/// Select the subscriptions that should receive a message published to
/// `subject`. Plain subscriptions are all selected; each queue group selects
/// exactly one member using a per-group round-robin cursor.
pub fn Registry::select(
  self : Registry,
  subject : String,
) -> Array[Subscription] {
  let plain : Array[Subscription] = []
  let groups : Map[String, Array[Subscription]] = Map([])
  for sub in self.subs {
    if subject_matches(sub.subject, subject) {
      match sub.queue {
        None => plain.push(sub)
        Some(queue) => {
          let arr = match groups.get(queue) {
            Some(arr) => arr
            None => {
              let arr : Array[Subscription] = []
              groups.set(queue, arr)
              arr
            }
          }
          arr.push(sub)
        }
      }
    }
  }
  for queue in groups.keys() {
    match groups.get(queue) {
      Some(arr) =>
        if arr.length() > 0 {
          let index = self.cursor.get_or_default(queue, 0)
          plain.push(arr[index % arr.length()])
          self.cursor.set(queue, index + 1)
        }
      None => ()
    }
  }
  plain
}

///|
/// Number of subscriptions, for tests and monitoring.
pub fn Registry::length(self : Registry) -> Int32 {
  self.subs.length()
}
