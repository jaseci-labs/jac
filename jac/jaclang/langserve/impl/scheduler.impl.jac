"""Implementation of analysis scheduler."""

import threading;
import time;
import logging;
import from typing { Optional, Callable, Any }

impl SchedulerConfig.default -> SchedulerConfig {
    return SchedulerConfig();
}

impl PendingAnalysis.postinit -> None {
    if self.timestamp == 0 {
        self.timestamp = time.time();
    }
}

impl PendingAnalysis.__lt__(other: PendingAnalysis) -> bool {
    # Lower priority value = higher priority
    if self.priority.value != other.priority.value {
        return self.priority.value < other.priority.value;
    }
    # Earlier timestamp = higher priority
    return self.timestamp < other.timestamp;
}

impl AnalysisScheduler.postinit -> None {
    if self._config is None {
        self._config = SchedulerConfig.default();
    }
    if self._pending is None {
        self._pending = {};
    }
    if self._pending_lock is None {
        self._pending_lock = threading.Lock();
    }
    if self._timer_lock is None {
        self._timer_lock = threading.Lock();
    }
    if self._open_files is None {
        self._open_files = set();
    }
    if self._snapshot_manager is None {
        self._snapshot_manager = SnapshotManager();
    }
    self._logger = logging.getLogger("jac.scheduler");
}

impl AnalysisScheduler.start -> None {
    if self._running {
        return;
    }
    self._running = True;
    # Create worker manager if not provided
    if self._worker_manager is None {
        self._worker_manager = WorkerManager(_config=WorkerConfig.default());
    }
    # Set up snapshot callback
    self._worker_manager.set_snapshot_callback(self._on_snapshot_received);
    # Start worker
    self._worker_manager.start();
    self._logger.info("Analysis scheduler started");
}

impl AnalysisScheduler.stop -> None {
    if not self._running {
        return;
    }
    self._running = False;
    # Cancel any pending timer
    self._cancel_timer();
    # Cancel current analysis
    self.cancel_current();
    # Stop worker
    if self._worker_manager is not None {
        self._worker_manager.stop();
    }
    self._logger.info("Analysis scheduler stopped");
}

impl AnalysisScheduler.schedule_file(
    file_uri: str, source: str, priority: Optional[AnalysisPriority] = None
) -> None {
    if not self._running {
        return;
    }
    # Record activity
    self._last_activity = time.time();
    # Determine priority if not specified
    if priority is None {
        priority = self._get_file_priority(file_uri);
    }
    # Add to pending queue
    with self._pending_lock {
        # Check queue size limit
        if len(self._pending) >= self._config.max_pending_files {
            # Remove lowest priority item
            if self._pending {
                lowest_uri = max(
                    self._pending.keys(),
                    key=lambda u: str : self._pending[u].priority.value
                );
                if self._pending[lowest_uri].priority.value > priority.value {
                    del self._pending[lowest_uri] ;
                } else {
                    # New item is lower priority, skip it
                    return;
                }
            }
        }
        # Add or update pending analysis
        self._pending[file_uri] = PendingAnalysis(
            file_uri=file_uri, source=source, priority=priority
        );
    }
    # Cancel current analysis if in progress
    if self._analysis_in_progress {
        self.cancel_current();
    }
    # Reset backoff timer
    self._reset_timer();
    self._logger.debug(f"Scheduled {file_uri} with priority {priority}");
}

impl AnalysisScheduler.schedule_all_open -> None {
    with self._pending_lock {
        for file_uri in self._open_files {
            if file_uri not in self._pending {
                # Schedule with no source - will use cached
                self._pending[file_uri] = PendingAnalysis(
                    file_uri=file_uri,
                    source=None,
                    priority=self._get_file_priority(file_uri)
                );
            }
        }
    }
    self._reset_timer();
}

impl AnalysisScheduler.mark_file_open(file_uri: str) -> None {
    self._open_files.add(file_uri);
}

impl AnalysisScheduler.mark_file_closed(file_uri: str) -> None {
    self._open_files.discard(file_uri);
    if self._focused_file == file_uri {
        self._focused_file = None;
    }
}

impl AnalysisScheduler.set_focused_file(file_uri: str | None) -> None {
    self._focused_file = file_uri;
}

impl AnalysisScheduler.cancel_current -> None {
    # Cancel the token (which will trigger callback to cancel worker)
    if self._current_cancel_source is not None {
        self._current_cancel_source.cancel();
        self._current_cancel_source = None;
    }
    # Also directly cancel worker as fallback (idempotent operation)
    if self._worker_manager is not None {
        self._worker_manager.cancel_current();
    }
    self._analysis_in_progress = False;
    self._logger.debug("Analysis cancelled");
}

impl AnalysisScheduler.is_analyzing -> bool {
    return self._analysis_in_progress;
}

impl AnalysisScheduler.has_pending -> bool {
    with self._pending_lock {
        return len(self._pending) > 0;
    }
}

