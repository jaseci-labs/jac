impl TestOutcome.is_failure -> bool {
    return self.status in (FAILED, ERROR, CRASHED);
}

impl TestOutcome.to_wire -> dict[(str, any)] {
    return {
        "file": self.file,
        "name": self.name,
        "status": self.status,
        "message": self.message,
        "duration": self.duration
    };
}

impl TestOutcome.from_wire(payload: dict[(str, any)]) -> TestOutcome {
    return TestOutcome(
        file=payload["file"],
        name=payload["name"],
        status=payload["status"],
        message=payload.get("message", ""),
        duration=payload.get("duration", 0.0)
    );
}

impl TestPlan.is_empty -> bool {
    return not self.files;
}

impl NameFilter.postinit -> None {
    self.tree = _parse_filter_expr(self.expr);
}

impl NameFilter.matches(name: str) -> bool {
    if self.tree is None {
        return True;
    }
    return _eval_filter(self.tree, name.lower());
}

impl _tokenize_filter(expr: str) -> list[str] {
    toks: list[str] = [];
    cur = "";
    for ch in expr {
        if ch in "()" {
            if cur {
                toks.append(cur);
                cur = "";
            }
            toks.append(ch);
        } elif ch.isspace() {
            if cur {
                toks.append(cur);
                cur = "";
            }
        } else {
            cur += ch;
        }
    }
    if cur {
        toks.append(cur);
    }
    return toks;
}

impl _parse_filter_expr(expr: str) -> any {
    text = expr.strip();
    if not text {
        return None;
    }
    toks = _tokenize_filter(text);
    if not toks {
        return None;
    }
    pos = [0];
    tree: any = None;
    try {
        tree = _parse_or(toks, pos);
    } except ValueError {
        return ("word", text.lower());
    }
    if pos[0] != len(toks) {
        return ("word", text.lower());
    }
    return tree;
}

impl _parse_or(toks: list[str], pos: list[int]) -> any {
    tree = _parse_and(toks, pos);
    while (pos[0] < len(toks)) and (toks[pos[0]] == "or") {
        pos[0] += 1;
        tree = ("or", tree, _parse_and(toks, pos));
    }
    return tree;
}

impl _parse_and(toks: list[str], pos: list[int]) -> any {
    tree = _parse_not(toks, pos);
    while (pos[0] < len(toks)) and (toks[pos[0]] == "and") {
        pos[0] += 1;
        tree = ("and", tree, _parse_not(toks, pos));
    }
    return tree;
}

impl _parse_not(toks: list[str], pos: list[int]) -> any {
    if pos[0] >= len(toks) {
        raise ValueError("unexpected end of filter expression");
    }
    tok = toks[pos[0]];
    if tok == "not" {
        pos[0] += 1;
        return ("not", _parse_not(toks, pos));
    }
    if tok == "(" {
        pos[0] += 1;
        tree = _parse_or(toks, pos);
        if (pos[0] >= len(toks)) or (toks[pos[0]] != ")") {
            raise ValueError("unbalanced parenthesis in filter expression");
        }
        pos[0] += 1;
        return tree;
    }
    if tok in (")", "and", "or") {
        raise ValueError(f"unexpected token {tok!r} in filter expression");
    }
    pos[0] += 1;
    return ("word", tok.lower());
}

impl _eval_filter(expr_node: any, name: str) -> bool {
    kind = expr_node[0];
    if kind == "word" {
        return expr_node[1] in name;
    }
    if kind == "not" {
        return not _eval_filter(expr_node[1], name);
    }
    if kind == "and" {
        return _eval_filter(expr_node[1], name) and _eval_filter(expr_node[2], name);
    }
    return _eval_filter(expr_node[1], name) or _eval_filter(expr_node[2], name);
}

impl _build_selector(test_name: str, filter: str) -> (NameFilter | None) {
    expr = "";
    if test_name {
        parts = test_name.split();
        expr = " and ".join(parts) if parts else test_name;
    } elif filter {
        expr = filter;
    }
    if not expr {
        return None;
    }
    return NameFilter(expr=expr);
}

