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
            dict[str, tuple[tuple[tuple[str, int, int], ...], list[DiagInfo]]] = {};

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

impl SymbolChange.to_dict -> dict[str, any] {
    return {
        "key": self.key,
        "kind": self.kind,
        "change": self.change,
        "old_lines": list(self.old_lines) if self.old_lines else None,
        "new_lines": list(self.new_lines) if self.new_lines else None,
        "public": self.public
    };
}

impl DiagInfo.to_dict -> dict[str, any] {
    return {
        "file": self.file,
        "line": self.line,
        "col": self.col,
        "severity": self.severity,
        "code": self.code,
        "message": self.message,
        "help": self.help
    };
}

impl DiagInfo.short(root_dir: str = "") -> str {
    code = f"[{self.code}] " if self.code else "";
    return f"{_rel(self.file, root_dir)}:{self.line}:{self.col} {self.severity} {code}{self.message}";
}

impl ArchChange.to_dict -> dict[str, any] {
    return {"kind": self.kind, "detail": self.detail};
}

impl EditReview.new_errors -> list[DiagInfo] {
    return [
        d
        for d in self.new_diagnostics
        if d.severity == "error"
    ];
}

impl EditReview.clean -> bool {
    return self.checked and not self.new_errors();
}

impl EditReview.summary -> str {
    name = os.path.basename(self.path);
    secs = f"{self.elapsed:.1f}s";
    if not self.checked {
        why = self.check_error.splitlines()[0] if self.check_error else "not checked";
        return f"{name}: could not check ({why}) [{secs}]";
    }
    errs = self.new_errors();
    warns = len(self.new_diagnostics) - len(errs);
    syms = len(self.symbol_changes);
    parts: list[str] = [];
    if errs {
        first = errs[0];
        code = f"{first.code} " if first.code else "";
        parts.append(
            f"{len(errs)} new error{'s' if len(errs) != 1 else ''} ({code}line {first.line}: {first.message})"
        );
    } else {
        parts.append("clean");
    }
    if warns {
        parts.append(f"{warns} new warning{'s' if warns != 1 else ''}");
    }
    if self.resolved_diagnostics {
        parts.append(f"{len(self.resolved_diagnostics)} resolved");
    }
    if syms {
        parts.append(f"{syms} symbol{'s' if syms != 1 else ''} changed");
    }
    if self.arch_changes {
        parts.append(
            f"{len(self.arch_changes)} architecture change{'s'
                if len(self.arch_changes) != 1
                else ''}"
        );
    }
    if self.remaining_errors and errs != [] and self.remaining_errors != len(errs) {
        parts.append(f"{self.remaining_errors} errors in checked files");
    }
    return f"{name}: " + ", ".join(parts) + f" [{secs}]";
}

impl EditReview.feedback -> str {
    rel = _rel(self.path, self.root_dir);
    lines: list[str] = [];
    if not self.checked {
        lines.append(
            f"The write to {rel} was rejected, and the compiler could not check it: {self.check_error}"
        );
        return "\n".join(lines);
    }
    errs = self.new_errors();
    if errs {
        lines.append(
            f"The write to {rel} was rejected: the Jac compiler reports {len(
                errs
            )} new error{'s'
                if len(errs) != 1
                else ''}. Fix them and write the file again."
        );
    } else {
        lines.append(f"The write to {rel} was rejected by the user.");
    }
    shown = errs
        + [
            d
            for d in self.new_diagnostics
            if d.severity != "error"
        ];
    for d in shown[:FEEDBACK_LIMIT] {
        code = f"{d.code} " if d.code else "";
        lines.append(
            f"- {_rel(d.file, self.root_dir)}:{d.line}:{d.col} {d.severity} {code}{d.message}"
        );
        if d.help and d.severity == "error" {
            lines.append(f"  help: {d.help}");
        }
    }
    if len(shown) > FEEDBACK_LIMIT {
        lines.append(f"- ... and {len(shown) - FEEDBACK_LIMIT} more");
    }
    arch = [
        a
        for a in self.arch_changes
        if a.kind in ARCH_CODES.values()
    ];
    if arch {
        lines.append("Architecture problems:");
        for a in arch {
            lines.append(f"- {a.kind}: {a.detail}");
        }
    }
    others = [
        a
        for a in self.arch_changes
        if a.kind not in ARCH_CODES.values()
    ];
    if others {
        lines.append("Architecture changes in this write:");
        for a in others {
            lines.append(f"- {a.kind}: {a.detail}");
        }
    }
    return "\n".join(lines);
}

