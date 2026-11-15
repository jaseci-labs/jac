import from pathlib { Path }

obj AppLayout {
    has directory: Path,
        executable: Path,
        resources: Path,
        bundle: Path | None = None;

    static def for_host(directory: Path, app_name: str, host: str) -> AppLayout;
    static def from_executable(executable: Path) -> AppLayout;
    def library_dir -> Path;
    def launcher -> Path;
    def launch_target -> str;
}
