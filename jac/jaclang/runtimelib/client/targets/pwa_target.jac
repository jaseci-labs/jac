import from pathlib { Path }
import from typing { Optional }
import from jaclang.runtimelib.client.targets.web_target { WebTarget }

obj PWATarget(WebTarget) {
    has name: str = "pwa",
        default: bool = False,
        requires_setup: bool = False,
        config_section: str = "plugins.client.pwa",
        output_dir: Path = Path(".jac/client/dist");

    override def setup(project_dir: Path) -> None;
    override def build(
        entry_file: Path, project_dir: Path, platform: Optional[str] = None
    ) -> Path;

    override def dev(
        entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
    ) -> None;

    override def start(
        entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;
}
