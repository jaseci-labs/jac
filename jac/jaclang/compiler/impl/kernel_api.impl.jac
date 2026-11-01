impl CompileResult.ok -> bool {
    return not self.errors;
}

impl CompileResult.unit(path: str) -> CompiledUnit {
    real = os.path.realpath(path);
    for candidate in self.units {
        if os.path.realpath(candidate.path) == real {
            return candidate;
        }
    }
    raise KernelError(f"the kernel compiled no unit for {path}");
}

impl CheckResult.ok -> bool {
    return not self.errors;
}

impl enter_world(project_root: str, search_paths: list[str], package_root: str) {
    import from jaclang.compiler.frontend.host { mark_kernel_resident, set_package_root }
    import from jaclang.project.modresolver { install_search_roots }
    if not package_root {
        raise KernelError("the request names no jaclang package root");
    }
    if not search_paths {
        raise KernelError("the request names no module search paths");
    }
    mark_kernel_resident();
    set_package_root(package_root);
    install_search_roots(search_paths);
}

impl source_span(loc: Span) -> SourceSpan {
    return SourceSpan(
        path=loc.mod_path,
        line=loc.first_line,
        col=loc.col_start,
        end_line=loc.last_line,
        end_col=loc.col_end
    );
}

impl kernel_diagnostic(alert: Alert, severity: str) -> KernelDiagnostic {
    code = alert.code;
    origin = alert.from_pass;
    hint = alert.help_text or (code.help_text if code is not None else None) or "";
    return KernelDiagnostic(
        code=code.code if code is not None else "",
        severity=severity,
        message=alert.msg,
        span=source_span(alert.loc),
        help=hint,
        pass_name=origin.__name__ if origin is not None else "",
        related=[
            RelatedNote(label=label, span=source_span(where))
            for (label, where) in alert.related
        ]
    );
}

impl other_compiler_diagnostic(path: str, root: str) -> KernelDiagnostic {
    import from jaclang.compiler.frontend.diagnostics { E1408 }
    return KernelDiagnostic(
        code=E1408.code,
        severity="error",
        message=E1408.format_message(path=path, root=root),
        span=SourceSpan(path=path, line=1, col=1, end_line=1, end_col=1),
        help=E1408.help_text or ""
    );
}

impl collect_diagnostics(
    program: JacProgram, errors: list[KernelDiagnostic], warnings: list[KernelDiagnostic]
) {
    for alert in program.errors_had {
        errors.append(kernel_diagnostic(alert, "error"));
    }
    for alert in program.warnings_had {
        warnings.append(kernel_diagnostic(alert, "warning"));
    }
}

impl merge_app_diagnostics(
    collected: list[tuple[str, list[KernelDiagnostic]]]
) -> list[KernelDiagnostic] {
    def key_of(diag: KernelDiagnostic) -> tuple[str, str, int, int, str, str] {
        return (
            diag.severity,
            diag.span.path,
            diag.span.line,
            diag.span.col,
            diag.code,
            diag.message
        );
    }
    seen_apps: dict[tuple[str, str, int, int, str, str], set[str]] = {};
    for (app_name, found) in collected {
        for diag in found {
            seen_apps.setdefault(key_of(diag), set()).add(app_name);
        }
    }
    merged: list[KernelDiagnostic] = [];
    emitted: set[tuple[str, str, int, int, str, str]] = set();
    for (app_name, found) in collected {
        for diag in found {
            key = key_of(diag);
            if len(seen_apps[key]) >= len(collected) {
                if key not in emitted {
                    emitted.add(key);
                    merged.append(diag);
                }
                continue;
            }
            tagged = copy.copy(diag);
            tagged.message = f"[app:{app_name}] {diag.message}";
            merged.append(tagged);
        }
    }
    return merged;
}

impl emitted_paths(host: ProjectHost, requested: list[str]) -> list[str] {
    import from jaclang.compiler.driver.jir { get_module_cache_path, is_module_cache_valid }
    chosen: list[str] = [];
    for real in requested {
        if real in host.units {
            chosen.append(real);
        }
    }
    for real in host.units {
        if real in chosen or not real.endswith(".jac") {
            continue;
        }
        if real in host.grown
            or not is_module_cache_valid(real, get_module_cache_path(real)) {
            chosen.append(real);
        }
    }
    return chosen;
}

impl compiled_unit(
    host: ProjectHost, real: str, want_code: bool, want_ast: bool = False
) -> CompiledUnit {
    import from jaclang.compiler.backends.py.kernel_bytecode {
        kernel_code_object,
        kernel_python_ast
    }
    import from jaclang.compiler.driver.compiler { unit_sections }
    import from jaclang.compiler.driver.unit_products { client_artifact_from_json }
    products = host.units[real];
    task = host.analyses.get(real);
    if task is None {
        raise KernelError(f"the kernel holds products for {real} but no analysis");
    }
    module = task.module;
    client = client_artifact_from_json(products.client) if products.client else None;
    return CompiledUnit(
        path=real,
        module_name=module.name,
        code=kernel_code_object(module) if want_code else ptr[PyObject](),
        python_ast=Py_NewRef(kernel_python_ast(module))
            if want_ast
            else ptr[PyObject](),
        interface=products.iface.encode("utf-8"),
        placement=products.placement,
        client_js=client.js if client is not None else "",
        native_iface=products.native_iface,
        native_deps=list(products.native_deps),
        native_ir=products.native_ir,
        native_layout=products.native_layout,
        jac_deps=list(products.jac_deps),
        app=products.app,
        persistence=list(products.persistence),
        import_edges=list(products.import_edges),
        interop=products.interop,
        client_manifest=products.client_manifest,
        iface_shape=products.iface_shape,
        effects=products.effects,
        sections=unit_sections(products, None)
    );
}

