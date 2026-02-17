"""Target registry for build targets (web, desktop, mobile, etc.).

This module provides a registry system for managing different build targets.
Each target is a class that inherits from the base ClientTarget class.
"""
import from typing { Optional }
import from pathlib { Path }

"""Enum for supported client target types."""
enum TargetType {
    WEB = "web",
    DESKTOP = "desktop",
    PWA = "pwa"
}

"""Get TargetType from string name."""
def get_target_type(name: str) -> TargetType {
    name_lower = name.lower().strip();
    if name_lower == "" or name_lower == "web" {
        return TargetType.WEB;
    }
    if name_lower == "desktop" {
        return TargetType.DESKTOP;
    }
    if name_lower == "pwa" {
        return TargetType.PWA;
    }
    raise ValueError(
        f"Unknown target: {name}. Available: {', '.join([t.value for t in TargetType])}"
    ) ;
}

"""Base class for all build targets.

All targets must inherit from this class and implement the required methods.
"""
class ClientTarget {
    has name: str,
        project_dir: Optional[Path] = None,
        default: bool = False,
        requires_setup: bool = False,
        config_section: str = "",
        required_dependencies: list[str] = [],
        output_dir: Optional[Path] = None;

    """Setup the target (one-time initialization)."""
    def setup(self: ClientTarget, project_dir: Path) -> None abs;

    """Build the target."""
    def build(
        self: ClientTarget,
        entry_file: Path,
        project_dir: Path,
        platform: Optional[str] = None
    ) -> Path abs;

    """Start dev server for the target."""
    def dev(
        self: ClientTarget, entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None abs;

    """Start the target (production mode - build and run)."""
    def start(
        self: ClientTarget, entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None abs;
}

"""Central registry for build targets.

This is a singleton that collects all build targets registered by plugins.
The CLI uses this registry to delegate build operations to the appropriate target.
"""
obj TargetRegistry {
    has _targets: dict[str, ClientTarget] = {},
        _default_target: Optional[str] = None;

    """Register a new build target."""
    def register(target: ClientTarget) -> None;

    """Get a target by name."""
    def get(name: str) -> Optional[ClientTarget];

    """Get the default target."""
    def get_default -> Optional[ClientTarget];

    """Get all registered targets."""
    def get_all -> list[ClientTarget];

    """Check if a target is registered."""
    def `has(name: str) -> bool;

    """Set the default target."""
    def set_default(name: str) -> None;

    """Clear all registered targets (for testing)."""
    def clear -> None;
}

"""Factory for creating target instances with lazy loading.

This singleton factory creates target instances on demand.
WebTarget is always available (default), Desktop/PWA are lazy-loaded.
"""
obj TargetFactory {
    has _web_target: Optional[ClientTarget] = None,
        _cached_targets: dict[str, ClientTarget] = {};

    """Create a target by name string (lazy loading for non-web targets)."""
    def create(name: str, project_dir: Path) -> ClientTarget;

    """Create a target by TargetType enum (preferred)."""
    def create_by_type(target_type: TargetType, project_dir: Path) -> ClientTarget;

    """Get the default (web) target, cached for fast access."""
    def get_default(project_dir: Path) -> ClientTarget;

    """Get list of available target types."""
    def get_available_targets -> list[TargetType];

    """Get list of available target names as strings."""
    def get_available_target_names -> list[str];

    """Clear cached targets (for testing)."""
    def clear_cache -> None;
}

# Global singleton instances
glob _registry: TargetRegistry | None = None,
     _factory: TargetFactory | None = None;

"""Get or create the global target registry."""
def get_target_registry -> TargetRegistry {
    import from jac_client.plugin.src.targets.registry { TargetRegistry }
    global _registry;
    if _registry is None {
        _registry = TargetRegistry();
    }
    return _registry;
}

"""Get or create the global target factory."""
def get_target_factory -> TargetFactory {
    import from jac_client.plugin.src.targets.registry { TargetFactory }
    global _factory;
    if _factory is None {
        _factory = TargetFactory();
    }
    return _factory;
}
