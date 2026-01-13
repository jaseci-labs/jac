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
        _running: bool = False;

    """Start the hot reloader and begin watching for changes."""
    def start -> None;

    """Stop the hot reloader and file watcher."""
    def stop -> None;

    """Callback for file change events from the watcher."""
    def on_file_change(event: Any) -> None;  # FileChangeEvent - using Any to avoid circular import


    """Process a file change by classifying declarations and taking action."""
    def _process_change(file_path: str) -> None;

    """Reload server-side module in sys.modules."""
    def _reload_server_module(file_path: str) -> None;

    """Recompile client declarations to JavaScript."""
    def _recompile_client_code(file_path: str) -> None;

    """Get client and server declarations from a file."""
    def _classify_declarations(file_path: str) -> tuple[bool, bool];

    """Convert file path to module name."""
    def _path_to_module(file_path: str) -> str;

    """Convert a .jac file path to a .js filename."""
    def _get_js_filename(file_path: str) -> str;
}
