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
        platform_tag: str = "any",
        transpile_jac: bool = True,
        skipped_codespace: list[str] = [],
        vendored_runtime_modules: int = 0,
        _src_data_cache: dict[str, bytes] | None = None;

    def postinit -> None;
    def source_data -> dict[str, bytes];
    def _assemble_src_data -> dict[str, bytes];
    def _vendor_runtime_into(src_data: dict[str, bytes], codes: list[str]) -> None;
    def _top_level_names(src_data: dict[str, bytes]) -> list[str];
    def _build_backend_script(src_data: dict[str, bytes]) -> str;
    def build -> bytes;
    def build_to(output_dir: Path) -> Path;
    def install_editable(src_dir: Path, site_pkgs: Path) -> Path;
    def build_sdist -> bytes;
    def build_sdist_to(output_dir: Path) -> Path;
}
