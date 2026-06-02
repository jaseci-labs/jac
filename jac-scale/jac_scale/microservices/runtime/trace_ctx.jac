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

# Per-request trace id. Empty when outside a request context.
glob _trace_id: ContextVar[str] = ContextVar("_sv_trace_id", default="");

"""Set the current request's trace id. Returns a Token for reset."""
def set_current_trace(trace_id: str | None) -> any {
    return _trace_id.set(trace_id or "");
}

"""Reset the trace-id ContextVar to its previous value."""
def reset_current_trace(token_obj: any) {
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

"""A logging filter that surfaces the current trace id on every record.

Two ways the trace id is exposed:

1. **As a record attribute** (`record.trace_id`) - read by the
   M-14.b `_JacJsonFormatter` and emitted as a top-level JSON field.
   None when outside a request context. This is the canonical source
   for trace correlation queries in Loki / Grafana / the admin logs UI.

2. **As an `[trace=...]` prefix on `record.msg`** - kept for plain-text
   consumers (`kubectl logs`, local dev terminal). Slight redundancy
   under JSON output, but harmless and preserves existing UX for
   anyone tailing pods directly.

Short form (first 8 hex chars of UUID4) is what gets prefixed; the
full id stays in the `trace_id` field.
"""
class TraceIdLogFilter(logging.Filter) {
    # `self: any` is required because we subclass a Python class
    # (`logging.Filter`); Python's logging framework calls `filter.filter(record)`
    # as a bound method (self + record), so the method MUST accept `self`
    # explicitly. Earlier versions omitted it and only worked when no
    # records actually flowed through the filter (latent bug).
    def filter(self: any, record: logging.LogRecord) -> bool {
        tid = get_current_trace();
        # Always set the field, even when empty, so JSON output has a
        # stable schema (`trace_id: null` when outside a request).
        # setattr (vs `record.trace_id =`) because LogRecord allows
        # dynamic attrs but the Jac type checker doesn't know that.
        setattr(record, "trace_id", tid or None);
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
    # Subtle: a Filter attached to a Logger only runs for records
    # EMITTED from that logger (via logger.info(), etc.). It does NOT
    # run on records propagated UP from child loggers. So attaching
    # the filter to the root logger alone would skip every record
    # from uvicorn.access, the gateway module's own logger, etc., and
    # `trace_id` would always be null for those (which is most of
    # what's in pod logs). Filters attached to a HANDLER, by contrast,
    # run for every record that reaches the handler regardless of
    # which logger originally emitted it. Walk the root logger's
    # handlers and attach the filter to each so propagated records
    # get `trace_id` set before formatting.
    flt = TraceIdLogFilter();
    _root = logging.getLogger();
    for h in _root.handlers {
        h.addFilter(flt);
    }
    # Belt-and-suspenders for direct emissions on the root logger.
    _root.addFilter(flt);
    _trace_filter_installed = True;
}
