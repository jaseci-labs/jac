import os;
import json;
import logging;
import from datetime { datetime, timezone }
import from typing { Any }

glob _SVC_NAME: str = (
         os.getenv("JAC_SV_NAME", "").strip()
         or os.getenv("K8S_APP_NAME", "").strip()
         or "unknown"
     ),
     _structured_installed: bool = False,
     _root_logger: logging.Logger = logging.getLogger();


def _to_str(value: Any) -> str {
    return str(value);
}


class _JacJsonFormatter(logging.Formatter) {
    def format(self: any, record: logging.LogRecord) -> str {
        ts = datetime.fromtimestamp(record.created, tz=timezone.utc).isoformat();

        if ts.endswith("+00:00") {
            ts = ts[:-6] + "Z";
        }
        out: dict[str, Any] = {
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

        return json.dumps(out, default=_to_str, ensure_ascii=False);
    }
}


def emit_log_record(level_name: str, msg: str, **extras: Any) {
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


def info(msg: str, **extras: Any) {
    emit_log_record("INFO", msg, **extras);
}

def warning(msg: str, **extras: Any) {
    emit_log_record("WARNING", msg, **extras);
}

def error(msg: str, **extras: Any) {
    emit_log_record("ERROR", msg, **extras);
}

def debug(msg: str, **extras: Any) {
    emit_log_record("DEBUG", msg, **extras);
}


def install_structured_logging {
    global _structured_installed;

    if not _structured_installed {
        handler = logging.StreamHandler();
        handler.setFormatter(_JacJsonFormatter());

        _log_root = logging.getLogger();

        _log_root.handlers = [handler];

        _log_root.setLevel(int(logging.INFO));

        import from jaclang.scale.runtime.context.trace_ctx { install_trace_log_filter }
        install_trace_log_filter();

        _structured_installed = True;
    }

    for noisy_name in ["uvicorn", "uvicorn.access", "uvicorn.error", "fastapi"] {
        noisy = logging.getLogger(noisy_name);
        if noisy.handlers or not noisy.propagate {
            noisy.handlers = [];
            noisy.propagate = True;
        }
    }
}
