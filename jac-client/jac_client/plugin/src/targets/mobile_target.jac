"""Mobile target implementation.

Extends WebTarget to add React Native mobile app capabilities.
Mobile builds use web bundle as foundation, then wrap with React Native WebView.
"""
import from pathlib { Path }
import from typing { Optional }
import from jac_client.plugin.src.targets.web_target { WebTarget }

"""Mobile build target - extends WebTarget with React Native wrapping."""
obj MobileTarget(WebTarget) {
    has name: str = "mobile",
        default: bool = False,
        requires_setup: bool = True,
        config_section: str = "mobile",
        output_dir: Path = Path("mobile");

    """Setup mobile target - scaffold React Native project structure."""
    override def setup(project_dir: Path) -> None;

    """Build mobile app - build web bundle first, then wrap with React Native."""
    override def build(
        entry_file: Path,
        project_dir: Path,
        platform: Optional[str] = None,
        build_type: str = "production",
        use_eas: bool = True
    ) -> Path;

    """Start mobile dev server - start web dev server and launch Expo dev."""
    override def dev(
        entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;

    """Start mobile app - build web bundle and launch React Native with built bundle."""
    override def start(
        entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;
}
