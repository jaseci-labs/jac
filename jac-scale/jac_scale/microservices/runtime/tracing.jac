"""OpenTelemetry tracing for the gateway and microservices.

Reuses the per-request `X-Trace-Id` UUID as the OpenTelemetry trace id so
a request's spans and its log lines share one id. OpenTelemetry is an
optional dependency (`jac-scale[tracing]`); every function is a no-op
when it isn't installed. The pure id helpers (`uuid_to_trace_id` /
`build_traceparent` / `parse_traceparent`) need no SDK and are unit
tested directly.
"""

import os;
import logging;
import from contextvars { ContextVar }
import from jac_scale._optdeps.opentelemetry {
    HAS_OTEL,
    trace,
    SpanContext,
    NonRecordingSpan,
    SpanKind,
    TraceFlags,
    set_span_in_context,
    Resource,
    TracerProvider,
    BatchSpanProcessor,
    ParentBased,
    TraceIdRatioBased,
    OTLPSpanExporter,
    IdGenerator
}

glob _logger: logging.Logger = logging.getLogger("jac_scale.tracing");

glob _tracer: any = None,
     _provider: any = None,
     _tracing_installed: bool = False,
     _tracing_active: bool = False;

# W3C Trace Context constants (https://www.w3.org/TR/trace-context/).
glob _TP_VERSION: str = "00",
     _FLAG_SAMPLED: int = 0x01,
     _MASK_128: int = (1 << 128) - 1,
     _MASK_64: int = (1 << 64) - 1;

# `traceparent` of the active SERVER span, read by the proxy/RPC paths to
# forward to downstream hops. Request-scoped; empty when no active span.
glob _current_tp: ContextVar[str] = ContextVar("_jac_current_tp", default="");

# Trace id to force on the next ROOT span (read by `_JacIdGenerator`), so
# a parentless root gets trace_id == the UUID and Tempo treats it as the
# trace root.
glob _pending_trace_id: ContextVar[int] = ContextVar(
         "_jac_pending_tid", default=0
     );


# --- Pure id helpers (no OpenTelemetry dependency) -------------------------
"""UUID string -> 128-bit trace id (dashes stripped). 0 if unparseable."""
def uuid_to_trace_id(uuid_str: str | None) -> int {
    if not uuid_str {
        return 0;
    }
    hex_str = uuid_str.replace("-", "").strip();
    try {
        return int(hex_str, 16) & _MASK_128;
    } except ValueError {
        return 0;
    }
}

"""128-bit trace id -> canonical 32-char lowercase hex (the form Tempo
stores and the `trace_id` log field must match)."""
def trace_id_hex(trace_id_int: int) -> str {
    return format(trace_id_int & _MASK_128, "032x");
}

"""Fresh random 64-bit span id (never zero)."""
def new_span_id -> int {
    val = int.from_bytes(os.urandom(8), "big");
    if val == 0 {
        return 1;
    }
    return val;
}

"""Build a W3C `traceparent`: `00-<32hex trace>-<16hex span>-<2hex flags>`."""
def build_traceparent(
    trace_id_int: int, span_id_int: int, sampled: bool = True
) -> str {
    flags = _FLAG_SAMPLED if sampled else 0;
    tid = format(trace_id_int & _MASK_128, "032x");
    sid = format(span_id_int & _MASK_64, "016x");
    flg = format(flags, "02x");
    return f"{_TP_VERSION}-{tid}-{sid}-{flg}";
}

