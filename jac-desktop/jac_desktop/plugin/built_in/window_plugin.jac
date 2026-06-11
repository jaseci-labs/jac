"""Window control plugin for the Jac desktop IPC system.

Controls the native window by calling back into libwebview via ctypes.
Requires the webview handle and the loaded libwebview CDLL.

Transpiled to dependency-free Python at build time.
"""
import ctypes;
import from desktop_plugin { PluginError, DesktopPlugin }


"""Controls the native webview window via ctypes -> libwebview."""
class WindowPlugin(DesktopPlugin) {
    def init(self: WindowPlugin, wv_handle: int, wv_lib: ctypes.CDLL) {
        super.init("jac.window");
        self._wv = wv_lib;
        self._handle = wv_handle;
    }

    """Late-bind the real webview handle and lib after native webview creation."""
    def setup(self: WindowPlugin, wv_handle: int, wv_lib: ctypes.CDLL) {
        self._handle = wv_handle;
        self._wv = wv_lib;
    }

    def handle(self: WindowPlugin, command: str, args: dict) -> dict {
        if command == "set_title" {
            title = args.get("title", "");
            if not title {
                raise PluginError("INVALID_ARGS", "'title' is required");
            }
            self._wv.webview_set_title(self._handle, title.encode("utf-8"));
            return {};
        }
        if command == "set_size" {
            width = int(args.get("width", 0));
            height = int(args.get("height", 0));
            if width <= 0 or height <= 0 {
                raise PluginError(
                    "INVALID_ARGS", "'width' and 'height' must be positive integers"
                );
            }
            hint = int(args.get("hint", 0));
            self._wv.webview_set_size(self._handle, width, height, hint);
            return {};
        }
        if command == "fullscreen" {
            # WEBVIEW_HINT_FIXED = 3, used here for fullscreen-like behavior
            self._wv.webview_set_size(self._handle, 0, 0, 3);
            return {};
        }
        if command == "terminate" {
            self._wv.webview_terminate(self._handle);
            return {};
        }
        if command == "eval" {
            js = args.get("js", "");
            if not js {
                raise PluginError("INVALID_ARGS", "'js' is required for 'eval'");
            }
            self._wv.webview_eval(self._handle, js.encode("utf-8"));
            return {};
        }
        raise PluginError(
            "UNKNOWN_COMMAND", f"Plugin 'jac.window' has no command '{command}'"
        );
    }
}
