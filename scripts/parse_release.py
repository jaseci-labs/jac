"""Parse release info from PR title for the publish workflow.

Extracts package names and versions from PR titles like:
  "release: jaclang 1.2.3, byllm 2.0.0"

Outputs a matrix for GitHub Actions with tier info for dependency ordering:
  - Tier 1: jaclang (base)
  - Tier 2: byllm, jac-client, jac-scale, jac-super, jac-mcp (depend on jaclang)
  - Tier 3: jaseci (depends on all)

Input:
  --pr-title: PR title string (e.g., "release: jaclang 1.2.3, byllm 2.0.0")

Output (GitHub Actions):
  has_releases: "true" or "false"
  matrix: JSON {"include": [{"name", "dir", "pypi", "tier", "version"}, ...]}
  release_summary: "jaclang 1.2.3, byllm 2.0.0"
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

PACKAGES: dict[str, dict[str, str | int]] = {
    "jaclang": {"dir": "jac", "pypi": "jaclang", "tier": 1},
    "byllm": {"dir": "jac-byllm", "pypi": "byllm", "tier": 2},
    "jac-byllm": {"dir": "jac-byllm", "pypi": "byllm", "tier": 2},
    "jac-client": {"dir": "jac-client", "pypi": "jac-client", "tier": 2},
    "jac-scale": {"dir": "jac-scale", "pypi": "jac-scale", "tier": 2},
    "jac-super": {"dir": "jac-super", "pypi": "jac-super", "tier": 2},
    "jac-mcp": {"dir": "jac-mcp", "pypi": "jac-mcp", "tier": 2},
    "jaseci": {"dir": "jaseci-package", "pypi": "jaseci", "tier": 3},
}


def parse_from_title(pr_title: str) -> list[dict[str, str | int]]:
    """Match patterns like 'jaclang 1.2.3' or 'jac-client 2.0.0'."""
    releases = []
    for pkg_name, version in re.findall(r"([\w-]+)\s+(\d+\.\d+\.\d+)", pr_title):
        pkg_name_lower = pkg_name.lower()
        if pkg_name_lower in PACKAGES:
            pkg_info = PACKAGES[pkg_name_lower]
            releases.append({
                "name": pkg_name_lower,
                "dir": pkg_info["dir"],
                "pypi": pkg_info["pypi"],
                "tier": pkg_info["tier"],
                "version": version,
            })
    return releases


def set_output(name: str, value: str) -> None:
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with Path(github_output).open("a") as f:
            f.write(f"{name}={value}\n")
    print(f"{name}={value}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pr-title", required=True)
    args = parser.parse_args()

    releases = parse_from_title(args.pr_title)

    if not releases:
        print("No packages found to release")
        set_output("has_releases", "false")
        set_output("matrix", json.dumps({"include": []}))
        set_output("release_summary", "none")
        return 1

    # Sort by tier for dependency ordering
    releases.sort(key=lambda x: x["tier"])

    print("Packages to release:")
    for r in releases:
        print(f"  - {r['pypi']} {r['version']} (tier {r['tier']})")

    summary = ", ".join(f"{r['pypi']} {r['version']}" for r in releases)
    set_output("has_releases", "true")
    set_output("matrix", json.dumps({"include": releases}))
    set_output("release_summary", summary)
    return 0


if __name__ == "__main__":
    sys.exit(main())
