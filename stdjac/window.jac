"""A desktop app's window: a webview on the platform's own engine.
window.linux.jac is Linux's; jac has no webview for the others yet."""

"""Show `url` in a window, titled `title`, of `width` by `height` and at
least `min_width` by `min_height`, until it closes: 0, -1 where jac has
no webview for this platform yet, or -2 where the platform's webview isn't
installed."""
def:pub run_window(
    url: str, title: str, width: int, height: int, min_width: int, min_height: int
) -> int {
    return -1;
}
