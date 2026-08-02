import from pathlib { Path }
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

obj DispatchConfig {
    has timeout_s: float = 30.0,
        max_queue: int = 128,
        debug: bool = False;

    static def from_dict(data: dict[str, any]) -> DispatchConfig {
        return DispatchConfig(
            timeout_s=float(data.get("timeout_s", 30.0)),
            max_queue=int(data.get("max_queue", 128)),
            debug=bool(data.get("debug", False))
        );
    }
}

# Capabilities the opt-in [desktop.http] FastAPI sidecar can expose. Kept in sync
# with the sidecar registration in
# runtimelib/client/targets/desktop/native/http_sidecar.jac.
glob HTTP_CAPABILITIES: tuple = ("multipart", "webhooks", "websockets", "openapi");

obj HttpConfig {
    has enabled: bool = False,
        capabilities: list[str] = [],
        port: int = 0;

    static def from_dict(data: dict[str, any]) -> HttpConfig {
        raw_caps = data.get("capabilities", []);
        caps: list[str] = [];
        if isinstance(raw_caps, list) {
            for c in raw_caps {
                caps.append(str(c));
            }
        }
        return HttpConfig(
            enabled=bool(data.get("enabled", False)),
            capabilities=caps,
            port=int(data.get("port", 0))
        );
    }

    def to_dict -> dict[str, any] {
        return {
            "enabled": self.enabled,
            "capabilities": list(self.capabilities),
            "port": self.port
        };
    }
}

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

class JacDesktopConfig(PluginConfigBase) {
    override def get_plugin_name(self: JacDesktopConfig) -> str;
    override def get_default_config(self: JacDesktopConfig) -> dict[str, any];
    def get_identity(self: JacDesktopConfig) -> DesktopIdentity;
    def get_window_config(self: JacDesktopConfig) -> WindowConfig;
    def get_dispatch_config(self: JacDesktopConfig) -> DispatchConfig;
    def get_http_config(self: JacDesktopConfig) -> HttpConfig;
    def get_engine(self: JacDesktopConfig) -> str;
    def get_plugin_configs(self: JacDesktopConfig) -> dict[str, any];
    def validate(self: JacDesktopConfig) -> None;
}

glob _desktop_config_instance: JacDesktopConfig | None = None;

def get_desktop_config(project_dir: Path | None = None) -> JacDesktopConfig;

def reset_desktop_config -> None;
