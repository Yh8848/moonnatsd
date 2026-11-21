# Contributing

## Development environment

- MoonBit toolchain (see `moon version`; the CI matrix pins a known-good version)
- Git
- For native tests: a C toolchain. On Windows, MSVC is required by the MoonBit
  runtime; MinGW is not supported by the runtime's Windows code paths.

## Commands

```bash
moon check --deny-warn
moon fmt --check
moon test --target wasm-gc   # pure core, no native toolchain required
moon test --target native    # requires a native C toolchain
moon info && moon fmt        # before committing public API changes
```

## Code style

- MoonBit blocks are separated by `///|`; keep blocks small and focused.
- Public APIs have doc comments.
- No `panic` on network input: return typed errors.
- Do not write BOMs. `moon.mod` with a BOM fails with `Lexing error at 0..3`.
  On Windows, use an editor that writes UTF-8 without BOM, or
  `[IO.File]::WriteAllText(path, text, (New-Object Text.UTF8Encoding($false)))`.

## Commit convention

Conventional Commits:

- `feat(scope): ...` new behavior
- `fix(scope): ...` bug fix
- `test(scope): ...` tests only
- `docs: ...` documentation
- `refactor(scope): ...` no behavior change
- `chore: ...` tooling, metadata

One logical change per commit. Do not split commits to inflate the count, and do
not commit generated `_build/` output.

## Pull requests

Even for solo work, use a branch and a PR for non-trivial changes. The PR
description should state:

- what changed and why;
- how it was tested;
- what is explicitly out of scope.

CI must be green before merge.
