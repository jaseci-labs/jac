"""Desktop target implementation.

Extends WebTarget to add Tauri desktop app capabilities.
Desktop builds use web bundle as foundation, then wrap with Tauri + sidecar.
"""
import from pathlib { Path }
import from typing { Optional }
import from jac_client.plugin.src.targets.web_target { WebTarget }

"""Desktop build target - extends WebTarget with Tauri wrapping."""
class DesktopTarget(WebTarget) {
    def init(self: DesktopTarget) {
        super.init();
        self.name = "desktop";
        self.default = False;
        self.requires_setup = True;
        self.config_section = "desktop";
        self.output_dir = Path("src-tauri/target/release/bundle");
    }

    """Setup desktop target - scaffold Tauri project structure."""
    override def setup(self: DesktopTarget, project_dir: Path) -> None;

    """Build desktop app - build web bundle first, then wrap with Tauri."""
    override def build(
        self: DesktopTarget,
        entry_file: Path,
        project_dir: Path,
        platform: Optional[str] = None
    ) -> Path;

    """Start desktop dev server - start web dev server and launch tauri dev."""
    override def dev(
        self: DesktopTarget, entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;

    """Start desktop app - build web bundle and launch Tauri with built bundle."""
    override def start(
        self: DesktopTarget, entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;
}
