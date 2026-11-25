///|
/// Parsed command-line options. `help` and `version` are handled before the
/// server starts; `config` is passed to `@server.run`.
pub(all) struct CliOptions {
  config : @server.ServerConfig
  help : Bool
  version : Bool
}

///|
fn parse_int_arg(value : String, flag : String) -> Result[Int32, String] {
  let parsed = @string.parse_int(value[:]) catch {
    _ => return Err("invalid value for \{flag}: \{value}")
  }
  Ok(parsed)
}

///|
fn expect_value(
  args : Array[String],
  index : Int32,
  flag : String,
) -> Result[String, String] {
  if index + 1 >= args.length() {
    return Err("missing value for \{flag}")
  }
  Ok(args[index + 1])
}

///|
/// Parse `argv` (including the program name at index 0).
///
/// Supported flags:
/// `--host`, `--port`, `--max-payload`, `--max-control-line`,
/// `--max-connections`, `--server-name`, `--token`, `--user`, `--pass`,
/// `--monitor-port`, `--help`, `--version`.
pub fn parse_args(args : Array[String]) -> Result[CliOptions, String] {
  let defaults = @server.ServerConfig::new()
  let mut host = defaults.host
  let mut port = defaults.port
  let mut max_payload = defaults.max_payload
  let mut max_control_line = defaults.max_control_line
  let mut max_connections = defaults.max_connections
  let mut server_name = defaults.server_name
  let mut monitor_port : Int32? = None
  let mut token : String? = None
  let mut user : String? = None
  let mut pass : String? = None
  let mut help = false
  let mut version = false
  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    if arg == "--help" || arg == "-h" {
      help = true
    } else if arg == "--version" || arg == "-V" {
      version = true
    } else if arg == "--host" {
      match expect_value(args, i, arg) {
        Ok(value) => host = value
        Err(error) => return Err(error)
      }
      i = i + 1
    } else if arg == "--port" {
      match expect_value(args, i, arg) {
        Ok(value) =>
          match parse_int_arg(value, arg) {
            Ok(number) => {
              if number < 0 || number > 65535 {
                return Err("port out of range: \{number}")
              }
              port = number
            }
            Err(error) => return Err(error)
          }
        Err(error) => return Err(error)
      }
      i = i + 1
    } else if arg == "--max-payload" {
      match expect_value(args, i, arg) {
        Ok(value) =>
          match parse_int_arg(value, arg) {
            Ok(number) => max_payload = number
            Err(error) => return Err(error)
          }
        Err(error) => return Err(error)
      }
      i = i + 1
    } else if arg == "--max-control-line" {
      match expect_value(args, i, arg) {
        Ok(value) =>
          match parse_int_arg(value, arg) {
            Ok(number) => max_control_line = number
            Err(error) => return Err(error)
          }
        Err(error) => return Err(error)
      }
      i = i + 1
    } else if arg == "--max-connections" {
      match expect_value(args, i, arg) {
        Ok(value) =>
          match parse_int_arg(value, arg) {
            Ok(number) => max_connections = number
            Err(error) => return Err(error)
          }
        Err(error) => return Err(error)
      }
      i = i + 1
    } else if arg == "--server-name" {
      match expect_value(args, i, arg) {
        Ok(value) => server_name = value
        Err(error) => return Err(error)
      }
      i = i + 1
    } else if arg == "--monitor-port" {
      match expect_value(args, i, arg) {
        Ok(value) =>
          match parse_int_arg(value, arg) {
            Ok(number) => monitor_port = Some(number)
            Err(error) => return Err(error)
          }
        Err(error) => return Err(error)
      }
      i = i + 1
    } else if arg == "--token" {
      match expect_value(args, i, arg) {
        Ok(value) => token = Some(value)
        Err(error) => return Err(error)
      }
      i = i + 1
    } else if arg == "--user" {
      match expect_value(args, i, arg) {
        Ok(value) => user = Some(value)
        Err(error) => return Err(error)
      }
      i = i + 1
    } else if arg == "--pass" {
      match expect_value(args, i, arg) {
        Ok(value) => pass = Some(value)
        Err(error) => return Err(error)
      }
      i = i + 1
    } else {
      return Err("unknown argument: \{arg}")
    }
    i = i + 1
  }
  let auth = match (token, user, pass) {
    (Some(value), _, _) => Some(@server.AuthConfig::Token(value))
    (None, Some(name), Some(secret)) =>
      Some(@server.AuthConfig::UserPass(name, secret))
    (None, Some(name), None) =>
      return Err("--user without --pass is not allowed (user: \{name})")
    (None, None, Some(_)) => return Err("--pass without --user is not allowed")
    (None, None, None) => None
  }
  let config : @server.ServerConfig = {
    host,
    port,
    max_payload,
    max_control_line,
    max_connections,
    server_name,
    auth,
    monitor_port,
  }
  Ok({ config, help, version, })
}

///|
pub fn print_help() -> Unit {
  println("moonnatsd - NATS-compatible server with JetStream (MoonBit)")
  println("")
  println("Usage: moonnatsd [options]")
  println("")
  println("  --host <addr>             bind address (default 127.0.0.1)")
  println("  --port <port>             client port (default 4222)")
  println("  --max-payload <bytes>     maximum PUB payload (default 1048576)")
  println(
    "  --max-control-line <n>    maximum control line length (default 1024)",
  )
  println(
    "  --max-connections <n>     maximum concurrent clients (default 1024)",
  )
  println("  --server-name <name>      name advertised in INFO")
  println("  --monitor-port <port>     enable /varz /connz /subsz /healthz")
  println("  --token <token>           require a token in CONNECT")
  println("  --user <user> --pass <p>  require user/password in CONNECT")
  println("  -h, --help                show this help")
  println("  -V, --version             show the version")
}
