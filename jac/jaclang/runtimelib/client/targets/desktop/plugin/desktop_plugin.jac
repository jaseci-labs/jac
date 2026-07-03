import base64;
import subprocess;
import sys;
import ctypes;

obj PluginError(Exception) {
    has code: str,
        message: str;

    def init(code: str, message: str) {
        self.code = code;
        self.message = message;
        Exception.__init__(self, f"[{code}] {message}");
    }
}


obj ErrorCode {
    static has INVALID_ARGS: str = "INVALID_ARGS",
        FORBIDDEN: str = "FORBIDDEN",
        NOT_FOUND: str = "NOT_FOUND",
        UNAVAILABLE: str = "UNAVAILABLE",
        UNSUPPORTED: str = "UNSUPPORTED",
        TIMEOUT: str = "TIMEOUT",
        NOT_READY: str = "NOT_READY",
        FAILED: str = "FAILED",
        UNKNOWN_COMMAND: str = "UNKNOWN_COMMAND",
        PLUGIN_NOT_FOUND: str = "PLUGIN_NOT_FOUND",
        INTERNAL_ERROR: str = "INTERNAL_ERROR";
}


obj DesktopPlugin {
    has plugin_name: str;

    static def _coerce_config(config: object) -> dict {
        if isinstance(config, dict) {
            return config;
        }
        return {};
    }

    static def _config_enabled(config: object) -> bool {
        return config is not False and config is not None;
    }

    def init { }
    def setup(wv_handle: int, wv_lib: ctypes.CDLL) { }
    def setup_cef(host: object) { }
    def handle(command: str, args: dict) -> dict {
        raise PluginError(
            ErrorCode.UNKNOWN_COMMAND,
            f"Plugin '{self.plugin_name}' has no command '{command}'"
        );
    }

    def _detect_platform -> str {
        if sys.platform.startswith("linux") {
            return "linux";
        }
        if sys.platform == "darwin" {
            return "darwin";
        }
        if sys.platform == "win32" {
            return "windows";
        }
        return sys.platform;
    }
}


obj OsPlugin(DesktopPlugin) {
    def _escape_applescript(s: str) -> str {
        return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace(
            "\r", "\\r"
        );
    }

    def _escape_powershell(s: str) -> str {
        return s.replace("'", "''");
    }

    def _run_powershell(ps: str, timeout: int = 60, check: bool = False) {
        encoded = base64.b64encode(ps.encode("utf-16-le")).decode("ascii");
        return subprocess.run(
            ["powershell", "-EncodedCommand", encoded],
            check=check,
            capture_output=True,
            timeout=timeout
        );
    }
}
