import os;
import logging;
import from contextvars { ContextVar }

import type from opentelemetry.trace { Span, Tracer }
import type from opentelemetry.sdk.trace { TracerProvider }
import type from opentelemetry.util.types { AttributeValue }

glob _logger: logging.Logger = logging.getLogger("jaclang.scale.tracing");

glob _tracer: Tracer | None = None,
     _provider: TracerProvider | None = None,
     _tracing_installed: bool = False,
     _tracing_active: bool = False;

glob _TP_VERSION: str = "00",
     _FLAG_SAMPLED: int = 0x01,
     _MASK_128: int = (1 << 128) - 1,
     _MASK_64: int = (1 << 64) - 1;

glob _current_tp: ContextVar[str] = ContextVar("_jac_current_tp", `default="");

glob _current_span: ContextVar[Span | None] = ContextVar(
         "_jac_current_span", `default=None
     );

glob _pending_trace_id: ContextVar[int] = ContextVar(
         "_jac_pending_tid", `default=0
     );


def uuid_to_trace_id(uuid_str: str | None) -> int;

def trace_id_hex(trace_id_int: int) -> str;

def new_span_id -> int;

def build_traceparent(
    trace_id_int: int, span_id_int: int, sampled: bool = True
) -> str;

def parse_traceparent(header: str | None) -> dict[str, int] | None;


def tracing_active -> bool;

def tracing_installed -> bool;


def install_tracing(
    enabled: bool = True,
    service_name: str | None = None,
    endpoint: str | None = None,
    sample_ratio: float = 1.0
) -> bool;


def start_server_span(
    name: str,
    trace_uuid: str | None,
    parent_traceparent: str | None = None,
    attributes: dict[str, AttributeValue] | None = None
) -> Span | None;

def end_span(span: Span | None);

def start_memory_span(
    name: str, attributes: dict[str, AttributeValue] | None = None
) -> Span | None;

def end_memory_span(span: Span | None);

def _span_traceparent(span: Span) -> str | None;

def current_traceparent(trace_uuid: str | None = None) -> str | None;
