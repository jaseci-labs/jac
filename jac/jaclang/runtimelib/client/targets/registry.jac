import from typing { Optional }
import from pathlib { Path }

class Host {
    has name: str,
        host_kind: str = 'browser',
        project_dir: Optional[Path] = None,
        `default: bool = False,
        requires_setup: bool = False,
        config_section: str = '',
        required_dependencies: list[str] = [],
        output_dir: Optional[Path] = None;

    def setup(self: Host, project_dir: Path) -> None abst;
    def build(
        self: Host,
        entry_file: Path,
        project_dir: Path,
        platform: Optional[str] = None
    ) -> Path abst;

    def dev(
        self: Host,
        entry_file: Path,
        project_dir: Path,
        port: int = 8000,
        api_port: int = 0
    ) -> None abst;

    def start(
        self: Host, entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None abst;
}

obj HostRegistry {
    has _hosts: dict[str, Host] = {};

    def register(host: Host) -> None;
    def get(name: str) -> Optional[Host];
    def get_all -> list[Host];
    def clear -> None;
}

obj HostFactory {
    def create(name: str, project_dir: Path) -> Host;
    def get_available_host_names -> list[str];
    def get_available_target_names -> list[str];
}

glob _registry: HostRegistry | None = None,
     _factory: HostFactory | None = None;

def get_host_registry -> HostRegistry {
    import from jaclang.runtimelib.client.targets.registry { HostRegistry }
    if _registry is None {
        _registry = HostRegistry();

        import from jaclang.runtimelib.client.targets.register { register_hosts }
        register_hosts();
    }
    return _registry;
}

def get_host_factory -> HostFactory {
    import from jaclang.runtimelib.client.targets.registry { HostFactory }
    if _factory is None {
        _factory = HostFactory();
    }
    return _factory;
}

def get_target_registry -> HostRegistry {
    return get_host_registry();
}

def get_target_factory -> HostFactory {
    return get_host_factory();
}