impl _should_ignore(path: str, ignore: list[str]) -> bool {
    if not ignore {
        return False;
    }
    target = os.path.abspath(path);
    for raw in ignore {
        if not raw {
            continue;
        }
        `entry = os.path.abspath(raw);
        if (target == `entry) or target.startswith(`entry + os.sep) {
            return True;
        }
    }
    return False;
}

impl _under_fixtures(path: str) -> bool {
    parts = os.path.abspath(path).split(os.sep);
    return "fixtures" in parts[:-1];
}

impl _is_named_test_file(filename: str) -> bool {
    import from jaclang.jac0core.ext_registry { is_jac, is_test }
    return (filename.startswith("test_") and is_jac(filename)) or is_test(filename);
}

impl _suite_source(filepath: str) -> str {
    import from jaclang.jac0core.ext_registry { is_test }
    if is_test(os.path.basename(filepath)) {
        try {
            import from jaclang.jac0core.bccache { discover_base_file }
            base = discover_base_file(filepath);
            if base {
                return os.path.abspath(base);
            }
        } except Exception {
            ;
        }
    }
    return os.path.abspath(filepath);
}

impl _iter_candidate_files(start: str, ignore: (list[str] | None) = None) -> list[str] {
    import from jaclang.jac0core.ext_registry { is_impl, is_jac }
    ignored = ignore or [];
    found: list[str] = [];
    for (dirpath, dirnames, filenames) in os.walk(start, topdown=True) {
        dirnames[:] = [
            d
            for d in dirnames
            if not d.startswith(".") and (d not in ("__pycache__", "node_modules"))
        ];
        dirnames.sort();
        for fn in sorted(filenames) {
            if not is_jac(fn) or is_impl(fn) {
                continue;
            }
            full = os.path.join(dirpath, fn);
            if _should_ignore(full, ignored) {
                continue;
            }
            found.append(os.path.abspath(full));
        }
    }
    return found;
}

impl discover(
    paths: (list[str] | None) = None,
    directory: str = "",
    ignore: (list[str] | None) = None
) -> TestPlan {
    import from jaclang.jac0core.ext_registry { is_jac }
    targets = paths or [];
    ignored = ignore or [];
    explicit: set[str] = set();
    ordered: list[str] = [];
    seen: set[str] = set();
    def _add(path: str) -> None {
        key = _suite_source(path);
        if key in seen {
            return;
        }
        seen.add(key);
        ordered.append(os.path.abspath(path));
    }
    for raw in targets {
        full = os.path.abspath(raw);
        if os.path.isdir(full) {
            for cand in _iter_candidate_files(full, ignored) {
                if _under_fixtures(cand) {
                    continue;
                }
                if not _is_named_test_file(os.path.basename(cand)) {
                    continue;
                }
                _add(cand);
            }
        } elif not os.path.exists(full) {
            raise FileNotFoundError(f"no such test target: {raw}");
        } elif not is_jac(full) {
            raise ValueError(f"not a .jac file: {raw}");
        } elif not _should_ignore(full, ignored) {
            explicit.add(full);
            _add(full);
        }
    }
    if directory {
        root_dir = os.path.abspath(directory);
        for cand in _iter_candidate_files(root_dir, ignored) {
            if _under_fixtures(cand) {
                continue;
            }
            _add(cand);
        }
    }
    return TestPlan(files=ordered, explicit=explicit);
}

impl install_warning_filters -> None {
    import warnings;
    warnings.resetwarnings();
    warnings.simplefilter("error");
    categories: dict[(str, type[Warning])] = {
        "DeprecationWarning": DeprecationWarning,
        "ResourceWarning": ResourceWarning
    };
    for (message, category, module) in _WARNING_IGNORES {
        warnings.filterwarnings(
            "ignore",
            message=message,
            category=categories.get(category, Warning),
            module=module
        );
    }
}

impl default_jobs -> int {
    cpus = os.cpu_count() or 1;
    avail = 0;
    try {
        with open("/proc/meminfo", encoding="utf-8") as f {
            for line in f {
                if line.startswith("MemAvailable:") {
                    avail = int(line.split()[1]) * 1024;
                    break;
                }
            }
        }
    } except Exception {
        avail = 0;
    }
    if not avail {
        try {
            avail = os.sysconf("SC_PHYS_PAGES") * os.sysconf("SC_PAGE_SIZE");
        } except Exception {
            avail = 0;
        }
    }
    cap = cpus;
    if avail {
        cap = max(1, int((avail * _MEM_HEADROOM) // _WORKER_MEM_BYTES));
    }
    return max(1, min(cpus, cap, _MAX_AUTO_JOBS));
}

impl resolve_jobs(requested: (str | int | None) = None) -> int {
    raw = requested;
    if (raw is None) or (raw == "") {
        raw = os.environ.get("JAC_TEST_JOBS", "");
    }
    if (raw is None) or (raw == "") {
        return default_jobs();
    }
    if isinstance(raw, int) {
        return max(1, raw);
    }
    text = str(raw).strip().lower();
    if text == "auto" {
        return default_jobs();
    }
    try {
        return max(1, int(text));
    } except ValueError {
        return default_jobs();
    }
}

impl _cleanup_test_bases -> None {
    import shutil;
    while _TEST_BASES {
        path = _TEST_BASES.pop();
        if os.path.isdir(path) {
            shutil.rmtree(path, ignore_errors=True);
        } else {
            try {
                os.unlink(path);
            } except OSError {
                ;
            }
        }
    }
}

impl _detach_from_parent(module_name: str) -> None {
    import sys;
    (parent_name, _, child_name) = module_name.rpartition('.');
    if not parent_name or not child_name {
        return;
    }
    parent = sys.modules.get(parent_name);
    if parent is None {
        return;
    }
    try {
        delattr(parent, child_name);
    } except AttributeError {
        ;
    }
}

impl _fresh_jac_state(clear_modules: bool = True) -> None {
    import sys;
    import tempfile;
    import from concurrent.futures { ThreadPoolExecutor }
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.jac0core.runtime { JacRuntime, JacRuntimeInterface }
    import from jaclang.runtimelib.serializer { Serializer }
    import from jaclang.runtimelib.session { mark_scratch_base }
    if JacRuntime.exec_ctx is not None {
        JacRuntime.exec_ctx.mem.close();
    }
    if clear_modules {
        for mod in list(JacRuntime.loaded_modules.values()) {
            if (
                not mod.__name__.startswith("jaclang.") and (mod.__name__ != "__main__")
            ) {
                sys.modules.pop(mod.__name__, None);
                Serializer.unregister_module(mod.__name__);
                _detach_from_parent(mod.__name__);
            }
        }
        JacRuntime.loaded_modules.clear();
    }
    fresh_base = tempfile.mkdtemp(prefix="jac-test-base-");
    _TEST_BASES.append(fresh_base);
    mark_scratch_base(fresh_base);
    JacRuntime.set_base_path(fresh_base);
    JacRuntime.set_full_target_path(None);
    outgoing_pool = JacRuntime.pool;
    JacRuntime.program = JacProgram();
    JacRuntime.pool = ThreadPoolExecutor();
    outgoing_pool.shutdown(`wait=False, cancel_futures=True);
    JacRuntime.exec_ctx = JacRuntimeInterface.create_j_context(
        user_root=None, base_path_dir=fresh_base, full_target_path=None
    );
}

