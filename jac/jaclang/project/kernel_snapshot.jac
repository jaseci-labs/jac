import os;
import sys;
import time;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.host {
    HostServices,
    active_host,
    install_host,
    kernel_host_mode
}
import from jaclang.compiler.frontend.kernel_inputs {
    KEY_SEP,
    KernelInputs,
    ManifestSets,
    NpmAnswer,
    PythonInterface,
    answers_to_dict,
    pair_key,
    request_of
}
import from jaclang.compiler.frontend.kernel_host {
    EMIT_QUESTION,
    HOST_ONLY_ANSWER,
    HostAsker,
    HostCensus,
    KernelHost
}
import from jaclang.compiler.frontend.kernel_analyze {
    ANALYSIS_CRASHED,
    ANALYSIS_OK,
    AnalysisReport,
    analysis_report,
    run_kernel_analysis
}
import from jaclang.compiler.driver.module_analysis { ModuleAnalysis, analyze_module }
import from jaclang.compiler.driver.session_compile {
    CompileFrame,
    SessionContext,
    SessionHooks,
    compile_in_session
}
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.codeinfo { is_compiler_source_path }
import type from jaclang.compiler.native_compiler { NativeCompiler }

glob _IFACE_MEMO: dict[str, tuple[list[str], list[str], PythonInterface]] = {},
     _IFACE_REFUSED: dict[str, str] = {},
     _IFACE_BUILT: list[float] = [0.0, 0.0],
     _OTHER_COMPILER_DIRS: dict[str, bool] = {},
     NATIVE_INT_OVERFLOW: str = "integer overflow",
     OTHER_COMPILER_MISS: str = "other_compiler",
     INTERFACE_QUESTIONS: tuple[str, ...] = ("compile_module", "parse_python"),
     NPM_QUESTIONS: tuple[str, ...] = (
         "has_npm_package",
         "resolve_npm_package",
         "npm_declarations"
     ),
     THIRD_PARTY_DIRS: tuple[str, ...] = ("/site-packages/", "/dist-packages/"),
     _TOTALS: list[HostCensus] = [],
     _EXIT_REPORT: list[bool] = [];

class KernelAnalysisError(RuntimeError) {}

def manifest_sets -> ManifestSets {
    import from jaclang.bootstrap_manifest {
        NATIVE_LOWERED_PATHS,
        NATIVE_ONLY_DIR_REL,
        NATIVE_ONLY_REL,
        SEED_PATHS
    }
    return ManifestSets(
        seed_paths=list(SEED_PATHS),
        native_only_files=list(NATIVE_ONLY_REL),
        native_only_dirs=list(NATIVE_ONLY_DIR_REL),
        native_lowered=list(NATIVE_LOWERED_PATHS)
    );
}

def python_interface(
    path: str, options: CompileOptions, scratch: (JacProgram | None) = None
) -> (PythonInterface | None) {
    import from jaclang.compiler.types.stubcat.writer {
        IncoherentInterface,
        build_module_iface
    }
    resolved = os.path.realpath(path);
    if scratch is None {
        scratch = JacProgram();
    }
    try {
        mod = scratch.compile(resolved, options=options.for_symbols());
        pkg_dir = os.path.dirname(resolved);
        data = build_module_iface(mod, scratch.get_type_evaluator(), pkg_dir);
    } except IncoherentInterface {
        return None;
    }
    return PythonInterface(path=resolved, pkg_dir=pkg_dir, data=data);
}

def interface_dependencies(iface: PythonInterface) -> list[str] {
    import from jaclang.compiler.types.stubcat.format { MOD_EXTERNAL }
    import from jaclang.compiler.types.stubcat.modiface { open_module_iface }
    catalog = open_module_iface(iface.data, iface.pkg_dir);
    if catalog is None {
        return [];
    }
    out: list[str] = [];
    for (_, rel, flags, scope_id, _) in catalog._mod_recs {
        if (flags & MOD_EXTERNAL) != 0 or scope_id < 0 {
            dep = os.path.realpath(catalog.abs_path(rel));
            if dep != iface.path and dep not in out {
                out.append(dep);
            }
        }
    }
    return out;
}

