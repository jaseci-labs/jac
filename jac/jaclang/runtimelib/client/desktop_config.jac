"""Configuration loader for jac-desktop.

Loads from jac.toml under [plugins.desktop], inheriting PluginConfigBase like
jac-scale and jac-client. Provides the app identity + window geometry the native
desktop target bakes into the generated host.
"""
import from pathlib { Path }
import from jaclang.project.plugin_config { PluginConfigBase }

"""Desktop app identity (name, identifier, version)."""
obj DesktopIdentity {
    has name: str,
        identifier: str,
        version: str;
}

"""Main window geometry from [plugins.desktop.window]."""
obj WindowConfig {
    has title: str,
        width: int = 1200,
        height: int = 800,
        min_width: int = 800,
        min_height: int = 600,
        resizable: bool = True;

    static def from_dict(
        data: dict[str, any], title_fallback: str = ""
    ) -> WindowConfig {
        title = str(data.get("title", title_fallback) or title_fallback);
        return WindowConfig(
            title=title,
            width=int(data.get("width", 1200)),
            height=int(data.get("height", 800)),
            min_width=int(data.get("min_width", 800)),
            min_height=int(data.get("min_height", 600)),
            resizable=bool(data.get("resizable", True))
        );
    }
}

"""Default [plugins.desktop] values before merging user jac.toml."""
obj DesktopDefaultConfig {
    has name: str,
        identifier: str,
        version: str,
        window: WindowConfig;

    def to_dict -> dict[str, any] {
        return {
            'name': self.name,
            'identifier': self.identifier,
            'version': self.version,
            'window': {
                'title': self.window.title,
                'width': self.window.width,
                'height': self.window.height,
                'min_width': self.window.min_width,
                'min_height': self.window.min_height,
                'resizable': self.window.resizable,
                'fullscreen': False
            }
        };
    }
}

"""Desktop plugin configuration loader."""
class JacDesktopConfig(PluginConfigBase) {
    override def get_plugin_name(self: JacDesktopConfig) -> str;
    override def get_default_config(self: JacDesktopConfig) -> dict[str, any];
    def get_identity(self: JacDesktopConfig) -> DesktopIdentity;
    def get_window_config(self: JacDesktopConfig) -> WindowConfig;
    def validate(self: JacDesktopConfig) -> None;
}

glob _desktop_config_instance: JacDesktopConfig | None = None;

"""Get or create the desktop config singleton."""
def get_desktop_config(project_dir: Path | None = None) -> JacDesktopConfig;

"""Reset cached desktop config (for tests)."""
def reset_desktop_config -> None;