impl run_compile(
    program: JacProgram, host: ProjectHost, request: CompileRequest
) -> CompileResult {
    import from jaclang.project.compiler_host { other_compiler_root }
    result = CompileResult();
    want_code = "bytecode" in request.products;
    options = copy.copy(request.options);
    if not request.products {
        options.no_cgen = True;
    }
    for (path, text) in request.sources.items() {
        host.overlay[os.path.realpath(path)] = text;
    }
    if not options.no_cgen {
        host.close_over(options);
    }
    requested: list[str] = [];
    with host.session() {
        for path in request.paths {
            real = os.path.realpath(path);
            other = other_compiler_root(real);
            if other {
                result.errors.append(other_compiler_diagnostic(real, other));
                continue;
            }
            requested.append(real);
            program.compile(real, use_str=host.overlay.get(real), options=options);
        }
        if not options.no_cgen {
            tried: set[str] = set(requested);
            grew = True;
            while grew {
                grew = False;
                for real in list(host.analyses) {
                    if real in tried or real in host.units {
                        continue;
                    }
                    tried.add(real);
                    if other_compiler_root(real) or not real.endswith(".jac") {
                        continue;
                    }
                    program.compile(real, use_str=host.overlay.get(real), options=options);
                    grew = True;
                }
            }
        }
    }
    collect_diagnostics(program, result.errors, result.warnings);
    result.reached = sorted(host.analyses.keys());
    result.reads = [
        SourceRead(path=path, digest=digest)
        for (path, digest) in sorted(host.source_reads.items())
    ];
    if options.no_cgen {
        return result;
    }
    want_ast = "python_ast" in request.products;
    for real in emitted_paths(host, requested) {
        result.units.append(compiled_unit(host, real, want_code, want_ast));
    }
    return result;
}

impl run_check(
    program: JacProgram, host: ProjectHost, request: CheckRequest
) -> CheckResult {
    import from jaclang.compiler.backends.native.mir.backend { native_coverage }
    import from jaclang.compiler.placement.placement_export { collect_placement_rows }
    import from jaclang.project.compiler_host { other_compiler_root }
    result = CheckResult();
    options = copy.copy(request.options);
    options.no_cgen = not request.native_coverage;
    for (path, text) in request.sources.items() {
        host.overlay[os.path.realpath(path)] = text;
    }
    with host.session() {
        for path in request.paths {
            real = os.path.realpath(path);
            other = other_compiler_root(real);
            if other {
                result.errors.append(other_compiler_diagnostic(real, other));
                continue;
            }
            program.compile(real, use_str=host.overlay.get(real), options=options);
        }
        if request.closure {
            checked: set[str] = set();
            grew = True;
            while grew {
                grew = False;
                for real in list(host.analyses) {
                    if real in checked {
                        continue;
                    }
                    checked.add(real);
                    if other_compiler_root(real) or not real.endswith(".jac") {
                        continue;
                    }
                    program.compile(real, use_str=host.overlay.get(real), options=options);
                    grew = True;
                }
            }
        }
    }
    collect_diagnostics(program, result.errors, result.warnings);
    if request.native_coverage {
        for (path, record) in sorted(native_coverage(program).items()) {
            row = CoverageRow(path=path, native=1 if record["outcome"] == "native" else 0);
            for (symbol, reason) in sorted(record["demoted"].items()) {
                row.demoted.append(
                    NativeDemotion(
                        symbol=symbol,
                        kind="function",
                        reason=reason,
                        code=record["code"],
                        span=SourceSpan(path=path)
                    )
                );
            }
            result.coverage.append(row);
        }
    }
    if request.placements {
        for (path, rows) in collect_placement_rows(program).items() {
            for row in rows.get("rows", []) {
                result.placements.append(
                    PlacementRow(
                        path=path,
                        symbol=str(row["name"]),
                        placement=str(row["space"]),
                        reason="; ".join([str(note) for note in row["evidence"]])
                    )
                );
            }
        }
    }
    if request.module_facts {
        import from jaclang.compiler.driver.pipeline { require }
        import from jaclang.compiler.driver.pipeline_types { CompilationProduct }
        for real in sorted(host.analyses.keys()) {
            module = host.analyses[real].module;
            result.modules.append(
                module_fact(program, real, module, request.options.target_app)
            );
            if not real.endswith(".jac") {
                continue;
            }
            manifest = module.gen.interop_manifest;
            if manifest is None or not (manifest.app_edges or manifest.surface) {
                require(program, module, CompilationProduct.BOUNDARIES);
                manifest = module.gen.interop_manifest;
            }
            if manifest is not None {
                for (consumer, provider) in manifest.app_edges {
                    result.app_edges.append(
                        AppEdge(consumer=str(consumer), provider=str(provider))
                    );
                }
            }
        }
    }
    result.reached = sorted(host.analyses.keys());
    return result;
}

impl module_fact(
    program: JacProgram, real: str, module: uni.Module, app: str
) -> ModuleFact {
    import from jaclang.compiler.frontend.constant { CodeContext }
    import from jaclang.compiler.frontend.unitree { Import, ModulePath }
    import from jaclang.compiler.placement.placement_facts { module_spaces }
    imports: set[str] = set();
    for statement in module.get_all_sub_nodes(Import) {
        if not statement.is_jac or statement.is_virtual_jac {
            continue;
        }
        targets = [statement.from_loc]
            if statement.from_loc is not None
            else [
                item
                for item in statement.items
                if isinstance(item, ModulePath)
            ];
        for target in targets {
            dependency = target.resolve_relative_path();
            if dependency and dependency.endswith(".jac") {
                imports.add(os.path.realpath(dependency));
            }
        }
    }
    return ModuleFact(
        path=real,
        app=app,
        spaces=sorted(module_spaces(module)),
        decided=str(module.decided_codespace or ""),
        client_declared=module.declares_codespace(CodeContext.CLIENT, path_hint=real),
        errors=program.count_module_errors(os.path.normpath(real)),
        imports=sorted(imports)
    );
}

impl NativeBuildResult.ok -> bool {
    return not self.errors;
}

impl native_build_request(request: NativeBuildRequest) -> NativeBuildResult {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.frontend.host { active_host, install_host }
    import from jaclang.project.compiler_host { ProjectHost }
    enter_world(request.project_root, request.search_paths, request.package_root);
    host = ProjectHost(root=request.project_root);
    previous = active_host();
    install_host(host);
    try {
        return run_native_build(JacProgram(), host, request);
    } finally {
        install_host(previous);
    }
}

