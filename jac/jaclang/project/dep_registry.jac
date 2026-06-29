import from typing { Any, Callable }
import from pathlib { Path }

obj DependencyType {
    has name: str,
        dev_name: str,
        cli_flag: str,
        install_dir: str,
        install_handler: Callable,
        remove_handler: Callable,
        install_all_handler: Callable | None = None;
}

obj DependencyRegistry {
    has _types: dict[str, DependencyType] = {},
        _flag_map: dict[str, str] = {};

    def register(dep_type_info: dict[(str, Any)]) -> None;
    def get_by_name(name: str) -> DependencyType | None;
    def get_by_flag(flag: str) -> DependencyType | None;
    def get_all -> dict[str, DependencyType];
    def get_all_flags -> list[str];
    def has_type(name: str) -> bool;
    def clear -> None;
}

glob _registry: DependencyRegistry | None = None;

def get_dependency_registry -> DependencyRegistry;

def initialize_dependency_registry -> None;
