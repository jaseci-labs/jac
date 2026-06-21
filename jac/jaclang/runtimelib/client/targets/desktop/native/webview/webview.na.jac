"""Jac-native binding to the OS web engine via the `webview` C library.

This is the Phase 0 foundation of the Jac-native desktop story (see issue #6436):
a `na` host that owns an OS-native webview window with no Rust toolchain, no
PyInstaller, and no Python at runtime - the whole shell is one Jac-compiled
binary plus the platform's own web engine.

It binds the `webview` library (a thin C wrapper over WebKitGTK on Linux /
WKWebView on macOS / WebView2 on Windows) by its *logical* name - `import from
webview` - so the native backend resolves the platform-correct filename
(`libwebview.so` / `libwebview.dylib` / `webview.dll`) from the target triple. The
`{ def ... }` body marks this as a C-library import, so it never collides with the
module import consumers use (`import from webview { Webview, new_webview }`). Every
declaration becomes an extern the native linker resolves out of the shared library
at load time (a DT_NEEDED entry on ELF) and, combined with the emitted `$ORIGIN`
runpath, the binary finds a sibling library regardless of the launch directory.
The linker is pure Python, so no cc/ld is needed to produce the host.

The opaque `webview_t` handle is a pointer; on every LP64 target it is carried as
a 64-bit `int`, so the binding never has to lower a struct across the C ABI - only
scalars and `const char*` (Jac `str`) cross the boundary. The JS<->native callback
(`webview_bind`) receives its C `const char*` args as raw `int` pointers for the
same reason (see its note below).
"""

# The webview C API. The opaque webview_t handle and every C `const char*`
# pointer cross the boundary as a 64-bit `int`; Jac `str` params are marshalled
# out to `const char*`. webview_create returns the handle (NULL parent = 0).
# webview_set_size's `hints` is a HINT_* value. webview_bind's handler is
# fn(id, req, arg): `id`/`req` are raw C string pointers (typed `int` to keep
# C-owned strings out of Jac's reference-counted string type) and `arg` is the
# user value; pass `id` straight back to webview_return, whose `result` must be a
# valid JSON value.
import from webview {
    def webview_create(debug: i32, window: int) -> int;  def webview_destroy(
        w: int
    ) -> i32;  def webview_run(w: int) -> i32;  def webview_terminate(w: int) -> i32;  def webview_set_title(
        w: int, title: str
    ) -> i32;  def webview_set_size(
        w: int, width: i32, height: i32, hints: i32
    ) -> i32;  def webview_navigate(w: int, url: str) -> i32;  def webview_set_html(
        w: int, html: str
    ) -> i32;  def webview_init(w: int, js: str) -> i32;  def webview_eval(
        w: int, js: str
    ) -> i32;  def webview_bind(
        w: int, name: str, fn: Callable[[int, int, int], None], arg: int
    ) -> i32;  def webview_return(w: int, id: int, status: i32, result: str) -> i32;
}

# webview_hint_t (window sizing for webview_set_size): NONE = resizable default,
# MIN/MAX = lower/upper bound, FIXED = non-resizable.
glob HINT_NONE: int = 0,
     HINT_MIN: int = 1,
     HINT_MAX: int = 2,
     HINT_FIXED: int = 3;

"""Opaque handle of the webview created by the most recent new_webview() call.

nacompile cannot pass wv.get_handle() into C ABI calls from host code (the
lowered value is wrong). Hosts should call run_main_loop() and pass this glob
to CPython bootstrap helpers instead of wv.get_handle().
"""
glob LAST_WEBVIEW_HANDLE: int = 0;

"""An OS-native webview window.

Thin ergonomic wrapper over the C handle. Construct with `new_webview(...)`,
configure with the setters, point it at content with `navigate`/`html`, then call
`run` (which blocks until the window closes).

`obj:pub` (and the `def:pub` factory below) make the type and its methods
cross-module-importable by the native backend, so a host in another `.na.jac`
file can `import from webview { Webview, new_webview }`.
"""
obj:pub Webview {
    has handle: int;

    """Set the window title."""
    def title(text: str) {
        webview_set_title(self.handle, text);
    }

    """Set the window size (hint defaults to HINT_NONE = resizable)."""
    def size(width: int, height: int, hint: int = 0) {
        webview_set_size(self.handle, width, height, hint);
    }

    """Navigate to a URL (http(s):// , file:// , or data: )."""
    def navigate(url: str) {
        webview_navigate(self.handle, url);
    }

    """Load HTML content directly."""
    def html(content: str) {
        webview_set_html(self.handle, content);
    }

    """Inject JS to run on every page load."""
    def on_load(js: str) {
        webview_init(self.handle, js);
    }

    """Evaluate JS in the current page."""
    def eval(js: str) {
        webview_eval(self.handle, js);
    }

    """Expose `window.<name>(...)` in JS, dispatched to a native handler.

    The handler is `fn(id, req, arg)` with the webview handle passed as `arg`, so
    it can reply with `respond(arg, id, result)` (see the module-level helper).
    """
    def bind(name: str, handler: Callable[[int, int, int], None]) {
        webview_bind(self.handle, name, handler, self.handle);
    }

    """Run the main loop. Blocks until the window is closed."""
    def:pub run {
        webview_run(self.handle);
    }

    """Stop the main loop (callable from another thread / a bound handler)."""
    def:pub terminate {
        webview_terminate(self.handle);
    }

    """Destroy the webview and release its resources."""
    def:pub destroy {
        webview_destroy(self.handle);
    }

    """Return the opaque C webview_t handle (for hosts that wire plugins in CPython)."""
    def:pub get_handle -> int {
        return self.handle;
    }
}

"""Block in the GTK main loop for LAST_WEBVIEW_HANDLE (generated desktop hosts)."""
def:pub run_main_loop {
    webview_run(LAST_WEBVIEW_HANDLE);
}

"""Create a window-owning webview. debug=True enables devtools where supported."""
def:pub new_webview(debug: bool = False) -> Webview {
    dbg: i32 = 1 if debug else 0;
    h = webview_create(dbg, 0);
    LAST_WEBVIEW_HANDLE = h;
    return Webview(handle=h);
}

"""Reply to a bound call from inside a handler.

`w` is the webview handle (the `arg` the handler received), `id` is the raw call
id (passed straight through to C), and `result` is a JSON value string. Status is
fixed to 0 (success); use webview_return directly for error replies.
"""
def:pub respond(w: int, id: int, result: str) {
    webview_return(w, id, 0, result);
}
