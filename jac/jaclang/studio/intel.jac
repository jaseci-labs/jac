import io;
import os;
import sys;
import time;
import logging;
import threading;
import from collections { deque }

glob LOG_REL: str = os.path.join(".jac", "studio", "logs", "intel.log"),
     OVERRIDABLE: set[str] = {"name", "function", "class"},
     SPECIAL_WORDS: set[str] = {
         "self",
         "super",
         "here",
         "visitor",
         "root",
         "props",
         "init",
         "postinit"
     },
     NUMBER_KINDS: set[str] = {"INT", "HEX", "BIN", "OCT", "FLOAT"},
     PUNCT_KINDS: set[str] = {
         "LPAREN",
         "RPAREN",
         "LBRACE",
         "RBRACE",
         "LSQUARE",
         "RSQUARE",
         "COMMA",
         "COLON",
         "SEMI",
         "DOT"
     },
     CLASS_KWS: set[str] = {
         "KW_OBJECT",
         "KW_CLASS",
         "KW_ENUM",
         "KW_NODE",
         "KW_EDGE",
         "KW_WALKER"
     },
     FUNC_KWS: set[str] = {"KW_DEF", "KW_CAN"},
     STRING_PREFIXES: set[str] = {"r", "b", "u", "rb", "br"};

obj Span {
    has start: int,
        end: int,
        style: str;
}

obj Diag {
    has line: int,
        col: int,
        end_line: int,
        end_col: int,
        severity: str,
        code: str,
        message: str,
        help: str = "";
}

obj StdioRouter {
    has threads: dict[int, any] = {},
        capturing: list[any] = [],
        refs: int = 0,
        saved_out: any = None,
        saved_err: any = None,
        saved_handlers: list[tuple[any, list[any]]] = [],
        log_handler: any = None,
        lock: any postinit;

    def postinit -> None;
    def sink_for_current -> any;
    def install(sink: any) -> None;
    def uninstall -> None;
}

obj RoutedStream {
    has orig: any,
        router: StdioRouter;

    def write(s: str) -> int;
    def writelines(lines: list[str]) -> None;
    def flush -> None;
    def isatty -> bool;
    def fileno -> int;
    def __getattr__(name: str) -> any;
}

glob ROUTER: StdioRouter = StdioRouter();

def lex_spans(text: str, path: str = "<input>") -> list[list[Span]];

def overlay_spans(base: list[Span], top: list[Span]) -> list[Span];

obj CodeIntel {
    has root_dir: str = "",
        log_path: str = "",
        max_apps: int = 1,
        _cancel: any = None,
        _lock: any postinit,
        _cv: any postinit,
        _worker: any = None,
        _stopping: bool = False,
        _started: bool = False,
        _sink: any = None,
        _ls: any = None,
        _engine_error: str = "",
        _checks: list[str] = [],
        _queries: any postinit,
        _invals: list[str] = [],
        _open: set[str] = set(),
        _current: str = "",
        _next_ticket: int = 1,
        _results: list[tuple[int, any]] = [],
        _status: dict[str, str] = {},
        _sem: dict[str, list[list[Span]]] = {},
        _sem_lines: dict[str, list[str]] = {},
        _sem_version: dict[str, int] = {},
        _diags: dict[str, list[Diag]] = {},
        _inlays: dict[str, dict[int, list[tuple[int, str]]]] = {},
        _syms: dict[str, dict[int, list[tuple[int, int, dict[str, any]]]]] = {},
        _check_secs: dict[str, float] = {},
        _real: dict[str, str] = {},
        _heads: dict[str, str] = {},
        _hl: dict[str, tuple[any, list[str], list[list[Span]]]] = {},
        _merged: dict[str, tuple[any, int, list[list[Span]]]] = {};

    def postinit -> None;
    def start(root_dir: str) -> None;
    def stop(timeout: float = 5.0) -> None;
    def highlight(path: str, text: (str | None) = None) -> list[list[Span]];
    def line_styles(path: str, text: (str | None) = None) -> list[list[Span]];
    def request_check(path: str) -> None;
    def semantic(path: str) -> (list[list[Span]] | None);
    def diagnostics(path: str) -> list[Diag];
    def inlays(path: str) -> dict[int, list[tuple[int, str]]];
    def status(path: str) -> str;
    def check_secs(path: str) -> float;
    def request_hover(path: str, line: int, col: int) -> int;
    def request_definition(path: str, line: int, col: int) -> int;
    def request_references(path: str, line: int, col: int) -> int;
    def poll -> list[tuple[int, any]];
    def symbol_at(path: str, line: int, col: int) -> (dict[str, any] | None);
    def invalidate(path: str) -> None;
    def realpath(path: str) -> str;
    def head(path: str) -> str;
    def _lexed(
        path: str, text: (str | None)
    ) -> tuple[any, list[str], list[list[Span]]];

    def _query(kind: str, path: str, line: int, col: int) -> int;
    def _run -> None;
    def _ensure_engine -> bool;
    def _do_check(head: str) -> None;
    def _do_query(ticket: int, kind: str, path: str, line: int, col: int) -> None;
    def _do_invalidate(path: str) -> None;
    def _store(head: str, out: dict[str, any], secs: float) -> None;
}
