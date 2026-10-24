import from pathlib { Path }

def client_workspace_app(
    config: JacConfig | None, entry_path: str = ""
) -> AppConfig | None;

def client_app_dir_for(config: JacConfig, entry_path: str = "") -> Path;

def client_app_root(
    config: JacConfig | None, project_dir: Path, entry_path: str = ""
) -> Path;


def client_assets_config(
    config: JacConfig | None, entry_path: str = ""
) -> dict[str, any];


def client_input_dirs(
    config: JacConfig | None, project_dir: Path, entry_path: str = ""
) -> list[str];


def client_assets_dir(
    config: JacConfig | None, project_dir: Path, entry_path: str = ""
) -> Path;
