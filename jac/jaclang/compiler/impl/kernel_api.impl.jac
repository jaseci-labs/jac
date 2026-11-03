impl SourceSpan.to_dict -> dict[str, any] {
    return {
        "path": self.path,
        "line": self.line,
        "col": self.col,
        "end_line": self.end_line,
        "end_col": self.end_col
    };
}

impl SourceSpan.from_dict(raw: dict[str, any]) -> SourceSpan {
    return SourceSpan(
        path=str(raw["path"]),
        line=int(raw["line"]),
        col=int(raw["col"]),
        end_line=int(raw["end_line"]),
        end_col=int(raw["end_col"])
    );
}

impl RelatedNote.to_dict -> dict[str, any] {
    return {
        "label": self.label,
        "span": self.span.to_dict()
    };
}

impl RelatedNote.from_dict(raw: dict[str, any]) -> RelatedNote {
    return RelatedNote(
        label=str(raw["label"]),
        span=SourceSpan.from_dict(raw["span"])
    );
}

impl KernelDiagnostic.to_dict -> dict[str, any] {
    return {
        "code": self.code,
        "severity": self.severity,
        "message": self.message,
        "span": self.span.to_dict(),
        "help": self.help,
        "pass_name": self.pass_name,
        "related": [item.to_dict() for item in self.related]
    };
}

impl KernelDiagnostic.from_dict(raw: dict[str, any]) -> KernelDiagnostic {
    return KernelDiagnostic(
        code=str(raw["code"]),
        severity=str(raw["severity"]),
        message=str(raw["message"]),
        span=SourceSpan.from_dict(raw["span"]),
        help=str(raw["help"]),
        pass_name=str(raw["pass_name"]),
        related=[RelatedNote.from_dict(item) for item in raw["related"]]
    );
}

impl NativeDemotion.to_dict -> dict[str, any] {
    return {
        "symbol": self.symbol,
        "kind": self.kind,
        "reason": self.reason,
        "code": self.code,
        "span": self.span.to_dict()
    };
}

impl NativeDemotion.from_dict(raw: dict[str, any]) -> NativeDemotion {
    return NativeDemotion(
        symbol=str(raw["symbol"]),
        kind=str(raw["kind"]),
        reason=str(raw["reason"]),
        code=str(raw["code"]),
        span=SourceSpan.from_dict(raw["span"])
    );
}

impl CompiledUnit.to_dict -> dict[str, any] {
    return {
        "path": self.path,
        "module_name": self.module_name,
        "bytecode": self.bytecode,
        "interface": self.interface,
        "placement": self.placement,
        "client_js": self.client_js,
        "native_object": self.native_object,
        "native_iface": self.native_iface,
        "native_deps": list(self.native_deps),
        "native_ir": self.native_ir,
        "native_layout": self.native_layout,
        "demoted": [item.to_dict() for item in self.demoted],
        "jac_deps": list(self.jac_deps),
        "app": self.app,
        "persistence": list(self.persistence),
        "import_edges": list(self.import_edges),
        "interop": self.interop,
        "client_manifest": self.client_manifest,
        "iface_shape": self.iface_shape,
        "effects": self.effects,
        "sections": {str(key): value for (key, value) in self.sections.items()}
    };
}

impl CompiledUnit.from_dict(raw: dict[str, any]) -> CompiledUnit {
    return CompiledUnit(
        path=str(raw["path"]),
        module_name=str(raw["module_name"]),
        bytecode=bytes(raw["bytecode"]),
        interface=bytes(raw["interface"]),
        placement=str(raw["placement"]),
        client_js=str(raw["client_js"]),
        native_object=bytes(raw["native_object"]),
        native_iface=str(raw["native_iface"]),
        native_deps=[str(item) for item in raw["native_deps"]],
        native_ir=str(raw["native_ir"]),
        native_layout=str(raw["native_layout"]),
        demoted=[NativeDemotion.from_dict(item) for item in raw["demoted"]],
        jac_deps=[str(item) for item in raw["jac_deps"]],
        app=str(raw["app"]),
        persistence=[str(item) for item in raw["persistence"]],
        import_edges=[str(item) for item in raw["import_edges"]],
        interop=str(raw["interop"]),
        client_manifest=str(raw["client_manifest"]),
        iface_shape=str(raw["iface_shape"]),
        effects=str(raw["effects"]),
        sections={int(key): bytes(value) for (key, value) in raw["sections"].items()}
    );
}