impl EditReview.to_dict -> dict[str, any] {
    return {
        "path": self.path,
        "diff": self.diff,
        "checked": self.checked,
        "check_error": self.check_error,
        "clean": self.clean(),
        "summary": self.summary(),
        "elapsed": round(self.elapsed, 3),
        "checked_files": self.checked_files,
        "remaining_errors": self.remaining_errors,
        "symbol_changes": [s.to_dict() for s in self.symbol_changes],
        "new_diagnostics": [d.to_dict() for d in self.new_diagnostics],
        "resolved_diagnostics": [d.to_dict() for d in self.resolved_diagnostics],
        "arch_changes": [a.to_dict() for a in self.arch_changes]
    };
}

impl OverlayHost.read_source(path: str) -> str {
    if self.enabled and self.overlay {
        real = os.path.realpath(path);
        if real in self.overlay {
            return self.overlay[real];
        }
    }
    return super.read_source(path);
}

impl OverlayHost.annex_files(path: str, suffix: str = ".impl.jac") -> list[str] {
    found = super.annex_files(path, suffix);
    if not self.enabled or not self.overlay {
        return found;
    }
    have = {os.path.realpath(f) for f in found};
    for staged in self.overlay {
        if staged in have or not staged.endswith(suffix) or os.path.exists(staged) {
            continue;
        }
        try {
            if self.is_annex_path_of(staged, path) {
                found.append(staged);
            }
        } except Exception {}
    }
    return found;
}

impl OverlayHost.note(message: str, style: str = "dim") {
    if not self.log_path {
        return;
    }
    try {
        with open(self.log_path, "a") as fh {
            fh.write(message + "\n");
        }
    } except Exception {}
}

impl ThreadRouter.write(data: str) -> int {
    if threading.get_ident() == self.thread_id {
        try {
            self.sink.write(data);
        } except Exception {}
        return len(data);
    }
    return self.target.write(data);
}

impl ThreadRouter.flush {
    if threading.get_ident() == self.thread_id {
        try {
            self.sink.flush();
        } except Exception {}
        return;
    }
    self.target.flush();
}

impl ThreadRouter.isatty -> bool {
    if threading.get_ident() == self.thread_id {
        return False;
    }
    return self.target.isatty();
}

impl ThreadRouter.fileno -> int {
    return self.target.fileno();
}

impl ThreadRouter.__getattr__(name: str) -> any {
    if name in ["target", "sink", "thread_id"] or name.startswith("__") {
        raise AttributeError(name);
    }
    return getattr(self.target, name);
}

impl EditGate.postinit {
    self.root_dir = os.path.realpath(self.root_dir);
    log_dir = os.path.join(self.root_dir, ".jac", "studio", "logs");
    try {
        os.makedirs(log_dir, exist_ok=True);
        self.log_path = os.path.join(log_dir, "gate.log");
    } except OSError {
        self.log_path = "";
    }
}

impl EditGate.stage(path: str, new_text: str) -> None {
    self.overlay[os.path.realpath(path)] = new_text;
}

impl EditGate.unstage(path: str) -> None {
    self.overlay.pop(os.path.realpath(path), None);
}

impl EditGate.unstage_if(path: str, text: str) -> None {
    with _GATE_LOCK {
        real = os.path.realpath(path);
        if self.overlay.get(real) == text {
            self.overlay.pop(real, None);
        }
    }
}

impl EditGate.staged -> dict[str, str] {
    return dict(self.overlay);
}

impl EditGate.read(path: str) -> (str | None) {
    real = os.path.realpath(path);
    if real in self.overlay {
        return self.overlay[real];
    }
    return self._disk_text(real);
}

impl EditGate.commit(path: str) -> None {
    real = os.path.realpath(path);
    if real not in self.overlay {
        return;
    }
    text = self.overlay[real];
    parent = os.path.dirname(real);
    if parent {
        os.makedirs(parent, exist_ok=True);
    }
    with open(real, "w", encoding="utf-8") as fh {
        fh.write(text);
    }
    self.overlay.pop(real, None);
    if is_arch_file(real) {
        wiring_mod._spec_cache.clear();
    }
}

impl EditGate._disk_text(path: str) -> (str | None) {
    try {
        with open(path, encoding="utf-8") as fh {
            return fh.read();
        }
    } except (OSError, UnicodeDecodeError) {
        return None;
    }
}

impl EditGate._text_for(path: str, overlay: bool) -> str {
    real = os.path.realpath(path);
    if overlay and real in self.overlay {
        return self.overlay[real];
    }
    return self._disk_text(real) or "";
}

impl EditGate._stamp(paths: list[str]) -> tuple[tuple[str, int, int], ...] {
    out: list[tuple[str, int, int]] = [];
    for p in sorted(set(paths)) {
        try {
            st = os.stat(p);
            out.append((p, st.st_mtime_ns, st.st_size));
        } except OSError {
            out.append((p, -1, -1));
        }
    }
    return tuple(out);
}

impl EditGate._arch_staged -> bool {
    return any([is_arch_file(p) for p in self.overlay]);
}

