#!/usr/bin/env python3
"""Check that new release note entries land in the (Unreleased) section.

Compares release notes files against the merge-base with origin/main and
fails if any newly added bullet lines (lines starting with "- ") are not
inside the section whose header contains "(Unreleased)".

This prevents entries from silently ending up in an already-released section
when a new release is cut while a PR is still open.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

RELEASE_NOTE_FILES = [
    "docs/docs/community/release_notes/jaclang.md",
    "docs/docs/community/release_notes/byllm.md",
    "docs/docs/community/release_notes/jac-client.md",
    "docs/docs/community/release_notes/jac-scale.md",
    "docs/docs/community/release_notes/jac-super.md",
    "docs/docs/community/release_notes/jac-mcp.md",
]


def get_merge_base() -> str | None:
    try:
        result = subprocess.run(
            ["git", "merge-base", "origin/main", "HEAD"],
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return None


def get_added_lines(merge_base: str, filepath: str) -> list[str]:
    """Return lines added in HEAD vs merge_base for the given file."""
    try:
        result = subprocess.run(
            ["git", "diff", f"{merge_base}...HEAD", "--", filepath],
            capture_output=True,
            text=True,
            check=True,
        )
    except subprocess.CalledProcessError:
        return []

    added = []
    for line in result.stdout.splitlines():
        # "+line" but not "+++" (file header)
        if line.startswith("+") and not line.startswith("+++"):
            added.append(line[1:])  # strip leading "+"
    return added


def find_unreleased_lines(filepath: str) -> set[str]:
    """Return the set of lines that are inside the (Unreleased) section."""
    path = Path(filepath)
    if not path.exists():
        return set()

    lines = path.read_text().splitlines()
    in_unreleased = False
    result: set[str] = set()

    for line in lines:
        if line.startswith("## "):
            in_unreleased = "(Unreleased)" in line
        elif in_unreleased:
            result.add(line)

    return result


def check_file(merge_base: str, filepath: str) -> list[str]:
    """Return error messages for misplaced entries in this file."""
    added_lines = get_added_lines(merge_base, filepath)
    new_bullets = [l for l in added_lines if l.startswith("- ")]
    if not new_bullets:
        return []

    unreleased_lines = find_unreleased_lines(filepath)
    misplaced = [b for b in new_bullets if b not in unreleased_lines]
    if not misplaced:
        return []

    errors = [f"  {filepath}: new entries found outside (Unreleased) section:"]
    for entry in misplaced:
        preview = entry[:100] + ("..." if len(entry) > 100 else "")
        errors.append(f"    {preview}")
    return errors


def main() -> int:
    merge_base = get_merge_base()
    if not merge_base:
        print("Could not determine merge base with origin/main — skipping check.")
        return 0

    all_errors: list[str] = []
    for filepath in RELEASE_NOTE_FILES:
        all_errors.extend(check_file(merge_base, filepath))

    if all_errors:
        print()
        print("=" * 60)
        print("ERROR: Release note entries are not in the (Unreleased) section!")
        print("=" * 60)
        print()
        print("The following new entries were added outside the (Unreleased) section.")
        print("This usually happens after rebasing when a new release was cut.")
        print("Move the entries to the (Unreleased) section at the top of the file.")
        print()
        for err in all_errors:
            print(err)
        print()
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
