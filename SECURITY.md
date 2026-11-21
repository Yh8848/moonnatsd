# Security policy

`moonnatsd` is an early-stage server. Do not expose it to untrusted networks
until the security section of the README says otherwise.

## Reporting a vulnerability

Open a private security advisory on GitHub, or contact the maintainer through
the repository. Please do not open a public issue for a suspected
vulnerability.

## Scope and threat model (v1)

- Authentication: token and user/password. Anonymous access is disabled by
  default when credentials are configured.
- Resource limits: `max_payload`, `max_control_line`, `max_connections`,
  per-connection pending budget.
- Parser: all input is treated as untrusted; malformed input must produce a
  protocol error, never a panic or out-of-bounds access.
- Storage: JetStream data is written under the configured store directory;
  path traversal outside that directory is rejected.
- Out of scope for v1: TLS termination, JWT/nkey, multi-tenancy, clustering.

## Disclosure

Once the project has releases, this file will list supported versions and the
disclosure timeline.
