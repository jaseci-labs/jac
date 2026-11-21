import from "libcef.so" {
    def cef_shutdown -> None;  def cef_run_message_loop -> None;  def cef_quit_message_loop -> None;
}

import from "libcef_dispatch.so" {
    def cef_dispatch_browser_get_main_frame(browser: int) -> int;  def cef_dispatch_frame_load_url(
        frame: int, url: str
    ) -> None;  def cef_dispatch_execute_process -> i32;  def cef_dispatch_startup(
        cache_path: str, no_sandbox: int
    ) -> i32;  def cef_dispatch_set_pending_browser(
        url: str, title: str, width: int, height: int
    ) -> None;  def cef_dispatch_open_browser(
        url: str, title: str, width: int, height: int
    ) -> None;
}

obj:pub CefBrowser {
    has browser_handle: int = 0;

    def title(_text: str);
    def size(_width: int, _height: int, _hint: int = 0);
    def navigate(url: str);
    def run;
    def terminate;
    def destroy;
}

def:pub cef_execute_subprocess -> i32;

def:pub cef_queue_browser(url: str, title: str, width: int, height: int);

def:pub cef_open_browser(url: str, title: str, width: int, height: int);

def:pub cef_startup(cache_path: str, no_sandbox: int) -> i32;

def:pub cef_run_loop;

def:pub new_cef_browser(
    url: str,
    title: str,
    width: int,
    height: int,
    cache_path: str = "",
    no_sandbox: int = 1,
) -> CefBrowser;

def:pub cef_cleanup;
