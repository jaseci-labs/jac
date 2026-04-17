"""Pre-commit hook to validate release note fragment filenames.

Fragment files must follow the naming convention:
    <PR_number>.<category>.md

Valid categories: feature, bugfix

Example valid filenames:
    1234.feature.md
    5678.bugfix.md
"""
import from __future__ { annotations }
import re;
import sys;
import from pathlib { Path }

with entry {
    VALID_CATEGORIES = {"feature", "bugfix", "breaking"};
    PATTERN = re.compile(r"^\d+\.(feature|bugfix|breaking)\.md$");
}

def validate(files: list[str]) -> int {
    failed = False;
    for filepath in files {
        path = Path(filepath);
        if ("unreleased" not in path.parts) {
            continue;
        }
        if (path.name in ("README.md",) or path.suffix == ".gitkeep") {
            continue;
        }
        if not PATTERN.match(path.name) {
            print(
                f"ERROR: Invalid fragment filename: {filepath}\n"
                "       Expected format: <PR_number>.<category>.md\n"
                f"       Valid categories: {', '.join(sorted(VALID_CATEGORIES))}\n"
                "       Example: 1234.bugfix.md"
            );
            failed = True;
        }
    }
    return 1 if failed else 0;
}

with entry {
    if (__name__ == "__main__") {
        sys.exit(validate(sys.argv[1:]));
    }
}