impl run_native_build(
    program: JacProgram, host: ProjectHost, request: NativeBuildRequest
) -> NativeBuildResult {
    import re;
    import from jaclang.compiler.backends.native.link_plan {
        ArtifactKind,
        LinkPlanError,
        build_link_plan,
        link_artifact,
        optimize_merged_program,
        unique_callbacks,
        whole_program_module
    }
    import from jaclang.compiler.driver.compile_options {
        pop_native_target,
        push_native_target
    }
    import from jaclang.compiler.frontend.codeinfo { is_toolchain_unit }
    import jaclang.compiler.backends.native.llvm.binding as llvm;
    result = NativeBuildResult(output=request.output);
    options = copy.copy(request.options);
    program.options = options;
    registry = program.native_units();
    def progress(line: str) {
        result.log.append(line);
    }
    registry.progress = progress;
    kinds = {
        "executable": ArtifactKind.EXECUTABLE,
        "shared": ArtifactKind.SHARED,
        "wasm": ArtifactKind.WASM
    };
    if request.kind != "plan" and request.kind not in kinds {
        raise KernelError(f"unknown native artifact kind '{request.kind}'");
    }
    roots = [os.path.realpath(path) for path in request.roots];
    if not roots {
        raise KernelError("a native build names no root module");
    }
    previous = push_native_target(options.native_target or "");
    try {
        with host.session() {
            root_module: (uni.Module | None) = None;
            if request.kind == "wasm" or request.callbacks {
                root_module = program.compile(roots[0], options=options);
                result.root_native = root_module.decided_codespace == "native"
                    and root_module.gen.native_iface is not None;
            }
            try {
                plan = build_link_plan(
                    program,
                    roots,
                    options,
                    mode=request.link_mode,
                    native_unit=request.native_unit
                );
            } except LinkPlanError as err {
                raise KernelError(str(err)) from err;
            }
            collect_diagnostics(program, result.errors, result.warnings);
            result.mode = plan.mode;
            result.triple = plan.triple;
            result.recompiled = len(registry.compiled_paths);
            result.analysed = program.analysis.cache_events.get("native_unit_analysis", 0);
            result.lowered = program.analysis.cache_events.get("native_unit_lower", 0);
            result.generated = program.analysis.cache_events.get("native_unit_codegen", 0);
            for unit in plan.units {
                result.units.append(
                    LinkedUnit(
                        path=unit.path,
                        digest=unit.digest,
                        stamp=registry.stamp_for(options, unit.path)
                    )
                );
            }
            result.python_imports = sorted(
                {name for unit in plan.units for name in unit.iface.python_imports}
            );
            result.demoted = list(plan.demoted_symbols());
            result.has_entry = bool(plan.root_unit().iface.entry_symbol);
            result.libraries = plan.clib_paths();
            if result.errors or request.kind == "plan" {
                return result;
            }
            if request.kind == "wasm" and not result.root_native {
                return result;
            }
            if request.refuse_python_imports and result.python_imports {
                return result;
            }
            if request.refuse_demoted and result.demoted {
                return result;
            }
            if request.kernel_entries {
                import from jaclang.compiler.backends.native.kernel_stage0 {
                    refuse_missing_entries
                }
                try {
                    refuse_missing_entries(
                        plan, request.project_root or request.package_root
                    );
                } except RuntimeError as err {
                    raise KernelError(str(err)) from err;
                }
            }
            if request.assert_no_rc {
                parts: list[str] = [];
                for unit in plan.units {
                    if is_toolchain_unit(unit.path) {
                        continue;
                    }
                    code = registry.bitcode_for(unit.path, plan.options);
                    if code is not None {
                        parts.append(str(llvm.parse_bitcode(code)));
                    }
                }
                emitted = "\n".join(parts);
                result.rc_symbols = sorted(
                    {found.group(0) for found in re.finditer(r"__rc_[A-Za-z0-9_]*", emitted)}
                );
                result.rc_probes = [
                    probe
                    for probe in ["JAC_GC"]
                    if probe in emitted
                ];
                if result.rc_symbols or result.rc_probes {
                    return result;
                }
            }
            if request.require_entry and not result.has_entry {
                return result;
            }
            kind = kinds[request.kind];
            plan.library_api = request.library_api;
            if request.callbacks and root_module is not None {
                manifest = root_module.gen.interop_manifest;
                bindings = unique_callbacks(manifest.callable_native_imports)
                    if manifest is not None
                    else [];
                plan.callback_bindings = list(bindings);
                for binding in bindings {
                    result.callbacks.append(
                        CallbackBinding(
                            name=binding.name,
                            symbol=binding.symbol,
                            ret_type=binding.ret_type,
                            param_types=list(binding.param_types)
                        )
                    );
                }
            }
            if request.emit_c {
                import from jaclang.compiler.backends.native.c_emit { emit_c }
                (merged, _exports) = whole_program_module(
                    plan, plan.glue_spec(kind, "c", False)
                );
                optimize_merged_program(plan, merged, kind);
                merged_ir = str(merged);
                if options.memory_profile == "nogc" {
                    import from jaclang.compiler.backends.native.wasm_build {
                        _assert_ir_rc_free
                    }
                    _assert_ir_rc_free(merged_ir, roots[0]);
                }
                with open(request.output, "w", encoding="utf-8") as handle {
                    handle.write(emit_c(merged_ir));
                }
                result.linked = True;
                return result;
            }
            app_imports: (set | None) = None;
            if request.kind == "wasm" and root_module is not None {
                import from jaclang.compiler.backends.native.wasm_build {
                    app_declared_imports
                }
                app_imports = app_declared_imports(root_module);
            }
            program.release_compile_closure();
            linked = link_artifact(
                plan, request.output, kind, log=progress, app_imports=app_imports
            );
            result.linked = True;
            result.reused = linked.reused;
            result.sha256 = linked.sha256;
            result.plan_digest = linked.plan_digest;
            result.layout_digest = linked.layout_digest;
        }
    } finally {
        pop_native_target(previous);
    }
    return result;
}

impl compile_request(request: CompileRequest) -> CompileResult {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.frontend.host { active_host, install_host }
    import from jaclang.project.compiler_host { ProjectHost }
    enter_world(request.project_root, request.search_paths, request.package_root);
    host = ProjectHost(root=request.project_root);
    previous = active_host();
    install_host(host);
    try {
        return run_compile(JacProgram(), host, request);
    } finally {
        install_host(previous);
    }
}

impl check_request(request: CheckRequest) -> CheckResult {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.frontend.host { active_host, install_host }
    import from jaclang.project.compiler_host { ProjectHost }
    enter_world(request.project_root, request.search_paths, request.package_root);
    host = ProjectHost(root=request.project_root);
    previous = active_host();
    install_host(host);
    try {
        return run_check(JacProgram(), host, request);
    } finally {
        install_host(previous);
    }
}

