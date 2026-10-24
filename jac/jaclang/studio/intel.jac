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

impl StdioRouter.postinit -> None {
    self.lock = threading.Lock();
}

impl CodeIntel.postinit -> None {
    self._lock = threading.Lock();
    self._cv = threading.Condition();
    self._queries = deque();
}

impl StdioRouter.sink_for_current -> any {
    ident = threading.get_ident();
    sink = self.threads.get(ident);
    if sink is not None {
        return sink;
    }
    if self.capturing and threading.current_thread() is not threading.main_thread() {
        return self.capturing[-1];
    }
    return None;
}

impl StdioRouter.install(sink: any) -> None {
    with self.lock {
        self.refs += 1;
        if self.refs > 1 {
            return;
        }
        self.saved_out = sys.stdout;
        self.saved_err = sys.stderr;
        sys.stdout = RoutedStream(orig=sys.stdout, router=self);
        sys.stderr = RoutedStream(orig=sys.stderr, router=self);
        handler = logging.StreamHandler(sink);
        handler.setFormatter(
            logging.Formatter("%(asctime)s %(levelname)s %(name)s: %(message)s")
        );
        self.log_handler = handler;
        self.saved_handlers = [];
        loggers: list[any] = [logging.getLogger()];
        for (name, lg) in list(logging.root.manager.loggerDict.items()) {
            if name.startswith("jaclang") and isinstance(lg, logging.Logger) {
                loggers.append(lg);
            }
        }
        for lg in loggers {
            streams = [
                h
                for h in lg.handlers
                if isinstance(h, logging.StreamHandler)
                    and not isinstance(h, logging.FileHandler)
            ];
            if not streams and lg is not logging.getLogger() {
                continue;
            }
            self.saved_handlers.append((lg, list(lg.handlers)));
            lg.handlers = [
                h
                for h in lg.handlers
                if h not in streams
            ]
                + [handler];
        }
    }
}

impl StdioRouter.uninstall -> None {
    with self.lock {
        if self.refs <= 0 {
            return;
        }
        self.refs -= 1;
        if self.refs > 0 {
            return;
        }
        if isinstance(sys.stdout, RoutedStream) and sys.stdout.router is self {
            sys.stdout = self.saved_out;
        }
        if isinstance(sys.stderr, RoutedStream) and sys.stderr.router is self {
            sys.stderr = self.saved_err;
        }
        for (lg, handlers) in self.saved_handlers {
            lg.handlers = handlers;
        }
        self.saved_handlers = [];
        self.log_handler = None;
    }
}

impl RoutedStream.write(s: str) -> int {
    sink = self.router.sink_for_current();
    if sink is None {
        return self.orig.write(s);
    }
    try {
        sink.write(s);
    } except Exception {}
    return len(s);
}

impl RoutedStream.writelines(lines: list[str]) -> None {
    for ln in lines {
        self.write(ln);
    }
}

impl RoutedStream.flush -> None {
    sink = self.router.sink_for_current();
    if sink is None {
        self.orig.flush();
        return;
    }
    try {
        sink.flush();
    } except Exception {}
}

impl RoutedStream.isatty -> bool {
    if self.router.sink_for_current() is not None {
        return False;
    }
    return self.orig.isatty();
}

impl RoutedStream.fileno -> int {
    return self.orig.fileno();
}

impl RoutedStream.__getattr__(name: str) -> any {
    if name in ["orig", "router"] or name.startswith("__") {
        raise AttributeError(name);
    }
    return getattr(self.orig, name);
}

