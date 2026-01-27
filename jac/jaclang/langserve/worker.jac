"""Worker process for background compilation.

Runs in a separate process to bypass Python's GIL for CPU-bound
compilation work. Includes debounce scheduling and snapshot management.
"""

import multiprocessing;
import threading;
import logging;
import time;
import from typing { Optional, Callable, Any }
import from queue { Empty }

import from .snapshot { ProgramSnapshot, SnapshotManager }
import from .sem_manager { SemTokManager }

"""Configuration for worker process."""
obj WorkerConfig {
    has poll_interval_ms: float = 100,
        shutdown_timeout_ms: float = 5000,
        restart_on_crash: bool = True,
        max_restart_attempts: int = 3,
        cancel_check_interval_ms: float = 50,
        # Debounce
        debounce_ms: float = 250,
        # Health monitoring
        health_check_interval_ms: float = 5000,
        health_check_timeout_ms: float = 2000;

    """Return default config."""
    static def default -> WorkerConfig;
}

"""Compilation worker that runs in a separate process."""
obj CompilationWorker {
    has _request_queue: Any | None = None,
        _response_queue: Any | None = None,
        _shutdown_event: Any | None = None,
        _cancel_event: Any | None = None,
        _config: WorkerConfig | None = None,
        _logger: Any | None = None,
        _current_request_id: str | None = None;

    """Initialize worker (called in worker process)."""
    def initialize(
        request_queue: Any,
        response_queue: Any,
        shutdown_event: Any,
        cancel_event: Any,
        config: WorkerConfig
    ) -> None;

    """Main worker loop."""
    def run -> None;

    """Internal compile file method."""
    def _compile_file(request: dict, program: Any, sem_managers: dict) -> dict;

    """Handle compile file request (dict-based)."""
    def handle_compile_file_dict(
        request_dict: dict, program: Any, sem_managers: dict
    ) -> dict;

    """Handle compile all request (dict-based)."""
    def handle_compile_all_dict(
        request_dict: dict, program: Any, sem_managers: dict
    ) -> dict;

    """Create snapshot from program state."""
    def create_snapshot(program: Any, sem_managers: dict) -> ProgramSnapshot;

    """Check if cancelled."""
    def is_cancelled -> bool;

    """Clear cancellation flag."""
    def clear_cancellation -> None;

    """Create pong response dict."""
    def _make_pong_response(request_id: str) -> dict;

    """Create error response dict."""
    def _make_error_response(request_id: str, error_message: str) -> dict;

    """Create cancelled response dict."""
    def _make_cancelled_response(request_id: str) -> dict;
}

"""Worker health status."""
enum WorkerHealth {
    HEALTHY,
    UNHEALTHY,
    DEAD,
    RESTARTING
}

"""Manages worker process with debounce scheduling.

Combines worker lifecycle management with intelligent scheduling:
- Debounces rapid edits (waits 250ms after user stops typing)
- Cancels in-progress work when new edits arrive
- Manages snapshots and diagnostics callbacks
"""
obj WorkerManager {
    has _process: Any | None = None,
        _request_queue: Any | None = None,
        _response_queue: Any | None = None,
        _shutdown_event: Any | None = None,
        _cancel_event: Any | None = None,
        _config: WorkerConfig | None = None,
        _request_counter: int = 0,
        _pending_requests: dict | None = None,
        _current_request_id: str | None = None,
        _restart_count: int = 0,
        _logger: Any | None = None,
        _response_thread: threading.Thread | None = None,
        _health_thread: threading.Thread | None = None,
        _running: bool = False,
        # Debounce scheduling
        _pending_uri: str | None = None,
        _pending_source: str | None = None,
        _timer: threading.Timer | None = None,
        _timer_lock: threading.Lock | None = None,
        _last_activity: float = 0,
        _analysis_in_progress: bool = False,
        # Snapshots
        _snapshot_manager: SnapshotManager | None = None,
        _snapshot_callback: Callable | None = None,
        _diagnostics_callback: Callable | None = None,
        # Health monitoring
        _health_status: WorkerHealth = WorkerHealth.DEAD,
        _last_health_check: float = 0,
        _consecutive_failures: int = 0,
        _health_callback: Callable | None = None;

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
    def schedule_file(file_uri: str, source: str) -> None;

    """Check if there is pending work."""
    def has_pending -> bool;

    """Check if analysis is in progress."""
    def is_analyzing -> bool;

    """Check if busy (pending, timer active, or analyzing)."""
    def is_busy -> bool;

    """Send compile request immediately (no debounce)."""
    def compile_file(
        file_uri: str,
        source: str,
        callback: Optional[Callable] = None
    ) -> str;

    """Send compile all request."""
    def compile_all(callback: Optional[Callable] = None) -> str;

    """Cancel current compilation."""
    def cancel_current -> None;

    """Poll for responses."""
    def poll_responses -> list;

    """Process all pending responses (call from async loop)."""
    def process_pending_responses -> None;

    """Handle a single response from worker."""
    def _handle_response(response: dict) -> None;

    """Process a response dict."""
    def _process_response_dict(response_dict: dict) -> None;

    """Handle timer expiry - start analysis."""
    def _on_timer_expired -> None;

    """Reset the debounce timer."""
    def _reset_timer -> None;

    """Cancel the debounce timer."""
    def _cancel_timer -> None;

    """Process pending file."""
    def _process_pending -> None;

    """Handle snapshot from worker."""
    def _on_snapshot_received(snapshot: ProgramSnapshot) -> None;

    """Background response processor (DEPRECATED)."""
    def _response_processor -> None;

    """Background health checker."""
    def _health_checker -> None;

    """Notify health callback."""
    def _notify_health_change(status: WorkerHealth) -> None;

    """Handle worker crash."""
    def _handle_crash -> None;

    """Set snapshot update callback."""
    def set_snapshot_callback(callback: Callable[[ProgramSnapshot], None]) -> None;

    """Set diagnostics callback."""
    def set_diagnostics_callback(callback: Callable) -> None;

    """Set health status callback."""
    def set_health_callback(callback: Callable[[WorkerHealth], None]) -> None;

    """Get current worker health."""
    def get_health -> WorkerHealth;

    """Get current snapshot."""
    def get_snapshot -> Optional[ProgramSnapshot];

    """Ping worker."""
    def ping(timeout_ms: float = 1000) -> bool;
}

"""Entry point for worker process."""
def worker_process_main(
    request_queue: Any,
    response_queue: Any,
    shutdown_event: Any,
    cancel_event: Any,
    config_dict: dict
) -> None;
