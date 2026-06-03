"""Distributed tracing (OpenTelemetry) for microservice + gateway pods.

This is the O-02 leg of the observability tripod. K-13 ships metrics,
M-14 ships logs; this module ships **spans** - the timed parent/child
tree that becomes a flame graph in Grafana/Tempo.

It builds directly on the K-12 trace-id plumbing in `trace_ctx.jac`.
K-12 already mints one `X-Trace-Id` (a UUID4) per external request and
threads it through every hop. This module turns that id into a real
OpenTelemetry trace and emits one SERVER span per hop (plus CLIENT
spans on cross-service RPC), exported over OTLP to a collector
(the Grafana Alloy DaemonSet from M-14.a, which doubles as an OTel
collector) and on to Tempo.

Design rules that keep this safe to import everywhere:

1. **OpenTelemetry is an OPTIONAL dependency** (`jac-scale[tracing]`),
   re-exported through `_optdeps/opentelemetry.jac`. Every function
   degrades to a no-op when `HAS_OTEL` is False - the gateway and
   services run unchanged, just without spans. Same contract as
   `metrics.jac` vs `prometheus_client`.

2. **The UUID4 IS the trace id.** A UUID4 is 128 bits, which is exactly
   the width of a W3C trace-id. We strip the dashes and reuse those
   128 bits as the OTel `trace_id`, so a request's logs (keyed on the
   UUID4 string via `log_emit.jac`) and its spans (keyed on the same
   128 bits in Tempo) share ONE id. This is the single most important
   correctness property: without it, Grafana's trace<->log pivots land
   on empty results. See `uuid_to_trace_id` / `build_traceparent`.

The id-reconciliation helpers (`uuid_to_trace_id`, `build_traceparent`,
`parse_traceparent`) are pure string/int math with NO OpenTelemetry
dependency, so they are fully unit-testable even where the SDK isn't
installed - which is also where the highest-risk format bugs live.
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
    OTLPSpanExporter
}

glob _logger: logging.Logger = logging.getLogger("jac_scale.tracing");

# Set once by install_tracing(). None until then (or permanently None
# when OpenTelemetry isn't installed / tracing is disabled).
glob _tracer: any = None,
     _provider: any = None,
     _tracing_installed: bool = False,
     _tracing_active: bool = False;

# W3C Trace Context constants (https://www.w3.org/TR/trace-context/).
glob _TP_VERSION: str = "00",
     _FLAG_SAMPLED: int = 0x01,
     _MASK_128: int = (1 << 128) - 1,
     _MASK_64: int = (1 << 64) - 1;

# Per-request `traceparent` of the active SERVER span, set by
# `start_server_span` and read by the proxy/RPC paths for outbound
# injection. A ContextVar (request-scoped, like `_trace_id`) so we
# don't depend on OpenTelemetry's own context propagation for the one
# value we need to forward. Empty when there's no active span.
glob _current_tp: ContextVar[str] = ContextVar("_jac_current_tp", default="");


# ---------------------------------------------------------------------------
# Pure id-reconciliation helpers (no OpenTelemetry dependency).
# ---------------------------------------------------------------------------

"""Convert a K-12 UUID4 trace-id string into a 128-bit OTel trace id.

