"""Plugin manifest + context — single source of truth for a capability.

A plugin's manifest drives three things that were previously hand-maintained
separately:
  - host registration (which IPC name, gated by which config key),
  - module loading in the embedded CPython,
  - typed client SDK generation (from `commands`).

Transpiled to dependency-free Python at build time.
"""
import ctypes;


"""One IPC command's shape — used for validation and SDK codegen."""
obj CommandSpec {
    has name: str,
        params: dict,
        returns: str,
        doc: str;

    def init(
        name: str, params: dict | None = None, returns: str = "dict", doc: str = ""
    ) {
        self.name = name;
        self.params = params if params is not None else {};
        self.returns = returns;
        self.doc = doc;
    }
}


"""Declarative description of a built-in plugin."""
obj PluginManifest {
    has name: str,  # IPC name, e.g. "jac.fs"
        config_key: str,  # key under [plugins.desktop.plugins], e.g. "fs"
        module: str,  # import path, e.g. "built_in.fs_plugin"
        class_name: str,  # e.g. "FsPlugin"
        commands: list = [],  # list[CommandSpec]
        default_on: bool = False;
}


"""Shared services handed to every plugin's build() factory.

Carries the always-on PathPlugin service (fs depends on it even when the
jac.path IPC surface is disabled) and the late-bound webview handle/lib that
WindowPlugin needs after the native webview is created.
"""
obj PluginContext {
    has path_plugin: object | None = None,
        wv_handle: int = 0,
        wv_lib: ctypes.CDLL | None = None;
}
