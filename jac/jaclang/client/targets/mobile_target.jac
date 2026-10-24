import from pathlib { Path }
import from typing { Optional }

obj _RNHmrHandler(_ClientHmrHandler) {
    has rn_dir: Path,
        entry_module: str;

    def on_event(evt: FileChangeEvent) -> None;
}

obj MobileTarget(ClientTarget) {
    has name: str = "mobile",
        requires_setup: bool = True,
        config_section: str = "react_native";

    override def setup(project_dir: Path) -> None;
    override def ensure_ready(
        project_dir: Path, platform: Optional[str] = None
    ) -> None;

    override def build(
        entry_file: Path, project_dir: Path, platform: Optional[str] = None
    ) -> Path;

    override def dev(
        entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
    ) -> None;

    override def start(
        entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;

    def:priv _provision(project_dir: Path, rn_dir: Path) -> None;
    def:priv _compile_native_jac_modules(entry_file: Path) -> tuple[(any, Path)];
}

impl _simctl_install_and_launch(
    xcrun: str, udid: str, app_path: Path, bundle_id: str | None
) {
    console.print(
        f"  Installing .app on simulator {udid}: {app_path.name}", style="muted"
    );
    subprocess.run(
        [xcrun, "simctl", "install", udid, str(app_path)],
        check=True,
        capture_output=True
    );
    if bundle_id {
        bid: str = str(bundle_id);
        console.print(f"  Launching: {bid}", style="muted");
        subprocess.run(
            [xcrun, "simctl", "launch", udid, bid], check=False, capture_output=True
        );
    }
}
