import uuid;
import logging;
import from contextvars { ContextVar }

glob _trace_id: ContextVar[str] = ContextVar("_sv_trace_id", `default="");

def set_current_trace(trace_id: str | None) -> any;

def reset_current_trace(token_obj: any);

def get_current_trace -> str;

def ensure_trace_id(incoming: str | None) -> str;

class TraceIdLogFilter(logging.Filter) {
    def filter(self: any, record: logging.LogRecord) -> bool;
}

glob _trace_filter_installed: bool = False;

def install_trace_log_filter -> None;
