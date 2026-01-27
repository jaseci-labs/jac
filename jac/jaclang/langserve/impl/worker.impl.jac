"""Implementation of worker process for background compilation."""

import multiprocessing;
import threading;
import logging;
import time;
import sys;
import from typing { Optional, Callable, Any }
import from queue { Empty }

"""Internal debug logging for worker."""
def _worker_debug(msg: str) -> None {
    print(f"[Worker] {msg}", file=sys.stderr);
}

"""Internal debug logging for worker manager."""
def _mgr_debug(msg: str) -> None {
    print(f"[WorkerMgr] {msg}", file=sys.stderr);
}

impl WorkerConfig.default -> WorkerConfig {
    return WorkerConfig(
        poll_interval_ms=100,
        shutdown_timeout_ms=5000,
        restart_on_crash=True,
        max_restart_attempts=3,
        cancel_check_interval_ms=50,
        health_check_interval_ms=5000,
        health_check_timeout_ms=2000
    );
}

impl CompilationWorker.initialize(
    request_queue: Any,
    response_queue: Any,
    shutdown_event: Any,
    cancel_event: Any,
    config: WorkerConfig
) -> None {
    self._request_queue = request_queue;
    self._response_queue = response_queue;
    self._shutdown_event = shutdown_event;
    self._cancel_event = cancel_event;
    self._config = config;
    self._logger = logging.getLogger("jac.worker");
    self._current_request_id = None;
}

impl CompilationWorker.run -> None {
    # Import here to avoid loading in main process
    import from jaclang.pycore.program { JacProgram }
    import traceback;

    # Initialize program in worker process
    program = JacProgram();
    sem_managers: dict = {};

    # Send startup notification via IPC (main process will log)
    self._response_queue.put({
        'request_id': '__startup__',
        'success': True,
        'message': 'Worker process started'
    });

    poll_interval = (self._config.poll_interval_ms or 100) / 1000.0;

    while not self._shutdown_event.is_set() {
        try {
            # Non-blocking poll with timeout
            request_dict = self._request_queue.get(timeout=poll_interval);
        } except Empty {
            continue;
        } except Exception as e {
            # Send queue error via IPC
            self._response_queue.put({
                'request_id': '__error__',
                'success': False,
                'error_message': f"Queue error: {str(e)}",
                'error_type': 'QUEUE_ERROR'
            });
            continue;
        }

        # Clear cancellation before starting new work
        self.clear_cancellation();
        request_id = request_dict.get('request_id', '');
        self._current_request_id = request_id;

        # Process request
        try {
            request_type = request_dict.get('request_type', '');

            if request_type == 'SHUTDOWN' {
                self._response_queue.put(self._make_pong_response(request_id));
                break;
            } elif request_type == 'PING' {
                self._response_queue.put(self._make_pong_response(request_id));
            } elif request_type == 'COMPILE_FILE' {
                response_dict = self.handle_compile_file_dict(
                    request_dict, program, sem_managers
                );
                if not self.is_cancelled() {
                    self._response_queue.put(response_dict);
                } else {
                    self._response_queue.put(self._make_cancelled_response(request_id));
                }
            } elif request_type == 'COMPILE_ALL' {
                response_dict = self.handle_compile_all_dict(
                    request_dict, program, sem_managers
                );
                if not self.is_cancelled() {
                    self._response_queue.put(response_dict);
                } else {
                    self._response_queue.put(self._make_cancelled_response(request_id));
                }
            } else {
                self._response_queue.put(
                    self._make_error_response(
                        request_id, f"Unknown request type: {request_type}"
                    )
                );
            }
        } except Exception as e {
            # Send error with full traceback via IPC
            tb = traceback.format_exc();
            self._response_queue.put({
                'request_id': request_id,
                'success': False,
                'cancelled': False,
                'error_message': str(e),
                'error_traceback': tb,
                'error_type': 'PROCESSING_ERROR',
                'timestamp': time.time()
            });
        } finally {
            self._current_request_id = None;
        }
    }