impl EditGate._head_of(path: str) -> str {
    host = active_host();
    try {
        base = host.base_file(path);
        if base {
            return os.path.realpath(base);
        }
    } except Exception {}
    for staged in self.overlay {
        if staged == path or os.path.basename(staged).count(".") != 1 {
            continue;
        }
        try {
            if host.is_annex_path_of(path, staged) {
                return staged;
            }
        } except Exception {}
    }
    return path;
}

impl EditGate._module_files(head: str) -> list[str] {
    files = [head];
    try {
        host = active_host();
        for suffix in [".impl.jac", ".test.jac"] {
            for f in host.annex_files(head, suffix) {
                real = os.path.realpath(f);
                if real not in files {
                    files.append(real);
                }
            }
        }
    } except Exception {}
    for staged in self.overlay {
        if staged in files or not staged.endswith(".jac") {
            continue;
        }
        try {
            if active_host().is_annex_path_of(staged, head) {
                files.append(staged);
            }
        } except Exception {}
    }
    return files;
}

impl EditGate._owner(head: str) -> dict[str, str] {
    info: dict[str, str] = {"project_root": "", "target_app": "", "app_kind": ""};
    try {
        ws = active_host().workspace(head);
        if ws is not None {
            info["project_root"] = ws.project_root;
            app = ws.app_for_path(head);
            if app is None and not ws.explicit {
                app = next(iter(ws.apps.values()), None);
            }
            if app is not None {
                info["target_app"] = app.name;
                info["app_kind"] = app.kind;
            }
        }
    } except Exception {}
    if not info["project_root"] {
        info["project_root"] = self.root_dir;
    }
    return info;
}

impl EditGate._quiet_enter -> dict[str, any] {
    saved: dict[str, any] = {};
    sink: any = None;
    try {
        sink = open(self.log_path, "a", buffering=1)
            if self.log_path
            else open(os.devnull, "w");
    } except OSError {
        sink = open(os.devnull, "w");
    }
    saved["sink"] = sink;
    sink.write(f"--- gate check {time.strftime('%Y-%m-%d %H:%M:%S')}\n");
    tid = threading.get_ident();
    saved["stdout"] = sys.stdout;
    saved["stderr"] = sys.stderr;
    out_router = ThreadRouter(target=sys.stdout, sink=sink, thread_id=tid);
    err_router = ThreadRouter(target=sys.stderr, sink=sink, thread_id=tid);
    sys.stdout = out_router;
    sys.stderr = err_router;
    saved["out_router"] = out_router;
    saved["err_router"] = err_router;
    root_logger = logging.getLogger();
    saved["handlers"] = list(root_logger.handlers);
    saved["level"] = root_logger.level;
    handler = logging.StreamHandler(sink);
    root_logger.handlers = [handler];
    if root_logger.level == logging.NOTSET or root_logger.level < logging.WARNING {
        root_logger.setLevel(logging.WARNING);
    }
    saved["warnings"] = warnings.catch_warnings();
    saved["warnings"].__enter__();
    warnings.simplefilter("ignore");
    return saved;
}

impl EditGate._quiet_exit(saved: dict[str, any]) -> None {
    try {
        saved["warnings"].__exit__(None, None, None);
    } except Exception {}
    root_logger = logging.getLogger();
    root_logger.handlers = saved["handlers"];
    root_logger.setLevel(saved["level"]);
    if sys.stdout is saved["out_router"] {
        sys.stdout = saved["stdout"];
    }
    if sys.stderr is saved["err_router"] {
        sys.stderr = saved["stderr"];
    }
    try {
        saved["sink"].close();
    } except Exception {}
}

impl EditGate._check(target: str, overlay: bool) -> list[DiagInfo] {
    if self._host is None {
        self._host = OverlayHost();
    }
    host = self._host;
    host.log_path = self.log_path;
    host.overlay = self.overlay;
    host.enabled = overlay;
    owner = self._owner(target);
    module_files = set(self._module_files(target));
    arch = arch_file_for(target) if not is_arch_file(target) else target;
    previous = active_host();
    previous_mode = set_kernel_host_mode("");
    arch_staged = self._arch_staged();
    if arch_staged {
        wiring_mod._spec_cache.clear();
    }
    install_host(host);
    prog = JacProgram();
    try {
        prog.deps.tracking = True;
        prog.iface_registry().verifying = True;
        opts = CompileOptions(
            no_cgen=True,
            project_root=owner["project_root"] or None,
            target_app=owner["target_app"],
            app_kind=owner["app_kind"]
        );
        opts.entry_point = target;
        source = host.read_source(target)
            if (overlay or os.path.exists(target))
            else "";
        prog.compile(target, use_str=source, options=opts);
    } finally {
        install_host(previous);
        set_kernel_host_mode(previous_mode);
        if arch_staged {
            wiring_mod._spec_cache.clear();
        }
    }
    out: list[DiagInfo] = [];
    seen: set[tuple[str, int, int, str, str, str]] = set();
    texts: dict[str, list[str]] = {};
    for (severity, alerts) in [
        ("error", prog.errors_had),
        ("warning", prog.warnings_had)
    ] {
        for a in alerts {
            loc = a.loc;
            if loc is None or not loc.mod_path {
                continue;
            }
            fpath = os.path.realpath(loc.mod_path);
            if fpath not in module_files and fpath != arch {
                continue;
            }
            code = a.code.code if a.code is not None else "";
            key = (fpath, loc.first_line, loc.col_start, code, a.msg, severity);
            if key in seen {
                continue;
            }
            seen.add(key);
            if fpath not in texts {
                texts[fpath] = self._text_for(fpath, overlay).splitlines();
            }
            src_lines = texts[fpath];
            anchor = src_lines[loc.first_line - 1].strip()
                if 0 < loc.first_line <= len(src_lines)
                else "";
            out.append(
                DiagInfo(
                    file=fpath,
                    line=loc.first_line,
                    col=loc.col_start,
                    severity=severity,
                    code=code,
                    message=a.msg,
                    help=a.help_text or "",
                    anchor=anchor
                )
            );
        }
    }
    return out;
}