impl lex_spans(text: str, path: str = "<input>") -> list[list[Span]] {
    lines = text.split("\n");
    out: list[list[Span]] = [[] for _ in lines];
    nlines = len(lines);
    def put(line: int, col: int, end_line: int, end_col: int, style: str) {
        if line < 1 or line > nlines {
            return;
        }
        if end_line <= line {
            if end_col > col {
                out[line - 1].append(Span(start=col, end=end_col, style=style));
            }
            return;
        }
        first = lines[line - 1].rstrip("\r");
        if len(first) > col {
            out[line - 1].append(Span(start=col, end=len(first), style=style));
        }
        ln = line + 1;
        while ln < end_line and ln <= nlines {
            mid = lines[ln - 1].rstrip("\r");
            if mid {
                out[ln - 1].append(Span(start=0, end=len(mid), style=style));
            }
            ln += 1;
        }
        if end_line <= nlines and end_col > 0 {
            out[end_line - 1].append(Span(start=0, end=end_col, style=style));
        }
    }
    try {
        (tokens, comments, _diags, _errs) = tokenize_full(text, path);
    } except Exception {
        return out;
    }
    prev_kind = "";
    prev_line = 0;
    prev_value = "";
    prev_end = (0, 0);
    in_decorator = False;
    for tok in tokens {
        kind = tok.kind.name;
        if kind in ["WS", "EOF", "COMMENT"] {
            continue;
        }
        loc = tok.loc;
        style = "operator";
        if kind.startswith("KW_") {
            style = "builtin" if tok.value in SPECIAL_WORDS else "keyword";
        } elif kind.startswith("TYP_") {
            style = "builtin_type";
        } elif kind in NUMBER_KINDS {
            style = "number";
        } elif kind == "STRING" {
            v = tok.value.lstrip("rbuRBU");
            style = "docstring"
                if (v.startswith('"""') or v.startswith("'''")) and loc.line > prev_line
                else "string";
        } elif kind.startswith("F_")
            or kind.startswith("RF_")
            or kind in ["D_LBRACE", "D_RBRACE"] {
            style = "string";
        } elif kind in ["BOOL", "NULL", "ELLIPSIS"] {
            style = "constant";
        } elif kind in ["NAME", "KWESC_NAME"] {
            if in_decorator {
                style = "decorator";
            } elif prev_kind in FUNC_KWS {
                style = "function";
            } elif prev_kind in CLASS_KWS {
                style = "class";
            } else {
                style = "name";
            }
        } elif kind == "DECOR_OP" {
            style = "decorator";
        } elif kind in PUNCT_KINDS {
            style = "punct";
        } elif kind == "PYNLINE" {
            style = "embedded";
        } elif kind == "JSX_NAME" {
            style = "tag";
        } elif kind == "JSX_TEXT" {
            style = "text";
        } elif kind == "JSX_COMMENT" {
            style = "comment";
        } elif kind.startswith("JSX_")
            or kind in ["JSX_SELF_CLOSE", "JSX_CLOSE_START"] {
            style = "punct";
        } elif kind == "ERROR" {
            style = "error";
        }
        if kind == "DECOR_OP" {
            in_decorator = True;
        } elif in_decorator and kind not in ["NAME", "KWESC_NAME", "DOT"] {
            in_decorator = False;
        }
        if in_decorator and kind == "DOT" {
            style = "decorator";
        }
        if style == "string"
            and prev_kind == "NAME"
            and prev_value.lower() in STRING_PREFIXES
            and prev_end == (loc.line, loc.col_start)
            and out[loc.line - 1] {
            out[loc.line - 1][-1].style = "string";
        }
        put(loc.line, loc.col_start - 1, loc.end_line, loc.col_end - 1, style);
        prev_kind = kind;
        prev_value = tok.value;
        prev_end = (loc.end_line, loc.col_end);
        prev_line = loc.end_line;
    }
    for c in comments {
        put(c.line, c.col_start - 1, c.end_line, c.col_end - 1, "comment");
    }
    for row in out {
        row.sort(key=lambda (s: Span) { s.start; });
    }
    return out;
}

impl overlay_spans(base: list[Span], top: list[Span]) -> list[Span] {
    if not top {
        return base;
    }
    out: list[Span] = [];
    j = 0;
    for b in base {
        if b.style not in OVERRIDABLE {
            out.append(b);
            continue;
        }
        while j < len(top) and top[j].end <= b.start {
            j += 1;
        }
        cursor = b.start;
        k = j;
        while k < len(top) and top[k].start < b.end {
            t = top[k];
            s = max(t.start, cursor);
            e = min(t.end, b.end);
            if e > s {
                if s > cursor {
                    out.append(Span(start=cursor, end=s, style=b.style));
                }
                out.append(Span(start=s, end=e, style=t.style));
                cursor = e;
            }
            k += 1;
        }
        if cursor < b.end {
            out.append(Span(start=cursor, end=b.end, style=b.style));
        }
    }
    return out;
}

impl CodeIntel.start(root_dir: str) -> None {
    if self._started {
        return;
    }
    self.root_dir = os.path.realpath(root_dir or os.getcwd());
    self.log_path = os.path.join(self.root_dir, LOG_REL);
    try {
        os.makedirs(os.path.dirname(self.log_path), exist_ok=True);
        self._sink = open(self.log_path, "a", encoding="utf-8", buffering=1);
    } except OSError {
        self._sink = io.StringIO();
    }
    self._sink.write(
        f"--- intel start {time.strftime('%Y-%m-%d %H:%M:%S')} {self.root_dir}\n"
    );
    ROUTER.install(self._sink);
    self._stopping = False;
    self._started = True;
    self._worker = threading.Thread(
        target=self._run, name="jac-hack-intel", daemon=True
    );
    self._worker.start();
}

