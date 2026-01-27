"""Worker process for background compilation.

Runs in a separate process to bypass Python's GIL for CPU-bound
compilation work. Communicates with main process via IPC queues.
"""

import multiprocessing;
import threading;
import logging;
import time;
import from typing { Optional, Callable, Any }
import from queue { Empty }

import from .snapshot { ProgramSnapshot }
import from .sem_manager { SemTokManager }

"""Configuration for worker process."""
obj WorkerConfig {
    has poll_interval_ms: float = 100,
        shutdown_timeout_ms: float = 5000,
        restart_on_crash: bool = True,
        max_restart_attempts: int = 3,
        cancel_check_interval_ms: float = 50,
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
    HEALTHY,     # Worker is responding to pings
    UNHEALTHY,   # Worker not responding but process alive
    DEAD,        # Worker process not running
    RESTARTING   # Worker is being restarted
}

"""Manages worker process lifecycle from main process."""
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
        _snapshot_callback: Callable | None = None,
        # Health monitoring
        _health_status: WorkerHealth = WorkerHealth.DEAD,
        _last_health_check: float = 0,
        _consecutive_failures: int = 0,
        _health_callback: Callable | None = None;

    def postinit -> None;
    """Generate next request ID (simple counter)."""
    def _next_request_id -> str;
    """Start the worker process."""
    def start -> None;

    """Stop the worker process."""
    def stop -> None;

    """Check if worker is running."""
    def is_running -> bool;

    """Send compile request for a file."""
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

    """Process a response dict."""
    def _process_response_dict(response_dict: dict) -> None;

    """Background response processor (DEPRECATED)."""
    def _response_processor -> None;

    """Background health checker."""
    def _health_checker -> None;

    """Notify health callback of status change."""
    def _notify_health_change(status: WorkerHealth) -> None;

    """Handle worker crash."""
    def _handle_crash -> None;

    """Set snapshot update callback."""
    def set_snapshot_callback(callback: Callable[[ProgramSnapshot], None]) -> None;

    """Set health status callback."""
    def set_health_callback(callback: Callable[[WorkerHealth], None]) -> None;

    """Get current worker health status."""
    def get_health -> WorkerHealth;

    """Ping worker to check if alive."""
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
