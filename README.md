# moonnatsd

[![CI](https://github.com/Yh8848/moonnatsd/actions/workflows/ci.yml/badge.svg)](https://github.com/Yh8848/moonnatsd/actions/workflows/ci.yml)

NATS-compatible server with JetStream, written in MoonBit.

> **Status: early development.** The protocol core and a minimal native server
> are working: a client can connect, `PING`/`PONG`, `SUB`, `PUB`, and receive
> `MSG` frames, including wildcard and queue-group subscriptions. JetStream,
> KV, monitoring and the `nats` CLI acceptance script are the next milestones.
> The plan and scope are tracked in [`docs/acceptance.md`](docs/acceptance.md).

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

## Scope

| Area | v1 |
|---|---|
| Core NATS | `INFO/CONNECT/PUB/HPUB/SUB/UNSUB/MSG/HMSG/PING/PONG/+OK/-ERR`, headers, wildcards, queue groups, request/reply, `no_responders`, auth, limits, monitoring |
| JetStream | single-node streams, retention, dedupe, push/pull consumers, ACK/NAK/WPI/TERM, KV |
| Interfaces | `moonnatsd` CLI, embedded `@natsd.start(...)`, JSON status, monitoring endpoints |
| Out of scope | clustering/Raft, leaf nodes, gateways, JWT/nkey, multi-tenancy, mirrors/sources, object store, encryption at rest |

## Quickstart

Requires the MoonBit toolchain. On Windows, the MoonBit native runtime requires
MSVC (MinGW is not supported by the runtime).

```bash
moon check --deny-warn
moon test --target wasm-gc     # pure core, no native toolchain required
moon test --target native      # protocol + TCP integration tests
moon run cmd/moonnatsd         # listens on 127.0.0.1:4222
```

In another terminal, with the official [`nats` CLI](https://github.com/nats-io/natscli):

```bash
nats -s nats://127.0.0.1:4222 sub hello
nats -s nats://127.0.0.1:4222 pub hello world
```

## Architecture

```
src/core      pure protocol model, parser, subject trie, delivery (no I/O)
src/server    native listener/connection runtime (async)
src/store     WAL/block storage and recovery (planned)
src/jetstream stream/consumer state machines (planned)
src/kv        KV facade over JetStream (planned)
src/cli       command line and embedded API
```

Design notes live in [`docs/architecture.md`](docs/architecture.md) and
[`docs/adr/`](docs/adr/). The supported protocol surface and known differences
are tracked in [`docs/compatibility.md`](docs/compatibility.md).

## References and license

This is an independent reimplementation based on the public NATS protocol
documentation and the NATS architecture decision records. It is **not**
affiliated with or endorsed by the NATS project. The reference server
[`nats-server`](https://github.com/nats-io/nats-server) is Apache-2.0; see
[`NOTICE`](NOTICE) for the exact reference scope.

Licensed under [Apache-2.0](LICENSE).