    # Send shutdown notification via IPC
    self._response_queue.put({
        'request_id': '__shutdown__',
        'success': True,
        'message': 'Worker process exiting'
    });
}

impl CompilationWorker._make_pong_response(request_id: str) -> dict {
    return {
        'request_id': request_id,
        'success': True,
        'cancelled': False,
        'timestamp': time.time()
    };
}

impl CompilationWorker._make_error_response(
    request_id: str, error_message: str
) -> dict {
    return {
        'request_id': request_id,
        'success': False,
        'cancelled': False,
        'error_message': error_message,
        'timestamp': time.time()
    };
}

impl CompilationWorker._make_cancelled_response(request_id: str) -> dict {
    return {
        'request_id': request_id,
        'success': False,
        'cancelled': True,
        'timestamp': time.time()
    };
}

impl CompilationWorker.handle_compile_file_dict(
    request_dict: dict, program: Any, sem_managers: dict
) -> dict {
    start_time = time.time();
    request_id = request_dict.get('request_id', '');
    file_uri = request_dict.get('file_uri');
    source = request_dict.get('source');
    type_check = request_dict.get('type_check', True);
    no_cgen = request_dict.get('no_cgen', True);
    _worker_debug(f"compile_file: {file_uri} ({len(source) if source else 0} chars)");
    # Convert URI to file path
    if file_uri and file_uri.startswith("file://") {
        file_path = file_uri[7:];
    } else {
        file_path = file_uri;
    }
    if not file_path or not source {
        _worker_debug("Missing file_uri or source");
        return self._make_error_response(request_id, "Missing file_uri or source");
    }
    try {
        # Clear previous errors/warnings for this file
        program.errors_had = [
            e
            for e in program.errors_had
            if not (e?.loc and e.loc?.mod_path and e.loc.mod_path == file_path)
        ];
        program.warnings_had = [
            w
            for w in program.warnings_had
            if not (w?.loc and w.loc?.mod_path and w.loc.mod_path == file_path)
        ];

        # Create cancellation event for compiler passes
        cancel_event = threading.Event();

        # Check cancellation periodically
        if self.is_cancelled() {
            return self._make_cancelled_response(request_id);
        }

        # Compile with type checking, skip code gen
        _worker_debug(f"Starting compilation: type_check={type_check}, no_cgen={no_cgen}");
        module = program.compile(
            file_path=file_path,
            use_str=source,
            type_check=type_check,
            no_cgen=no_cgen,
            cancel_token=cancel_event
        );
        _worker_debug(f"Compilation finished, module={'valid' if module else 'None'}");

        if self.is_cancelled() {
            _worker_debug("Cancelled after compilation");
            return self._make_cancelled_response(request_id);
        }

        # IMPORTANT: Manually add module to hub even if there are parse errors.
        # The compiler's parse_str returns early on errors without adding to hub,
        # but LSP needs the partial AST for features like completion.
        if module and module?.loc {
            program.mod.hub[file_path] = module;
        }

        files_analyzed = [file_path];

        # Update semantic manager for this file
        if module and module?.loc {
            sem_managers[file_path] = SemTokManager(ir=module, hub=program.mod.hub);
        }

        # Handle impl files: if this file is annexable by another (e.g., foo.impl.jac -> foo.jac),
        # we need to recompile the parent file to get proper type checking
        if module and module?.annexable_by {
            parent_path = module.annexable_by;
            files_analyzed.append(parent_path);

            if self.is_cancelled() {
                return self._make_cancelled_response(request_id);
            }

            # Read parent file from disk and recompile
            try {
                with open(parent_path, 'r') as f {
                    parent_source = f.read();
                }
                # Clear parent file errors before recompiling
                program.errors_had = [
                    e for e in program.errors_had
                    if not (e?.loc and e.loc?.mod_path and e.loc.mod_path == parent_path)
                ];
                program.warnings_had = [
                    w for w in program.warnings_had
                    if not (w?.loc and w.loc?.mod_path and w.loc.mod_path == parent_path)
                ];

                parent_module = program.compile(
                    file_path=parent_path,
                    use_str=parent_source,
                    type_check=type_check,
                    no_cgen=no_cgen,
                    cancel_token=cancel_event
                );

                if parent_module and parent_module?.loc {
                    sem_managers[parent_path] = SemTokManager(
                        ir=parent_module, hub=program.mod.hub
                    );
                }
            } except FileNotFoundError {
                # Parent file doesn't exist yet, skip
            } except Exception as e {
                _worker_debug(f"Exception during parent file compilation: {e}");
            }
        }

        # Create snapshot
        _worker_debug("Creating snapshot");
        snapshot = self.create_snapshot(program, sem_managers);

        # Use shared memory for zero-copy transfer
        shm_result = snapshot.serialize_to_shared_memory();
        shm_name = shm_result[0];
        shm_size = shm_result[1];
        _worker_debug(f"Snapshot in shared memory: {shm_name}, {shm_size} bytes");

        duration_ms = (time.time() - start_time) * 1000;
        _worker_debug(f"Compilation complete: {duration_ms:.1f}ms, {len(program.errors_had)} errors, {len(program.warnings_had)} warnings");

        return {
            'request_id': request_id,
            'success': True,
            'cancelled': False,
            'shm_name': shm_name,
            'shm_size': shm_size,
            'errors': list(program.errors_had),
            'warnings': list(program.warnings_had),
            'duration_ms': duration_ms,
            'timestamp': time.time(),
            'files_analyzed': files_analyzed
        };
    } except Exception as e {
        _worker_debug(f"Compilation exception: {e}");
        import traceback;
        tb = traceback.format_exc();
        duration_ms = (time.time() - start_time) * 1000;
        # Return structured error via IPC (main process will log)
        return {
            'request_id': request_id,
            'success': False,
            'cancelled': False,
            'error_message': f"Compilation failed: {str(e)}",
            'error_traceback': tb,
            'error_type': 'COMPILATION_ERROR',
            'duration_ms': duration_ms,
            'timestamp': time.time(),
            'files_analyzed': [file_path] if file_path else []
        };
    }
}

