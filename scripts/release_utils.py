"""Shared utilities for release scripts."""

from __future__ import annotations

import os
import urllib.error
import urllib.request
from pathlib import Path
from typing import NamedTuple


class PackageInfo(NamedTuple):
    """Package metadata for release scripts."""

    dir: str  # Directory name (e.g., "jac", "jac-byllm")
    pypi: str  # PyPI package name (e.g., "jaclang", "byllm")
    tier: int  # Publish order: 1=base, 2=depends on jaclang, 3=depends on all


# Package registry - single source of truth for all release scripts
PACKAGES: dict[str, PackageInfo] = {
    "jaclang": PackageInfo(dir="jac", pypi="jaclang", tier=1),
    "jac-byllm": PackageInfo(dir="jac-byllm", pypi="byllm", tier=2),
    "jac-client": PackageInfo(dir="jac-client", pypi="jac-client", tier=2),
    "jac-scale": PackageInfo(dir="jac-scale", pypi="jac-scale", tier=2),
    "jac-super": PackageInfo(dir="jac-super", pypi="jac-super", tier=2),
    "jac-mcp": PackageInfo(dir="jac-mcp", pypi="jac-mcp", tier=2),
    "jaseci": PackageInfo(dir="jaseci-package", pypi="jaseci", tier=3),
}


def bump_version(current: str, bump_type: str) -> str:
    """Compute the next version given a bump type (patch/minor/major)."""
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


def check_pypi(pypi_name: str, version: str) -> bool:
    """Check if a package version exists on PyPI. Returns True if it exists."""
    url = f"https://pypi.org/pypi/{pypi_name}/{version}/json"
    try:
        urllib.request.urlopen(url, timeout=10)
        return True
    except urllib.error.HTTPError as e:
        # 404 = doesn't exist, other errors = treat as exists (fail safe)
        return e.code != 404
    except urllib.error.URLError:
        # Network error - don't block, assume doesn't exist
        print(f"Warning: Could not reach PyPI to check {pypi_name} {version}")
        return False


def set_output(name: str, value: str) -> None:
    """Write a key=value pair to GitHub Actions output (or print if not in CI)."""
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with Path(github_output).open("a") as f:
            # Handle multiline values using GitHub Actions heredoc syntax
            if "\n" in value:
                import uuid

                delimiter = uuid.uuid4().hex
                f.write(f"{name}<<{delimiter}\n{value}\n{delimiter}\n")
            else:
                f.write(f"{name}={value}\n")
    print(f"{name}={value}")
