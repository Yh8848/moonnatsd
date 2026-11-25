#!/usr/bin/env python3
"""Count MoonBit source lines.

The competition asks for "effective MoonBit source volume". This script reports
several defensible numbers:

- raw: every line in every .mbt file
- code: non-blank, non-`//` lines
- source: `code` excluding `*_test.mbt` and `*_wbtest.mbt`
- test: `code` in test files

Run from the repository root: `python3 scripts/count_source_lines.py`.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKIP_DIRS = {".git", "_build", ".mooncakes", "target"}


def count(path: Path) -> int:
    lines = path.read_text(encoding="utf-8").splitlines()
    return sum(1 for line in lines if line.strip() and not line.strip().startswith("//"))


def main() -> None:
    raw = code = source = test = 0
    rows = []
    for path in sorted(ROOT.rglob("*.mbt")):
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        lines = path.read_text(encoding="utf-8").splitlines()
        raw += len(lines)
        current = count(path)
        code += current
        is_test = path.name.endswith("_test.mbt") or path.name.endswith("_wbtest.mbt")
        if is_test:
            test += current
        else:
            source += current
        rows.append((str(path.relative_to(ROOT)), current, is_test))

    print(f"raw lines:    {raw}")
    print(f"code lines:   {code}")
    print(f"source lines: {source}  (non-test)")
    print(f"test lines:   {test}")
    print("")
    print(f"{'file':60s} {'code':>6s}  kind")
    for name, current, is_test in sorted(rows, key=lambda row: -row[1]):
        print(f"{name:60s} {current:6d}  {'test' if is_test else 'source'}")


if __name__ == "__main__":
    main()