impl CodeIntel.stop(timeout: float = 5.0) -> None {
    if not self._started {
        return;
    }
    with self._cv {
        self._stopping = True;
        if self._cancel is not None {
            self._cancel.set();
        }
        self._cv.notify_all();
    }
    if self._worker is not None {
        self._worker.join(timeout);
    }
    self._started = False;
    ROUTER.uninstall();
    try {
        self._sink.flush();
        if self._sink is not None and self.log_path {
            self._sink.close();
        }
    } except Exception {}
}

impl CodeIntel.realpath(path: str) -> str {
    rp = self._real.get(path);
    if rp is None {
        rp = os.path.realpath(path);
        self._real[path] = rp;
    }
    return rp;
}

impl CodeIntel.head(path: str) -> str {
    rp = self.realpath(path);
    h = self._heads.get(rp);
    if h is None {
        h = rp;
        try {
            base = discover_base_file(rp);
            if base {
                h = os.path.realpath(base);
            }
        } except Exception {}
        self._heads[rp] = h;
    }
    return h;
}

impl CodeIntel._lexed(
    path: str, text: (str | None)
) -> tuple[any, list[str], list[list[Span]]] {
    rp = self.realpath(path);
    key: any = None;
    if text is None {
        try {
            st = os.stat(rp);
            key = ("disk", st.st_mtime_ns, st.st_size);
        } except OSError {
            return (("missing", ), [], []);
        }
    } else {
        key = ("text", hash(text));
    }
    hit = self._hl.get(rp);
    if hit is not None and hit[0] == key {
        return hit;
    }
    if text is None {
        try {
            with open(rp, "r", encoding="utf-8", errors="replace") as f {
                text = f.read();
            }
        } except OSError {
            return (("missing", ), [], []);
        }
    }
    src: str = text or "";
    lines = src.split("\n");
    spans = lex_spans(src, rp) if rp.endswith(".jac") else [[] for _ in lines];
    lexed = (key, lines, spans);
    self._hl[rp] = lexed;
    return lexed;
}

impl CodeIntel.highlight(path: str, text: (str | None) = None) -> list[list[Span]] {
    return self._lexed(path, text)[2];
}

impl CodeIntel.line_styles(path: str, text: (str | None) = None) -> list[list[Span]] {
    rp = self.realpath(path);
    (key, lines, base) = self._lexed(rp, text);
    with self._lock {
        sem_rows = self._sem.get(rp);
        sem_lines = self._sem_lines.get(rp, []);
        ver = self._sem_version.get(rp, 0);
    }
    if sem_rows is None {
        return base;
    }
    hit = self._merged.get(rp);
    if hit is not None and hit[0] == key and hit[1] == ver {
        return hit[2];
    }
    merged: list[list[Span]] = [];
    for (i, row) in enumerate(base) {
        if i < len(sem_rows)
            and sem_rows[i]
            and i < len(sem_lines)
            and sem_lines[i] == lines[i] {
            merged.append(overlay_spans(row, sem_rows[i]));
        } else {
            merged.append(row);
        }
    }
    self._merged[rp] = (key, ver, merged);
    return merged;
}

impl CodeIntel.request_check(path: str) -> None {
    h = self.head(path);
    with self._cv {
        self._open.add(h);
        if h not in self._checks and h != self._current {
            self._checks.append(h);
            with self._lock {
                self._status[h] = "queued";
            }
        }
        self._cv.notify_all();
    }
}

impl CodeIntel.semantic(path: str) -> (list[list[Span]] | None) {
    with self._lock {
        return self._sem.get(self.realpath(path));
    }
}

impl CodeIntel.diagnostics(path: str) -> list[Diag] {
    with self._lock {
        return list(self._diags.get(self.realpath(path), []));
    }
}

impl CodeIntel.inlays(path: str) -> dict[int, list[tuple[int, str]]] {
    with self._lock {
        return dict(self._inlays.get(self.realpath(path), {}));
    }
}

impl CodeIntel.status(path: str) -> str {
    with self._lock {
        return self._status.get(self.head(path), "idle");
    }
}