"""Parse a W3C `traceparent` into `{trace_id, span_id, sampled}`, or None
if missing/malformed (strict on field count + hex widths)."""
def parse_traceparent(header: str | None) -> dict | None {
    if not header {
        return None;
    }
    parts = header.strip().split("-");
    if len(parts) != 4 {
        return None;
    }
    version = parts[0];
    tid_hex = parts[1];
    sid_hex = parts[2];
    flags_hex = parts[3];
    if len(version) != 2
    or len(tid_hex) != 32
    or len(sid_hex) != 16
    or len(flags_hex) != 2 {
        return None;
    }
    try {
        tid = int(tid_hex, 16);
        sid = int(sid_hex, 16);
        flags = int(flags_hex, 16);
    } except ValueError {
        return None;
    }
    if tid == 0 or sid == 0 {
        return None;
    }
    return {"trace_id": tid, "span_id": sid, "sampled": bool(flags & _FLAG_SAMPLED)};
}


# --- SDK bootstrap (no-op without OpenTelemetry) ---------------------------
"""True once install_tracing has activated and spans are being emitted."""
def tracing_active -> bool {
    return _tracing_active;
}

"""True once install_tracing has run (lets per-request callers install
once and skip re-reading config thereafter)."""
def tracing_installed -> bool {
    return _tracing_installed;
}

"""Process tracer, or None when tracing is inactive."""
def get_tracer -> any {
    return _tracer;
}

"""Id generator that forces a root span's trace id to the UUID stashed in
`_pending_trace_id` (the SDK calls generate_trace_id only for parentless
spans). Subclasses `IdGenerator` for the full interface OTel 1.4x calls;
the shim aliases `IdGenerator` to `object` when OpenTelemetry is absent so
this still compiles (it's only instantiated under a HAS_OTEL guard)."""
class _JacIdGenerator(IdGenerator) {
    def generate_span_id(self: any) -> int {
        return new_span_id();
    }

    def generate_trace_id(self: any) -> int {
        pend = _pending_trace_id.get(0);
        if pend != 0 {
            return pend;
        }
        return int.from_bytes(os.urandom(16), "big") & _MASK_128;
    }

    def is_trace_id_random(self: any) -> bool {
        return True;
    }
}

"""Configure the global TracerProvider + OTLP exporter once per process.
Returns True if tracing is now active, False if it's a no-op (disabled or
OpenTelemetry not installed). `service_name`/`endpoint`/`sample_ratio`
fall back to the `JAC_SV_NAME` / `OTEL_EXPORTER_OTLP_ENDPOINT` env vars."""
def install_tracing(
    enabled: bool = True,
    service_name: str | None = None,
    endpoint: str | None = None,
    sample_ratio: float = 1.0
) -> bool {
    global _tracer,_provider,_tracing_installed,_tracing_active;

    if _tracing_installed {
        return _tracing_active;
    }
    _tracing_installed = True;

    if not enabled {
        return False;
    }
    if not HAS_OTEL {
        _logger.debug("OpenTelemetry not installed; tracing disabled.");
        return False;
    }

    # Wrapped best-effort: a tracing setup problem must never crash the
    # host gateway/service.
    try {
        svc = service_name or os.getenv("JAC_SV_NAME", "unknown");
        base = endpoint
        or os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
        or "http://localhost:4318";
        traces_url = base.rstrip("/") + "/v1/traces";

        resource = Resource.create(
            {
                "service.name": svc,
                "service.namespace": os.getenv("K8S_NAMESPACE", "default")
            }
        );

        ratio = sample_ratio;
        if ratio < 0.0 {
            ratio = 0.0;
        }
        if ratio > 1.0 {
            ratio = 1.0;
        }
        # Pass the root sampler positionally: `root` is a reserved keyword
        # in Jac, so `ParentBased(root=...)` mis-compiles and throws.
        sampler = ParentBased(TraceIdRatioBased(ratio));

        provider = TracerProvider(
            resource=resource, sampler=sampler, id_generator=_JacIdGenerator()
        );
        # BatchSpanProcessor flushes off the request path, so a slow/dead
        # collector drops spans instead of slowing requests.
        provider.add_span_processor(
            BatchSpanProcessor(OTLPSpanExporter(endpoint=traces_url))
        );
        trace.set_tracer_provider(provider);

        _provider = provider;
        _tracer = trace.get_tracer("jac_scale.microservices");
        _tracing_active = True;
        _logger.info(
            f"Tracing active: service={svc} otlp={traces_url} sample_ratio={ratio}"
        );
        return True;
    } except Exception as e {
        _logger.warning(f"Tracing setup failed; continuing without spans: {e}");
        _tracing_active = False;
        return False;
    }
}

