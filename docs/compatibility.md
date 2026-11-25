# Compatibility

This document records the supported NATS surface and the known differences from
`nats-server`. It is intentionally conservative: an operation is listed as
supported only after a test exercises it.

Status values: `yes`, `partial`, `no`.

## Core protocol

| Operation | Status | Notes |
|---|---|---|
| `INFO` | yes | fields: `server_id`, `server_name`, `version`, `proto`, `go`, `host`, `port`, `headers`, `max_payload`, `jetstream` |
| `CONNECT` | yes | JSON parsed; `auth_token`, `user`, `pass`, `name` applied |
| `PING` / `PONG` | yes | |
| `PUB` | yes | subject, optional reply, size limit enforced |
| `HPUB` | yes | header block size validated; delivered as `HMSG`; KV/ack headers are not interpreted yet |
| `SUB` | yes | plain, wildcard (`*`, `>`), queue group |
| `UNSUB` | partial | `sid` removed; `max_msgs` parsed but not enforced |
| `MSG` | yes | |
| `HMSG` | yes | |
| `+OK` | partial | not sent yet (only relevant with `verbose`) |
| `-ERR` | yes | parser/limit/auth errors |

## Connection behavior

| Behavior | Status | Notes |
|---|---|---|
| `max_payload` enforcement | yes | default 1 MiB |
| `max_control_line` enforcement | yes | default 1024 bytes; exceeding it closes the connection |
| token authentication | yes | `--token` / `AuthConfig::Token` |
| user/password authentication | yes | `--user` + `--pass` / `AuthConfig::UserPass` |
| connection limit | yes | passed to `TcpServer::run_forever` |
| slow-consumer disconnect | partial | bounded outbox is planned; current queue is unbounded |
| monitoring `/varz` `/connz` `/subsz` `/healthz` | yes | JSON over HTTP on `--monitor-port` |

## JetStream / KV

Not implemented yet. The plan is single-node streams, retention, dedupe,
push/pull consumers, ACK/NAK/WPI/TERM and KV; see `docs/acceptance.md`.

## Known differences

- The listener still binds to `127.0.0.1`; `ServerConfig.host` is accepted by
  the CLI but the listener refactor is pending.
- `CONNECT` options such as `verbose`, `pedantic` and `no_responders` are parsed
  but only `auth_token` / `user` / `pass` / `name` affect behavior today.
- `HPUB` header blocks are validated but not interpreted for JetStream/KV
  semantics.
- No TLS, WebSocket or clustering.

These gaps are explicit; an operation is never claimed as supported merely
because a client can send it.