impl CompileRequest.to_dict -> dict[str, any] {
    return {
        "paths": list(self.paths),
        "project_root": self.project_root,
        "search_paths": list(self.search_paths),
        "package_root": self.package_root,
        "options": self.options.to_dict(),
        "sources": dict(self.sources),
        "products": list(self.products)
    };
}

impl CompileRequest.from_dict(raw: dict[str, any]) -> CompileRequest {
    return CompileRequest(
        paths=[str(item) for item in raw["paths"]],
        project_root=str(raw["project_root"]),
        search_paths=[str(item) for item in raw["search_paths"]],
        package_root=str(raw["package_root"]),
        options=CompileOptions.from_dict(raw["options"]),
        sources={str(key): str(value) for (key, value) in raw["sources"].items()},
        products=[str(item) for item in raw["products"]]
    );
}

impl SourceRead.to_dict -> dict[str, any] {
    return {
        "path": self.path,
        "digest": self.digest
    };
}

impl SourceRead.from_dict(raw: dict[str, any]) -> SourceRead {
    return SourceRead(
        path=str(raw["path"]),
        digest=str(raw["digest"])
    );
}

impl CompileResult.to_dict -> dict[str, any] {
    return {
        "units": [item.to_dict() for item in self.units],
        "errors": [item.to_dict() for item in self.errors],
        "warnings": [item.to_dict() for item in self.warnings],
        "reached": list(self.reached),
        "reads": [item.to_dict() for item in self.reads]
    };
}

impl CompileResult.from_dict(raw: dict[str, any]) -> CompileResult {
    return CompileResult(
        units=[CompiledUnit.from_dict(item) for item in raw["units"]],
        errors=[KernelDiagnostic.from_dict(item) for item in raw["errors"]],
        warnings=[KernelDiagnostic.from_dict(item) for item in raw["warnings"]],
        reached=[str(item) for item in raw["reached"]],
        reads=[SourceRead.from_dict(item) for item in raw["reads"]]
    );
}

impl CoverageRow.to_dict -> dict[str, any] {
    return {
        "path": self.path,
        "outcome": self.outcome,
        "code": self.code,
        "detail": self.detail,
        "seams": list(self.seams),
        "late": self.late
    };
}

impl CoverageRow.from_dict(raw: dict[str, any]) -> CoverageRow {
    return CoverageRow(
        path=str(raw["path"]),
        outcome=str(raw["outcome"]),
        code=str(raw["code"]),
        detail=str(raw["detail"]),
        seams=[str(item) for item in raw["seams"]],
        late=int(raw["late"])
    );
}

impl PlacementRow.to_dict -> dict[str, any] {
    return {
        "path": self.path,
        "symbol": self.symbol,
        "placement": self.placement,
        "reason": self.reason
    };
}

impl PlacementRow.from_dict(raw: dict[str, any]) -> PlacementRow {
    return PlacementRow(
        path=str(raw["path"]),
        symbol=str(raw["symbol"]),
        placement=str(raw["placement"]),
        reason=str(raw["reason"])
    );
}

impl CheckRequest.to_dict -> dict[str, any] {
    return {
        "paths": list(self.paths),
        "project_root": self.project_root,
        "search_paths": list(self.search_paths),
        "package_root": self.package_root,
        "options": self.options.to_dict(),
        "sources": dict(self.sources),
        "native_coverage": self.native_coverage,
        "placements": self.placements,
        "closure": self.closure
    };
}

impl CheckRequest.from_dict(raw: dict[str, any]) -> CheckRequest {
    return CheckRequest(
        paths=[str(item) for item in raw["paths"]],
        project_root=str(raw["project_root"]),
        search_paths=[str(item) for item in raw["search_paths"]],
        package_root=str(raw["package_root"]),
        options=CompileOptions.from_dict(raw["options"]),
        sources={str(key): str(value) for (key, value) in raw["sources"].items()},
        native_coverage=bool(raw["native_coverage"]),
        placements=bool(raw["placements"]),
        closure=bool(raw["closure"])
    );
}

impl CheckResult.to_dict -> dict[str, any] {
    return {
        "errors": [item.to_dict() for item in self.errors],
        "warnings": [item.to_dict() for item in self.warnings],
        "reached": list(self.reached),
        "coverage": [item.to_dict() for item in self.coverage],
        "placements": [item.to_dict() for item in self.placements]
    };
}

