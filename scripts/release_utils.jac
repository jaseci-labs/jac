"""Shared utilities for release scripts.

This module provides the single source of truth for package metadata,
version bumping logic, and GitHub Actions output helpers.
All release-related scripts import from here to ensure consistency.
"""
import from __future__ { annotations }
import os;
import re;
import tomllib;
import from pathlib { Path }
import from typing { NamedTuple }
"""Package metadata for release scripts."""
class PackageInfo(NamedTuple) {
    has dir: str;
    has pypi: str;
    has release_notes: str = "";
    has notes_display: str = "";
}

glob PACKAGES: dict[(str, PackageInfo)] = {
         # Anchor: not published to PyPI; its version tags the GitHub Release.
         "jaclang": PackageInfo(
             dir="jac",
             pypi="jaclang",
             release_notes="docs/docs/community/release_notes/jaclang.md",
             notes_display="jaclang",
         )
         # byLLM was Tier 2 (published to PyPI as `byllm`); it is now folded into
         # jaclang (jaclang.byllm) and ships inside the binary, so it no longer
         # releases separately -- same as the earlier scale fold-in.
     };

"""Read the current version from a package's manifest.

    Prefers jac.toml; falls back to pyproject.toml for packages (e.g. jac/)
    that cannot migrate because they bootstrap the jac toolchain itself.
    """
def get_current_version(repo_root: Path, pkg_dir: str) -> str {
    jac_toml = repo_root / pkg_dir / "jac.toml";
    manifest = jac_toml
        if jac_toml.exists()
        else repo_root / pkg_dir / "pyproject.toml";
    data = tomllib.loads(manifest.read_text());
    return str(data["project"]["version"]);
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