def interface_wanted(path: str) -> bool {
    if not os.path.isfile(path) {
        return False;
    }
    if is_compiler_source_path(path) {
        return path.endswith(".py") or path.endswith(".jac");
    }
    return path.endswith(".py");
}

def file_stamp(path: str) -> str {
    try {
        st = os.stat(path);
    } except OSError {
        return "";
    }
    return f"{st.st_mtime_ns}:{st.st_size}";
}

def interface_cache_file(path: str) -> str {
    import hashlib;
    import from jaclang.compiler.driver.jir {
        get_jir_cache_dir,
        running_compiler_digest
    }
    key = hashlib.sha256(
        (running_compiler_digest() + "\x1f" + path).encode("utf-8")
    ).hexdigest();
    return os.path.join(
        str(get_jir_cache_dir()), "kernel_ifaces", key[:2], key + ".json"
    );
}

def cached_interface(path: str) -> (PythonInterface | None) {
    import base64;
    import json;
    memo = _IFACE_MEMO.get(path);
    if memo is not None and memo[0] == dependency_stamps(memo[1]) {
        return memo[2];
    }
    try {
        with open(interface_cache_file(path), "r", encoding="utf-8") as f {
            record = json.load(f);
        }
    } except (OSError, ValueError) {
        return None;
    }
    deps: list[str] = [str(d) for d in record.get("deps", [])];
    if record.get("stamps") != dependency_stamps(deps) {
        return None;
    }
    iface = PythonInterface(
        path=path,
        pkg_dir=str(record.get("pkg_dir", "")),
        data=base64.b64decode(str(record.get("data", "")))
    );
    _IFACE_MEMO[path] = (record["stamps"], deps, iface);
    return iface;
}

def dependency_stamps(deps: list[str]) -> list[str] {
    return [file_stamp(d) for d in deps];
}

def remember_interface(iface: PythonInterface, deps: list[str]) {
    import base64;
    import json;
    tracked = [iface.path] + deps;
    stamps = dependency_stamps(tracked);
    _IFACE_MEMO[iface.path] = (stamps, tracked, iface);
    target = interface_cache_file(iface.path);
    try {
        os.makedirs(os.path.dirname(target), exist_ok=True);
        scratch_file = target + f".{os.getpid()}.tmp";
        with open(scratch_file, "w", encoding="utf-8") as f {
            json.dump(
                {
                    "deps": tracked,
                    "stamps": stamps,
                    "pkg_dir": iface.pkg_dir,
                    "data": base64.b64encode(iface.data).decode("ascii")
                },
                f
            );
        }
        os.replace(scratch_file, target);
    } except OSError {}
}

def served_interface(
    path: str, options: CompileOptions, scratch: JacProgram
) -> (PythonInterface | None) {
    if not interface_wanted(path) {
        return None;
    }
    iface = cached_interface(path);
    if iface is not None {
        return iface;
    }
    stamp = file_stamp(path);
    if _IFACE_REFUSED.get(path) == stamp {
        return None;
    }
    began = time.monotonic();
    iface = python_interface(path, options, scratch);
    _IFACE_BUILT[0] += 1.0;
    _IFACE_BUILT[1] += time.monotonic() - began;
    if iface is None {
        _IFACE_REFUSED[path] = stamp;
        return None;
    }
    remember_interface(iface, interface_dependencies(iface));
    return iface;
}

