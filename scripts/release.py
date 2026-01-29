"""Unified release script for the jaseci monorepo.

Usage:
    python scripts/release.py --package <name> --bump <major|minor|patch>
    python scripts/release.py --package <name> --bump patch --dry-run

This script:
  1. Reads the current version from the package's pyproject.toml
  2. Computes the new version based on the bump type
  3. Updates pyproject.toml with the new version
  4. Syncs internal dependency versions in dependent packages
  5. Updates the release notes markdown file
  6. Outputs metadata for the GitHub Actions workflow
"""

from __future__ import annotations

import argparse
import os
import re
import tomllib
from pathlib import Path

# ---------------------------------------------------------------------------
# Package registry
# ---------------------------------------------------------------------------

PACKAGES: dict[str, dict[str, str]] = {
    "jaclang": {
        "dir": "jac",
        "pyproject": "jac/pyproject.toml",
        "release_notes": "docs/docs/community/release_notes/jaclang.md",
        "pypi_name": "jaclang",
        "notes_display": "jaclang",
    },
    "jac-byllm": {
        "dir": "jac-byllm",
        "pyproject": "jac-byllm/pyproject.toml",
        "release_notes": "docs/docs/community/release_notes/byllm.md",
        "pypi_name": "byllm",
        "notes_display": "byllm",
    },
    "jac-client": {
        "dir": "jac-client",
        "pyproject": "jac-client/pyproject.toml",
        "release_notes": "docs/docs/community/release_notes/jac-client.md",
        "pypi_name": "jac-client",
        "notes_display": "jac-client",
    },
    "jac-scale": {
        "dir": "jac-scale",
        "pyproject": "jac-scale/pyproject.toml",
        "release_notes": "docs/docs/community/release_notes/jac-scale.md",
        "pypi_name": "jac-scale",
        "notes_display": "jac-scale",
    },
    "jac-super": {
        "dir": "jac-super",
        "pyproject": "jac-super/pyproject.toml",
        "release_notes": "docs/docs/community/release_notes/jac-super.md",
        "pypi_name": "jac-super",
        "notes_display": "jac-super",
    },
}

# Internal dependency graph: pypi_name -> list of pypi_names it depends on
INTERNAL_DEPS: dict[str, list[str]] = {
    "jaclang": [],
    "byllm": ["jaclang"],
    "jac-client": ["jaclang"],
    "jac-scale": ["jaclang"],
    "jac-super": ["jaclang"],
}

# Reverse map: pypi_name -> list of package keys that depend on it
DEPENDENTS: dict[str, list[str]] = {}
for _pkg_key, _pkg_info in PACKAGES.items():
    for _dep in INTERNAL_DEPS.get(_pkg_info["pypi_name"], []):
        DEPENDENTS.setdefault(_dep, []).append(_pkg_key)


# ---------------------------------------------------------------------------
# Version helpers
# ---------------------------------------------------------------------------


def read_version(pyproject_path: Path) -> str:
    """Read the version string from a pyproject.toml file."""
    data = tomllib.loads(pyproject_path.read_text())
    return data["project"]["version"]


def bump_version(current: str, bump_type: str) -> str:
    """Compute the next version given a bump type."""
    parts = current.split(".")
    if len(parts) != 3:
        raise ValueError(f"Expected semver X.Y.Z, got: {current}")
    major, minor, patch = int(parts[0]), int(parts[1]), int(parts[2])

    if bump_type == "patch":
        patch += 1
    elif bump_type == "minor":
        minor += 1
        patch = 0
    elif bump_type == "major":
        major += 1
        minor = 0
        patch = 0
    else:
        raise ValueError(f"Unknown bump type: {bump_type}")

    return f"{major}.{minor}.{patch}"


# ---------------------------------------------------------------------------
# File modification helpers
# ---------------------------------------------------------------------------


def update_pyproject_version(pyproject_path: Path, new_version: str) -> None:
    """Update the version field in a pyproject.toml file."""
    content = pyproject_path.read_text()
    updated = re.sub(
        r'^(version\s*=\s*")[^"]*(")',
        rf"\g<1>{new_version}\2",
        content,
        count=1,
        flags=re.MULTILINE,
    )
    if updated == content:
        raise RuntimeError(f"Failed to update version in {pyproject_path}")
    pyproject_path.write_text(updated)


def update_dependency_version(
    pyproject_path: Path, dep_pypi_name: str, new_version: str
) -> bool:
    """Update an internal dependency version in a pyproject.toml file.

    Returns True if a change was made, False otherwise.
    """
    content = pyproject_path.read_text()
    # Match lines like: "jaclang>=0.9.12" or "jaclang>=0.9.9"
    pattern = rf'("{re.escape(dep_pypi_name)}>=)[^"]*(")'
    updated = re.sub(pattern, rf"\g<1>{new_version}\2", content)
    if updated == content:
        return False
    pyproject_path.write_text(updated)
    return True


