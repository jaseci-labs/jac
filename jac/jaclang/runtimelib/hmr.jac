"""Hot Module Replacement handler for jac start.

Coordinates file watching and module reloading for development workflow.
Uses AST-based classification to determine client vs server declarations.
"""

import threading;
import from enum { StrEnum }
import from pathlib { Path }
import from typing { Callable }
import type from jaclang.runtimelib.watcher {
    JacFileWatcher,
    FileChangeEvent,
    ChangeType
}

"""Dev-server build health, served over HTTP via get_build_status()."""
enum BuildStatus(StrEnum) {
    OK = "ok",
    COMPILING = "compiling",
    ERROR = "error",
    UNAVAILABLE = "unavailable"
}

"""Handles hot reloading of Jac modules."""
obj HotReloader {
    has base_path: str,
        module_name: str,
        watcher: any,  # JacFileWatcher - using Any to avoid circular import
        _client_output_dir: str = ".jac/client/compiled",
        _running: bool = False,
        _overlay_entry: bool = False,
        _build_status: BuildStatus = BuildStatus.OK,
        _build_error_file: str = "",
        _build_error: str = "";

    # The running reloader (so servers can serve build status without wiring)
    static has _active: any = None,
        _build_lock: any = threading.Lock();

    def start -> None;
    def stop -> None;
    def on_file_change(
        event: any
    ) -> None;  # FileChangeEvent - using Any to avoid circular import


    def build_status -> dict;
    def record_ok -> None;
    def record_error(file_path: str, message: str) -> None;
    def _process_change(file_path: str) -> None;
    def _dispatch_change(file_path: str) -> None;
    def _reload_server_module(file_path: str) -> None;
    def _recompile_client_code(
        file_path: str, visited: set | None = None, force: bool = True
    ) -> None;

    def _classify_declarations(file_path: str) -> tuple[bool, bool];
    def _path_to_module(file_path: str) -> str;
    def _get_js_filename(file_path: str) -> str;
    def _emit_client_error_overlay(file_path: str, errors: str) -> None;
    def _copy_frontend_files(file_path: str) -> None;
    def _update_entry_point -> None;
}

"""Active reloader's build health: ok | compiling | error (with file and
message) | unavailable (no reloader running, i.e. non-dev mode)."""
def get_build_status -> dict;
