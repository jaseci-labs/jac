def generate_wheel_file(
    generator_version: str = "",
    pure_python: bool = True,
    python_tag: str = "py3",
    abi_tag: str = "none",
    platform_tag: str = "any",
) -> str;

def generate_entry_points(config: JacConfig) -> str;

def dist_info_dirname(config: JacConfig) -> str;
