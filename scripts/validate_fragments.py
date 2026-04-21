"""Pre-commit hook to validate release note fragment filenames and content.

Fragment files must follow the naming convention:
    <PR_number>.<category>.md

Valid categories: feature, bugfix, breaking, refactor, docs

Example valid filenames:
    1234.feature.md
    5678.bugfix.md

Content rules:
    - No markdown headings (lines starting with #)
    - Every non-empty line must start with '- ' or be an indented continuation
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

VALID_CATEGORIES = {"feature", "bugfix", "breaking", "refactor", "docs"}
PATTERN = re.compile(r"^\d+\.(feature|bugfix|breaking|refactor|docs)\.md$")
HEADING = re.compile(r"^#{1,6} ")
INVALID_LINE = re.compile(r"^[^\s-]")


def validate(files: list[str]) -> int:
    failed = False
    for filepath in files:
        path = Path(filepath)
        if "unreleased" not in path.parts:
            continue
        if path.name in ("README.md",) or path.suffix == ".gitkeep":
            continue

        if not PATTERN.match(path.name):
            print(
                f"ERROR: Invalid fragment filename: {filepath}\n"
                f"       Expected format: <PR_number>.<category>.md\n"
                f"       Valid categories: {', '.join(sorted(VALID_CATEGORIES))}\n"
                f"       Example: 1234.bugfix.md"
            )
            failed = True
            continue

        content = path.read_text(encoding="utf-8")
        for lineno, line in enumerate(content.splitlines(), start=1):
            if HEADING.match(line):
                print(
                    f"ERROR: Markdown heading in fragment {filepath}:{lineno}\n"
                    f"       Remove headings — use '- **Category: Title**: description' format"
                )
                failed = True
                break
            if INVALID_LINE.match(line):
                print(
                    f"ERROR: Invalid line in fragment {filepath}:{lineno}\n"
                    f"       Every non-empty line must start with '- ' or be indented\n"
                    f"       Example: - **Fix: Title**: Description of the change."
                )
                failed = True
                break

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(validate(sys.argv[1:]))
