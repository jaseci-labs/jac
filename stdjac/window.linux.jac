"""A desktop app's window on Linux: a GTK 3 window holding a WebKitGTK 4.1
web view, through their stable C APIs. The libraries are opened as the
window opens (dl), so a program with a window starts without them, and says
so where they are missing. window.jac says what the window is."""

import dl;

"""Show `url` in a window, titled `title`, of `width` by `height` and at
least `min_width` by `min_height`, until it closes: 0, or -2 where GTK 3 or
WebKitGTK 4.1 isn't installed."""
def:pub run_window(
    url: str, title: str, width: int, height: int, min_width: int, min_height: int
) -> int {
    try {
        gtk = dl.open("libgtk-3.so.0");
        webkit = dl.open("libwebkit2gtk-4.1.so.0");
        gobject = dl.open("libgobject-2.0.so.0");
        gtk_init = Callable[[ptr, ptr], None](gtk.symbol("gtk_init"));
        window_new = Callable[[i32], ptr](gtk.symbol("gtk_window_new"));
        set_title = Callable[[ptr, str], None](gtk.symbol("gtk_window_set_title"));
        set_default_size = Callable[[ptr, i32, i32], None](
            gtk.symbol("gtk_window_set_default_size")
        );
        set_size_request = Callable[[ptr, i32, i32], None](
            gtk.symbol("gtk_widget_set_size_request")
        );
        container_add = Callable[[ptr, ptr], None](gtk.symbol("gtk_container_add"));
        show_all = Callable[[ptr], None](gtk.symbol("gtk_widget_show_all"));
        gtk_main = Callable[[], None](gtk.symbol("gtk_main"));
        # Given to GTK as the destroy signal's handler: an address.
        main_quit = gtk.symbol("gtk_main_quit");
        connect = Callable[[ptr, str, ptr, ptr, ptr, i32], int](
            gobject.symbol("g_signal_connect_data")
        );
        view_new = Callable[[], ptr](webkit.symbol("webkit_web_view_new"));
        load_uri = Callable[[ptr, str], None](webkit.symbol("webkit_web_view_load_uri"));
    } except OSError {
        return -2;
    } except AttributeError {
        return -2;
    }
    gtk_init(ptr(0), ptr(0));
    window = window_new(i32(0));
    set_title(window, title);
    set_default_size(window, i32(width), i32(height));
    set_size_request(window, i32(min_width), i32(min_height));
    connect(window, "destroy", main_quit, ptr(0), ptr(0), i32(0));
    view = view_new();
    container_add(window, view);
    load_uri(view, url);
    show_all(window);
    gtk_main();
    return 0;
}
