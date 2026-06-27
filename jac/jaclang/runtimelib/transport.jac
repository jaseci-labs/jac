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
        body: any = None,
        query_params: dict[(str, list[str])] = {},
        metadata: dict[(str, Any)] = {};
}

"""Error information for transport responses."""
obj ErrorInfo {
    has code: str,
        message: str,
        details: any = None;
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
        data: any = None,
        error: (ErrorInfo | None) = None,
        meta: Meta = Meta();

    static def success(
        data: any = None,
        msg_type: MessageType = MessageType.RESPONSE.value,
        meta: (Meta | None) = None
    ) -> TransportResponse;

    static def fail(
        code: str,
        message: str,
        details: any = None,
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
    async def send(data: any) -> None;
    async def close -> None;
}

"""HTTP Transport for stateless request/response."""
obj HTTPTransport(BaseTransport) {
    has handler: any = None,
        response_data: dict[(str, Any)] = {};

    def connect -> None;
    def send(data: any) -> None;
    def close -> None;
}
