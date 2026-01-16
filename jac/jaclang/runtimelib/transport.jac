"""Transport Abstraction Layer for Jac API Server."""

import json;
import from collections.abc { Callable }
import from typing { Any }
import from enum { Enum }

"""Message type enumeration for transport responses."""
enum MessageType {
    RESPONSE = "response",
    EVENT = "event",
    CHUNK = "chunk",
    DONE = "done",
    ERROR = "error"
}

"""Transport-agnostic request container for protocol-independent communication."""
obj TransportRequest {
    has method: str,
        path: str,
        headers: dict[(str, str)] = {},
        body: Any = None,
        query_params: dict[(str, <>list[str])] = {},
        metadata: dict[(str, Any)] = {};
}

"""Error information for transport responses."""
obj ErrorInfo {
    has code: str,
        message: str,
        details: Any = None;
}

"""Metadata container for transport responses."""
obj Meta {
    has request_id: (str | None) = None,
        trace_id: (str | None) = None,
        timestamp: (str | None) = None,
        extra: dict[(str, Any)] = {};
}

"""Transport-agnostic response container following envelope pattern."""
obj TransportResponse {
    has type: MessageType = MessageType.RESPONSE.value,
        ok: bool = True,
        data: Any = None,
        error: (ErrorInfo | None) = None,
        meta: Meta = Meta();

    """Create a success response."""
    static def success(
        data: Any = None,
        msg_type: MessageType = MessageType.RESPONSE.value,
        meta: (Meta | None) = None
    ) -> TransportResponse;

    """Create an error response."""
    static def fail(
        code: str,
        message: str,
        details: Any = None,
        msg_type: MessageType = MessageType.ERROR.value,
        meta: (Meta | None) = None
    ) -> TransportResponse;
}

"""Abstract base transport interface for protocol-agnostic communication."""
obj BaseTransport {
    has on_message: (Callable[(..., Any)] | None) = None,
        on_error: (Callable[(..., Any)] | None) = None,
        on_close: (Callable[(..., Any)] | None) = None;

    """Initialize and establish the transport connection."""
    async def connect -> None;

    """Send data through the transport. Protocol-agnostic."""
    async def send(data: Any) -> None;

    """Close the transport connection and cleanup resources."""
    async def close -> None;
}

"""HTTP Transport for stateless request/response."""
obj HTTPTransport(BaseTransport) {
    has handler: Any = None,
        response_data: dict[(str, Any)] = {};

    """HTTP is stateless - nothing to connect."""
    def connect -> None;

    """Serialize and store response data. Triggers on_message callback."""
    def send(data: Any) -> None;

    """HTTP is stateless - nothing to close."""
    def close -> None;
}

"""Stream Transport for Server-Sent Events (SSE)."""
obj StreamTransport(BaseTransport) {
    has queue: Any = None;

    """SSE is stateless - nothing to connect."""
    async def connect -> None;

    """Push data to the queue for SSE streaming."""
    async def send(data: Any) -> None;

    """Signal stream end by pushing None to queue."""
    async def close -> None;
}

"""WebSocket Transport for bidirectional communication."""
obj WebSocketTransport(BaseTransport) {
    has websocket: Any = None;

    """Accept the WebSocket connection."""
    async def connect -> None;

    """Send JSON data through WebSocket."""
    async def send(data: Any) -> None;

    """Close the WebSocket connection."""
    async def close -> None;
}
