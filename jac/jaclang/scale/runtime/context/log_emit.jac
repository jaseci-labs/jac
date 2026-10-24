import os;
import json;
import logging;
import from datetime { datetime, timezone }
glob _SVC_NAME: str = (
         os.getenv("JAC_SV_NAME", "").strip()
         or os.getenv("K8S_APP_NAME", "").strip()
         or "unknown"
     ),
     _structured_installed: bool = False,
     _structured_optout: bool = False,
     _root_logger: logging.Logger = logging.getLogger();


def _to_str(value: any) -> str;


class _JacJsonFormatter(logging.Formatter) {
    def format(self: any, record: logging.LogRecord) -> str;
}


def emit_log_record(level_name: str, msg: str, **extras: any);


def info(msg: str, **extras: any);

def warning(msg: str, **extras: any);

def error(msg: str, **extras: any);

def debug(msg: str, **extras: any);


def install_structured_logging;
