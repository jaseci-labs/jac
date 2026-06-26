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


"""Canonical PluginError codes - the IPC error taxonomy shared by every plugin.

The client SDK switches on the `code` field, so these are a stable contract.
Reuse a code here rather than inventing a per-plugin synonym; that is what keeps
error handling uniform across capabilities.
"""
obj ErrorCode {
    static has INVALID_ARGS: str = "INVALID_ARGS",  # missing/malformed command arguments
        FORBIDDEN: str = "FORBIDDEN",  # blocked by an allow-list / permission gate
        NOT_FOUND: str = "NOT_FOUND",  # target path/resource does not exist
        UNAVAILABLE: str = "UNAVAILABLE",  # required OS tool/service not present
        UNSUPPORTED: str = "UNSUPPORTED",  # operation unsupported on this platform
        TIMEOUT: str = "TIMEOUT",  # operation exceeded its time budget
        NOT_READY: str = "NOT_READY",  # capability not initialized yet (e.g. webview)
        FAILED: str = "FAILED",  # operation ran but did not succeed
        UNKNOWN_COMMAND: str = "UNKNOWN_COMMAND",  # plugin has no such command
        PLUGIN_NOT_FOUND: str = "PLUGIN_NOT_FOUND",  # no plugin registered under that name
        INTERNAL_ERROR: str = "INTERNAL_ERROR";  # unexpected host-side exception
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
    """Receive the live webview handle and ctypes lib after the native webview is created.

    Default is a no-op; override in plugins that need to call back into libwebview
    (e.g. WindowPlugin). Called by PluginHost.setup() once the webview exists.
    """
    def setup(wv_handle: int, wv_lib: ctypes.CDLL) { }

    """Receive the PluginHost on the CEF target (no libwebview).

    Default is a no-op; override in plugins that drive the renderer (e.g.
    WindowPlugin) to capture the host so they can call host.eval_js(). Called by
    PluginHost.setup_cef().
    """
    def setup_cef(host: object) { }

    """Handle a command from JS. Returns a dict result or raises PluginError.

    Base implementation raises UNKNOWN_COMMAND. Plugins override handle() with
    their command dispatch and delegate anything they don't recognize back here
    via `super.handle(command, args)`.
    """
    def handle(command: str, args: dict) -> dict {
        raise PluginError(
            ErrorCode.UNKNOWN_COMMAND,
            f"Plugin '{self.plugin_name}' has no command '{command}'"
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
