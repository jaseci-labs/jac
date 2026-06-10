"""CEF test host — opens a browser window to example.com.

Run from this directory after fetch_libcef.sh + build_cef_shim.sh:
    jac nacompile cef_test_host.na.jac -o cef_test_host
    LD_LIBRARY_PATH=. ./cef_test_host
"""

import from cef { new_cef_browser, cef_cleanup }

glob browser = new_cef_browser("https://example.com", "CEF test", 1024, 768);

with entry {
    if browser.browser_handle != 0 {
        browser.run();
        cef_cleanup();
    }
}
