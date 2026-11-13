impl error_response(
    code: str,
    message: str,
    status: int,
    service: str | None = None,
    retry_after_seconds: int | None = None
) -> JSONResponse {
    err: dict[str, any] = {"code": code, "message": message};
    if service {
        err["service"] = service;
    }
    trace = get_current_trace();
    if trace {
        err["trace_id"] = trace;
    }

    body: dict[str, any] = {"ok": False, "error": err, "meta": {"http_status": status}};

    headers: dict[str, str] = {};
    if retry_after_seconds is not None {
        headers["Retry-After"] = str(retry_after_seconds);
    }

    return JSONResponse(status_code=status, content=body, headers=headers);
}

impl service_unavailable(service: str, reason: str) -> JSONResponse {
    return error_response(
        code="SERVICE_UNAVAILABLE",
        message=f"Service '{service}' is {reason}",
        status=503,
        service=service,
        retry_after_seconds=2
    );
}

impl identity_unresolvable(detail: str) -> JSONResponse {
    return error_response(
        code="IDENTITY_UNRESOLVABLE",
        message=f"The caller's identity could not be resolved: {detail}",
        status=401
    );
}

impl gateway_timeout(service: str) -> JSONResponse {
    return error_response(
        code="GATEWAY_TIMEOUT",
        message=f"Service '{service}' did not respond in time",
        status=504,
        service=service
    );
}

impl bad_gateway(service: str) -> JSONResponse {
    return error_response(
        code="BAD_GATEWAY",
        message=f"Failed to reach service '{service}'",
        status=502,
        service=service
    );
}

impl not_found(path: str, message: str = "Not found") -> JSONResponse {
    return error_response(code="NOT_FOUND", message=f"{message}: {path}", status=404);
}
