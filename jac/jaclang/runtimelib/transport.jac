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
        query_params: dict[(str, list[str])] = {},
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

    static def success(
        data: Any = None,
        msg_type: MessageType = MessageType.RESPONSE.value,
        meta: (Meta | None) = None
    ) -> TransportResponse;

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

    async def connect -> None;
    async def send(data: Any) -> None;
    async def close -> None;
}

"""HTTP Transport for stateless request/response."""
obj HTTPTransport(BaseTransport) {
    has handler: Any = None,
        response_data: dict[(str, Any)] = {};

    def connect -> None;
    def send(data: Any) -> None;
    def close -> None;
}

"""Stream Transport for Server-Sent Events (SSE)."""
obj StreamTransport(BaseTransport) {
    has queue: Any = None;

    async def connect -> None;
    async def send(data: Any) -> None;
    async def close -> None;
}

"""WebSocket Transport for bidirectional communication."""
obj WebSocketTransport(BaseTransport) {
    has websocket: Any = None;

    async def connect -> None;
    async def send(data: Any) -> None;
    async def close -> None;
}
