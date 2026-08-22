import io;
import importlib;
import json;
import logging;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.scale.config.config_loader {
    get_scale_config,
    peek_scale_config,
    reset_scale_config
}
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


def _reset_install_state {
    # install_structured_logging is once-per-process; reset its module state
    # the same way reset_scale_config resets the config singleton, so each
    # test exercises a fresh install decision.
    le = importlib.import_module("jaclang.scale.runtime.context.log_emit");
    setattr(le, "_structured_installed", False);
    setattr(le, "_structured_optout", False);
}


def _project_with_toml(toml_content: str) -> str {
    project_dir = tempfile.mkdtemp(prefix="jac-logcfg-");
    (Path(project_dir) / "jac.toml").write_text(toml_content);
    reset_scale_config();
    get_scale_config(project_dir=Path(project_dir));
    return project_dir;
}


test "structured_logs=false leaves the host's handlers and level untouched" {
    project_dir = _project_with_toml(
        "[project]\n"
        'name = "host"\n'
        'entry-point = "main.jac"\n'
        "\n"
        "[scale.server]\n"
        "structured_logs = false\n"
    );
    _reset_install_state();
    log_root = logging.getLogger();
    saved_handlers = list(log_root.handlers);
    saved_level = log_root.level;
    host_buf = io.StringIO();
    host_handler = logging.StreamHandler(host_buf);
    try {
        log_root.addHandler(host_handler);
        log_root.setLevel(int(logging.DEBUG));
        install_structured_logging();
        assert host_handler in log_root.handlers , "the host's handler was wiped by install_structured_logging";
        assert log_root.level == int(logging.DEBUG) , f"the host's DEBUG level was forced to {log_root.level}";
    } finally {
        log_root.handlers = saved_handlers;
        log_root.setLevel(saved_level);
        _reset_install_state();
        reset_scale_config();
        shutil.rmtree(project_dir, ignore_errors=True);
    }
}


test "an explicitly-set root level survives the default install" {
    project_dir = _project_with_toml(
        "[project]\n" 'name = "host"\n' 'entry-point = "main.jac"\n'
    );
    _reset_install_state();
    log_root = logging.getLogger();
    saved_handlers = list(log_root.handlers);
    saved_level = log_root.level;
    try {
        log_root.handlers = [];
        log_root.setLevel(int(logging.DEBUG));
        install_structured_logging();
        assert log_root.level == int(logging.DEBUG) , f"an explicit DEBUG level was forced to {log_root.level}";
        assert len(log_root.handlers) == 1;
        assert isinstance(log_root.handlers[0].formatter, _JacJsonFormatter);
    } finally {
        log_root.handlers = saved_handlers;
        log_root.setLevel(saved_level);
        _reset_install_state();
        reset_scale_config();
        shutil.rmtree(project_dir, ignore_errors=True);
    }
}


test "default install on an untouched root: one JSON handler at INFO" {
    project_dir = _project_with_toml(
        "[project]\n" 'name = "host"\n' 'entry-point = "main.jac"\n'
    );
    _reset_install_state();
    log_root = logging.getLogger();
    saved_handlers = list(log_root.handlers);
    saved_level = log_root.level;
    try {
        log_root.handlers = [];
        log_root.setLevel(int(logging.WARNING));
        install_structured_logging();
        assert len(log_root.handlers) == 1;
        assert isinstance(log_root.handlers[0].formatter, _JacJsonFormatter);
        assert log_root.level == int(logging.INFO) , f"expected the pod default INFO, got {log_root.level}";
    } finally {
        log_root.handlers = saved_handlers;
        log_root.setLevel(saved_level);
        _reset_install_state();
        reset_scale_config();
        shutil.rmtree(project_dir, ignore_errors=True);
    }
}


test "install before any config load defers, then applies once config exists" {
    # A process may reach install before its own config load; deciding from
    # ambient defaults there would latch past a project's explicit opt-out,
    # and creating the singleton there would mis-scope config for everything
    # after it. Until the process loads its config, install must do nothing.
    _reset_install_state();
    reset_scale_config();
    log_root = logging.getLogger();
    saved_handlers = list(log_root.handlers);
    saved_level = log_root.level;
    try {
        log_root.handlers = [];
        log_root.setLevel(int(logging.WARNING));
        install_structured_logging();
        assert peek_scale_config() is None , (
            "install_structured_logging created the config singleton as a "
            "side effect"
        );
        assert log_root.handlers == [] , (
            "install decided from ambient defaults before any config load"
        );
        assert log_root.level == int(logging.WARNING) , (
            f"install touched the level before any config load: {log_root.level}"
        );
        get_scale_config();
        install_structured_logging();
        assert len(log_root.handlers) == 1 , (
            "install did not apply on the first call after config load"
        );
        assert isinstance(log_root.handlers[0].formatter, _JacJsonFormatter);
    } finally {
        log_root.handlers = saved_handlers;
        log_root.setLevel(saved_level);
        _reset_install_state();
        reset_scale_config();
    }
}


test "emit_log_record produces a JSON line with the stable schema" {
    reset_scale_config();
    get_scale_config();
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
    reset_scale_config();
    get_scale_config();
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
    reset_scale_config();
    get_scale_config();
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


test "install_structured_logging routes serving loggers through root" {
    reset_scale_config();
    get_scale_config();
    install_structured_logging();

    for name in [
        "jaclang.runtimelib.serving.server",
        "jaclang.runtimelib.serving.app"
    ] {
        lg = logging.getLogger(name);
        assert lg.propagate is True , f"{name} should propagate to root";
        assert lg.handlers == [] , f"{name} should have no local handlers";
    }
}


test "trace_id populates on records emitted from child loggers" {
    reset_scale_config();
    get_scale_config();
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