A UUID4 is 16 bytes = 32 hex chars once the dashes are stripped, which
is exactly a W3C/OTel trace-id. Returns the integer form OTel's API
expects. Returns 0 (an invalid trace-id, which callers treat as "mint
a fresh one") if the input isn't parseable as hex.
"""
def uuid_to_trace_id(uuid_str: str | None) -> int {
    if not uuid_str {
        return 0;
    }
    hex_str = uuid_str.replace("-", "").strip();
    try {
        # 32 hex chars -> 128-bit int. Mask to 128 bits so an oversized
        # input can't produce an out-of-range trace id.
        return int(hex_str, 16) & _MASK_128;
    } except ValueError {
        return 0;
    }
}

"""Format a 128-bit trace id as the canonical 32-char lowercase hex.

This is the form Tempo stores and the form that must appear in the
`trace_id` log field for trace<->log correlation to join. Use this
(not the dashed UUID) anywhere an id crosses into the tracing world.
"""
def trace_id_hex(trace_id_int: int) -> str {
    return format(trace_id_int & _MASK_128, "032x");
}

"""Mint a fresh random 64-bit span id (never zero)."""
def new_span_id -> int {
    # os.urandom is fine here (not Math.random); 8 bytes = 64-bit span id.
    val = int.from_bytes(os.urandom(8), "big");
    if val == 0 {
        # 0 is the "invalid span" sentinel in OTel; retry-free fixup.
        return 1;
    }
    return val;
}

"""Build a W3C `traceparent` header value.

Format: `{version}-{trace_id:032x}-{span_id:016x}-{flags:02x}`, e.g.
`00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01`.
"""
def build_traceparent(trace_id_int: int, span_id_int: int, sampled: bool = True) -> str {
    flags = _FLAG_SAMPLED if sampled else 0;
    tid = format(trace_id_int & _MASK_128, "032x");
    sid = format(span_id_int & _MASK_64, "016x");
    flg = format(flags, "02x");
    return f"{_TP_VERSION}-{tid}-{sid}-{flg}";
}

"""Parse a W3C `traceparent` header into its parts.

Returns a dict `{trace_id, span_id, sampled}` (ints + bool) on success,
or None if the header is missing or malformed. Strict on shape (4
dash-separated fields, correct hex widths) so a garbage header can't
silently corrupt a trace.
"""
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
    if len(version) != 2 or len(tid_hex) != 32 or len(sid_hex) != 16 or len(flags_hex) != 2 {
        return None;
    }
    try {
        tid = int(tid_hex, 16);
        sid = int(sid_hex, 16);
        flags = int(flags_hex, 16);
    } except ValueError {
        return None;
    }
    # All-zero trace/span ids are invalid per the spec.
    if tid == 0 or sid == 0 {
        return None;
    }
    return {
        "trace_id": tid,
        "span_id": sid,
        "sampled": bool(flags & _FLAG_SAMPLED)
    };
}


# ---------------------------------------------------------------------------
# OpenTelemetry SDK bootstrap (optional dependency; no-op without it).
# ---------------------------------------------------------------------------

"""True once install_tracing has succeeded and spans are being emitted."""
def tracing_active -> bool {
    return _tracing_active;
}

"""True once install_tracing has run (whether or not it activated).

Lets per-request callers (jfast_api) skip re-reading config + re-calling
install on every request: read config and install once, then this gate
is True forever after.
"""
def tracing_installed -> bool {
    return _tracing_installed;
}

"""Return the process tracer, or None when tracing is inactive."""
def get_tracer -> any {
    return _tracer;
}

"""Configure the global OpenTelemetry TracerProvider + OTLP exporter.

Idempotent and safe to call once per process (mirrors
`install_structured_logging`). Returns True if tracing is now active,
False if it's a no-op (OpenTelemetry not installed, or disabled).

Arguments (all optional; env vars take over when omitted):
- `service_name`: the `service.name` resource attribute. Defaults to
  `JAC_SV_NAME` env (the same value `log_emit._SVC_NAME` reads) so a
  span's service matches its log lines.
- `endpoint`: OTLP/HTTP base URL of the collector (Alloy/Tempo). The
  exporter appends `/v1/traces`. Defaults to `OTEL_EXPORTER_OTLP_ENDPOINT`
  env, then `http://localhost:4318`.
- `sample_ratio`: head-sampling ratio in [0, 1]. 1.0 keeps every trace
  (the O-02 default while traffic is small). Parent-based, so a child
  always honours the root's decision and a trace is never half-sampled.
"""
def install_tracing(
    enabled: bool = True,
    service_name: str | None = None,
    endpoint: str | None = None,
    sample_ratio: float = 1.0
) -> bool {
    global _tracer, _provider, _tracing_installed, _tracing_active;

    if _tracing_installed {
        return _tracing_active;
    }
    # Mark installed up front so a disabled/failed/absent-SDK attempt
    # doesn't re-read config + retry on every request.
    _tracing_installed = True;

    if not enabled {
        # Configured off: install marked done, tracing stays inactive.
        return False;
    }

    if not HAS_OTEL {
        # Expected when jac-scale[tracing] isn't installed.
        _logger.debug("OpenTelemetry not installed; tracing disabled.");
        return False;
    }

    svc = service_name or os.getenv("JAC_SV_NAME", "unknown");
    base = endpoint or os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT") or "http://localhost:4318";
    traces_url = base.rstrip("/") + "/v1/traces";

    resource = Resource.create({
        "service.name": svc,
        "service.namespace": os.getenv("K8S_NAMESPACE", "default")
    });

    # Parent-based ratio sampler: root traces sampled at `sample_ratio`,
    # children inherit the root's decision via the traceparent sampled
    # bit (so a trace is all-in or all-out, never partial).
    ratio = sample_ratio;
    if ratio < 0.0 {
        ratio = 0.0;
    }
    if ratio > 1.0 {
        ratio = 1.0;
    }
    sampler = ParentBased(root=TraceIdRatioBased(ratio));

    provider = TracerProvider(resource=resource, sampler=sampler);
    # BatchSpanProcessor (NOT SimpleSpanProcessor): buffers finished
    # spans and flushes off the request path in a background thread, so
    # a slow/dead collector drops spans instead of slowing requests.
    provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(endpoint=traces_url)));
    trace.set_tracer_provider(provider);

    _provider = provider;
    _tracer = trace.get_tracer("jac_scale.microservices");
    _tracing_active = True;
    _logger.info(f"Tracing active: service={svc} otlp={traces_url} sample_ratio={ratio}");
    return True;
}

"""Flush any buffered spans and tear down the provider (best-effort).

Called on graceful drain so in-flight spans aren't lost when a pod
exits. No-op when tracing is inactive.
"""
def shutdown_tracing -> None {
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


# ---------------------------------------------------------------------------
# Span creation - ties an OTel span to the K-12 UUID4 trace id.
# ---------------------------------------------------------------------------

"""Start a SERVER span whose trace id is the given K-12 UUID4.

This is the reconciliation point. Instead of letting the SDK mint a
random trace id (which would NOT match the UUID4 in the log lines), we:

  1. derive the 128-bit trace id from the UUID4 (`uuid_to_trace_id`);
  2. build a *remote parent* SpanContext carrying that trace id and the
     inbound `traceparent`'s span id (or a fresh one when this hop is
     the trace root);
  3. start the real span as a child of that context, so it inherits the
     trace id but gets its own fresh span id.

