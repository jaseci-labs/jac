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
class PWATarget(WebTarget) {
    def init(self: PWATarget) {
        super.init();
        self.name = "pwa";
        self.default = False;
        self.requires_setup = False;
        self.config_section = "plugins.client.pwa";
        self.output_dir = Path(".jac/client/dist");
    }

    """Setup PWA target - copies default icons and configures jac.toml."""
    override def setup(self: PWATarget, project_dir: Path) -> None;

    """Build PWA bundle - web bundle + manifest + service worker."""
    override def build(
        self: PWATarget,
        entry_file: Path,
        project_dir: Path,
        platform: Optional[str] = None
    ) -> Path;

    """Start PWA dev server."""
    override def dev(
        self: PWATarget, entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;

    """Start PWA server - build PWA bundle and serve with HTTP server."""
    override def start(
        self: PWATarget, entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;
}
