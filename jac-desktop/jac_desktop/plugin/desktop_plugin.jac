"""Base types for the Jac desktop plugin IPC system.

Defines PluginError (structured error for command failures) and DesktopPlugin
(abstract base for capability plugins). Every built-in plugin subclasses
DesktopPlugin and raises PluginError on validation / permission failures.

Transpiled to dependency-free Python at build time. Runs in the embedded CPython
with only the stdlib (no jaclang).
"""

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

    """Handle a command from JS. Returns a dict result or raises PluginError."""
    def handle(self: DesktopPlugin, command: str, args: dict) -> dict {
        raise PluginError(
            "UNKNOWN_COMMAND", f"Plugin '{self.plugin_name}' has no command '{command}'"
        );
    }
}
