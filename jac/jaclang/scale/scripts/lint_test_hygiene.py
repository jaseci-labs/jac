#!/usr/bin/env python3
"""Anti-pattern gate for the jac-scale test suite (testing-trophy hygiene).

Fails when a scale test file reintroduces a pattern the trophy bans:
  - a tautological `assert True`
  - a hand-rolled infrastructure fake (`_Fake<Redis|Mongo|Firestore|Gcs|S3|...>`)
  - a silent skip: `print("[skip] ...")` immediately followed by `return`
  - a swallowed body: `} except ... { 0; }`
  - over-broad status acceptance: `status_code in [/(  200, 404, ... ]/)` with 3+ codes

Usage: lint_test_hygiene.py [root]   (default root: this file's ../tests)
Exit 1 on any violation, printing file:line and the rule.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

RULES = [
    ("assert-true", re.compile(r"\bassert\s+True\b")),
    (
        "hand-rolled-fake",
        re.compile(
            r"\b(obj|class)\s+_Fake(Redis|Mongo|Firestore|Gcs|GCS|S3|Storage|Db|Client)"
        ),
    ),
    ("swallowed-except", re.compile(r"\}\s*except[^{]*\{\s*0;?\s*\}")),
]

# multi-code status acceptance, e.g. status_code in [200, 404, 422]
STATUS_IN = re.compile(r"status_code\s+in\s+[\[(]([^\])]*)[\])]")


def scan(path: Path) -> list[tuple[int, str, str]]:
    hits: list[tuple[int, str, str]] = []
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    for i, line in enumerate(lines, start=1):
        for rule, rx in RULES:
            if rx.search(line):
                hits.append((i, rule, line.strip()))
        m = STATUS_IN.search(line)
        if m:
            codes = [c.strip() for c in m.group(1).split(",") if c.strip()]
            has_2xx = any(c.startswith("2") for c in codes)
            has_err = any(c[:1] in ("4", "5") for c in codes)
            # A set that accepts BOTH a success and an error code cannot tell a
            # working path from a broken one. All-4xx reject-sets are fine.
            if has_2xx and has_err:
                hits.append((i, "broad-status", line.strip()))
        # silent skip: print([skip]...) then return on the next non-blank line
        if re.search(r"print\([^)]*\[skip", line):
            nxt = lines[i] if i < len(lines) else ""
            if re.match(r"\s*return\s*;?\s*$", nxt):
                hits.append((i, "silent-skip", line.strip()))
    return hits


def load_baseline(baseline: Path) -> set[str]:
    """Known pre-existing violations, ratcheted: `relpath:rule` per line.

    New violations fail; grandfathered ones are tracked debt (fix and remove)."""
    if not baseline.exists():
        return set()
    keys = set()
    for line in baseline.read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            keys.add(line)
    return keys


def main() -> int:
    root = (
        Path(sys.argv[1])
        if len(sys.argv) > 1
        else Path(__file__).resolve().parent.parent / "tests"
    )
    baseline = load_baseline(
        Path(__file__).resolve().parent / "test_hygiene_baseline.txt"
    )
    files = [p for p in root.rglob("test_*.jac") if "fixtures" not in p.parts]
    new_hits = 0
    grandfathered = 0
    for p in sorted(files):
        rel = p.relative_to(root.parent)
        for ln, rule, text in scan(p):
            if f"{rel}:{rule}" in baseline:
                grandfathered += 1
                continue
            new_hits += 1
            print(f"{rel}:{ln}: [{rule}] {text}")  # noqa: T201
    if new_hits:
        print(  # noqa: T201
            f"\n{new_hits} NEW test-hygiene violation(s). Rules + baseline: jac/jaclang/scale/scripts/lint_test_hygiene.py"
        )
        return 1
    print(  # noqa: T201
        f"OK: {len(files)} scale test files clean ({grandfathered} grandfathered in baseline)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