def session_inputs(
    host: HostServices, program: JacProgram, path: str, options: CompileOptions
) -> KernelInputs {
    import from jaclang.compiler.driver.bccache { host_layout_tables }
    import from jaclang.project.modresolver { get_jac_search_paths, get_typeshed_paths }
    import from jaclang.compiler.types.stubcat.locate { catalog_origin }
    import from jaclang.compiler.frontend.host { package_root }
    catalog_dir = "";
    host.compiler_for(program).ensure_stub_catalog();
    catalog_active = host.has_active_stub_catalog();
    if catalog_active {
        import from jaclang.jac0core.stubcat_hook { active }
        catalog: any = active();
        catalog_dir = str(catalog.pkg_dir) if catalog is not None else "";
    }
    origin = catalog_origin() if catalog_active else None;
    natives = program._natives;
    inputs = KernelInputs(
        entry_path=path,
        package_root=package_root(),
        module_projection=options.module_projection(),
        target_app=options.target_app or "",
        request=request_of(options),
        project_defaults=host.project_defaults(),
        host_platform=host.host_platform(),
        ct_environment=host.ct_environment(),
        stub_catalog_active=catalog_active,
        stub_catalog_dir=catalog_dir,
        stub_catalog_file=origin.path if origin is not None else "",
        stub_catalog_offset=origin.offset if origin is not None else 0,
        stub_catalog_length=origin.length if origin is not None else 0,
        typeshed_roots=get_typeshed_paths(),
        search_paths=get_jac_search_paths(os.path.dirname(os.path.abspath(path))),
        native_session_active=natives is not None and natives.session is not None,
        manifest=manifest_sets(),
        layout=host_layout_tables()
    );
    for app in {"", options.target_app or ""} {
        inputs.check_settings[app] = host.check_settings(app);
    }
    inputs.lint_of[""] = host.lint_settings("");
    (inputs.native_pipeline, inputs.native_pipeline_reason) = host.native_pipeline_available();
    inputs.native_pipeline_known = True;
    inputs.target_triple = host.default_target_triple();
    inputs.target_triple_known = True;
    if not options.no_cgen {
        inputs.osp_core_js = host.client_osp_core_js();
        inputs.client_stub_globals = host.client_stub_globals();
        inputs.client_stub_globals_known = True;
    }
    return inputs;
}

obj KernelSnapshot(HostAsker) {
    has host: HostServices,
        program: JacProgram,
        options: CompileOptions,
        seed: KernelInputs,
        emit_cached: bool = True,
        scratch: (JacProgram | None) = None,
        shipped: set[str] = set(),
        asked: int = 0,
        ask_seconds: float = 0.0,
        other_compiler: str = "";

    def inputs -> KernelInputs {
        return self.seed;
    }

    def text -> str {
        return self.seed.to_json();
    }

    def ask(method: str, key: str) -> str {
        import json;
        began = time.monotonic();
        self.asked += 1;
        learner = KernelHost(inputs=KernelInputs(), fallback=self.host);
        refused = "";
        asking = active_host();
        install_host(self.host);
        try {
            refused = self.answer(learner, method, key.split(KEY_SEP));
        } except Exception as err {
            kernel_note(f"no answer for {method} {key!r}: {type(err).__name__}: {err}");
            return "";
        } finally {
            install_host(asking);
            self.ask_seconds += time.monotonic() - began;
        }
        record = {
            name: value
            for (name, value) in answers_to_dict(learner.inputs).items()
            if value
        };
        if refused {
            record[HOST_ONLY_ANSWER] = refused;
        }
        return json.dumps(record) if record else "";
    }

    def answer(learner: KernelHost, method: str, fields: list[str]) -> str {
        key = fields[0];
        if method == "resolve_module" and len(fields) == 3 {
            (found, _) = learner.resolve_module(
                fields[1], fields[2], string_spec=fields[0] == "1"
            );
            if found and in_other_compiler_tree(found) {
                self.other_compiler = found;
                return f"{OTHER_COMPILER_MISS}: {found}";
            }
        } elif method == "resolve_local_module" and len(fields) == 2 {
            learner.resolve_local_module(fields[0], fields[1].split("/"));
        } elif method == "project_root" {
            learner.project_root(key);
        } elif method == "project_facts" {
            learner.project_facts(key);
        } elif method == "workspace" {
            learner.workspace(key);
        } elif method == "app_for_path" {
            learner.app_for_path(key);
        } elif method == "lint_settings" {
            learner.lint_settings(key);
        } elif method == "check_settings" {
            learner.check_settings(key);
        } elif method == "native_verdict" {
            learner.native_verdict(key, self.program);
        } elif method == "is_untyped_third_party" {
            learner.is_untyped_third_party(key);
        } elif method == "sibling_declaration" {
            learner.sibling_declaration(key);
        } elif method == "jac_virtual_module_path" {
            learner.jac_virtual_module_path(key);
        } elif method == "is_path_alias" and len(fields) == 2 {
            learner.is_path_alias(fields[0], fields[1]);
        } elif method == "declared_dependencies" and len(fields) == 2 {
            learner.declared_dependencies(fields[0], fields[1]);
        } elif method in NPM_QUESTIONS and len(fields) == 2 {
            if learner.has_npm_package(fields[0], fields[1]) {
                learner.resolve_npm_package(fields[0], fields[1]);
                learner.npm_declarations(fields[0], fields[1]);
            } else {
                held = learner._npm[pair_key(fields[0], fields[1])];
                held.entry_known = True;
                held.declarations_known = True;
            }
        } elif method in INTERFACE_QUESTIONS {
            self.serve_interface(learner, os.path.realpath(key));
        } elif method == EMIT_QUESTION {
            learner.inputs.emit_of[key] = self.emits(key);
        }
        return "";
    }

    def serve_interface(learner: KernelHost, module_file: str) {
        if module_file in self.shipped {
            return;
        }
        self.shipped.add(module_file);
        if self.scratch is None {
            self.scratch = JacProgram();
        }
        iface = served_interface(module_file, self.options, self.scratch);
        if iface is not None {
            learner.inputs.python_ifaces.append(iface);
        }
    }

    def emits(path: str) -> bool {
        import from jaclang.jac0core.ext_registry { is_annex }
        if not path.endswith(".jac")
            or is_annex(path)
            or is_compiler_source_path(path) {
            return False;
        }
        normalized = path.replace("\\", "/");
        if any(marker in normalized for marker in THIRD_PARTY_DIRS) {
            return False;
        }
        return self.emit_cached or not compiled_already(path);
    }
}

