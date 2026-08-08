import from pathlib { Path }
import from typing { Optional }
import from jaclang.runtimelib.client.targets.android.dev_server {
    _jac_start_dev_server
}
import from jaclang.runtimelib.client.targets.registry { ClientTarget }

obj AndroidTarget(ClientTarget) {
    has name: str = "android",
        default: bool = False,
        requires_setup: bool = True,
        config_section: str = "android",
        _type_check: bool = False;

    override def setup(project_dir: Path) -> None;
    override def build(
        entry_file: Path, project_dir: Path, platform: Optional[str] = None
    ) -> Path;

    override def dev(
        entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
    ) -> None;

    override def start(
        entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;

    def:priv _compile_compose_modules(
        entry_file: Path, project_dir: Path
    ) -> tuple[(any, any)];

    def:priv _load_android_cfg(project_dir: Path) -> dict;
    def:priv _apply_android_cfg_to_model(model: any, project_dir: Path) -> None;
    def:priv _resolve_type_check(project_dir: Path) -> bool;
    def:priv _resolve_client_framework(project_dir: Path) -> str | None;
    def:priv _ensure_compose_framework(project_dir: Path) -> None;
    def:priv _write_compose_framework(project_dir: Path) -> None;
    def:priv _android_dir(project_dir: Path) -> Path;
    def:priv _resolve_package_name(project_dir: Path) -> str;
    def:priv _run_gradle_assemble(
        android_dir: Path, release: bool = False, task: str = ""
    ) -> Path;

    def:priv _resolve_android_avd(project_dir: Path) -> str;
    def:priv _ensure_adb(project_dir: Path) -> str;
    def:priv _adb_install_launch(apk_path: Path, project_dir: Path) -> None;
    def:priv _adb_reverse_launch(apk_path: Path, project_dir: Path, port: int) -> None;
    def:priv _build_hot_dex(android_dir: Path, package_name: str) -> tuple[(str, any)];
    def:priv _locate_android_tools -> tuple[(any, any)];
    def:priv _collect_jac_sources(project_dir: Path) -> list;
    def:priv _attach_interop_manifest(model: any, mod: any) -> None;
    def:priv _merge_interop_manifest(into: any, src: any) -> None;
    def:priv _populate_compose_routes(
        model: any, project_dir: Path, program: any
    ) -> None;

    def:priv _synthesize_routes_from_screens(model: any) -> None;
    def:priv _compile_page_into_model(
        page_file: Path, program: any
    ) -> tuple[(any, any)];
}
