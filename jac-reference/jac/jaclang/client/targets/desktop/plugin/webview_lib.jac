import from jaclang.toolchains.host { shared_library_name }

"""The webview shared library's file name on this host, as the build named it."""
def libwebview_name -> str {
    return shared_library_name("webview");
}
