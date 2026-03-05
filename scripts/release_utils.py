"""Shared utilities for release scripts.

This module provides the single source of truth for package metadata,
version bumping logic, and GitHub Actions output helpers.
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import NamedTuple


class PackageInfo(NamedTuple):
    """Package metadata for release scripts."""

    dir: str
    pypi: str
    release_notes: str = ""
    notes_display: str = ""


PACKAGES: dict[str, PackageInfo] = {
    "jaclang": PackageInfo(
        dir="jac",
        pypi="jaclang",
        release_notes="docs/docs/community/release_notes/jaclang.md",
        notes_display="jaclang",
    ),
    "jac-byllm": PackageInfo(
        dir="jac-byllm",
        pypi="byllm",
        release_notes="docs/docs/community/release_notes/byllm.md",
        notes_display="byllm",
    ),
    "jac-client": PackageInfo(
        dir="jac-client",
        pypi="jac-client",
        release_notes="docs/docs/community/release_notes/jac-client.md",
        notes_display="jac-client",
    ),
    "jac-scale": PackageInfo(
        dir="jac-scale",
        pypi="jac-scale",
        release_notes="docs/docs/community/release_notes/jac-scale.md",
        notes_display="jac-scale",
    ),
    "jac-super": PackageInfo(
        dir="jac-super",
        pypi="jac-super",
        release_notes="docs/docs/community/release_notes/jac-super.md",
        notes_display="jac-super",
    ),
    "jac-mcp": PackageInfo(
        dir="jac-mcp",
        pypi="jac-mcp",
        release_notes="docs/docs/community/release_notes/jac-mcp.md",
        notes_display="jac-mcp",
    ),
    "jaseci": PackageInfo(
        dir="jaseci-package",
        pypi="jaseci",
        release_notes="",
        notes_display="jaseci",
    ),
}

# Internal dependency graph: pypi_name -> list of pypi_names it depends on
INTERNAL_DEPS: dict[str, list[str]] = {
    "jaclang": [],
    "byllm": ["jaclang"],
    "jac-client": ["jaclang"],
    "jac-scale": ["jaclang"],
    "jac-super": ["jaclang"],
    "jac-mcp": ["jaclang"],
    "jaseci": ["jaclang", "byllm", "jac-client", "jac-scale", "jac-super", "jac-mcp"],
}

# Reverse map: pypi_name -> list of package keys that depend on it
DEPENDENTS: dict[str, list[str]] = {}
for _pkg_key, _pkg_info in PACKAGES.items():
    for _dep in INTERNAL_DEPS.get(_pkg_info.pypi, []):
        DEPENDENTS.setdefault(_dep, []).append(_pkg_key)


def bump_version(current: str, bump_type: str) -> str:
    """Compute the next version given a bump type (patch, minor, major)."""
    parts = current.split(".")
    if len(parts) != 3:
        raise ValueError(f"Expected semver X.Y.Z, got: {current}")
    major, minor, patch = int(parts[0]), int(parts[1]), int(parts[2])

    if bump_type == "patch":
        patch += 1
    elif bump_type == "minor":
        minor, patch = minor + 1, 0
    elif bump_type == "major":
        major, minor, patch = major + 1, 0, 0
    else:
        raise ValueError(f"Unknown bump type: {bump_type}")

    return f"{major}.{minor}.{patch}"


def set_output(name: str, value: str) -> None:
    """Write a key=value pair to $GITHUB_OUTPUT (or print if not in CI)."""
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with Path(github_output).open("a") as f:
            if "\n" in value:
                import uuid

                delimiter = uuid.uuid4().hex
                f.write(f"{name}<<{delimiter}\n{value}\n{delimiter}\n")
            else:
                f.write(f"{name}={value}\n")
    else:
        print(f"  [output] {name}={value}")
