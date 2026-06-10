"""Jac-native binding to Chromium Embedded Framework (CEF).

Thin ergonomic wrapper over libcef_shim.so, which owns all CEF vtable/C API
complexity. Jac only sees scalars and strings across the FFI boundary — the
same pattern as webview.na.jac.

The shim (cef_shim.c → libcef_shim.so) is built on first use by
build_cef_shim.sh against the staged CEF binary distribution.
"""

import from cef_shim {
    def jac_cef_execute_process -> i32;  def jac_cef_initialize(
        cache_path: str, no_sandbox: i32
    ) -> i32;  def jac_cef_shutdown -> None;  def jac_cef_run_message_loop -> None;  def jac_cef_quit_message_loop -> None;  def jac_cef_create_browser(
        url: str, title: str, width: i32, height: i32
    ) -> int;  def jac_cef_navigate(browser_handle: int, url: str) -> None;
}

"""Chromium browser window powered by CEF.

Same interface shape as `Webview` from webview.na.jac: construct with
`new_cef_browser(...)`, navigate, then call `run` (blocks until closed).
"""
obj:pub CefBrowser {
    has browser_handle: int = 0;

    def title(_text: str) {
    # Title is applied at window creation time in the shim.
    }

    def size(_width: int, _height: int, _hint: int = 0) {
    # Size is applied at window creation time in the shim.
    }

    def navigate(url: str) {
        if self.browser_handle != 0 {
            jac_cef_navigate(self.browser_handle, url);
        }
    }

    def run {
        jac_cef_run_message_loop();
    }

    def terminate {
        jac_cef_quit_message_loop();
    }

    def destroy {
    # Browser lifetime is managed by CEF; on_before_close quits the loop.
    }
}

"""Factory: bootstrap CEF, initialize, and open a browser window.

cache_path: persistent profile directory for localStorage ("" for incognito).
no_sandbox: pass 1 on Linux dev setups without setuid chrome-sandbox.

Returns CefBrowser(browser_handle=0) when running as a CEF subprocess.
"""
def:pub new_cef_browser(
    url: str,
    title: str,
    width: int,
    height: int,
    cache_path: str = "",
    no_sandbox: int = 1,
) -> CefBrowser {
    code: i32 = jac_cef_execute_process();
    if code >= 0 {
        return CefBrowser(browser_handle=0);
    }
    # Queue browser before initialize — on_context_initialized creates the window.
    handle = jac_cef_create_browser(url, title, width, height);
    rc: i32 = jac_cef_initialize(cache_path, no_sandbox);
    if rc != 1 {
        return CefBrowser(browser_handle=0);
    }
    return CefBrowser(browser_handle=handle);
}

"""Shut down CEF after the message loop exits."""
def:pub cef_cleanup {
    jac_cef_shutdown();
}