impl _capture_begin -> dict[(str, any)] {
    import sys;
    import tempfile;
    for stream in (sys.stdout, sys.stderr) {
        try {
            stream.flush();
        } except Exception {
            ;
        }
    }
    sink: any = None;
    if _CRASH_LOG[0] {
        sink = open(_CRASH_LOG[0], "w+b");
    } else {
        sink = tempfile.TemporaryFile();
    }
    state: dict[(str, any)] = {
        "sink": sink,
        "out": os.dup(1),
        "err": os.dup(2),
        "sys_out": sys.stdout,
        "sys_err": sys.stderr
    };
    os.dup2(sink.fileno(), 1);
    os.dup2(sink.fileno(), 2);
    made_out = os.fdopen(os.dup(1), "w", encoding="utf-8", errors="replace");
    made_err = os.fdopen(os.dup(2), "w", encoding="utf-8", errors="replace");
    state["made_out"] = made_out;
    state["made_err"] = made_err;
    sys.stdout = made_out;
    sys.stderr = made_err;
    return state;
}

impl _capture_end(state: dict[(str, any)]) -> str {
    import sys;
    for stream in (state["made_out"], state["made_err"]) {
        try {
            stream.flush();
            stream.close();
        } except Exception {
            ;
        }
    }
    sys.stdout = state["sys_out"];
    sys.stderr = state["sys_err"];
    os.dup2(state["out"], 1);
    os.dup2(state["err"], 2);
    os.close(state["out"]);
    os.close(state["err"]);
    sink = state["sink"];
    text = "";
    try {
        sink.flush();
        sink.seek(0);
        text = sink.read().decode("utf-8", "replace");
    } except Exception {
        text = "";
    }
    try {
        sink.close();
    } except Exception {
        ;
    }
    return text;
}

