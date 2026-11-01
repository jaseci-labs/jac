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

impl compiled_unit(host: ProjectHost, real: str, want_code: bool) -> CompiledUnit {
    import from jaclang.compiler.backends.py.kernel_bytecode { kernel_code_object }
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
            if want_code {
                refuse_native_only(real, request.package_root);
            }
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
    for real in emitted_paths(host, requested) {
        result.units.append(compiled_unit(host, real, want_code));
    }
    return result;
}

impl refuse_native_only(real: str, package_root: str) {
    import from jaclang.compiler.native_scope { is_native_only }
    pkg = os.path.realpath(package_root) + os.sep;
    if not real.startswith(pkg) {
        return;
    }
    rel = real[len(pkg):].replace(os.sep, "/");
    if is_native_only(rel) {
        raise KernelError(
            f"jaclang/{rel} is native-only: it is compiled into the kernel and "
            "has no bytecode, so it cannot be imported"
        );
    }
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
    result.reached = sorted(host.analyses.keys());
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

impl KernelBuildResult.ok -> bool {
    return not self.errors;
}

impl build_kernel_request(request: KernelBuildRequest) -> KernelBuildResult {
    import hashlib;
    import from jaclang.compiler.backends.native.kernel_stage0 {
        KernelEntryError,
        kernel_llvm_runpath,
        link_kernel
    }
    import from jaclang.compiler.backends.native.link_plan { LinkPlanError }
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.frontend.host { active_host, install_host }
    import from jaclang.compiler.kernel_target { set_kernel_target }
    import from jaclang.compiler.target_spec { host_target_spec, target_spec }
    import from jaclang.project.compiler_host { ProjectHost }
    target = request.target;
    if not target.root or not target.root_module {
        raise KernelError("the kernel build request names no target root or root module");
    }
    if not request.output {
        raise KernelError("the kernel build request names no output");
    }
    project_root = os.path.dirname(target.root);
    enter_world(project_root, request.search_paths, request.package_root);
    spec = target_spec(request.triple) if request.triple else host_target_spec();
    host = ProjectHost(root=project_root);
    previous_host = active_host();
    previous_target = set_kernel_target(target);
    install_host(host);
    result = KernelBuildResult(output=request.output, triple=spec.triple);
    program = JacProgram();
    try {
        with host.session() {
            linked = link_kernel(
                request.output,
                target=target,
                prog=program,
                link_mode=target.link_mode,
                spec=spec,
                runpath=kernel_llvm_runpath(request.output, target.root)
            );
        }
    } except (KernelEntryError, LinkPlanError) as error {
        raise KernelError(str(error)) from error;
    } finally {
        install_host(previous_host);
        set_kernel_target(previous_target);
    }
    collect_diagnostics(program, result.errors, result.warnings);
    with open(request.output, "rb") as built {
        result.artifact_sha256 = hashlib.sha256(built.read()).hexdigest();
    }
    if result.artifact_sha256 != linked.sha256 {
        raise KernelError(
            f"{request.output} does not match the sha256 its link recorded"
        );
    }
    result.plan_digest = linked.plan_digest;
    result.units = len(linked.units);
    result.inputs = [
        SourceRead(path=path, digest=digest)
        for (path, digest) in sorted(host.source_reads.items())
    ];
    return result;
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

impl KernelSession.analysed(path: str) -> uni.Module {
    real = os.path.realpath(path);
    program = self._program;
    host = self.enter();
    try {
        version = self._versions.get(real, 0);
        held = program.find_module(real);
        if held is not None and self._analysed.get(real) == version {
            return held;
        }
        program.drop_module_alerts(real);
        with host.session() {
            module = program.compile(
                real, use_str=host.overlay.get(real), options=self.options
            );
        }
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
    self._versions[real] = self._versions.get(real, 0) + 1;
    self.invalidate(real);
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
        self._versions[real] = self._versions.get(real, 0) + 1;
        self.invalidate(real);
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
    self.invalidate(real);
    program.release_module(real);
    self._versions.pop(real, None);
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
    self._versions[new_real] = self._versions.get(new_real, 0) + 1;
    self.invalidate(new_real);
}

impl KernelSession.diagnostics(path: str) -> list[KernelDiagnostic] {
    real = os.path.realpath(path);
    self.analysed(real);
    program = self._program;
    found: list[KernelDiagnostic] = [];
    for alert in program.errors_had {
        if alert.loc.mod_path and os.path.realpath(alert.loc.mod_path) == real {
            found.append(kernel_diagnostic(alert, "error"));
        }
    }
    for alert in program.warnings_had {
        if alert.loc.mod_path and os.path.realpath(alert.loc.mod_path) == real {
            found.append(kernel_diagnostic(alert, "warning"));
        }
    }
    return found;
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

impl KernelSession.completion(
    path: str, line: int, col: int, trigger: str = ""
) -> list[CompletionItem] {
    import from jaclang.compiler.tools.session_queries { completion_items }
    real = os.path.realpath(path);
    module = self.analysed(real);
    self.enter();
    try {
        return completion_items(self._program, module, line, col, trigger);
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

impl KernelSession.format(path: str) -> str {
    import from jaclang.compiler.driver.program { JacProgram }
    real = os.path.realpath(path);
    host = self.enter();
    try {
        formatted = JacProgram.jac_str_formatter(host.read_source(real), real);
    } finally {
        self.leave();
    }
    if formatted.errors_had {
        raise KernelError(f"{real} does not parse: {formatted.errors_had[0].msg}");
    }
    return formatted.mod.main.gen.jac;
}

impl KernelSession.lint_fix(path: str) -> str {
    import from jaclang.compiler.driver.program { JacProgram }
    real = os.path.realpath(path);
    host = self.enter();
    try {
        fixed = JacProgram.jac_str_formatter(host.read_source(real), real, True);
    } finally {
        self.leave();
    }
    if fixed.errors_had {
        raise KernelError(f"{real} does not parse: {fixed.errors_had[0].msg}");
    }
    return fixed.mod.main.gen.jac;
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
