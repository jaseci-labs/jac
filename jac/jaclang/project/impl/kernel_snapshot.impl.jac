impl manifest_sets -> ManifestSets {
    return ManifestSets(
        seed_paths=list(SEED_PATHS),
        native_only_files=list(NATIVE_ONLY_REL),
        native_only_dirs=list(NATIVE_ONLY_DIR_REL),
        native_lowered=list(NATIVE_LOWERED_PATHS)
    );
}

impl python_interface(
    path: str, options: CompileOptions, scratch: (JacProgram | None) = None
) -> (PythonInterface | None) {
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

impl interface_dependencies(iface: PythonInterface) -> list[str] {
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

impl interface_wanted(path: str) -> bool {
    if not os.path.isfile(path) {
        return False;
    }
    if is_compiler_source_path(path) {
        return path.endswith(".py") or path.endswith(".jac");
    }
    return path.endswith(".py") or path.endswith(".pyi");
}

impl forget_interface_memo {
    _IFACE_MEMO.clear();
    _IFACE_REFUSED.clear();
}

impl file_stamp(path: str) -> str {
    try {
        st = os.stat(path);
    } except OSError {
        return "";
    }
    return f"{st.st_mtime_ns}:{st.st_size}";
}

impl interface_cache_file(path: str) -> str {
    import hashlib;

    key = hashlib.sha256(
        (running_compiler_digest() + "\x1f" + path).encode("utf-8")
    ).hexdigest();
    return os.path.join(
        str(get_jir_cache_dir()), "kernel_ifaces", key[:2], key + ".json"
    );
}

impl cached_interface(path: str) -> (PythonInterface | None) {
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

impl dependency_stamps(deps: list[str]) -> list[str] {
    return [file_stamp(d) for d in deps];
}

impl remember_interface(iface: PythonInterface, deps: list[str]) {
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

impl served_interface(
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

impl catalog_build_blocker(artifact: any) -> str {
    if sealed._jaclang_image() is not None {
        return SEALED_CATALOG_MISSING;
    }
    if not artifact.host_supported() {
        return "the stub catalog cannot be built on this host";
    }

    if offline_mode() {
        import from jaclang.artifacts.router { artifact_named }
        typeshed = artifact_named("typeshed").built();
        if typeshed.found is None {
            return (
                f"the typeshed stubs it is built from are missing ({typeshed.describe()}), "
                "and this project is offline ([network] offline)"
            );
        }
    }
    return artifact.unavailable_reason() or artifact.build_blocker();
}

impl build_stub_catalog {
    artifact = artifact_named("stubcat");
    blocker = catalog_build_blocker(artifact);
    if blocker {
        raise StubCatalogMissing(catalog_missing_message(blocker));
    }
    lock_path = artifact.checkout_path() + ".build.lock";
    lock = FileLock(lock_path, timeout=0.0);
    try {
        try {
            lock.acquire();
        } except TimeoutError {
            sys.stderr.write(
                "jac: waiting for another jac process to finish building the stub catalog\n"
            );
            sys.stderr.flush();
            lock = FileLock(lock_path);
            lock.acquire();
        }
    } except OSError as e {
        raise StubCatalogMissing(
            catalog_missing_message(f"cannot lock {lock_path} ({e})")
        ) from None;
    }
    try {
        forget("stubcat");
        if artifact.built().found is not None {
            return;
        }
        sys.stderr.write(
            "jac: the native compiler kernel needs the stub catalog (pre-resolved "
            "typeshed types); building stubcat now (one time, about 2 minutes)\n"
        );
        sys.stderr.flush();
        try {
            build(["stubcat"], _to_stderr, strict=True);
        } except Exception as e {
            raise StubCatalogMissing(catalog_missing_message(str(e))) from None;
        }
    } finally {
        lock.release();
    }
}

impl _to_stderr(line: str) {
    sys.stderr.write(line + "\n");
    sys.stderr.flush();
}

impl catalog_missing_message(cause: str) -> str {
    fix = "reinstall jac"
        if cause == SEALED_CATALOG_MISSING
        else "run `jac native build stubcat`, then rerun";
    return (
        "jac: the native compiler kernel needs the stub catalog, which is missing "
        "and could not be built\n"
        f"  cause: {cause}\n"
        f"  fix:   {fix}"
    );
}

impl require_stub_catalog(host: HostServices, program: JacProgram) -> bool {
    compiler = host.compiler_for(program);
    compiler.ensure_stub_catalog();
    if host.has_active_stub_catalog() {
        return True;
    }

    if catalog_disabled() {
        return False;
    }
    build_stub_catalog();

    forget("stubcat");
    reset_catalog_cache();
    compiler._stub_catalog_tried = False;
    compiler.ensure_stub_catalog();
    if not host.has_active_stub_catalog() {
        raise StubCatalogMissing(
            catalog_missing_message("it was built but could not be opened")
        );
    }
    return True;
}

impl session_inputs(
    host: HostServices, program: JacProgram, path: str, options: CompileOptions
) -> KernelInputs {
    catalog_dir = "";
    catalog_active = require_stub_catalog(host, program);
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
    return inputs;
}

impl KernelSnapshot.inputs -> KernelInputs {
    return self.seed;
}

impl KernelSnapshot.record_interface(
    program: JacProgram, module: uni.Module, products: UnitProducts
) {
    import base64;

    evaluator = program.get_type_evaluator();
    pkg_dir = os.path.dirname(os.path.realpath(module.loc.mod_path));
    try {
        data = build_module_iface(module, evaluator, pkg_dir);
        shape = module_iface_shape(module, evaluator, pkg_dir);
    } except IncoherentInterface {
        return;
    }
    products.iface = base64.b64encode(data).decode("ascii");
    products.iface_shape = shape;
}

impl KernelSnapshot.text -> str {
    return self.seed.to_json();
}

impl KernelSnapshot.ask(method: str, key: str) -> str {
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
        failed = f"no answer for {method} {key!r}: {type(err).__name__}: {err}";
        self.failures.append(failed);
        kernel_note(failed);
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
    if learner.inputs.osp_core_js {
        record["osp_core_js"] = learner.inputs.osp_core_js;
    }
    if learner.inputs.client_stub_globals_known {
        record["client_stub_globals"] = list(learner.inputs.client_stub_globals);
        record["client_stub_globals_known"] = True;
    }
    if refused {
        record[HOST_ONLY_ANSWER] = refused;
    }
    return json.dumps(record) if record else "";
}

impl KernelSnapshot.answer(learner: KernelHost, method: str, fields: list[str]) -> str {
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
    } elif method in PATH_QUESTIONS {
        self.path_answers(learner, method, key);
    } elif method == "client_osp_core_js" {
        learner.client_osp_core_js();
    } elif method == "client_stub_globals" {
        learner.client_stub_globals();
    } elif method == "check_settings" {
        learner.check_settings(key);
    } elif method == "is_untyped_third_party" {
        learner.is_untyped_third_party(key);
    } elif method == "sibling_declaration" {
        learner.sibling_declaration(key);
    } elif method == "client_pulls" {
        learner.client_pulls(key);
    } elif method == "native_fact" and len(fields) >= 2 {
        learner.native_fact(fields[0], KEY_SEP.join(fields[1:]));
    } elif method == "held_native_iface" and len(fields) == 2 {
        iface_text = "";
        if self.options.unit_codegen_identity(fields[0]) == fields[1] {
            iface_text = self.host.held_native_iface(
                self.program, fields[0], self.options
            );
        }
        learner.inputs.native_ifaces[pair_key(fields[0], fields[1])] = iface_text;
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

impl KernelSnapshot.path_answer(learner: KernelHost, method: str, path: str) {
    if method == "project_root" {
        learner.project_root(path);
    } elif method == "project_facts" {
        learner.project_facts(path);
    } elif method == "workspace" {
        learner.workspace(path);
    } elif method == "app_for_path" {
        learner.app_for_path(path);
    } elif method == "lint_settings" {
        learner.lint_settings(path);
    }
}

impl KernelSnapshot.path_answers(learner: KernelHost, method: str, path: str) {
    self.path_answer(learner, method, path);
    for related in PATH_QUESTIONS {
        if related != method {
            try {
                self.path_answer(learner, related, path);
            } except Exception {}
        }
    }
}

impl KernelSnapshot.failure_note -> str {
    return f"; the host said: {self.failures[-1]}" if self.failures else "";
}

impl KernelSnapshot.serve_interface(learner: KernelHost, module_file: str) {
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

impl KernelSnapshot.emits(path: str) -> bool {
    if not path.endswith(".jac") or is_annex(path) or is_compiler_source_path(path) {
        return False;
    }
    normalized = path.replace("\\", "/");
    if any(marker in normalized for marker in THIRD_PARTY_DIRS) {
        return False;
    }
    return self.emit_cached or not compiled_already(path);
}

impl kernel_note(message: str) {
    if os.environ.get("JAC_KERNEL_TRACE") {
        report_stream().write(f"[kernel host] {message}\n");
    }
}

impl compiled_already(path: str) -> bool {
    try {
        return is_module_cache_valid(path, get_module_cache_path(path));
    } except Exception {
        return False;
    }
}

impl kernel_snapshot(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    emit_closure: bool = False,
    emit_cached: bool = True,
    seeds: (list[PythonInterface] | None) = None
) -> KernelSnapshot {
    seed = session_inputs(host, program, path, options);
    seed.emit_closure = emit_closure;
    seeds = seeds or [];
    seed.python_ifaces.extend(seeds);
    snapshot = KernelSnapshot(
        host=host, program=program, options=options, seed=seed, emit_cached=emit_cached
    );
    snapshot.shipped.update(iface.path for iface in seeds);
    if in_other_compiler_tree(path) {
        snapshot.other_compiler = path;
    }
    return snapshot;
}

impl HostReferenceSession.enter_compile(ctx: SessionContext) -> CompileFrame {
    return self.compiler.enter_compile(ctx);
}

impl HostReferenceSession.leave_compile(ctx: SessionContext, frame: CompileFrame) {
    self.compiler.leave_compile(ctx, frame);
}

impl HostReferenceSession.finish_compile(frame: CompileFrame) {
    self.compiler.finish_compile(frame);
}

impl HostReferenceSession.check_crash(crash: Exception, file_path: str) {
    self.compiler.check_crash(crash, file_path);
}

impl HostReferenceSession.closure_options -> (CompileOptions | None) {
    return self.compiler.closure_options();
}

impl HostReferenceSession.assemble_python(program: JacProgram, module: uni.Module) {
    self.compiler.assemble_python(program, module);
}

impl HostReferenceSession.assemble_native(
    program: JacProgram, module: uni.Module, checking: bool
) {
    self.compiler.assemble_native(program, module, checking);
}

impl HostReferenceSession.run_module(
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

impl host_analysis(
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

impl call_kernel(
    kernel: NativeCompiler,
    kind: KernelEntry,
    inputs_json: str,
    path: str,
    source: (str | None),
    ask: (Callable[[str, str], str] | None) = None
) -> str {
    import from ctypes { c_int64, c_void_p }
    lib = kernel.lib;
    run = getattr(lib, kind.call);
    run.argtypes = [c_void_p, c_void_p, c_int64] * 3 + [c_int64];
    run.restype = c_int64;
    take = getattr(lib, kind.take);
    take.argtypes = [];
    take.restype = c_void_p;

    def deliver(method: str, key: str) -> None {
        data = ask(method, key).encode() if ask is not None else b"";
        if not data {
            return;
        }
        held = lib.jac_str_new(data, len(data));
        try {
            lib.jc_answer(c_void_p(held), c_void_p(held), c_int64(len(data)));
        } finally {
            lib.jac_release(held);
        }
    }
    if ask is not None {
        lib.jc_set_asker.argtypes = [c_void_p];
        lib.jc_set_asker.restype = c_int64;
        lib.jc_answer.argtypes = [c_void_p, c_void_p, c_int64];
        lib.jc_answer.restype = c_int64;
        lib.jc_set_asker(c_void_p(id(deliver)));
    }
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
        if ask is not None {
            lib.jc_set_asker(c_void_p(0));
        }
    }
    return kernel._take(take()) or "";
}

impl send_frame(fd: int, tag: bytes, data: bytes) {
    packet = tag + len(data).to_bytes(8, "little") + data;
    sent = 0;
    while sent < len(packet) {
        sent += os.write(fd, packet[sent:]);
    }
}

impl read_exactly(fd: int, size: int) -> (bytes | None) {
    parts: list[bytes] = [];
    left = size;
    while left > 0 {
        part = os.read(fd, min(left, 1 << 20));
        if not part {
            return None;
        }
        parts.append(part);
        left -= len(part);
    }
    return b"".join(parts);
}

impl read_frame(fd: int) -> (tuple[bytes, bytes] | None) {
    head = read_exactly(fd, 9);
    if head is None {
        return None;
    }
    data = read_exactly(fd, int.from_bytes(head[1:], "little"));
    if data is None {
        return None;
    }
    return (head[:1], data);
}

impl call_kernel_isolated(
    kernel: NativeCompiler,
    kind: KernelEntry,
    inputs_json: str,
    path: str,
    source: (str | None),
    ask: (Callable[[str, str], str] | None) = None
) -> str {
    if not hasattr(os, "fork") {
        return call_kernel(kernel, kind, inputs_json, path, source, ask);
    }
    (report_in, report_out) = os.pipe();
    (answer_in, answer_out) = os.pipe();
    pid = os.fork();
    if pid == 0 {
        code = 0;
        try {
            import gc;
            gc.disable();
            os.close(report_in);
            os.close(answer_out);

            def relay(method: str, key: str) -> str {
                send_frame(
                    report_out, ASK_FRAME, (method + "\0" + key).encode("utf-8")
                );
                answered = read_frame(answer_in);
                return answered[1].decode("utf-8") if answered is not None else "";
            }
            payload = call_kernel(
                kernel,
                kind,
                inputs_json,
                path,
                source,
                relay if ask is not None else None
            ).encode(
                "utf-8"
            );
            send_frame(report_out, REPORT_FRAME, payload);
            os.close(report_out);
        } except BaseException {
            code = 1;
        } finally {
            os._exit(code);
        }
    }
    os.close(report_out);
    os.close(answer_in);
    payload = b"";
    try {
        while True {
            frame = read_frame(report_in);
            if frame is None {
                break;
            }
            if frame[0] == REPORT_FRAME {
                payload = frame[1];
                break;
            }
            (method, _, key) = frame[1].decode("utf-8").partition("\0");
            answer = ask(method, key) if ask is not None else "";
            send_frame(answer_out, ASK_FRAME, answer.encode("utf-8"));
        }
    } except OSError {} finally {
        os.close(report_in);
        os.close(answer_out);
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

impl in_other_compiler_tree(path: str) -> bool {
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

impl other_compiler_dir(folder: str) -> bool {
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

impl native_stdlib_misses(misses: list[str]) -> bool {
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

impl host_only_miss(miss: str) -> bool {
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

impl host_deferred(outcome: AnalysisReport) -> bool {
    if outcome.misses and all(host_only_miss(miss) for miss in outcome.misses) {
        return True;
    }
    return outcome.status == ANALYSIS_CRASHED
        and NATIVE_INT_OVERFLOW in outcome.message;
}

impl loaded_kernel(kind: KernelEntry) -> NativeCompiler {
    kernel = ensure_loaded();
    if kernel is None {
        raise KernelAnalysisError("no native compiler kernel is available");
    }
    if not hasattr(kernel.lib, kind.call) {
        raise KernelAnalysisError(f"the loaded kernel has no {kind.call}");
    }
    return kernel;
}

impl call_with_asker(
    kernel: NativeCompiler,
    kind: KernelEntry,
    snapshot: KernelSnapshot,
    path: str,
    source: (str | None),
    isolated: bool
) -> str {
    call = call_kernel_isolated if isolated else call_kernel;
    return call(kernel, kind, snapshot.text(), path, source, snapshot.ask);
}

impl kernel_analysis(
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
        raise KernelAnalysisError(outcome.message + detail + snapshot.failure_note());
    }
    return outcome;
}

impl other_compiler_report(path: str, reached: str) -> AnalysisReport {
    return AnalysisReport(
        entry_path=path, misses=[f"{OTHER_COMPILER_MISS}: {reached}"]
    );
}

impl kernel_census -> HostCensus {
    if not _TOTALS {
        _TOTALS.append(HostCensus());
    }
    return _TOTALS[0];
}

impl reset_kernel_census {
    _TOTALS.clear();
}

impl record_kernel_session(census: HostCensus, path: str) {
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

impl report_kernel_census {
    report_stream().write(kernel_census().summary() + "\n");
}

impl report_stream -> any {
    return sys.__stderr__ or sys.stderr;
}
