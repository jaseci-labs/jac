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
import queue;
import threading;
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
        _wv_lib: ctypes.CDLL | None = None,
        # CEF (multi-process) push transport: emit()/eval_js() fan out to the
        # SSE subscribers (one queue.Queue per /__jac/events connection) instead
        # of calling libwebview, which the CEF target does not load.
        _cef: bool = False,
        _subscribers: list = [],
        _sub_lock: object = None,
        # libcef_dispatch.so (CEF target only), loaded in setup_cef for native
        # window control (set_title/set_size). None if unavailable -> WindowPlugin
        # falls back to renderer-side document.title / window.resizeTo.
        _cef_lib: object = None;

    def init {
        self.plugins = {};
        self._subscribers = [];
        self._sub_lock = threading.Lock();
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

    """CEF setup: switch emit()/eval_js() to the SSE transport.

    The CEF target has no libwebview, and its render process is out-of-process,
    so host->JS pushes go over the /__jac/events SSE channel instead. Plugins
    that need to drive the renderer (e.g. WindowPlugin) get a reference to the
    host via setup_cef() so they can call eval_js().
    """
    def setup_cef {
        self._cef = True;
        self._cef_lib = self._load_cef_lib();
        for plugin in self.plugins.values() {
            plugin.setup_cef(self);
        }
    }

    """Load libcef_dispatch.so and bind the native window-control entry points.

    The DSO is already loaded by the CEF host binary; CDLL returns the same
    handle. Returns None (and logs nothing) if it cannot be loaded so window
    control degrades to the renderer-side best-effort path.
    """
    def _load_cef_lib -> object {
        try {
            lib_path = os.path.join(_binary_dir(), "libcef_dispatch.so");
            lib = ctypes.CDLL(lib_path);
            # char* (c_char_p) for the title; the .so takes it as an int pointer.
            lib.cef_dispatch_window_set_title.argtypes = [ctypes.c_char_p];
            lib.cef_dispatch_window_set_title.restype = ctypes.c_int;
            lib.cef_dispatch_window_set_size.argtypes = [ctypes.c_long, ctypes.c_long];
            lib.cef_dispatch_window_set_size.restype = ctypes.c_int;
            return lib;
        } except Exception as e {
            return None;
        }
    }

    """Set the real OS window title via libcef_dispatch (X11). True if applied."""
    def set_window_title(title: str) -> bool {
        if self._cef_lib is None {
            return False;
        }
        rc = self._cef_lib.cef_dispatch_window_set_title(title.encode("utf-8"));
        return bool(rc);
    }

    """Resize the real OS window via libcef_dispatch (X11). True if applied."""
    def set_window_size(width: int, height: int) -> bool {
        if self._cef_lib is None {
            return False;
        }
        rc = self._cef_lib.cef_dispatch_window_set_size(int(width), int(height));
        return bool(rc);
    }

    """Register a new SSE subscriber; returns its event queue, or None if the
    subscriber pool is full (each live subscriber pins a server thread)."""
    def subscribe -> (queue.Queue | None) {
        q = queue.Queue();
        with self._sub_lock {
            if len(self._subscribers) >= 256 {
                return None;
            }
            self._subscribers.append(q);
        }
        return q;
    }

    """Drop an SSE subscriber (connection closed)."""
    def unsubscribe(q: queue.Queue) {
        with self._sub_lock {
            if q in self._subscribers {
                self._subscribers.remove(q);
            }
        }
    }

    """Fan a pre-serialized SSE data line out to every live subscriber."""
    def _push(message: str) {
        with self._sub_lock {
            subs = list(self._subscribers);
        }
        for q in subs {
            q.put(message);
        }
    }

    """Execute JS in the renderer (host->JS).

    On CEF this rides the SSE channel ({"eval": code}); on the native webview it
    calls libwebview directly. Used by WindowPlugin's CEF backend.
    """
    def eval_js(code: str) -> None {
        if self._cef {
            self._push(json.dumps({"eval": code}));
            return;
        }
        if self._wv_lib is None or self._wv_handle == 0 {
            return;
        }
        self._wv_lib.webview_eval(
            ctypes.c_void_p(self._wv_handle), code.encode("utf-8")
        );
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
        if self._cef {
            # SSE: the page's EventSource routes {event,payload} to __jac.__emit__.
            self._push(json.dumps({"event": event, "payload": payload}));
            return;
        }
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
