# Compatibility

This document records the supported NATS surface and the known differences from
`nats-server`. It is intentionally conservative: an operation is listed as
supported only after a test exercises it.

## Core protocol

| Operation | Status | Notes |
|---|---|---|
| `INFO` | ✅ | sent on connect; fields: `server_id`, `server_name`, `version`, `proto`, `go`, `host`, `port`, `headers`, `max_payload`, `jetstream` |
| `CONNECT` | ✅ | accepted; JSON is currently not interpreted beyond framing |
| `PING` / `PONG` | ✅ | |
| `PUB` | ✅ | subject, optional reply, size limit enforced |
| `HPUB` | ✅ | header block is forwarded as `HMSG`; header semantics (KV/ack) pending |
| `SUB` | ✅ | plain, wildcard (`*`, `>`), queue group |
| `UNSUB` | ✅ | `max_msgs` parsed but not yet enforced |
| `MSG` | ✅ | |
| `HMSG` | ✅ | |
| `+OK` | ⏳ | not sent yet (only relevant with `verbose`) |
| `-ERR` | ✅ | parser/limit errors |

## Connection behavior

| Behavior | Status |
|---|---|
| `max_payload` enforcement | ✅ |
| `max_control_line` enforcement | ⏳ |
| token / user+pass authentication | ⏳ |
| slow-consumer disconnect | ⏳ |
| monitoring `/varz` `/connz` `/subsz` `/healthz` | ⏳ |

## JetStream / KV

Not implemented yet. The plan is single-node streams, retention, dedupe,
push/pull consumers, ACK/NAK/WPI/TERM and KV; see `docs/acceptance.md`.

## Known differences

- The server currently binds to `127.0.0.1` only; `host` in `ServerConfig` is
  reserved for the listener refactor.
- `CONNECT` options (`verbose`, `pedantic`, `echo`, auth fields) are parsed by
  the framing layer but not yet applied.
- No TLS, WebSocket or clustering.

These gaps are explicit; an operation is never claimed as supported merely
because a client can send it.
