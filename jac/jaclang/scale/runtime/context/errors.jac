def error_response(
    code: str,
    message: str,
    status: int,
    service: str | None = None,
    retry_after_seconds: int | None = None
) -> JSONResponse;

def service_unavailable(service: str, reason: str) -> JSONResponse;

def identity_unresolvable(detail: str) -> JSONResponse;


def gateway_timeout(service: str) -> JSONResponse;

def bad_gateway(service: str) -> JSONResponse;

def not_found(path: str, message: str = "Not found") -> JSONResponse;
