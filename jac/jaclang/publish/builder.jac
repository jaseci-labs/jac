"""WheelBuilder — zips all wheel components into a PEP 427 .whl archive."""

import from pathlib { Path }
import from jaclang.project.config { JacConfig }

# Fixed timestamp for all zip entries — produces reproducible wheels.
# (year, month, day, hour, minute, second) — convention used by pip and hatch.
glob _WHEEL_TIMESTAMP: tuple = (2016, 1, 1, 0, 0, 0);

"""Builds a .whl archive from a JacConfig and the project source tree."""
obj WheelBuilder {
    has config: JacConfig,
        project_root: Path | None = None,
        pure_python: bool = True,
        python_tag: str = "py3",
        abi_tag: str = "none",
        platform_tag: str = "any";

    def postinit -> None;
    """Build the wheel in memory and return its raw bytes; raises ValueError when config.package is None."""
    def build -> bytes;

    """Build the wheel and write it to output_dir/<name>.whl; returns the Path written."""
    def build_to(output_dir: Path) -> Path;

    """Write dist-info for an editable install of src_dir into site_pkgs; returns the .pth path written."""
    def install_editable(src_dir: Path, site_pkgs: Path) -> Path;
}
