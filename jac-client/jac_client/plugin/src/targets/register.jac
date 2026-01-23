"""Register all build targets.

This module registers all available build targets when the plugin loads.
"""
import from .registry { get_target_registry }
import from .web_target { WebTarget }
import from .desktop_target { DesktopTarget }

"""Register all available targets."""
def register_targets() -> None {
    registry = get_target_registry();
    
    # Register web target (default)
    web_target = WebTarget();
    registry.register(web_target);
    
    # Register desktop target (placeholder for Phase 2)
    desktop_target = DesktopTarget();
    registry.register(desktop_target);
}

