import from pathlib { Path }
import from typing { Optional }
import from jaclang.server.watcher { FileChangeEvent }
import from jaclang.client.targets.registry { ClientTarget }
import from jaclang.client.targets.client_dev_common { _ClientHmrHandler }

obj _RNHmrHandler(_ClientHmrHandler) {
    has rn_dir: Path,
        entry_module: str;

    def on_event(evt: FileChangeEvent) -> None;
}

obj MobileTarget(ClientTarget) {
    has name: str = "mobile",
        requires_setup: bool = True,
        config_section: str = "react_native";

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

    def:priv _compile_native_jac_modules(entry_file: Path) -> tuple[(any, Path)];
}
