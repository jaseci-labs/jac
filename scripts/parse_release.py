"""Parse release info from PR title for the publish workflow.

Extracts package names and versions from merged release PR titles and outputs
a GitHub Actions matrix for tiered publishing.

Example PR title: "release: jaclang 1.2.3, jac-byllm 2.0.0"

The output matrix includes tier information for dependency-aware publishing:
  - Tier 1: jaclang (base package, no internal dependencies)
  - Tier 2: jac-byllm, jac-client, etc. (depend on jaclang)
  - Tier 3: jaseci meta-package (depends on all)
"""

from __future__ import annotations

import argparse
import json
import re
import sys

from release_utils import PACKAGES, set_output


def parse_from_title(pr_title: str) -> list[dict]:
    """Match patterns like 'jaclang 1.2.3' or 'jac-client 2.0.0'."""
    releases = []
    for pkg_name, version in re.findall(r"([\w-]+)\s+(\d+\.\d+\.\d+)", pr_title):
        pkg_name_lower = pkg_name.lower()
        if pkg_name_lower in PACKAGES:
            pkg_info = PACKAGES[pkg_name_lower]
            releases.append(
                {
                    "name": pkg_name_lower,
                    "dir": pkg_info.dir,
                    "pypi": pkg_info.pypi,
                    "tier": pkg_info.tier,
                    "version": version,
                    "submodules": pkg_info.submodules,
                    "precompile": pkg_info.precompile,
                    "precompile_path": pkg_info.precompile_path,
                    "precompile_artifact": pkg_info.precompile_artifact,
                    "extra_build_cmd": pkg_info.extra_build_cmd,
                }
            )
    return releases


PYTHON_VERSIONS = ["3.12", "3.13", "3.14"]


def build_precompile_matrix(releases: list[dict]) -> dict:
    """Build matrix for precompilation jobs (packages × python versions)."""
    include = []
    for r in releases:
        if r["precompile"]:
            for py_version in PYTHON_VERSIONS:
                include.append(
                    {
                        "name": r["name"],
                        "dir": r["dir"],
                        "pypi": r["pypi"],
                        "precompile_path": r["precompile_path"],
                        "precompile_artifact": r["precompile_artifact"],
                        "python_version": py_version,
                        "submodules": r["submodules"],
                    }
                )
    return {"include": include}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pr-title", required=True)
    args = parser.parse_args()

    releases = parse_from_title(args.pr_title)

    if not releases:
        print("No packages found to release")
        set_output("has_releases", "false")
        set_output("matrix", json.dumps({"include": []}))
        set_output("precompile_matrix", json.dumps({"include": []}))
        set_output("has_precompile", "false")
        set_output("release_summary", "none")
        return 1

    # Sort by tier for dependency ordering
    releases.sort(key=lambda x: x["tier"])

    print("Packages to release:")
    for r in releases:
        print(f"  - {r['pypi']} {r['version']} (tier {r['tier']})")
        if r["precompile"]:
            print("    (requires precompilation)")

    # Build precompile matrix
    precompile_matrix = build_precompile_matrix(releases)
    has_precompile = len(precompile_matrix["include"]) > 0

    summary = ", ".join(f"{r['pypi']} {r['version']}" for r in releases)
    set_output("has_releases", "true")
    set_output("matrix", json.dumps({"include": releases}))
    set_output("precompile_matrix", json.dumps(precompile_matrix))
    set_output("has_precompile", str(has_precompile).lower())
    set_output("release_summary", summary)
    return 0


if __name__ == "__main__":
    sys.exit(main())
