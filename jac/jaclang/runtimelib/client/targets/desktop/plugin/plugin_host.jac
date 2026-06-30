import json;
import os;
import sys;
import ctypes;
import queue;
import threading;
import from pathlib { Path }
import from desktop_plugin { PluginError, ErrorCode, DesktopPlugin }
import from webview_lib { libwebview_name }


def _binary_dir -> str {
    if os.path.isfile("/proc/self/exe") {
        return os.path.dirname(os.path.realpath("/proc/self/exe"));
    }

    return os.path.dirname(os.path.abspath(sys.argv[0]));
}

obj PluginHost {
    has plugins: dict,
        _wv_handle: int = 0,
        _wv_lib: ctypes.CDLL | None = None,
        _cef: bool = False,
        _subscribers: list = [],
        _sub_lock: object = None,
        _cef_lib: object = None;

    def init {
        self.plugins = {};
        self._subscribers = [];
        self._sub_lock = threading.Lock();
    }

    def register(name: str, plugin: DesktopPlugin) {
        self.plugins[name] = plugin;
    }

    def setup(wv_handle: int) {
        self._wv_handle = wv_handle;
        exe_dir = _binary_dir();
        lib_name = libwebview_name();
        lib_path = os.path.join(exe_dir, lib_name);
        self._wv_lib = ctypes.CDLL(lib_path);

        for plugin in self.plugins.values() {
            plugin.setup(wv_handle, self._wv_lib);
        }
    }

    def setup_cef {
        self._cef = True;
        self._cef_lib = self._load_cef_lib();
        for plugin in self.plugins.values() {
            plugin.setup_cef(self);
        }
    }

    def _load_cef_lib -> object {
        try {
            lib_path = os.path.join(_binary_dir(), "libcef_dispatch.so");
            lib = ctypes.CDLL(lib_path);

            lib.cef_dispatch_window_set_title.argtypes = [ctypes.c_char_p];
            lib.cef_dispatch_window_set_title.restype = ctypes.c_int;
            lib.cef_dispatch_window_set_size.argtypes = [ctypes.c_long, ctypes.c_long];
            lib.cef_dispatch_window_set_size.restype = ctypes.c_int;
            return lib;
        } except Exception as e {
            return None;
        }
    }

    def set_window_title(title: str) -> bool {
        if self._cef_lib is None {
            return False;
        }
        rc = self._cef_lib.cef_dispatch_window_set_title(title.encode("utf-8"));
        return bool(rc);
    }

    def set_window_size(width: int, height: int) -> bool {
        if self._cef_lib is None {
            return False;
        }
        rc = self._cef_lib.cef_dispatch_window_set_size(int(width), int(height));
        return bool(rc);
    }

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

    def unsubscribe(q: queue.Queue) {
        with self._sub_lock {
            if q in self._subscribers {
                self._subscribers.remove(q);
            }
        }
    }

    def _push(message: str) {
        with self._sub_lock {
            subs = list(self._subscribers);
        }
        for q in subs {
            q.put(message);
        }
    }

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

    def emit(event: str, payload: dict) -> None {
        if self._cef {
            self._push(json.dumps({"event": event, "payload": payload}));
            return;
        }
        if self._wv_lib is None or self._wv_handle == 0 {
            return;
        }
        js = "window.__jac.__emit__(" + json.dumps(event) + ", " + json.dumps(
            payload
        ) + ")";

        self._wv_lib.webview_eval(ctypes.c_void_p(self._wv_handle), js.encode("utf-8"));
    }
}
