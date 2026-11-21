# Acceptance checklist

This file maps the competition requirements to concrete evidence. It is updated
as the project progresses; an unchecked item is not claimed as done.

Status: **in progress** (initial-review checkpoint).

| Requirement | Evidence | Status |
|---|---|---|
| MoonBit is the primary implementation language | repository source tree; no C/JS implementation of the protocol | ✅ |
| Public GitHub repository | https://github.com/Yh8848/moonnatsd | ⏳ (currently private; to be public before submission) |
| At least 10 meaningful commits | `git log --oneline` | ⏳ |
| README: goal, install, usage, examples, reproducible | `README.md`, `docs/`, `examples/` | ⏳ (quickstart will be finalized with the working server) |
| CI covers check, build, test | `.github/workflows/ci.yml` + passing runs | ⏳ |
| At least one runnable example | `examples/pubsub` | ⏳ |
| Tests cover the core paths | unit + golden + interop tests | ⏳ |
| Published to mooncakes.io | `Yh8848/moonnatsd` package page | ⏳ (0.1.0 planned) |
| OSI license | Apache-2.0 `LICENSE` | ✅ |
| Reference/porting attribution | `NOTICE`, README "References" | ✅ |
| Declared core features implemented | scope matrix in README + this file | ⏳ |

## How each item will be verified

- **Build/test**: three-OS GitHub Actions matrix; commands are in the workflow.
- **Protocol**: official `nats` CLI pub/sub and JetStream commands, plus
  `nats.go`/`nats.py` integration subsets.
- **Persistence**: `kill -9` during publish, restart, verify no ACKed message is
  lost and sequence numbers remain monotonic.
- **Compatibility**: `docs/compatibility.md` lists supported operations and
  known differences from `nats-server`.
- **Reproducibility**: README quickstart is copied verbatim into CI.
