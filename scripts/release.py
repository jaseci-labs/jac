"""Unified release script for the jaseci monorepo.

Usage:
    python scripts/release.py --jaclang patch --jac-client minor
    python scripts/release.py --jaclang patch --dry-run

Each package flag accepts: skip (default), patch, minor, major
Omit a package flag to skip it.

This script:
  1. Reads the current version from each package's pyproject.toml
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
from pathlib import Path

import tomlkit

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
    "jaseci": {
        "dir": "jaseci-package",
        "pyproject": "jaseci-package/pyproject.toml",
        "release_notes": "",  # Meta package - no release notes
        "pypi_name": "jaseci",
        "notes_display": "jaseci",
    },
}

# Internal dependency graph: pypi_name -> list of pypi_names it depends on
INTERNAL_DEPS: dict[str, list[str]] = {
    "jaclang": [],
    "byllm": ["jaclang"],
    "jac-client": ["jaclang"],
    "jac-scale": ["jaclang"],
    "jac-super": ["jaclang"],
    "jaseci": ["jaclang", "byllm", "jac-client", "jac-scale", "jac-super"],
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
    data = tomlkit.loads(pyproject_path.read_text())
    return str(data["project"]["version"])  # type: ignore[index]


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
    data = tomlkit.loads(pyproject_path.read_text())
    data["project"]["version"] = new_version  # type: ignore[index]
    pyproject_path.write_text(tomlkit.dumps(data))


def update_dependency_version(
    pyproject_path: Path, dep_pypi_name: str, new_version: str
) -> bool:
    """Update an internal dependency version in a pyproject.toml file.

    Returns True if a change was made, False otherwise.
    """
    data = tomlkit.loads(pyproject_path.read_text())
    dependencies = data["project"]["dependencies"]  # type: ignore[index]
    modified = False

    for i, dep in enumerate(dependencies):  # type: ignore[arg-type]
        dep_str = str(dep)
        if dep_str.startswith(f"{dep_pypi_name}>="):
            dependencies[i] = f"{dep_pypi_name}>={new_version}"  # type: ignore[index]
            modified = True
            break

    if modified:
        pyproject_path.write_text(tomlkit.dumps(data))

    return modified


def sync_dependents(
    repo_root: Path,
    pkg_pypi_name: str,
    new_version: str,
    releasing_packages: set[str],
) -> list[str]:
    """Update packages that depend on pkg_pypi_name (only if they are also being released).

    Args:
        repo_root: Path to repository root.
        pkg_pypi_name: PyPI name of the package whose version changed.
        new_version: The new version of the package.
        releasing_packages: Set of package keys being released in this run.

    Returns list of modified file paths (relative to repo root).
    """
    modified: list[str] = []
    for dep_key in DEPENDENTS.get(pkg_pypi_name, []):
        # Only update dependency if the dependent package is also being released
        if dep_key not in releasing_packages:
            continue
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
        with Path(github_output).open("a") as f:
            # Handle multiline values using GitHub Actions heredoc syntax.
            # Format: name<<DELIMITER\nvalue\nDELIMITER\n
            # A random UUID is used as delimiter to avoid conflicts with value content.
            # See: https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#multiline-strings
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
        description="Release packages in the jaseci monorepo"
    )
    bump_choices = ["skip", "patch", "minor", "major"]
    for pkg_name in PACKAGES:
        parser.add_argument(
            f"--{pkg_name}",
            choices=bump_choices,
            default="skip",
            help=f"Version bump type for {pkg_name} (default: skip)",
        )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be done without modifying files",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    repo_root = Path(__file__).resolve().parent.parent

    # Collect packages to release (those not set to "skip")
    releases: list[dict[str, str]] = []
    for pkg_name, pkg_info in PACKAGES.items():
        # Convert hyphens to underscores for attribute access
        attr_name = pkg_name.replace("-", "_")
        bump_type = getattr(args, attr_name)
        if bump_type != "skip":
            releases.append(
                {
                    "name": pkg_name,
                    "bump": bump_type,
                    **pkg_info,
                }
            )

    if not releases:
        print("No packages selected for release (all set to 'skip').")
        return

    # Print summary
    print("Packages to release:")
    for rel in releases:
        print(f"  - {rel['name']}: {rel['bump']}")
    print()

    # Set of package keys being released (for filtering dependent updates)
    releasing_packages: set[str] = {rel["name"] for rel in releases}

    modified_files: list[str] = []
    version_updates: list[tuple[str, str, str]] = []  # (name, old, new)

    # Process each package
    for rel in releases:
        pkg_name = rel["name"]
        bump_type = rel["bump"]
        pyproject_path = repo_root / rel["pyproject"]

        current_version = read_version(pyproject_path)
        new_version = bump_version(current_version, bump_type)
        version_updates.append((pkg_name, current_version, new_version))

        print(f"Package:  {pkg_name}")
        print(f"Current:  {current_version}")
        print(f"Bump:     {bump_type}")
        print(f"New:      {new_version}")
        print()

        if args.dry_run:
            print(f"[dry-run] Would update {rel['pyproject']} -> version {new_version}")
            for dep_key in DEPENDENTS.get(rel["pypi_name"], []):
                if dep_key in releasing_packages:
                    dep_info = PACKAGES[dep_key]
                    print(
                        f"[dry-run] Would update {dep_info['pyproject']} -> {rel['pypi_name']}>={new_version}"
                    )
            if rel["release_notes"]:
                print(f"[dry-run] Would update {rel['release_notes']}")
            print()
            continue

        # 1. Update primary pyproject.toml version
        print("Updating version...")
        update_pyproject_version(pyproject_path, new_version)
        if rel["pyproject"] not in modified_files:
            modified_files.append(rel["pyproject"])

        # 2. Sync dependents (only for packages being released)
        print("Syncing dependents...")
        for dep_file in sync_dependents(
            repo_root, rel["pypi_name"], new_version, releasing_packages
        ):
            if dep_file not in modified_files:
                modified_files.append(dep_file)

        # 3. Update release notes (if applicable)
        if rel["release_notes"]:
            print("Updating release notes...")
            release_notes_path = repo_root / rel["release_notes"]
            update_release_notes(release_notes_path, rel["notes_display"], new_version)
            if rel["release_notes"] not in modified_files:
                modified_files.append(rel["release_notes"])
        print()

    if args.dry_run:
        return

    # 4. Output metadata for the workflow
    # Build branch name and PR title from all released packages
    pkg_versions = [f"{name}-{new}" for name, _, new in version_updates]
    branch_name = "release/" + "_".join(pkg_versions)
    pr_title = "release: " + ", ".join(
        f"{name} {new}" for name, _, new in version_updates
    )

    # Build PR body
    pr_body = "## Release\n\n"
    for name, old, new in version_updates:
        rel = next(r for r in releases if r["name"] == name)
        pr_body += f"### {name}\n"
        pr_body += f"- Version: {old} → {new}\n"
        pr_body += f"- Bump type: {rel['bump']}\n\n"

    if any(DEPENDENTS.get(rel["pypi_name"]) for rel in releases):
        pr_body += "- Updated internal dependency versions in dependent packages\n"
    pr_body += "- Updated release notes\n"

    set_output("branch_name", branch_name)
    set_output("pr_title", pr_title)
    set_output("pr_body", pr_body)
    set_output("modified_files", " ".join(modified_files))

    print(f"Done. Modified files: {', '.join(modified_files)}")


if __name__ == "__main__":
    main()
