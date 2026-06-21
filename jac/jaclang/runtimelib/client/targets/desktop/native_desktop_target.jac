"""Jac-native desktop target - one `jac nacompile`d binary + the OS webview.

The canonical `desktop` client target (issue #6436). It builds the `cl` bundle
with the standard Vite pipeline (via `WebTarget`), then compiles a native host
(`na`) that embeds CPython to serve that bundle on a loopback port and renders it
in the OS-native webview. No Rust toolchain, no PyInstaller, no separate process:
the shell is a single self-contained binary plus the platform's own web engine
(WebKitGTK on Linux / WKWebView on macOS / WebView2 on Windows).

The native binding + build tooling ship inside this package under
`targets/desktop/native/webview/`.
"""
import from pathlib { Path }
import from typing { Optional }
import from jaclang.runtimelib.client.targets.web_target { WebTarget }
import from jaclang.runtimelib.client.targets.registry { TargetType }

"""Native desktop build target (webview + embedded-CPython host)."""
obj NativeDesktopTarget(WebTarget) {
    has name: str = TargetType.DESKTOP.value,
        default: bool = False,
        requires_setup: bool = False,
        config_section: str = "plugins.desktop",
        output_dir: Path = Path(".jac/client/desktop");

    """No scaffolding needed - the native host is generated at build time."""
    override def setup(project_dir: Path) -> None;

    """Build the cl bundle, then compile a native host that serves + renders it."""
    override def build(
        entry_file: Path, project_dir: Path, platform: Optional[str] = None
    ) -> Path;

    """Dev: build and run the native app (HMR dev is a follow-up)."""
    override def dev(
        entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
    ) -> None;

    """Build the native app and launch it."""
    override def start(
        entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;
}
