"""Configuration loader for Desktop target (Tauri).

Configuration is loaded from jac.toml under [desktop] section.
Inherits shared init/load/_get_jac_config from TargetConfig.
"""
import from pathlib { Path }
import from typing { Any }
import from jaclang.project.config { JacConfig }
import from jac_client.plugin.src.target_config { TargetConfig }

"""Desktop target configuration loader."""
class DesktopConfig(TargetConfig) {
    """Return the TOML section key for desktop config."""
    override def _section_key(self: DesktopConfig) -> str;

    """Return default desktop configuration."""
    override def get_default_config(self: DesktopConfig) -> dict[str, Any];

    """Get core desktop fields (name, identifier, version)."""
    def get_desktop_config(self: DesktopConfig) -> dict[str, Any];

    """Get window configuration."""
    def get_window_config(self: DesktopConfig) -> dict[str, Any];

    """Get platforms configuration."""
    def get_platforms_config(self: DesktopConfig) -> dict[str, Any];

    """Get features configuration."""
    def get_features_config(self: DesktopConfig) -> dict[str, Any];

    """Get plugins configuration (which Jac plugins to bundle)."""
    def get_plugins_config(self: DesktopConfig) -> dict[str, Any];

    """Check if desktop is configured for client-only mode (no sidecar)."""
    def is_client_only(self: DesktopConfig) -> bool;

    """Validate required desktop configuration fields."""
    def validate(self: DesktopConfig) -> None;
}