impl _project_root_for(start_dir: str) -> str {
    current = os.path.realpath(start_dir);
    while True {
        if os.path.exists(os.path.join(current, "jac.toml")) {
            return current;
        }
        parent = os.path.dirname(current);
        if parent == current {
            return "";
        }
        current = parent;
    }
}

impl _package_basedir(start_dir: str) -> str {
    current = os.path.realpath(start_dir);
    while True {
        packaged = False;
        for marker in ("__init__.py", "__init__.jac") {
            if os.path.exists(os.path.join(current, marker)) {
                packaged = True;
            }
        }
        if not packaged {
            return current;
        }
        parent = os.path.dirname(current);
        if parent == current {
            return current;
        }
        current = parent;
    }
}

impl _outermost_package_root(start_dir: str, ceiling: str) -> str {
    current = os.path.realpath(start_dir);
    stop = os.path.realpath(ceiling) if ceiling else "";
    outermost = "";
    while True {
        for marker in ("__init__.py", "__init__.jac") {
            if os.path.exists(os.path.join(current, marker)) {
                outermost = current;
            }
        }
        if stop and (current == stop) {
            break;
        }
        parent = os.path.dirname(current);
        if parent == current {
            break;
        }
        current = parent;
    }
    return os.path.dirname(outermost) if outermost else "";
}

impl _ensure_test_package(base_dir: str) -> str {
    import sys;
    import types;
    import from importlib.machinery { ModuleSpec }
    real_dir = os.path.realpath(base_dir);
    pkg_name = _TEST_PACKAGES.get(real_dir, "");
    if pkg_name and (pkg_name in sys.modules) {
        return pkg_name;
    }
    if not pkg_name {
        pkg_name = f"_jac_test_pkg_{_TEST_PKG_COUNTER[0]}";
        _TEST_PKG_COUNTER[0] += 1;
        _TEST_PACKAGES[real_dir] = pkg_name;
    }
    pkg = types.ModuleType(pkg_name);
    pkg.__path__ = [real_dir];
    pkg.__package__ = pkg_name;
    pkg.__spec__ = ModuleSpec(pkg_name, loader=None, is_package=True);
    pkg.__spec__.submodule_search_locations = [real_dir];
    sys.modules[pkg_name] = pkg;
    return pkg_name;
}

impl JacTestResult._exc_info_to_string(err: any, `test: any) -> str {
    import linecache;
    (exc_type, exc_value, tb) = err;
    entries: list[tuple[str, int, str, str]] = [];
    last: any = None;
    cur = tb;
    while cur is not None {
        frame = cur.tb_frame;
        filename = frame.f_code.co_filename;
        lineno = cur.tb_lineno;
        funcname = frame.f_code.co_name;
        cur = cur.tb_next;
        src = "";
        try {
            src = linecache.getline(filename, lineno).strip();
        } except Exception {
            src = "";
        }
        `entry = (filename, lineno, funcname, src);
        last = `entry;
        vendored = False;
        for marker in (".venv/", "site-packages/", "/unittest/") {
            if marker in filename {
                vendored = True;
            }
        }
        if vendored {
            continue;
        }
        if ("/jaclang/" in filename) and ("/tests/" not in filename) {
            continue;
        }
        entries.append(`entry);
    }
    lines: list[str] = [];
    for (filename, lineno, funcname, src) in entries {
        lines.append(f"  {filename}:{lineno} in {funcname}");
        if src {
            lines.append(f"    {src}");
        }
    }
    if (last is not None) and (not entries or (last != entries[-1])) {
        (filename, lineno, funcname, src) = last;
        lines.append(f"  {filename}:{lineno} in {funcname}");
        if src {
            lines.append(f"    {src}");
        }
    }
    lines.append(f"E   {exc_type.__name__}: {exc_value}");
    return "\n".join(lines);
}

