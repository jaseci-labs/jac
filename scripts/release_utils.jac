"""Shared utilities for release scripts.

This module provides the single source of truth for package metadata,
version bumping logic, PyPI availability checks, and GitHub Actions output helpers.
All release-related scripts import from here to ensure consistency.
"""
import from __future__ { annotations }
import os;
import re;
import urllib.error;
import urllib.request;
import from pathlib { Path }
import from typing { NamedTuple }
"""Package metadata for release scripts."""
class PackageInfo(NamedTuple) {
    has dir: str;
    has pypi: str;
    has tier: int;
    has release_notes: str = "";
    has notes_display: str = "";
    has submodules: bool = False;
    has precompile: bool = False;
    has precompile_path: str = "";
    has precompile_artifact: str = "";
    has extra_build_cmd: str = "";
    has needs_nodejs: bool = False;
    has extra_build_deps: str = "";
}
glob PACKAGES: dict[(str, PackageInfo)] = {
    "jaclang": PackageInfo(
        dir="jac",
        pypi="jaclang",
        tier=1,
        release_notes="docs/docs/community/release_notes/jaclang.md",
        notes_display="jaclang",
        submodules=True,
        precompile=True,
        precompile_path="jac/jaclang/_precompiled",
        precompile_artifact="precompiled-jaclang"
    ),
    "jac-byllm": PackageInfo(
        dir="jac-byllm",
        pypi="byllm",
        tier=2,
        release_notes="docs/docs/community/release_notes/byllm.md",
        notes_display="byllm",
        submodules=True,
        precompile=True,
        precompile_path="jac-byllm/byllm/_precompiled",
        precompile_artifact="precompiled-byllm"
    ),
    "jac-client": PackageInfo(
        dir="jac-client",
        pypi="jac-client",
        tier=2,
        release_notes="docs/docs/community/release_notes/jac-client.md",
        notes_display="jac-client",
        submodules=True,
        precompile=True,
        precompile_path="jac-client/jac_client/_precompiled",
        precompile_artifact="precompiled-client"
    ),
    "jac-scale": PackageInfo(
        dir="jac-scale",
        pypi="jac-scale",
        tier=2,
        release_notes="docs/docs/community/release_notes/jac-scale.md",
        notes_display="jac-scale",
        submodules=True,
        precompile=True,
        precompile_path="jac-scale/jac_scale/_precompiled",
        precompile_artifact="precompiled-scale",
        extra_build_cmd="jac run scripts/build_admin_ui.jac",
        needs_nodejs=True,
        extra_build_deps="jac-client"
    ),
    "jac-super": PackageInfo(
        dir="jac-super",
        pypi="jac-super",
        tier=2,
        release_notes="docs/docs/community/release_notes/jac-super.md",
        notes_display="jac-super",
        submodules=True,
        precompile=True,
        precompile_path="jac-super/jac_super/_precompiled",
        precompile_artifact="precompiled-super"
    ),
    "jac-mcp": PackageInfo(
        dir="jac-mcp",
        pypi="jac-mcp",
        tier=2,
        release_notes="docs/docs/community/release_notes/jac-mcp.md",
        notes_display="jac-mcp",
        submodules=True,
        precompile=True,
        precompile_path="jac-mcp/jac_mcp/_precompiled",
        precompile_artifact="precompiled-mcp",
        extra_build_cmd="jac run scripts/bundle_docs.jac"
    ),
    "jaseci": PackageInfo(
        dir="jaseci-package",
        pypi="jaseci",
        tier=3,
        release_notes="",
        notes_display="jaseci"
    )
},
     INTERNAL_DEPS: dict[(str, list[str])] = {
    "jaclang": [],
    "byllm": ["jaclang"],
    "jac-client": ["jaclang"],
    "jac-scale": ["jaclang"],
    "jac-super": ["jaclang"],
    "jac-mcp": ["jaclang"],
    "jaseci": [
        "jaclang",
        "byllm",
        "jac-client",
        "jac-scale",
        "jac-super",
        "jac-mcp"
    ]
},
     DEPENDENTS: dict[(str, list[str])] = {};
with entry {
    for (_pkg_key, _pkg_info) in PACKAGES.items() {
        for _dep in INTERNAL_DEPS.get(_pkg_info.pypi, []) {
            DEPENDENTS.setdefault(_dep, []).append(_pkg_key);
        }
    }
}
"""Compute the next semantic version based on bump type.

    Given a version like "1.2.3" and bump type:
      - "patch" -> "1.2.4" (bug fixes)
      - "minor" -> "1.3.0" (new features, backwards compatible)
      - "major" -> "2.0.0" (breaking changes)

    Raises ValueError if version format is invalid or bump type is unrecognized.
    """
def bump_version(current: str, bump_type: str) -> str {
    if not re.match(r"^\d+\.\d+\.\d+$", current) {
        raise ValueError(
            f"Invalid version format '{current}': expected X.Y.Z where X, Y, Z are integers"
        );
    }
    parts = current.split(".");
    (major, minor, patch) = (int(parts[0]), int(parts[1]), int(parts[2]));
    if (bump_type == "patch") {
        patch += 1;
    } elif (bump_type == "minor") {
        (minor, patch) = ((minor + 1), 0);
    } elif (bump_type == "major") {
        (major, minor, patch) = ((major + 1), 0, 0);
    } else {
        raise ValueError(
            f"Unknown bump type '{bump_type}': expected patch, minor, or major"
        );
    }
    return f"{major}.{minor}.{patch}";
}

"""Check if a specific package version already exists on PyPI.

    Used to prevent publishing duplicate versions and to wait for packages
    to become available between tier publishes. Returns True if the version
    exists, False if it doesn't or if PyPI is unreachable (fail-open for polling).
    """
def check_pypi(pypi_name: str, version: str) -> bool {
    url = f"https://pypi.org/pypi/{pypi_name}/{version}/json";
    try {
        urllib.request.urlopen(url, timeout=10);
        return True;
    } except urllib.error.HTTPError as e {
        return (e.code != 404);
    } except urllib.error.URLError {
        print(f"Warning: Could not reach PyPI to check {pypi_name} {version}");
        return False;
    }
}

"""Write a workflow output variable for GitHub Actions.

    In CI, writes to $GITHUB_OUTPUT file using heredoc syntax for multiline values.
    Locally, prints the output for debugging. These outputs can be referenced
    by subsequent workflow jobs via needs.<job>.outputs.<name>.
    """
def set_output(name: str, value: str) -> None {
    github_output = os.environ.get("GITHUB_OUTPUT");
    if github_output {
        with Path(github_output).open("a") as f {
            if ("\n" in value) {
                import uuid;
                delimiter = uuid.uuid4().hex;
                f.write(f"{name}<<{delimiter}\n{value}\n{delimiter}\n");
            } else {
                f.write(f"{name}={value}\n");
            }
        }
    } else {
        print(f"  [output] {name}={value}");
    }
}
