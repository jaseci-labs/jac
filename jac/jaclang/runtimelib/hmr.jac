import threading;
import from enum { StrEnum }
import from pathlib { Path }
import type from jaclang.runtimelib.watcher {
    JacFileWatcher,
    FileChangeEvent,
    ChangeType
}

enum BuildStatus(StrEnum) {
    OK = "ok",
    COMPILING = "compiling",
    ERROR = "error",
    UNAVAILABLE = "unavailable"
}

obj HotReloader {
    has base_path: str,
        module_name: str,
        watcher: any,
        client_compiler: any = None,
        _client_output_dir: str = ".jac/client/compiled",
        _running: bool = False,
        _build_status: BuildStatus = BuildStatus.OK,
        _build_error_file: str = "",
        _build_error: str = "",
        _reload_nonce: int = 0;

    static has _active: any = None,
        _build_lock: any = threading.Lock();

    def start -> None;
    def stop -> None;
    def on_file_change(event: any) -> None;
    def build_status -> dict;
    def _dev_status_error -> (dict | None);
    def record_ok -> None;
    def record_error(file_path: str, message: str) -> None;
    def _process_change(file_path: str, is_directory: bool = False) -> None;
    def _dispatch_change(file_path: str, is_directory: bool = False) -> None;
    def _reload_server_module(file_path: str) -> None;
    def _recompile_client_code(
        file_path: str, visited: set | None = None, force: bool = True
    ) -> None;

    def _recompile_client_unified(file_path: str) -> None;
    def _client_js_path(file_path: str) -> (Path | None);
    def _extract_js_exports(js_path: Path) -> set[str];
    def _signal_full_reload -> None;
    def _remove_compiled_output(file_path: str) -> None;
    def _remove_compiled_dir(file_path: str) -> None;
    def _refresh_routing(file_path: str) -> None;
    def _entry_module_path -> Path;
    def _error_file_path -> Path;
    def _sync_error_file -> None;
    def _classify_declarations(file_path: str) -> tuple[bool, bool];
    def _path_to_module(file_path: str) -> str;
    def _get_js_filename(file_path: str) -> str;
    def _copy_frontend_files(file_path: str) -> None;
}

def get_build_status -> dict;
