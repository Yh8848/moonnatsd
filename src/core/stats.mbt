///|
/// Server counters. All mutation happens on the single-threaded async runtime,
/// so plain mutable fields are sufficient.
pub(all) struct Stats {
  mut connections : Int32
  mut total_connections : Int32
  mut in_msgs : Int32
  mut out_msgs : Int32
  mut in_bytes : Int32
  mut out_bytes : Int32
  mut subscriptions : Int32
}

///|
pub fn Stats::new() -> Stats {
  {
    connections: 0,
    total_connections: 0,
    in_msgs: 0,
    out_msgs: 0,
    in_bytes: 0,
    out_bytes: 0,
    subscriptions: 0,
  }
}

///|
pub fn Stats::open_connection(self : Stats) -> Unit {
  self.connections = self.connections + 1
  self.total_connections = self.total_connections + 1
}

///|
pub fn Stats::close_connection(self : Stats) -> Unit {
  if self.connections > 0 {
    self.connections = self.connections - 1
  }
}

///|
pub fn Stats::record_in(self : Stats, bytes : Int32) -> Unit {
  self.in_msgs = self.in_msgs + 1
  self.in_bytes = self.in_bytes + bytes
}

///|
pub fn Stats::record_out(self : Stats, bytes : Int32) -> Unit {
  self.out_msgs = self.out_msgs + 1
  self.out_bytes = self.out_bytes + bytes
}

///|
pub fn Stats::add_subscription(self : Stats) -> Unit {
  self.subscriptions = self.subscriptions + 1
}

///|
pub fn Stats::remove_subscriptions(self : Stats, count : Int32) -> Unit {
  self.subscriptions = self.subscriptions - count
  if self.subscriptions < 0 {
    self.subscriptions = 0
  }
}

///|
/// Compact JSON for `/varz`. Values are integers, so no escaping is needed.
pub fn Stats::to_json(self : Stats) -> String {
  "{\"connections\":\{self.connections},\"total_connections\":\{self.total_connections},\"in_msgs\":\{self.in_msgs},\"out_msgs\":\{self.out_msgs},\"in_bytes\":\{self.in_bytes},\"out_bytes\":\{self.out_bytes},\"subscriptions\":\{self.subscriptions}}"
}
