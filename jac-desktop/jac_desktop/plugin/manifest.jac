"""Plugin manifest + context — single source of truth for a capability.

A plugin's manifest drives two things that were previously hand-maintained
separately:
  - host registration (which IPC name, gated by which config key),
  - module loading in the embedded CPython.

The typed client SDK (``desktop_api.cl.jac``) is hand-written, not generated
from the manifest. The "desktop_sdk exports match api declarations" test keeps
its export list in sync with its `obj` declarations, and the "client SDK commands
map to host plugin commands" test keeps its `_invoke` calls in sync with the
plugins' dispatch. There is no codegen path off the manifest.

Transpiled to dependency-free Python at build time.
"""
import ctypes;


"""Declarative description of a built-in plugin."""
obj PluginManifest {
    has name: str,  # IPC name, e.g. "jac.fs"
        config_key: str,  # key under [plugins.desktop.plugins], e.g. "fs"
        module: str,  # import path, e.g. "built_in.fs_plugin"
        class_name: str,  # e.g. "FsPlugin"
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