impl open_session(
    project_root: str, search_paths: list[str], package_root: str
) -> KernelSession {
    return KernelSession(
        project_root=project_root, search_paths=search_paths, package_root=package_root
    );
}

impl KernelSession.postinit {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.project.compiler_host { ProjectHost }
    enter_world(self.project_root, self.search_paths, self.package_root);
    self._host = ProjectHost(root=self.project_root);
    program = JacProgram();
    program.deps.tracking = True;
    self._program = program;
    self.options = copy.copy(self.options);
    self.options.no_cgen = True;
}

impl KernelSession.enter -> ProjectHost {
    import from jaclang.compiler.frontend.host { install_host }
    host = self._host;
    if host is None or self._program is None {
        raise KernelError("the kernel session is closed");
    }
    install_host(host);
    return host;
}

impl KernelSession.leave {
    import from jaclang.compiler.frontend.host { NeutralHost, install_host }
    install_host(NeutralHost());
}

impl KernelSession.invalidate(real: str) {
    program = self._program;
    host = self._host;
    if program is None or host is None {
        raise KernelError("the kernel session is closed");
    }
    stale = {real} | program.transitive_dependents(real);
    for path in stale {
        program.drop_module_alerts(path);
        program.invalidate_module(path);
        host.forget_program_products(program, path);
        self._analysed.pop(path, None);
    }
}

impl KernelSession.owner(real: str) -> str {
    host = self._host;
    if host is None {
        raise KernelError("the kernel session is closed");
    }
    base = host.base_file(real);
    return os.path.realpath(base) if base else real;
}

impl KernelSession.touch(real: str) {
    owner = self.owner(real);
    for path in {real, owner} {
        self._versions[path] = self._versions.get(path, 0) + 1;
        self.invalidate(path);
    }
}

