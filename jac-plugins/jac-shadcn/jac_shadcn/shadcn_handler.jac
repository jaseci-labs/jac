"""Shadcn component handler — fetch, resolve dependencies, install/remove components.

Reads [jac-shadcn] config from jac.toml for style + registry URL,
then fetches resolved components and writes them to components/ui/.
"""

import from pathlib { Path }

"""Read [jac-shadcn] section from config._raw_data."""
def _read_shadcn_config(config: any) -> any;

"""HTTP GET with Accept: application/json. Unwraps TransportResponse envelope if present.
Pass silent=True to suppress the console.error on failure (used by feature-detection
calls like the /options try-fetch in validation)."""
def _fetch_json(url: str, silent: bool = False) -> any;

"""BFS over peerComponents to auto-resolve missing dependencies."""
def _resolve_peer_deps(requested: list, registry_data: dict, existing: set) -> list;

"""Reject filenames that could escape ui_dir or land outside the .cl.jac convention."""
def _validate_component_filename(name: str, filename: any) -> str | None;

"""Patch a nested table in jac.toml with key-value pairs. Creates the section
if missing. Uses tomlkit so comments/formatting round-trip cleanly."""
def _patch_toml_section(toml_path: Path, section_path: list, deps: dict) -> None;

"""Update [dependencies.npm] in the project's jac.toml with new npm deps."""
def _update_npm_deps(config: any, npm_deps: dict) -> None;

"""Remove keys from [dependencies.npm] if present. Returns the keys that were
actually pruned. Silently skips missing keys."""
def _remove_npm_deps(toml_path: Path, keys: list) -> list;

"""Fetch and install shadcn components from registry into components/ui/.
Accepts plain names ('button') or pinned names ('button@1.0.0')."""
def add_shadcn_components(config: any, component_names: list) -> bool;

"""Remove component files from components/ui/. Also prunes npm deps owned
exclusively by the removed components, unless keep_deps is True."""
def remove_shadcn_components(
    config: any, component_names: list, keep_deps: bool = False
) -> bool;

"""Initialize shadcn theme in an existing project. Fetches global.css and
config from the registry at [jac-shadcn].registry (or the public default)
using the given theme params. `install_set` selects which components are
installed: "essential" (10-component curated starter set, default),
"all" (every component the registry returns in default_components), or
"bare" (theme/css only, no components)."""
def init_shadcn_theme(
    config: any,
    style: str = "nova",
    base_color: str = "neutral",
    theme: str = "neutral",
    font: str = "figtree",
    radius: str = "default",
    menu_accent: str = "subtle",
    install_set: str = "essential"
) -> bool;

"""Re-fetch installed components from the registry, replacing their files
in components/ui/. Any theme param given (style, base_color, etc.) is also
written back to [jac-shadcn] in jac.toml so future installs match. If
`names` is empty, every component in the lockfile is upgraded; otherwise
only the named ones."""
def upgrade_shadcn_components(
    config: any,
    names: list,
    style: str | None = None,
    base_color: str | None = None,
    theme: str | None = None,
    font: str | None = None,
    radius: str | None = None,
    menu_accent: str | None = None
) -> bool;

"""Print available + installed components. With installed_only=True, only
the lockfile entries are shown (no registry call)."""
def list_shadcn_components(config: any, installed_only: bool = False) -> bool;

"""Drop npm deps from [dependencies.npm] that no installed component still
needs. Use after manual edits to the lockfile or when deps drifted."""
def prune_orphan_deps(config: any) -> bool;

"""Suggested close matches for a misspelt component name. Used by error
messages to make 'no such component' actionable."""
def _suggest_close_matches(name: str, candidates: list, limit: int = 3) -> list;
