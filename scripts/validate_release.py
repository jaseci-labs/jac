"""Pre-release validation: ensures versions don't already exist on PyPI.

Run before creating a release PR to fail fast on version conflicts.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

import tomlkit

PACKAGES: dict[str, tuple[str, str]] = {
    "jaclang": ("jac", "jaclang"),
    "jac-byllm": ("jac-byllm", "byllm"),
    "jac-client": ("jac-client", "jac-client"),
    "jac-scale": ("jac-scale", "jac-scale"),
    "jac-super": ("jac-super", "jac-super"),
    "jac-mcp": ("jac-mcp", "jac-mcp"),
    "jaseci": ("jaseci-package", "jaseci"),
}


def get_current_version(repo_root: Path, pkg_dir: str) -> str:
    pyproject = repo_root / pkg_dir / "pyproject.toml"
    data = tomlkit.loads(pyproject.read_text())
    return str(data["project"]["version"])


def bump_version(current: str, bump_type: str) -> str:
    major, minor, patch = map(int, current.split("."))
    if bump_type == "patch":
        patch += 1
    elif bump_type == "minor":
        minor, patch = minor + 1, 0
    elif bump_type == "major":
        major, minor, patch = major + 1, 0, 0
    return f"{major}.{minor}.{patch}"


def version_exists_on_pypi(pypi_name: str, version: str) -> bool:
    url = f"https://pypi.org/pypi/{pypi_name}/{version}/json"
    try:
        urllib.request.urlopen(url, timeout=10)
        return True
    except urllib.error.HTTPError as e:
        return e.code != 404
    except urllib.error.URLError:
        # Network error - don't block release
        print(f"Warning: Could not reach PyPI to check {pypi_name} {version}")
        return False


def set_output(name: str, value: str) -> None:
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with Path(github_output).open("a") as f:
            f.write(f"{name}={value}\n")
    print(f"{name}={value}")


def main() -> int:
    parser = argparse.ArgumentParser()
    for pkg_name in PACKAGES:
        parser.add_argument(f"--{pkg_name}", choices=["skip", "patch", "minor", "major"], default="skip")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    releases: list[dict[str, str]] = []
    errors: list[str] = []

    for pkg_name, (pkg_dir, pypi_name) in PACKAGES.items():
        bump_type = getattr(args, pkg_name.replace("-", "_"))
        if bump_type == "skip":
            continue

        current = get_current_version(repo_root, pkg_dir)
        new_version = bump_version(current, bump_type)

        print(f"Checking {pypi_name} {new_version}...")
        if version_exists_on_pypi(pypi_name, new_version):
            errors.append(f"{pypi_name} {new_version} already exists on PyPI")
        else:
            releases.append({
                "name": pkg_name,
                "pypi": pypi_name,
                "dir": pkg_dir,
                "current": current,
                "new": new_version,
                "bump": bump_type,
            })

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

    set_output("releases", json.dumps(releases))
    set_output("has_releases", "true")
    return 0


if __name__ == "__main__":
    sys.exit(main())
