"""Check that new release note entries land in the (Unreleased) section.

Compares release notes files against the merge-base with origin/main and
fails if any newly added bullet lines (lines starting with "- ") are not
inside the section whose header contains "(Unreleased)".

This prevents entries from silently ending up in an already-released section
when a new release is cut while a PR is still open.
"""
import subprocess;
import sys;
import from pathlib { Path }

glob RELEASE_NOTE_FILES = [
    "docs/docs/community/release_notes/jaclang.md",
    "docs/docs/community/release_notes/byllm.md",
    "docs/docs/community/release_notes/jac-client.md",
    "docs/docs/community/release_notes/jac-scale.md",
    "docs/docs/community/release_notes/jac-super.md",
    "docs/docs/community/release_notes/jac-mcp.md"
];

def get_merge_base() -> (str | None) {
    try {
        result = subprocess.run(
            ["git", "merge-base", "origin/main", "HEAD"],
            capture_output=True,
            text=True,
            check=True
        );
        return result.stdout.strip();
    } except subprocess.CalledProcessError {
        return None;
    }
}

"""Return lines added in HEAD vs merge_base for the given file."""
def get_added_lines(merge_base: str, filepath: str) -> list[str] {
    try {
        result = subprocess.run(
            ["git", "diff", f"{merge_base}...HEAD", "--", filepath],
            capture_output=True,
            text=True,
            check=True
        );
    } except subprocess.CalledProcessError {
        return [];
    }
    added = [];
    for line in result.stdout.splitlines() {
        if (line.startswith("+") and not line.startswith("+++")) {
            added.append(line[1:]);
        }
    }
    return added;
}

"""Return the set of lines that are inside the (Unreleased) section."""
def find_unreleased_lines(filepath: str) -> set[str] {
    path = Path(filepath);
    if not path.exists() {
        return `set();
    }
    lines = path.read_text().splitlines();
    in_unreleased = False;
    result: set[str] = `set();
    for line in lines {
        if line.startswith("## ") {
            in_unreleased = "(Unreleased)" in line;
        } elif in_unreleased {
            result.add(line);
        }
    }
    return result;
}

"""Return error messages for misplaced entries in this file."""
def check_file(merge_base: str, filepath: str) -> list[str] {
    added_lines = get_added_lines(merge_base, filepath);
    new_bullets = [
        line
        for line in added_lines
        if line.startswith("- ")
    ];
    if not new_bullets {
        return [];
    }
    unreleased_lines = find_unreleased_lines(filepath);
    misplaced = [
        b
        for b in new_bullets
        if (b not in unreleased_lines)
    ];
    if not misplaced {
        return [];
    }
    errors = [f"  {filepath}:"];
    for `entry in misplaced {
        preview = `entry[:100] + ("..." if (len(`entry) > 100) else "");
        errors.append(f"    {preview}");
    }
    return errors;
}

def main() -> int {
    merge_base = get_merge_base();
    if not merge_base {
        print("Could not determine merge base with origin/main -- skipping check.");
        return 0;
    }
    all_errors: list[str] = [];
    for filepath in RELEASE_NOTE_FILES {
        all_errors.extend(check_file(merge_base, filepath));
    }
    if all_errors {
        print();
        print("ERROR: New release note entries must be in the (Unreleased) section.");
        print();
        print("The entries below landed outside it -- this usually happens when a");
        print("new release is cut while your PR is open and you rebase afterward.");
        print("Open the file and move the entry to the top section marked (Unreleased).");
        print();
        for err in all_errors {
            print(err);
        }
        print();
        return 1;
    }
    return 0;
}

with entry {
    sys.exit(main());
}
