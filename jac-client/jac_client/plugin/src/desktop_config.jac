"""Configuration loader for Desktop target (Tauri).

This module provides configuration access for the desktop target.
Configuration is loaded from jac.toml under [desktop] section.

Similar to JacClientConfig but loads [desktop] directly (not under [plugins]).
"""
import from pathlib { Path }
import from typing { Any }
import from jaclang.project.config { JacConfig, get_config }

"""Desktop target configuration loader.

Provides access to desktop/Tauri configuration
from the [desktop] section of jac.toml.
"""
class DesktopConfig {
    has project_dir: Path | None = None,
        _config: dict[str, Any] | None = None,
        _jac_config: JacConfig | None = None;

    def init(self: DesktopConfig, project_dir: Path | None = None) -> None;
    def load(self: DesktopConfig) -> dict[str, Any];
    def get_desktop_config(self: DesktopConfig) -> dict[str, Any];
    def get_window_config(self: DesktopConfig) -> dict[str, Any];
    def get_platforms_config(self: DesktopConfig) -> dict[str, Any];
    def get_features_config(self: DesktopConfig) -> dict[str, Any];
    def validate(self: DesktopConfig) -> None;
    def get_default_config(self: DesktopConfig) -> dict[str, Any];
    # def _get_jac_config(self: DesktopConfig) -> JacConfig;
}
