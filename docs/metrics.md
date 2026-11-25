# Source metrics

The competition requires evidence of effective MoonBit source volume. This page
records the counting method and the numbers at each release so the claim can be
checked instead of guessed.

## Method

`scripts/count_source_lines.py` counts every `.mbt` file tracked by the
repository (skipping `.git`, `_build`, `.mooncakes`, `target`) and reports:

- **raw**: every line in every `.mbt` file;
- **code**: non-blank lines that do not start with `//`;
- **source**: `code` excluding `*_test.mbt` / `*_wbtest.mbt`;
- **test**: `code` in test files.

Run it from the repository root:

```bash
python3 scripts/count_source_lines.py
```

## 0.2.0 checkpoint (2026-11-25)

| Metric | Lines |
|---|---|
| raw | 2177 |
| code | 1793 |
| **source (non-test)** | **1249** |
| test | 544 |

Largest source files:

| File | Non-comment lines |
|---|---|
| `src/server/server.mbt` | 286 |
| `src/core/protocol.mbt` | 186 |
| `src/core/trie.mbt` | 184 |
| `src/cli/args.mbt` | 174 |
| `src/core/headers.mbt` | 102 |
| `src/server/monitor.mbt` | 89 |
| `src/core/connect.mbt` | 85 |
| `src/core/stats.mbt` | 49 |
| `src/core/subject.mbt` | 37 |
| `src/core/registry.mbt` | 33 |

The source-only number is the conservative one: it excludes tests, generated
interfaces, Markdown, YAML and comments. It is roughly 2.5x the 500-line
threshold.
