"""Implementation of worker process for background compilation."""

import sys;
import time;
import threading;
import multiprocessing;
import logging;
import from typing { Optional, Callable, Any }
import from queue { Empty }
import from jaclang.langserve.snapshot { ProgramSnapshot, SnapshotManager }
import from jaclang.langserve.sem_manager { SemTokManager }

impl WorkerConfig.default -> WorkerConfig {
    return WorkerConfig();
}

# ============== CompilationWorker (runs in separate process) ==============

impl CompilationWorker.initialize(
    request_queue: Any, response_queue: Any,
    shutdown_event: Any, cancel_event: Any, config: WorkerConfig
) -> None {
    self._request_queue = request_queue;
    self._response_queue = response_queue;
    self._shutdown_event = shutdown_event;
    self._cancel_event = cancel_event;
    self._config = config;
}

impl CompilationWorker.run -> None {
    import from jaclang.pycore.program { JacProgram }
    import traceback;

    print("[Worker] Starting worker process", file=sys.stderr);
    program = JacProgram();
    sem_managers: dict = {};
    poll_interval = self._config.poll_interval_ms / 1000.0;

    while not self._shutdown_event.is_set() {
        try {
            request = self._request_queue.get(timeout=poll_interval);
        } except Empty {
            continue;
        }

        print(f"[Worker] Got request: {request.get('request_type')} {request.get('request_id')}", file=sys.stderr);
        self.clear_cancellation();
        request_id = request.get('request_id', '');
        request_type = request.get('request_type', '');

        try {
            if request_type == 'SHUTDOWN' {
                print("[Worker] Shutdown requested", file=sys.stderr);
                break;
            } elif request_type == 'COMPILE_FILE' {
                response = self._compile_file(request, program, sem_managers);
                print(f"[Worker] Sending response: success={response.get('success')}", file=sys.stderr);
                self._response_queue.put(response);
            }
        } except Exception as e {
            print(f"[Worker] Exception: {e}", file=sys.stderr);
            self._response_queue.put({
                'request_id': request_id,
                'success': False,
                'error_message': str(e),
                'error_traceback': traceback.format_exc()
            });
        }
    }
    print("[Worker] Exiting worker loop", file=sys.stderr);
}

impl CompilationWorker._compile_file(request: dict, program: Any, sem_managers: dict) -> dict {
    start = time.time();
    request_id = request.get('request_id', '');
    file_uri = request.get('file_uri', '');
    source = request.get('source', '');
    print(f"[Worker] Compiling: {file_uri} ({len(source)} chars)", file=sys.stderr);

    # Convert URI to path
    file_path = file_uri[7:] if file_uri.startswith("file://") else file_uri;

    if not file_path or not source {
        return {'request_id': request_id, 'success': False, 'error_message': 'Missing file_uri or source'};
    }

    # Clear old errors for this file
    program.errors_had = [e for e in program.errors_had if not (e?.loc?.mod_path == file_path)];
    program.warnings_had = [w for w in program.warnings_had if not (w?.loc?.mod_path == file_path)];

    if self.is_cancelled() {
        return {'request_id': request_id, 'success': False, 'cancelled': True};
    }

    # Compile
    module = program.compile(file_path=file_path, use_str=source, type_check=True, no_cgen=True);

    if self.is_cancelled() {
        return {'request_id': request_id, 'success': False, 'cancelled': True};
    }

    if module?.loc {
        program.mod.hub[file_path] = module;
        sem_managers[file_path] = SemTokManager(ir=module, hub=program.mod.hub);
    }

    # Handle impl files
    if module?.annexable_by {
        parent_path = module.annexable_by;
        try {
            with open(parent_path, 'r') as f {
                parent_source = f.read();
            }
            program.errors_had = [e for e in program.errors_had if not (e?.loc?.mod_path == parent_path)];
            program.warnings_had = [w for w in program.warnings_had if not (w?.loc?.mod_path == parent_path)];
            parent_module = program.compile(file_path=parent_path, use_str=parent_source, type_check=True, no_cgen=True);
            if parent_module?.loc {
                sem_managers[parent_path] = SemTokManager(ir=parent_module, hub=program.mod.hub);
            }
        } except Exception { }
    }

    # Create snapshot and send via shared memory
    snapshot = ProgramSnapshot.from_program_state(
        hub=program.mod.hub, sem_managers={},
        errors=program.errors_had, warnings=program.warnings_had
    );
    shm_result = snapshot.serialize_to_shared_memory();

