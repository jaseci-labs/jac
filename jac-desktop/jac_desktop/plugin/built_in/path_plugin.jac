"""Path resolution plugin for the Jac desktop IPC system.

Resolves standard OS paths (home, data, config, cache, downloads, temp, etc.)
using os/pathlib. No native callbacks needed — purely Python stdlib.

Transpiled to dependency-free Python at build time.
"""
import os;
import tempfile;
import from pathlib { Path }
import from desktop_plugin { PluginError, DesktopPlugin }


"""Provides OS path resolution for standard directories."""
obj PathPlugin(DesktopPlugin) {
    def init {
        super.init("jac.path");
    }

    def handle(command: str, args: dict) -> dict {
        if command == "home" {
            return {"path": str(Path.home())};
        }
        if command == "data" {
            return {"path": self._resolve_xdg("XDG_DATA_HOME", ".local/share")};
        }
        if command == "config" {
            return {"path": self._resolve_xdg("XDG_CONFIG_HOME", ".config")};
        }
        if command == "cache" {
            return {"path": self._resolve_xdg("XDG_CACHE_HOME", ".cache")};
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
            base = self._resolve_xdg("XDG_DATA_HOME", ".local/share");
            app_name = args.get("app", "jac-desktop");
            return {"path": str(Path(base) / app_name)};
        }
        if command == "separator" {
            return {"separator": os.sep};
        }
        if command == "join" {
            parts = args.get("parts", []);
            if not parts {
                raise PluginError("INVALID_ARGS", "'parts' is required for 'join'");
            }
            return {"path": str(Path(*parts))};
        }
        if command == "resolve" {
            p = args.get("path", "");
            if not p {
                raise PluginError("INVALID_ARGS", "'path' is required for 'resolve'");
            }
            return {"path": str(Path(p).expanduser().resolve())};
        }
        return super.handle(command, args);
    }

    """Resolve an XDG directory with fallback."""
    def _resolve_xdg(env_var: str, fallback: str) -> str {
        val = os.environ.get(env_var);
        if val {
            return str(Path(val).expanduser().resolve());
        }
        return str(Path.home() / fallback);
    }
}