impl EditGate._baseline(target: str) -> list[DiagInfo] {
    files = self._module_files(target);
    arch = arch_file_for(target);
    if arch {
        files.append(arch);
    }
    stamp = self._stamp(files + list(self.overlay.keys()));
    cached = self._baselines.get(target);
    if cached is not None and cached[0] == stamp {
        return cached[1];
    }
    if not os.path.exists(target) {
        result: list[DiagInfo] = [];
    } else {
        result = self._check(target, False);
    }
    self._baselines[target] = (stamp, result);
    return result;
}

impl EditGate._scan_importers(head: str) -> list[str] {
    rel = os.path.relpath(head, self.root_dir);
    if rel.startswith("..") {
        return [];
    }
    stem = rel[:-4] if rel.endswith(".jac") else rel;
    dotted = stem.replace(os.sep, ".");
    last = dotted.split(".")[-1];
    found: list[str] = [];
    for (dirpath, dirnames, filenames) in os.walk(self.root_dir) {
        dirnames[:] = [
            d
            for d in dirnames
            if d not in GATE_SKIP_DIRS and not d.startswith(".")
        ];
        for fname in filenames {
            if not fname.endswith(".jac") or fname.count(".") > 1 {
                continue;
            }
            fpath = os.path.realpath(os.path.join(dirpath, fname));
            if fpath == head {
                continue;
            }
            text = self._disk_text(fpath) or "";
            if last not in text {
                continue;
            }
            for line in text.splitlines() {
                s = line.strip();
                if s.startswith("import")
                    and (dotted in s or f".{last}" in s or f" {last}" in s) {
                    found.append(fpath);
                    break;
                }
            }
        }
    }
    return found;
}

impl EditGate._dependents(head: str, review: EditReview) -> list[str] {
    public = [
        s
        for s in review.symbol_changes
        if s.public
    ];
    if not public {
        return [];
    }
    names = {s.key.split(".")[0] for s in public};
    out: list[str] = [];
    spec: (WiringSpec | None) = None;
    try {
        spec = wiring_for_path(head);
    } except Exception {
        spec = None;
    }
    if spec is not None and spec.owns(head) {
        for w in spec.wires {
            split = spec.split_consumer(w.provider);
            if split is None {
                continue;
            }
            pfile = spec.module_file(split[0]);
            if pfile is None or os.path.realpath(pfile) != head {
                continue;
            }
            carried = set([it[0] for it in w.items]);
            if split[1] {
                carried.add(split[1][0]);
            }
            if carried and not (carried & names) {
                continue;
            }
            for consumer in w.consumers {
                csplit = spec.split_consumer(consumer);
                if csplit is None {
                    continue;
                }
                cfile = spec.module_file(csplit[0]);
                if cfile is None {
                    continue;
                }
                creal = os.path.realpath(cfile);
                if creal != head and creal not in out {
                    out.append(creal);
                }
            }
        }
    } else {
        for f in self._scan_importers(head) {
            if f not in out {
                out.append(f);
            }
        }
    }
    return out[:self.max_dependents];
}

impl EditGate._targets(real: str, review: EditReview) -> list[str] {
    if is_arch_file(real) {
        targets: list[str] = [real];
        spec: (WiringSpec | None) = None;
        try {
            spec = wiring_for_path(real);
        } except Exception {
            spec = None;
        }
        if spec is not None {
            for ch in review.arch_changes {
                if ch.kind not in ["new wire", "removed wire", "changed wire"] {
                    continue;
                }
                csplit = spec.split_consumer(ch.module) if ch.module else None;
                if csplit is None {
                    continue;
                }
                cfile = spec.module_file(csplit[0]);
                if cfile is not None {
                    creal = os.path.realpath(cfile);
                    if creal not in targets {
                        targets.append(creal);
                    }
                }
            }
        }
        return targets[:self.max_dependents + 1];
    }
    head = self._head_of(real);
    targets = [head];
    for dep in self._dependents(head, review) {
        if dep not in targets {
            targets.append(dep);
        }
    }
    return targets;
}

