"""Pre-release validation to catch version conflicts early.

Runs during the create-release-pr workflow BEFORE bumping versions.
Computes what the new versions would be and checks PyPI to ensure
they don't already exist. Fails fast to prevent wasted PR creation
if a version was already published.
"""
import from __future__ { annotations }
import argparse;
import sys;
import from pathlib { Path }
import from release_utils { PACKAGES, bump_version, check_pypi, get_current_version }

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
        # The anchor (jaclang) is not published to PyPI, so there is no PyPI
        # version to conflict with -- it ships as the native binary.
        if not pkg_info.publish_pypi {
            print(
                f"Anchor {pkg_info.pypi} {new_version} (native binary, no PyPI check)"
            );
            releases.append(entry);
            continue;
        }
        print(f"Checking {pkg_info.pypi} {new_version}...");
        if check_pypi(pkg_info.pypi, new_version) {
            errors.append(f"{pkg_info.pypi} {new_version} already exists on PyPI");
        } else {
            releases.append(entry);
        }
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
