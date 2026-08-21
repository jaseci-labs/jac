import from pathlib { Path }
import from typing { Optional }
import from jaclang.runtimelib.client.targets.registry { Host }
import from jaclang.jac0core.host {
    HOST_CLI_JS,
    HOST_EDGE,
    HOST_SERVICE_WORKER,
    HOST_WEB_WORKER
}

obj WebWorkerTarget(Host) {
    has name: str = "web-worker",
        host_kind: str = HOST_WEB_WORKER,
        default: bool = False,
        requires_setup: bool = False,
        config_section: str = "plugin.client",
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

obj ServiceWorkerTarget(Host) {
    has name: str = "service-worker",
        host_kind: str = HOST_SERVICE_WORKER,
        default: bool = False,
        requires_setup: bool = False,
        config_section: str = "plugin.client",
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

obj EdgeTarget(Host) {
    has name: str = "edge",
        host_kind: str = HOST_EDGE,
        default: bool = False,
        requires_setup: bool = False,
        config_section: str = "plugin.client",
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

obj CliJsTarget(Host) {
    has name: str = "cli-js",
        host_kind: str = HOST_CLI_JS,
        default: bool = False,
        requires_setup: bool = False,
        config_section: str = "plugin.client",
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
