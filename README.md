# moonnatsd

[![CI](https://github.com/Yh8848/moonnatsd/actions/workflows/ci.yml/badge.svg)](https://github.com/Yh8848/moonnatsd/actions/workflows/ci.yml)

NATS-compatible server with JetStream, written in MoonBit.

> **Status: core NATS server is working.** A client can connect, authenticate,
> `PING`/`PONG`, `SUB`, `PUB`/`HPUB`, and receive `MSG`/`HMSG`, including
> wildcard and queue-group subscriptions. The server enforces payload/control
> line/connection limits, serves `/varz`, `/connz`, `/subsz` and `/healthz`, and
> has a CLI with auth and monitoring flags. JetStream and KV are the next
> milestones. The plan and scope are tracked in
> [`docs/acceptance.md`](docs/acceptance.md).

## Why

NATS has 40+ client implementations but essentially one mature server
implementation (`nats-server`, Go). MoonBit has several NATS clients and codecs
but no server. `moonnatsd` is an independent, memory-safe reimplementation of
the server side, with a focus on:

- **Embeddability**: start a broker inside a MoonBit process, e.g. in tests,
  without Docker or a Go binary.
- **Verifiability**: the official `nats` CLI and client libraries are the
  acceptance suite; behavior is diffed against `nats-server`.
- **A clear boundary**: single node, core NATS + JetStream + KV. Clustering,
  leaf nodes, gateways, JWT/nkey accounts and multi-tenancy are explicitly out
  of scope for v1.

## Implemented today

- **Protocol core** (`src/core`): `INFO`, `CONNECT`, `PING`, `PONG`, `PUB`,
  `HPUB`, `SUB`, `UNSUB`, `MSG`, `HMSG`, `+OK`, `-ERR`; `NATS/1.0` header block
  parser; `CONNECT` JSON options; token and user/password auth.
- **Subject trie**: `*` and `>` matching, queue-group round-robin, in-place
  removal, node counting.
- **Server runtime** (`src/server`): one task per connection, a per-connection
  outbox so frames never interleave, bounded control line/payload, structured
  shutdown, connection and byte counters.
- **Monitoring**: `/varz`, `/connz`, `/subsz`, `/healthz` JSON over HTTP.
- **CLI** (`src/cli`): `--host`, `--port`, `--max-payload`,
  `--max-control-line`, `--max-connections`, `--server-name`, `--token`,
  `--user`, `--pass`, `--monitor-port`, `--help`, `--version`.

## Scope

| Area | v1 |
|---|---|
| Core NATS | protocol listed above, headers, wildcards, queue groups, auth, limits, monitoring |
| JetStream | single-node streams, retention, dedupe, push/pull consumers, ACK/NAK/WPI/TERM, KV (next) |
| Interfaces | `moonnatsd` CLI, JSON status, monitoring endpoints |
| Out of scope | clustering/Raft, leaf nodes, gateways, JWT/nkey, multi-tenancy, mirrors/sources, object store, encryption at rest |

## Quickstart

Requires the MoonBit toolchain. On Windows, the MoonBit native runtime requires
MSVC (MinGW is not supported by the runtime).

```bash
moon check --deny-warn
moon test --target wasm-gc     # pure core, no native toolchain required
moon test --target native      # protocol, auth and TCP integration tests
moon run cmd/moonnatsd         # listens on 127.0.0.1:4222
```

With authentication and monitoring:

```bash
moon run cmd/moonnatsd -- --token secret --monitor-port 8222
curl -s http://127.0.0.1:8222/varz
nats -s nats://127.0.0.1:4222 --auth-token secret pub hello world
```

In another terminal, with the official [`nats` CLI](https://github.com/nats-io/natscli):

```bash
nats -s nats://127.0.0.1:4222 sub hello
nats -s nats://127.0.0.1:4222 pub hello world
```

## Architecture

```
src/core      pure protocol model, header/CONNECT parsing, subject trie, stats
src/server    native listener/connection runtime, auth, monitoring
src/store     WAL/block storage and recovery (planned)
src/jetstream stream/consumer state machines (planned)
src/kv        KV facade over JetStream (planned)
src/cli       argument parsing and command line
```

Design notes live in [`docs/architecture.md`](docs/architecture.md) and
[`docs/adr/`](docs/adr/). The supported protocol surface and known differences
are tracked in [`docs/compatibility.md`](docs/compatibility.md).

## Project size

At the 0.2.0 checkpoint the repository contains roughly 1,200 non-comment,
non-test lines of MoonBit source and 45 tests. Exact counts and the counting
method are recorded in [`docs/metrics.md`](docs/metrics.md).

## References and license

This is an independent reimplementation based on the public NATS protocol
documentation and the NATS architecture decision records. It is **not**
affiliated with or endorsed by the NATS project. The reference server
[`nats-server`](https://github.com/nats-io/nats-server) is Apache-2.0; see
[`NOTICE`](NOTICE) for the exact reference scope.

Licensed under [Apache-2.0](LICENSE).