impl run_file(
    filepath: str,
    selector: (NameFilter | None) = None,
    explicit: bool = False,
    xit: bool = False,
    maxfail: (int | None) = None,
    seen_failures: int = 0
) -> list[TestOutcome] {
    import importlib;
    import sys;
    import time;
    import from jaclang.runtimelib.test { JacTestCheck }
    import from jaclang.runtimelib.cl_test_runner { module_is_client, run_cl_test_file }
    import from jaclang.jac0core.ext_registry { base_stem }
    abs_path = os.path.abspath(filepath);
    outcomes: list[TestOutcome] = [];
    is_client = False;
    setup_capture = _capture_begin();
    try {
        _fresh_jac_state();
        JacTestCheck.reset();
        try {
            is_client = bool(module_is_client(abs_path));
        } except Exception {
            is_client = False;
        }
    } finally {
        _capture_end(setup_capture);
    }
    if is_client {
        try {
            results = run_cl_test_file(abs_path);
        } except Exception as exc {
            return [
                TestOutcome(
                    file=abs_path,
                    name=os.path.basename(abs_path),
                    status=ERROR,
                    message=f"{type(exc).__name__}: {exc}"
                )
            ];
        }
        for res in results {
            label = res.description or res.name;
            if (selector is not None) and not selector.matches(label) {
                continue;
            }
            outcomes.append(
                TestOutcome(
                    file=abs_path,
                    name=label,
                    status=PASSED if res.ok else FAILED,
                    message="" if res.ok else (res.error or "client test failed")
                )
            );
        }
        return outcomes;
    }
    source = _suite_source(abs_path);
    base_dir = os.path.dirname(source);
    mod_name = base_stem(os.path.basename(source));
    pkg_name = _ensure_test_package(base_dir);
    qualified = f"{pkg_name}.{mod_name}";
    real_dir = os.path.realpath(base_dir);
    basedir = _package_basedir(real_dir);
    roots: list[str] = [];
    project_root = _project_root_for(real_dir);
    if project_root {
        roots.append(project_root);
    }
    package_root = _outermost_package_root(real_dir, project_root);
    if package_root and (package_root not in roots) {
        roots.append(package_root);
    }
    injected: list[str] = [];
    for `entry in (roots + [basedir, real_dir]) {
        if `entry not in sys.path {
            sys.path.insert(0, `entry);
            injected.append(`entry);
        }
    }
    import_error = "";
    capture = _capture_begin();
    try {
        importlib.import_module(qualified);
    } except BaseException as exc {
        import from traceback { format_exception }
        import_error = "".join(format_exception(exc)).rstrip();
    }
    import_output = _capture_end(capture);
    try {
        if import_error {
            if import_output.strip() {
                import_error += "\n--- captured output ---\n" + import_output.rstrip();
            }
            return [
                TestOutcome(
                    file=abs_path,
                    name=os.path.basename(abs_path),
                    status=ERROR,
                    message=import_error
                )
            ];
        }
        pending: list = [];
        for (_key, registered) in list(JacTestCheck.test_suite_path.items()) {
            for info in list(registered) {
                pending.append(info);
            }
        }
        for info in pending {
            label = info.display_name;
            if (selector is not None) and not selector.matches(label) {
                continue;
            }
            result = JacTestResult();
            started = time.perf_counter();
            capture = _capture_begin();
            try {
                _fresh_jac_state(clear_modules=False);
                info.test_case.run(result);
            } finally {
                captured = _capture_end(capture);
            }
            elapsed = time.perf_counter() - started;
            status = PASSED;
            message = "";
            if result.skipped {
                status = SKIPPED;
                message = str(result.skipped[0][1]);
            } elif result.failures {
                status = FAILED;
                message = str(result.failures[0][1]);
            } elif result.errors {
                status = ERROR;
                message = str(result.errors[0][1]);
            }
            if (status in (FAILED, ERROR)) and captured.strip() {
                message += "\n--- captured output ---\n" + captured.rstrip();
            }
            outcomes.append(
                TestOutcome(
                    file=abs_path,
                    name=label,
                    status=status,
                    message=message,
                    duration=elapsed
                )
            );
            failed = seen_failures
                + len(
                    [
                        o
                        for o in outcomes
                        if o.is_failure()
                    ]
                );
            if xit and (failed > 0) {
                return outcomes;
            }
            if maxfail and (failed >= maxfail) {
                return outcomes;
            }
        }
    } finally {
        for `entry in injected {
            try {
                sys.path.remove(`entry);
            } except ValueError {
                ;
            }
        }
    }
    return outcomes;
}

