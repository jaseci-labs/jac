"""Web target implementation.

This is the default target for building web applications.
"""
import from pathlib { Path }
import from typing { Optional }
import from jac_client.plugin.src.targets.registry { ClientTarget }

"""Web build target."""
obj WebTarget(ClientTarget) {
    has name: str = "web",
        default: bool = True,
        requires_setup: bool = False,
        config_section: str = "plugin.client",
        output_dir: Path = Path(".jac/client/dist");

    """Setup web target (no-op for web, already set up by default)."""
    override def setup(project_dir: Path) -> None;

    """Build web bundle using existing Vite pipeline.

    Args:
        script_loading: Script loading strategy - 'module' (default, ES modules) or 'defer' (classic script for Tauri file://)
    """
    override def build(
        self: WebTarget,
        entry_file: Path,
        project_dir: Path,
        platform: Optional[str] = None,
        script_loading: str = "module"
    ) -> Path;

    """Start web dev server."""
    override def dev(
        entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;

    """Start web target (production preview mode)."""
    override def start(
        entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;
}