def kernel_note(message: str) {
    if os.environ.get("JAC_KERNEL_TRACE") {
        report_stream().write(f"[kernel host] {message}\n");
    }
}

def compiled_already(path: str) -> bool {
    import from jaclang.compiler.driver.jir {
        get_module_cache_path,
        is_module_cache_valid
    }
    try {
        return is_module_cache_valid(path, get_module_cache_path(path));
    } except Exception {
        return False;
    }
}

def kernel_snapshot(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    emit_closure: bool = False,
    emit_cached: bool = True
) -> KernelSnapshot {
    seed = session_inputs(host, program, path, options);
    seed.emit_closure = emit_closure;
    snapshot = KernelSnapshot(
        host=host, program=program, options=options, seed=seed, emit_cached=emit_cached
    );
    if in_other_compiler_tree(path) {
        snapshot.other_compiler = path;
    }
    return snapshot;
}

obj HostReferenceSession(SessionHooks) {
    has compiler: any,
        entry_path: str,
        task: (ModuleAnalysis | None) = None;

    def enter_compile(ctx: SessionContext) -> CompileFrame {
        return self.compiler.enter_compile(ctx);
    }

    def leave_compile(ctx: SessionContext, frame: CompileFrame) {
        self.compiler.leave_compile(ctx, frame);
    }

    def finish_compile(frame: CompileFrame) {
        self.compiler.finish_compile(frame);
    }

    def check_crash(crash: Exception, file_path: str) {
        self.compiler.check_crash(crash, file_path);
    }

    def closure_options -> (CompileOptions | None) {
        return self.compiler.closure_options();
    }

    def assemble_python(program: JacProgram, module: uni.Module) {
        self.compiler.assemble_python(program, module);
    }

    def assemble_native(program: JacProgram, module: uni.Module, checking: bool) {
        self.compiler.assemble_native(program, module, checking);
    }

    def run_module(
        file_path: str,
        target_program: JacProgram,
        use_str: (str | None),
        options: CompileOptions
    ) -> uni.Module {
        if self.task is None and os.path.realpath(file_path) == self.entry_path {
            task = analyze_module(target_program, file_path, options, use_str);
            self.task = task;
            return task.module;
        }
        return self.compiler.run_module(file_path, target_program, use_str, options);
    }
}

def host_analysis(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: (str | None) = None
) -> AnalysisReport {
    session = HostReferenceSession(
        compiler=host.compiler_for(program), entry_path=os.path.realpath(path)
    );
    status = ANALYSIS_OK;
    message = "";
    try {
        compile_in_session(session, path, program, source, options);
    } except Exception as err {
        status = ANALYSIS_CRASHED;
        message = f"{type(err).__name__}: {err}";
    }
    tasks = [session.task] if session.task is not None else [];
    return analysis_report(program, path, tasks, status, message);
}

