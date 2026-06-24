"""CEF-based desktop target - one `jac nacompile`d binary + CEF Chromium.

An alternative to `NativeDesktopTarget` that uses Chromium Embedded Framework
(CEF) instead of the OS-native webview (WebKitGTK/WKWebView/WebView2). Selected
explicitly with `--client cef` (the OS-native variant is `--client desktop`).

Provides a consistent Chromium rendering engine across all platforms, at the
cost of bundling the CEF runtime (~200 MB) alongside the app. The build
pipeline is structurally the same as the native target: Vite bundle → stage →
generate a native host → nacompile. The host embeds CPython to serve the bundle
on a loopback port and renders it in a CEF browser window.

The native binding + fetch tooling ship inside this package under
`targets/desktop/native/cef/`.
"""
import from pathlib { Path }
import from typing { Optional }
import from jaclang.runtimelib.client.targets.web_target { WebTarget }
import from jaclang.runtimelib.client.targets.registry { TargetType }

"""CEF desktop build target (Chromium + embedded-CPython host)."""
obj CefDesktopTarget(WebTarget) {
    has name: str = TargetType.DESKTOP_CEF.value,
        default: bool = False,
        requires_setup: bool = False,
        config_section: str = "plugins.desktop",
        output_dir: Path = Path(".jac/client/cef");

    """No scaffolding needed — the native host is generated at build time."""
    override def setup(project_dir: Path) -> None;

    """Build the cl bundle, then compile a CEF-based native host."""
    override def build(
        entry_file: Path, project_dir: Path, platform: Optional[str] = None
    ) -> Path;

    """Dev: build and run the CEF app (HMR dev is a follow-up)."""
    override def dev(
        entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
    ) -> None;

    """Build the CEF app and launch it."""
    override def start(
        entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;
}