impl AnalysisScheduler.has_timer_active -> bool {
    with self._timer_lock {
        return self._timer is not None and self._timer.is_alive();
    }
}

impl AnalysisScheduler.is_busy -> bool {
    """Returns True if scheduler has any pending work, active timer, or in-progress analysis."""
    return self.has_pending() or self.has_timer_active() or self._analysis_in_progress;
}

impl AnalysisScheduler.get_snapshot -> Optional[ProgramSnapshot] {
    if self._snapshot_manager is not None {
        return self._snapshot_manager.get_snapshot();
    }
    return None;
}

impl AnalysisScheduler.set_diagnostics_callback(callback: Callable) -> None {
    self._diagnostics_callback = callback;
}

impl AnalysisScheduler._on_timer_expired -> None {
    if not self._running {
        return;
    }
    # Check if enough time has passed since last activity
    elapsed = (time.time() - self._last_activity) * 1000;
    if elapsed < self._config.user_activity_backoff_ms {
        # User still active, reset timer for remaining time
        remaining = self._config.user_activity_backoff_ms - elapsed;
        with self._timer_lock {
            self._timer = threading.Timer(remaining / 1000.0, self._on_timer_expired);
            self._timer.daemon = True;
            self._timer.start();
        }
        return;
    }
    # Start processing pending files
    self._process_pending();
}

impl AnalysisScheduler._reset_timer -> None {
    with self._timer_lock {
        # Cancel existing timer
        if self._timer is not None {
            self._timer.cancel();
            self._timer = None;
        }
        # Start new timer
        delay_sec = self._config.user_activity_backoff_ms / 1000.0;
        self._timer = threading.Timer(delay_sec, self._on_timer_expired);
        self._timer.daemon = True;
        self._timer.start();
    }
}

impl AnalysisScheduler._cancel_timer -> None {
    with self._timer_lock {
        if self._timer is not None {
            self._timer.cancel();
            self._timer = None;
        }
    }
}

impl AnalysisScheduler._process_pending -> None {
    if not self._running {
        return;
    }
    # Get next file to analyze
    pending = self._get_next_pending();
    if pending is None {
        self._analysis_in_progress = False;
        return;
    }
    self._analysis_in_progress = True;

    # Create cancellation source with callback to cancel worker
    # This bridges the main-process CancellationToken to the worker's multiprocessing.Event
    self._current_cancel_source = CancellationTokenSource();
    # Register callback so any token cancellation propagates to worker
    def on_cancel {
        if self._worker_manager is not None {
            self._worker_manager.cancel_current();
            self._logger.debug("Cancellation propagated to worker");
        }
    }
    self._current_cancel_source.token.register_callback(on_cancel);

    # Map priority to request priority
    req_priority = RequestPriority.NORMAL;
    if pending.priority == AnalysisPriority.FOREGROUND {
        req_priority = RequestPriority.HIGH;
    } elif pending.priority == AnalysisPriority.BACKGROUND {
        req_priority = RequestPriority.LOW;
    }

    # Send to worker
    if pending.source is not None {
        self._worker_manager.compile_file(
            file_uri=pending.file_uri, source=pending.source, priority=req_priority
        );
    } else {
        # No source provided, trigger compile all
        self._worker_manager.compile_all();
    }
    self._logger.debug(f"Started analysis for {pending.file_uri}");
}

impl AnalysisScheduler._get_next_pending -> Optional[PendingAnalysis] {
    with self._pending_lock {
        if not self._pending {
            return None;
        }
        best_uri = min(
            self._pending.keys(),
            key=lambda u: str :
                (self._pending[u].priority.value, self._pending[u].timestamp)
        );
        return self._pending.pop(best_uri);
    }
}

impl AnalysisScheduler._on_snapshot_received(snapshot: ProgramSnapshot) -> None {
    self._analysis_in_progress = False;
    self._current_cancel_source = None;
    # Update snapshot manager
    if self._snapshot_manager is not None {
        self._snapshot_manager.update_snapshot(snapshot);
    }
    # Publish diagnostics
    if self._diagnostics_callback is not None {
        try {
            self._diagnostics_callback(snapshot);
        } except Exception as e {
            self._logger.error(f"Diagnostics callback failed: {e}");
        }
    }
    # Check if more pending work
    with self._pending_lock {
        has_more = len(self._pending) > 0;
    }
    if has_more {
        # Schedule next batch
        self._reset_timer();
    }
    self._logger.debug(f"Snapshot received, version {snapshot.version}");
}

impl AnalysisScheduler._get_file_priority(file_uri: str) -> AnalysisPriority {
    if file_uri == self._focused_file {
        return AnalysisPriority.FOREGROUND;
    }
    if file_uri in self._open_files {
        return AnalysisPriority.OPEN_FILE;
    }
    return AnalysisPriority.BACKGROUND;
}