    return {
        'request_id': request_id,
        'success': True,
        'shm_name': shm_result[0],
        'shm_size': shm_result[1],
        'duration_ms': (time.time() - start) * 1000
    };
}

impl CompilationWorker.is_cancelled -> bool {
    return self._cancel_event.is_set() if self._cancel_event else False;
}

impl CompilationWorker.clear_cancellation -> None {
    if self._cancel_event {
        self._cancel_event.clear();
    }
}

impl CompilationWorker._make_pong_response(request_id: str) -> dict {
    return {'request_id': request_id, 'success': True};
}

impl CompilationWorker._make_error_response(request_id: str, error_message: str) -> dict {
    return {'request_id': request_id, 'success': False, 'error_message': error_message};
}

impl CompilationWorker._make_cancelled_response(request_id: str) -> dict {
    return {'request_id': request_id, 'success': False, 'cancelled': True};
}

impl CompilationWorker.handle_compile_file_dict(request_dict: dict, program: Any, sem_managers: dict) -> dict {
    return self._compile_file(request_dict, program, sem_managers);
}

impl CompilationWorker.handle_compile_all_dict(request_dict: dict, program: Any, sem_managers: dict) -> dict {
    snapshot = ProgramSnapshot.from_program_state(
        hub=program.mod.hub, sem_managers={},
        errors=program.errors_had, warnings=program.warnings_had
    );
    shm_result = snapshot.serialize_to_shared_memory();
    return {
        'request_id': request_dict.get('request_id', ''),
        'success': True,
        'shm_name': shm_result[0],
        'shm_size': shm_result[1]
    };
}

impl CompilationWorker.create_snapshot(program: Any, sem_managers: dict) -> ProgramSnapshot {
    return ProgramSnapshot.from_program_state(
        hub=program.mod.hub, sem_managers={},
        errors=program.errors_had, warnings=program.warnings_had
    );
}

# ============== WorkerManager (runs in main process) ==============

impl WorkerManager.postinit -> None {
    self._config = self._config or WorkerConfig.default();
    self._request_counter = 0;
    self._pending_requests = {};
    self._logger = logging.getLogger("jac.worker");
    self._running = False;
    self._diagnostics_callback = None;
    self._current_request_id = None;
    # Debounce
    self._pending_uri = None;
    self._pending_source = None;
    self._timer = None;
    self._timer_lock = threading.Lock();
    self._last_activity = 0;
    self._analysis_in_progress = False;
    self._snapshot_manager = SnapshotManager();
    self._health_status = WorkerHealth.DEAD;
}

impl WorkerManager._next_request_id -> str {
    self._request_counter += 1;
    return f"req_{self._request_counter}";
}

impl WorkerManager.start -> None {
    if self._process and self._process.is_alive() {
        return;
    }
    self._request_queue = multiprocessing.Queue();
    self._response_queue = multiprocessing.Queue();
    self._shutdown_event = multiprocessing.Event();
    self._cancel_event = multiprocessing.Event();

    config_dict = {
        'poll_interval_ms': self._config.poll_interval_ms,
        'shutdown_timeout_ms': self._config.shutdown_timeout_ms
    };
    self._process = multiprocessing.Process(
        target=worker_process_main,
        args=(self._request_queue, self._response_queue, self._shutdown_event, self._cancel_event, config_dict),
        daemon=True
    );
    self._process.start();
    self._running = True;
    self._health_status = WorkerHealth.HEALTHY;
}

impl WorkerManager.stop -> None {
    if not self._process {
        return;
    }
    self._running = False;
    self._cancel_timer();
    try {
        self._request_queue.put({'request_type': 'SHUTDOWN', 'request_id': self._next_request_id()});
    } except Exception { }
    self._shutdown_event.set();
    self._process.join(timeout=self._config.shutdown_timeout_ms / 1000.0);
    if self._process.is_alive() {
        self._process.terminate();
    }
    self._process = None;
}

impl WorkerManager.is_running -> bool {
    return self._running and self._process is not None and self._process.is_alive();
}

impl WorkerManager.schedule_file(file_uri: str, source: str) -> None {
    print(f"[WorkerMgr] schedule_file: {file_uri} ({len(source)} chars)", file=sys.stderr);
    if not self._running {
        print("[WorkerMgr] Worker not running, starting...", file=sys.stderr);
        self.start();
    }
    self._last_activity = time.time();
    self._pending_uri = file_uri;
    self._pending_source = source;
    if self._analysis_in_progress {
        print("[WorkerMgr] Cancelling in-progress analysis", file=sys.stderr);
        self.cancel_current();
    }
    self._reset_timer();
}