impl EditGate.review(path: str, new_text: str, cancelled: any = None) -> EditReview {
    started = time.perf_counter();
    real = os.path.realpath(path);
    with _GATE_LOCK, COMPILE_LOCK {
        if cancelled is not None and cancelled() {
            return EditReview(
                path=real,
                old_text="",
                new_text=new_text,
                root_dir=self.root_dir,
                check_error="cancelled: the edit was decided before its check ran"
            );
        }
        old_text = self._disk_text(real);
        self.stage(real, new_text);
        rel = _rel(real, self.root_dir);
        rv = EditReview(
            path=real,
            old_text=old_text or "",
            new_text=new_text,
            root_dir=self.root_dir,
            seen_staged=sorted(
                [
                    p
                    for p in self.overlay
                    if p != real
                ]
            )
        );
        rv.diff = "".join(
            difflib.unified_diff(
                (old_text or "").splitlines(keepends=True),
                new_text.splitlines(keepends=True),
                fromfile=f"a/{rel}" if old_text is not None else "/dev/null",
                tofile=f"b/{rel}"
            )
        );
        saved = self._quiet_enter();
        try {
            if is_arch_file(real) {
                rv.arch_changes = wiring_changes(old_text or "", new_text, real);
            } else {
                rv.symbol_changes = symbol_changes(old_text or "", new_text, real);
                old_imports = import_lines(old_text or "", real);
                new_imports = import_lines(new_text, real);
                for imp in new_imports {
                    if imp not in old_imports {
                        rv.arch_changes.append(
                            ArchChange(kind="new import", detail=imp)
                        );
                    }
                }
                for imp in old_imports {
                    if imp not in new_imports {
                        rv.arch_changes.append(
                            ArchChange(kind="removed import", detail=imp)
                        );
                    }
                }
            }
            before: list[DiagInfo] = [];
            after: list[DiagInfo] = [];
            for target in self._targets(real, rv) {
                rv.checked_files.append(target);
                before.extend(self._baseline(target));
                after.extend(self._check(target, True));
            }
            (added, resolved) = match_diagnostics(before, after);
            rv.new_diagnostics = added;
            rv.resolved_diagnostics = resolved;
            rv.remaining_errors = len(
                [
                    d
                    for d in after
                    if d.severity == "error"
                ]
            );
            for d in added {
                if d.code in ARCH_CODES {
                    rv.arch_changes.append(
                        ArchChange(
                            kind=ARCH_CODES[d.code],
                            detail=f"{d.code} {_rel(d.file, self.root_dir)}:{d.line}: {d.message}"
                        )
                    );
                }
            }
            rv.checked = True;
        } except Exception as e {
            rv.checked = False;
            rv.check_error = f"{type(e).__name__}: {e}";
            try {
                import traceback;
                saved["sink"].write(traceback.format_exc());
            } except Exception {}
        } finally {
            self._quiet_exit(saved);
        }
        rv.elapsed = time.perf_counter() - started;
        return rv;
    }
}

impl gate_root_for(path: str) -> str {
    real = os.path.realpath(path);
    cur = real if os.path.isdir(real) else os.path.dirname(real);
    while True {
        if os.path.isfile(os.path.join(cur, "jac.toml")) {
            return cur;
        }
        parent = os.path.dirname(cur);
        if parent == cur {
            return os.path.dirname(real);
        }
        cur = parent;
    }
}

impl _node_text(nd: any) -> str {
    if nd is None {
        return "";
    }
    try {
        return " ".join(unparse_node(nd).split());
    } except Exception {
        return "";
    }
}

impl _lines_text(lines: list[str], first: int, last: int) -> str {
    return "\n".join([ln.rstrip() for ln in lines[max(first - 1, 0):max(last, 0)]]);
}

impl _rel(path: str, root_dir: str) -> str {
    if not root_dir {
        return path;
    }
    try {
        rel = os.path.relpath(path, root_dir);
    } except ValueError {
        return path;
    }
    return path if rel.startswith("..") else rel;
}

