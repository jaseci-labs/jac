"""Standardized error envelopes for the microservice gateway (ROADMAP P10).

Every failure path (proxy, passthrough, aggregation, no-match) returns
the same shape so clients can parse errors uniformly. The shape matches
jac-scale's TransportResponse envelope that sv-services emit, so a
client doesn't need to distinguish 'service error' from 'gateway error'
at parse time.

Envelope:

  {
    "ok": false,
    "error": {
      "code": "SERVICE_UNAVAILABLE",           // machine-readable
      "message": "Service 'cart_app' is stopped",  // human-readable
      "service": "cart_app",                   // optional
      "trace_id": "8f4a-..."                   // the X-Trace-Id header
    },
    "meta": {"http_status": 503}
  }

Retry-After is emitted as an HTTP header on 503 responses with a short
cool-down (2s). In K8s pod evictions are routine; a retry-friendly
contract keeps clients simple.

Gateway error codes:
  SERVICE_UNAVAILABLE - 503 - downstream service is STOPPED/UNHEALTHY
  GATEWAY_TIMEOUT     - 502 - transport failure (connect refused, etc.)
  NOT_FOUND           - 404 - no route matches or all services 404'd
  METRICS_UNAVAILABLE - 503 - prometheus_client not installed
  INTERNAL_ERROR      - 500 - unexpected exception
"""

import from typing { Any }
import from fastapi.responses { JSONResponse }

"""Build a JSONResponse with the standard error envelope.

`service` is added to the envelope when set (useful for client-side
routing of retries). `retry_after_seconds` sets the `Retry-After`
response header (seconds) - only set this for 503s where the caller
should actually retry; 404s and 502s are deterministic for the given
request so they shouldn't advertise retry.

The current trace id is added automatically via `_trace_ctx` so every
error in every log across the stack can be correlated to a single
client request.
"""
def error_response(
    code: str,
    message: str,
    status: int,
    service: str | None = None,
    retry_after_seconds: int | None = None
) -> JSONResponse {
    import from jac_scale.microservices._trace_ctx { get_current_trace }

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

"""Convenience: service-unavailable 503 with a 2s Retry-After hint.

For K8s pod evictions or graceful-shutdown windows, 2s is usually long
enough for the replacement pod to become ready. Clients that respect
Retry-After back off automatically; clients that don't still get
predictable 503 shape.
"""
def service_unavailable(service: str, reason: str) -> JSONResponse {
    return error_response(
        code="SERVICE_UNAVAILABLE",
        message=f"Service '{service}' is {reason}",
        status=503,
        service=service,
        retry_after_seconds=2
    );
}

"""Convenience: downstream transport failure."""
def gateway_timeout(service: str) -> JSONResponse {
    return error_response(
        code="GATEWAY_TIMEOUT",
        message=f"Failed to reach service '{service}'",
        status=502,
        service=service
    );
}

"""Convenience: no route matches the requested path."""
def not_found(path: str, message: str = "Not found") -> JSONResponse {
    return error_response(code="NOT_FOUND", message=f"{message}: {path}", status=404);
}
