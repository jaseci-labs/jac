"""Jaseci Log Handlers."""

from datetime import time as dtime
from enum import IntEnum
from io import text_encoding
from itertools import chain
from logging import FileHandler, LogRecord, getLogger
from logging.handlers import (
    BaseRotatingHandler,
    RotatingFileHandler,
    TimedRotatingFileHandler,
)
from os import getenv, remove, stat
from os.path import exists, getmtime, isfile
from pathlib import Path
from re import ASCII, compile, escape
from stat import ST_MTIME
from time import gmtime, localtime, strftime, time as ttime
from traceback import format_exc
from typing import Any

from ecs_logging import StdlibFormatter

from orjson import JSONEncodeError, dumps

from starlette.datastructures import UploadFile

DEFAULT_PART = [0]


class MixedTimedRotatingFileHandler(TimedRotatingFileHandler, RotatingFileHandler):
    """Merge TimedRotatingFileHandler and RotatingFileHandler."""

    # mypy bug: Incompatible types in assignment
    # (expression has type "int", base class "RotatingFileHandler" defined the type as "str")
    # even RotatingHandler declared as int
    maxBytes: int  # type: ignore[assignment] # noqa: N815

    def __init__(
        self,
        filename: str,
        when: str = "h",
        interval: int = 1,
        max_bytes: int = 0,
        backup_count: int = 0,
        encoding: str | None = None,
        delay: bool = False,
        utc: bool = False,
        at_time: dtime | None = None,
        errors: str | None = None,
    ) -> None:
        """Override __init__."""
        Path(filename).parent.mkdir(parents=True, exist_ok=True)
        BaseRotatingHandler.__init__(
            self,
            filename,
            "a",
            encoding=text_encoding(encoding),
            delay=delay,
            errors=errors,
        )

        file_path = Path(self.baseFilename)
        self.file_folder = file_path.parent.absolute()
        self.file_name = file_path.stem
        self.file_ext = file_path.suffix

        self.maxBytes: int = max_bytes
        self.when = when.upper()
        self.backupCount = backup_count
        self.utc = utc
        self.atTime = at_time

        re_format = escape(self.file_name) + r"-[0-9]+" + escape(self.file_ext) + "$"
        if self.when == "S":
            self.interval = 1
            self.prefix = "%Y-%m-%d-%H-%M-%S"
            ext_match = (
                r"^(?<!\d)\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2}(?!\d)-" + re_format
            )
        elif self.when == "M":
            self.interval = 60
            self.prefix = "%Y-%m-%d-%H-%M"
            ext_match = r"^(?<!\d)\d{4}-\d{2}-\d{2}-\d{2}-\d{2}(?!\d)-" + re_format
        elif self.when == "H":
            self.interval = 60 * 60
            self.prefix = "%Y-%m-%d-%H"
            ext_match = r"^(?<!\d)\d{4}-\d{2}-\d{2}-\d{2}(?!\d)-" + re_format
        elif self.when == "D" or self.when == "MIDNIGHT":
            self.interval = 60 * 60 * 24
            self.prefix = "%Y-%m-%d"
            ext_match = r"^(?<!\d)\d{4}-\d{2}-\d{2}(?!\d)-" + re_format
        elif self.when.startswith("W"):
            self.interval = 60 * 60 * 24 * 7
            if len(self.when) != 2:
                raise ValueError(
                    f"You must specify a day for weekly rollover from 0 to 6 (0 is Monday): {self.when}"
                )
            if self.when[1] < "0" or self.when[1] > "6":
                raise ValueError(
                    f"Invalid day specified for weekly rollover: {self.when}"
                )
            self.dayOfWeek = int(self.when[1])
            self.prefix = "%Y-%m-%d"
            ext_match = r"^(?<!\d)\d{4}-\d{2}-\d{2}(?!\d)-" + re_format
        else:
            raise ValueError(f"Invalid rollover interval specified: {self.when}")

        self.extMatch = compile(ext_match, ASCII)
        self.interval = self.interval * interval
        filename = self.baseFilename
        if exists(filename):
            t = stat(filename)[ST_MTIME]
        else:
            t = ttime()
        self.has_buffer = False
        self.rolloverAt = self.computeRollover(int(t))

    def pull_buffer(self) -> int:
        """Pull buffer."""
        if self.has_buffer:
            self.has_buffer = False
            return self.interval
        return 0

    def build_file_name(self, prefix: str) -> str:
        """Override rotation_filename."""
        part_extractor = compile(
            r"^"
            + escape(f"{prefix}-{self.file_name}-")
            + r"([0-9]+)"
            + escape(self.file_ext)
            + r"$"
        )

        part = (
            max(
                chain(
                    (
                        int(match.group(1))
                        for path in self.file_folder.iterdir()
                        if (match := part_extractor.match(path.name))
                    ),
                    DEFAULT_PART,
                )
            )
            + 1
        )

        name = f"{self.file_folder}/{prefix}-{self.file_name}-{part}{self.file_ext}"

        if not callable(self.namer):
            return name
        else:
            return self.namer(name)

    def remove_old_backup(self) -> None:
        """Remove old backup files."""
        if self.backupCount > 0:
            backups = sorted(
                (
                    path
                    for path in self.file_folder.iterdir()
                    if self.extMatch.match(path.name)
                ),
                key=getmtime,
            )

            if self.backupCount < (backup_count := len(backups)):
                for backup in backups[0 : backup_count - self.backupCount]:
                    remove(backup)

    def doRollover(self, record: LogRecord) -> None:  # type: ignore[override] # noqa: N802
        """Override doRollover."""
        current_time = int(record.created)
        t = self.rolloverAt - (self.interval + self.pull_buffer())

        if self.utc:
            time_tuple = gmtime(t)
        else:
            time_tuple = localtime(t)
            dst_now = localtime(current_time)[-1]
            dst_then = time_tuple[-1]
            if dst_now != dst_then:
                if dst_now:
                    addend = 3600
                else:
                    addend = -3600
                time_tuple = localtime(t + addend)
        prefix = strftime(self.prefix, time_tuple)

        if self.stream:
            self.stream.close()
            self.stream = None  # type: ignore[assignment]

        self.rotate(self.baseFilename, self.build_file_name(prefix))
        self.remove_old_backup()

        if not self.delay:
            self.stream = self._open()

    def shouldRollover(self, record: LogRecord) -> bool:  # noqa: N802
        """Override shouldRollover."""
        t = int(record.created)
        if exists(self.baseFilename) and not isfile(self.baseFilename):
            self.rolloverAt = self.computeRollover(t)
            return False
        if self.stream is None:
            self.stream = self._open()
        if self.maxBytes > 0:
            msg = "%s\n" % self.format(record)
            self.stream.seek(0, 2)
            if self.stream.tell() + len(msg) >= self.maxBytes:
                return True
        if t >= self.rolloverAt:
            self.has_buffer = True
            self.rolloverAt = self.computeRollover(t)
            return True
        return False

    def computeRollover(self, currentTime: int) -> int:  # noqa: N802, N803
        """Override compute roll over to adjust buffer."""
        return super().computeRollover(currentTime) - int(currentTime % self.interval)

    def emit(self, record: LogRecord) -> None:
        """
        Emit a record.

        Output the record to the file, catering for rollover as described
        in doRollover().
        """
        try:
            if self.shouldRollover(record):
                self.doRollover(record)
            FileHandler.emit(self, record)
        except Exception:
            self.handleError(record)


