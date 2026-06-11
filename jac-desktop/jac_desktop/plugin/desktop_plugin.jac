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
class PluginError(Exception) {
    def init(self: PluginError, code: str, message: str) {
        self.code = code;
        self.message = message;
        super.init(f"[{code}] {message}");
    }
}


"""Abstract base for capability plugins.

Subclasses override handle(command, args) to implement their commands.
The plugin_host dispatches requests to the correct plugin by plugin_name.
"""
class DesktopPlugin {
    def init(self: DesktopPlugin, plugin_name: str) {
        self.plugin_name = plugin_name;
    }

    """Receive the live webview handle and ctypes lib after the native webview is created.

    Default is a no-op; override in plugins that need to call back into libwebview
    (e.g. WindowPlugin). Called by PluginHost.setup() once the webview exists.
    """
    def setup(self: DesktopPlugin, wv_handle: int, wv_lib: ctypes.CDLL) { }

    """Handle a command from JS. Returns a dict result or raises PluginError."""
    def handle(self: DesktopPlugin, command: str, args: dict) -> dict {
        raise PluginError(
            "UNKNOWN_COMMAND", f"Plugin '{self.plugin_name}' has no command '{command}'"
        );
    }

    """Detect the host OS and return a canonical platform name."""
    def _detect_platform(self: DesktopPlugin) -> str {
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
class OsPlugin(DesktopPlugin) {
    def _escape_applescript(self: OsPlugin, s: str) -> str {
        return s.replace("\\", "\\\\").replace('"', '\\"');
    }

    def _escape_powershell(self: OsPlugin, s: str) -> str {
        return s.replace("'", "''");
    }

    def _run_powershell(
        self: OsPlugin, ps: str, timeout: int = 60, check: bool = False
    ) {
        encoded = base64.b64encode(ps.encode("utf-16-le")).decode("ascii");
        return subprocess.run(
            ["powershell", "-EncodedCommand", encoded],
            check=check,
            capture_output=True,
            timeout=timeout
        );
    }
}
