import io;
import json;
import logging;
import from jaclang.scale.runtime.context.log_emit {
    emit_log_record,
    install_structured_logging,
    _JacJsonFormatter
}
import from jaclang.scale.runtime.context.trace_ctx {
    set_current_trace,
    reset_current_trace,
    install_trace_log_filter
}


test "emit_log_record produces a JSON line with the stable schema" {
    install_structured_logging();
    install_trace_log_filter();

    buf: io.StringIO = io.StringIO();
    capture: logging.StreamHandler = logging.StreamHandler(buf);
    capture.setFormatter(_JacJsonFormatter());
    logging.getLogger().addHandler(capture);

    try {
        emit_log_record("INFO", "hello world");
        line: str = buf.getvalue().strip();

        assert "\n" not in line , f"expected single-line JSON, got: {line!r}";
        parsed = json.loads(line);
        assert parsed["level"] == "INFO";
        assert parsed["msg"] == "hello world";
        assert "ts" in parsed;
        assert "service" in parsed;

        assert "trace_id" in parsed;
        assert parsed["trace_id"] is None;
    } finally {
        logging.getLogger().removeHandler(capture);
    }
}


test "extras land under the 'extras' key, not top-level" {
    install_structured_logging();
    install_trace_log_filter();

    buf: io.StringIO = io.StringIO();
    capture: logging.StreamHandler = logging.StreamHandler(buf);
    capture.setFormatter(_JacJsonFormatter());
    logging.getLogger().addHandler(capture);

    try {
        emit_log_record("INFO", "order placed", order_id=42, amount=99.5);
        line: str = buf.getvalue().strip();
        parsed = json.loads(line);

        assert parsed["extras"] == {"order_id": 42, "amount": 99.5};
        assert "order_id" not in parsed;
    } finally {
        logging.getLogger().removeHandler(capture);
    }
}


test "trace_id field is populated inside a request context" {
    install_structured_logging();
    install_trace_log_filter();

    buf: io.StringIO = io.StringIO();
    capture: logging.StreamHandler = logging.StreamHandler(buf);
    capture.setFormatter(_JacJsonFormatter());
    logging.getLogger().addHandler(capture);

    try {
        tok = set_current_trace("abc12345-deadbeef-0000-0000-000000000000");
        try {
            emit_log_record("INFO", "in-request log");
            line: str = buf.getvalue().strip();
            parsed = json.loads(line);
            assert parsed["trace_id"] == "abc12345-deadbeef-0000-0000-000000000000";

            assert "[trace=abc12345]" in parsed["msg"];
        } finally {
            reset_current_trace(tok);
        }
    } finally {
        logging.getLogger().removeHandler(capture);
    }
}


test "install_structured_logging routes uvicorn loggers through root" {
    install_structured_logging();

    for name in ["uvicorn", "uvicorn.access", "uvicorn.error", "fastapi"] {
        lg = logging.getLogger(name);
        assert lg.propagate is True , f"{name} should propagate to root";
        assert lg.handlers == [] , f"{name} should have no local handlers";
    }
}


test "trace_id populates on records emitted from child loggers" {
    install_structured_logging();

    buf: io.StringIO = io.StringIO();
    capture: logging.StreamHandler = logging.StreamHandler(buf);
    capture.setFormatter(_JacJsonFormatter());
    import from jaclang.scale.runtime.context.trace_ctx { TraceIdLogFilter }
    capture.addFilter(TraceIdLogFilter());
    logging.getLogger().addHandler(capture);

    try {
        tok = set_current_trace("trace-from-child-test");
        try {
            child: logging.Logger = logging.getLogger("jaclang.scale.test.child");
            child.info("propagated line");
            line: str = buf.getvalue().strip().split("\n")[-1];
            parsed: dict = json.loads(line);
            assert parsed["trace_id"] == "trace-from-child-test";
        } finally {
            reset_current_trace(tok);
        }
    } finally {
        logging.getLogger().removeHandler(capture);
    }
}
