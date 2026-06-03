"""Structured-JSON log emission for microservice + gateway pods.

When `install_structured_logging` runs (called from the gateway's setup
and from every sv-service's request handler), the root logger swaps
its handler for one that emits **one JSON document per log line** to
stdout. Each line carries:

    ts          RFC3339Nano UTC, app-emitted (not the agent's clock)
    level       DEBUG | INFO | WARNING | ERROR | CRITICAL
    service     value of JAC_SV_NAME env (or 'unknown' off-K8s)
    trace_id    K-12 trace id, or null when outside a request
    msg         human-readable message
    extras      caller-supplied **kwargs from emit_log_record

Alloy (M-14.a) parses these lines via a `stage.json` block in
`loki.process`, promotes `service` + `level` to Loki labels, keeps
`trace_id` as a queryable field (high-cardinality, NOT safe as a label
- query via `{...} | json | trace_id="xyz"` instead).

Backwards compat: the existing `TraceIdLogFilter` still adds the
`[trace=...]` prefix to `record.msg` for plain-text consumers
(`kubectl logs`, local dev terminal). The JSON formatter renders the
mutated `msg` as-is, so JSON consumers see a slight redundancy but no
broken output; the canonical source for trace correlation is the
top-level `trace_id` field, not parsing the msg string.
"""

import os;
import json;
import logging;
import from datetime { datetime, timezone }
import from typing { Any }

# Service name resolution. In microservice mode K-track injects
# `JAC_SV_NAME` per pod (gateway, builder-sv, ...) and that's what
# we want. In monolith mode no `JAC_SV_NAME` is set, so we fall
# back to `K8S_APP_NAME` (injected on every jac-scale K8s pod)
# instead of the bare "unknown" sentinel - which made every JSON
# line on a monolith deploy land with `"service":"unknown"` and
# was indistinguishable from a misconfigured microservice.
glob _SVC_NAME: str = (
         os.getenv("JAC_SV_NAME", "").strip()
         or os.getenv("K8S_APP_NAME", "").strip()
         or "unknown"
     ),
     _structured_installed: bool = False,
     _root_logger: logging.Logger = logging.getLogger();


"""`json.dumps(default=...)` adaptor for non-JSON-native values
(datetime, Path, ...). Returns `str(value)`. Named `value` not
`obj` because `obj` is a Jac keyword."""
def _to_str(value: Any) -> str {
    return str(value);
}


"""Formatter that renders a `LogRecord` as one-line JSON.

Reads:
- `record.trace_id` - set by `TraceIdLogFilter`. None outside request.
- `record.svc_extras` - set by `emit_log_record` from **kwargs.
- `record.exc_info` - stdlib, present when `logger.exception()` is used.
"""
class _JacJsonFormatter(logging.Formatter) {
    # `self: any` because we subclass a Python class; logging calls
    # `formatter.format(record)` as a bound method (self + record).
    def format(self: any, record: logging.LogRecord) -> str {
        ts = datetime.fromtimestamp(record.created, tz=timezone.utc).isoformat();
        # RFC3339-style "Z" suffix matches what Alloy's stage.timestamp expects.
        if ts.endswith("+00:00") {
            ts = ts[:-6] + "Z";
        }
        out: dict[str, Any] = {
            "ts": ts,
            "level": record.levelname,
            "service": _SVC_NAME,
            "trace_id": record?.trace_id,
            "msg": record.getMessage()
        };
        extras = record?.svc_extras;
        if extras {
            out["extras"] = extras;
        }
        if record.exc_info {
            out["exc"] = self.formatException(record.exc_info);
        }
        # _to_str is a thin wrapper around str() so json.dumps's `default`
        # parameter (typed `Callable[[Any], Any] | None`) accepts it - the
        # Jac checker doesn't model `str` itself as a Callable.
        # ensure_ascii=False lets unicode pass through (no \uXXXX noise).
        return json.dumps(out, default=_to_str, ensure_ascii=False);
    }
}


"""Emit one structured log line at the given level.

The record routes through Python's root logger so every existing
filter / handler still runs (TraceIdLogFilter sets record.trace_id;
the JSON formatter promotes it). Extras land under the `extras` key
of the JSON output, not as top-level keys, so caller-supplied names
can't collide with the stable schema.
"""
def emit_log_record(level_name: str, msg: str, **extras: Any) {
    # Cast to int because Jac's type-checker widens `getattr(...)` to Any|Final
    # and the makeRecord(level=...) parameter is typed `int`.
    level_int: int = int(getattr(logging, level_name.upper(), logging.INFO));
    record = _root_logger.makeRecord(
        name="jac_scale.svlog",
        level=level_int,
        fn="",
        lno=0,
        msg=msg,
        args=(),
        exc_info=None
    );
    if extras {
        # setattr (vs `record.svc_extras = ...`) because LogRecord allows
        # dynamic attrs but the Jac type checker doesn't model that.
        setattr(record, "svc_extras", dict(extras));
    }
    _root_logger.handle(record);
}


def info(msg: str, **extras: Any) {
    emit_log_record("INFO", msg, **extras);
}

def warning(msg: str, **extras: Any) {
    emit_log_record("WARNING", msg, **extras);
}

def error(msg: str, **extras: Any) {
    emit_log_record("ERROR", msg, **extras);
}

def debug(msg: str, **extras: Any) {
    emit_log_record("DEBUG", msg, **extras);
}


"""Install the JSON formatter on the root logger (idempotent).

Replaces root logger handlers with a single JSON-emitting StreamHandler
and ensures the trace-id filter is active so `record.trace_id` is set
on every record before formatting.

Called from gateway.setup and jfast_api request handlers - i.e. once
per process - so emission shape is stable from process start.
"""
def install_structured_logging {
    global _structured_installed;

    # The expensive root-logger reconfigure runs only once per process.
    if not _structured_installed {
        handler = logging.StreamHandler();
        handler.setFormatter(_JacJsonFormatter());
        # Note: not `root = ...` because `root` is a reserved name in Jac
        # (graph context). Use `_log_root` instead.
        _log_root = logging.getLogger();
        # Replace prior handlers - downstream libraries that may have called
        # logging.basicConfig get superseded by ours so we don't double-emit.
        _log_root.handlers = [handler];
        # int(...) cast because Jac models `logging.INFO` as `Final` and the
        # checker won't accept it as the `int | str` parameter type.
        _log_root.setLevel(int(logging.INFO));

        # Make sure record.trace_id is populated before the formatter sees it.
        import from jac_scale.microservices.runtime.trace_ctx {
            install_trace_log_filter
        }
        install_trace_log_filter();

        _structured_installed = True;
    }

    # uvicorn / FastAPI install their own logger hierarchy with their
    # own handlers and propagate=False, so the JSON formatter we just
    # put on root never sees the access lines
    # (`INFO:     192.168.0.5:42 - "GET /healthz HTTP/1.1" 200 OK`).
    # Worse, uvicorn re-runs Config.configure_logging() at serve-time -
    # AFTER our setup() runs but BEFORE the first request - which undoes
    # the fixup if we only do it once. So we re-take-over these loggers
    # on EVERY call (the request-context middleware calls us each tick).
    # Cost is a handful of attribute writes, no allocation.
    for noisy_name in ["uvicorn", "uvicorn.access", "uvicorn.error", "fastapi"] {
        noisy = logging.getLogger(noisy_name);
        if noisy.handlers or not noisy.propagate {
            noisy.handlers = [];
            noisy.propagate = True;
        }
    }
}
