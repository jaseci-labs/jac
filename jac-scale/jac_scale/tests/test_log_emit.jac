"""Tests for M-14.b structured-JSON log emission.

Three contract guarantees:
1. `install_structured_logging` makes every log record render as a
   one-line JSON document with the stable schema.
2. `emit_log_record` extras round-trip under the `extras` JSON key,
   not at top-level (protects schema from caller collisions).
3. `record.trace_id` (set by `TraceIdLogFilter`) appears as a
   top-level JSON field; null when outside a request context.
"""

import io;
import json;
import logging;
import from jac_scale.microservices.runtime.log_emit {
    emit_log_record,
    install_structured_logging,
    _JacJsonFormatter
}
import from jac_scale.microservices.runtime.trace_ctx {
    set_current_trace,
    reset_current_trace,
    install_trace_log_filter
}


test "emit_log_record produces a JSON line with the stable schema" {
    install_structured_logging();
    install_trace_log_filter();

    # Capture handler so test doesn't depend on stdout
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
        # trace_id key is always present, null outside a request
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

        # Caller-supplied kwargs nest under "extras". Protects the stable
        # schema from collisions (e.g. emit_log_record("...", level="X")).
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
            # And the msg keeps the [trace=...] prefix for plain-text consumers
            assert "[trace=abc12345]" in parsed["msg"];
        } finally {
            reset_current_trace(tok);
        }
    } finally {
        logging.getLogger().removeHandler(capture);
    }
}
