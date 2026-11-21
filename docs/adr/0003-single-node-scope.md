# ADR-0003: Single node is the v1 boundary

- Status: accepted
- Date: 2026-11-21

## Context

NATS supports clustering, leaf nodes, gateways, JWT/nkey accounts, multi-tenancy,
mirrors, sources, and an object store. Implementing all of that would turn a
focused protocol server into a multi-year distributed-systems project and would
make the "complete, runnable, reproducible" acceptance bar harder to clear.

## Decision

v1 is a **single-node** server with core NATS, JetStream streams/consumers, and
KV. The following are explicitly out of scope for v1 and documented in the
README:

- clustering / Raft
- leaf nodes and gateways
- JWT/nkey accounts and multi-tenancy
- mirrors / sources / republish
- object store
- encryption at rest
- snapshot / restore

Clustering may be revisited in v2 on top of `moonbitstack/moonraft`, but it is
not part of the acceptance scope.

## Consequences

- The acceptance claim matches what is actually implemented.
- Reviewers can verify a clear boundary instead of guessing which features are
  half-finished.
- The internal interfaces (`store`, `jetstream`) are still designed so that a
  future replicated log can be added without rewriting the protocol layer.
