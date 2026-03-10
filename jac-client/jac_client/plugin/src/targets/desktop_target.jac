"""Desktop target implementation.

Extends WebTarget to add Tauri desktop app capabilities.
Desktop builds use web bundle as foundation, then wrap with Tauri + sidecar.
"""
import from pathlib { Path }
import from typing { Optional }
import from jac_client.plugin.src.targets.web_target { WebTarget }

"""Desktop build target - extends WebTarget with Tauri wrapping."""
obj DesktopTarget(WebTarget) {
    has name: str = "desktop",
        default: bool = False,
        requires_setup: bool = True,
        config_section: str = "desktop",
        output_dir: Path = Path("src-tauri/target/release/bundle");

    """Setup desktop target - scaffold Tauri project structure."""
    override def setup(project_dir: Path) -> None;

    """Build desktop app - build web bundle first, then wrap with Tauri."""
    override def build(
        entry_file: Path, project_dir: Path, platform: Optional[str] = None
    ) -> Path;

    """Start desktop dev server - start web dev server and launch tauri dev."""
    override def dev(
        entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;

    """Start desktop app - build web bundle and launch Tauri with built bundle."""
    override def start(
        entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;
}