Returns the started span or None when tracing is inactive. Caller MUST
pass the returned span to `end_span` when the request finishes - see
the gateway middleware wiring. As a side effect, stashes this span's
`traceparent` in `_current_tp` so the proxy/RPC paths forward it.

`parent_traceparent` is the inbound W3C header, if any. `attributes`
are set on the span at creation.
"""
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
        # No usable id - fall back to a fresh random trace.
        tid = int.from_bytes(os.urandom(16), "big") & _MASK_128;
    }

    parsed = parse_traceparent(parent_traceparent);
    sampled = True;
    if parsed is not None {
        parent_span_id = parsed["span_id"];
        sampled = parsed["sampled"];
    } else {
        # Root hop for this trace: synthesize a parent span id so the
        # SpanContext is valid; the resulting span becomes the visible
        # root in Tempo.
        parent_span_id = new_span_id();
    }

    flags = TraceFlags(_FLAG_SAMPLED if sampled else 0);
    parent_ctx = SpanContext(
        trace_id=tid,
        span_id=parent_span_id,
        is_remote=True,
        trace_flags=flags
    );
    ctx = set_span_in_context(NonRecordingSpan(parent_ctx));
    span = _tracer.start_span(name, context=ctx, kind=SpanKind.SERVER);
    if attributes {
        for (k, v) in attributes.items() {
            span.set_attribute(k, v);
        }
    }
    # Stash this span's traceparent so build_forward_headers /
    # sv_service_call forward it, making downstream hops our children.
    tp = _span_traceparent(span);
    if tp {
        _current_tp.set(tp);
    }
    return span;
}

"""End a span started by `start_server_span` and clear `_current_tp`.

No-op when `span` is None (tracing inactive). Best-effort: a span-end
error must never break request handling.
"""
def end_span(span: any) -> None {
    if span is not None {
        try {
            span.end();
        } except Exception as e {
            _logger.debug(f"span.end error (ignored): {e}");
        }
    }
    # Clear so the next request on this worker re-derives its own value
    # rather than inheriting this request's traceparent.
    _current_tp.set("");
}

"""Build a `traceparent` from a live OTel span's context, or None."""
def _span_traceparent(span: any) -> str | None {
    sc = span.get_span_context();
    if sc is not None and sc.trace_id != 0 and sc.span_id != 0 {
        return build_traceparent(
            sc.trace_id, sc.span_id, bool(sc.trace_flags & _FLAG_SAMPLED)
        );
    }
    return None;
}

"""Return the `traceparent` to forward on outbound proxy/RPC calls.

Prefers the active SERVER span's traceparent (set by
`start_server_span`) so the downstream hop links as our child. When
tracing is active but no span is set on this path, synthesizes one from
`trace_uuid` so the trace id still propagates.

Returns None when tracing is inactive (so we add no `traceparent`
header at all and preserve pre-O-02 behavior) or when no usable id is
available.
"""
def current_traceparent(trace_uuid: str | None = None) -> str | None {
    cur = _current_tp.get("");
    if cur {
        return cur;
    }
    # No active SERVER span on this path. Only keep propagating the id
    # when tracing is actually on; when it's off, emit no header.
    if not _tracing_active {
        return None;
    }
    tid = uuid_to_trace_id(trace_uuid);
    if tid == 0 {
        return None;
    }
    return build_traceparent(tid, new_span_id(), True);
}
