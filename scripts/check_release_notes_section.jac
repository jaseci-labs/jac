"""Check that new release note entries land in the (Unreleased) section.

Fails if any added bullet lines are outside (Unreleased), or if anything
is added to the (Latest Release) section.
"""
import subprocess;
import sys;
import re;


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

def get_diff(merge_base: str, filepath: str) -> str {
    try {
        result = subprocess.run(
            ["git", "diff", "-U99999", f"{merge_base}...HEAD", "--", filepath],
            capture_output=True,
            text=True,
            check=True
        );
        return result.stdout;
    } except subprocess.CalledProcessError {
        return "";
    }
}

def check_file(merge_base: str, filepath: str, version_header: str) -> list[str] {
    diff = get_diff(merge_base, filepath);
    if not diff {
        return [];
    }

    is_unreleased = False;
    is_latest_release = False;
    latest_release_entries: list[str] = [];
    misplaced_entries: list[str] = [];

    for line in diff.splitlines() {
        if line.startswith("---") or line.startswith("+++") or line.startswith("@@") or not line {
            continue;
        }

        prefix = line[0];
        content = line[1:];

        if prefix == "-" {
            continue;
        }

        if re.match(version_header, content) {
            is_unreleased = "(Unreleased)" in content;
            is_latest_release = "(Latest Release)" in content;
        }

        if prefix == "+" and content.startswith("- ") {
            if not is_unreleased {
                preview = content[:100] + ("..." if len(content) > 100 else "");
                if is_latest_release {
                    latest_release_entries.append(f"    {preview}");
                } else {
                    misplaced_entries.append(f"    {preview}");
                }
            }
        }
    }

    errors: list[str] = [];
    if latest_release_entries {
        errors.append(f"  {filepath}: additions to (Latest Release) are not allowed:");
        errors.extend(latest_release_entries);
    }
    if misplaced_entries {
        errors.append(f"  {filepath}: entries added outside (Unreleased) section:");
        errors.extend(misplaced_entries);
    }
    return errors;
}

# NOTE: This check can be skipped by adding the 'skip-release-notes-check' label
# to the PR. Useful when intentionally editing old release note sections (e.g., typo fixes).
def main() -> int {
    release_note_files: dict[str, str] = {
        "jaclang":    "docs/docs/community/release_notes/jaclang.md",
        "byllm":      "docs/docs/community/release_notes/byllm.md",
        "jac-client": "docs/docs/community/release_notes/jac-client.md",
        "jac-scale":  "docs/docs/community/release_notes/jac-scale.md",
        "jac-super":  "docs/docs/community/release_notes/jac-super.md",
        "jac-mcp":    "docs/docs/community/release_notes/jac-mcp.md"
    };
    version_header = rf"^## ({'|'.join(list(release_note_files.keys()) + ['Version'])}) \d+\.\d+(\.\d+)?";
    merge_base = get_merge_base();
    if not merge_base {
        print("Could not determine merge base with origin/main -- skipping check.");
        return 0;
    }
    all_errors: list[str] = [];
    for filepath in release_note_files.values() {
        all_errors.extend(check_file(merge_base, filepath, version_header));
    }
    if all_errors {
        print();
        print("ERROR: Release note entries must only be added to the (Unreleased) section.");
        print();
        print("- If your entry landed in a released section: move it to the top (Unreleased) header.");
        print("- If your entry is in (Latest Release): that section is locked -- move it to (Unreleased).");
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
