import from pathlib { Path }
import from typing { Optional }
import from jaclang.runtimelib.client.targets.web_target { WebTarget }

def inline_dist_assets(dist_dir: Path) -> bool;

def serve_static_dir(dist_dir: Path, host: str, port: int) -> None;

obj StaticTarget(WebTarget) {
    has name: str = "static",
        default: bool = False,
        requires_setup: bool = False,
        config_section: str = "plugin.client",
        output_dir: Path = Path(".jac/client/dist");

    override def build(
        entry_file: Path, project_dir: Path, platform: Optional[str] = None
    ) -> Path;

    override def start(
        entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;
}
