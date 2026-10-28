impl set_current_trace(trace_id: str | None) -> any {
    return _trace_id.set(trace_id or "");
}

impl reset_current_trace(token_obj: any) {
    _trace_id.reset(token_obj);
}

impl get_current_trace -> str {
    return _trace_id.get("");
}

impl ensure_trace_id(incoming: str | None) -> str {
    if incoming {
        return incoming;
    }
    return str(uuid.uuid4());
}

impl TraceIdLogFilter.filter(self: any, record: logging.LogRecord) -> bool {
    tid = get_current_trace();

    setattr(record, "trace_id", tid or None);
    if tid {
        short = tid.split("-")[0];
        record.msg = f"[trace={short}] {record.msg}";
    }
    return True;
}

impl install_trace_log_filter -> None {
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
