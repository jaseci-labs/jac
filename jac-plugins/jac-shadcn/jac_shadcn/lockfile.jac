"""jac-shadcn lockfile — tracks installed components, their versions, and the
npm dependencies each one brought in. Used by `add`/`init` to record installs
and by `remove` to compute orphaned npm deps for pruning.

Format (`<project_root>/jac-shadcn.lock`):

    version = 1

    [components.button]
    version = "1.0.0"
    npm_deps = ["class-variance-authority", "radix-ui"]

    [components.dialog]
    version = "1.0.0"
    npm_deps = ["@radix-ui/react-dialog"]
"""

import from pathlib { Path }

"""Path to the lockfile inside a project."""
def lockfile_path(project_root: Path) -> Path;

"""Load lockfile as a plain dict. Returns {} if the file does not exist."""
def load_lockfile(project_root: Path) -> dict;

"""Write lockfile data. Creates the file if missing. Preserves comments on
existing files."""
def save_lockfile(project_root: Path, data: dict) -> None;

"""Upsert one component entry."""
def record_install(
    project_root: Path, name: str, version: str, npm_deps: list
) -> None;

"""Drop one component entry. No-op if missing."""
def record_remove(project_root: Path, name: str) -> None;

"""Return the npm deps that were owned exclusively by `removed_names`
(i.e. not declared by any other installed component). The caller decides
whether to actually prune them from jac.toml."""
def compute_orphan_deps(project_root: Path, removed_names: list) -> list;

"""Return the recorded version for `name`, or None if not installed."""
def installed_version(project_root: Path, name: str) -> str | None;
