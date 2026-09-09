import json;


def serialize_response(resp: any) -> str {
    import from jaclang.server.serving.app { transport_to_response }
    import from jaclang.server.serving.datatypes { JSONResponse }
    import from jaclang.server.transport { TransportResponse }
    if isinstance(resp, TransportResponse) {
        resp = transport_to_response(resp);
    }
    if isinstance(resp, JSONResponse) {
        return json.dumps(
            {"status": resp.status_code, "body": resp.content}, `default=str
        );
    }
    return json.dumps({"status": 200, "body": resp}, `default=str);
}


def replay_response(cached: str) -> any {
    import from jaclang.server.serving.datatypes { JSONResponse }
    payload = json.loads(cached);
    return JSONResponse(
        content=payload.get("body"), status_code=int(payload.get("status", 200))
    );
}


obj BridgeError(Exception) {
    has app: str = "",
        name: str = "",
        detail: str = "",
        status: int = 0;

    def __str__ -> str {
        label = f"{self.app}.{self.name}" if self.name else self.app;
        return f"bridge to '{label}' failed: {self.detail or 'unknown error'}";
    }
}

obj BridgeUnavailable(BridgeError) {}

obj BridgeTimeout(BridgeError) {}

obj BridgeRejected(BridgeError) {}


def bridge_error_for_status(
    status: int, app: str, name: str, detail: str
) -> BridgeError {
    if 400 <= status < 500 {
        return BridgeRejected(app=app, name=name, detail=detail, status=status);
    }
    return BridgeError(app=app, name=name, detail=detail, status=status);
}


def bridge_error_from(exc: Exception, app: str, name: str) -> BridgeError {
    if isinstance(exc, BridgeError) {
        return exc;
    }
    import asyncio;
    import socket;
    import from jaclang.server.serving.client {
        ClientConnectionError,
        ClientReadTimeout,
        ClientRequestNotSent
    }
    detail = str(exc) or exc.__class__.__name__;
    if isinstance(
        exc, (ClientReadTimeout, asyncio.TimeoutError, socket.timeout, TimeoutError)
    ) {
        return BridgeTimeout(app=app, name=name, detail=detail);
    }
    if isinstance(exc, ClientRequestNotSent) {
        return BridgeUnavailable(app=app, name=name, detail=detail);
    }
    if isinstance(exc, ClientConnectionError) {
        status = exc.status_code or 0;
        if status {
            return bridge_error_for_status(status, app, name, detail);
        }
        return BridgeUnavailable(app=app, name=name, detail=detail);
    }
    if isinstance(exc, (ConnectionError, OSError)) {
        return BridgeUnavailable(app=app, name=name, detail=detail);
    }
    return BridgeError(app=app, name=name, detail=detail);
}
