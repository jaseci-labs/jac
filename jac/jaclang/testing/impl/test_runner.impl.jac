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

impl strict_mode -> bool {
    return os.environ.get(STRICT_ENV, "").strip().lower() in ("1", "true", "yes", "on");
}

impl _match_patterns(files: list[str], patterns: (list[str] | None)) -> set[str] {
    import fnmatch;
    matched: set[str] = set();
    for raw in (patterns or []) {
        if not raw {
            continue;
        }
        pat = os.path.abspath(raw);
        for path in files {
            if path in matched {
                continue;
            }
            if fnmatch.fnmatch(path, pat) or path.startswith(pat + os.sep) {
                matched.add(path);
            }
        }
    }
    return matched;
}

impl _optional_dep_gap(exc: BaseException) -> str {
    import sys;
    if not isinstance(exc, ModuleNotFoundError) {
        return "";
    }
    name = str(exc.name or "");
    top = name.split(".")[0] if name else "";
    if not top {
        return "";
    }
    if (top in ("jaclang", "tests")) or top.startswith("_jac_test_pkg") {
        return "";
    }
    if (top in sys.stdlib_module_names) or (top in sys.builtin_module_names) {
        return "";
    }
    return top;
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
            import from jaclang.compiler.driver.bccache { discover_base_file }
            base = discover_base_file(filepath);
            if base {
                return os.path.realpath(base);
            }
        } except Exception {}
    }
    return os.path.realpath(filepath);
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
    directory: (str | list[str]) = "",
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
    roots = [directory] if isinstance(directory, str) else list(directory);
    for rt in roots {
        if not rt {
            continue;
        }
        root_dir = os.path.abspath(rt);
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

impl _cleanup_test_bases -> None {
    import shutil;
    while _TEST_BASES {
        path = _TEST_BASES.pop();
        if os.path.isdir(path) {
            shutil.rmtree(path, ignore_errors=True);
        } else {
            try {
                os.unlink(path);
            } except OSError {}
        }
    }
}

impl _fresh_jac_state(clear_modules: bool = True) -> None {
    import tempfile;
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.runtime.runtime { JacRuntime, JacRuntimeInterface }
    import from jaclang.project.config { get_explicit_config, set_config }
    import from jaclang.server.session { mark_scratch_base }
    if not _CONFIG_PIN_BASELINE {
        _CONFIG_PIN_BASELINE.append(get_explicit_config());
    } else {
        set_config(_CONFIG_PIN_BASELINE[0]);
    }
    JacRuntime.reset_process_state(clear_modules=clear_modules);
    fresh_base = tempfile.mkdtemp(prefix="jac-test-base-");
    _TEST_BASES.append(fresh_base);
    mark_scratch_base(fresh_base);
    JacRuntime.set_base_path(fresh_base);
    JacRuntime.set_full_target_path(None);
    JacRuntime.program = JacProgram();
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
        } except Exception {}
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
        } except Exception {}
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
    } except Exception {}
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
    import from jaclang.testing.test { JacTestCheck }
    import from jaclang.testing.cl_test_runner { module_is_client, run_cl_test_file }
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
    dep_gap = "";
    skip_gap = "";
    capture = _capture_begin();
    try {
        importlib.import_module(qualified);
    } except unittest.SkipTest as exc {
        skip_gap = str(exc) or "skipped at import";
    } except BaseException as exc {
        import from traceback { format_exception }
        import_error = "".join(format_exception(exc)).rstrip();
        dep_gap = _optional_dep_gap(exc);
    }
    import_output = _capture_end(capture);
    try {
        if skip_gap {
            return [
                TestOutcome(
                    file=abs_path,
                    name=os.path.basename(abs_path),
                    status=SKIPPED,
                    message=skip_gap
                )
            ];
        }
        if import_error {
            if dep_gap and not strict_mode() {
                return [
                    TestOutcome(
                        file=abs_path,
                        name=os.path.basename(abs_path),
                        status=SKIPPED,
                        message=(
                            f"missing optional dependency '{dep_gap}'"
                            f" (install it, or set {STRICT_ENV}=1 to fail instead)"
                        )
                    )
                ];
            }
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
            } except ValueError {}
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
    pct = self._pct_text();
    if self.verbose {
        line = f"{outcome.status.upper():8} {outcome.name}  [{outcome.file}]";
        if pct {
            line += " " * max(1, _PROGRESS_WIDTH - len(line)) + pct;
        }
        self.stream.write(line + "\n");
    } else {
        marks = {PASSED: ".", FAILED: "F", ERROR: "E", SKIPPED: "s", CRASHED: "!"};
        self.stream.write(marks.get(outcome.status, "?"));
        self.column += 1;
        if self.column >= _PROGRESS_WIDTH {
            if pct {
                self.stream.write(" " + pct);
            }
            self.stream.write("\n");
            self.column = 0;
        }
    }
    self.stream.flush();
}

