# ADR-0001: A sans-IO protocol core

- Status: accepted
- Date: 2026-11-21

## Context

The server must parse NATS control lines and payloads, match subjects, and
select queue-group members. These behaviors are the most error-prone part of the
project and the hardest to test if they are entangled with sockets, timers, and
file descriptors.

MoonBit's native target requires a C toolchain, while `wasm-gc` does not. We want
the protocol tests to run everywhere, including in environments without a
native toolchain.

## Decision

Put the protocol model, parser, subject matching, and subscription registry in
`src/core`, with **no I/O**. The `src/server` package owns all sockets, timers,
and file system access, and calls into `core` through plain values.

## Consequences

- Protocol tests run on `wasm`, `wasm-gc`, `js`, and `native`.
- The server package stays small and can be swapped to a different transport.
- The core cannot call `read_line`; the server must supply complete lines and
  payloads. This is a small amount of adapter code and a large testability win.
- Any future WASM/browser build of the protocol core is free.
