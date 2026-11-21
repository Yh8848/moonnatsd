///|
/// Command-line entry point for moonnatsd.
pub async fn run() -> Unit {
  let config = @server.ServerConfig::new()
  @server.run(config)
}