impl symbol_table(text: str, path: str) -> dict[str, tuple[str, int, int, str, str]] {
    table: dict[str, tuple[str, int, int, str, str]] = {};
    if not text.strip() {
        return table;
    }
    (module, had_error) = parse_woven(text, path, None, [], load_kernel=False);
    if module is None {
        return table;
    }
    lines = text.splitlines();
    def put(key: str, kind: str, nd: any, sig: str) {
        first = nd.loc.first_line;
        last = nd.loc.last_line;
        k = key;
        n = 2;
        while k in table {
            k = f"{key}#{n}";
            n += 1;
        }
        table[k] = (kind, first, last, _lines_text(lines, first, last), sig);
    }
    for el in module.body {
        if isinstance(el, uni.Archetype) {
            name = el.name.sym_name;
            kind = el.arch_type.value;
            member_spans: list[tuple[int, int]] = [];
            fields: list[str] = [];
            for hv in el.get_has_vars() {
                fname = hv.name.sym_name;
                ftype = _node_text(hv.type_tag.tag if hv.type_tag else None);
                fields.append(f"{fname}: {ftype}");
                put(f"{name}.{fname}", "has", hv, ftype);
            }
            for ab in el.get_methods() {
                if ab.name_ref is None {
                    continue;
                }
                member_spans.append((ab.loc.first_line, ab.loc.last_line));
                put(
                    f"{name}.{ab.name_ref.sym_name}",
                    "method",
                    ab,
                    _node_text(ab.signature)
                );
            }
            own_lines: list[str] = [];
            for i in range(el.loc.first_line, el.loc.last_line + 1) {
                if any([a <= i <= b for (a, b) in member_spans]) {
                    continue;
                }
                if 0 < i <= len(lines) {
                    own_lines.append(lines[i - 1].rstrip());
                }
            }
            bases = ", ".join([_node_text(b) for b in (el.base_classes or [])]);
            k = name;
            table[k] = (
                kind,
                el.loc.first_line,
                el.loc.last_line,
                "\n".join(own_lines),
                f"{kind}({bases}) " + "; ".join(fields)
            );
        } elif isinstance(el, uni.Enum) {
            name = el.name.sym_name;
            put(
                name,
                "enum",
                el,
                _lines_text(lines, el.loc.first_line, el.loc.last_line)
            );
        } elif isinstance(el, uni.Ability) {
            if el.name_ref is None {
                continue;
            }
            put(el.name_ref.sym_name, "def", el, _node_text(el.signature));
        } elif isinstance(el, uni.GlobalVars) {
            for asg in el.assignments {
                tgt = ", ".join([_node_text(t) for t in asg.target]);
                if not tgt {
                    continue;
                }
                tname = tgt.split(":")[0].strip();
                put(
                    tname,
                    "glob",
                    asg,
                    _node_text(asg.type_tag) if asg.type_tag else tgt
                );
            }
        } elif isinstance(el, uni.Test) {
            put(f"test {_node_text(el.name)}", "test", el, "");
        }
    }
    for idef in module.get_all_sub_nodes(uni.ImplDef) {
        parts = [t.sym_name for t in idef.target];
        if not parts {
            continue;
        }
        put("impl " + ".".join(parts), "impl", idef, "");
    }
    return table;
}

impl symbol_changes(old_text: str, new_text: str, path: str) -> list[SymbolChange] {
    old_tab = symbol_table(old_text, path);
    new_tab = symbol_table(new_text, path);
    out: list[SymbolChange] = [];
    for (key, nv) in new_tab.items() {
        ov = old_tab.get(key);
        public = nv[0] not in ["impl", "test"]
            and not key.split(".")[-1].startswith("_");
        if ov is None {
            out.append(
                SymbolChange(
                    key=key,
                    kind=nv[0],
                    change="added",
                    new_lines=(nv[1], nv[2]),
                    public=public
                )
            );
        } elif ov[3] != nv[3] {
            out.append(
                SymbolChange(
                    key=key,
                    kind=nv[0],
                    change="changed",
                    old_lines=(ov[1], ov[2]),
                    new_lines=(nv[1], nv[2]),
                    public=public and ov[4] != nv[4]
                )
            );
        }
    }
    for (key, ov) in old_tab.items() {
        if key not in new_tab {
            out.append(
                SymbolChange(
                    key=key,
                    kind=ov[0],
                    change="removed",
                    old_lines=(ov[1], ov[2]),
                    public=ov[0] not in ["impl", "test"]
                )
            );
        }
    }
    return out;
}

impl import_lines(text: str, path: str) -> list[str] {
    out: list[str] = [];
    if not text.strip() {
        return out;
    }
    try {
        (module, had_error) = parse_woven(text, path, None, [], load_kernel=False);
    } except Exception {
        return out;
    }
    if module is None {
        return out;
    }
    lines = text.splitlines();
    for imp in module.get_all_sub_nodes(uni.Import) {
        t = " ".join(_lines_text(lines, imp.loc.first_line, imp.loc.last_line).split());
        if t and t not in out {
            out.append(t);
        }
    }
    return out;
}