impl WorkerManager.has_pending -> bool {
    return self._pending_uri is not None;
}

impl WorkerManager.is_analyzing -> bool {
    return self._analysis_in_progress;
}

impl WorkerManager.is_busy -> bool {
    with self._timer_lock {
        has_timer = self._timer is not None and self._timer.is_alive();
    }
    return self.has_pending() or has_timer or self._analysis_in_progress;
}

impl WorkerManager._reset_timer -> None {
    with self._timer_lock {
        if self._timer {
            self._timer.cancel();
        }
        self._timer = threading.Timer(self._config.debounce_ms / 1000.0, self._on_timer_expired);
        self._timer.daemon = True;
        self._timer.start();
    }
}

impl WorkerManager._cancel_timer -> None {
    with self._timer_lock {
        if self._timer {
            self._timer.cancel();
            self._timer = None;
        }
    }
}

impl WorkerManager._on_timer_expired -> None {
    if not self._running {
        print("[WorkerMgr] Timer expired but not running", file=sys.stderr);
        return;
    }
    elapsed = (time.time() - self._last_activity) * 1000;
    if elapsed < self._config.debounce_ms {
        print(f"[WorkerMgr] Timer: {elapsed:.0f}ms < {self._config.debounce_ms}ms, rescheduling", file=sys.stderr);
        with self._timer_lock {
            self._timer = threading.Timer((self._config.debounce_ms - elapsed) / 1000.0, self._on_timer_expired);
            self._timer.daemon = True;
            self._timer.start();
        }
        return;
    }
    print(f"[WorkerMgr] Timer expired after {elapsed:.0f}ms, processing pending", file=sys.stderr);
    self._process_pending();
}

impl WorkerManager._process_pending -> None {
    print(f"[WorkerMgr] _process_pending: running={self._running}, pending_uri={self._pending_uri}", file=sys.stderr);
    if not self._running or self._pending_uri is None {
        print("[WorkerMgr] _process_pending: early return", file=sys.stderr);
        return;
    }
    file_uri = self._pending_uri;
    source = self._pending_source;
    self._pending_uri = None;
    self._pending_source = None;
    self._analysis_in_progress = True;
    print(f"[WorkerMgr] _process_pending: calling compile_file", file=sys.stderr);
    self.compile_file(file_uri, source);
}

impl WorkerManager.compile_file(file_uri: str, source: str, callback: Optional[Callable] = None) -> str {
    print(f"[WorkerMgr] compile_file: {file_uri}", file=sys.stderr);
    if not self.is_running() {
        print("[WorkerMgr] compile_file: worker not running, starting", file=sys.stderr);
        self.start();
    }
    if self._current_request_id {
        print(f"[WorkerMgr] compile_file: cancelling {self._current_request_id}", file=sys.stderr);
        self.cancel_current();
    }
    request_id = self._next_request_id();
    self._current_request_id = request_id;
    request = {
        'request_type': 'COMPILE_FILE',
        'request_id': request_id,
        'file_uri': file_uri,
        'source': source
    };
    if callback {
        self._pending_requests[request_id] = callback;
    }
    print(f"[WorkerMgr] compile_file: putting request {request_id} in queue", file=sys.stderr);
    self._request_queue.put(request);
    print(f"[WorkerMgr] compile_file: request queued", file=sys.stderr);
    return request_id;
}

impl WorkerManager.compile_all(callback: Optional[Callable] = None) -> str {
    if not self.is_running() {
        self.start();
    }
    request_id = self._next_request_id();
    self._request_queue.put({'request_type': 'COMPILE_ALL', 'request_id': request_id});
    if callback {
        self._pending_requests[request_id] = callback;
    }
    return request_id;
}

impl WorkerManager.cancel_current -> None {
    if self._cancel_event {
        self._cancel_event.set();
    }
    self._analysis_in_progress = False;
}

impl WorkerManager.process_pending_responses -> None {
    while True {
        try {
            response = self._response_queue.get_nowait();
        } except Empty {
            break;
        }
        self._handle_response(response);
    }
    if self._process and not self._process.is_alive() and self._running {
        self._running = False;
        self._health_status = WorkerHealth.DEAD;
    }
}

impl WorkerManager._handle_response(response: dict) -> None {
    request_id = response.get('request_id', '');
    print(f"[WorkerMgr] Response received: {request_id}, success={response.get('success')}", file=sys.stderr);

    if self._current_request_id == request_id {
        self._current_request_id = None;
    }

