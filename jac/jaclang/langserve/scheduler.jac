"""Analysis scheduler with user activity backoff.

Simplified scheduler: waits after user stops typing (debounce),
cancels in-flight work when new edits arrive, tracks single pending file.
"""

import threading;
import time;
import from typing { Optional, Callable, Any }

import from .worker { WorkerManager, WorkerConfig }
import from .snapshot { ProgramSnapshot, SnapshotManager }

"""Configuration for the analysis scheduler."""
obj SchedulerConfig {
    has debounce_ms: float = 250,  # Wait after user stops typing
        enable_background_analysis: bool = True;

    """Return default config."""
    static def default -> SchedulerConfig;
}

"""Main analysis scheduler coordinating compilation work."""
obj AnalysisScheduler {
    has _config: SchedulerConfig | None = None,
        _worker_manager: WorkerManager | None = None,
        _snapshot_manager: SnapshotManager | None = None,
        # Single pending file (most recent edit wins)
        _pending_uri: str | None = None,
        _pending_source: str | None = None,
        # Debounce timer
        _timer: threading.Timer | None = None,
        _timer_lock: threading.Lock | None = None,
        _last_activity: float = 0,
        _running: bool = False,
        _analysis_in_progress: bool = False,
        # Track open files for diagnostics
        _open_files: set | None = None,
        _diagnostics_callback: Callable | None = None,
        _logger: Any | None = None;

    def postinit -> None;
    """Start the scheduler."""
    def start -> None;

    """Stop the scheduler."""
    def stop -> None;

    """Schedule a file for analysis (replaces any pending)."""
    def schedule_file(file_uri: str, source: str) -> None;

    """Mark a file as open in editor."""
    def mark_file_open(file_uri: str) -> None;

    """Mark a file as closed in editor."""
    def mark_file_closed(file_uri: str) -> None;

    """Cancel current analysis."""
    def cancel_current -> None;

    """Check if analysis is in progress."""
    def is_analyzing -> bool;

    """Check if there is a pending file to analyze."""
    def has_pending -> bool;

    """Check if debounce timer is active."""
    def has_timer_active -> bool;

    """Check if scheduler has any work (pending, timer, or in-progress)."""
    def is_busy -> bool;

    """Process pending responses from worker (call from async loop)."""
    def process_worker_responses -> None;

    """Get current snapshot."""
    def get_snapshot -> Optional[ProgramSnapshot];

    """Set diagnostics callback."""
    def set_diagnostics_callback(callback: Callable) -> None;

    """Handle timer expiry - start analysis."""
    def _on_timer_expired -> None;

    """Reset the debounce timer."""
    def _reset_timer -> None;

    """Cancel the debounce timer."""
    def _cancel_timer -> None;

    """Process the pending file."""
    def _process_pending -> None;

    """Handle snapshot from worker."""
    def _on_snapshot_received(snapshot: ProgramSnapshot) -> None;
}