impl CompilationWorker.handle_compile_all_dict(
    request_dict: dict, program: Any, sem_managers: dict
) -> dict {
    start_time = time.time();
    request_id = request_dict.get('request_id', '');
    # For now, create snapshot of current state
    # Full implementation would iterate workspace files
    snapshot = self.create_snapshot(program, sem_managers);

    # Use shared memory for zero-copy transfer
    shm_result = snapshot.serialize_to_shared_memory();
    shm_name = shm_result[0];
    shm_size = shm_result[1];

    duration_ms = (time.time() - start_time) * 1000;
    return {
        'request_id': request_id,
        'success': True,
        'cancelled': False,
        'shm_name': shm_name,
        'shm_size': shm_size,
        'errors': list(program.errors_had),
        'warnings': list(program.warnings_had),
        'duration_ms': duration_ms,
        'timestamp': time.time(),
        'files_analyzed': list(program.mod.hub.keys())
    };
}

impl CompilationWorker.create_snapshot(
    program: Any, sem_managers: dict
) -> ProgramSnapshot {
    # Don't include sem_managers in snapshot - they can't be pickled
    # Main process will recreate them from hub data
    return ProgramSnapshot.from_program_state(
        hub=program.mod.hub,
        sem_managers={},  # Empty - main process recreates
        errors=program.errors_had,
        warnings=program.warnings_had
    );
}

impl CompilationWorker.is_cancelled -> bool {
    if self._cancel_event {
        return self._cancel_event.is_set();
    }
    return False;
}

