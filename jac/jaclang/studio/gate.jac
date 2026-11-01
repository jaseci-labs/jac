import os;
import sys;
import time;
import difflib;
import logging;
import warnings;
import threading;

glob ARCH_CODES: dict[str, str] = {
         "E1144": "written import under archwire",
         "E2094": "written import under archwire",
         "E1146": "unused wired name",
         "E2090": "rule violation",
         "E2091": "rule violation",
         "E2092": "duplicate rule",
         "E2093": "archwire syntax error",
         "E2095": "bare package import",
         "E2096": "unexported package module",
         "E2097": "dangling wiring",
         "E2098": "rule pattern matches nothing",
         "E2099": "cross-package import",
         "E2100": "unbounded rule"
     },
     GATE_SKIP_DIRS: list[str] = [
         "node_modules",
         "__pycache__",
         ".jac",
         ".git",
         "build",
         "dist",
         ".venv",
         "venv",
         "vendor"
     ],
     FEEDBACK_LIMIT: int = 20,
     _GATE_LOCK: threading.Lock = threading.Lock();

obj SymbolChange {
    has key: str,
        kind: str,
        change: str,
        old_lines: (tuple[int, int] | None) = None,
        new_lines: (tuple[int, int] | None) = None,
        public: bool = False;

    def to_dict -> dict[str, any];
}

obj DiagInfo {
    has file: str,
        line: int,
        col: int,
        severity: str,
        code: str,
        message: str,
        help: str = "",
        anchor: str = "";

    def to_dict -> dict[str, any];
    def short(root_dir: str = "") -> str;
}

obj ArchChange {
    has kind: str,
        detail: str,
        module: str = "";

    def to_dict -> dict[str, any];
}

obj EditReview {
    has path: str,
        old_text: str,
        new_text: str,
        diff: str = "",
        root_dir: str = "",
        symbol_changes: list[SymbolChange] = [],
        new_diagnostics: list[DiagInfo] = [],
        resolved_diagnostics: list[DiagInfo] = [],
        remaining_errors: int = 0,
        arch_changes: list[ArchChange] = [],
        checked_files: list[str] = [],
        checked: bool = False,
        check_error: str = "",
        elapsed: float = 0.0,
        seen_staged: list[str] = [];

    def new_errors -> list[DiagInfo];
    def clean -> bool;
    def summary -> str;
    def feedback -> str;
    def to_dict -> dict[str, any];
}

obj OverlayHost(ProjectHost) {
    has overlay: dict[str, str] = {},
        enabled: bool = False,
        log_path: str = "";

    def read_source(path: str) -> str;
    def annex_files(path: str, suffix: str = ".impl.jac") -> list[str];
    def note(message: str, style: str = "dim");
}

obj ThreadRouter {
    has target: any,
        sink: any,
        thread_id: int;

    def write(data: str) -> int;
    def flush;
    def isatty -> bool;
    def fileno -> int;
    def __getattr__(name: str) -> any;
}

obj EditGate {
    has root_dir: str,
        max_dependents: int = 6,
        overlay: dict[str, str] = {},
        log_path: str = "",
        _host: (OverlayHost | None) = None,
        _baselines:
            dict[
                str,
                tuple[tuple[tuple[str, int, int], ...], list[DiagInfo], list[str]]
            ] = {},
        _last_deps: list[str] = [];

    def postinit;
    def stage(path: str, new_text: str) -> None;
    def unstage(path: str) -> None;
    def staged -> dict[str, str];
    def read(path: str) -> (str | None);
    def review(path: str, new_text: str, cancelled: any = None) -> EditReview;
    def unstage_if(path: str, text: str) -> None;
    def commit(path: str) -> None;
    def _disk_text(path: str) -> (str | None);
    def _text_for(path: str, overlay: bool) -> str;
    def _stamp(paths: list[str]) -> tuple[tuple[str, int, int], ...];
    def _arch_staged -> bool;
    def _module_files(head: str) -> list[str];
    def _head_of(path: str) -> str;
    def _owner(head: str) -> dict[str, str];
    def _check(target: str, overlay: bool) -> list[DiagInfo];
    def _baseline(target: str) -> list[DiagInfo];
    def _targets(real: str, review: EditReview) -> list[str];
    def _dependents(head: str, review: EditReview) -> list[str];
    def _scan_importers(head: str) -> list[str];
    def _quiet_enter -> dict[str, any];
    def _quiet_exit(saved: dict[str, any]) -> None;
}

def gate_root_for(path: str) -> str;

def symbol_table(text: str, path: str) -> dict[str, tuple[str, int, int, str, str]];

def symbol_changes(old_text: str, new_text: str, path: str) -> list[SymbolChange];

def import_lines(text: str, path: str) -> list[str];

def wiring_changes(old_text: str, new_text: str, path: str) -> list[ArchChange];

def match_diagnostics(
    before: list[DiagInfo], after: list[DiagInfo]
) -> tuple[list[DiagInfo], list[DiagInfo]];

def format_review(rv: EditReview) -> str;

def leaf_changes(changes: list[SymbolChange]) -> list[SymbolChange];

def change_groups(changes: list[SymbolChange]) -> dict[str, list[str]];

def partial_text(
    old_text: str, new_text: str, changes: list[SymbolChange], keep: set[str]
) -> str;

def _node_text(nd: any) -> str;

def _lines_text(lines: list[str], first: int, last: int) -> str;

def _rel(path: str, root_dir: str) -> str;
