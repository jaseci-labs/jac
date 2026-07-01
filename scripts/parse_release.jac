"""Parse release info from PR title for the publish workflow.

Extracts package names and versions from merged release PR titles and outputs
a GitHub Actions matrix for tiered publishing.

Example PR title: "release: jaclang 1.2.3, jac-byllm 2.0.0"

The output matrix includes tier info for dependency-aware publishing:
  - Tier 0: jaclang -- the release anchor; ships as the native binary, not PyPI
  - Tier 2: jac-byllm (plugin published to PyPI)
"""
import from __future__ { annotations }
import argparse;
import json;
import re;
import sys;
import from pathlib { Path }
import from release_utils { PACKAGES, get_current_version, set_output }
"""Build a release dict for one known package at a given version."""
def release_entry(pkg_name_lower: str, version: str) -> dict {
    pkg_info = PACKAGES[pkg_name_lower];
    return {
        "name": pkg_name_lower,
        "dir": pkg_info.dir,
        "pypi": pkg_info.pypi,
        "tier": pkg_info.tier,
        "version": version,
        "submodules": pkg_info.submodules,
        "extra_build_cmd": pkg_info.extra_build_cmd,
        "needs_nodejs": pkg_info.needs_nodejs,
        "extra_build_deps": pkg_info.extra_build_deps,
        "publish_pypi": pkg_info.publish_pypi,
        "is_anchor": pkg_info.is_anchor
    };
}

"""Match patterns like 'jaclang 1.2.3' or 'jac-mcp 2.0.0'."""
def parse_from_title(pr_title: str) -> list[dict] {
    releases = [];
    for (pkg_name, version) in re.findall(r"([\w-]+)\s+(\d+\.\d+\.\d+)", pr_title) {
        pkg_name_lower = pkg_name.lower();
        if (pkg_name_lower in PACKAGES) {
            releases.append(release_entry(pkg_name_lower, version));
        }
    }
    return releases;
}

"""Build releases for an explicit package list, reading versions from manifests.

    Used by the manual (workflow_dispatch) re-publish path: the caller selects
    which packages to publish and the version is read straight from each
    package's jac.toml (or pyproject.toml for jaclang). Lets a release be
    re-fired after a partial CI failure without re-merging a release/* PR.
    """
def parse_from_packages(pkg_names: list[str]) -> list[dict] {
    repo_root = Path(__file__).resolve().parent.parent;
    releases = [];
    for raw in pkg_names {
        pkg_name_lower = raw.strip().lower();
        if pkg_name_lower not in PACKAGES {
            print(f"Warning: unknown package '{raw}' - skipping");
            continue;
        }
        version = get_current_version(repo_root, PACKAGES[pkg_name_lower].dir);
        releases.append(release_entry(pkg_name_lower, version));
    }
    return releases;
}

def main() -> int {
    parser = argparse.ArgumentParser();
    parser.add_argument("--pr-title", `default="");
    parser.add_argument(
        "--packages",
        `default="",
        help="Comma/space separated package names; versions read from manifests"
    );
    args = parser.parse_args();
    if args.packages {
        pkg_list = [
            p
            for p in re.split(r"[,\s]+", args.packages)
            if p
        ];
        releases = parse_from_packages(pkg_list);
    } else {
        releases = parse_from_title(args.pr_title);
    }
    if not releases {
        print("No packages found to release");
        set_output("has_releases", "false");
        set_output("matrix", json.dumps({"include": []}));
        set_output("release_summary", "none");
        return 1;
    }
    releases.sort(key=lambda x : x["tier"]);
    print("Packages to release:");
    for r in releases {
        print(f"  - {r['pypi']} {r['version']} (tier {r['tier']})");
    }
    summary = ", ".join(f"{r['pypi']} {r['version']}" for r in releases);
    set_output("has_releases", "true");
    set_output("matrix", json.dumps({"include": releases}));
    set_output("release_summary", summary);
    return 0;
}

with entry:__main__ {
    sys.exit(main());
}
