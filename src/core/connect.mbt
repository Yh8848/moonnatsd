///|
/// Errors returned when the `CONNECT` payload cannot be interpreted.
#derive(Debug, Eq)
pub(all) enum ConnectError {
  BadJson(String)
  NotAnObject
}

///|
/// The subset of NATS `CONNECT` options that affects server behavior.
///
/// Unknown fields are ignored on purpose: clients add new options over time and
/// a server must remain forward compatible.
pub(all) struct ConnectOptions {
  verbose : Bool
  pedantic : Bool
  echo : Bool
  headers : Bool
  no_responders : Bool
  protocol : Int32
  name : String?
  user : String?
  pass : String?
  auth_token : String?
}

///|
pub fn ConnectOptions::default() -> ConnectOptions {
  {
    verbose: false,
    pedantic: false,
    echo: true,
    headers: false,
    no_responders: false,
    protocol: 1,
    name: None,
    user: None,
    pass: None,
    auth_token: None,
  }
}

///|
fn json_bool(
  fields : Map[String, @json.Json],
  key : String,
  default : Bool,
) -> Bool {
  match fields.get(key) {
    Some(@json.Json::True) => true
    Some(@json.Json::False) => false
    _ => default
  }
}

///|
fn json_string(fields : Map[String, @json.Json], key : String) -> String? {
  match fields.get(key) {
    Some(@json.Json::String(value)) => Some(value)
    _ => None
  }
}

///|
fn json_int(fields : Map[String, @json.Json], key : String) -> Int32? {
  match fields.get(key) {
    Some(@json.Json::Number(value, ..)) => Some(value.to_int())
    _ => None
  }
}

///|
/// Parse the JSON object carried by `CONNECT`.
pub fn parse_connect(text : String) -> Result[ConnectOptions, ConnectError] {
  let value = @json.parse(text[:]) catch { _ => return Err(BadJson(text)) }
  match value {
    @json.Json::Object(fields) => {
      let defaults = ConnectOptions::default()
      Ok({
        verbose: json_bool(fields, "verbose", defaults.verbose),
        pedantic: json_bool(fields, "pedantic", defaults.pedantic),
        echo: json_bool(fields, "echo", defaults.echo),
        headers: json_bool(fields, "headers", defaults.headers),
        no_responders: json_bool(
          fields,
          "no_responders",
          defaults.no_responders,
        ),
        protocol: json_int(fields, "protocol").unwrap_or(defaults.protocol),
        name: json_string(fields, "name"),
        user: json_string(fields, "user"),
        pass: json_string(fields, "pass"),
        auth_token: json_string(fields, "auth_token"),
      })
    }
    _ => Err(NotAnObject)
  }
}

///|
/// True if the client asked for verbose acknowledgements (`+OK`).
pub fn ConnectOptions::is_verbose(self : ConnectOptions) -> Bool {
  self.verbose
}

///|
/// True if the client asked the server not to echo messages back to the same
/// connection.
pub fn ConnectOptions::no_echo(self : ConnectOptions) -> Bool {
  !self.echo
}