impl KernelSession.app_targets(real: str) -> list[tuple[str, str, str]] {
    host = self._host;
    if host is None {
        raise KernelError("the kernel session is closed");
    }
    space = host.workspace(real);
    if space is None {
        return [];
    }
    app = host.app_for_path(real);
    if app is not None {
        return [(app.name, app.kind, app.`entry or real)];
    }
    return [
        (each.name, each.kind, each.`entry or real)
        for each in list(space.apps.values())[:self.shared_app_limit]
    ];
}

impl KernelSession.compile_for(
    real: str, target: (tuple[str, str, str] | None)
) -> uni.Module {
    host = self._host;
    program = self._program;
    options = copy.copy(self.options);
    if target is not None {
        (name, kind, entry_path) = target;
        space = host.workspace(real);
        options.target_app = name;
        options.app_kind = kind;
        options.entry_point = entry_path;
        options.project_root = space.project_root if space is not None else None;
    }
    for path in self.own_files(real) {
        program.drop_module_alerts(path);
    }
    program.invalidate_module(real);
    with host.session() {
        return program.compile(real, use_str=host.overlay.get(real), options=options);
    }
}

impl KernelSession.own_files(real: str) -> set[str] {
    host = self._host;
    if host is None {
        raise KernelError("the kernel session is closed");
    }
    return {
        real,
        *[
            os.path.realpath(path)
            for path in [
                *host.annex_files(real, ".impl.jac"),
                *host.annex_files(real, ".test.jac")
            ]
        ]
    };
}

impl KernelSession.analysed(path: str) -> uni.Module {
    real = self.owner(os.path.realpath(path));
    program = self._program;
    self.enter();
    try {
        version = self._versions.get(real, 0);
        held = program.find_module(real);
        if held is not None and self._analysed.get(real) == version {
            return held;
        }
        targets = self.app_targets(real);
        module = self.compile_for(real, targets[0] if targets else None);
        self._analysed[real] = version;
        return module;
    } finally {
        self.leave();
    }
}

impl KernelSession.update(path: str, text: str) {
    real = os.path.realpath(path);
    host = self._host;
    if host is None {
        raise KernelError("the kernel session is closed");
    }
    host.overlay[real] = text;
    self._open.add(real);
    self.touch(real);
}

impl KernelSession.close(path: str) {
    import from jaclang.project.textio { read_file_with_encoding }
    real = os.path.realpath(path);
    host = self._host;
    if host is None {
        raise KernelError("the kernel session is closed");
    }
    self._open.discard(real);
    held = host.overlay.pop(real, None);
    if held is None {
        return;
    }
    on_disk = read_file_with_encoding(real) if os.path.isfile(real) else None;
    if on_disk != held {
        self.touch(real);
    }
}

impl KernelSession.forget(path: str) {
    real = os.path.realpath(path);
    host = self._host;
    program = self._program;
    if host is None or program is None {
        raise KernelError("the kernel session is closed");
    }
    host.overlay.pop(real, None);
    self._open.discard(real);
    self.touch(real);
    program.release_module(real);
    self._versions.pop(real, None);
    self._analysed.pop(real, None);
}

impl KernelSession.rename_module(old_path: str, new_path: str) {
    old_real = os.path.realpath(old_path);
    new_real = os.path.realpath(new_path);
    if old_real == new_real {
        return;
    }
    host = self._host;
    if host is None {
        raise KernelError("the kernel session is closed");
    }
    held = host.overlay.get(old_real);
    was_open = old_real in self._open;
    self.forget(old_real);
    if held is not None {
        host.overlay[new_real] = held;
    }
    if was_open {
        self._open.add(new_real);
    }
    self.touch(new_real);
}

impl KernelSession.dependents(path: str) -> list[str] {
    program = self._program;
    if program is None {
        raise KernelError("the kernel session is closed");
    }
    if not self._edges_seeded and self.project_root {
        import from jaclang.compiler.driver.ifacecache { seed_dep_edges }
        self.enter();
        try {
            seed_dep_edges(program, self.project_root);
        } finally {
            self.leave();
        }
        self._edges_seeded = True;
    }
    real = os.path.realpath(path);
    found = program.transitive_dependents(real) | program.transitive_dependents(
        self.owner(real)
    );
    return sorted([os.path.realpath(dep) for dep in found]);
}

impl KernelSession.set_shared_app_limit(limit: int) {
    if limit < 1 {
        raise KernelError(f"the shared-app limit must be at least 1, not {limit}");
    }
    self.shared_app_limit = limit;
    self._analysed.clear();
}

impl KernelSession.diagnostics(path: str) -> list[KernelDiagnostic] {
    real = self.owner(os.path.realpath(path));
    files = self.own_files(real);
    program = self._program;
    def gathered -> list[KernelDiagnostic] {
        found: list[KernelDiagnostic] = [];
        for (severity, alerts) in [
            ("error", program.errors_had),
            ("warning", program.warnings_had)
        ] {
            for alert in alerts {
                if alert.loc.mod_path and os.path.realpath(alert.loc.mod_path) in files {
                    found.append(kernel_diagnostic(alert, severity));
                }
            }
        }
        return found;
    }
    self.enter();
    try {
        targets = self.app_targets(real);
    } finally {
        self.leave();
    }
    if len(targets) <= 1 {
        self.analysed(real);
        return gathered();
    }
    collected: list[tuple[str, list[KernelDiagnostic]]] = [];
    self.enter();
    try {
        for target in targets {
            self.compile_for(real, target);
            collected.append((target[0], gathered()));
        }
        self._analysed[real] = self._versions.get(real, 0);
    } finally {
        self.leave();
    }
    return merge_app_diagnostics(collected);
}

impl KernelSession.hover(path: str, line: int, col: int) -> str {
    import from jaclang.compiler.tools.session_queries { hover_text, token_at }
    real = os.path.realpath(path);
    module = self.analysed(real);
    selected = token_at(module, real, line, col);
    return hover_text(selected) if selected is not None else "";
}

impl KernelSession.definition(path: str, line: int, col: int) -> list[SourceSpan] {
    import from jaclang.compiler.tools.session_queries { definition_spans, string_import_definition, token_at }
    real = os.path.realpath(path);
    module = self.analysed(real);
    selected = token_at(module, real, line, col);
    if selected is None {
        return string_import_definition(module, line, col);
    }
    return definition_spans(self._program, selected);
}

impl KernelSession.references(path: str, line: int, col: int) -> list[SourceSpan] {
    import from jaclang.compiler.tools.session_queries { reference_spans, token_at }
    real = os.path.realpath(path);
    selected = token_at(self.analysed(real), real, line, col);
    return reference_spans(selected) if selected is not None else [];
}

impl KernelSession.completion(path: str, line: int, col: int) -> list[CompletionItem] {
    import from jaclang.compiler.tools.session_queries {
        completion_items,
        inside_literal_or_comment
    }
    real = os.path.realpath(path);
    host = self.enter();
    try {
        source = host.read_source(real);
    } finally {
        self.leave();
    }
    if inside_literal_or_comment(source, real, line, col) {
        return [];
    }
    module = self.analysed(real);
    self.enter();
    try {
        return completion_items(self._program, module, real, line, col);
    } finally {
        self.leave();
    }
}

impl KernelSession.semantic_tokens(path: str) -> list[int] {
    import from jaclang.compiler.tools.session_queries { semantic_token_data }
    real = os.path.realpath(path);
    return semantic_token_data(self.analysed(real), real);
}

impl KernelSession.inlay_hints(
    path: str, first_line: int, last_line: int
) -> list[InlayHint] {
    import from jaclang.compiler.tools.session_queries { inlay_hint_rows }
    return inlay_hint_rows(self.analysed(path), first_line, last_line);
}

impl KernelSession.symbols(path: str) -> list[DocumentSymbol] {
    import from jaclang.compiler.tools.session_queries { outline }
    module = self.analysed(path);
    return outline(module.sym_tab);
}

impl KernelSession.rename(
    path: str, line: int, col: int, new_name: str
) -> list[TextEdit] {
    import from jaclang.compiler.tools.session_queries { rename_edits, token_at }
    real = os.path.realpath(path);
    selected = token_at(self.analysed(real), real, line, col);
    return rename_edits(selected, new_name) if selected is not None else [];
}

impl KernelSession.formatted(path: str, auto_lint: bool) -> ToolOutput {
    import from jaclang.compiler.driver.compiler { JacCompiler }
    real = os.path.realpath(path);
    host = self.enter();
    try {
        program = JacCompiler.jac_str_formatter(host.read_source(real), real, auto_lint);
    } finally {
        self.leave();
    }
    out = ToolOutput();
    collect_diagnostics(program, out.errors, out.warnings);
    main = program.mod.main;
    out.text = (main.gen.jac or "") if main is not None else "";
    return out;
}

impl KernelSession.format(path: str) -> ToolOutput {
    return self.formatted(path, False);
}

impl KernelSession.lint_fix(path: str) -> ToolOutput {
    return self.formatted(path, True);
}

impl KernelSession.lint(path: str) -> ToolOutput {
    import from jaclang.compiler.driver.compiler { JacCompiler }
    real = os.path.realpath(path);
    host = self.enter();
    try {
        program = JacCompiler.jac_str_linter(host.read_source(real), real);
    } finally {
        self.leave();
    }
    out = ToolOutput();
    collect_diagnostics(program, out.errors, out.warnings);
    return out;
}

impl KernelSession.parse(path: str) -> ToolOutput {
    import from jaclang.compiler.driver.compiler { JacCompiler }
    real = os.path.realpath(path);
    host = self.enter();
    try {
        (program, _module) = JacCompiler._prepare_tool_program(
            host.read_source(real), real
        );
    } finally {
        self.leave();
    }
    out = ToolOutput();
    collect_diagnostics(program, out.errors, out.warnings);
    return out;
}

impl KernelSession.statements(path: str) -> list[SourceSpan] {
    import from jaclang.compiler.driver.compiler { JacCompiler }
    real = os.path.realpath(path);
    host = self.enter();
    try {
        (program, module) = JacCompiler._prepare_tool_program(
            host.read_source(real), real
        );
    } finally {
        self.leave();
    }
    if module is None {
        raise KernelError(f"{real} does not parse: {program.errors_had[0].msg}");
    }
    return [
        source_span(stmt.loc)
        for stmt in module.body
        if stmt.loc.mod_path and os.path.realpath(stmt.loc.mod_path) == real
    ];
}

impl KernelSession.py_to_jac(path: str) -> ToolOutput {
    import from jaclang.compiler.driver.compiler { JacCompiler }
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.passes.pyast_load_pass { parse_python_source }
    import from jaclang.compiler.tools.jac_formatter_pass { unparse_module }
    real = os.path.realpath(path);
    if not real.endswith((".py", ".pyi")) {
        raise KernelError(f"{real} is not a Python file");
    }
    out = ToolOutput();
    host = self.enter();
    try {
        program = JacProgram();
        (converted, had_error) = parse_python_source(host.read_source(real), real, program);
        collect_diagnostics(program, out.errors, out.warnings);
        if had_error {
            return out;
        }
        laid_out = JacCompiler.jac_str_formatter(
            unparse_module(converted, requires_format=False), real, False
        );
    } finally {
        self.leave();
    }
    collect_diagnostics(laid_out, out.errors, out.warnings);
    main = laid_out.mod.main;
    out.text = (main.gen.jac or "") if main is not None else "";
    return out;
}

impl KernelSession.ast_view(path: str, view: str) -> ToolOutput {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.passes.pyast_load_pass { parse_python_source }
    import from jaclang.compiler.tools.ast_views {
        ANALYSED_VIEWS,
        PARSED_VIEWS,
        analysed_view,
        parsed_view
    }
    import from jaclang.compiler.tools.jac_formatter_pass { unparse_module }
    real = os.path.realpath(path);
    if view not in PARSED_VIEWS and view not in ANALYSED_VIEWS {
        raise KernelError(
            f"unknown AST view '{view}'; expected one of "
            + ", ".join([*PARSED_VIEWS, *ANALYSED_VIEWS])
        );
    }
    out = ToolOutput();
    program = JacProgram();
    host = self.enter();
    try {
        source = host.read_source(real);
        if view in PARSED_VIEWS {
            module = program.parse_str(source, real);
            collect_diagnostics(program, out.errors, out.warnings);
            if not out.errors {
                out.text = parsed_view(module, view);
            }
            return out;
        }
        target = real;
        if real.endswith(".py") {
            (converted, had_error) = parse_python_source(source, real, program);
            if had_error {
                collect_diagnostics(program, out.errors, out.warnings);
                return out;
            }
            source = unparse_module(converted);
            target = real[:-len(".py")] + ".jac";
        }
        with host.session() {
            module = program.compile(
                target, use_str=source, options=CompileOptions(no_cgen=True)
            );
        }
        collect_diagnostics(program, out.errors, out.warnings);
        out.text = analysed_view(program, module, view);
        return out;
    } finally {
        self.leave();
    }
}

impl KernelSession.explain(
    path: str, topic: str, memory_profile: str = ""
) -> ToolOutput {
    import from jaclang.compiler.backends.native.na_compile_pass {
        native_linked_ir_text
    }
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.passes.ownership_hints { inferred_hints }
    real = os.path.realpath(path);
    if topic == "memory" {
        options = CompileOptions(
            rc_stats=True, nogc_debug=True, memory_profile=(memory_profile or None)
        );
    } elif topic == "native" {
        options = CompileOptions(aot_mode=True, default_codespace="native");
    } else {
        raise KernelError(
            f"unknown explain topic '{topic}'; the kernel explains 'memory' and 'native'"
        );
    }
    out = ToolOutput();
    program = JacProgram();
    host = self.enter();
    try {
        with host.session() {
            module = program.compile(
                real, use_str=host.overlay.get(real), options=options
            );
        }
    } finally {
        self.leave();
    }
    collect_diagnostics(program, out.errors, out.warnings);
    if topic == "native" {
        if module.gen.llvm_ir is not None {
            out.text = native_linked_ir_text(module);
        }
        return out;
    }
    name = os.path.basename(real);
    hints = sorted(
        inferred_hints(module), key=lambda (h: any) { (h.line, h.col); }
    );
    lines = [
        f"memory profile: {program.options.memory_profile
            if program.options and program.options.memory_profile
            else 'managed'}",
        f"inferred facts: {len(hints)}",
        *[f"  {name}:{h.line}:{h.col}  {h.label.strip()}" for h in hints],
        f"move sites: {len(module.own_move_sites)}",
        f"last-use releases: {sum([len(v) for v in module.rc_last_use.values()])}"
    ];
    out.text = "\n".join(lines);
    return out;
}

