import from jaclang.cli.console { console }

def setup_toolchain(name: str) -> int {
    try {
        if name == "android" {
            import from jaclang.toolchains.android { ensure_android }
            ensure_android();
            import from jaclang.toolchains.javascript { native_node }
            native_node();
        } elif name == "ios" {
            import from jaclang.toolchains.apple { ensure_apple }
            ensure_apple();
            import from jaclang.toolchains.javascript { native_node }
            native_node();
        } elif name == "desktop" {
            import from jaclang.client.targets.desktop.desktop_build {
                _find_webview_dir
            }
            import from jaclang.toolchains.desktop { ensure_webview }
            ensure_webview(_find_webview_dir());
        } elif name == "cef" {
            import from jaclang.client.targets.desktop.desktop_build { _find_cef_dir }
            import from jaclang.toolchains.cef { ensure_cef }
            ensure_cef(_find_cef_dir());
        } else {
            raise ValueError(
                f"Unknown toolchain '{name}'. Choose android, ios, desktop, or cef."
            );
        }
        return 0;
    } except Exception as error {
        console.error(str(error));
        return 1;
    }
}
