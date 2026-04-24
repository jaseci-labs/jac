"""Configuration loader for Mobile target (React Native/Expo).

Configuration is loaded from jac.toml under [mobile] section.
Inherits shared init/load/_get_jac_config from TargetConfig.
"""
import from pathlib { Path }
import from typing { Any }
import from jaclang.project.config { JacConfig }
import from jac_client.plugin.src.target_config { TargetConfig }

"""Mobile target configuration loader."""
class MobileConfig(TargetConfig) {
    """Return the TOML section key for mobile config."""
    override def _section_key(self: MobileConfig) -> str;

    """Return default mobile configuration."""
    override def get_default_config(self: MobileConfig) -> dict[str, Any];

    """Get core mobile fields (name, bundle_id, version, display_name)."""
    def get_mobile_config(self: MobileConfig) -> dict[str, Any];

    """Get platforms configuration."""
    def get_platforms_config(self: MobileConfig) -> dict[str, Any];

    """Get features configuration."""
    def get_features_config(self: MobileConfig) -> dict[str, Any];

    """Get EAS build configuration."""
    def get_eas_config(self: MobileConfig) -> dict[str, Any];

    """Get app.json configuration for Expo."""
    def get_app_json_config(self: MobileConfig) -> dict[str, Any];

    """Validate required mobile configuration fields."""
    def validate(self: MobileConfig) -> None;
}