impl Reporter.postinit -> None {
    import sys;
    if self.stream is None {
        self.stream = sys.stdout;
    }
    self.counts = {PASSED: 0, FAILED: 0, ERROR: 0, SKIPPED: 0, CRASHED: 0};
    self.failures = [];
}

impl Reporter.record(outcome: TestOutcome) -> None {
    self.counts[outcome.status] = self.counts.get(outcome.status, 0) + 1;
    if outcome.is_failure() {
        self.failures.append(outcome);
    }
    if self.verbose {
        self.stream.write(
            f"{outcome.status.upper():8} {outcome.name}  [{outcome.file}]\n"
        );
    } else {
        marks = {PASSED: ".", FAILED: "F", ERROR: "E", SKIPPED: "s", CRASHED: "!"};
        self.stream.write(marks.get(outcome.status, "?"));
        self.column += 1;
        if self.column >= _PROGRESS_WIDTH {
            self.stream.write("\n");
            self.column = 0;
        }
    }
    self.stream.flush();
}

impl Reporter.file_crashed(filepath: str, detail: str) -> None {
    self.record(
        TestOutcome(
            file=filepath,
            name=os.path.basename(filepath),
            status=CRASHED,
            message=detail
        )
    );
}

impl Reporter.total_count -> int {
    return sum(self.counts.values());
}

impl Reporter.failure_count -> int {
    return (
        self.counts.get(FAILED, 0)
        + self.counts.get(ERROR, 0)
        + self.counts.get(CRASHED, 0)
    );
}

impl Reporter.summarize(elapsed: float) -> int {
    if self.column {
        self.stream.write("\n");
        self.column = 0;
    }
    for outcome in self.failures {
        self.stream.write(f"\nFAILED {outcome.file}::{outcome.name}\n");
        if outcome.message {
            self.stream.write(outcome.message.rstrip() + "\n");
        }
    }
    parts: list[str] = [];
    for key in (PASSED, FAILED, ERROR, SKIPPED, CRASHED) {
        count = self.counts.get(key, 0);
        if count {
            parts.append(f"{count} {key}");
        }
    }
    if not parts {
        parts.append("no tests ran");
    }
    self.stream.write(f"\n{', '.join(parts)} in {elapsed:.2f}s\n");
    self.stream.flush();
    return self.failure_count();
}

impl ForkPool.postinit -> None {
    self.kids = [];
}

impl ForkPool._should_stop -> bool {
    if self.stopping {
        return True;
    }
    fails = self.reporter.failure_count();
    if self.xit and (fails > 0) {
        self.stopping = True;
        return True;
    }
    if self.maxfail and (fails >= self.maxfail) {
        self.stopping = True;
        return True;
    }
    return False;
}

impl ForkPool._spawn(slot: int) -> dict[(str, any)] {
    (dispatch_r, dispatch_w) = os.pipe();
    (result_r, result_w) = os.pipe();
    pid = os.fork();
    if pid == 0 {
        try {
            os.close(dispatch_w);
            os.close(result_r);
            for other in self.kids {
                try {
                    os.close(other["dispatch_fd"]);
                } except OSError {
                    ;
                }
                try {
                    os.close(other["result_fd"]);
                } except OSError {
                    ;
                }
            }
            self._worker_loop(dispatch_r, result_w);
            _cleanup_test_bases();
        } except BaseException {
            ;
        }
        os._exit(0);
    }
    os.close(dispatch_r);
    os.close(result_w);
    import tempfile;
    (log_fd, log_path) = tempfile.mkstemp(prefix="jac-test-crash-");
    os.close(log_fd);
    _TEST_BASES.append(log_path);
    return {
        "pid": pid,
        "slot": slot,
        "dispatch_fd": dispatch_w,
        "result_fd": result_r,
        "buf": b"",
        "inflight": None,
        "alive": True,
        "crashlog": log_path
    };
}

