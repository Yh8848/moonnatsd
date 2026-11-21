# Architecture

`moonnatsd` is a single-node NATS-compatible server. The design is deliberately
split into a pure protocol core and a thin native runtime, so that most behavior
can be tested on every MoonBit backend and the socket layer stays small.

## Layers

```
┌─────────────────────────────────────────────┐
│ cli/ (moonnatsd)      monitor/ (HTTP JSON)  │
├─────────────────────────────────────────────┤
│ server/  native listener, connections,      │
│          auth, limits, backpressure         │
├─────────────────────────────────────────────┤
│ core/    sans-IO protocol model, parser,    │
│          subject trie, subscription registry │
├─────────────────────────────────────────────┤
│ jetstream/  stream/consumer state machines  │
│ store/      WAL/block files, recovery       │
│ kv/         KV facade over JetStream        │
├─────────────────────────────────────────────┤
│ config/  TOML parsing and validation        │
└─────────────────────────────────────────────┘
```

### `core` is sans-IO

`core` contains no sockets, timers, or file system access. It exposes:

- typed client/server operations and their wire encoding;
- an incremental control-line parser;
- subject matching (`*` and `>`) and queue-group selection;
- a subscription registry that is independent of connection objects.

This makes the protocol deterministic and testable with plain unit tests,
including on `wasm-gc`, where no native toolchain is required.

### `server` is the only async package

`server` owns:

- the TCP listener (`moonbitlang/async/socket`);
- one task per connection, wrapped in a structured task group;
- the read loop (control line, then payload for `PUB`/`HPUB`);
- authentication and connection limits;
- a per-connection write mutex, so concurrent publishers cannot interleave
  frames on the same socket;
- cleanup on disconnect or cancellation.

A connection is represented by a `Connection` value containing the socket, the
write mutex, and its subscription IDs. The server keeps a registry of live
connections and subscriptions.

### Delivery path

```
client A ──PUB──▶ server read loop
                     │
                     ├─ core: validate subject, size, permissions
                     ├─ core: match subscriptions (wildcards + queue groups)
                     └─ for each target connection:
                            acquire write mutex
                            write MSG/HMSG frame
                            release
```

Publishing never blocks on a slow subscriber indefinitely: each connection has
a bounded outbound budget. When the budget is exceeded the connection is closed
with `-ERR 'Slow Consumer'`.

### Storage (planned)

JetStream storage is append-only block files plus a subject index. Recovery
truncates a torn trailing record and rebuilds the in-memory index from the
surviving records. The exact format and fsync policy are documented in
`docs/storage.md` and ADR-0002 when that layer lands.

### Error model

- Protocol errors are typed (`ParseError`), never panics.
- Network EOF is a normal condition (`read_until` returns `None`).
- Storage errors are typed (`StoreError`) and surfaced to the client as
  `-ERR` where the protocol allows it.
- Internal invariant violations may abort, but are covered by tests and fuzzing.

## Concurrency model

MoonBit native is single-threaded at the language level; `moonbitlang/async`
provides cooperative multitasking on one core. Therefore:

- All state is shared within one process without locks, except at `await`
  points where another task may run.
- Writes to a socket are serialized with a per-connection `@async.Mutex`.
- Long CPU work must yield; the protocol core is designed to be O(payload) and
  allocation-light.
- Multi-core scaling is a deployment concern: multiple processes with
  `reuse_port_lb` on Linux (a v2 topic), not threads.

## Testing strategy

- **Unit tests** for the pure core, run on `wasm-gc` and native.
- **Golden transcripts** recorded from `nats-server` and replayed against the
  parser/serializer.
- **Interop tests** with the official `nats` CLI, `nats.go` and `nats.py`.
- **Crash tests** for the JetStream store (`kill -9`, restart, invariants).
- **Fuzzing** for the parser, headers and JetStream JSON.
- **Benchmarks** for core pub/sub and JetStream publish/consume.

See `docs/acceptance.md` for the mapping between the competition requirements
and the evidence produced by these tests.
