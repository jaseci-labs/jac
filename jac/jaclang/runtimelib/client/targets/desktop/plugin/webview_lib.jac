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