obj KernelEntry {
    has call: str,
        take: str;
}

glob ANALYZE_ENTRY: KernelEntry = KernelEntry(
         call="jc_analyze", take="jc_take_analysis"
     ),
     COMPILE_ENTRY: KernelEntry = KernelEntry(
         call="jc_compile", take="jc_take_compile"
     );

def call_kernel(
    kernel: NativeCompiler,
    kind: KernelEntry,
    inputs_json: str,
    path: str,
    source: (str | None)
) -> str {
    import from ctypes { c_int64, c_void_p }
    lib = kernel.lib;
    run = getattr(lib, kind.call);
    run.argtypes = [c_void_p, c_void_p, c_int64] * 3 + [c_int64];
    run.restype = c_int64;
    take = getattr(lib, kind.take);
    take.argtypes = [];
    take.restype = c_void_p;
    handles: list[int] = [];
    args: list[object] = [];
    try {
        for text in (inputs_json, path, source or "") {
            data = text.encode();
            handle = lib.jac_str_new(data, len(data));
            handles.append(handle);
            args.extend([c_void_p(handle), c_void_p(handle), c_int64(len(data))]);
        }
        args.append(c_int64(1 if source is not None else 0));
        run(*args);
    } finally {
        for handle in handles {
            lib.jac_release(handle);
        }
    }
    return kernel._take(take()) or "";
}

def call_kernel_isolated(
    kernel: NativeCompiler,
    kind: KernelEntry,
    inputs_json: str,
    path: str,
    source: (str | None)
) -> str {
    if not hasattr(os, "fork") {
        return call_kernel(kernel, kind, inputs_json, path, source);
    }
    (read_fd, write_fd) = os.pipe();
    pid = os.fork();
    if pid == 0 {
        code = 0;
        try {
            os.close(read_fd);
            payload = call_kernel(kernel, kind, inputs_json, path, source).encode(
                "utf-8"
            );
            sent = 0;
            while sent < len(payload) {
                sent += os.write(write_fd, payload[sent:]);
            }
            os.close(write_fd);
        } except BaseException {
            code = 1;
        } finally {
            os._exit(code);
        }
    }
    os.close(write_fd);
    with os.fdopen(read_fd, "rb") as reader {
        payload = reader.read();
    }
    (_, status) = os.waitpid(pid, 0);
    if os.WIFSIGNALED(status) {
        raise KernelAnalysisError(
            f"the kernel {kind.call} died with signal {os.WTERMSIG(status)}"
        );
    }
    if not os.WIFEXITED(status) or os.WEXITSTATUS(status) != 0 or not payload {
        raise KernelAnalysisError(f"the kernel {kind.call} exited without a report");
    }
    return payload.decode("utf-8");
}

def in_other_compiler_tree(path: str) -> bool {
    if not path.endswith((".jac", ".py")) {
        return False;
    }
    folder = os.path.dirname(path);
    known = _OTHER_COMPILER_DIRS.get(folder);
    if known is None {
        known = other_compiler_dir(folder);
        _OTHER_COMPILER_DIRS[folder] = known;
    }
    return known;
}

def other_compiler_dir(folder: str) -> bool {
    import from jaclang.project.modresolver { COMPILER_PACKAGE }
    current = os.path.realpath(folder);
    if is_compiler_source_path(os.path.join(current, "x.jac")) {
        return False;
    }
    while True {
        above = os.path.dirname(current);
        if above == current {
            return False;
        }
        if os.path.basename(current) == COMPILER_PACKAGE
            and os.path.isdir(os.path.join(current, "jac0core")) {
            return True;
        }
        current = above;
    }
}

def native_stdlib_misses(misses: list[str]) -> bool {
    import from jaclang.compiler.frontend.codeinfo { native_stdlib_root }
    stdlib_dir = native_stdlib_root();
    if not misses or not stdlib_dir {
        return False;
    }
    prefix = os.path.join(os.path.realpath(stdlib_dir), "");
    for miss in misses {
        asked = miss.partition(": ")[2];
        if not os.path.realpath(asked).startswith(prefix) {
            return False;
        }
    }
    return True;
}

