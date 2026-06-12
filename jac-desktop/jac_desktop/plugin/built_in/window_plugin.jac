"""Window control plugin for the Jac desktop IPC system.

Controls the native window by calling back into libwebview via ctypes.
Requires the webview handle and the loaded libwebview CDLL.

Transpiled to dependency-free Python at build time.
"""
import ctypes;
import from desktop_plugin { PluginError, DesktopPlugin }
import from manifest { PluginManifest, CommandSpec, PluginContext }


"""Controls the native webview window via ctypes -> libwebview."""
obj WindowPlugin(DesktopPlugin) {
    has _wv: ctypes.CDLL | None = None,
        _handle: int = 0;

    static def manifest -> PluginManifest {
        return PluginManifest(
            name="jac.window",
            config_key="window",
            module="built_in.window_plugin",
            class_name="WindowPlugin",
            commands=[
                CommandSpec(name="set_title", params={"title": "str"}, returns="dict"),
                CommandSpec(
                    name="set_size",
                    params={"width": "int", "height": "int", "hint": "int"},
                    returns="dict"
                ),
                CommandSpec(name="fullscreen", returns="dict"),
                CommandSpec(name="terminate", returns="dict")
            ],
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

    def handle(command: str, args: dict) -> dict {
        if self._wv is None {
            raise PluginError("NOT_READY", "Window plugin not yet initialized");
        }
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
        return super.handle(command, args);
    }
}
