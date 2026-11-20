import from pathlib { Path }

glob SKIP_DIRS: set[str] = {
         ".jac",
         "node_modules",
         ".git",
         "__pycache__",
         "dist",
         "build"
     };

def _read_shadcn_config(config: any) -> any;

def _registry_dir -> Path;

def load_registry -> dict[str, any];

def parse_style_css(style_name: str) -> dict[str, str];

def resolve_component(source: str, resolution_map: dict[str, str]) -> str;

def resolve_single_component(component_name: str, style: str) -> dict[str, any];

def _resolve_peer_deps(
    requested: list[str], registry_data: dict[str, any], existing: set[str]
) -> list[str];

obj ShadcnPaths {
    has ui_dir: Path,
        utils_file: Path,
        utils_module: str;
}

def _has_jac(path: Path) -> bool;

def _defines_cn(path: Path) -> bool;

def _inside(project_root: Path, candidate: Path) -> Path | None;

def _discover(
    project_root: Path, pattern: str, accept: Callable[[Path], bool]
) -> Path | None;

def _resolve_one(
    project_root: Path,
    shadcn_config: any,
    key: str,
    pattern: str,
    accept: Callable[[Path], bool],
    fallback: Path
) -> Path | None;

def _module_of(project_root: Path, path: Path) -> str;

def resolve_shadcn_paths(project_root: Path, shadcn_config: any) -> ShadcnPaths | None;

def _retarget_utils_import(
    content: str, ui_dir: Path, project_root: Path, utils_mod: str
) -> str;

def _update_npm_deps(config: any, npm_deps: dict[str, str]) -> None;

def add_shadcn_components(config: any, component_names: list[str]) -> bool;

def remove_shadcn_components(config: any, component_names: list[str]) -> bool;
