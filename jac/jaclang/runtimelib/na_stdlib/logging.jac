import sys;

glob CRITICAL: int = 50,
     FATAL: int = 50,
     ERROR: int = 40,
     WARNING: int = 30,
     WARN: int = 30,
     INFO: int = 20,
     DEBUG: int = 10,
     NOTSET: int = 0,
     BASIC_FORMAT: str = "%(levelname)s:%(name)s:%(message)s";

obj _Config {
    has level: int = 30,
        fmt: str = "%(levelname)s:%(name)s:%(message)s";
}

glob _cfg: _Config = _Config();

def _sub(text: str, token: str, value: str) -> str {
    return value.join(text.split(token));
}

def _render(levelname: str, name: str, msg: str) -> str {
    line: str = _sub(_cfg.fmt, "%(levelname)s", levelname);
    line = _sub(line, "%(name)s", name);
    line = _sub(line, "%(message)s", msg);
    return line;
}

obj:pub Logger {
    has name: str = "root";

    def _log(levelname: str, level: int, msg: str) {
        if level >= _cfg.level {
            sys.stderr.write(_render(levelname, self.name, msg) + "\n");
        }
    }

    def debug(msg: str) {
        self._log("DEBUG", 10, msg);
    }

    def info(msg: str) {
        self._log("INFO", 20, msg);
    }

    def warning(msg: str) {
        self._log("WARNING", 30, msg);
    }

    def error(msg: str) {
        self._log("ERROR", 40, msg);
    }

    def critical(msg: str) {
        self._log("CRITICAL", 50, msg);
    }

    def setLevel(level: int) {
        _cfg.level = level;
    }
}

def:pub getLogger(name: str = "root") -> Logger {
    if name == "" {
        return Logger(name="root");
    }
    return Logger(name=name);
}

def:pub basicConfig(
    level: int = -1,
    format: str = "",
    datefmt: str = "",
    style: str = "",
    filename: str = "",
    filemode: str = "",
    encoding: str = "",
    errors: str = "",
    force: bool = False
) {
    if level >= 0 {
        _cfg.level = level;
    }
    if format != "" {
        _cfg.fmt = format;
    }
}

def:pub debug(msg: str) {
    getLogger("root").debug(msg);
}

def:pub info(msg: str) {
    getLogger("root").info(msg);
}

def:pub warning(msg: str) {
    getLogger("root").warning(msg);
}

def:pub error(msg: str) {
    getLogger("root").error(msg);
}

def:pub critical(msg: str) {
    getLogger("root").critical(msg);
}
