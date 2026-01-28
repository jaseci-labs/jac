"""Worker process for background compilation and LSP queries.

Runs in a separate process to bypass Python's GIL for CPU-bound
compilation work. Handles both compilation AND foreground LSP requests
(hover, definition, etc.) to avoid heavy IPC overhead.

Architecture:
- Worker keeps JacProgram and all AST/type info
- Main process forwards LSP requests to worker
- Only small responses sent back (hover text, locations, diagnostics)
- Foreground requests cancel ongoing compilation, get handled, then compilation restarts
"""

import threading;
import from typing { Optional, Callable, Any }

"""Request types for worker IPC."""
enum RequestType {
    # Compilation
    COMPILE_FILE,
    SHUTDOWN,
    # Foreground LSP requests (high priority - interrupt compilation)
    HOVER,
    DEFINITION,
    REFERENCES,
    COMPLETION,
    OUTLINE,
    SEMANTIC_TOKENS,
    RENAME,
    FORMAT
}

"""Configuration for worker process."""
obj WorkerConfig {
    has poll_interval_ms: float = 100,
        shutdown_timeout_ms: float = 5000,
        debounce_ms: float = 250;

    static def default -> WorkerConfig;
}

"""Compilation worker that runs in a separate process.

Handles both compilation AND foreground LSP requests (hover, definition, etc.).
Keeps JacProgram persistent - no AST serialization needed for queries.
"""
obj CompilationWorker {
    has _request_queue: Any | None = None,
        _response_queue: Any | None = None,
        _shutdown_event: Any | None = None,
        _cancel_event: Any | None = None,
        _config: WorkerConfig | None = None,
        _foreground_queue: Any | None = None;

    """Initialize worker (called in worker process)."""
    def initialize(
        request_queue: Any,
        response_queue: Any,
        shutdown_event: Any,
        cancel_event: Any,
        config: WorkerConfig,
        foreground_queue: Any | None = None
    ) -> None;

    """Main worker loop."""
    def run -> None;

    """Check if there are pending foreground requests."""
    def has_foreground_request -> bool;

    """Process all pending foreground requests."""
    def process_foreground_requests(program: Any, sem_managers: dict) -> None;

    """Internal compile file method."""
    def _compile_file(request: dict, program: Any, sem_managers: dict) -> dict;

    """Serialize diagnostics for a file into lightweight dict."""
    def _serialize_diagnostics(file_path: str, program: Any) -> dict;

    # Foreground request handlers
    """Handle hover request."""
    def handle_hover(request: dict, program: Any, sem_managers: dict) -> dict;

    """Handle definition request."""
    def handle_definition(request: dict, program: Any, sem_managers: dict) -> dict;

    """Handle references request."""
    def handle_references(request: dict, program: Any, sem_managers: dict) -> dict;

    """Handle completion request."""
    def handle_completion(request: dict, program: Any, sem_managers: dict) -> dict;

    """Handle outline request."""
    def handle_outline(request: dict, program: Any, sem_managers: dict) -> dict;

    """Handle semantic tokens request."""
    def handle_semantic_tokens(request: dict, program: Any, sem_managers: dict) -> dict;

    """Handle rename request."""
    def handle_rename(request: dict, program: Any, sem_managers: dict) -> dict;

    """Handle format request."""
    def handle_format(request: dict, program: Any) -> dict;

    """Check if cancelled."""
    def is_cancelled -> bool;

    """Clear cancellation flag."""
    def clear_cancellation -> None;

    # Helper methods for LSP features
    """Get token at position from semantic manager."""
    def _get_token_at_position(
        file_path: str, line: int, character: int, sem_managers: dict, hub: dict
    ) -> Any | None;

    """Get node info for hover."""
    def _get_node_info(sym_node: Any) -> str | None;

    """Get node at position from AST."""
    def _get_node_at_position(
        file_path: str, line: int, col: int, hub: dict
    ) -> Any | None;

    """Create location dict from AST node."""
    def _make_location_dict(ast_node: Any) -> dict | None;

    """Get completion items for a node's type."""
    def _get_completion_for_node(expr_node: Any, program: Any) -> list;

    """Get completion items for a scope."""
    def _get_completion_for_scope(scope_node: Any) -> list;
}

