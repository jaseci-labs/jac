import uuid;
import logging;
import from contextvars { ContextVar }

glob _trace_id: ContextVar[str] = ContextVar("_sv_trace_id", default="");

def set_current_trace(trace_id: str | None) -> any {
    return _trace_id.set(trace_id or "");
}

def reset_current_trace(token_obj: any) {
    _trace_id.reset(token_obj);
}

def get_current_trace -> str {
    return _trace_id.get("");
}

def ensure_trace_id(incoming: str | None) -> str {
    if incoming {
        return incoming;
    }
    return str(uuid.uuid4());
}

class TraceIdLogFilter(logging.Filter) {
    def filter(self: any, record: logging.LogRecord) -> bool {
        tid = get_current_trace();

        setattr(record, "trace_id", tid or None);
        if tid {
            short = tid.split("-")[0];
            record.msg = f"[trace={short}] {record.msg}";
        }
        return True;
    }
}

glob _trace_filter_installed: bool = False;

def install_trace_log_filter -> None {
    global _trace_filter_installed;
    if _trace_filter_installed {
        return;
    }

    flt = TraceIdLogFilter();
    _root = logging.getLogger();
    for h in _root.handlers {
        h.addFilter(flt);
    }

    _root.addFilter(flt);
    _trace_filter_installed = True;
}
