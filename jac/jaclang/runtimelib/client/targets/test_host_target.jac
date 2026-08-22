import from pathlib { Path }
import from typing { Optional }
import from jaclang.runtimelib.client.targets.registry { Host }
import from jaclang.jac0core.host { HOST_TEST }

obj TestHost(Host) {
    has name: str = "test",
        host_kind: str = HOST_TEST,
        `default: bool = False,
        requires_setup: bool = False,
        config_section: str = "",
        output_dir: Optional[Path] = None;

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
