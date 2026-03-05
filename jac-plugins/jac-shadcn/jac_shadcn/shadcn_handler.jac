"""Shadcn component handler — fetch, resolve dependencies, install/remove components.

Reads [jac-shadcn] config from jac.toml for style + registry URL,
then fetches resolved components and writes them to components/ui/.
"""

"""Read [jac-shadcn] section from config._raw_data."""
def _read_shadcn_config(config: Any) -> Any;

"""HTTP GET with Accept: application/json. Unwraps TransportResponse envelope if present."""
def _fetch_json(url: str) -> Any;

"""BFS over peerComponents to auto-resolve missing dependencies."""
def _resolve_peer_deps(requested: list, registry_data: dict, existing: set) -> list;

"""Text-patch [dependencies.npm] in jac.toml with new npm deps."""
def _update_npm_deps(config: Any, npm_deps: dict) -> None;

"""Fetch and install shadcn components from registry into components/ui/."""
def add_shadcn_components(config: Any, component_names: list) -> bool;

"""Remove component files from components/ui/."""
def remove_shadcn_components(config: Any, component_names: list) -> bool;
