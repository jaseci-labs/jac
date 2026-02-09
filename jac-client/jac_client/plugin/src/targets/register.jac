"""Register all build targets.

This module registers all available build targets when the plugin loads.
"""
import from jac_client.plugin.src.targets.registry { get_target_registry }
import from jac_client.plugin.src.targets.web_target { WebTarget }
import from jac_client.plugin.src.targets.desktop_target { DesktopTarget }
import from jac_client.plugin.src.targets.mobile_target { MobileTarget }
# Note: Jac's annex pass should auto-discover .impl.jac files automatically
# The impl files in impl/ directory should be loaded when the base classes are imported
"""Register all available targets."""
def register_targets -> None {
    registry = get_target_registry();

    # Register web target (default)
    web_target = WebTarget();
    registry.register(web_target);

    # Register desktop target (placeholder for Phase 2)
    desktop_target = DesktopTarget();
    registry.register(desktop_target);

    # Register mobile target (Expo + WebView)
    mobile_target = MobileTarget();
    registry.register(mobile_target);
}
