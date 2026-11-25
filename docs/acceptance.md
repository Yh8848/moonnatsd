# Acceptance checklist

This file maps the competition requirements to concrete evidence. It is updated
as the project progresses; an unchecked item is not claimed as done.

Status: **resubmission checkpoint (0.2.0)**. Core NATS, authentication,
limits, monitoring and the CLI are implemented; JetStream/KV are the next
milestone.

| Requirement | Evidence | Status |
|---|---|---|
| MoonBit is the primary implementation language | protocol/server/CLI code is MoonBit | done |
| Effective MoonBit source volume | 1,249 non-comment, non-test lines; method and per-file counts in `docs/metrics.md`; reproduce with `python3 scripts/count_source_lines.py` | done |
| Public GitHub repository | https://github.com/Yh8848/moonnatsd | done |
| At least 10 meaningful commits | `git log --oneline` (29+ at this checkpoint) | done |
| README: goal, install, usage, examples, reproducible | `README.md` quickstart; CI runs the same commands | done |
| CI covers check, build, test | `.github/workflows/ci.yml`, green on Ubuntu/macOS/Windows | done |
| At least one runnable example | README quickstart with `nats` CLI; a dedicated `examples/` directory follows with JetStream | pending |
| Tests cover the core paths | 45 tests: core parser/trie/headers/CONNECT/stats, server auth and pub/sub, CLI args | done |
| Official nats CLI interop | `interop` job: `nats sub` / `nats pub` against `moonnatsd` | done |
| Published to mooncakes.io | `Yh8848/moonnatsd@0.2.0` (build checked by the registry) | done |
| OSI license | Apache-2.0 `LICENSE` | done |
| Reference/porting attribution | `NOTICE`, README "References" | done |
| Declared core features implemented | core NATS, auth, limits, monitoring, CLI done; JetStream/KV pending | pending |

## How each item is verified

- **Build/test**: three-OS GitHub Actions matrix; commands are in the workflow.
- **Protocol**: parser unit tests, subject-trie tests, TCP integration tests in
  `src/server/server_wbtest.mbt`, and the official `nats` CLI job.
- **Source volume**: `docs/metrics.md` + `scripts/count_source_lines.py` report
  raw / code / source / test lines separately, so the conservative number can
  be reproduced.
- **Persistence**: `kill -9` during publish, restart, verify no ACKed message is
  lost and sequence numbers remain monotonic (JetStream milestone).
- **Compatibility**: `docs/compatibility.md` lists supported operations and
  known differences from `nats-server`.
- **Reproducibility**: README quickstart is copied verbatim into CI.