impl ForkPool._worker_loop(dispatch_fd: int, result_fd: int) -> None {
    import json;
    install_warning_filters();
    reader = os.fdopen(dispatch_fd, "r", encoding="utf-8");
    while True {
        line = reader.readline();
        if not line {
            break;
        }
        text = line.strip();
        if not text or (text == "q") {
            break;
        }
        try {
            request = json.loads(text);
        } except Exception {
            break;
        }
        _CRASH_LOG[0] = str(request.get("crashlog", ""));
        outcomes: list[TestOutcome] = [];
        try {
            outcomes = run_file(
                request["path"],
                self.selector,
                bool(request.get("explicit")),
                xit=self.xit,
                maxfail=self.maxfail,
                seen_failures=int(request.get("seen", 0))
            );
        } except BaseException as exc {
            import from traceback { format_exception }
            outcomes = [
                TestOutcome(
                    file=request["path"],
                    name=os.path.basename(request["path"]),
                    status=ERROR,
                    message="".join(format_exception(exc)).rstrip()
                )
            ];
        }
        payload = json.dumps(
            {"idx": request["idx"], "outcomes": [o.to_wire() for o in outcomes]}
        );
        try {
            os.write(result_fd, (payload + "\n").encode("utf-8"));
        } except OSError {
            break;
        }
    }
}

impl ForkPool._dispatch(kid: dict[(str, any)]) -> bool {
    import json;
    if self._should_stop() or (self.cursor >= len(self.plan.files)) {
        return False;
    }
    idx = self.cursor;
    self.cursor += 1;
    path = self.plan.files[idx];
    kid["inflight"] = idx;
    payload = json.dumps(
        {
            "idx": idx,
            "path": path,
            "explicit": path in self.plan.explicit,
            "seen": self.reporter.failure_count(),
            "crashlog": kid["crashlog"]
        }
    );
    try {
        os.write(kid["dispatch_fd"], (payload + "\n").encode("utf-8"));
    } except OSError {
        kid["inflight"] = None;
        return False;
    }
    return True;
}

impl ForkPool._handle_record(kid: dict[(str, any)], line: str) -> None {
    import json;
    text = line.strip();
    if not text {
        return;
    }
    try {
        record = json.loads(text);
    } except Exception {
        return;
    }
    kid["inflight"] = None;
    for item in record.get("outcomes", []) {
        self.reporter.record(TestOutcome.from_wire(item));
    }
    self._dispatch(kid);
}

impl ForkPool._reap(kid: dict[(str, any)]) -> None {
    if not kid["alive"] {
        return;
    }
    kid["alive"] = False;
    try {
        os.close(kid["result_fd"]);
    } except OSError {
        ;
    }
    try {
        os.close(kid["dispatch_fd"]);
    } except OSError {
        ;
    }
    status = 0;
    try {
        (_, status) = os.waitpid(kid["pid"], 0);
    } except OSError {
        status = 0;
    }
    idx = kid["inflight"];
    if idx is not None {
        kid["inflight"] = None;
        detail = f"worker exited while running this file (wait status {status})";
        spilled = "";
        try {
            with open(kid["crashlog"], "rb") as f {
                spilled = f.read().decode("utf-8", "replace").strip();
            }
        } except Exception {
            spilled = "";
        }
        if spilled {
            detail += "\n--- output captured before the worker died ---\n" + spilled;
        }
        self.reporter.file_crashed(self.plan.files[idx], detail);
    }
    if not self._should_stop() and (self.cursor < len(self.plan.files)) {
        replacement = self._spawn(kid["slot"]);
        self.kids.append(replacement);
        self._dispatch(replacement);
    }
}

impl ForkPool.run -> None {
    import select;
    for slot in range(self.jobs) {
        self.kids.append(self._spawn(slot));
    }
    try {
        for kid in list(self.kids) {
            self._dispatch(kid);
        }
        self._pump();
    } finally {
        self._shutdown();
    }
}

