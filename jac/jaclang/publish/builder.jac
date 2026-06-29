import from pathlib { Path }
import from jaclang.project.config { JacConfig }

glob _WHEEL_TIMESTAMP: tuple = (2016, 1, 1, 0, 0, 0),
     _SDIST_MTIME: int = 1451606400;

obj WheelBuilder {
    has config: JacConfig,
        project_root: Path | None = None,
        pure_python: bool = True,
        python_tag: str = "py3",
        abi_tag: str = "none",
        platform_tag: str = "any";

    def postinit -> None;
    def build -> bytes;
    def build_to(output_dir: Path) -> Path;
    def install_editable(src_dir: Path, site_pkgs: Path) -> Path;
    def build_sdist -> bytes;
    def build_sdist_to(output_dir: Path) -> Path;
}
