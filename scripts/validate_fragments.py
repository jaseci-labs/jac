"""Pre-commit hook to validate release note fragment filenames.

Fragment files must follow the naming convention:
    <PR_number>.<category>.md

Valid categories: feature, bugfix, breaking, refactor, docs

Example valid filenames:
    1234.feature.md
    5678.bugfix.md
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

VALID_CATEGORIES = {"feature", "bugfix", "breaking", "refactor", "docs"}
PATTERN = re.compile(r"^\d+\.(feature|bugfix|breaking|refactor|docs)\.md$")


def validate(files: list[str]) -> int:
    failed = False
    for filepath in files:
        path = Path(filepath)
        # Only validate files inside the unreleased/ directory
        if "unreleased" not in path.parts:
            continue
        # Skip README and .gitkeep
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
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(validate(sys.argv[1:]))
