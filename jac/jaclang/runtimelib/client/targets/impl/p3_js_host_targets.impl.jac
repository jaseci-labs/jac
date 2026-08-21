import from pathlib { Path }
import from typing { Optional }

glob _P3_ROW_MSG: str = 'P3 host is a registry row only; build/dev/start are not implemented yet';


def _p3_row_not_implemented(label: str) -> None {
    raise NotImplementedError(f"{label}: {_P3_ROW_MSG}");
}


impl P3RegistryRowHost.setup(project_dir: Path) -> None {
    _p3_row_not_implemented(self.name);
}

impl P3RegistryRowHost.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    _p3_row_not_implemented(self.name);
    return entry_file;
}

impl P3RegistryRowHost.dev(
    entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
) -> None {
    _p3_row_not_implemented(self.name);
}

impl P3RegistryRowHost.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    _p3_row_not_implemented(self.name);
}
