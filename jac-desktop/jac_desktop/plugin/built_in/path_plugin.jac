"""Path resolution plugin for the Jac desktop IPC system.

Resolves standard OS paths (home, data, config, cache, downloads, temp, etc.)
using os/pathlib. No native callbacks needed — purely Python stdlib.

Transpiled to dependency-free Python at build time.
"""
import os;
import tempfile;
import from pathlib { Path }
import from desktop_plugin { PluginError, ErrorCode, DesktopPlugin }
import from manifest { PluginManifest, PluginContext }


"""Provides OS path resolution for standard directories."""
obj PathPlugin(DesktopPlugin) {
    has plugin_name: str = "jac.path";

    static def manifest -> PluginManifest {
        return PluginManifest(
            name="jac.path",
            config_key="path",
            module="built_in.path_plugin",
            class_name="PathPlugin",
            default_on=False
        );
    }

    static def build(ctx: PluginContext, config: object) -> DesktopPlugin {
        return PathPlugin();
    }

    def init {
        self.plugin_name = "jac.path";
    }

    def handle(command: str, args: dict) -> dict {
        if command == "home" {
            return {"path": str(Path.home())};
        }
        if command == "data" {
            return {"path": self.resolve_xdg("XDG_DATA_HOME", ".local/share")};
        }
        if command == "config" {
            return {"path": self.resolve_xdg("XDG_CONFIG_HOME", ".config")};
        }
        if command == "cache" {
            return {"path": self.resolve_xdg("XDG_CACHE_HOME", ".cache")};
        }
        if command == "downloads" {
            dl = Path.home() / "Downloads";
            return {"path": str(dl)};
        }
        if command == "documents" {
            docs = Path.home() / "Documents";
            return {"path": str(docs)};
        }
        if command == "temp" {
            return {"path": tempfile.gettempdir()};
        }
        if command == "app_data" {
            base = self.resolve_xdg("XDG_DATA_HOME", ".local/share");
            app_name = args.get("app", "jac-desktop");
            return {"path": str(Path(base) / app_name)};
        }
        if command == "separator" {
            return {"separator": os.sep};
        }
        if command == "join" {
            parts = args.get("parts", []);
            if not parts {
                raise PluginError(
                    ErrorCode.INVALID_ARGS, "'parts' is required for 'join'"
                );
            }
            return {"path": str(Path(*parts))};
        }
        if command == "resolve" {
            p = args.get("path", "");
            if not p {
                raise PluginError(
                    ErrorCode.INVALID_ARGS, "'path' is required for 'resolve'"
                );
            }
            return {"path": str(Path(p).expanduser().resolve())};
        }
        return super.handle(command, args);
    }

    """Resolve an XDG directory with platform-appropriate fallback."""
    def resolve_xdg(env_var: str, fallback: str) -> str {
        val = os.environ.get(env_var);
        if val {
            return str(Path(val).expanduser().resolve());
        }
        platform = self._detect_platform();
        if platform == "windows" {
            if env_var == "XDG_CONFIG_HOME" {
                base = os.environ.get(
                    "APPDATA", str(Path.home() / "AppData" / "Roaming")
                );
                return str(Path(base).expanduser().resolve());
            }
            base = os.environ.get(
                "LOCALAPPDATA", str(Path.home() / "AppData" / "Local")
            );
            return str(Path(base).expanduser().resolve());
        }
        if platform == "darwin" {
            if env_var == "XDG_CACHE_HOME" {
                return str(Path.home() / "Library" / "Caches");
            }
            return str(Path.home() / "Library" / "Application Support");
        }
        return str(Path.home() / fallback);
    }
}
