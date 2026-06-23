"""Platform-correct libwebview DSO filename beside the desktop host binary.

Used at build time (staging the library into the output dir) and at runtime
(plugin_host ctypes.CDLL). Keep in sync with webview.na.jac's logical import.
"""
def libwebview_name -> str {
    import sys;
    if sys.platform == "darwin" {
        return "libwebview.dylib";
    }
    if sys.platform == "win32" {
        return "webview.dll";
    }
    return "libwebview.so";
}
