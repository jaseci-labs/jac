import sys;
import time;

glob:pub CRITICAL: int = 50,
     FATAL: int = 50,
     ERROR: int = 40,
     WARNING: int = 30,
     WARN: int = 30,
     INFO: int = 20,
     DEBUG: int = 10,
     NOTSET: int = 0,
     BASIC_FORMAT: str = "%(levelname)s:%(name)s:%(message)s",
     raiseExceptions: bool = True;

glob _DEFAULT_TIME_FORMAT: str = "%Y-%m-%d %H:%M:%S",
     _START_TIME: float = time.time();

glob _KIND_STDERR: int = 0,
     _KIND_STDOUT: int = 1,
     _KIND_FILE: int = 2;


obj _Names {
    has extra: dict[str, str];

    def init;
}

glob _NAMES: _Names = _Names();


def:pub getLevelName(level: int) -> str;


def:pub addLevelName(level: int, levelName: str);


def:pub getLevelNamesMapping -> dict[str, int];


def _pad3(v: int) -> str;


obj:pub LogRecord {
    has name: str,
        levelno: int,
        levelname: str,
        msg: str,
        pathname: str,
        lineno: int,
        funcName: str,
        created: float,
        msecs: float,
        relativeCreated: float;

    def init(
        name: str = "root",
        level: int = 0,
        pathname: str = "",
        lineno: int = 0,
        msg: str = "",
        args: (list[any] | None) = None,
        exc_info: (list[any] | None) = None,
        func: str = "",
        sinfo: str = ""
    );

    def getMessage -> str;
}


def _sub(text: str, token: str, value: str) -> str;


obj:pub Formatter {
    has _fmt: str,
        datefmt: str;

    def init(fmt: str = "", datefmt: str = "", style: str = "%");
    def formatTime(record: LogRecord, datefmt: str = "") -> str;
    def formatMessage(record: LogRecord) -> str;
    def format(record: LogRecord) -> str;
}


def _f6(v: float) -> str;


def _basename(path: str) -> str;


def _modname(path: str) -> str;


obj:pub Handler {
    has level: int,
        _kind: int,
        _stream: int,
        _formatter: Formatter | None,
        _closed: bool;

    def init(level: int = 0, kind: int = 0, stream: int = 0);
    def setLevel(level: int);
    def setFormatter(fmt: Formatter);
    def format(record: LogRecord) -> str;
    def emit(record: LogRecord);
    def handle(record: LogRecord) -> bool;
    def flush;
    def close;
}

glob _DEFAULT_FORMATTER: Formatter = Formatter(fmt="%(message)s");


def:pub StreamHandler(stream: str = "stderr") -> Handler;


def:pub FileHandler(
    filename: str, mode: str = "a", encoding: str = "", delay: bool = False
) -> Handler;


obj:pub Logger {
    has name: str,
        level: int,
        propagate: bool,
        disabled: bool,
        handlers: list[Handler],
        parent: Logger | None;

    def init(name: str = "root", level: int = 0);
    def setLevel(level: int);
    def addHandler(hdlr: Handler) -> None;
    def removeHandler(hdlr: Handler) -> None;
    def hasHandlers -> bool;
    def getEffectiveLevel -> int;
    def isEnabledFor(level: int) -> bool;
    def callHandlers(record: LogRecord) -> int;
    def handle(record: LogRecord) -> None;
    def _log(level: int, msg: str) -> None;
    def debug(msg: str);
    def info(msg: str);
    def warning(msg: str);
    def error(msg: str);
    def critical(msg: str);
    def fatal(msg: str);
    def exception(msg: str);
    def log(level: int, msg: str);
    def getChild(suffix: str) -> Logger;
}


obj _RootCfg {
    has disable: int,
        configured: bool;

    def init;
}

glob _ROOTCFG: _RootCfg = _RootCfg(),
     _ROOT: Logger = Logger(name="root", level=WARNING);


obj _Registry {
    has known: dict[str, Logger];

    def init;
}

glob _REG: _Registry = _Registry();


def _parent_for(name: str) -> Logger;


def:pub getLogger(name: str = "") -> Logger;


def:pub basicConfig(
    level: int = -1,
    format: str = "",
    datefmt: str = "",
    style: str = "%",
    filename: str = "",
    filemode: str = "a",
    stream: str = "",
    force: bool = False,
    encoding: str = "",
    errors: str = ""
);


def _ensure_root;


def:pub disable(level: int = 50);


def:pub debug(msg: str);


def:pub info(msg: str);


def:pub warning(msg: str);


def:pub error(msg: str);


def:pub critical(msg: str);


def:pub exception(msg: str);


def log_msg(level: int, msg: str);


def shutdown_handlers;
