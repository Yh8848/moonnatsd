///|
/// A protocol-level error. Parsing never panics: every malformed input maps to
/// one of these values.
#derive(Debug, Eq)
pub(all) enum ParseError {
  EmptyLine
  UnknownOp(String)
  BadArity(String)
  BadNumber(String)
  PayloadTooLarge(Int32)
}

///|
/// A client-to-server operation, decoded from one control line plus an
/// optional payload read by the caller (`server`).
#derive(Debug, Eq)
pub(all) enum ClientOp {
  /// `CONNECT <json>`
  Connect(String)
  Ping
  Pong
  /// `PUB <subject> [reply] <size>`
  Pub(String, String?, Int32)
  /// `HPUB <subject> [reply] <header_size> <total_size>`
  Hpub(String, String?, Int32, Int32)
  /// `SUB <subject> [queue] <sid>`
  Sub(String, String?, String)
  /// `UNSUB <sid> [max_msgs]`
  Unsub(String, Int32?)
}

///|
/// Parse a decimal non-negative integer without relying on the standard
/// library's error-raising parser, so the result is a plain `Option`.
fn parse_dec(view : StringView) -> Int32? {
  if view.is_empty() {
    return None
  }
  let mut n = 0
  for c in view {
    if !c.is_ascii_digit() {
      return None
    }
    n = n * 10 + (c.to_int() - 48)
  }
  Some(n)
}

///|
/// Split a control line into non-empty whitespace-separated tokens.
fn tokens(text : String) -> Array[StringView] {
  text.split(" ").filter(fn(part) { !part.is_empty() }).to_array()
}

///|
/// Parse one client control line (without the trailing CRLF).
///
/// `max_payload` is enforced for `PUB` so a peer cannot announce a payload
/// larger than the server is willing to buffer.
pub fn parse_client_line(
  line : String,
  max_payload : Int32,
) -> Result[ClientOp, ParseError] {
  let trimmed = line.trim()
  if trimmed.is_empty() {
    return Err(EmptyLine)
  }
  let text = trimmed.to_owned()
  if text == "PING" {
    return Ok(Ping)
  }
  if text == "PONG" {
    return Ok(Pong)
  }
  if text.has_prefix("CONNECT ") {
    return Ok(Connect(text.exact_view(start=8).to_owned()))
  }
  let parts = tokens(text)
  let op = parts[0].to_owned()
  if op == "PUB" {
    if parts.length() == 3 {
      let size = match parse_dec(parts[2]) {
        Some(n) => n
        None => return Err(BadNumber(parts[2].to_owned()))
      }
      if size > max_payload {
        return Err(PayloadTooLarge(size))
      }
      return Ok(Pub(parts[1].to_owned(), None, size))
    }
    if parts.length() == 4 {
      let size = match parse_dec(parts[3]) {
        Some(n) => n
        None => return Err(BadNumber(parts[3].to_owned()))
      }
      if size > max_payload {
        return Err(PayloadTooLarge(size))
      }
      return Ok(Pub(parts[1].to_owned(), Some(parts[2].to_owned()), size))
    }
    return Err(BadArity("PUB"))
  }
  if op == "HPUB" {
    if parts.length() == 4 {
      let header_size = match parse_dec(parts[2]) {
        Some(n) => n
        None => return Err(BadNumber(parts[2].to_owned()))
      }
      let total_size = match parse_dec(parts[3]) {
        Some(n) => n
        None => return Err(BadNumber(parts[3].to_owned()))
      }
      if total_size > max_payload {
        return Err(PayloadTooLarge(total_size))
      }
      return Ok(Hpub(parts[1].to_owned(), None, header_size, total_size))
    }
    if parts.length() == 5 {
      let header_size = match parse_dec(parts[3]) {
        Some(n) => n
        None => return Err(BadNumber(parts[3].to_owned()))
      }
      let total_size = match parse_dec(parts[4]) {
        Some(n) => n
        None => return Err(BadNumber(parts[4].to_owned()))
      }
      if total_size > max_payload {
        return Err(PayloadTooLarge(total_size))
      }
      return Ok(
        Hpub(
          parts[1].to_owned(),
          Some(parts[2].to_owned()),
          header_size,
          total_size,
        ),
      )
    }
    return Err(BadArity("HPUB"))
  }
  if op == "SUB" {
    if parts.length() == 3 {
      return Ok(Sub(parts[1].to_owned(), None, parts[2].to_owned()))
    }
    if parts.length() == 4 {
      return Ok(
        Sub(parts[1].to_owned(), Some(parts[2].to_owned()), parts[3].to_owned()),
      )
    }
    return Err(BadArity("SUB"))
  }
  if op == "UNSUB" {
    if parts.length() == 2 {
      return Ok(Unsub(parts[1].to_owned(), None))
    }
    if parts.length() == 3 {
      let max_msgs = match parse_dec(parts[2]) {
        Some(n) => n
        None => return Err(BadNumber(parts[2].to_owned()))
      }
      return Ok(Unsub(parts[1].to_owned(), Some(max_msgs)))
    }
    return Err(BadArity("UNSUB"))
  }
  Err(UnknownOp(op))
}

///|
/// Build the `INFO` line sent immediately after a client connects.
pub fn info_line(
  server_id : String,
  server_name : String,
  version : String,
  port : Int32,
  max_payload : Int32,
) -> String {
  "INFO {\"server_id\":\"\{server_id}\",\"server_name\":\"\{server_name}\",\"version\":\"\{version}\",\"proto\":1,\"go\":\"moonbit\",\"host\":\"0.0.0.0\",\"port\":\{port},\"headers\":true,\"max_payload\":\{max_payload},\"jetstream\":false}\r\n"
}

///|
/// Header for a `MSG` frame. The payload and trailing CRLF are written by the
/// server under the target connection's write lock.
pub fn msg_header(
  subject : String,
  sid : String,
  reply : String?,
  size : Int32,
) -> String {
  match reply {
    Some(reply) => "MSG \{subject} \{sid} \{reply} \{size}\r\n"
    None => "MSG \{subject} \{sid} \{size}\r\n"
  }
}

///|
/// Header for an `HMSG` frame (payload contains the header block plus body).
pub fn hmsg_header(
  subject : String,
  sid : String,
  reply : String?,
  header_size : Int32,
  total_size : Int32,
) -> String {
  match reply {
    Some(reply) =>
      "HMSG \{subject} \{sid} \{reply} \{header_size} \{total_size}\r\n"
    None => "HMSG \{subject} \{sid} \{header_size} \{total_size}\r\n"
  }
}