"""Flush buffered spans and tear down the provider (best-effort). Called
on graceful drain; no-op when tracing is inactive."""
def shutdown_tracing {
    global _tracing_active;
    if _provider is not None {
        try {
            _provider.shutdown();
        } except Exception as e {
            _logger.debug(f"Tracing shutdown error (ignored): {e}");
        }
    }
    _tracing_active = False;
}


# --- Span creation ---------------------------------------------------------
"""Start a SERVER span whose trace id is the given UUID. A root hop (no
inbound `parent_traceparent`) becomes a genuine parentless root; a child
hop inherits the inbound parent. Stashes the span's traceparent in
`_current_tp` for outbound forwarding. Returns None when tracing is
inactive; the caller MUST pass the span to `end_span`."""
def start_server_span(
    name: str,
    trace_uuid: str | None,
    parent_traceparent: str | None = None,
    attributes: dict | None = None
) -> any {
    if not _tracing_active or _tracer is None or not HAS_OTEL {
        return None;
    }

    tid = uuid_to_trace_id(trace_uuid);
    if tid == 0 {
        tid = int.from_bytes(os.urandom(16), "big") & _MASK_128;
    }

    parsed = parse_traceparent(parent_traceparent);
    span = None;
    if parsed is not None {
        # Child hop: start under the inbound span as parent.
        flags = TraceFlags(_FLAG_SAMPLED if parsed["sampled"] else 0);
        parent_ctx = SpanContext(
            trace_id=tid, span_id=parsed["span_id"], is_remote=True, trace_flags=flags
        );
        ctx = set_span_in_context(NonRecordingSpan(parent_ctx));
        span = _tracer.start_span(name, context=ctx, kind=SpanKind.SERVER);
    } else {
        # Root hop: parentless span, trace id forced to the UUID via the
        # id generator reading `_pending_trace_id`.
        tok = _pending_trace_id.set(tid);
        try {
            span = _tracer.start_span(name, kind=SpanKind.SERVER);
        } finally {
            _pending_trace_id.reset(tok);
        }
    }
    if attributes {
        for (k, v) in attributes.items() {
            span.set_attribute(k, v);
        }
    }
    tp = _span_traceparent(span);
    if tp {
        _current_tp.set(tp);
    }
    return span;
}

"""End a span started by `start_server_span` and clear `_current_tp`.
No-op/best-effort: a span-end error must never break request handling."""
def end_span(span: any) {
    if span is not None {
        try {
            span.end();
        } except Exception as e {
            _logger.debug(f"span.end error (ignored): {e}");
        }
    }
    _current_tp.set("");
}

"""Build a `traceparent` from a live span's context, or None."""
def _span_traceparent(span: any) -> str | None {
    sc = span.get_span_context();
    if sc is not None and sc.trace_id != 0 and sc.span_id != 0 {
        return build_traceparent(
            sc.trace_id, sc.span_id, bool(sc.trace_flags & _FLAG_SAMPLED)
        );
    }
    return None;
}

"""`traceparent` to forward on outbound proxy/RPC calls: the active
span's, else synthesized from `trace_uuid` so the id still propagates.
None when tracing is inactive (forward no header) or no id is available."""
def current_traceparent(trace_uuid: str | None = None) -> str | None {
    cur = _current_tp.get("");
    if cur {
        return cur;
    }
    if not _tracing_active {
        return None;
    }
    tid = uuid_to_trace_id(trace_uuid);
    if tid == 0 {
        return None;
    }
    return build_traceparent(tid, new_span_id(), True);
}