impl CompilationWorker.clear_cancellation -> None {
    if self._cancel_event {
        self._cancel_event.clear();
    }
}

impl WorkerManager.postinit -> None {
    self._config = self._config or WorkerConfig.default();
    self._request_counter = 0;
    self._pending_requests = {};
    self._logger = logging.getLogger("jac.worker_manager");
    self._running = False;
    self._snapshot_callback = None;
    self._diagnostics_callback = None;
    self._health_callback = None;
    self._current_request_id = None;
    self._restart_count = 0;
    # Debounce scheduling
    self._pending_uri = None;
    self._pending_source = None;
    self._timer = None;
    self._timer_lock = threading.Lock();
    self._last_activity = 0;
    self._analysis_in_progress = False;
    # Snapshot manager
    self._snapshot_manager = SnapshotManager();
    # Health monitoring
    self._health_status = WorkerHealth.DEAD;
    self._last_health_check = 0;
    self._consecutive_failures = 0;
}

"""Generate next request ID (simple counter, no lock needed - single thread access)."""
impl WorkerManager._next_request_id -> str {
    self._request_counter += 1;
    return f"req_{self._request_counter}";
}

impl WorkerManager.start -> None {
    _mgr_debug("start() called");
    if self._process and self._process.is_alive() {
        _mgr_debug("Worker already running");
        self._logger.warning("Worker already running");
        return;
    }
    # Create IPC primitives
    _mgr_debug("Creating IPC primitives");
    self._request_queue = multiprocessing.Queue();
    self._response_queue = multiprocessing.Queue();
    self._shutdown_event = multiprocessing.Event();
    self._cancel_event = multiprocessing.Event();
    # Config as dict for pickling
    config_dict = {
        'poll_interval_ms': self._config.poll_interval_ms,
        'shutdown_timeout_ms': self._config.shutdown_timeout_ms,
        'cancel_check_interval_ms': self._config.cancel_check_interval_ms
    };
    # Start worker process
    _mgr_debug("Starting worker process");
    self._process = multiprocessing.Process(
        target=worker_process_main,
        args=(
            self._request_queue,
            self._response_queue,
            self._shutdown_event,
            self._cancel_event,
            config_dict
        ),
        daemon=True
    );
    self._process.start();
    self._running = True;
    self._health_status = WorkerHealth.HEALTHY;
    self._consecutive_failures = 0;
    _mgr_debug(f"Worker process started: PID {self._process.pid}");

    # NOTE: No background threads - use process_pending_responses() from async loop instead
    self._logger.info(f"Worker process started: PID {self._process.pid}");
}

impl WorkerManager.stop -> None {
    _mgr_debug("stop() called");
    if not self._process {
        _mgr_debug("No process to stop");
        return;
    }
    self._running = False;
    # Send shutdown request as dict (for pickle compatibility)
    try {
        _mgr_debug("Sending shutdown request");
        shutdown_req = {
            'request_type': 'SHUTDOWN',
            'request_id': self._next_request_id(),
            'timestamp': time.time()
        };
        self._request_queue.put(shutdown_req);
    } except Exception as e {
        _mgr_debug(f"Error sending shutdown: {e}");
        self._logger.error(f"Error sending shutdown: {e}");
    }
    # Signal shutdown
    _mgr_debug("Setting shutdown event");
    self._shutdown_event.set();
    # Wait for graceful shutdown
    timeout = (self._config.shutdown_timeout_ms or 5000) / 1000.0;
    _mgr_debug(f"Waiting for graceful shutdown ({timeout}s timeout)");
    self._process.join(timeout=timeout);
    # Force terminate if still running
    if self._process.is_alive() {
        _mgr_debug("Force terminating worker");
        self._logger.warning("Force terminating worker");
        self._process.terminate();
        self._process.join(timeout=1.0);
    }
    self._process = None;
    _mgr_debug("Worker process stopped");
    self._logger.info("Worker process stopped");
}

