"""Target registry for build targets (web, desktop, mobile, etc.).

This module provides a registry system for managing different build targets.
Each target is a class that inherits from the base Target class.
"""
import from typing { Optional }
import from pathlib { Path }

"""Base class for all build targets.

All targets must inherit from this class and implement the required methods.
"""
class Target {
    has name: str;                    # Target name: "web", "desktop", "android", "ios"
    has default: bool = False;        # Is this the default target?
    has requires_setup: bool = False; # Does this target need setup?
    has config_section: str = "";     # Section in jac.toml (e.g., "desktop")
    has required_dependencies: list[str] = [];  # Required npm/system dependencies
    has output_dir: Optional[Path] = None;  # Where build outputs go

    """Setup the target (one-time initialization)."""
    def setup(self: Target, project_dir: Path) -> None abs;

    """Build the target."""
    def build(self: Target, entry_file: Path, project_dir: Path, platform: Optional[str] = None) -> Path abs;

    """Start dev server for the target."""
    def dev(self: Target, entry_file: Path, project_dir: Path) -> None abs;

    """Start the target (production mode - build and run)."""
    def start(self: Target, entry_file: Path, project_dir: Path) -> None abs;
}

"""Central registry for build targets.

This is a singleton that collects all build targets registered by plugins.
The CLI uses this registry to delegate build operations to the appropriate target.
"""
obj TargetRegistry {
    has _targets: dict[str, Target] = {},
        _default_target: Optional[str] = None;

    """Register a new build target."""
    def register(target: Target) -> None;

    """Get a target by name."""
    def get(name: str) -> Optional[Target];

    """Get the default target."""
    def get_default() -> Optional[Target];

    """Get all registered targets."""
    def get_all() -> list[Target];

    """Check if a target is registered."""
    def has(name: str) -> bool;

    """Set the default target."""
    def set_default(name: str) -> None;

    """Clear all registered targets (for testing)."""
    def clear() -> None;
}

# Global singleton instance
glob _registry: TargetRegistry | None = None;

"""Get or create the global target registry."""
def get_target_registry() -> TargetRegistry {
    import from jac_client.plugin.src.targets.registry { TargetRegistry }
    global _registry;
    if _registry is None {
        _registry = TargetRegistry();
    }
    return _registry;
}
