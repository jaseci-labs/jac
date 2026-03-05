"""Pre-release validation to catch version conflicts early.

Runs during the create-release-pr workflow BEFORE bumping versions.
Computes what the new versions would be and checks PyPI to ensure
they don't already exist. Fails fast to prevent wasted PR creation
if a version was already published.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import tomlkit
from release_utils import PACKAGES, bump_version, check_pypi


def get_current_version(repo_root: Path, pkg_dir: str) -> str:
    """Read the current version from a package's pyproject.toml."""
    pyproject = repo_root / pkg_dir / "pyproject.toml"
    data = tomlkit.loads(pyproject.read_text())
    return str(data["project"]["version"])


def main() -> int:
    parser = argparse.ArgumentParser()
    for pkg_name in PACKAGES:
        parser.add_argument(
            f"--{pkg_name}", choices=["skip", "patch", "minor", "major"], default="skip"
        )
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    releases: list[dict[str, str]] = []
    errors: list[str] = []

    for pkg_name, pkg_info in PACKAGES.items():
        bump_type = getattr(args, pkg_name.replace("-", "_"))
        if bump_type == "skip":
            continue

        current = get_current_version(repo_root, pkg_info.dir)
        new_version = bump_version(current, bump_type)

        print(f"Checking {pkg_info.pypi} {new_version}...")
        if check_pypi(pkg_info.pypi, new_version):
            errors.append(f"{pkg_info.pypi} {new_version} already exists on PyPI")
        else:
            releases.append(
                {
                    "name": pkg_name,
                    "pypi": pkg_info.pypi,
                    "current": current,
                    "new": new_version,
                    "bump": bump_type,
                }
            )

    if errors:
        print("\nValidation failed:")
        for err in errors:
            print(f"  - {err}")
        return 1

    if not releases:
        print("No packages selected for release")
        return 1

    print("\nValidation passed:")
    for r in releases:
        print(f"  - {r['pypi']}: {r['current']} -> {r['new']}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