impl WorkerManager.is_running -> bool {
    return self._running and self._process is not None and self._process.is_alive();
}

impl WorkerManager.compile_file(
    file_uri: str,
    source: str,
    callback: Optional[Callable] = None
) -> str {
    _mgr_debug(f"compile_file: {file_uri} ({len(source)} chars)");
    if not self.is_running() {
        _mgr_debug("Worker not running, starting...");
        self._logger.warning("Worker not running, starting...");
        self.start();
    }
    # Cancel any in-progress work - user typed again
    if self._current_request_id {
        _mgr_debug(f"Cancelling in-progress request: {self._current_request_id}");
        self.cancel_current();
    }
    request_id = self._next_request_id();
    self._current_request_id = request_id;
    _mgr_debug(f"Created request: {request_id}");
    # Use dict for IPC (pickle compatibility)
    request = {
        'request_type': 'COMPILE_FILE',
        'request_id': request_id,
        'file_uri': file_uri,
        'source': source,
        'timestamp': time.time(),
        'type_check': True,
        'no_cgen': True
    };
    if callback {
        self._pending_requests[request_id] = callback;
    }
    _mgr_debug(f"Queueing request: {request_id}");
    self._request_queue.put(request);
    return request_id;
}

impl WorkerManager.compile_all(callback: Optional[Callable] = None) -> str {
    if not self.is_running() {
        self.start();
    }
    request_id = self._next_request_id();
    # Use dict for IPC (pickle compatibility)
    request = {
        'request_type': 'COMPILE_ALL',
        'request_id': request_id,
        'timestamp': time.time(),
        'type_check': True,
        'no_cgen': True
    };
    if callback {
        self._pending_requests[request_id] = callback;
    }
    self._request_queue.put(request);
    return request_id;
}

impl WorkerManager.cancel_current -> None {
    if self._cancel_event {
        self._cancel_event.set();
        self._logger.debug("Cancellation requested");
    }
    self._analysis_in_progress = False;
}

"""Schedule a file for analysis with debouncing."""
impl WorkerManager.schedule_file(file_uri: str, source: str) -> None {
    _mgr_debug(f"schedule_file: {file_uri} ({len(source)} chars)");
    if not self._running {
        _mgr_debug("Not running, starting worker first");
        self.start();
    }
    # Record activity
    self._last_activity = time.time();
    # Replace any pending (most recent edit wins)
    self._pending_uri = file_uri;
    self._pending_source = source;
    # Cancel current analysis if in progress
    if self._analysis_in_progress {
        _mgr_debug("Cancelling in-progress analysis");
        self.cancel_current();
    }
    # Reset debounce timer
    self._reset_timer();
}

impl WorkerManager.has_pending -> bool {
    return self._pending_uri is not None;
}

impl WorkerManager.is_analyzing -> bool {
    return self._analysis_in_progress;
}

impl WorkerManager.is_busy -> bool {
    has_timer = False;
    with self._timer_lock {
        has_timer = self._timer is not None and self._timer.is_alive();
    }
    return self.has_pending() or has_timer or self._analysis_in_progress;
}

impl WorkerManager._on_timer_expired -> None {
    _mgr_debug("Timer expired");
    if not self._running {
        return;
    }
    # Check if enough time has passed since last activity
    elapsed = (time.time() - self._last_activity) * 1000;
    if elapsed < self._config.debounce_ms {
        # User still active, reset timer for remaining time
        remaining = self._config.debounce_ms - elapsed;
        _mgr_debug(f"User still active, resetting timer for {remaining:.0f}ms");
        with self._timer_lock {
            self._timer = threading.Timer(remaining / 1000.0, self._on_timer_expired);
            self._timer.daemon = True;
            self._timer.start();
        }
        return;
    }
    # Start processing pending file
    _mgr_debug(f"Debounce complete ({elapsed:.0f}ms elapsed), processing");
    self._process_pending();
}

