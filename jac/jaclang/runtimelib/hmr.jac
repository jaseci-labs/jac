"""Hot Module Replacement handler for jac start.

Coordinates file watching and module reloading for development workflow.
Uses AST-based classification to determine client vs server declarations.
"""

import from pathlib { Path }
import from typing { TYPE_CHECKING, Any, Callable }

with entry {
    if TYPE_CHECKING {
        import from jaclang.runtimelib.watcher {
            JacFileWatcher,
            FileChangeEvent,
            ChangeType
        }
    }
}

"""Handles hot reloading of Jac modules."""
obj HotReloader {
    has base_path: str,
        module_name: str,
        watcher: Any,  # JacFileWatcher - using Any to avoid circular import
        _client_output_dir: str = ".jac/client/compiled",
        _running: bool = False,
        _overlay_entry: bool = False;

    def start -> None;
    def stop -> None;
    def on_file_change(
        event: Any
    ) -> None;  # FileChangeEvent - using Any to avoid circular import


    def _process_change(file_path: str) -> None;
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
