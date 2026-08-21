import from pathlib { Path }
import from typing { Optional }

glob _P3_ROW_MSG: str = 'P3 host is a registry row only; build/dev/start are not implemented yet';


def _p3_row_not_implemented(label: str) -> None {
    raise NotImplementedError(f"{label}: {_P3_ROW_MSG}");
}


impl WebWorkerTarget.setup(project_dir: Path) -> None { }

impl WebWorkerTarget.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    _p3_row_not_implemented('web-worker');
    return entry_file;
}

impl WebWorkerTarget.dev(
    entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
) -> None {
    _p3_row_not_implemented('web-worker');
}

impl WebWorkerTarget.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    _p3_row_not_implemented('web-worker');
}

impl ServiceWorkerTarget.setup(project_dir: Path) -> None { }

impl ServiceWorkerTarget.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    _p3_row_not_implemented('service-worker');
    return entry_file;
}

impl ServiceWorkerTarget.dev(
    entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
) -> None {
    _p3_row_not_implemented('service-worker');
}

impl ServiceWorkerTarget.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    _p3_row_not_implemented('service-worker');
}

impl EdgeTarget.setup(project_dir: Path) -> None { }

impl EdgeTarget.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    _p3_row_not_implemented('edge');
    return entry_file;
}

impl EdgeTarget.dev(
    entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
) -> None {
    _p3_row_not_implemented('edge');
}

impl EdgeTarget.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    _p3_row_not_implemented('edge');
}

impl CliJsTarget.setup(project_dir: Path) -> None { }

impl CliJsTarget.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    _p3_row_not_implemented('cli-js');
    return entry_file;
}

impl CliJsTarget.dev(
    entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
) -> None {
    _p3_row_not_implemented('cli-js');
}

impl CliJsTarget.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    _p3_row_not_implemented('cli-js');
}
