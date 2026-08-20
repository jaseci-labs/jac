import from pathlib { Path }
import from typing { Optional, cast }

impl TestHost.setup(project_dir: Path) -> None { }

impl TestHost.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    raise NotImplementedError("test host does not build artifacts");
}

impl TestHost.dev(
    entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
) -> None {
    raise NotImplementedError("test host is started via ensure_sv_service only");
}

impl TestHost.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    raise NotImplementedError("test host is started via ensure_sv_service only");
}