class Level(IntEnum):
    """Log Level Enum."""

    CRITICAL = 50
    FATAL = CRITICAL
    ERROR = 40
    WARNING = 30
    WARN = WARNING
    INFO = 20
    DEBUG = 10
    NOTSET = 0


logger = getLogger(getenv("LOGGER_NAME", "app"))
logger.setLevel(Level[getenv("LOGGER_LEVEL", "DEBUG")].value)

handler = MixedTimedRotatingFileHandler(
    getenv("LOGGER_FILE_PATH", "/tmp/jac_cloud_logs/jac-cloud.log"),
    when=getenv("LOGGER_ROLLOVER_INTERVAL", "d"),
    backup_count=int(getenv("LOGGER_MAX_BACKUP", "-1")),
    max_bytes=int(getenv("LOGGER_ROLLOVER_MAX_FILE_SIZE", "10000000")),
    utc=getenv("LOGGER_USE_UTC") == "true",
)
handler.setFormatter(StdlibFormatter())
logger.addHandler(handler)


def cls_fullname(obj: object) -> str:
    """Get class full name."""
    cls = obj.__class__
    module = cls.__module__
    if module == "__builtin__":
        return cls.__name__
    return module + "." + cls.__name__


def serializer(data: object) -> object:
    """Override default handler."""
    match data:
        case UploadFile():
            return {
                "name": data.filename,
                "content_type": data.content_type,
                "size": data.size,
            }
        case bytes():
            return data.decode()
        case _:
            raise JSONEncodeError(
                f"Type is not JSON serializable: {cls_fullname(data)}"
            )


def log_dumps(payload: dict[str, Any] | list[Any]) -> str:
    """Dump dictionary log."""
    try:
        return dumps(payload, default=serializer).decode()
    except Exception:
        return format_exc()


def log_entry(
    api: str, caller: str | None, payload: dict[str, Any], node: str | None = None
) -> dict[str, Any]:
    """Log metadata on entry."""
    log: dict[str, Any] = {
        "api_name": api,
        "caller_name": caller,
        "payload": log_dumps(payload),
        "entry_node": node,
    }
    msg = str(
        f"Incoming call from {log["caller_name"]}"
        f" to {log["api_name"]}"
        f" with payload: {log["payload"]}"
        f" at entry node: {log["entry_node"]}"
    )
    log["extra_fields"] = list(log.keys())
    logger.info(msg, extra=log)

    return log


def log_exit(response: dict[str, Any], log: dict[str, Any] | None = None) -> None:
    """Log metadata on exit."""
    log = log or {}
    log["api_response"] = log_dumps(response)
    log["extra_fields"] = list(log.keys())
    log_msg = str(
        f"Returning call from {log["caller_name"]}"
        f" to {log["api_name"]}"
        f" with payload: {log["payload"]}"
        f" at entry node: {log["entry_node"]}"
        f" with response: {log["api_response"]}"
    )
    logger.info(
        log_msg,
        extra=log,
    )
