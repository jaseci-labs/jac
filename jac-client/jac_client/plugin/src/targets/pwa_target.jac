"""PWA (Progressive Web App) target implementation.

Extends WebTarget to add PWA capabilities:
- manifest.json generation
- Service worker for offline support
- Installability

PWA builds use web bundle as foundation, then add PWA artifacts.
"""
import from pathlib { Path }
import from typing { Optional }
import from jac_client.plugin.src.targets.web_target { WebTarget }

"""PWA build target - extends WebTarget with PWA artifacts."""
obj PWATarget(WebTarget) {
    has name: str = "pwa",
        default: bool = False,
        requires_setup: bool = False,
        config_section: str = "plugins.client.pwa",
        output_dir: Path = Path(".jac/client/dist");

    """Setup PWA target - copies default icons and configures jac.toml."""
    override def setup(project_dir: Path) -> None;

    """Build PWA bundle - web bundle + manifest + service worker."""
    override def build(
        entry_file: Path, project_dir: Path, platform: Optional[str] = None
    ) -> Path;

    """Start PWA dev server."""
    override def dev(
        entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;

    """Start PWA server - build PWA bundle and serve with HTTP server."""
    override def start(
        entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;
}
