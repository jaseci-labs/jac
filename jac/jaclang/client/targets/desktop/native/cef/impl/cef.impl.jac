impl CefBrowser.title(_text: str) {}

impl CefBrowser.size(_width: int, _height: int, _hint: int = 0) {}

impl CefBrowser.navigate(url: str) {
    if self.browser_handle != 0 {
        frame = cef_dispatch_browser_get_main_frame(self.browser_handle);
        if frame != 0 {
            cef_dispatch_frame_load_url(frame, url);
        }
    }
}

impl CefBrowser.run {
    cef_run_message_loop();
}

impl CefBrowser.terminate {
    cef_quit_message_loop();
}

impl CefBrowser.destroy {}

impl cef_execute_subprocess -> i32 {
    return cef_dispatch_execute_process();
}

impl cef_queue_browser(url: str, title: str, width: int, height: int) {
    cef_dispatch_set_pending_browser(url, title, width, height);
}

impl cef_open_browser(url: str, title: str, width: int, height: int) {
    cef_dispatch_open_browser(url, title, width, height);
}

impl cef_startup(cache_path: str, no_sandbox: int) -> i32 {
    return cef_dispatch_startup(cache_path, no_sandbox);
}

impl cef_run_loop {
    cef_run_message_loop();
}

impl new_cef_browser(
    url: str,
    title: str,
    width: int,
    height: int,
    cache_path: str = "",
    no_sandbox: int = 1,
) -> CefBrowser {
    code: int = cef_execute_subprocess();
    if code >= 0 {
        return CefBrowser(browser_handle=0);
    }
    cef_queue_browser(url, title, width, height);
    rc: int = cef_startup(cache_path, no_sandbox);
    if rc != 1 {
        return CefBrowser(browser_handle=0);
    }
    return CefBrowser(browser_handle=1);
}

impl cef_cleanup {
    cef_shutdown();
}
