# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.3.0] - 2026-11-25

### Added

- Embedded `ServerHandle` API: `start`, `addr`, `url`, `serve`, `stop`
  (`src/server/handle.mbt`); port 0 gives a test-friendly ephemeral port.
- No-responders 503: a request with no matching subscriber receives a
  `NATS/1.0 503` header on its reply subject when the client opts in.
- Bounded per-connection outbox (4096 frames); a full outbox closes the
  slow-consumer socket instead of growing memory without bound.
- Integration tests for the embedded handle and no-responders behavior.

### Changed

- Delivery and status frames use non-blocking enqueue; slow consumers are
  disconnected rather than blocking the publisher.

## [0.2.0] - 2026-11-25

### Added

- NATS/1.0 header block parser and serializer (`src/core/headers.mbt`).
- `CONNECT` JSON option parser (`src/core/connect.mbt`).
- Subject trie with wildcard, tail and queue-group matching
  (`src/core/trie.mbt`), replacing the linear subscription scan.
- Server counters (`src/core/stats.mbt`) and `/varz`, `/connz`, `/subsz`,
  `/healthz` monitoring endpoints (`src/server/monitor.mbt`).
- Token and user/password authentication, control-line and connection limits.
- CLI argument parsing: host/port/payload/limits/auth/monitor/help/version
  (`src/cli/args.mbt`).
- Source-line counter (`scripts/count_source_lines.py`) and
  `docs/metrics.md`.

### Changed

- `Registry` is now a thin facade over `SubjectTrie`.
- Connection writer drains queued frames before closing, so `-ERR` is visible
  to the client.

### Fixed

- Authentication failures now send `-ERR 'Authorization Violation'` before the
  socket closes.

## [0.1.0] - 2026-11-21

### Added

- Initial MoonBit module layout, Apache-2.0 license, README, architecture notes
  and ADRs.
- Core NATS protocol parser, subject matching, queue groups and a native TCP
  server with `PUB`/`SUB`/`PING`/`PONG`.
- Three-OS CI matrix and official `nats` CLI pub/sub interop job.

[Unreleased]: https://github.com/Yh8848/moonnatsd/commits/main
[0.2.0]: https://github.com/Yh8848/moonnatsd/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Yh8848/moonnatsd/releases/tag/v0.1.0