impl WorkerManager._reset_timer -> None {
    with self._timer_lock {
        if self._timer is not None {
            self._timer.cancel();
            self._timer = None;
        }
        delay_sec = self._config.debounce_ms / 1000.0;
        self._timer = threading.Timer(delay_sec, self._on_timer_expired);
        self._timer.daemon = True;
        self._timer.start();
    }
}

impl WorkerManager._cancel_timer -> None {
    with self._timer_lock {
        if self._timer is not None {
            self._timer.cancel();
            self._timer = None;
        }
    }
}

impl WorkerManager._process_pending -> None {
    _mgr_debug("_process_pending called");
    if not self._running {
        return;
    }
    if self._pending_uri is None {
        _mgr_debug("No pending file");
        self._analysis_in_progress = False;
        return;
    }
    file_uri = self._pending_uri;
    source = self._pending_source;
    self._pending_uri = None;
    self._pending_source = None;
    _mgr_debug(f"Processing: {file_uri}");
    self._analysis_in_progress = True;
    # Send to worker
    self.compile_file(file_uri=file_uri, source=source);
}

impl WorkerManager._on_snapshot_received(snapshot: ProgramSnapshot) -> None {
    _mgr_debug(f"Snapshot received: v{snapshot.version}, {len(snapshot.hub)} files");
    self._analysis_in_progress = False;
    # Update snapshot manager
    if self._snapshot_manager is not None {
        self._snapshot_manager.update_snapshot(snapshot);
    }
    # Call snapshot callback
    if self._snapshot_callback is not None {
        try {
            self._snapshot_callback(snapshot);
        } except Exception as e {
            self._logger.error(f"Snapshot callback error: {e}");
        }
    }
    # Call diagnostics callback
    if self._diagnostics_callback is not None {
        try {
            self._diagnostics_callback(snapshot);
        } except Exception as e {
            self._logger.error(f"Diagnostics callback error: {e}");
        }
    }
    # Check if more pending work
    if self._pending_uri is not None {
        _mgr_debug("More pending work, scheduling");
        self._reset_timer();
    }
}

impl WorkerManager.set_diagnostics_callback(callback: Callable) -> None {
    self._diagnostics_callback = callback;
}

impl WorkerManager.get_snapshot -> Optional[ProgramSnapshot] {
    if self._snapshot_manager is not None {
        return self._snapshot_manager.get_snapshot();
    }
    return None;
}

impl WorkerManager.poll_responses -> list {
    responses: list = [];
    while True {
        try {
            # Response comes as dict
            response_dict = self._response_queue.get_nowait();
            responses.append(response_dict);
        } except Empty {
            break;
        } except Exception as e {
            self._logger.error(f"Error polling responses: {e}");
            break;
        }
    }
    return responses;
}

impl WorkerManager.process_pending_responses -> None {
    # Process all pending responses from the worker (call from async loop)
    responses = self.poll_responses();

    for response_dict in responses {
        self._process_response_dict(response_dict);
    }

    # Check for worker crash
    if self._process and not self._process.is_alive() and self._running {
        self._handle_crash();
    }
}

impl WorkerManager._response_processor -> None {
    # DEPRECATED: No longer used - use process_pending_responses() from async loop
    pass;
}

impl WorkerManager._process_response_dict(response_dict: dict) -> None {
    request_id = response_dict.get('request_id', '');
    _mgr_debug(f"Processing response: {request_id}");