impl Reporter.file_done -> None {
    self.files_done += 1;
}

impl Reporter._pct_text -> str {
    if self.total_files <= 0 {
        return "";
    }
    pct = (self.files_done * 100) // self.total_files;
    return f"[{min(pct, 100):3d}%]";
}

impl Reporter.file_crashed(filepath: str, detail: str) -> None {
    self.file_done();
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
        pct = self._pct_text();
        if pct {
            self.stream.write(" " * max(1, _PROGRESS_WIDTH - self.column + 1) + pct);
        }
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

impl _parse_pct_range(expr: str) -> tuple[(int, int)] {
    parts = expr.split("-");
    bad = ValueError(f"bad --range '{expr}': expected N-M, N-, or -M (percents)");
    if len(parts) != 2 {
        raise bad;
    }
    try {
        lo = int(parts[0]) if parts[0] else 0;
        hi = int(parts[1]) if parts[1] else 100;
    } except ValueError {
        raise bad;
    }
    if not (0 <= lo <= hi <= 100) {
        raise bad;
    }
    return (lo, hi);
}

impl _state_path -> str {
    return os.path.join(os.getcwd(), ".jac", "test_state.json");
}

impl _load_last_failed -> str {
    import json;
    try {
        with open(_state_path(), "r", encoding="utf-8") as f {
            payload = json.load(f);
        }
        return str(payload.get("first_failed", ""));
    } except Exception {
        return "";
    }
}

impl _store_run_state(plan: TestPlan, reporter: Reporter) -> None {
    import json;
    path = _state_path();
    if not reporter.failure_count() {
        try {
            os.remove(path);
        } except OSError {}
        return;
    }
    order = {p: i for (i, p) in enumerate(plan.files)};
    first = "";
    best = len(plan.files) + 1;
    for outcome in reporter.failures {
        idx = order.get(outcome.file, len(plan.files));
        if idx < best {
            best = idx;
            first = outcome.file;
        }
    }
    if not first {
        return;
    }
    try {
        os.makedirs(os.path.dirname(path), exist_ok=True);
        with open(path, "w", encoding="utf-8") as f {
            json.dump({"first_failed": first}, f);
        }
    } except Exception {}
}

impl run_tests(
    paths: (list[str] | None) = None,
    directory: (str | list[str]) = "",
    test_name: str = "",
    filter: str = "",
    xit: bool = False,
    maxfail: (int | None) = None,
    collect_only: bool = False,
    pct_range: str = "",
    resume: bool = False,
    verbose: bool = False,
    ignore: (list[str] | None) = None,
    jobs: (str | int | None) = None,
    isolate: (list[str] | None) = None,
    serial: (list[str] | None) = None
) -> int {
    import sys;
    import time;
    if pct_range and resume {
        raise ValueError("--range and --resume cannot be combined");
    }
    plan = discover(paths, directory, ignore);
    iso_set = _match_patterns(plan.files, isolate);
    ser_set = _match_patterns(plan.files, serial);
    if iso_set or ser_set {
        plan.files = (
            [
                f
                for f in plan.files
                if (f in iso_set) and (f not in ser_set)
            ]
            + [
                f
                for f in plan.files
                if (f not in iso_set) and (f not in ser_set)
            ]
            + [
                f
                for f in plan.files
                if f in ser_set
            ]
        );
    }
    if resume {
        last = _load_last_failed();
        if not last {
            sys.stdout.write(
                "nothing to resume (no failure recorded); running the full plan\n"
            );
        } elif last not in plan.files {
            sys.stdout.write(
                "recorded failure is not in the current plan; "
                "running the full plan\n"
            );
        } else {
            plan.files = plan.files[plan.files.index(last):];
        }
    }
    if pct_range {
        (lo, hi) = _parse_pct_range(pct_range);
        n = len(plan.files);
        plan.files = plan.files[(lo * n) // 100:-((-hi * n) // 100)];
    }
    reporter = Reporter(verbose=verbose, total_files=len(plan.files));
    if plan.is_empty() {
        sys.stdout.write("no tests ran (no test files collected)\n");
        sys.stdout.flush();
        return EXIT_NO_TESTS;
    }
    if collect_only {
        for path in plan.files {
            rel = os.path.relpath(path);
            sys.stdout.write((path if rel.startswith("..") else rel) + "\n");
        }
        count = len(plan.files);
        plural = "" if count == 1 else "s";
        sys.stdout.write(f"\n{count} test file{plural} collected\n");
        sys.stdout.flush();
        return EXIT_OK;
    }
    selector = _build_selector(test_name, filter);
    workers = resolve_jobs(jobs);
    started = time.perf_counter();
    raw_jobs = jobs
        if (jobs not in (None, ""))
        else os.environ.get("JAC_TEST_JOBS", "");
    forced_serial = str(raw_jobs).strip() == "0";
    use_pool = hasattr(os, "fork")
        and not forced_serial
        and (len(plan.files) > 1 or bool(iso_set) or bool(ser_set));
    if not use_pool {
        _run_plan(
            plan, selector, reporter, xit, maxfail, jobs=1, isolate=None, inline=True
        );
    } else {
        par_files = [
            f
            for f in plan.files
            if f not in ser_set
        ];
        ser_files = [
            f
            for f in plan.files
            if f in ser_set
        ];
        if par_files {
            _run_plan(
                TestPlan(files=par_files, explicit=plan.explicit),
                selector,
                reporter,
                xit,
                maxfail,
                jobs=min(workers, len(par_files)),
                isolate=iso_set,
                inline=False
            );
        }
        fails = reporter.failure_count();
        blocked = (xit and (fails > 0)) or (maxfail and (fails >= maxfail));
        if ser_files and not blocked {
            _run_plan(
                TestPlan(files=ser_files, explicit=plan.explicit),
                selector,
                reporter,
                xit,
                maxfail,
                jobs=1,
                isolate=set(ser_files),
                inline=False
            );
        }
    }
    failures = reporter.summarize(time.perf_counter() - started);
    _store_run_state(plan, reporter);
    if reporter.total_count() == 0 {
        return EXIT_NO_TESTS;
    }
    if failures {
        return EXIT_FAILED;
    }
    return EXIT_OK;
}

impl resolve_jobs(requested: (str | int | None) = None) -> int {
    import from jaclang.cli.workpool { resolve_jobs as _resolve_pool_jobs }

    return _resolve_pool_jobs(requested, env_var="JAC_TEST_JOBS");
}

def _test_rss_cap_mb -> int {
    import from jaclang.cli.workpool { env_int }
    return env_int("JAC_TEST_RECYCLE_MB", 8192);
}

impl _test_retire(served: int, rss_mb: int) -> bool {
    import from jaclang.cli.workpool { env_int }
    return _should_retire(
        served, env_int("JAC_TEST_RECYCLE", 25), rss_mb, _test_rss_cap_mb()
    );
}

impl _run_plan(
    plan: TestPlan,
    selector: (NameFilter | None),
    reporter: Reporter,
    xit: bool,
    maxfail: (int | None),
    jobs: int,
    isolate: (set[str] | None),
    inline: bool
) -> None {
    def job(request: dict[(str, any)]) -> list[dict[(str, any)]] {
        _CRASH_LOG[0] = str(request.get("crashlog", ""));
        outcomes = run_file(
            request["path"],
            selector,
            bool(request.get("explicit")),
            xit=xit,
            maxfail=maxfail,
            seen_failures=int(request.get("seen", 0))
        );
        return [o.to_wire() for o in outcomes];
    }
    def request_extra(idx: int, path: str) -> dict[(str, any)] {
        return {"explicit": path in plan.explicit, "seen": reporter.failure_count()};
    }
    def should_stop -> bool {
        fails = reporter.failure_count();
        if xit and (fails > 0) {
            return True;
        }
        return bool(maxfail) and (fails >= int(maxfail or 0));
    }
    def on_record(idx: int, record: dict[(str, any)]) -> None {
        path = plan.files[idx];
        crash = record.get("crash");
        if crash is not None {
            reporter.file_crashed(path, str(crash));
            return;
        }
        reporter.file_done();
        error = record.get("error");
        if error is not None {
            reporter.record(
                TestOutcome(
                    file=path,
                    name=os.path.basename(path),
                    status=ERROR,
                    message=str(error)
                )
            );
            return;
        }
        for item in (record.get("result") or []) {
            reporter.record(TestOutcome.from_wire(item));
        }
    }
    pool = WorkPool(
        items=list(plan.files),
        job=job,
        on_record=on_record,
        jobs=jobs,
        request_extra=request_extra,
        should_stop=should_stop,
        retire=_test_retire,
        worker_init=install_warning_filters,
        worker_exit=_cleanup_test_bases,
        isolate=isolate,
        rss_log_env="JAC_TEST_RSS_LOG",
        crash_prefix="jac-test-crash-"
    );
    if inline {
        pool.run_inline();
    } else {
        pool.run();
    }
}
