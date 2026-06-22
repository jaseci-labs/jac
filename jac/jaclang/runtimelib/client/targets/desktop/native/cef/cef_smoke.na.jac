"""Minimal CEF smoke test — validates the dispatch binding initializes CEF.

Run from this directory after fetch_libcef.sh + build_cef_dispatch.sh:
    jac nacompile cef_smoke.na.jac -o cef_smoke
    LD_LIBRARY_PATH=cef_dist:. ./cef_smoke
"""

import from cef { new_cef_browser, cef_cleanup }

glob browser = new_cef_browser("about:blank", "cef-smoke", 640, 480);

with entry {
    if browser.browser_handle != 0 {
        cef_cleanup();
    }
}