impl CodeIntel.check_secs(path: str) -> float {
    with self._lock {
        return self._check_secs.get(self.head(path), 0.0);
    }
}

impl CodeIntel._query(kind: str, path: str, line: int, col: int) -> int {
    with self._cv {
        ticket = self._next_ticket;
        self._next_ticket += 1;
        self._queries.append((ticket, kind, self.realpath(path), line, col));
        self._cv.notify_all();
    }
    return ticket;
}

impl CodeIntel.request_hover(path: str, line: int, col: int) -> int {
    return self._query("hover", path, line, col);
}

impl CodeIntel.request_definition(path: str, line: int, col: int) -> int {
    return self._query("definition", path, line, col);
}

impl CodeIntel.request_references(path: str, line: int, col: int) -> int {
    return self._query("references", path, line, col);
}

impl CodeIntel.poll -> list[tuple[int, any]] {
    with self._lock {
        done = self._results;
        self._results = [];
    }
    return done;
}

impl CodeIntel.symbol_at(path: str, line: int, col: int) -> (dict[str, any] | None) {
    with self._lock {
        idx = self._syms.get(self.realpath(path));
    }
    if not idx {
        return None;
    }
    for (start, end, info) in idx.get(line, []) {
        if start <= col < end {
            return dict(info);
        }
    }
    return None;
}

impl CodeIntel.invalidate(path: str) -> None {
    rp = self.realpath(path);
    self._hl.pop(rp, None);
    self._merged.pop(rp, None);
    h = self.head(rp);
    with self._cv {
        if rp not in self._invals {
            self._invals.append(rp);
        }
        if h in self._open {
            with self._lock {
                self._status[h] = "queued";
            }
        }
        if h == self._current and self._cancel is not None {
            self._cancel.set();
        }
        self._cv.notify_all();
    }
}

