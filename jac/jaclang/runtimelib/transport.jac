import json;
import from collections.abc { Callable }
import from typing { Any }

enum MessageType {
    RESPONSE = "response",
    EVENT = "event",
    CHUNK = "chunk",
    DONE = "done",
    ERROR = "error"
}

obj TransportRequest {
    has method: str,
        path: str,
        headers: dict[(str, str)] = {},
        body: any = None,
        query_params: dict[(str, list[str])] = {},
        metadata: dict[(str, Any)] = {};
}

obj ErrorInfo {
    has code: str,
        message: str,
        details: any = None;
}

obj Meta {
    has request_id: (str | None) = None,
        trace_id: (str | None) = None,
        timestamp: (str | None) = None,
        extra: dict[(str, Any)] = {};
}

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

obj BaseTransport {
    has on_message: (Callable[(..., Any)] | None) = None,
        on_error: (Callable[(..., Any)] | None) = None,
        on_close: (Callable[(..., Any)] | None) = None;

    async def send(data: any) -> None;
}

obj HTTPTransport(BaseTransport) {
    has handler: any = None,
        response_data: dict[(str, Any)] = {};

    def send(data: any) -> None;
}
