"""Shadcn component handler - resolve dependencies, install/remove bundled components.

Components ship with the plugin under registry/ (components/ui, styles, registry.json).
Reads [jac-shadcn] config from jac.toml for style, resolves cn-* tokens against the
bundled style CSS, then writes components to components/ui/. No network access.
"""

"""Read [jac-shadcn] section from config._raw_data."""
def _read_shadcn_config(config: any) -> any;

"""Locate the bundled registry directory (components/ui, styles, registry.json)."""
def _registry_dir -> any;

"""Load the bundled registry.json manifest."""
def load_registry -> dict;

"""Parse a bundled style CSS file into a {cn-token: tailwind-classes} map."""
def parse_style_css(style_name: str) -> dict;

"""Replace all cn-* tokens in component source with resolved Tailwind classes."""
def resolve_component(source: str, resolution_map: dict) -> str;

"""Resolve a single bundled component with the chosen style applied."""
def resolve_single_component(component_name: str, style: str) -> dict;

"""BFS over peerComponents to auto-resolve missing dependencies."""
def _resolve_peer_deps(requested: list, registry_data: dict, existing: set) -> list;

"""Text-patch [dependencies.npm] in jac.toml with new npm deps."""
def _update_npm_deps(config: any, npm_deps: dict) -> None;

"""Install bundled shadcn components into components/ui/."""
def add_shadcn_components(config: any, component_names: list) -> bool;

"""Remove component files from components/ui/."""
def remove_shadcn_components(config: any, component_names: list) -> bool;
