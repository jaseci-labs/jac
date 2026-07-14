"""Pre-release validation to catch version mistakes early.

Runs during the create-release-pr workflow BEFORE bumping versions.
Computes and prints what the new versions would be so an invalid bump
fails fast before any files are mutated.
"""
import from __future__ { annotations }
import argparse;
import sys;
import from pathlib { Path }
import from release_utils { PACKAGES, bump_version, get_current_version }

def main -> int {
    parser = argparse.ArgumentParser();
    for pkg_name in PACKAGES {
        parser.add_argument(
            f"--{pkg_name}",
            choices=["skip", "patch", "minor", "major"],
            `default="skip"
        );
    }
    args = parser.parse_args();
    repo_root = Path(__file__).resolve().parent.parent;
    releases: list[dict] = [];
    errors: list[str] = [];
    for (pkg_name, pkg_info) in PACKAGES.items() {
        bump_type = getattr(args, pkg_name.replace("-", "_"));
        if (bump_type == "skip") {
            continue;
        }
        current = get_current_version(repo_root, pkg_info.dir);
        new_version = bump_version(current, bump_type);
        entry = {
            "name": pkg_name,
            "pypi": pkg_info.pypi,
            "current": current,
            "new": new_version,
            "bump": bump_type
        };
        releases.append(entry);
    }
    if errors {
        print("\nValidation failed:");
        for err in errors {
            print(f"  - {err}");
        }
        return 1;
    }
    if not releases {
        print("No packages selected for release");
        return 1;
    }
    print("\nValidation passed:");
    for r in releases {
        print(f"  - {r['pypi']}: {r['current']} -> {r['new']}");
    }
    return 0;
}

with entry:__main__ {
    sys.exit(main());
}
