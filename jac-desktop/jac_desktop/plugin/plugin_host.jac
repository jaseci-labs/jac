"""Plugin host: registry, dispatch, and push-event emission.

The host owns the plugin registry, routes JS invoke() calls to the correct
plugin's handle() method, and provides emit() for pushing events back to JS
via webview_eval().

Transpiled to dependency-free Python at build time. Runs in the embedded CPython
with only the stdlib (no jaclang).
"""
import json;
import os;
import sys;
import ctypes;
import from pathlib { Path }
import from desktop_plugin { PluginError, ErrorCode, DesktopPlugin }
import from webview_lib { libwebview_name }


"""Return the directory containing the running binary, cross-platform.

Uses /proc/self/exe on Linux (fast, no argv[0] edge cases), falls back to
resolving sys.argv[0] on macOS/Windows. Works inside embedded CPython where
__main__.__file__ is unset but sys.argv[0] is still the host binary.
"""
def _binary_dir -> str {
    if os.path.isfile("/proc/self/exe") {
        return os.path.dirname(os.path.realpath("/proc/self/exe"));
    }
    # macOS / Windows: sys.argv[0] is the binary path set by the native host.
    return os.path.dirname(os.path.abspath(sys.argv[0]));
}

"""Plugin host: registry, dispatch, emit."""
obj PluginHost {
    has plugins: dict,
        _wv_handle: int = 0,
        _wv_lib: ctypes.CDLL | None = None;

    def init {
        self.plugins = {};
    }

    """Register a plugin under the given name (e.g. 'jac.fs')."""
    def register(name: str, plugin: DesktopPlugin) {
        self.plugins[name] = plugin;
    }

    """Load libwebview via ctypes and store the webview handle.

    The webview DSO is already loaded by the native binary; dlopen returns
    the same handle. The opaque wv_handle (int pointer) is valid across both
    native and CPython contexts.

    Also propagates the handle and lib to any registered plugin that overrides
    setup() (e.g. WindowPlugin).
    """
    def setup(wv_handle: int) {
        self._wv_handle = wv_handle;
        exe_dir = _binary_dir();
        lib_name = libwebview_name();
        lib_path = os.path.join(exe_dir, lib_name);
        self._wv_lib = ctypes.CDLL(lib_path);
        # Propagate to all registered plugins so they can call into libwebview.
        for plugin in self.plugins.values() {
            plugin.setup(wv_handle, self._wv_lib);
        }
    }

    """Normalize a webview bind callback payload into {plugin, command, args}.

    The canonical wire shape is a JSON array of the JS call arguments, e.g.
    ``["jac.path", "home", {}]`` - the host's BOOTSTRAP_JS always invokes with
    three arguments (``__jac_invoke(p, c, a || {})``). The trailing args object
    is tolerated as absent or null for robustness.

    A bare ``{plugin, command, args}`` object is also accepted: that is the
    already-normalized form, used by in-process callers and the test suite.
    """
    def _parse_invoke(req_json: str) -> dict {
        wire = json.loads(req_json);
        if isinstance(wire, list) and len(wire) >= 2 {
            args = wire[2] if len(wire) > 2 and wire[2] is not None else {};
            return {"plugin": wire[0], "command": wire[1], "args": args};
        }
        if isinstance(wire, dict) {
            return wire;
        }
        raise ValueError(f"unexpected invoke payload: {req_json}");
    }

    """Dispatch a JS invoke() request to the registered plugin.

    Entry point called from the native shim via PyObject_CallOneArg.
    Returns a JSON string: {"ok": true, "data": ...} or
    {"ok": false, "error": {"code": ..., "message": ...}}.
    """
    def dispatch(req_json: str) -> str {
        try {
            req = self._parse_invoke(req_json);
            name = req.get("plugin", "");
            command = req.get("command", "");
            args = req.get("args", {});
            if name not in self.plugins {
                return json.dumps(
                    {
                        "ok": False,
                        "error": {
                            "code": ErrorCode.PLUGIN_NOT_FOUND,
                            "message": f"Plugin '{name}' is not registered"
                        }
                    }
                );
            }
            result = self.plugins[name].handle(command, args);
            return json.dumps({"ok": True, "data": result});
        } except PluginError as e {
            return json.dumps(
                {"ok": False, "error": {"code": e.code, "message": e.message}}
            );
        } except Exception as e {
            return json.dumps(
                {
                    "ok": False,
                    "error": {"code": ErrorCode.INTERNAL_ERROR, "message": str(e)}
                }
            );
        }
    }

    """Push an event to JS via webview_eval().

    Calls window.__jac.__emit__(event, payload) in the webview.
    Uses json.dumps for both event and payload to prevent injection.
    """
    def emit(event: str, payload: dict) -> None {
        if self._wv_lib is None or self._wv_handle == 0 {
            return;
        }
        js = "window.__jac.__emit__(" + json.dumps(event) + ", " + json.dumps(
            payload
        ) + ")";
        # Wrap the handle in c_void_p so ctypes marshals it as a full-width
        # pointer. Passing the bare int defaults to c_int and truncates the
        # 64-bit webview handle to 32 bits on Windows x64 (LLP64), breaking emit.
        self._wv_lib.webview_eval(ctypes.c_void_p(self._wv_handle), js.encode("utf-8"));
    }
}
