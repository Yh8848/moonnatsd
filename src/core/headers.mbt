///|
/// Errors returned when a `NATS/1.0` header block is malformed.
#derive(Debug, Eq)
pub(all) enum HeaderError {
  MissingVersion
  BadVersion(String)
  MissingColon(String)
  EmptyKey
}

///|
/// A parsed NATS header block.
///
/// The status line is kept separately because `no_responders` and JetStream
/// advisory messages use it (`NATS/1.0 503 No Responders`).
pub(all) struct Header {
  mut status : String?
  values : Array[(String, String)]
}

///|
pub fn Header::new() -> Header {
  { status: None, values: [], }
}

///|
/// Case-insensitive lookup, matching NATS header semantics.
pub fn Header::get(self : Header, name : String) -> String? {
  for entry in self.values {
    let (key, value) = entry
    if key.equal_ignore_ascii_case(name) {
      return Some(value)
    }
  }
  None
}

///|
/// Insert or replace a header value.
pub fn Header::set(self : Header, name : String, value : String) -> Unit {
  let mut i = 0
  let mut found = false
  while i < self.values.length() {
    let (key, _) = self.values[i]
    if key.equal_ignore_ascii_case(name) {
      self.values[i] = (name, value)
      found = true
      break
    }
    i = i + 1
  }
  if !found {
    self.values.push((name, value))
  }
}

///|
/// Remove a header value, if present.
pub fn Header::remove(self : Header, name : String) -> Unit {
  let mut i = 0
  while i < self.values.length() {
    let (key, _) = self.values[i]
    if key.equal_ignore_ascii_case(name) {
      let _ = self.values.remove(i)
    } else {
      i = i + 1
    }
  }
}

///|
/// Serialize back to wire format, including the terminating blank line.
pub fn Header::to_string(self : Header) -> String {
  let mut out = "NATS/1.0"
  match self.status {
    Some(status) => out = out + " " + status
    None => ()
  }
  out = out + "\r\n"
  for entry in self.values {
    let (key, value) = entry
    out = out + key + ": " + value + "\r\n"
  }
  out + "\r\n"
}

///|
/// Parse a complete header block (the portion covered by `header_size` in
/// `HPUB`). The trailing blank line is required by the wire format.
pub fn parse_header_block(text : String) -> Result[Header, HeaderError] {
  let lines = text.split("\r\n").to_array()
  if lines.length() == 0 || lines[0].is_empty() {
    return Err(MissingVersion)
  }
  let first = lines[0].to_owned()
  if !first.has_prefix("NATS/1.0") {
    return Err(BadVersion(first))
  }
  let status = if first == "NATS/1.0" {
    None
  } else {
    Some(first.exact_view(start=9).to_owned().trim().to_owned())
  }
  let header : Header = { status, values: [], }
  let mut i = 1
  while i < lines.length() {
    let line = lines[i].to_owned()
    if line.is_empty() {
      break
    }
    match line.find(":") {
      Some(index) => {
        let key = line[:index].trim().to_owned()
        let value = line[index + 1:].trim().to_owned()
        if key.is_empty() {
          return Err(EmptyKey)
        }
        header.set(key, value)
      }
      None => return Err(MissingColon(line))
    }
    i = i + 1
  }
  Ok(header)
}

///|
/// Return the header block size for an `HPUB` frame. The size includes the
/// `NATS/1.0` line, all header lines, and the final blank line.
pub fn header_size(header : Header) -> Int32 {
  header.to_string().length()
}
