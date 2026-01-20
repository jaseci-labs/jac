"""Implementation of worker process for background compilation."""

import multiprocessing;
import threading;
import logging;
import time;
import from typing { Optional, Callable, Any }
import from queue { Empty }

impl WorkerConfig.default -> WorkerConfig {
    return WorkerConfig(
        poll_interval_ms=100,
        shutdown_timeout_ms=5000,
        restart_on_crash=True,
        max_restart_attempts=3,
        cancel_check_interval_ms=50
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
    # Initialize program in worker process
    program = JacProgram();
    sem_managers: dict = {};
    self._logger.info("Worker process started");
    poll_interval = (self._config.poll_interval_ms or 100) / 1000.0;
    while not self._shutdown_event.is_set() {
        try {
            # Non-blocking poll with timeout
            # Request comes as dict (for pickle compatibility)
            request_dict = self._request_queue.get(timeout=poll_interval);
        } except Empty {
            continue;
        } except Exception as e {
            self._logger.error(f"Queue error: {e}");
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
                self._logger.info("Received shutdown request");
                self._response_queue.put(self._make_pong_response(request_id));
                break;
            } elif request_type == 'PING' {
                self._response_queue.put(self._make_pong_response(request_id));
            } elif request_type == 'COMPILE_FILE' {
                response_dict = self.handle_compile_file_dict(
                    request_dict, program, sem_managers
                );
                # Only send response if not cancelled
                if not self.is_cancelled() {
                    self._response_queue.put(response_dict);
                } else {
                    self._response_queue.put(self._make_cancelled_response(request_id));
                    self._logger.debug(f"Request {request_id} cancelled");
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
                self._logger.warning(f"Unknown request type: {request_type}");
                self._response_queue.put(
                    self._make_error_response(
                        request_id, f"Unknown request type: {request_type}"
                    )
                );
            }
        } except Exception as e {
            self._logger.error(f"Error processing request: {e}");
            import traceback;
            traceback.print_exc();
            self._response_queue.put(self._make_error_response(request_id, str(e)));
        } finally {
            self._current_request_id = None;
        }
    }
    self._logger.info("Worker process exiting");
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
    # Convert URI to file path
    if file_uri and file_uri.startswith("file://") {
        file_path = file_uri[7:];
    } else {
        file_path = file_uri;
    }
    if not file_path or not source {
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
        module = program.compile(
            file_path=file_path,
            use_str=source,
            type_check=type_check,
            no_cgen=no_cgen,
            cancel_token=cancel_event
        );

        if self.is_cancelled() {
            return self._make_cancelled_response(request_id);
        }

        # Update semantic manager for this file
        if module and module?.loc {
            sem_managers[file_path] = SemTokManager(ir=module, hub=program.mod.hub);
        }

        # Create snapshot
        snapshot = self.create_snapshot(program, sem_managers);

        duration_ms = (time.time() - start_time) * 1000;

        return {
            'request_id': request_id,
            'success': True,
            'cancelled': False,
            'snapshot_data': snapshot.serialize(),
            'errors': list(program.errors_had),
            'warnings': list(program.warnings_had),
            'duration_ms': duration_ms,
            'timestamp': time.time(),
            'files_analyzed': [file_path]
        };
    } except Exception as e {
        self._logger.error(f"Compilation error: {e}");
        import traceback;
        traceback.print_exc();
        return self._make_error_response(request_id, f"Compilation failed: {str(e)}");
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
    duration_ms = (time.time() - start_time) * 1000;
    return {
        'request_id': request_id,
        'success': True,
        'cancelled': False,
        'snapshot_data': snapshot.serialize(),
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
    self._id_generator = RequestIdGenerator();
    self._pending_requests = {};
    self._logger = logging.getLogger("jac.worker_manager");
    self._running = False;
    self._snapshot_callback = None;
    self._current_request_id = None;
    self._restart_count = 0;
}

impl WorkerManager.start -> None {
    if self._process and self._process.is_alive() {
        self._logger.warning("Worker already running");
        return;
    }
    # Create IPC primitives
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
    # Start response processing thread
    self._response_thread = threading.Thread(
        target=self._response_processor, daemon=True
    );
    self._response_thread.start();
    self._logger.info(f"Worker process started: PID {self._process.pid}");
}

impl WorkerManager.stop -> None {
    if not self._process {
        return;
    }
    self._running = False;
    # Send shutdown request as dict (for pickle compatibility)
    try {
        shutdown_req = {
            'request_type': 'SHUTDOWN',
            'request_id': self._id_generator.next_id(),
            'timestamp': time.time()
        };
        self._request_queue.put(shutdown_req);
    } except Exception as e {
        self._logger.error(f"Error sending shutdown: {e}");
    }
    # Signal shutdown
    self._shutdown_event.set();
    # Wait for graceful shutdown
    timeout = (self._config.shutdown_timeout_ms or 5000) / 1000.0;
    self._process.join(timeout=timeout);
    # Force terminate if still running
    if self._process.is_alive() {
        self._logger.warning("Force terminating worker");
        self._process.terminate();
        self._process.join(timeout=1.0);
    }
    self._process = None;
    self._logger.info("Worker process stopped");
}

impl WorkerManager.is_running -> bool {
    return self._running and self._process is not None and self._process.is_alive();
}

impl WorkerManager.compile_file(
    file_uri: str,
    source: str,
    priority: RequestPriority = RequestPriority.NORMAL,
    callback: Optional[Callable] = None
) -> str {
    if not self.is_running() {
        self._logger.warning("Worker not running, starting...");
        self.start();
    }
    # Cancel any in-progress work - user typed again
    if self._current_request_id {
        self.cancel_current();
    }
    request_id = self._id_generator.next_id();
    self._current_request_id = request_id;
    # Use dict for IPC (pickle compatibility)
    request = {
        'request_type': 'COMPILE_FILE',
        'request_id': request_id,
        'file_uri': file_uri,
        'source': source,
        'priority': priority?.value or priority,
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

impl WorkerManager.compile_all(callback: Optional[Callable] = None) -> str {
    if not self.is_running() {
        self.start();
    }
    request_id = self._id_generator.next_id();
    # Use dict for IPC (pickle compatibility)
    request = {
        'request_type': 'COMPILE_ALL',
        'request_id': request_id,
        'priority': RequestPriority.LOW.value,
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

impl WorkerManager._response_processor -> None {
    while self._running {
        responses = self.poll_responses();

        for response_dict in responses {
            self._process_response_dict(response_dict);
        }

        # Check for worker crash
        if self._process and not self._process.is_alive() and self._running {
            self._handle_crash();
        }

        time.sleep(0.05);  # 50ms poll interval
    }
}

impl WorkerManager._process_response_dict(response_dict: dict) -> None {
    request_id = response_dict.get('request_id', '');
    # Clear current request tracking if this is our current request
    if self._current_request_id == request_id {
        self._current_request_id = None;
    }
    # Skip processing cancelled responses (user already sent new request)
    if response_dict.get('cancelled', False) {
        self._logger.debug(f"Request {request_id} was cancelled, skipping");
        # Remove from pending without calling callback
        self._pending_requests.pop(request_id, None);
        return;
    }
    # Convert dict to WorkerResponse for callback compatibility
    response = WorkerResponse(
        request_id=request_id,
        success=response_dict.get('success', False),
        cancelled=response_dict.get('cancelled', False),
        snapshot_data=response_dict.get('snapshot_data'),
        errors=response_dict.get('errors'),
        warnings=response_dict.get('warnings'),
        error_message=response_dict.get('error_message'),
        duration_ms=response_dict.get('duration_ms', 0),
        timestamp=response_dict.get('timestamp', 0),
        files_analyzed=response_dict.get('files_analyzed')
    );
    # Call registered callback
    if request_id in self._pending_requests {
        callback = self._pending_requests.pop(request_id);
        try {
            callback(response);
        } except Exception as e {
            self._logger.error(f"Callback error: {e}");
        }
    }
    # If success and has snapshot, call snapshot callback
    if response.success and response.snapshot_data and self._snapshot_callback {
        try {
            snapshot = ProgramSnapshot.deserialize(response.snapshot_data);
            self._snapshot_callback(snapshot);
        } except Exception as e {
            self._logger.error(f"Snapshot callback error: {e}");
        }
    }
}

impl WorkerManager._handle_crash -> None {
    self._logger.error("Worker process crashed");
    if not self._config.restart_on_crash {
        self._running = False;
        return;
    }
    if self._restart_count >= self._config.max_restart_attempts {
        self._logger.error("Max restart attempts reached");
        self._running = False;
        return;
    }
    self._restart_count += 1;
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
    request_id = self._id_generator.next_id();
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
