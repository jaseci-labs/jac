"""Plugin host: registry, dispatch, and push-event emission.

The host owns the plugin registry, routes JS invoke() calls to the correct
plugin's handle() method, and provides emit() for pushing events back to JS
via webview_eval().

Transpiled to dependency-free Python at build time. Runs in the embedded CPython
with only the stdlib (no jaclang).
"""
import json;
import ctypes;
import from pathlib { Path }
import from desktop_plugin { PluginError, DesktopPlugin }


"""Plugin host: registry, dispatch, emit."""
class PluginHost {
    def init(self: PluginHost) {
        self.plugins: dict = {};
        self._wv_handle: int = 0;
        self._wv_lib = None;  # ctypes.CDLL once setup() is called
    }

    """Register a plugin under the given name (e.g. 'jac.fs')."""
    def register(self: PluginHost, name: str, plugin: DesktopPlugin) {
        self.plugins[name] = plugin;
    }

    """Load libwebview via ctypes and store the webview handle.

    The webview DSO is already loaded by the native binary; dlopen returns
    the same handle. The opaque wv_handle (int pointer) is valid across both
    native and CPython contexts.
    """
    def setup(self: PluginHost, wv_handle: int) {
        self._wv_handle = wv_handle;
        # Find libwebview.so next to the running binary.
        import os;
        exe_dir = os.path.dirname(os.path.realpath("/proc/self/exe"));
        lib_path = os.path.join(exe_dir, "libwebview.so");
        self._wv_lib = ctypes.CDLL(lib_path);
    }

    """Dispatch a JS invoke() request to the registered plugin.

    Entry point called from the native shim via PyObject_CallOneArg.
    Returns a JSON string: {"ok": true, "data": ...} or
    {"ok": false, "error": {"code": ..., "message": ...}}.
    """
    def dispatch(self: PluginHost, req_json: str) -> str {
        try {
            req = json.loads(req_json);
            name = req.get("plugin", "");
            command = req.get("command", "");
            args = req.get("args", {});
            if name not in self.plugins {
                return json.dumps(
                    {
                        "ok": False,
                        "error": {
                            "code": "PLUGIN_NOT_FOUND",
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
                {"ok": False, "error": {"code": "INTERNAL_ERROR", "message": str(e)}}
            );
        }
    }

    """Push an event to JS via webview_eval().

    Calls window.__jac.__emit__(event, payload) in the webview.
    Uses json.dumps for both event and payload to prevent injection.
    """
    def emit(self: PluginHost, event: str, payload: dict) -> None {
        if self._wv_lib is None or self._wv_handle == 0 {
            return;
        }
        js = "window.__jac.__emit__(" + json.dumps(event) + ", " + json.dumps(
            payload
        ) + ")";
        self._wv_lib.webview_eval(self._wv_handle, js.encode("utf-8"));
    }
}
