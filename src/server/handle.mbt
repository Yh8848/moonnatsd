///|
/// A bound, not-yet-serving server. Useful for embedding in tests:
///
/// ```moonbit nocheck
/// let handle = @natsd.start(config)          // port 0 -> ephemeral port
/// @async.with_task_group(group => {
///   group.spawn_bg(() => handle.serve())
///   let url = handle.url()
///   ...
///   handle.stop()
/// })
/// ```
pub struct ServerHandle {
  server : @socket.TcpServer
  config : ServerConfig
}

///|
/// Bind the listener and return a handle. The actual port is available via
/// `addr()` / `url()`, which is what makes `port: 0` usable in tests.
pub async fn start(config : ServerConfig) -> ServerHandle {
  let server = bind(config)
  { server, config, }
}

///|
pub fn ServerHandle::addr(self : ServerHandle) -> @socket.Addr {
  self.server.addr
}

///|
pub fn ServerHandle::url(self : ServerHandle) -> String {
  "nats://" + self.server.addr.to_string()
}

///|
/// Serve until `stop()` is called or the surrounding task group is cancelled.
pub async fn ServerHandle::serve(self : ServerHandle) -> Unit {
  serve(self.server, self.config)
}

///|
pub fn ServerHandle::stop(self : ServerHandle) -> Unit {
  self.server.close()
}
