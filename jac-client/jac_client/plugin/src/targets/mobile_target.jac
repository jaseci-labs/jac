"""Mobile target implementation.

Capacitor mobile target that reuses Jac web bundling.
Wraps the web bundle with Capacitor to produce native Android APK or iOS app.
Supports both platforms via --platform android|ios (defaults to android).
"""
import from pathlib { Path }
import from typing { Any, Optional }
import from jaclang.runtimelib.watcher { FileChangeEvent }
import from jac_client.plugin.src.targets.web_target { WebTarget }

"""Binds Vite compiler state for JacFileWatcher HMR (decl only; see impl)."""
obj _MobileHmrHandler {
    has compiler: Any,
        entry_file: Path,
        project_dir: Path;

    def on_event(evt: FileChangeEvent) -> None;
}

"""Mobile build target - extends WebTarget with Capacitor mobile wrapping."""
obj MobileTarget(WebTarget) {
    has name: str = "mobile",
        default: bool = False,
        requires_setup: bool = True,
        config_section: str = "mobile",
        output_dir: Path = Path("android/app/build/outputs");

    """Setup mobile target - install Capacitor deps and scaffold platform project."""
    override def setup(project_dir: Path) -> None;

    """Build mobile app - build web bundle first, then sync and build native app."""
    override def build(
        entry_file: Path, project_dir: Path, platform: Optional[str] = None
    ) -> Path;

    """Start mobile dev flow - build web bundle and launch on device/simulator."""
    override def dev(
        entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
    ) -> None;

    """Start mobile app - build then run on device/simulator."""
    override def start(
        entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;
}