    if response.get('cancelled', False) {
        print(f"[WorkerMgr] Request {request_id} was cancelled", file=sys.stderr);
        self._pending_requests.pop(request_id, None);
        return;
    }

    if response.get('error_message') {
        print(f"[WorkerMgr] Error: {response.get('error_message')}", file=sys.stderr);
        if response.get('error_traceback') {
            print(f"[WorkerMgr] Traceback: {response.get('error_traceback')}", file=sys.stderr);
        }
    }

    # Deserialize snapshot from shared memory
    snapshot: ProgramSnapshot | None = None;
    shm_name = response.get('shm_name');
    shm_size = response.get('shm_size');
    if shm_name and shm_size {
        try {
            print(f"[WorkerMgr] Deserializing snapshot from {shm_name} ({shm_size} bytes)", file=sys.stderr);
            snapshot = ProgramSnapshot.deserialize_from_shared_memory(shm_name, shm_size);
            print(f"[WorkerMgr] Snapshot deserialized: {len(snapshot.hub) if snapshot else 0} modules", file=sys.stderr);
        } except Exception as e {
            print(f"[WorkerMgr] Snapshot deserialization failed: {e}", file=sys.stderr);
        }
    }

    # Call callback if registered
    if request_id in self._pending_requests {
        try {
            self._pending_requests.pop(request_id)(response);
        } except Exception as e {
            print(f"[WorkerMgr] Callback error: {e}", file=sys.stderr);
        }
    }

    # Handle snapshot
    if response.get('success', False) and snapshot {
        self._analysis_in_progress = False;
        self._snapshot_manager.update_snapshot(snapshot);
        print(f"[WorkerMgr] Snapshot updated, calling diagnostics callback", file=sys.stderr);
        if self._diagnostics_callback {
            try {
                self._diagnostics_callback(snapshot);
            } except Exception as e {
                print(f"[WorkerMgr] Diagnostics callback error: {e}", file=sys.stderr);
            }
        }
        if self._pending_uri {
            self._reset_timer();
        }
    } elif not response.get('success', False) {
        self._analysis_in_progress = False;
        print(f"[WorkerMgr] Request failed, analysis_in_progress reset", file=sys.stderr);
    }
}

impl WorkerManager.set_diagnostics_callback(callback: Callable) -> None {
    self._diagnostics_callback = callback;
}

impl WorkerManager.get_snapshot -> Optional[ProgramSnapshot] {
    return self._snapshot_manager.get_snapshot() if self._snapshot_manager else None;
}

impl WorkerManager.poll_responses -> list {
    responses = [];
    while True {
        try {
            responses.append(self._response_queue.get_nowait());
        } except Empty {
            break;
        }
    }
    return responses;
}

impl WorkerManager._process_response_dict(response_dict: dict) -> None {
    self._handle_response(response_dict);
}

impl WorkerManager._on_snapshot_received(snapshot: ProgramSnapshot) -> None {
    self._snapshot_manager.update_snapshot(snapshot);
    if self._diagnostics_callback {
        self._diagnostics_callback(snapshot);
    }
}

impl WorkerManager._response_processor -> None {
    pass;
}

impl WorkerManager._health_checker -> None {
    pass;
}

impl WorkerManager._notify_health_change(status: WorkerHealth) -> None {
    pass;
}

impl WorkerManager._handle_crash -> None {
    self._running = False;
    self._health_status = WorkerHealth.DEAD;
}

impl WorkerManager.set_snapshot_callback(callback: Callable[[ProgramSnapshot], None]) -> None {
    pass;
}

impl WorkerManager.set_health_callback(callback: Callable[[WorkerHealth], None]) -> None {
    pass;
}

impl WorkerManager.get_health -> WorkerHealth {
    return self._health_status;
}

impl WorkerManager.ping(timeout_ms: float = 1000) -> bool {
    return self.is_running();
}

impl worker_process_main(
    request_queue: Any, response_queue: Any,
    shutdown_event: Any, cancel_event: Any, config_dict: dict
) -> None {
    import traceback;
    try {
        print("[Worker] worker_process_main starting", file=sys.stderr);
        config = WorkerConfig(
            poll_interval_ms=config_dict.get('poll_interval_ms', 100),
            shutdown_timeout_ms=config_dict.get('shutdown_timeout_ms', 5000)
        );
        worker = CompilationWorker();
        worker.initialize(request_queue, response_queue, shutdown_event, cancel_event, config);
        worker.run();
    } except Exception as e {
        print(f"[Worker] FATAL ERROR: {e}", file=sys.stderr);
        print(traceback.format_exc(), file=sys.stderr);
    }
}