def host_only_miss(miss: str) -> bool {
    (kind, _, asked) = miss.partition(": ");
    if kind == OTHER_COMPILER_MISS {
        return True;
    }
    if native_stdlib_misses([miss]) {
        return True;
    }
    normalized = asked.replace("\\", "/");
    return kind == "parse_python"
        and any(marker in normalized for marker in THIRD_PARTY_DIRS);
}

def host_deferred(outcome: AnalysisReport) -> bool {
    if outcome.misses and all(host_only_miss(miss) for miss in outcome.misses) {
        return True;
    }
    return outcome.status == ANALYSIS_CRASHED
        and NATIVE_INT_OVERFLOW in outcome.message;
}

def loaded_kernel(kind: KernelEntry) -> NativeCompiler {
    import from jaclang.compiler.native_compiler { ensure_loaded }
    kernel = ensure_loaded();
    if kernel is None {
        raise KernelAnalysisError("no native compiler kernel is available");
    }
    if not hasattr(kernel.lib, kind.call) {
        raise KernelAnalysisError(f"the loaded kernel has no {kind.call}");
    }
    return kernel;
}

def call_with_asker(
    kernel: NativeCompiler,
    kind: KernelEntry,
    snapshot: KernelSnapshot,
    path: str,
    source: (str | None),
    isolated: bool
) -> str {
    import from ctypes { c_int64, c_void_p }
    lib = kernel.lib;
    lib.jc_set_asker.argtypes = [c_void_p];
    lib.jc_set_asker.restype = c_int64;
    lib.jc_answer.argtypes = [c_void_p, c_void_p, c_int64];
    lib.jc_answer.restype = c_int64;

    def deliver(method: str, key: str) -> None {
        data = snapshot.ask(method, key).encode();
        if not data {
            return;
        }
        handle = lib.jac_str_new(data, len(data));
        try {
            lib.jc_answer(c_void_p(handle), c_void_p(handle), c_int64(len(data)));
        } finally {
            lib.jac_release(handle);
        }
    }
    call = call_kernel_isolated if isolated else call_kernel;
    lib.jc_set_asker(c_void_p(id(deliver)));
    try {
        return call(kernel, kind, snapshot.text(), path, source);
    } finally {
        lib.jc_set_asker(c_void_p(0));
    }
}

def kernel_analysis(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: (str | None) = None,
    in_process: bool = False,
    isolated: bool = False
) -> AnalysisReport {
    snapshot = kernel_snapshot(host, program, path, options);
    if snapshot.other_compiler {
        return other_compiler_report(path, snapshot.other_compiler);
    }
    if in_process {
        outcome = run_kernel_analysis(snapshot.text(), path, source, snapshot);
    } else {
        kernel = loaded_kernel(ANALYZE_ENTRY);
        outcome = AnalysisReport.from_json(
            call_with_asker(kernel, ANALYZE_ENTRY, snapshot, path, source, isolated)
        );
    }
    if outcome.status == ANALYSIS_CRASHED and not host_deferred(outcome) {
        detail = f" ({outcome.misses[-1]})" if outcome.misses else "";
        raise KernelAnalysisError(outcome.message + detail);
    }
    return outcome;
}

def other_compiler_report(path: str, reached: str) -> AnalysisReport {
    return AnalysisReport(
        entry_path=path, misses=[f"{OTHER_COMPILER_MISS}: {reached}"]
    );
}

def kernel_census -> HostCensus {
    if not _TOTALS {
        _TOTALS.append(HostCensus());
    }
    return _TOTALS[0];
}

def reset_kernel_census {
    _TOTALS.clear();
}

def record_kernel_session(census: HostCensus, path: str) {
    census.sessions += 1;
    census.entry_path = path;
    kernel_census().merge(census);
    if kernel_host_mode() != "census" {
        return;
    }
    if not _EXIT_REPORT {
        import atexit;
        _EXIT_REPORT.append(True);
        atexit.register(report_kernel_census);
    }
    if census.total_misses() {
        report_stream().write(f"[{path}] {census.summary()}\n");
    }
}

def report_kernel_census {
    report_stream().write(kernel_census().summary() + "\n");
}

def report_stream -> any {
    return sys.__stderr__ or sys.stderr;
}
