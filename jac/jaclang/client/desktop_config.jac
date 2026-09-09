import from pathlib { Path }
import from jaclang.comptime { fields, get_field }
import from jaclang.project.plugin_config { PluginConfigBase }

obj DesktopIdentity {
    has name: str,
        identifier: str,
        version: str;
}

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
        kw: dict[str, any] = {
            "title": str(data.get("title", title_fallback) or title_fallback)
        };
        comptime for f in fields(WindowConfig) {
            comptime if f.name != "title" {
                kw[f.name] = f.`type(data.get(f.name, f.`default));
            }
        }
        return WindowConfig(**kw);
    }
}

obj DispatchConfig {
    has timeout_s: float = 30.0,
        max_queue: int = 128,
        debug: bool = False;

    static def from_dict(data: dict[str, any]) -> DispatchConfig {
        kw: dict[str, any] = {};
        comptime for f in fields(DispatchConfig) {
            kw[f.name] = f.`type(data.get(f.name, f.`default));
        }
        return DispatchConfig(**kw);
    }
}

obj DesktopDefaultConfig {
    has name: str,
        identifier: str,
        version: str,
        window: WindowConfig;

    def to_dict -> dict[str, any] {
        window: dict[str, any] = {};
        comptime for f in fields(WindowConfig) {
            window[f.name] = get_field(self.window, f.name);
        }
        window['fullscreen'] = False;
        return {
            'name': self.name,
            'identifier': self.identifier,
            'version': self.version,
            'window': window
        };
    }
}

class JacDesktopConfig(PluginConfigBase) {
    override def get_plugin_name(self: JacDesktopConfig) -> str;
    override def get_default_config(self: JacDesktopConfig) -> dict[str, any];
    def get_identity(self: JacDesktopConfig) -> DesktopIdentity;
    def get_window_config(self: JacDesktopConfig) -> WindowConfig;
    def get_dispatch_config(self: JacDesktopConfig) -> DispatchConfig;
    def get_engine(self: JacDesktopConfig) -> str;
    def get_backend(self: JacDesktopConfig) -> str;
    def get_plugin_configs(self: JacDesktopConfig) -> dict[str, any];
    def validate(self: JacDesktopConfig) -> None;
}

glob _desktop_config_instance: JacDesktopConfig | None = None;

def get_desktop_config(project_dir: Path | None = None) -> JacDesktopConfig;

def reset_desktop_config -> None;
