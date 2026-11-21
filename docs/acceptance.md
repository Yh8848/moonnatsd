# Acceptance checklist

This file maps the competition requirements to concrete evidence. It is updated
as the project progresses; an unchecked item is not claimed as done.

Status: **initial-review checkpoint** (core protocol + minimal native server;
JetStream/KV not yet implemented).

| Requirement | Evidence | Status |
|---|---|---|
| MoonBit is the primary implementation language | repository source tree; the protocol/server code is MoonBit | 鉁?|
| Public GitHub repository | https://github.com/Yh8848/moonnatsd | 鉁?|
| At least 10 meaningful commits | `git log --oneline` (20+ at this checkpoint) | 鉁?|
| README: goal, install, usage, examples, reproducible | `README.md` quickstart; CI runs the same commands | 鉁?|
| CI covers check, build, test | `.github/workflows/ci.yml`, green on Ubuntu/macOS/Windows | 鉁?|
| At least one runnable example | README quickstart; a dedicated `examples/` directory follows with JetStream | 鈴?|
| Tests cover the core paths | 13 core tests + 2 TCP integration tests + official `nats` CLI pub/sub in CI | 鉁?|
| Official nats CLI interop | `interop` job: `nats sub` / `nats pub` against `moonnatsd` | 鉁?|
| Published to mooncakes.io | [`Yh8848/moonnatsd@0.1.0`](https://mooncakes.io/docs/Yh8848/moonnatsd) (build: success) | 鉁?|
| OSI license | Apache-2.0 `LICENSE` | 鉁?|
| Reference/porting attribution | `NOTICE`, README "References" | 鉁?|
| Declared core features implemented | core NATS done; JetStream/KV pending | 鈴?|

## How each item is verified

- **Build/test**: three-OS GitHub Actions matrix; commands are in the workflow.
- **Protocol**: parser unit tests, TCP integration tests (`src/server/server_wbtest.mbt`),
  and later the official `nats` CLI.
- **Persistence**: `kill -9` during publish, restart, verify no ACKed message is
  lost and sequence numbers remain monotonic (JetStream milestone).
- **Compatibility**: `docs/compatibility.md` lists supported operations and
  known differences from `nats-server`.
- **Reproducibility**: README quickstart is copied verbatim into CI.