def sync_dependents(repo_root: Path, pkg_pypi_name: str, new_version: str) -> list[str]:
    """Update all packages that depend on pkg_pypi_name.

    Returns list of modified file paths (relative to repo root).
    """
    modified: list[str] = []
    for dep_key in DEPENDENTS.get(pkg_pypi_name, []):
        dep_info = PACKAGES[dep_key]
        dep_pyproject = repo_root / dep_info["pyproject"]
        if update_dependency_version(dep_pyproject, pkg_pypi_name, new_version):
            modified.append(dep_info["pyproject"])
            print(
                f"  Updated {pkg_pypi_name}>={new_version} in {dep_info['pyproject']}"
            )
    return modified


def update_release_notes(
    release_notes_path: Path, display_name: str, new_version: str
) -> None:
    """Update the release notes markdown file.

    Transforms:
        ## <name> X.Y.Z (Unreleased)
        ## <name> A.B.C (Latest Release)
    Into:
        ## <name> <next_unreleased> (Unreleased)
        ## <name> <new_version> (Latest Release)
        ## <name> A.B.C
    """
    content = release_notes_path.read_text()

    # Compute next unreleased version (new_version + patch)
    next_unreleased = bump_version(new_version, "patch")

    # Replace the current (Unreleased) line with the new version as (Latest Release)
    unreleased_pattern = rf"(## {re.escape(display_name)} )\S+( \(Unreleased\))"
    match = re.search(unreleased_pattern, content)
    if not match:
        print(f"  Warning: No (Unreleased) section found in {release_notes_path}")
        return

    # Remove (Latest Release) from the previous latest
    content = content.replace(" (Latest Release)", "")

    # Replace (Unreleased) version with new version as (Latest Release)
    content = re.sub(
        unreleased_pattern,
        rf"\g<1>{new_version} (Latest Release)",
        content,
    )

    # Insert new unreleased section above the new latest release line
    new_unreleased_header = f"## {display_name} {next_unreleased} (Unreleased)\n\n"
    latest_line = f"## {display_name} {new_version} (Latest Release)"
    content = content.replace(latest_line, new_unreleased_header + latest_line)

    release_notes_path.write_text(content)


# ---------------------------------------------------------------------------
# GitHub Actions output
# ---------------------------------------------------------------------------


def set_output(name: str, value: str) -> None:
    """Write a key=value pair to $GITHUB_OUTPUT (or print if not in CI)."""
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with open(github_output, "a") as f:
            # Handle multiline values
            if "\n" in value:
                import uuid

                delimiter = uuid.uuid4().hex
                f.write(f"{name}<<{delimiter}\n{value}\n{delimiter}\n")
            else:
                f.write(f"{name}={value}\n")
    else:
        print(f"  [output] {name}={value}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Release a package in the jaseci monorepo"
    )
    parser.add_argument(
        "--package",
        required=True,
        choices=PACKAGES.keys(),
        help="Package to release",
    )
    parser.add_argument(
        "--bump",
        required=True,
        choices=["major", "minor", "patch"],
        help="Version bump type",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be done without modifying files",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    pkg = PACKAGES[args.package]
    repo_root = Path(__file__).resolve().parent.parent

    # Read current version
    pyproject_path = repo_root / pkg["pyproject"]
    current_version = read_version(pyproject_path)
    new_version = bump_version(current_version, args.bump)

    print(f"Package:  {args.package}")
    print(f"Current:  {current_version}")
    print(f"Bump:     {args.bump}")
    print(f"New:      {new_version}")
    print()

    if args.dry_run:
        print("[dry-run] Would update the following files:")
        print(f"  {pkg['pyproject']} -> version {new_version}")
        for dep_key in DEPENDENTS.get(pkg["pypi_name"], []):
            dep_info = PACKAGES[dep_key]
            print(f"  {dep_info['pyproject']} -> {pkg['pypi_name']}>={new_version}")
        print(f"  {pkg['release_notes']} -> release notes updated")
        return

    # 1. Update primary pyproject.toml version
    print("Updating version...")
    update_pyproject_version(pyproject_path, new_version)
    modified_files = [pkg["pyproject"]]

    # 2. Sync dependents
    print("Syncing dependents...")
    modified_files.extend(sync_dependents(repo_root, pkg["pypi_name"], new_version))

    # 3. Update release notes
    print("Updating release notes...")
    release_notes_path = repo_root / pkg["release_notes"]
    update_release_notes(release_notes_path, pkg["notes_display"], new_version)
    modified_files.append(pkg["release_notes"])

    # 4. Output metadata for the workflow
    branch_name = f"release/{args.package}-{new_version}"
    pr_title = f"release: {args.package} {new_version}"
    pr_body = (
        f"## Release {args.package} {new_version}\n\n"
        f"- Bump version: {current_version} -> {new_version}\n"
        f"- Bump type: {args.bump}\n"
    )
    if len(modified_files) > 1:
        pr_body += "- Updated internal dependency versions in dependent packages\n"
    pr_body += "- Updated release notes\n"

    set_output("new_version", new_version)
    set_output("branch_name", branch_name)
    set_output("pr_title", pr_title)
    set_output("pr_body", pr_body)
    set_output("modified_files", " ".join(modified_files))

    print()
    print(f"Done. Modified files: {', '.join(modified_files)}")


if __name__ == "__main__":
    main()
