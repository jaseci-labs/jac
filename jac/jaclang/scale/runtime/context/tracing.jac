import os;
import logging;
import from contextvars { ContextVar }
import from jaclang.scale._optdeps.opentelemetry {
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

glob _logger: logging.Logger = logging.getLogger("jaclang.scale.tracing");

glob _tracer: any = None,
     _provider: any = None,
     _tracing_installed: bool = False,
     _tracing_active: bool = False;

glob _TP_VERSION: str = "00",
     _FLAG_SAMPLED: int = 0x01,
     _MASK_128: int = (1 << 128) - 1,
     _MASK_64: int = (1 << 64) - 1;

glob _current_tp: ContextVar[str] = ContextVar("_jac_current_tp", default="");

glob _current_span: ContextVar[any] = ContextVar(
         "_jac_current_span", default=None
     );

glob _pending_trace_id: ContextVar[int] = ContextVar(
         "_jac_pending_tid", default=0
     );


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

def trace_id_hex(trace_id_int: int) -> str {
    return format(trace_id_int & _MASK_128, "032x");
}

def new_span_id -> int {
    val = int.from_bytes(os.urandom(8), "big");
    if val == 0 {
        return 1;
    }
    return val;
}

def build_traceparent(
    trace_id_int: int, span_id_int: int, sampled: bool = True
) -> str {
    flags = _FLAG_SAMPLED if sampled else 0;
    tid = format(trace_id_int & _MASK_128, "032x");
    sid = format(span_id_int & _MASK_64, "016x");
    flg = format(flags, "02x");
    return f"{_TP_VERSION}-{tid}-{sid}-{flg}";
}

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


def tracing_active -> bool {
    return _tracing_active;
}

def tracing_installed -> bool {
    return _tracing_installed;
}

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

        sampler = ParentBased(TraceIdRatioBased(ratio));

        provider = TracerProvider(
            resource=resource, sampler=sampler, id_generator=_JacIdGenerator()
        );

        provider.add_span_processor(
            BatchSpanProcessor(OTLPSpanExporter(endpoint=traces_url))
        );
        trace.set_tracer_provider(provider);

        _provider = provider;
        _tracer = trace.get_tracer("jaclang.scale.microservices");
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
        flags = TraceFlags(_FLAG_SAMPLED if parsed["sampled"] else 0);
        parent_ctx = SpanContext(
            trace_id=tid, span_id=parsed["span_id"], is_remote=True, trace_flags=flags
        );
        ctx = set_span_in_context(NonRecordingSpan(parent_ctx));
        span = _tracer.start_span(name, context=ctx, kind=SpanKind.SERVER);
    } else {
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
    _current_span.set(span);
    return span;
}

def end_span(span: any) {
    if span is not None {
        try {
            span.end();
        } except Exception as e {
            _logger.debug(f"span.end error (ignored): {e}");
        }
    }
    _current_tp.set("");
    _current_span.set(None);
}

def start_memory_span(name: str, attributes: dict | None = None) -> any {
    if not _tracing_active or _tracer is None or not HAS_OTEL {
        return None;
    }
    parent = _current_span.get(None);
    if parent is None {
        return None;
    }
    try {
        ctx = set_span_in_context(parent);
        span = _tracer.start_span(name, context=ctx, kind=SpanKind.CLIENT);
        if attributes {
            for (k, v) in attributes.items() {
                span.set_attribute(k, v);
            }
        }
        return span;
    } except Exception as e {
        _logger.debug(f"start_memory_span error (ignored): {e}");
        return None;
    }
}

def end_memory_span(span: any) {
    if span is not None {
        try {
            span.end();
        } except Exception as e {
            _logger.debug(f"memory span.end error (ignored): {e}");
        }
    }
}

def _span_traceparent(span: any) -> str | None {
    sc = span.get_span_context();
    if sc is not None and sc.trace_id != 0 and sc.span_id != 0 {
        return build_traceparent(
            sc.trace_id, sc.span_id, bool(sc.trace_flags & _FLAG_SAMPLED)
        );
    }
    return None;
}

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