impl KernelSession.grammar -> GrammarReport {
    import from jaclang.compiler.driver.pipeline { run_utility }
    import from jaclang.compiler.driver.pipeline_types { CompilationProduct }
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.tools.grammar_extract_pass { GrammarExtractPass }
    parser_path = os.path.join(
        self.package_root, "compiler", "frontend", "parser", "parser.jac"
    );
    report = GrammarReport(ebnf="", rules=0);
    program = JacProgram();
    host = self.enter();
    try {
        with host.session() {
            module = program.compile(
                parser_path,
                options=CompileOptions(
                    symtab_ir_only=True, no_cgen=True, need_full_ast=True
                )
            );
        }
        ignored: list[KernelDiagnostic] = [];
        collect_diagnostics(program, report.errors, ignored);
        if report.errors {
            return report;
        }
        extracted = run_utility(CompilationProduct.GRAMMAR, module, program);
    } finally {
        self.leave();
    }
    if not isinstance(extracted, GrammarExtractPass) {
        raise KernelError("the grammar product did not run the grammar extractor");
    }
    report.ebnf = extracted.emit_ebnf();
    report.rules = len(extracted.rules);
    report.diagnostics = extracted.emit_diagnostics();
    return report;
}

impl KernelSession.arch_plan(
    arch_path: str, action: str, prune: bool = False, graph_format: str = ""
) -> ArchPlan {
    import from jaclang.compiler.tools.arch_plan { graph_plan, init_plan, sync_plan }
    real = os.path.realpath(arch_path);
    host = self.enter();
    try {
        if action == "init" {
            return init_plan(host, real);
        }
        if action == "sync" {
            return sync_plan(host, real, prune);
        }
        if action == "graph" {
            return graph_plan(real, graph_format);
        }
    } finally {
        self.leave();
    }
    raise KernelError(f"unknown arch action '{action}'; expected init, sync or graph");
}

impl KernelSession.compile(request: CompileRequest) -> CompileResult {
    host = self.enter();
    try {
        return run_compile(self._program, host, request);
    } finally {
        self.leave();
    }
}

impl KernelSession.check(request: CheckRequest) -> CheckResult {
    host = self.enter();
    try {
        return run_check(self._program, host, request);
    } finally {
        self.leave();
    }
}

impl KernelSession.module_outline(path: str) -> ModuleOutline {
    import from jaclang.compiler.tools.studio_queries { module_outline_of }
    host = self.enter();
    try {
        with host.session() {
            return module_outline_of(host, path);
        }
    } finally {
        self.leave();
    }
}

