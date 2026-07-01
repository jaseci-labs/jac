import from cef { new_cef_browser, cef_cleanup }

glob browser = new_cef_browser("about:blank", "cef-smoke", 640, 480);

with entry {
    if browser.browser_handle != 0 {
        cef_cleanup();
    }
}