impl CheckResult.from_dict(raw: dict[str, any]) -> CheckResult {
    return CheckResult(
        errors=[KernelDiagnostic.from_dict(item) for item in raw["errors"]],
        warnings=[KernelDiagnostic.from_dict(item) for item in raw["warnings"]],
        reached=[str(item) for item in raw["reached"]],
        coverage=[CoverageRow.from_dict(item) for item in raw["coverage"]],
        placements=[PlacementRow.from_dict(item) for item in raw["placements"]]
    );
}

impl TextEdit.to_dict -> dict[str, any] {
    return {
        "span": self.span.to_dict(),
        "text": self.text
    };
}

impl TextEdit.from_dict(raw: dict[str, any]) -> TextEdit {
    return TextEdit(
        span=SourceSpan.from_dict(raw["span"]),
        text=str(raw["text"])
    );
}

impl CompletionItem.to_dict -> dict[str, any] {
    return {
        "label": self.label,
        "kind": self.kind,
        "detail": self.detail,
        "insert_text": self.insert_text
    };
}

impl CompletionItem.from_dict(raw: dict[str, any]) -> CompletionItem {
    return CompletionItem(
        label=str(raw["label"]),
        kind=str(raw["kind"]),
        detail=str(raw["detail"]),
        insert_text=str(raw["insert_text"])
    );
}

impl InlayHint.to_dict -> dict[str, any] {
    return {
        "line": self.line,
        "col": self.col,
        "label": self.label,
        "kind": self.kind
    };
}

impl InlayHint.from_dict(raw: dict[str, any]) -> InlayHint {
    return InlayHint(
        line=int(raw["line"]),
        col=int(raw["col"]),
        label=str(raw["label"]),
        kind=str(raw["kind"])
    );
}

impl DocumentSymbol.to_dict -> dict[str, any] {
    return {
        "name": self.name,
        "kind": self.kind,
        "span": self.span.to_dict(),
        "children": [item.to_dict() for item in self.children]
    };
}

impl DocumentSymbol.from_dict(raw: dict[str, any]) -> DocumentSymbol {
    return DocumentSymbol(
        name=str(raw["name"]),
        kind=str(raw["kind"]),
        span=SourceSpan.from_dict(raw["span"]),
        children=[DocumentSymbol.from_dict(item) for item in raw["children"]]
    );
}

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
    if not package_root {
        raise KernelError("the request names no jaclang package root");
    }
    if not search_paths {
        raise KernelError("the request names no module search paths");
    }
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

