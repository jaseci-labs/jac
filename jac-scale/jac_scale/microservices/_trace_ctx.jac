"""Per-request distributed trace-id context.

Companion to `_auth_ctx`. The FastAPI middleware on both the gateway
and every sv-service reads the inbound `X-Trace-Id` header (or
generates a fresh UUID if absent) and stashes it in this ContextVar.
The gateway's proxy path forwards the header to downstream services;
the `sv_service_call` hookimpl forwards it on sv-import RPC calls.

Result: one trace-id per external request threads through every
service touched by that request, visible in every log line via the
log filter below. In K8s this trace-id is what you join on in
Jaeger/Tempo when debugging "which pod did this user's request go
through and how long did each hop take."
"""

import uuid;
import logging;
import from contextvars { ContextVar }
import from typing { Any }

# Per-request trace id. Empty when outside a request context.
glob _trace_id: ContextVar[str] = ContextVar("_sv_trace_id", default="");

"""Set the current request's trace id. Returns a Token for reset."""
def set_current_trace(trace_id: str | None) -> Any {
    return _trace_id.set(trace_id or "");
}

"""Reset the trace-id ContextVar to its previous value."""
def reset_current_trace(token_obj: Any) {
    _trace_id.reset(token_obj);
}

"""Return the current trace id, or '' when not in a request."""
def get_current_trace -> str {
    return _trace_id.get("");
}

"""Return the current trace id, generating a fresh UUID4 if none is set.

Used by the gateway ingress middleware: if the inbound request has no
`X-Trace-Id` header, we mint one here so every downstream hop sees a
consistent id.
"""
def ensure_trace_id(incoming: str | None) -> str {
    if incoming {
        return incoming;
    }
    return str(uuid.uuid4());
}

"""A logging filter that prepends the current trace id (short form) to
every log record's message. Installed once per service on import.

The short form is the first 8 hex chars of the UUID, which is plenty
for log correlation and keeps lines readable.
"""
class TraceIdLogFilter(logging.Filter) {
    def filter(record: logging.LogRecord) -> bool {
        tid = get_current_trace();
        if tid {
            short = tid.split("-")[0];
            record.msg = f"[trace={short}] {record.msg}";
        }
        return True;
    }
}

# Track whether we've installed the filter on the root logger, so
# repeated imports don't stack duplicates.
glob _trace_filter_installed: bool = False;

"""Install the trace-id log filter on the root logger (idempotent)."""
def install_trace_log_filter -> None {
    global _trace_filter_installed;
    if _trace_filter_installed {
        return;
    }
    logging.getLogger().addFilter(TraceIdLogFilter());
    _trace_filter_installed = True;
}