"""Manages worker process with debounce scheduling.

Combines worker lifecycle management with intelligent scheduling:
- Debounces rapid edits (waits 250ms after user stops typing)
- Cancels in-progress work when new edits arrive
- Forwards foreground LSP requests to worker (hover, definition, etc.)
- Manages diagnostics callbacks (no more full AST snapshots)
"""
obj WorkerManager {
    has _process: Any | None = None,
        _request_queue: Any | None = None,
        _response_queue: Any | None = None,
        _foreground_queue: Any | None = None,
        _shutdown_event: Any | None = None,
        _cancel_event: Any | None = None,
        _config: WorkerConfig | None = None,
        _request_counter: int = 0,
        _pending_requests: dict | None = None,
        _current_request_id: str | None = None,
        _running: bool = False,
        _pending_uri: str | None = None,
        _timer: threading.Timer | None = None,
        _timer_lock: threading.Lock | None = None,
        _last_activity: float = 0,
        _analysis_in_progress: bool = False,
        _diagnostics_callback: Callable | None = None;

    def postinit -> None;
    """Generate next request ID."""
    def _next_request_id -> str;
    """Start the worker process."""
    def start -> None;
    """Stop the worker process."""
    def stop -> None;
    """Check if worker is running."""
    def is_running -> bool;

    """Schedule a file for analysis with debouncing.

    Waits for user to stop typing before starting analysis.
    Cancels any in-progress work when new edit arrives.
    """
    def schedule_file(file_uri: str) -> None;

    """Check if there is pending work."""
    def has_pending -> bool;

    """Check if busy (pending, timer active, or analyzing)."""
    def is_busy -> bool;

    """Send compile request immediately (no debounce). Worker reads source from disk."""
    def compile_file(
        file_uri: str,
        callback: Optional[Callable] = None
    ) -> str;

    """Cancel current compilation."""
    def cancel_current -> None;

    # Foreground LSP request methods (blocking - wait for response)
    """Send hover request and wait for response."""
    def request_hover(file_path: str, line: int, character: int, timeout_ms: float = 5000) -> dict | None;

    """Send definition request and wait for response."""
    def request_definition(file_path: str, line: int, character: int, timeout_ms: float = 5000) -> dict | None;

    """Send references request and wait for response."""
    def request_references(file_path: str, line: int, character: int, timeout_ms: float = 5000) -> dict | None;

    """Send completion request and wait for response."""
    def request_completion(
        file_path: str, line: int, character: int, trigger: str | None = None, timeout_ms: float = 5000
    ) -> dict | None;

    """Send outline request and wait for response."""
    def request_outline(file_path: str, timeout_ms: float = 5000) -> dict | None;

    """Send semantic tokens request and wait for response."""
    def request_semantic_tokens(file_path: str, timeout_ms: float = 5000) -> dict | None;

    """Send rename request and wait for response."""
    def request_rename(
        file_path: str, line: int, character: int, new_name: str, timeout_ms: float = 5000
    ) -> dict | None;

    """Send format request and wait for response."""
    def request_format(file_path: str, source: str, timeout_ms: float = 5000) -> dict | None;

    """Internal: send foreground request and wait for response."""
    def _send_foreground_request(request: dict, timeout_ms: float) -> dict | None;

    """Process all pending responses (call from async loop)."""
    def process_pending_responses -> None;

    """Handle a single response from worker."""
    def _handle_response(response: dict) -> None;

    """Handle timer expiry - start analysis."""
    def _on_timer_expired -> None;

    """Reset the debounce timer."""
    def _reset_timer -> None;

    """Cancel the debounce timer."""
    def _cancel_timer -> None;

    """Process pending file."""
    def _process_pending -> None;

    """Set diagnostics callback."""
    def set_diagnostics_callback(callback: Callable) -> None;
}

"""Entry point for worker process."""
def worker_process_main(
    request_queue: Any,
    response_queue: Any,
    shutdown_event: Any,
    cancel_event: Any,
    config_dict: dict,
    foreground_queue: Any | None = None
) -> None;
