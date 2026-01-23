"""Web target implementation.

This is the default target for building web applications.
"""
import from pathlib { Path }
import from typing { Optional }
import from jac_client.plugin.src.targets.registry { ClientTarget }

"""Web build target."""
class WebTarget(ClientTarget) {
    def init(self: WebTarget) {
        self.name = "web";
        self.default = True;
        self.requires_setup = False;
        self.config_section = "plugin.client";
        self.output_dir = Path(".jac/client/dist");
    }

    """Setup web target (no-op for web, already set up by default)."""
    override def setup(self: WebTarget, project_dir: Path) -> None;

    """Build web bundle using existing Vite pipeline."""
    override def build(
        self: WebTarget,
        entry_file: Path,
        project_dir: Path,
        platform: Optional[str] = None
    ) -> Path;

    """Start web dev server."""
    override def dev(self: WebTarget, entry_file: Path, project_dir: Path) -> None;

    """Start web target (no-op for web, handled by jac start)."""
    override def start(self: WebTarget, entry_file: Path, project_dir: Path) -> None;
}
