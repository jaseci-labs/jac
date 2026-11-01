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
    if not self.path.endswith(".jac") {
        return f"{name}: not Jac source, so the compiler does not check it";
    }
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

impl EditGate.client -> SessionClient {
    if self._session is None {
        self._session = tool_session(self.root_dir);
    }
    return self._session;
}

impl EditGate._head_of(path: str) -> str {
    base = discover_base_file(path);
    if base {
        return os.path.realpath(base);
    }
    tables = host_layout_tables();
    for staged in self.overlay {
        if staged == path or os.path.basename(staged).count(".") != 1 {
            continue;
        }
        if is_annex_path_of(tables, path, staged) {
            return staged;
        }
    }
    return path;
}

impl EditGate._module_files(head: str) -> list[str] {
    files = [head];
    for suffix in [".impl.jac", ".test.jac"] {
        for f in discover_annex_files(head, suffix) {
            real = os.path.realpath(f);
            if real not in files {
                files.append(real);
            }
        }
    }
    tables = host_layout_tables();
    for staged in self.overlay {
        if staged in files or not staged.endswith(".jac") {
            continue;
        }
        if is_annex_path_of(tables, staged, head) {
            files.append(staged);
        }
    }
    return files;
}

impl EditGate._owner(head: str) -> dict[str, str] {
    info: dict[str, str] = {"project_root": "", "target_app": "", "app_kind": ""};
    ws = workspace_for_path(head);
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
    target = os.path.realpath(target);
    owner = self._owner(target);
    module_files = set(self._module_files(target));
    arch = arch_file_for(target) if not is_arch_file(target) else target;
    opts = CompileOptions(
        no_cgen=True,
        project_root=owner["project_root"] or None,
        target_app=owner["target_app"],
        app_kind=owner["app_kind"]
    );
    opts.entry_point = target;
    request = check_request_for([target], opts);
    if overlay {
        request.sources = dict(self.overlay);
    } elif not os.path.exists(target) {
        request.sources = {target: ""};
    }
    result = call_check(request);
    self._last_deps = sorted(result.reached);
    out: list[DiagInfo] = [];
    seen: set[tuple[str, int, int, str, str, str]] = set();
    texts: dict[str, list[str]] = {};
    for (severity, diags) in [("error", result.errors), ("warning", result.warnings)] {
        for d in diags {
            span = d.span;
            if not span.path {
                continue;
            }
            fpath = os.path.realpath(span.path);
            if fpath not in module_files and fpath != arch {
                continue;
            }
            key = (fpath, span.line, span.col, d.code, d.message, severity);
            if key in seen {
                continue;
            }
            seen.add(key);
            if fpath not in texts {
                texts[fpath] = self._text_for(fpath, overlay).splitlines();
            }
            src_lines = texts[fpath];
            anchor = src_lines[span.line - 1].strip()
                if 0 < span.line <= len(src_lines)
                else "";
            out.append(
                DiagInfo(
                    file=fpath,
                    line=span.line,
                    col=span.col,
                    severity=severity,
                    code=d.code,
                    message=d.message,
                    help=d.help,
                    anchor=anchor
                )
            );
        }
    }
    return out;
}

impl EditGate._baseline(target: str) -> list[DiagInfo] {
    target = os.path.realpath(target);
    files = self._module_files(target);
    arch = arch_file_for(target);
    if arch {
        files.append(arch);
    }
    staged = list(self.overlay.keys());
    cached = self._baselines.get(target);
    if cached is not None and cached[0] == self._stamp(files + staged + cached[2]) {
        return cached[1];
    }
    self._last_deps = [];
    if not os.path.exists(target) {
        result: list[DiagInfo] = [];
    } else {
        result = self._check(target, False);
    }
    deps = sorted(set(self._last_deps));
    self._baselines[target] = (self._stamp(files + staged + deps), result, deps);
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
    names = sorted({s.key.split(".")[0] for s in public});
    wired = self.client().wired_dependents(head, names);
    out: list[str] = list(wired.files);
    if not wired.owned {
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
        consumers = [
            ch.module
            for ch in review.arch_changes
            if ch.kind in ["new wire", "removed wire", "changed wire"] and ch.module
        ];
        for creal in self.client().wiring_module_files(real, consumers) {
            if creal not in targets {
                targets.append(creal);
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
    if not real.endswith(".jac") {
        old_plain = self._disk_text(real);
        plain = EditReview(
            path=real,
            old_text=old_plain or "",
            new_text=new_text,
            root_dir=self.root_dir
        );
        rel_plain = _rel(real, self.root_dir);
        plain.diff = "".join(
            difflib.unified_diff(
                (old_plain or "").splitlines(keepends=True),
                new_text.splitlines(keepends=True),
                fromfile=f"a/{rel_plain}" if old_plain is not None else "/dev/null",
                tofile=f"b/{rel_plain}"
            )
        );
        return plain;
    }
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
            session = self.client();
            if is_arch_file(real) {
                rv.arch_changes = wiring_changes(session, old_text or "", new_text, real);
            } else {
                rv.symbol_changes = symbol_changes(
                    session, old_text or "", new_text, real
                );
                old_imports = import_lines(session, old_text or "", real);
                new_imports = import_lines(session, new_text, real);
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

impl symbol_table(
    session: SessionClient, text: str, path: str
) -> dict[str, tuple[str, int, int, str, str]] {
    table: dict[str, tuple[str, int, int, str, str]] = {};
    if not text.strip() {
        return table;
    }
    for row in session.edit_symbols(path, text) {
        table[row.key] = (row.kind, row.line, row.end_line, row.text, row.signature);
    }
    return table;
}

impl symbol_changes(
    session: SessionClient, old_text: str, new_text: str, path: str
) -> list[SymbolChange] {
    old_tab = symbol_table(session, old_text, path);
    new_tab = symbol_table(session, new_text, path);
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

impl import_lines(session: SessionClient, text: str, path: str) -> list[str] {
    if not text.strip() {
        return [];
    }
    return session.import_texts(path, text);
}

impl wiring_changes(
    session: SessionClient, old_text: str, new_text: str, path: str
) -> list[ArchChange] {
    return [
        ArchChange(kind=row.kind, detail=row.detail, module=row.module)
        for row in session.wiring_changes(path, old_text, new_text)
    ];
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
