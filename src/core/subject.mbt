///|
/// NATS subject matching.
///
/// - `*` matches exactly one token.
/// - `>` matches one or more trailing tokens and may only appear as the last
///   token of a pattern.
/// - Everything else is a literal, case-sensitive token.
pub fn subject_matches(pattern : String, subject : String) -> Bool {
  let p = pattern.split(".").to_array()
  let s = subject.split(".").to_array()
  let mut i = 0
  while i < p.length() {
    let token = p[i]
    if token == ">" {
      return i == p.length() - 1 && s.length() > i
    }
    if i >= s.length() {
      return false
    }
    if token != "*" && token != s[i] {
      return false
    }
    i = i + 1
  }
  i == s.length()
}

///|
/// Return true if the pattern is syntactically usable as a subscription
/// pattern. This rejects `>` in a non-final position and empty tokens.
pub fn valid_subject_pattern(pattern : String) -> Bool {
  if pattern.is_empty() {
    return false
  }
  let parts = pattern.split(".").to_array()
  let mut i = 0
  while i < parts.length() {
    let token = parts[i]
    if token.is_empty() {
      return false
    }
    if token == ">" && i != parts.length() - 1 {
      return false
    }
    i = i + 1
  }
  true
}
