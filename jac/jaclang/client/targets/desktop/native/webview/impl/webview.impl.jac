impl Webview.title(text: str) {
    webview_set_title(self.handle, text);
}

impl Webview.size(width: int, height: int, hint: int = 0) {
    webview_set_size(self.handle, i32(width), i32(height), i32(hint));
}

impl Webview.navigate(url: str) {
    webview_navigate(self.handle, url);
}

impl Webview.html(content: str) {
    webview_set_html(self.handle, content);
}

impl Webview.on_load(js: str) {
    webview_init(self.handle, js);
}

impl Webview.eval(js: str) {
    webview_eval(self.handle, js);
}

impl Webview.bind(name: str, handler: BindingCallback) {
    webview_bind(self.handle, name, handler.invoke, self.handle);
}

impl Webview.run {
    webview_run(self.handle);
}

impl Webview.terminate {
    webview_terminate(self.handle);
}

impl Webview.destroy {
    webview_destroy(self.handle);
}

impl Webview.get_handle -> int {
    return self.handle;
}

impl run_main_loop {
    webview_run(LAST_WEBVIEW_HANDLE);
}

impl new_webview(debug: bool = False) -> Webview {
    dbg: i32 = i32(1 if debug else 0);
    h = webview_create(dbg, 0);
    LAST_WEBVIEW_HANDLE = h;
    return Webview(handle=h);
}

impl respond(w: int, id: int, result: str) {
    webview_return(w, id, 0, result);
}
