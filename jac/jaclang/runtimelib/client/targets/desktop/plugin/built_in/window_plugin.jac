"""Window control plugin for the Jac desktop IPC system.

Controls the native window by calling back into libwebview via ctypes.
Requires the webview handle and the loaded libwebview CDLL.

Transpiled to dependency-free Python at build time.
"""
import ctypes;
import json;
import from desktop_plugin { PluginError, ErrorCode, DesktopPlugin }
import from manifest { PluginManifest, PluginContext }


"""Controls the native webview window via ctypes -> libwebview.

On the CEF target there is no libwebview and the renderer is out-of-process.
set_title/set_size drive the real OS window through libcef_dispatch (X11) via
host.set_window_title/set_window_size, falling back to renderer-side
document.title / window.resizeTo over the SSE eval channel when no window id is
available yet (e.g. headless). fullscreen/terminate are expressed as JS pushed
through that same channel.
"""
obj WindowPlugin(DesktopPlugin) {
    has _wv: ctypes.CDLL | None = None,
        _handle: int = 0,
        _host: object | None = None;

    static def manifest -> PluginManifest {
        return PluginManifest(
            name="jac.window",
            config_key="window",
            module="built_in.window_plugin",
            class_name="WindowPlugin",
            default_on=False
        );
    }

    static def build(ctx: PluginContext, config: object) -> DesktopPlugin {
        return WindowPlugin(ctx.wv_handle, ctx.wv_lib);
    }

    def init(wv_handle: int = 0, wv_lib: ctypes.CDLL | None = None) {
        self.plugin_name = "jac.window";
        self._handle = wv_handle;
        self._wv = wv_lib;
    }

    """Late-bind the real webview handle and lib after native webview creation."""
    def setup(wv_handle: int, wv_lib: ctypes.CDLL) {
        self._handle = wv_handle;
        self._wv = wv_lib;
    }

    """CEF backend: capture the host for eval_js()-based window control."""
    def setup_cef(host: object) {
        self._host = host;
    }

    """CEF window control.

    set_title/set_size try the real OS window first (libcef_dispatch X11 via the
    host); if that no-ops (no window id yet / headless), they fall back to a
    renderer-side document.title / window.resizeTo over the SSE eval channel.
    fullscreen/terminate are expressed as JS pushed via that same channel.
    """
    def _handle_cef(command: str, args: dict) -> dict {
        if command == "set_title" {
            title = args.get("title", "");
            if not title {
                raise PluginError(ErrorCode.INVALID_ARGS, "'title' is required");
            }
            if not self._host.set_window_title(title) {
                self._host.eval_js("document.title=" + json.dumps(title));
            }
            return {};
        }
        if command == "set_size" {
            width = int(args.get("width", 0));
            height = int(args.get("height", 0));
            if width <= 0 or height <= 0 {
                raise PluginError(
                    ErrorCode.INVALID_ARGS,
                    "'width' and 'height' must be positive integers"
                );
            }
            if not self._host.set_window_size(width, height) {
                self._host.eval_js(
                    "try{window.resizeTo(" + str(width) + "," + str(height) + ");}catch(e){}"
                );
            }
            return {};
        }
        if command == "fullscreen" {
            self._host.eval_js(
                "document.documentElement.requestFullscreen().catch(function(){});"
            );
            return {};
        }
        if command == "terminate" {
            self._host.eval_js("window.close();");
            return {};
        }
        return super.handle(command, args);
    }

    def handle(command: str, args: dict) -> dict {
        if self._host is not None {
            return self._handle_cef(command, args);
        }
        if self._wv is None {
            raise PluginError(ErrorCode.NOT_READY, "Window plugin not yet initialized");
        }
        # Wrap the handle in c_void_p so ctypes marshals it as a full-width
        # pointer. A bare int defaults to c_int and truncates the 64-bit webview
        # handle to 32 bits on Windows x64 (LLP64).
        wv = ctypes.c_void_p(self._handle);
        if command == "set_title" {
            title = args.get("title", "");
            if not title {
                raise PluginError(ErrorCode.INVALID_ARGS, "'title' is required");
            }
            self._wv.webview_set_title(wv, title.encode("utf-8"));
            return {};
        }
        if command == "set_size" {
            width = int(args.get("width", 0));
            height = int(args.get("height", 0));
            if width <= 0 or height <= 0 {
                raise PluginError(
                    ErrorCode.INVALID_ARGS,
                    "'width' and 'height' must be positive integers"
                );
            }
            hint = int(args.get("hint", 0));
            self._wv.webview_set_size(wv, width, height, hint);
            return {};
        }
        if command == "fullscreen" {
            self._wv.webview_eval(
                wv, b"document.documentElement.requestFullscreen().catch(function(){});"
            );
            return {};
        }
        if command == "terminate" {
            self._wv.webview_terminate(wv);
            return {};
        }
        return super.handle(command, args);
    }
}
