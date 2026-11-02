import from webview {
    obj BindingCallback {
        has invoke: Callable[[int, int, int], None];
    }  def webview_create(debug: i32, window: int) -> int;  def webview_destroy(
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

    def title(text: str);
    def size(width: int, height: int, hint: int = 0);
    def navigate(url: str);
    def html(content: str);
    def on_load(js: str);
    def eval(js: str);
    def bind(name: str, handler: BindingCallback);
    def:pub run;
    def:pub terminate;
    def:pub destroy;
    def:pub get_handle -> int;
}

def:pub run_main_loop;

def:pub new_webview(debug: bool = False) -> Webview;

def:pub respond(w: int, id: int, result: str);
