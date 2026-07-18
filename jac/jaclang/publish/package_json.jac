import from pathlib { Path }
import from jaclang.project.config { JacConfig }

def npm_settings(config: JacConfig) -> dict[str, any];

def npm_package_name(config: JacConfig) -> str;

def npm_tarball_filename(config: JacConfig) -> str;

def npm_dependencies(config: JacConfig) -> dict[str, str];

def npm_peer_dependencies(config: JacConfig) -> dict[str, str];

def generate_package_json(
    config: JacConfig,
    project_root: Path | None = None,
    main: str | None = None,
    types: str | None = None,
    extra_dependencies: dict[str, str] | None = None,
    extra_peer_dependencies: dict[str, str] | None = None,
) -> str;