impl CodeIntel._run -> None {
    ROUTER.threads[threading.get_ident()] = self._sink;
    try {
        self._ensure_engine();
        while True {
            job: any = None;
            with self._cv {
                while not self._stopping
                    and not self._invals
                    and not self._queries
                    and not self._checks {
                    self._cv.`wait(1.0);
                }
                if self._stopping {
                    break;
                }
                if self._invals {
                    job = ("invalidate", self._invals.pop(0));
                } elif self._queries {
                    job = ("query", self._queries.popleft());
                } else {
                    job = ("check", self._checks.pop(0));
                    self._current = job[1];
                }
            }
            if job[0] == "invalidate" {
                self._do_invalidate(job[1]);
            } elif job[0] == "query" {
                (ticket, kind, qpath, qline, qcol) = job[1];
                self._do_query(ticket, kind, qpath, qline, qcol);
            } else {
                self._do_check(job[1]);
                with self._cv {
                    self._current = "";
                }
            }
        }
    } except Exception as e {
        self._sink.write(f"intel worker crashed: {e}\n");
    } finally {
        if self._ls is not None {
            import from jaclang.studio.intel_server { shutdown_server }
            ROUTER.capturing.append(self._sink);
            try {
                shutdown_server(self._ls);
            } finally {
                ROUTER.capturing.remove(self._sink);
            }
            self._ls = None;
        }
        ROUTER.threads.pop(threading.get_ident(), None);
    }
}

impl CodeIntel._ensure_engine -> bool {
    if self._ls is not None {
        return True;
    }
    if self._engine_error {
        return False;
    }
    ROUTER.capturing.append(self._sink);
    try {
        import from jaclang.studio.intel_server { new_server }
        self._ls = new_server(self.root_dir);
    } except Exception as e {
        self._engine_error = f"error: language engine failed to start: {e}";
        self._sink.write(self._engine_error + "\n");
    } finally {
        ROUTER.capturing.remove(self._sink);
    }
    return self._ls is not None;
}

impl CodeIntel._do_check(head: str) -> None {
    if not self._ensure_engine() {
        with self._lock {
            self._status[head] = self._engine_error;
        }
        return;
    }
    with self._lock {
        self._status[head] = "checking";
    }
    t0 = time.perf_counter();
    ROUTER.capturing.append(self._sink);
    try {
        import from jaclang.studio.intel_server { check_head, new_cancel_token }
        token = new_cancel_token();
        with self._cv {
            self._cancel = token;
            if self._stopping {
                token.set();
            }
        }
        with COMPILE_LOCK {
            out = check_head(self._ls, head, self.max_apps, token);
        }
    } except Exception as e {
        out = {"ok": False, "error": f"{type(e).__name__}: {e}", "files": {}};
    } finally {
        ROUTER.capturing.remove(self._sink);
        with self._cv {
            self._cancel = None;
        }
    }
    if out.get("cancelled") {
        with self._cv {
            requeued = head in self._checks
                or (head in self._open and not self._stopping);
        }
        with self._lock {
            self._status[head] = "queued" if requeued else "idle";
        }
        return;
    }
    self._store(head, out, time.perf_counter() - t0);
}

impl CodeIntel._store(head: str, out: dict[str, any], secs: float) -> None {
    staged:
        dict[
            str,
            tuple[
                list[list[Span]],
                list[str],
                list[Diag],
                dict[int, list[tuple[int, int, dict[str, any]]]]
            ]
        ] = {};
    hinted: dict[str, dict[int, list[tuple[int, str]]]] = {};
    for (f, data) in out["files"].items() {
        lines: list[str] = data["lines"];
        sem_rows: list[list[Span]] = [[] for _ in lines];
        for (ln, s, e, style) in data["sem"] {
            if 0 <= ln < len(sem_rows) {
                sem_rows[ln].append(Span(start=s, end=e, style=style));
            }
        }
        for row in sem_rows {
            row.sort(key=lambda (sp: Span) { sp.start; });
        }
        syms: dict[int, list[tuple[int, int, dict[str, any]]]] = {};
        for (ln, s, e, info) in data["syms"] {
            syms.setdefault(ln + 1, []).append((s, e, info));
        }
        diags = [
            Diag(
                line=d[4],
                col=d[5],
                end_line=d[6],
                end_col=d[7],
                severity=d[0],
                code=d[1],
                message=d[2],
                help=d[3]
            ) for d in data["diags"]
        ];
        diags.sort(key=lambda (dg: Diag) { (dg.line, dg.col); });
        staged[f] = (sem_rows, lines, diags, syms);
        hints: dict[int, list[tuple[int, str]]] = {};
        for (ln, col, label) in (data.get("inlays") or []) {
            hints.setdefault(ln + 1, []).append((col, label));
        }
        hinted[f] = hints;
    }
    with self._lock {
        for (f, (sem_rows, lines, diags, syms)) in staged.items() {
            if out["ok"] {
                self._inlays[f] = hinted.get(f, {});
                self._sem[f] = sem_rows;
                self._sem_lines[f] = lines;
                self._sem_version[f] = self._sem_version.get(f, 0) + 1;
                self._syms[f] = syms;
            }
            self._diags[f] = diags;
        }
        self._check_secs[head] = secs;
        if out["ok"] {
            self._status[head] = "ready";
        } else {
            self._status[head] = "error: " + (out["error"] or "type check failed");
        }
    }
}

impl CodeIntel._do_query(
    ticket: int, kind: str, path: str, line: int, col: int
) -> None {
    result: any = None;
    h = self.head(path);
    with self._lock {
        st = self._status.get(h, "idle");
    }
    if st != "ready" and not st.startswith("error") {
        with self._cv {
            if h in self._checks {
                self._checks.remove(h);
            }
            self._open.add(h);
        }
        self._do_check(h);
    }
    if self._ls is not None {
        ROUTER.capturing.append(self._sink);
        try {
            import from jaclang.studio.intel_server {
                hover_at,
                definition_at,
                references_at
            }
            if kind == "hover" {
                result = hover_at(self._ls, path, line, col);
            } elif kind == "definition" {
                result = definition_at(self._ls, path, line, col);
            } else {
                result = references_at(self._ls, path, line, col);
            }
        } except Exception as e {
            self._sink.write(f"intel {kind} failed: {e}\n");
            result = [] if kind == "references" else None;
        } finally {
            ROUTER.capturing.remove(self._sink);
        }
    } elif kind == "references" {
        result = [];
    }
    with self._lock {
        self._results.append((ticket, result));
    }
}

impl CodeIntel._do_invalidate(path: str) -> None {
    deps: list[str] = [];
    if self._ls is not None {
        import from jaclang.studio.intel_server { invalidate_path }
        deps = invalidate_path(self._ls, path);
    }
    h = self.head(path);
    with self._cv {
        for d in [h, *deps] {
            dh = self.head(d);
            if dh in self._open and dh not in self._checks {
                self._checks.append(dh);
                with self._lock {
                    self._status[dh] = "queued";
                }
            }
        }
    }
}
