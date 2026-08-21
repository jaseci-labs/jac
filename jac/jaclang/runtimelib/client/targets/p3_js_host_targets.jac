import from pathlib { Path }
import from typing { Optional }
import from jaclang.runtimelib.client.targets.registry { Host }
import from jaclang.jac0core.host { P3_JS_HOST_KINDS }

obj P3RegistryRowHost(Host) {
    has name: str,
        host_kind: str,
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

def p3_js_host_targets -> list[Host] {
    hosts: list[Host] = [];
    for kind in P3_JS_HOST_KINDS {
        hosts.append(P3RegistryRowHost(name=kind, host_kind=kind));
    }
    return hosts;
}
