"""Minimal test host for the CEF binding."""
import from cef.na { new_cef_browser, cef_cleanup, CefBrowser }

glob browser = new_cef_browser(
         url="http://example.com", title="CEF Test", width=800, height=600,
     );

with entry {
    if browser.browser_handle != 0 {
        browser.run();
    }
    cef_cleanup();
}