impl ForkPool._pump -> None {
    import select;
    while True {
        live = [
            k
            for k in self.kids
            if k["alive"]
        ];
        if not live {
            break;
        }
        busy = [
            k
            for k in live
            if k["inflight"] is not None
        ];
        if not busy {
            break;
        }
        fds = [k["result_fd"] for k in busy];
        try {
            (ready, _, _) = select.select(fds, [], []);
        } except OSError {
            break;
        }
        for fd in ready {
            owners = [
                k
                for k in busy
                if k["result_fd"] == fd
            ];
            if not owners {
                continue;
            }
            kid = owners[0];
            if not kid["alive"] {
                continue;
            }
            chunk = b"";
            try {
                chunk = os.read(fd, 65536);
            } except OSError {
                chunk = b"";
            }
            if not chunk {
                self._reap(kid);
                continue;
            }
            buf: bytes = bytes(kid["buf"]) + chunk;
            while b"\n" in buf {
                (line, _, rest) = buf.partition(b"\n");
                buf = rest;
                self._handle_record(kid, line.decode("utf-8", "replace"));
            }
            kid["buf"] = buf;
        }
    }
}

impl ForkPool._shutdown -> None {
    import signal;
    import time;
    for kid in self.kids {
        if not kid["alive"] {
            continue;
        }
        try {
            os.write(kid["dispatch_fd"], b"q\n");
        } except OSError {
            ;
        }
    }
    for kid in self.kids {
        if not kid["alive"] {
            continue;
        }
        kid["alive"] = False;
        for fd_key in ("dispatch_fd", "result_fd") {
            try {
                os.close(kid[fd_key]);
            } except OSError {
                ;
            }
        }
        reaped = False;
        deadline = time.monotonic() + 2.0;
        while time.monotonic() < deadline {
            done = 0;
            try {
                (done, _) = os.waitpid(kid["pid"], os.WNOHANG);
            } except OSError {
                reaped = True;
            }
            if reaped or done {
                reaped = True;
                break;
            }
            time.sleep(0.02);
        }
        if not reaped {
            try {
                os.kill(int(kid["pid"]), int(signal.SIGKILL));
            } except OSError {
                ;
            }
            try {
                os.waitpid(kid["pid"], 0);
            } except OSError {
                ;
            }
        }
    }
}

impl _run_serial(
    plan: TestPlan,
    selector: (NameFilter | None),
    reporter: Reporter,
    xit: bool,
    maxfail: (int | None)
) -> None {
    install_warning_filters();
    for path in plan.files {
        outcomes: list[TestOutcome] = [];
        try {
            outcomes = run_file(
                path,
                selector,
                path in plan.explicit,
                xit=xit,
                maxfail=maxfail,
                seen_failures=reporter.failure_count()
            );
        } except BaseException as exc {
            import from traceback { format_exception }
            outcomes = [
                TestOutcome(
                    file=path,
                    name=os.path.basename(path),
                    status=ERROR,
                    message="".join(format_exception(exc)).rstrip()
                )
            ];
        }
        for outcome in outcomes {
            reporter.record(outcome);
        }
        fails = reporter.failure_count();
        if xit and (fails > 0) {
            break;
        }
        if maxfail and (fails >= maxfail) {
            break;
        }
    }
}

impl run_tests(
    paths: (list[str] | None) = None,
    directory: str = "",
    test_name: str = "",
    filter: str = "",
    xit: bool = False,
    maxfail: (int | None) = None,
    verbose: bool = False,
    ignore: (list[str] | None) = None,
    jobs: (str | int | None) = None
) -> int {
    import sys;
    import time;
    plan = discover(paths, directory, ignore);
    reporter = Reporter(verbose=verbose);
    if plan.is_empty() {
        sys.stdout.write("no tests ran (no test files collected)\n");
        sys.stdout.flush();
        return EXIT_NO_TESTS;
    }
    selector = _build_selector(test_name, filter);
    workers = resolve_jobs(jobs);
    started = time.perf_counter();
    if (workers <= 1) or (len(plan.files) <= 1) or not hasattr(os, "fork") {
        _run_serial(plan, selector, reporter, xit, maxfail);
    } else {
        pool = ForkPool(
            plan=plan,
            selector=selector,
            reporter=reporter,
            jobs=min(workers, len(plan.files)),
            xit=xit,
            maxfail=maxfail
        );
        pool.run();
    }
    failures = reporter.summarize(time.perf_counter() - started);
    if reporter.total_count() == 0 {
        return EXIT_NO_TESTS;
    }
    if failures {
        return EXIT_FAILED;
    }
    return EXIT_OK;
}
