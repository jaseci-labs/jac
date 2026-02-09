"""Mobile target implementation.

This target wraps the existing web bundle in an Expo app with WebView,
enabling Jac web apps to run on iOS/Android with zero code changes.
Same pattern as desktop target: web bundle → native shell.
"""
import from pathlib { Path }
import from typing { Optional }
import from jac_client.plugin.src.targets.registry { ClientTarget }

"""Mobile build target (Expo + WebView)."""
class MobileTarget(ClientTarget) {
    def init(self: MobileTarget) {
        self.name = "mobile";
        self.default = False;
        self.requires_setup = True;
        self.config_section = "plugins.client.mobile";
        self.output_dir = Path(".jac/mobile");
    }

    """Setup mobile target - scaffold Expo project with WebView shell."""
    override def setup(self: MobileTarget, project_dir: Path) -> None;

    """Build mobile app - build web bundle first, then wrap with Expo."""
    override def build(
        self: MobileTarget,
        entry_file: Path,
        project_dir: Path,
        platform: Optional[str] = None
    ) -> Path;

    """Start mobile dev server - start jac backend and launch Expo dev server."""
    override def dev(
        self: MobileTarget, entry_file: Path, project_dir: Path,
        api_port: int = 8000
    ) -> None;

    """Start mobile app - build web bundle and launch Expo with built bundle."""
    override def start(
        self: MobileTarget, entry_file: Path, project_dir: Path,
        api_port: int = 8000
    ) -> None;
}
