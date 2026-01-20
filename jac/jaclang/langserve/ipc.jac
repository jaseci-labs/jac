"""Inter-process communication protocol for worker process.

Defines message types for communication between main LSP process
and the compilation worker process.

Message Flow:
1. Main → Worker: CompileRequest (file_uri, source)
2. Worker → Main: CompileResponse (diagnostics, snapshot_data)
"""

import threading;
import from typing { Optional, Any }
import from enum { Enum, auto }

"""Types of requests that can be sent to the worker."""
enum RequestType {
    COMPILE_FILE = auto(),  # Compile single file
    COMPILE_ALL = auto(),  # Full workspace compilation
    TYPE_CHECK = auto(),  # Type check only (no parse)
    SHUTDOWN = auto(),  # Graceful shutdown
    PING = auto()  # Health check
}

"""Priority levels for requests."""
enum RequestPriority {
    HIGH = 0,  # User-triggered (hover, completion)
    NORMAL = 1,  # Background (diagnostics)
    LOW = 2  # Batch operations (workspace symbols)
}

"""Request message sent from main process to worker."""
obj WorkerRequest {
    has request_type: RequestType,
        request_id: str,
        file_uri: str | None = None,
        source: str | None = None,
        priority: RequestPriority = RequestPriority.NORMAL,
        timestamp: float = 0;

    """Create a compile file request."""
    static def compile_file(
        request_id: str,
        file_uri: str,
        source: str,
        priority: RequestPriority = RequestPriority.NORMAL
    ) -> WorkerRequest;

    """Create a compile all request."""
    static def compile_all(request_id: str) -> WorkerRequest;

    """Create a shutdown request."""
    static def shutdown(request_id: str) -> WorkerRequest;

    """Create a ping request."""
    static def ping(request_id: str) -> WorkerRequest;
}

"""Response message sent from worker to main process."""
obj WorkerResponse {
    has request_id: str,
        success: bool = True,
        cancelled: bool = False,  # True if request was cancelled
        snapshot_data: bytes | None = None,  # Serialized ProgramSnapshot
        errors: list | None = None,  # List of error alerts
        warnings: list | None = None,  # List of warning alerts
        error_message: str | None = None,  # If success=False
        duration_ms: float = 0,  # Processing time
        timestamp: float = 0,
        files_analyzed: list | None = None;  # List of files that were analyzed

    """Create a success response with snapshot."""
    static def success_with_snapshot(
        request_id: str,
        snapshot_data: bytes,
        errors: list,
        warnings: list,
        duration_ms: float
    ) -> WorkerResponse;

    """Create an error response."""
    static def error(request_id: str, error_message: str) -> WorkerResponse;

    """Create a cancelled response."""
    static def cancelled(request_id: str) -> WorkerResponse;

    """Create a pong response (for ping)."""
    static def pong(request_id: str) -> WorkerResponse;
}

"""Manages unique request IDs."""
obj RequestIdGenerator {
    has _counter: int = 0,
        _prefix: str = "req",
        _lock: threading.Lock | None = None;

    def postinit -> None;
    """Generate unique request ID."""
    def next_id -> str;
}
