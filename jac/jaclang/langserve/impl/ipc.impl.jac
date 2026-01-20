"""Implementation of IPC message protocol."""

import time;
import threading;

impl WorkerRequest.compile_file(
    request_id: str,
    file_uri: str,
    source: str,
    priority: RequestPriority = RequestPriority.NORMAL
) -> WorkerRequest {
    return WorkerRequest(
        request_type=RequestType.COMPILE_FILE,
        request_id=request_id,
        file_uri=file_uri,
        source=source,
        priority=priority,
        timestamp=time.time()
    );
}

impl WorkerRequest.compile_all(request_id: str) -> WorkerRequest {
    return WorkerRequest(
        request_type=RequestType.COMPILE_ALL,
        request_id=request_id,
        timestamp=time.time()
    );
}

impl WorkerRequest.shutdown(request_id: str) -> WorkerRequest {
    return WorkerRequest(
        request_type=RequestType.SHUTDOWN, request_id=request_id, timestamp=time.time()
    );
}

impl WorkerRequest.ping(request_id: str) -> WorkerRequest {
    return WorkerRequest(
        request_type=RequestType.PING, request_id=request_id, timestamp=time.time()
    );
}

impl WorkerResponse.success_with_snapshot(
    request_id: str,
    snapshot_data: bytes,
    errors: list,
    warnings: list,
    duration_ms: float
) -> WorkerResponse {
    return WorkerResponse(
        request_id=request_id,
        success=True,
        snapshot_data=snapshot_data,
        errors=errors,
        warnings=warnings,
        duration_ms=duration_ms,
        timestamp=time.time()
    );
}

impl WorkerResponse.error(request_id: str, error_message: str) -> WorkerResponse {
    return WorkerResponse(
        request_id=request_id,
        success=False,
        error_message=error_message,
        timestamp=time.time()
    );
}

impl WorkerResponse.cancelled(request_id: str) -> WorkerResponse {
    return WorkerResponse(
        request_id=request_id,
        success=False,
        cancelled=True,
        error_message="Request cancelled",
        timestamp=time.time()
    );
}

impl WorkerResponse.pong(request_id: str) -> WorkerResponse {
    return WorkerResponse(request_id=request_id, success=True, timestamp=time.time());
}

impl RequestIdGenerator.postinit -> None {
    self._counter = 0;
    self._lock = threading.Lock();
}

impl RequestIdGenerator.next_id -> str {
    with self._lock {
        self._counter += 1;
        return f"{self._prefix}_{self._counter}_{int(time.time() * 1000)}";
    }
}