impl KernelSession.edit_symbols(path: str, text: str) -> list[EditSymbol] {
    import from jaclang.compiler.tools.studio_queries { edit_symbol_rows }
    self.enter();
    try {
        return edit_symbol_rows(text, os.path.realpath(path));
    } finally {
        self.leave();
    }
}

impl KernelSession.import_texts(path: str, text: str) -> list[str] {
    import from jaclang.compiler.tools.studio_queries { import_text_rows }
    self.enter();
    try {
        return import_text_rows(text, os.path.realpath(path));
    } finally {
        self.leave();
    }
}

impl KernelSession.wiring_changes(
    path: str, old_text: str, new_text: str
) -> list[WiringChange] {
    import from jaclang.compiler.tools.studio_queries { wiring_change_rows }
    self.enter();
    try {
        return wiring_change_rows(old_text, new_text, os.path.realpath(path));
    } finally {
        self.leave();
    }
}

impl KernelSession.wired_dependents(head: str, names: list[str]) -> WiredFiles {
    import from jaclang.compiler.tools.studio_queries { wired_dependent_files }
    host = self.enter();
    try {
        with host.session() {
            return wired_dependent_files(head, names);
        }
    } finally {
        self.leave();
    }
}

impl KernelSession.wiring_module_files(
    arch_path: str, consumers: list[str]
) -> list[str] {
    import from jaclang.compiler.tools.studio_queries { wiring_files_of }
    host = self.enter();
    try {
        with host.session() {
            return wiring_files_of(arch_path, consumers);
        }
    } finally {
        self.leave();
    }
}

impl KernelSession.wiring_model(arch_path: str) -> WiringModel {
    import from jaclang.compiler.tools.studio_queries { wiring_model_of }
    host = self.enter();
    try {
        with host.session() {
            return wiring_model_of(arch_path);
        }
    } finally {
        self.leave();
    }
}

impl KernelSession.token_symbols(path: str) -> list[TokenSymbol] {
    import from jaclang.compiler.tools.studio_queries { token_symbol_rows }
    real = os.path.realpath(path);
    return token_symbol_rows(self.analysed(real), real);
}

impl KernelSession.assignment_hints(path: str) -> list[InlayHint] {
    import from jaclang.compiler.tools.studio_queries { assignment_hint_rows }
    real = os.path.realpath(path);
    return assignment_hint_rows(self.analysed(real), real);
}

impl KernelSession.tokens(path: str, text: str) -> TokenStream {
    import from jaclang.compiler.tools.studio_queries { token_stream }
    return token_stream(text, os.path.realpath(path));
}

impl KernelSession.code_index -> CodeIntelligence {
    import from jaclang.compiler.tools.code_intel { CodeIntelligence }
    if not self.project_root {
        raise KernelError(
            "the code index needs a session opened on a project root, not an empty one"
        );
    }
    if self._intel is None {
        self._intel = CodeIntelligence(proj_dir=self.project_root);
    }
    return self._intel;
}

impl KernelSession.code_lookup(name: str) -> list[SymbolInfo] {
    host = self.enter();
    try {
        with host.session() {
            return self.code_index().lookup(name);
        }
    } finally {
        self.leave();
    }
}

impl KernelSession.code_references(name: str) -> list[SourceRef] {
    host = self.enter();
    try {
        with host.session() {
            return self.code_index().references(name);
        }
    } finally {
        self.leave();
    }
}

impl KernelSession.code_archetypes(kind: str) -> list[SymbolInfo] {
    host = self.enter();
    try {
        with host.session() {
            return self.code_index().archetypes(kind);
        }
    } finally {
        self.leave();
    }
}

impl KernelSession.code_walkers(node_type: str) -> list[EntryPoint] {
    host = self.enter();
    try {
        with host.session() {
            return self.code_index().walkers_visiting(node_type);
        }
    } finally {
        self.leave();
    }
}

impl KernelSession.code_slice(name: str, depth: int) -> ContextSlice {
    host = self.enter();
    try {
        with host.session() {
            return self.code_index().slice_for(name, depth);
        }
    } finally {
        self.leave();
    }
}

impl KernelSession.code_diagnostics(file: str) -> list[CodeDiagnostic] {
    host = self.enter();
    try {
        with host.session() {
            return self.code_index().diagnostics(file);
        }
    } finally {
        self.leave();
    }
}

impl KernelSession.code_refresh(file: str) {
    host = self.enter();
    try {
        with host.session() {
            self.code_index().refresh(file);
        }
    } finally {
        self.leave();
    }
}

impl SourceRef.render -> str {
    loc = f"{self.file}:{self.line}";
    return f"{loc}  {self.snippet}" if self.snippet else loc;
}

impl SourceRef.to_dict -> dict[str, any] {
    return {
        "file": self.file,
        "line": self.line,
        "col": self.col,
        "role": self.role,
        "snippet": self.snippet
    };
}

impl SymbolInfo.render -> str {
    head = f"{self.kind} {self.name}";
    if self.signature {
        head += self.signature;
    } elif self.type_str {
        head += f": {self.type_str}";
    }
    lines = [f"{head}    [{self.file}:{self.line}]"];
    if self.base_classes {
        lines.append("  extends: " + ", ".join(self.base_classes));
    }
    for f in self.fields {
        lines.append(f"  has {f}");
    }
    for a in self.abilities {
        lines.append(f"  def {a}");
    }
    if self.doc {
        lines.append("  " + self.doc.strip().splitlines()[0]);
    }
    return "\n".join(lines);
}

impl SymbolInfo.to_dict -> dict[str, any] {
    return {
        "name": self.name,
        "kind": self.kind,
        "file": self.file,
        "line": self.line,
        "col": self.col,
        "type_str": self.type_str,
        "doc": self.doc,
        "signature": self.signature,
        "fields": self.fields,
        "abilities": self.abilities,
        "base_classes": self.base_classes,
        "is_genai": self.is_genai
    };
}

impl SymbolInfo.from_dict(d: dict[str, any]) -> SymbolInfo {
    return SymbolInfo(
        name=str(d.get("name", "")),
        kind=str(d.get("kind", "symbol")),
        file=str(d.get("file", "")),
        line=int(d.get("line", 0)),
        col=int(d.get("col", 0)),
        type_str=str(d.get("type_str", "")),
        doc=str(d.get("doc", "")),
        signature=str(d.get("signature", "")),
        fields=list(d.get("fields", [])),
        abilities=list(d.get("abilities", [])),
        base_classes=list(d.get("base_classes", [])),
        is_genai=bool(d.get("is_genai", False))
    );
}

