impl _to_str(value: any) -> str {
    return str(value);
}

impl _JacJsonFormatter.format(self: any, record: logging.LogRecord) -> str {
    ts = datetime.fromtimestamp(record.created, tz=timezone.utc).isoformat();

    if ts.endswith("+00:00") {
        ts = ts[:-6] + "Z";
    }
    out: dict[str, any] = {
        "ts": ts,
        "level": record.levelname,
        "service": _SVC_NAME,
        "trace_id": record?.trace_id,
        "msg": record.getMessage()
    };
    extras = record?.svc_extras;
    if extras {
        out["extras"] = extras;
    }
    if record.exc_info {
        out["exc"] = self.formatException(record.exc_info);
    }

    return json.dumps(out, `default=_to_str, ensure_ascii=False);
}

impl emit_log_record(level_name: str, msg: str, **extras: any) {
    level_int: int = int(getattr(logging, level_name.upper(), logging.INFO));
    record = _root_logger.makeRecord(
        name="jaclang.scale.svlog",
        level=level_int,
        fn="",
        lno=0,
        msg=msg,
        args=(),
        exc_info=None
    );
    if extras {
        setattr(record, "svc_extras", dict(extras));
    }
    _root_logger.handle(record);
}

impl info(msg: str, **extras: any) {
    emit_log_record("INFO", msg, **extras);
}

impl warning(msg: str, **extras: any) {
    emit_log_record("WARNING", msg, **extras);
}

impl error(msg: str, **extras: any) {
    emit_log_record("ERROR", msg, **extras);
}

impl debug(msg: str, **extras: any) {
    emit_log_record("DEBUG", msg, **extras);
}

impl install_structured_logging {
    if not _structured_installed {
        import from jaclang.scale.config.config_loader { peek_scale_config }
        cfg = peek_scale_config();
        if cfg is None {
            return;
        }
        _structured_optout = not bool(
            cfg.get_server_config().get('structured_logs', True)
        );
        if not _structured_optout {
            handler = logging.StreamHandler();
            handler.setFormatter(_JacJsonFormatter());

            _log_root = logging.getLogger();

            _log_root.handlers = [handler];

            if _log_root.level in [int(logging.NOTSET), int(logging.WARNING)] {
                _log_root.setLevel(int(logging.INFO));
            }

            import from jaclang.scale.runtime.context.trace_ctx {
                install_trace_log_filter
            }
            install_trace_log_filter();
        }
        _structured_installed = True;
    }

    if _structured_optout {
        return;
    }

    for noisy_name in ["jaclang.server.serving.server", "jaclang.server.serving.app"] {
        noisy = logging.getLogger(noisy_name);
        if noisy.handlers or not noisy.propagate {
            noisy.handlers = [];
            noisy.propagate = True;
        }
    }
}