impl wiring_changes(old_text: str, new_text: str, path: str) -> list[ArchChange] {
    out: list[ArchChange] = [];
    old_rec = parse_records(old_text, path) if old_text.strip() else (False, [], []);
    new_rec = parse_records(new_text, path);
    if new_rec[0] {
        out.append(
            ArchChange(
                kind="archwire syntax error",
                detail="the new archwire.jac does not parse; its wiring is incomplete"
            )
        );
    }
    def facts(recs: list[WireRec]) -> dict[tuple[str, ...], str] {
        found: dict[tuple[str, ...], str] = {};
        for (consumer, binding) in wiring_facts(recs) {
            arrow = "++>" if binding.injected else "-->";
            head = " ".join(
                [
                    w
                    for w in binding.form.split(" ")
                    if w in ("comptime", "include", "type")
                ]
                    + [binding.provider]
            );
            if binding.is_module_form() {
                alias = f" as {binding.alias}" if binding.alias else "";
                text = f"{head}{alias} {arrow} {consumer}";
            } else {
                item = binding.name + (f" as {binding.alias}" if binding.alias else "");
                text = f"{head} {arrow} {consumer} {{ {item} }}";
            }
            found[(consumer, ) + binding.key()] = text;
        }
        return found;
    }
    old_facts = facts(old_rec[1]);
    new_facts = facts(new_rec[1]);
    for (k, text) in new_facts.items() {
        if k not in old_facts {
            out.append(ArchChange(kind="new wire", detail=text, module=k[0]));
        }
    }
    for (k, text) in old_facts.items() {
        if k not in new_facts {
            out.append(ArchChange(kind="removed wire", detail=text, module=k[0]));
        }
    }
    old_rules = {r.name: rule_text(r) for r in old_rec[2]};
    new_rules = {r.name: rule_text(r) for r in new_rec[2]};
    for (name, text) in new_rules.items() {
        if name not in old_rules {
            out.append(ArchChange(kind="new rule", detail=text));
        } elif old_rules[name] != text {
            out.append(
                ArchChange(kind="changed rule", detail=f"{old_rules[name]}  =>  {text}")
            );
        }
    }
    for (name, text) in old_rules.items() {
        if name not in new_rules {
            out.append(ArchChange(kind="removed rule", detail=text));
        }
    }
    return out;
}

impl match_diagnostics(
    before: list[DiagInfo], after: list[DiagInfo]
) -> tuple[list[DiagInfo], list[DiagInfo]] {
    def exact(d: DiagInfo) -> tuple[str, ...] {
        return (d.file, d.severity, d.code, d.message, d.anchor);
    }
    def loose(d: DiagInfo) -> tuple[str, ...] {
        return (d.file, d.severity, d.code, d.message);
    }
    pool_before = list(before);
    pending: list[DiagInfo] = [];
    for d in after {
        k = exact(d);
        hit = -1;
        for (i, b) in enumerate(pool_before) {
            if exact(b) == k {
                hit = i;
                break;
            }
        }
        if hit >= 0 {
            pool_before.pop(hit);
        } else {
            pending.append(d);
        }
    }
    added: list[DiagInfo] = [];
    for d in pending {
        k = loose(d);
        hit = -1;
        for (i, b) in enumerate(pool_before) {
            if loose(b) == k {
                hit = i;
                break;
            }
        }
        if hit >= 0 {
            pool_before.pop(hit);
        } else {
            added.append(d);
        }
    }
    return (added, pool_before);
}

impl format_review(rv: EditReview) -> str {
    lines: list[str] = [];
    lines.append(f"review of {_rel(rv.path, rv.root_dir)}");
    lines.append(f"  {rv.summary()}");
    lines.append(
        f"  checked: {rv.checked}  clean: {rv.clean()}  elapsed: {rv.elapsed:.2f}s  remaining errors: {rv.remaining_errors}"
    );
    if rv.check_error {
        lines.append(f"  check error: {rv.check_error}");
    }
    if rv.checked_files {
        lines.append(
            "  checked modules: "
                + ", ".join([_rel(f, rv.root_dir) for f in rv.checked_files])
        );
    }
    lines.append("");
    lines.append("diff:");
    lines.append(rv.diff.rstrip() if rv.diff else "  (no textual change)");
    lines.append("");
    lines.append(f"symbol changes ({len(rv.symbol_changes)}):");
    for s in rv.symbol_changes {
        span = "";
        if s.old_lines and s.new_lines {
            span = f"lines {s.old_lines[0]}-{s.old_lines[1]} -> {s.new_lines[0]}-{s.new_lines[
                1
            ]}";
        } elif s.new_lines {
            span = f"lines {s.new_lines[0]}-{s.new_lines[1]}";
        } elif s.old_lines {
            span = f"was lines {s.old_lines[0]}-{s.old_lines[1]}";
        }
        pub_tag = " (public)" if s.public else "";
        lines.append(f"  {s.change:8} {s.kind:7} {s.key}  {span}{pub_tag}");
    }
    lines.append(f"new diagnostics ({len(rv.new_diagnostics)}):");
    for d in rv.new_diagnostics {
        lines.append("  " + d.short(rv.root_dir));
        if d.help {
            lines.append(f"      help: {d.help}");
        }
    }
    lines.append(f"resolved diagnostics ({len(rv.resolved_diagnostics)}):");
    for d in rv.resolved_diagnostics {
        lines.append("  " + d.short(rv.root_dir));
    }
    lines.append(f"architecture changes ({len(rv.arch_changes)}):");
    for a in rv.arch_changes {
        lines.append(f"  {a.kind}: {a.detail}");
    }
    if not rv.clean() {
        lines.append("");
        lines.append("feedback for the agent:");
        for ln in rv.feedback().splitlines() {
            lines.append("  " + ln);
        }
    }
    return "\n".join(lines);
}

