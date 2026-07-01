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

glob HINT_NONE: int = 0,
     HINT_MIN: int = 1,
     HINT_MAX: int = 2,
     HINT_FIXED: int = 3;

glob LAST_WEBVIEW_HANDLE: int = 0;

obj:pub Webview {
    has handle: int;

    def title(text: str) {
        webview_set_title(self.handle, text);
    }

    def size(width: int, height: int, hint: int = 0) {
        webview_set_size(self.handle, width, height, hint);
    }

    def navigate(url: str) {
        webview_navigate(self.handle, url);
    }

    def html(content: str) {
        webview_set_html(self.handle, content);
    }

    def on_load(js: str) {
        webview_init(self.handle, js);
    }

    def eval(js: str) {
        webview_eval(self.handle, js);
    }

    def bind(name: str, handler: Callable[[int, int, int], None]) {
        webview_bind(self.handle, name, handler, self.handle);
    }

    def:pub run {
        webview_run(self.handle);
    }

    def:pub terminate {
        webview_terminate(self.handle);
    }

    def:pub destroy {
        webview_destroy(self.handle);
    }

    def:pub get_handle -> int {
        return self.handle;
    }
}

def:pub run_main_loop {
    webview_run(LAST_WEBVIEW_HANDLE);
}

def:pub new_webview(debug: bool = False) -> Webview {
    dbg: i32 = 1 if debug else 0;
    h = webview_create(dbg, 0);
    LAST_WEBVIEW_HANDLE = h;
    return Webview(handle=h);
}

def:pub respond(w: int, id: int, result: str) {
    webview_return(w, id, 0, result);
}
