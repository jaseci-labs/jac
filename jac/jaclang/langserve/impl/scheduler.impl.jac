"""Implementation of simplified analysis scheduler."""

import threading;
import time;
import logging;
import sys;
import from typing { Optional, Callable, Any }

"""Internal debug logging."""
def _sched_debug(msg: str) -> None {
    print(f"[Scheduler] {msg}", file=sys.stderr);
}

impl SchedulerConfig.default -> SchedulerConfig {
    return SchedulerConfig();
}

impl AnalysisScheduler.postinit -> None {
    if self._config is None {
        self._config = SchedulerConfig.default();
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
    _sched_debug("start() called");
    if self._running {
        _sched_debug("Already running, skipping start");
        return;
    }
    self._running = True;
    # Create worker manager if not provided
    if self._worker_manager is None {
        _sched_debug("Creating new WorkerManager");
        self._worker_manager = WorkerManager(_config=WorkerConfig.default());
    }
    # Set up snapshot callback
    self._worker_manager.set_snapshot_callback(self._on_snapshot_received);
    # Start worker
    self._worker_manager.start();
    _sched_debug("Scheduler started successfully");
    self._logger.info("Analysis scheduler started");
}

impl AnalysisScheduler.stop -> None {
    _sched_debug("stop() called");
    if not self._running {
        _sched_debug("Not running, skipping stop");
        return;
    }
    self._running = False;
    # Cancel any pending timer
    _sched_debug("Cancelling timer...");
    self._cancel_timer();
    # Cancel current analysis
    _sched_debug("Cancelling current analysis...");
    self.cancel_current();
    # Stop worker
    if self._worker_manager is not None {
        _sched_debug("Stopping worker manager...");
        self._worker_manager.stop();
    }
    _sched_debug("Scheduler stopped");
    self._logger.info("Analysis scheduler stopped");
}

impl AnalysisScheduler.schedule_file(file_uri: str, source: str) -> None {
    _sched_debug(f"schedule_file called: {file_uri} ({len(source)} chars)");
    if not self._running {
        _sched_debug("Scheduler not running, ignoring schedule request");
        return;
    }
    # Record activity
    self._last_activity = time.time();
    # Replace any pending (most recent edit wins)
    self._pending_uri = file_uri;
    self._pending_source = source;
    _sched_debug(f"Set pending file: {file_uri}");
    # Cancel current analysis if in progress
    if self._analysis_in_progress {
        _sched_debug("Cancelling in-progress analysis");
        self.cancel_current();
    }
    # Reset debounce timer
    _sched_debug("Resetting debounce timer");
    self._reset_timer();
    self._logger.debug(f"Scheduled {file_uri}");
}

impl AnalysisScheduler.mark_file_open(file_uri: str) -> None {
    self._open_files.add(file_uri);
}

impl AnalysisScheduler.mark_file_closed(file_uri: str) -> None {
    self._open_files.discard(file_uri);
}

impl AnalysisScheduler.cancel_current -> None {
    # Directly cancel worker
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
    return self._pending_uri is not None;
}

impl AnalysisScheduler.has_timer_active -> bool {
    with self._timer_lock {
        return self._timer is not None and self._timer.is_alive();
    }
}

impl AnalysisScheduler.is_busy -> bool {
    return self.has_pending() or self.has_timer_active() or self._analysis_in_progress;
}

impl AnalysisScheduler.process_worker_responses -> None {
    # Process pending responses from worker (call from async loop)
    if self._worker_manager is not None {
        self._worker_manager.process_pending_responses();
    }
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
    _sched_debug("Timer expired");
    if not self._running {
        _sched_debug("Not running, ignoring timer");
        return;
    }
    # Check if enough time has passed since last activity
    elapsed = (time.time() - self._last_activity) * 1000;
    if elapsed < self._config.debounce_ms {
        # User still active, reset timer for remaining time
        remaining = self._config.debounce_ms - elapsed;
        _sched_debug(f"User still active, resetting timer for {remaining:.0f}ms");
        with self._timer_lock {
            self._timer = threading.Timer(remaining / 1000.0, self._on_timer_expired);
            self._timer.daemon = True;
            self._timer.start();
        }
        return;
    }
    # Start processing pending file
    _sched_debug(f"Debounce complete ({elapsed:.0f}ms elapsed), processing pending");
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
        delay_sec = self._config.debounce_ms / 1000.0;
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
    _sched_debug("_process_pending called");
    if not self._running {
        _sched_debug("Scheduler not running, skipping");
        return;
    }
    # Get pending file
    if self._pending_uri is None {
        _sched_debug("No pending file, setting idle");
        self._analysis_in_progress = False;
        return;
    }
    file_uri = self._pending_uri;
    source = self._pending_source;
    # Clear pending
    self._pending_uri = None;
    self._pending_source = None;
    _sched_debug(f"Processing: {file_uri}");
    self._analysis_in_progress = True;
    # Send to worker
    _sched_debug(f"Sending compile_file to worker: {file_uri}");
    self._worker_manager.compile_file(file_uri=file_uri, source=source);
    self._logger.debug(f"Started analysis for {file_uri}");
}

impl AnalysisScheduler._on_snapshot_received(snapshot: ProgramSnapshot) -> None {
    _sched_debug(f"Snapshot received: v{snapshot.version}, {len(snapshot.hub)} files, {len(snapshot.errors)} errors");
    self._analysis_in_progress = False;
    # Update snapshot manager
    if self._snapshot_manager is not None {
        _sched_debug("Updating snapshot manager");
        self._snapshot_manager.update_snapshot(snapshot);
    }
    # Publish diagnostics
    if self._diagnostics_callback is not None {
        _sched_debug("Calling diagnostics callback");
        try {
            self._diagnostics_callback(snapshot);
        } except Exception as e {
            _sched_debug(f"Diagnostics callback failed: {e}");
            self._logger.error(f"Diagnostics callback failed: {e}");
        }
    }
    # Check if more pending work
    if self._pending_uri is not None {
        _sched_debug("More pending work, scheduling");
        self._reset_timer();
    } else {
        _sched_debug("No more pending work");
    }
    self._logger.debug(f"Snapshot received, version {snapshot.version}");
}
