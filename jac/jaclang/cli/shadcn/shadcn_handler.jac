def _read_shadcn_config(config: any) -> any;

def _registry_dir -> any;

def load_registry -> dict;

def parse_style_css(style_name: str) -> dict;

def resolve_component(source: str, resolution_map: dict) -> str;

def resolve_single_component(component_name: str, style: str) -> dict;

def _resolve_peer_deps(requested: list, registry_data: dict, existing: set) -> list;

def _update_npm_deps(config: any, npm_deps: dict) -> None;

def add_shadcn_components(config: any, component_names: list) -> bool;

def remove_shadcn_components(config: any, component_names: list) -> bool;
