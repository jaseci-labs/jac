"""Base types for the Jac desktop plugin IPC system.

Defines PluginError (structured error for command failures) and DesktopPlugin
(abstract base for capability plugins). Every built-in plugin subclasses
DesktopPlugin and raises PluginError on validation / permission failures.

Transpiled to dependency-free Python at build time. Runs in the embedded CPython
with only the stdlib (no jaclang).
"""

import base64;
import subprocess;
import sys;
import ctypes;

"""Structured error raised by a plugin when a command fails."""
obj PluginError(Exception) {
    has code: str,
        message: str;

    def init(code: str, message: str) {
        self.code = code;
        self.message = message;
        Exception.__init__(self, f"[{code}] {message}");
    }
}


"""Abstract base for capability plugins.

Subclasses override handle(command, args) to implement their commands.
The plugin_host dispatches requests to the correct plugin by plugin_name.
"""
obj DesktopPlugin {
    has plugin_name: str;

    """Normalize a config value to a dict.

Plugins accept True (from `fs = true`), False, a dict with sub-settings,
or None/missing. This helper collapses the non-dict forms so each plugin
init() can assume it always receives a dict.
"""
    static def _coerce_config(config: object) -> dict {
        if isinstance(config, dict) {
            return config;
        }
        return {};
    }

    """True when a config value means 'enabled'.

Only an explicit False (or None/missing) disables the plugin.
"""
    static def _config_enabled(config: object) -> bool {
        return config is not False and config is not None;
    }

    def init { }
    """Register a command handler. Enables command-map dispatch."""
    def register_command(name: str, handler: callable) {
        if not hasattr(self, "_command_map") {
            self._command_map = {};
        }
        self._command_map[name] = handler;
    }

    """Receive the live webview handle and ctypes lib after the native webview is created.

    Default is a no-op; override in plugins that need to call back into libwebview
    (e.g. WindowPlugin). Called by PluginHost.setup() once the webview exists.
    """
    def setup(wv_handle: int, wv_lib: ctypes.CDLL) { }

    """Handle a command from JS. Returns a dict result or raises PluginError.

    First checks the command map; if not found, raises UNKNOWN_COMMAND.
    """
    def handle(command: str, args: dict) -> dict {
        if self?._command_map and command in self._command_map {
            return self._command_map[command](args);
        }
        raise PluginError(
            "UNKNOWN_COMMAND", f"Plugin '{self.plugin_name}' has no command '{command}'"
        );
    }

    """Detect the host OS and return a canonical platform name."""
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


"""Base for plugins that invoke OS-native tools (AppleScript, PowerShell, etc.).

Subclasses get platform detection from DesktopPlugin plus shared helpers for
escaping and running shell commands on macOS and Windows.
"""
obj OsPlugin(DesktopPlugin) {
    def _escape_applescript(s: str) -> str {
        # Backslash first, then quotes, then raw newlines -> \n / \r escapes.
        # AppleScript string literals can't span raw newlines (parse error), but
        # it does interpret \n and \r escape sequences. Newline replacement runs
        # after backslash-doubling so the inserted backslashes aren't re-escaped.
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