impl other_compiler_diagnostic(path: str, tree: str) -> KernelDiagnostic {
    return KernelDiagnostic(
        code=E1408.code,
        severity="error",
        message=E1408.format_message(path=path, tree=tree),
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
        bytecode=products.bytecode,
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
    for real in emitted_paths(host, requested) {
        result.units.append(compiled_unit(host, real, want_code));
    }
    return result;
}

impl run_check(
    program: JacProgram, host: ProjectHost, request: CheckRequest
) -> CheckResult {
    result = CheckResult();
    options = copy.copy(request.options);
    options.no_cgen = not request.native_coverage;
    for (path, text) in request.sources.items() {
        host.overlay[os.path.realpath(path)] = text;
    }
    if request.native_coverage {
        na_coverage_begin();
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
        for (path, record) in sorted(na_coverage_end().items()) {
            result.coverage.append(
                CoverageRow(
                    path=path,
                    outcome=str(record["outcome"]),
                    code=str(record.get("code", "")),
                    detail=str(record.get("detail", "")),
                    seams=[str(seam) for seam in record.get("seams", [])],
                    late=int(record.get("late", 0))
                )
            );
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
    enter_world(request.project_root, request.search_paths, request.package_root);
    host = ProjectHost(root_dir=request.project_root);
    previous = enter_compiler(host);
    try {
        return run_compile(JacProgram(), host, request);
    } finally {
        leave_compiler(previous);
    }
}

impl check_request(request: CheckRequest) -> CheckResult {
    enter_world(request.project_root, request.search_paths, request.package_root);
    host = ProjectHost(root_dir=request.project_root);
    previous = enter_compiler(host);
    try {
        return run_check(JacProgram(), host, request);
    } finally {
        leave_compiler(previous);
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
    enter_world(self.project_root, self.search_paths, self.package_root);
    self._host = ProjectHost(root_dir=self.project_root);
    program = JacProgram();
    program.deps.tracking = True;
    self._program = program;
    self.options = copy.copy(self.options);
    self.options.no_cgen = True;
}

impl KernelSession.enter -> ProjectHost {
    host = self._host;
    if host is None or self._program is None {
        raise KernelError("the kernel session is closed");
    }
    self._entered.append(enter_compiler(host));
    return host;
}

impl KernelSession.leave {
    leave_compiler(self._entered.pop());
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
    real = os.path.realpath(path);
    module = self.analysed(real);
    selected = token_at(module, real, line, col);
    return hover_text(selected) if selected is not None else "";
}

impl KernelSession.definition(path: str, line: int, col: int) -> list[SourceSpan] {
    real = os.path.realpath(path);
    module = self.analysed(real);
    selected = token_at(module, real, line, col);
    if selected is None {
        return string_import_definition(module, line, col);
    }
    return definition_spans(self._program, selected);
}

impl KernelSession.references(path: str, line: int, col: int) -> list[SourceSpan] {
    real = os.path.realpath(path);
    selected = token_at(self.analysed(real), real, line, col);
    return reference_spans(selected) if selected is not None else [];
}

impl KernelSession.completion(
    path: str, line: int, col: int, trigger: str = ""
) -> list[CompletionItem] {
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
    real = os.path.realpath(path);
    return semantic_token_data(self.analysed(real), real);
}

impl KernelSession.inlay_hints(
    path: str, first_line: int, last_line: int
) -> list[InlayHint] {
    return inlay_hint_rows(self.analysed(path), first_line, last_line);
}

impl KernelSession.symbols(path: str) -> list[DocumentSymbol] {
    module = self.analysed(path);
    return outline(module.sym_tab);
}

impl KernelSession.rename(
    path: str, line: int, col: int, new_name: str
) -> list[TextEdit] {
    real = os.path.realpath(path);
    selected = token_at(self.analysed(real), real, line, col);
    return rename_edits(selected, new_name) if selected is not None else [];
}

impl KernelSession.format(path: str) -> str {
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

impl session_query(session: KernelSession, method: str, args: list[any]) -> any {
    if method == "update" {
        session.update(str(args[0]), str(args[1]));
        return None;
    }
    if method == "close" {
        session.close(str(args[0]));
        return None;
    }
    if method == "forget" {
        session.forget(str(args[0]));
        return None;
    }
    if method == "rename_module" {
        session.rename_module(str(args[0]), str(args[1]));
        return None;
    }
    if method == "diagnostics" {
        return [item.to_dict() for item in session.diagnostics(str(args[0]))];
    }
    if method == "hover" {
        return session.hover(str(args[0]), int(args[1]), int(args[2]));
    }
    if method == "definition" {
        return [
            item.to_dict()
            for item in session.definition(str(args[0]), int(args[1]), int(args[2]))
        ];
    }
    if method == "references" {
        return [
            item.to_dict()
            for item in session.references(str(args[0]), int(args[1]), int(args[2]))
        ];
    }
    if method == "completion" {
        return [
            item.to_dict()
            for item in session.completion(
                str(args[0]), int(args[1]), int(args[2]), str(args[3])
            )
        ];
    }
    if method == "semantic_tokens" {
        return list(session.semantic_tokens(str(args[0])));
    }
    if method == "inlay_hints" {
        return [
            item.to_dict()
            for item in session.inlay_hints(str(args[0]), int(args[1]), int(args[2]))
        ];
    }
    if method == "symbols" {
        return [item.to_dict() for item in session.symbols(str(args[0]))];
    }
    if method == "rename" {
        return [
            item.to_dict()
            for item in session.rename(
                str(args[0]), int(args[1]), int(args[2]), str(args[3])
            )
        ];
    }
    if method == "format" {
        return session.format(str(args[0]));
    }
    if method == "lint_fix" {
        return session.lint_fix(str(args[0]));
    }
    if method == "compile" {
        return session.compile(CompileRequest.from_dict(args[0])).to_dict();
    }
    if method == "check" {
        return session.check(CheckRequest.from_dict(args[0])).to_dict();
    }
    raise KernelError(f"the kernel session has no query {method!r}");
}