impl leaf_changes(changes: list[SymbolChange]) -> list[SymbolChange] {
    def span(sc: SymbolChange) -> tuple[str, int, int] {
        if sc.change == "removed" and sc.old_lines {
            return ("old", sc.old_lines[0], sc.old_lines[1]);
        }
        if sc.new_lines {
            return ("new", sc.new_lines[0], sc.new_lines[1]);
        }
        return ("none", 0, -1);
    }
    out: list[SymbolChange] = [];
    for sc in changes {
        (side, a, b) = span(sc);
        if side == "none" {
            continue;
        }
        container = False;
        for other in changes {
            if other is sc {
                continue;
            }
            (os_, c, d) = span(other);
            if os_ == side and a <= c and d <= b and (c, d) != (a, b) {
                container = True;
                break;
            }
        }
        if not container {
            out.append(sc);
        }
    }
    return out;
}

impl change_groups(changes: list[SymbolChange]) -> dict[str, list[str]] {
    leaves = leaf_changes(changes);
    parent = list(range(len(leaves)));
    def find(i: int) -> int {
        while parent[i] != i {
            parent[i] = parent[parent[i]];
            i = parent[i];
        }
        return i;
    }
    def overlap(x: (tuple[int, int] | None), y: (tuple[int, int] | None)) -> bool {
        return x is not None and y is not None and x[0] <= y[1] and y[0] <= x[1];
    }
    for i in range(len(leaves)) {
        for j in range(i + 1, len(leaves)) {
            (a, b) = (leaves[i], leaves[j]);
            if overlap(a.new_lines, b.new_lines) or overlap(a.old_lines, b.old_lines) {
                parent[find(i)] = find(j);
            }
        }
    }
    members: dict[int, list[str]] = {};
    for i in range(len(leaves)) {
        members.setdefault(find(i), []).append(leaves[i].key);
    }
    return {leaves[i].key: members[find(i)] for i in range(len(leaves))};
}

impl partial_text(
    old_text: str, new_text: str, changes: list[SymbolChange], keep: set[str]
) -> str {
    old = old_text.split("\n");
    new = new_text.split("\n");
    ops = difflib.SequenceMatcher(None, old, new, autojunk=False).get_opcodes();
    def map_old(i0: int) -> int {
        for (tag, a1, a2, b1, b2) in ops {
            if a1 <= i0 < a2 {
                return b1 + (i0 - a1) if tag == "equal" else b1;
            }
        }
        return len(new);
    }
    groups = change_groups(changes);
    by_key = {sc.key: sc for sc in leaf_changes(changes)};
    done: set[str] = set();
    edits: list[tuple[int, int, list[str]]] = [];
    for (key, group) in groups.items() {
        if key in done {
            continue;
        }
        done.update(group);
        if any([k in keep for k in group]) {
            continue;
        }
        members = [by_key[k] for k in group];
        new_spans = [
            sc.new_lines
            for sc in members
            if sc.change in ["added", "changed"] and sc.new_lines
        ];
        old_spans = [
            sc.old_lines
            for sc in members
            if sc.change in ["changed", "removed"] and sc.old_lines
        ];
        old_part: list[str] = [];
        if old_spans {
            c = min([sp_[0] for sp_ in old_spans]);
            d = max([sp_[1] for sp_ in old_spans]);
            old_part = old[c - 1:d];
        }
        if new_spans {
            a = min([sp_[0] for sp_ in new_spans]);
            b = max([sp_[1] for sp_ in new_spans]);
            edits.append((a - 1, b, old_part));
        } elif old_spans {
            at = map_old(min([sp_[0] for sp_ in old_spans]) - 1);
            edits.append((at, at, old_part));
        }
    }
    edits.sort(
        key=lambda (e: tuple[int, int, list[str]]) -> tuple[int, int] { (e[0], e[1]) },
        reverse=True
    );
    for (a, b, rep) in edits {
        if not rep
            and a > 0
            and not new[a - 1].strip()
            and (b >= len(new) or new[b].strip() in ["", "}"]) {
            a -= 1;
        }
        new[a:b] = rep;
    }
    return "\n".join(new);
}
