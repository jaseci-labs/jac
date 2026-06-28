import from fastapi.responses { JSONResponse }

def error_response(
    code: str,
    message: str,
    status: int,
    service: str | None = None,
    retry_after_seconds: int | None = None
) -> JSONResponse {
    import from jac_scale.runtime.context.trace_ctx { get_current_trace }

    err: dict = {"code": code, "message": message};
    if service {
        err["service"] = service;
    }
    trace = get_current_trace();
    if trace {
        err["trace_id"] = trace;
    }

    body: dict = {"ok": False, "error": err, "meta": {"http_status": status}};

    headers: dict[str, str] = {};
    if retry_after_seconds is not None {
        headers["Retry-After"] = str(retry_after_seconds);
    }

    return JSONResponse(status_code=status, content=body, headers=headers);
}

def service_unavailable(service: str, reason: str) -> JSONResponse {
    return error_response(
        code="SERVICE_UNAVAILABLE",
        message=f"Service '{service}' is {reason}",
        status=503,
        service=service,
        retry_after_seconds=2
    );
}

def gateway_timeout(service: str) -> JSONResponse {
    return error_response(
        code="GATEWAY_TIMEOUT",
        message=f"Failed to reach service '{service}'",
        status=502,
        service=service
    );
}

def not_found(path: str, message: str = "Not found") -> JSONResponse {
    return error_response(code="NOT_FOUND", message=f"{message}: {path}", status=404);
}
