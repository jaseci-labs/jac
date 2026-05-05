"""WHEEL file and entry_points.txt generators for jac bundle."""

import from jaclang.project.config { JacConfig }

"""Generate the .dist-info/WHEEL file content (version, generator, purity, and compatibility tag)."""
def generate_wheel_file(
    generator_version: str = "",
    pure_python: bool = True,
    python_tag: str = "py3",
    abi_tag: str = "none",
    platform_tag: str = "any",
) -> str;

"""Generate .dist-info/entry_points.txt content from a JacConfig; returns empty string when no [entrypoints]."""
def generate_entry_points(config: JacConfig) -> str;

"""Build the canonical .whl filename (PEP 427); raises ValueError when config.package is None."""
def wheel_filename(
    config: JacConfig,
    python_tag: str = "py3",
    abi_tag: str = "none",
    platform_tag: str = "any",
) -> str;

"""Build the .dist-info directory name (e.g. 'byllm-0.6.4.dist-info'); raises ValueError when config.package is None."""
def dist_info_dirname(config: JacConfig) -> str;