    # Handle special worker messages (startup, shutdown, errors)
    if request_id == '__startup__' {
        _mgr_debug("Worker startup confirmed");
        self._logger.info("Worker: " + response_dict.get('message', 'started'));
        return;
    }
    if request_id == '__shutdown__' {
        _mgr_debug("Worker shutdown confirmed");
        self._logger.info("Worker: " + response_dict.get('message', 'stopped'));
        return;
    }
    if request_id == '__error__' {
        error_type = response_dict.get('error_type', 'UNKNOWN');
        error_msg = response_dict.get('error_message', 'Unknown error');
        _mgr_debug(f"Worker error: {error_type} - {error_msg}");
        self._logger.error(f"Worker {error_type}: {error_msg}");
        return;
    }

    # Clear current request tracking if this is our current request
    if self._current_request_id == request_id {
        _mgr_debug(f"Clearing current request: {request_id}");
        self._current_request_id = None;
    }

    # Skip processing cancelled responses (user already sent new request)
    if response_dict.get('cancelled', False) {
        _mgr_debug(f"Request {request_id} was cancelled, skipping");
        self._logger.debug(f"Request {request_id} was cancelled");
        self._pending_requests.pop(request_id, None);
        return;
    }

    # Log errors from the worker
    if not response_dict.get('success', False) {
        error_msg = response_dict.get('error_message', 'Unknown error');
        error_type = response_dict.get('error_type', 'ERROR');
        error_tb = response_dict.get('error_traceback', '');
        _mgr_debug(f"Request {request_id} failed: {error_type} - {error_msg}");
        self._logger.error(f"Worker {error_type} for request {request_id}: {error_msg}");
        if error_tb {
            self._logger.debug(f"Traceback:\n{error_tb}");
        }
    } else {
        duration = response_dict.get('duration_ms', 0);
        _mgr_debug(f"Request {request_id} succeeded in {duration:.1f}ms");
    }

    # Deserialize snapshot from shared memory if present
    snapshot: ProgramSnapshot | None = None;
    shm_name = response_dict.get('shm_name');
    shm_size = response_dict.get('shm_size');
    if shm_name and shm_size {
        try {
            _mgr_debug(f"Reading snapshot from shared memory: {shm_name}, {shm_size} bytes");
            snapshot = ProgramSnapshot.deserialize_from_shared_memory(shm_name, shm_size);
            _mgr_debug(f"Snapshot deserialized: v{snapshot.version}, {len(snapshot.hub)} files");
        } except Exception as e {
            _mgr_debug(f"Failed to read shared memory: {e}");
            self._logger.error(f"Shared memory read error: {e}");
        }
    }

    # Call registered callback with response dict
    if request_id in self._pending_requests {
        callback = self._pending_requests.pop(request_id);
        try {
            callback(response_dict);
        } except Exception as e {
            self._logger.error(f"Callback error for request {request_id}: {e}");
        }
    }

    # If success and has snapshot, handle it
    success = response_dict.get('success', False);
    if success and snapshot is not None {
        self._on_snapshot_received(snapshot);
    }
}

impl WorkerManager._handle_crash -> None {
    self._logger.error("Worker process crashed");
    self._health_status = WorkerHealth.DEAD;
    self._notify_health_change(WorkerHealth.DEAD);

    if not self._config.restart_on_crash {
        self._running = False;
        return;
    }
    if self._restart_count >= self._config.max_restart_attempts {
        self._logger.error(
            f"Max restart attempts ({self._config.max_restart_attempts}) reached, giving up"
        );
        self._running = False;
        return;
    }

    self._restart_count += 1;
    self._health_status = WorkerHealth.RESTARTING;
    self._notify_health_change(WorkerHealth.RESTARTING);
    self._logger.info(f"Restarting worker (attempt {self._restart_count})");

    # Clear old process
    self._process = None;
    # Restart
    self.start();
}

impl WorkerManager.set_snapshot_callback(
    callback: Callable[[ProgramSnapshot], None]
) -> None {
    self._snapshot_callback = callback;
}

