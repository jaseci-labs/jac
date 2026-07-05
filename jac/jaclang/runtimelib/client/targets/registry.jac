import from typing { Optional }
import from pathlib { Path }

enum TargetType {
    WEB = "web",
    DESKTOP = "desktop",
    DESKTOP_CEF = "cef",
    PWA = "pwa",
    STATIC = "static",
    MOBILE = "mobile",
    REACT_NATIVE = "react-native"
}

def get_target_type(name: str) -> TargetType {
    name_lower = name.lower().strip();
    if name_lower == "" or name_lower == "web" {
        return TargetType.WEB;
    }
    if name_lower == "desktop" {
        return TargetType.DESKTOP;
    }
    if name_lower == "cef" {
        return TargetType.DESKTOP_CEF;
    }
    if name_lower == "pwa" {
        return TargetType.PWA;
    }
    if name_lower == "static" {
        return TargetType.STATIC;
    }
    if name_lower == "mobile" {
        return TargetType.MOBILE;
    }

    if name_lower in ("react-native", "react_native", "rn") {
        return TargetType.REACT_NATIVE;
    }
    raise ValueError(
        f"Unknown target: {name}. Available: {', '.join([t.value for t in TargetType])}"
    );
}

class ClientTarget {
    has name: str,
        project_dir: Optional[Path] = None,
        default: bool = False,
        requires_setup: bool = False,
        config_section: str = "",
        required_dependencies: list[str] = [],
        output_dir: Optional[Path] = None;

    def setup(self: ClientTarget, project_dir: Path) -> None abs;
    def build(
        self: ClientTarget,
        entry_file: Path,
        project_dir: Path,
        platform: Optional[str] = None
    ) -> Path abs;

    def dev(
        self: ClientTarget,
        entry_file: Path,
        project_dir: Path,
        port: int = 8000,
        api_port: int = 0
    ) -> None abs;

    def start(
        self: ClientTarget, entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None abs;
}

obj TargetRegistry {
    has _targets: dict[str, ClientTarget] = {};

    def register(target: ClientTarget) -> None;
    def get(name: str) -> Optional[ClientTarget];
    def get_all -> list[ClientTarget];
    def clear -> None;
}

obj TargetFactory {
    def create(name: str, project_dir: Path) -> ClientTarget;
    def get_available_target_names -> list[str];
}

glob _registry: TargetRegistry | None = None,
     _factory: TargetFactory | None = None;

def get_target_registry -> TargetRegistry {
    import from jaclang.runtimelib.client.targets.registry { TargetRegistry }
    global _registry;
    if _registry is None {
        _registry = TargetRegistry();
    }
    return _registry;
}

def get_target_factory -> TargetFactory {
    import from jaclang.runtimelib.client.targets.registry { TargetFactory }
    global _factory;
    if _factory is None {
        _factory = TargetFactory();
    }
    return _factory;
}
