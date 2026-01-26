"""Analysis scheduler with user activity backoff.

Coordinates compilation work with smart scheduling: waits 250ms after
user stops typing before starting analysis, cancels in-flight work
when new edits arrive, and prioritizes open files.
"""

import threading;
import time;
import from typing { Optional, Callable, Any }
import from enum { auto }

import from .ipc { RequestPriority }
import from .worker { WorkerManager, WorkerConfig }
import from .snapshot { ProgramSnapshot, SnapshotManager }
import from .cancellation { CancellationTokenSource }

"""Priority levels for pending analysis."""
enum AnalysisPriority {
    FOREGROUND = 0,  # Currently focused file
    OPEN_FILE = 1,  # Open in editor but not focused
    IMPORTED = 2,  # Imported by open files
    BACKGROUND = 3  # Everything else
}

"""Configuration for the analysis scheduler."""
obj SchedulerConfig {
    has user_activity_backoff_ms: float = 250,
        batch_window_ms: float = 50,
        max_pending_files: int = 100,
        idle_analysis_delay_ms: float = 1000,
        enable_background_analysis: bool = True;

    """Return default config."""
    static def default -> SchedulerConfig;
}

"""Represents a file pending analysis."""
obj PendingAnalysis {
    has file_uri: str,
        source: str | None = None,
        priority: AnalysisPriority = AnalysisPriority.OPEN_FILE,
        timestamp: float = 0,
        version: int = 0;

    def postinit -> None;
    """Compare for priority queue ordering."""
    def __lt__(other: PendingAnalysis) -> bool;
}

"""Main analysis scheduler coordinating compilation work."""
obj AnalysisScheduler {
    has _config: SchedulerConfig | None = None,
        _worker_manager: WorkerManager | None = None,
        _snapshot_manager: SnapshotManager | None = None,
        _pending: dict | None = None,
        _pending_lock: threading.Lock | None = None,
        _timer: threading.Timer | None = None,
        _timer_lock: threading.Lock | None = None,
        _last_activity: float = 0,
        _running: bool = False,
        _analysis_in_progress: bool = False,
        _current_cancel_source: CancellationTokenSource | None = None,
        _open_files: set | None = None,
        _focused_file: str | None = None,
        _diagnostics_callback: Callable | None = None,
        _logger: Any | None = None;

    def postinit -> None;
    """Start the scheduler."""
    def start -> None;

    """Stop the scheduler."""
    def stop -> None;

    """Schedule a file for analysis."""
    def schedule_file(
        file_uri: str, source: str, priority: Optional[AnalysisPriority] = None
    ) -> None;

    """Schedule all open files for reanalysis."""
    def schedule_all_open -> None;

    """Mark a file as open in editor."""
    def mark_file_open(file_uri: str) -> None;

    """Mark a file as closed in editor."""
    def mark_file_closed(file_uri: str) -> None;

    """Set the currently focused file."""
    def set_focused_file(file_uri: str | None) -> None;

    """Cancel current analysis."""
    def cancel_current -> None;

    """Check if analysis is in progress."""
    def is_analyzing -> bool;

    """Check if there are pending files to analyze."""
    def has_pending -> bool;

    """Check if backoff timer is active."""
    def has_timer_active -> bool;

    """Check if scheduler has any work (pending, timer, or in-progress)."""
    def is_busy -> bool;

    """Get current snapshot."""
    def get_snapshot -> Optional[ProgramSnapshot];

    """Set diagnostics callback."""
    def set_diagnostics_callback(callback: Callable) -> None;

    """Handle timer expiry - start analysis."""
    def _on_timer_expired -> None;

    """Reset the backoff timer."""
    def _reset_timer -> None;

    """Cancel the backoff timer."""
    def _cancel_timer -> None;

    """Process pending files."""
    def _process_pending -> None;

    """Get next file to analyze based on priority."""
    def _get_next_pending -> Optional[PendingAnalysis];

    """Handle snapshot from worker."""
    def _on_snapshot_received(snapshot: ProgramSnapshot) -> None;

    """Determine priority for a file."""
    def _get_file_priority(file_uri: str) -> AnalysisPriority;
}