impl WorkerManager.ping(timeout_ms: float = 1000) -> bool {
    if not self.is_running() {
        return False;
    }
    request_id = self._next_request_id();
    request = {
        'request_type': 'PING',
        'request_id': request_id,
        'timestamp': time.time()
    };
    self._request_queue.put(request);
    # Wait for response
    start_time = time.time();
    timeout_sec = timeout_ms / 1000.0;
    while time.time() - start_time < timeout_sec {
        responses = self.poll_responses();
        for response in responses {
            if response.get('request_id') == request_id {
                return response.get('success', False);
            }
            # Process other responses
            self._process_response_dict(response);
        }
        time.sleep(0.01);  # 10ms poll
    }
    return False;  # Timeout
}

"""Background health checker thread."""
impl WorkerManager._health_checker -> None {
    interval_sec = self._config.health_check_interval_ms / 1000.0;
    timeout_ms = self._config.health_check_timeout_ms;

    while self._running {
        time.sleep(interval_sec);

        if not self._running {
            break;
        }

        # Check process status first
        if not self._process or not self._process.is_alive() {
            old_status = self._health_status;
            self._health_status = WorkerHealth.DEAD;
            if old_status != WorkerHealth.DEAD {
                self._notify_health_change(WorkerHealth.DEAD);
            }
            continue;
        }

        # Skip ping check if worker is busy with a request - compilation can take time
        if self._current_request_id is not None {
            # Worker is busy, reset consecutive failures and continue
            self._consecutive_failures = 0;
            continue;
        }

        # Perform ping check
        self._last_health_check = time.time();
        ping_ok = self.ping(timeout_ms=timeout_ms);

        if ping_ok {
            self._consecutive_failures = 0;
            old_status = self._health_status;
            self._health_status = WorkerHealth.HEALTHY;
            if old_status != WorkerHealth.HEALTHY {
                self._notify_health_change(WorkerHealth.HEALTHY);
                self._logger.info("Worker health restored");
            }
        } else {
            self._consecutive_failures += 1;
            old_status = self._health_status;
            self._health_status = WorkerHealth.UNHEALTHY;
            if old_status != WorkerHealth.UNHEALTHY {
                self._notify_health_change(WorkerHealth.UNHEALTHY);
            }
            self._logger.warning(
                f"Worker health check failed ({self._consecutive_failures} consecutive)"
            );

            # After 3 consecutive failures, trigger recovery
            if self._consecutive_failures >= 3 and self._config.restart_on_crash {
                self._logger.error("Worker unresponsive, triggering recovery");
                self._health_status = WorkerHealth.RESTARTING;
                self._notify_health_change(WorkerHealth.RESTARTING);
                self._handle_crash();
            }
        }
    }
}

"""Notify health callback of status change."""
impl WorkerManager._notify_health_change(status: WorkerHealth) -> None {
    if self._health_callback is not None {
        try {
            self._health_callback(status);
        } except Exception as e {
            self._logger.error(f"Health callback error: {e}");
        }
    }
}

"""Set health status callback."""
impl WorkerManager.set_health_callback(
    callback: Callable[[WorkerHealth], None]
) -> None {
    self._health_callback = callback;
}

"""Get current worker health status."""
impl WorkerManager.get_health -> WorkerHealth {
    return self._health_status;
}

impl worker_process_main(
    request_queue: Any,
    response_queue: Any,
    shutdown_event: Any,
    cancel_event: Any,
    config_dict: dict
) -> None {
    # Configure logging in worker process
    logging.basicConfig(
        level=logging.INFO, format='[WORKER %(levelname)s] %(message)s'
    );
    config = WorkerConfig(
        poll_interval_ms=config_dict.get('poll_interval_ms', 100),
        shutdown_timeout_ms=config_dict.get('shutdown_timeout_ms', 5000),
        cancel_check_interval_ms=config_dict.get('cancel_check_interval_ms', 50)
    );
    worker = CompilationWorker();
    worker.initialize(
        request_queue, response_queue, shutdown_event, cancel_event, config
    );
    worker.run();
}