impl CodeDiagnostic.render -> str {
    return f"{self.severity}: {self.file}:{self.line}: {self.message}";
}

impl CodeDiagnostic.to_dict -> dict[str, any] {
    return {
        "file": self.file,
        "line": self.line,
        "severity": self.severity,
        "message": self.message
    };
}


impl EntryPoint.render -> str {
    return f"{self.walker_name}.{self.ability}  ({self.event} {self.node_type})  [{self.file}:{self.line}]";
}

impl EntryPoint.to_dict -> dict[str, any] {
    return {
        "walker_name": self.walker_name,
        "ability": self.ability,
        "node_type": self.node_type,
        "event": self.event,
        "file": self.file,
        "line": self.line
    };
}

impl EntryPoint.from_dict(d: dict[str, any]) -> EntryPoint {
    return EntryPoint(
        walker_name=str(d.get("walker_name", "")),
        ability=str(d.get("ability", "")),
        node_type=str(d.get("node_type", "")),
        event=str(d.get("event", "")),
        file=str(d.get("file", "")),
        line=int(d.get("line", 0))
    );
}

impl ContextSlice.render -> str {
    if self.target is None {
        return f"(no symbol named {self.query} was found)";
    }
    parts = ["# Definition", self.target.render()];
    if self.related {
        parts.append("\n# Referenced types");
        for s in self.related {
            parts.append(s.render());
        }
    }
    if self.uses {
        parts.append(f"\n# Used in {len(self.uses)} place(s)");
        for u in self.uses {
            parts.append("  " + u.render());
        }
    }
    return "\n".join(parts);
}

impl ContextSlice.to_dict -> dict[str, any] {
    return {
        "query": self.query,
        "target": self.target.to_dict() if self.target is not None else None,
        "related": [s.to_dict() for s in self.related],
        "uses": [u.to_dict() for u in self.uses]
    };
}

impl KernelSession.strip_markers(path: str, text: str) -> MarkerScan {
    import from jaclang.compiler.tools.fix_queries { marker_scan }
    self.enter();
    try {
        return marker_scan(text, path);
    } finally {
        self.leave();
    }
}

impl KernelSession.element_spaces(path: str) -> list[ElementSpace] {
    import from jaclang.compiler.tools.fix_queries { top_element_spaces }
    return top_element_spaces(self.analysed(path));
}

impl KernelSession.client_imports(path: str) -> list[ImportSpace] {
    import from jaclang.compiler.tools.fix_queries { import_spaces }
    real = os.path.realpath(path);
    module = self.analysed(real);
    if self._program.count_module_errors(os.path.normpath(module.loc.mod_path)) {
        return [];
    }
    return import_spaces(module);
}

impl KernelSession.access_plan(project_root: str) -> AccessPlan {
    import from jaclang.compiler.tools.fix_queries { served_access_plan }
    self.enter();
    try {
        return served_access_plan(os.path.realpath(project_root));
    } finally {
        self.leave();
    }
}

impl KernelSession.package_api(base_root: str, exports: list[str]) -> str {
    import json;
    import from pathlib { Path }
    import from jaclang.compiler.driver.compilation_context { compilation_scope }
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.packages.api {
        API_FORMAT,
        MODULE_DOCS,
        doc_text,
        module_path_for,
        module_surface
    }
    root = Path(base_root);
    host = self.enter();
    program = JacProgram();
    modules: dict[str, any] = {};
    module_docs: dict[str, str] = {};
    missing: list[str] = [];
    try {
        with host.session() {
            for name in sorted(set(exports)) {
                path = module_path_for(root, name);
                if path is None {
                    missing.append(name);
                    continue;
                }
                options = CompileOptions(no_cgen=True, project_root=str(root));
                with compilation_scope(options) {
                    module = program.compile(str(path), options=options);
                }
                modules[name] = module_surface(module, program.get_type_evaluator());
                text = doc_text(module);
                if text {
                    module_docs[name] = text;
                }
            }
        }
    } finally {
        program.release_compile_closure();
        self.leave();
    }
    if missing {
        raise KernelError(
            "exported module(s) not found in the package: " + ", ".join(missing)
        );
    }
    surface: dict[str, any] = {"format": API_FORMAT, "modules": modules};
    if module_docs {
        surface[MODULE_DOCS] = module_docs;
    }
    return json.dumps(surface, sort_keys=True);
}

impl KernelSession.stub_catalog(
    out_path: str, only: list[str], pkg_dir: str
) -> StubCatalogReport {
    import from jaclang.compiler.types.stubcat.build { build_catalog }
    self.enter();
    try {
        manifest = build_catalog(
            out_path, only=only or None, pkg_dir=pkg_dir or None, quiet=True
        );
    } finally {
        self.leave();
    }
    return StubCatalogReport(
        summary=f"stubcat: {manifest['modules']} modules, {manifest['symbols']} symbols, "
            f"{manifest['types']} types, {manifest['bytes']} bytes, "
            f"{manifest['failures']} evaluation failures in {manifest['seconds']}s",
        load_failures=[str(failure) for failure in manifest["load_failures"]]
    );
}

impl KernelSession.npm_sources(project_root: str) -> list[NpmSource] {
    import from pathlib { Path }
    import from jaclang.dist.publish.npm_sources {
        NpmBoundaryError,
        collect_npm_sources
    }
    import from jaclang.project.config { get_config_for_path }
    root = Path(project_root);
    config = get_config_for_path(root);
    if config is None {
        raise KernelError(f"no jac.toml governs {project_root}");
    }
    host = self.enter();
    try {
        with host.session() {
            files = collect_npm_sources(config, project_root=root);
        }
    } except (NpmBoundaryError, ValueError) as err {
        raise KernelError(str(err)) from err;
    } finally {
        self.leave();
    }
    return [
        NpmSource(
            npm_path=item.npm_path,
            source_path=str(item.source_path) if item.source_path is not None else "",
            js=item.js,
            dts=item.dts,
            external_imports=list(item.external_imports)
        )
        for item in files
    ];
}

impl KernelSession.definition_rows(path: str) -> list[str] {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.unit_products { definition_span_rows }
    real = os.path.realpath(path);
    host = self.enter();
    try {
        return definition_span_rows(
            JacProgram().parse_source(host.read_source(real), real)
        );
    } finally {
        self.leave();
    }
}
