///|
/// Command-line entry point for moonnatsd.
pub async fn run() -> Unit {
  match parse_args(@env.args()) {
    Ok(options) =>
      if options.help {
        print_help()
      } else if options.version {
        println("moonnatsd \{@core.version()}")
      } else {
        @server.run(options.config)
      }
    Err(message) => {
      println("error: \{message}")
      println("run `moonnatsd --help` for usage")
      @env.exit(2)
    }
  }
}
