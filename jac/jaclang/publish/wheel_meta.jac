import from jaclang.project.config { JacConfig }

def generate_wheel_file(
    generator_version: str = "",
    pure_python: bool = True,
    python_tag: str = "py3",
    abi_tag: str = "none",
    platform_tag: str = "any",
) -> str;

def generate_entry_points(config: JacConfig) -> str;

def wheel_filename(
    config: JacConfig,
    python_tag: str = "py3",
    abi_tag: str = "none",
    platform_tag: str = "any",
) -> str;

def dist_info_dirname(config: JacConfig) -> str;

def sdist_filename(config: JacConfig) -> str;
