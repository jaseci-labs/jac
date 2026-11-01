impl options_record(options: CompileOptions) -> dict[str, any] {
    record: dict[str, any] = {};
    for name in KERNEL_OPTION_FIELDS {
        value = getattr(options, name);
        record[name] = list(value) if isinstance(value, list) else value;
    }
    return record;
}

impl compile_request_record(request: CompileRequest) -> dict[str, any] {
    return {
        "paths": list(request.paths),
        "project_root": request.project_root,
        "search_paths": list(request.search_paths),
        "package_root": request.package_root,
        "options": options_record(request.options),
        "sources": dict(request.sources),
        "products": list(request.products)
    };
}

impl check_request_record(request: CheckRequest) -> dict[str, any] {
    return {
        "paths": list(request.paths),
        "project_root": request.project_root,
        "search_paths": list(request.search_paths),
        "package_root": request.package_root,
        "options": options_record(request.options),
        "sources": dict(request.sources),
        "native_coverage": request.native_coverage,
        "placements": request.placements,
        "closure": request.closure,
        "module_facts": request.module_facts
    };
}

impl kernel_build_request_record(request: KernelBuildRequest) -> dict[str, any] {
    return {
        "target": request.target.to_dict(),
        "output": request.output,
        "triple": request.triple,
        "search_paths": list(request.search_paths),
        "package_root": request.package_root
    };
}

impl span_of_record(raw: dict[str, any]) -> SourceSpan {
    return SourceSpan(
        path=raw["path"],
        line=raw["line"],
        col=raw["col"],
        end_line=raw["end_line"],
        end_col=raw["end_col"]
    );
}

impl diagnostic_of_record(raw: dict[str, any]) -> KernelDiagnostic {
    return KernelDiagnostic(
        code=raw["code"],
        severity=raw["severity"],
        message=raw["message"],
        span=span_of_record(raw["span"]),
        help=raw["help"],
        pass_name=raw["pass_name"],
        related=[
            RelatedNote(label=note["label"], span=span_of_record(note["span"]))
            for note in raw["related"]
        ]
    );
}

impl demotion_of_record(raw: dict[str, any]) -> NativeDemotion {
    return NativeDemotion(
        symbol=raw["symbol"],
        kind=raw["kind"],
        reason=raw["reason"],
        code=raw["code"],
        span=span_of_record(raw["span"])
    );
}

impl unit_of_record(raw: dict[str, any]) -> CompiledUnit {
    return CompiledUnit(
        path=raw["path"],
        module_name=raw["module_name"],
        code=raw["code"],
        interface=raw["interface"],
        placement=raw["placement"],
        client_js=raw["client_js"],
        native_object=raw["native_object"],
        native_iface=raw["native_iface"],
        native_deps=list(raw["native_deps"]),
        native_ir=raw["native_ir"],
        native_mir=raw["native_mir"],
        native_layout=raw["native_layout"],
        demoted=[demotion_of_record(row) for row in raw["demoted"]],
        jac_deps=list(raw["jac_deps"]),
        app=raw["app"],
        persistence=list(raw["persistence"]),
        import_edges=list(raw["import_edges"]),
        interop=raw["interop"],
        client_manifest=raw["client_manifest"],
        iface_shape=raw["iface_shape"],
        effects=raw["effects"],
        sections=dict(raw["sections"]),
        python_ast=raw["python_ast"]
    );
}

impl compile_result_of(raw: dict[str, any]) -> CompileResult {
    return CompileResult(
        units=[unit_of_record(unit) for unit in raw["units"]],
        errors=[diagnostic_of_record(diag) for diag in raw["errors"]],
        warnings=[diagnostic_of_record(diag) for diag in raw["warnings"]],
        reached=list(raw["reached"]),
        reads=[
            SourceRead(path=read["path"], digest=read["digest"])
            for read in raw["reads"]
        ]
    );
}

impl check_result_of(raw: dict[str, any]) -> CheckResult {
    return CheckResult(
        errors=[diagnostic_of_record(diag) for diag in raw["errors"]],
        warnings=[diagnostic_of_record(diag) for diag in raw["warnings"]],
        reached=list(raw["reached"]),
        coverage=[
            CoverageRow(
                path=row["path"],
                native=row["native"],
                demoted=[demotion_of_record(item) for item in row["demoted"]]
            )
            for row in raw["coverage"]
        ],
        placements=[
            PlacementRow(
                path=row["path"],
                symbol=row["symbol"],
                placement=row["placement"],
                reason=row["reason"]
            )
            for row in raw["placements"]
        ],
        modules=[
            ModuleFact(
                path=row["path"],
                app=row["app"],
                spaces=list(row["spaces"]),
                decided=row["decided"],
                client_declared=row["client_declared"],
                errors=row["errors"],
                imports=list(row["imports"])
            )
            for row in raw["modules"]
        ],
        app_edges=[
            AppEdge(consumer=row["consumer"], provider=row["provider"])
            for row in raw["app_edges"]
        ]
    );
}

impl kernel_build_result_of(raw: dict[str, any]) -> KernelBuildResult {
    return KernelBuildResult(
        output=raw["output"],
        triple=raw["triple"],
        artifact_sha256=raw["artifact_sha256"],
        plan_digest=raw["plan_digest"],
        units=raw["units"],
        errors=[diagnostic_of_record(diag) for diag in raw["errors"]],
        warnings=[diagnostic_of_record(diag) for diag in raw["warnings"]],
        inputs=[
            SourceRead(path=read["path"], digest=read["digest"])
            for read in raw["inputs"]
        ]
    );
}

impl call_compile(request: CompileRequest) -> CompileResult {
    kernel = load_kernel();
    try {
        raw = kernel.compile(compile_request_record(request));
    } except kernel.KernelError as error {
        raise KernelError(str(error)) from error;
    }
    return compile_result_of(raw);
}

impl call_check(request: CheckRequest) -> CheckResult {
    kernel = load_kernel();
    try {
        raw = kernel.check(check_request_record(request));
    } except kernel.KernelError as error {
        raise KernelError(str(error)) from error;
    }
    return check_result_of(raw);
}

impl call_build_kernel(request: KernelBuildRequest) -> KernelBuildResult {
    kernel = load_kernel();
    try {
        raw = kernel.build_kernel(kernel_build_request_record(request));
    } except kernel.KernelError as error {
        raise KernelError(str(error)) from error;
    }
    return kernel_build_result_of(raw);
}

impl open_kernel_session(project_root: str) -> any {
    kernel = load_kernel();
    try {
        return kernel.open_session(project_root, list(sys.path), package_root());
    } except kernel.KernelError as error {
        raise KernelError(str(error)) from error;
    }
}

impl kernel_tests -> list[KernelTestCase] {
    kernel = load_kernel();
    try {
        raw = kernel.tests();
    } except kernel.KernelError as error {
        raise KernelError(str(error)) from error;
    }
    return [KernelTestCase(suite=row["suite"], name=row["name"]) for row in raw];
}

impl call_kernel_tests(
    suite: str, scratch: str, names: (list[str] | None) = None
) -> list[KernelTestOutcome] {
    kernel = load_kernel();
    try {
        raw = kernel.run_tests(
            {
                "suite": suite,
                "scratch": scratch,
                "names": list(names or []),
                "search_paths": list(sys.path),
                "package_root": package_root()
            }
        );
    } except kernel.KernelError as error {
        raise KernelError(str(error)) from error;
    }
    return [
        KernelTestOutcome(
            suite=row["suite"],
            name=row["name"],
            passed=row["passed"],
            message=row["message"]
        )
        for row in raw
    ];
}

impl completion_of_record(raw: dict[str, any]) -> CompletionItem {
    return CompletionItem(
        label=raw["label"],
        kind=raw["kind"],
        detail=raw["detail"],
        insert_text=raw["insert_text"]
    );
}

impl hint_of_record(raw: dict[str, any]) -> InlayHint {
    return InlayHint(
        line=raw["line"], col=raw["col"], label=raw["label"], kind=raw["kind"]
    );
}

impl symbol_of_record(raw: dict[str, any]) -> DocumentSymbol {
    return DocumentSymbol(
        name=raw["name"],
        kind=raw["kind"],
        span=span_of_record(raw["span"]),
        children=[symbol_of_record(child) for child in raw["children"]]
    );
}

impl edit_of_record(raw: dict[str, any]) -> TextEdit {
    return TextEdit(span=span_of_record(raw["span"]), text=raw["text"]);
}

impl output_of_record(raw: dict[str, any]) -> ToolOutput {
    return ToolOutput(
        text=raw["text"],
        errors=[diagnostic_of_record(diag) for diag in raw["errors"]],
        warnings=[diagnostic_of_record(diag) for diag in raw["warnings"]]
    );
}

impl grammar_of_record(raw: dict[str, any]) -> GrammarReport {
    return GrammarReport(
        ebnf=raw["ebnf"],
        rules=raw["rules"],
        diagnostics=raw["diagnostics"],
        errors=[diagnostic_of_record(diag) for diag in raw["errors"]]
    );
}

impl arch_plan_of_record(raw: dict[str, any]) -> ArchPlan {
    return ArchPlan(
        arch_path=raw["arch_path"],
        text=raw["text"],
        modules=list(raw["modules"]),
        fed=list(raw["fed"]),
        added=raw["added"],
        dropped=raw["dropped"],
        rules=raw["rules"],
        rules_added=raw["rules_added"],
        refusal=raw["refusal"],
        hint=raw["hint"]
    );
}

impl SessionClient.postinit {
    self.handle = open_kernel_session(self.project_root);
}

impl SessionClient.ask(method: str, *args: any) -> any {
    kernel = load_kernel();
    with self._lock {
        try {
            return getattr(self.handle, method)(*args);
        } except kernel.KernelError as error {
            raise KernelError(str(error)) from error;
        }
    }
}

impl SessionClient.update(path: str, text: str) {
    self.ask("update", path, text);
}

impl SessionClient.close(path: str) {
    self.ask("close", path);
}

impl SessionClient.forget(path: str) {
    self.ask("forget", path);
}

impl SessionClient.rename_module(old_path: str, new_path: str) {
    self.ask("rename_module", old_path, new_path);
}

impl SessionClient.dependents(path: str) -> list[str] {
    return list(self.ask("dependents", path));
}

impl SessionClient.set_shared_app_limit(limit: int) {
    self.ask("set_shared_app_limit", limit);
}

impl SessionClient.diagnostics(path: str) -> list[KernelDiagnostic] {
    return [diagnostic_of_record(diag) for diag in self.ask("diagnostics", path)];
}

impl SessionClient.hover(path: str, line: int, col: int) -> str {
    return self.ask("hover", path, line, col);
}

impl SessionClient.definition(path: str, line: int, col: int) -> list[SourceSpan] {
    return [span_of_record(span) for span in self.ask("definition", path, line, col)];
}

impl SessionClient.references(path: str, line: int, col: int) -> list[SourceSpan] {
    return [span_of_record(span) for span in self.ask("references", path, line, col)];
}

impl SessionClient.completion(path: str, line: int, col: int) -> list[CompletionItem] {
    return [completion_of_record(item) for item in self.ask("completion", path, line, col)];
}

impl SessionClient.semantic_tokens(path: str) -> list[int] {
    return list(self.ask("semantic_tokens", path));
}

impl SessionClient.inlay_hints(
    path: str, first_line: int, last_line: int
) -> list[InlayHint] {
    return [
        hint_of_record(hint)
        for hint in self.ask("inlay_hints", path, first_line, last_line)
    ];
}

impl SessionClient.symbols(path: str) -> list[DocumentSymbol] {
    return [symbol_of_record(symbol) for symbol in self.ask("symbols", path)];
}

impl SessionClient.rename(
    path: str, line: int, col: int, new_name: str
) -> list[TextEdit] {
    return [
        edit_of_record(edit)
        for edit in self.ask("rename", path, line, col, new_name)
    ];
}

impl SessionClient.format(path: str) -> ToolOutput {
    return output_of_record(self.ask("format", path));
}

impl SessionClient.lint_fix(path: str) -> ToolOutput {
    return output_of_record(self.ask("lint_fix", path));
}

impl SessionClient.lint(path: str) -> ToolOutput {
    return output_of_record(self.ask("lint", path));
}

impl SessionClient.parse(path: str) -> ToolOutput {
    return output_of_record(self.ask("parse", path));
}

impl SessionClient.statements(path: str) -> list[SourceSpan] {
    return [span_of_record(span) for span in self.ask("statements", path)];
}

impl SessionClient.py_to_jac(path: str) -> ToolOutput {
    return output_of_record(self.ask("py_to_jac", path));
}

impl SessionClient.ast_view(path: str, view: str) -> ToolOutput {
    return output_of_record(self.ask("ast_view", path, view));
}

impl SessionClient.explain(
    path: str, topic: str, memory_profile: str = ""
) -> ToolOutput {
    return output_of_record(self.ask("explain", path, topic, memory_profile));
}

impl SessionClient.grammar -> GrammarReport {
    return grammar_of_record(self.ask("grammar"));
}

impl SessionClient.arch_plan(
    arch_path: str, action: str, prune: bool = False, graph_format: str = ""
) -> ArchPlan {
    return arch_plan_of_record(
        self.ask("arch_plan", arch_path, action, prune, graph_format)
    );
}

impl SessionClient.compile(request: CompileRequest) -> CompileResult {
    return compile_result_of(self.ask("compile", compile_request_record(request)));
}

impl SessionClient.check(request: CheckRequest) -> CheckResult {
    return check_result_of(self.ask("check", check_request_record(request)));
}

impl SessionClient.with_text(path: str, text: str, query: Callable[[], any]) -> any {
    with self._lock {
        self.update(path, text);
        try {
            return query();
        } finally {
            self.close(path);
        }
    }
}

impl SessionClient.format_text(
    path: str, text: str, auto_lint: bool = False
) -> ToolOutput {
    return self.with_text(
        path,
        text,
        lambda -> ToolOutput {
            return self.lint_fix(path) if auto_lint else self.format(path);
        }
    );
}

impl tool_session(project_root: str = "") -> SessionClient {
    held = _TOOL_SESSIONS.get(project_root);
    if held is None {
        held = SessionClient(project_root=project_root);
        _TOOL_SESSIONS[project_root] = held;
    }
    return held;
}

impl diagnostic_text(diag: KernelDiagnostic) -> str {
    return f"{diag.span.path}, line {diag.span.line}, col {diag.span.col}: {diag.message}";
}

impl outline_of_record(raw: dict[str, any]) -> ModuleOutline {
    return ModuleOutline(
        path=raw["path"],
        doc=raw["doc"],
        files=list(raw["files"]),
        error=raw["error"],
        symbols=[
            OutlineSymbol(
                kind=row["kind"],
                name=row["name"],
                owner=row["owner"],
                file=row["file"],
                line=row["line"],
                end_line=row["end_line"],
                col=row["col"],
                doc=row["doc"],
                bases=list(row["bases"]),
                signature=row["signature"],
                event=row["event"],
                type_str=row["type_str"],
                target=row["target"]
            )
            for row in raw["symbols"]
        ]
    );
}

impl edit_symbol_of_record(raw: dict[str, any]) -> EditSymbol {
    return EditSymbol(
        key=raw["key"],
        kind=raw["kind"],
        line=raw["line"],
        end_line=raw["end_line"],
        text=raw["text"],
        signature=raw["signature"]
    );
}

impl wiring_change_of_record(raw: dict[str, any]) -> WiringChange {
    return WiringChange(kind=raw["kind"], detail=raw["detail"], module=raw["module"]);
}

impl wiring_model_of_record(raw: dict[str, any]) -> WiringModel {
    return WiringModel(
        arch_path=raw["arch_path"],
        parsed=raw["parsed"],
        modules=[
            WiringModule(
                local=row["local"],
                file=row["file"],
                import_name=row["import_name"],
                project=row["project"]
            )
            for row in raw["modules"]
        ],
        edges=[
            WiringEdge(
                provider=row["provider"],
                consumer=row["consumer"],
                scope=list(row["scope"]),
                names=list(row["names"]),
                form=row["form"],
                injected=row["injected"],
                line=row["line"],
                crosses=row["crosses"],
                rules=list(row["rules"]),
                violation=row["violation"],
                arms=list(row["arms"])
            )
            for row in raw["edges"]
        ],
        rules=[
            WiringRule(
                name=row["name"],
                sources=list(row["sources"]),
                targets=list(row["targets"]),
                names=list(row["names"]),
                governs=list(row["governs"])
            )
            for row in raw["rules"]
        ]
    );
}

impl token_symbol_of_record(raw: dict[str, any]) -> TokenSymbol {
    return TokenSymbol(
        line=raw["line"],
        col=raw["col"],
        end_col=raw["end_col"],
        name=raw["name"],
        kind=raw["kind"],
        dotted=raw["dotted"],
        decl_path=raw["decl_path"],
        decl_line=raw["decl_line"],
        decl_col=raw["decl_col"]
    );
}

impl token_stream_of_record(raw: dict[str, any]) -> TokenStream {
    return TokenStream(
        tokens=[
            SourceToken(
                kind=tok["kind"],
                value=tok["value"],
                line=tok["line"],
                col=tok["col"],
                end_line=tok["end_line"],
                end_col=tok["end_col"]
            )
            for tok in raw["tokens"]
        ],
        comments=[span_of_record(span) for span in raw["comments"]]
    );
}

impl symbol_info_of_record(raw: dict[str, any]) -> SymbolInfo {
    return SymbolInfo(
        name=raw["name"],
        kind=raw["kind"],
        file=raw["file"],
        line=raw["line"],
        col=raw["col"],
        type_str=raw["type_str"],
        doc=raw["doc"],
        signature=raw["signature"],
        fields=list(raw["fields"]),
        abilities=list(raw["abilities"]),
        base_classes=list(raw["base_classes"]),
        is_genai=raw["is_genai"]
    );
}

impl source_ref_of_record(raw: dict[str, any]) -> SourceRef {
    return SourceRef(
        file=raw["file"],
        line=raw["line"],
        col=raw["col"],
        role=raw["role"],
        snippet=raw["snippet"]
    );
}

impl entry_point_of_record(raw: dict[str, any]) -> EntryPoint {
    return EntryPoint(
        walker_name=raw["walker_name"],
        ability=raw["ability"],
        node_type=raw["node_type"],
        event=raw["event"],
        file=raw["file"],
        line=raw["line"]
    );
}

impl context_slice_of_record(raw: dict[str, any]) -> ContextSlice {
    target = raw["target"];
    return ContextSlice(
        query=raw["query"],
        target=symbol_info_of_record(target) if target is not None else None,
        related=[symbol_info_of_record(row) for row in raw["related"]],
        uses=[source_ref_of_record(row) for row in raw["uses"]]
    );
}

impl code_diagnostic_of_record(raw: dict[str, any]) -> CodeDiagnostic {
    return CodeDiagnostic(
        file=raw["file"],
        line=raw["line"],
        severity=raw["severity"],
        message=raw["message"]
    );
}

impl SessionClient.module_outline(path: str) -> ModuleOutline {
    return outline_of_record(self.ask("module_outline", path));
}

impl SessionClient.edit_symbols(path: str, text: str) -> list[EditSymbol] {
    return [edit_symbol_of_record(row) for row in self.ask("edit_symbols", path, text)];
}

impl SessionClient.import_texts(path: str, text: str) -> list[str] {
    return list(self.ask("import_texts", path, text));
}

impl SessionClient.wiring_changes(
    path: str, old_text: str, new_text: str
) -> list[WiringChange] {
    return [
        wiring_change_of_record(row)
        for row in self.ask("wiring_changes", path, old_text, new_text)
    ];
}

impl SessionClient.wired_dependents(head: str, names: list[str]) -> WiredFiles {
    raw = self.ask("wired_dependents", head, list(names));
    return WiredFiles(owned=raw["owned"], files=list(raw["files"]));
}

impl SessionClient.wiring_module_files(
    arch_path: str, consumers: list[str]
) -> list[str] {
    return list(self.ask("wiring_module_files", arch_path, list(consumers)));
}

impl SessionClient.wiring_model(arch_path: str) -> WiringModel {
    return wiring_model_of_record(self.ask("wiring_model", arch_path));
}

impl SessionClient.token_symbols(path: str) -> list[TokenSymbol] {
    return [token_symbol_of_record(row) for row in self.ask("token_symbols", path)];
}

impl SessionClient.assignment_hints(path: str) -> list[InlayHint] {
    return [hint_of_record(row) for row in self.ask("assignment_hints", path)];
}

impl SessionClient.tokens(path: str, text: str) -> TokenStream {
    return token_stream_of_record(self.ask("tokens", path, text));
}

impl SessionClient.code_lookup(name: str) -> list[SymbolInfo] {
    return [symbol_info_of_record(row) for row in self.ask("code_lookup", name)];
}

impl SessionClient.code_references(name: str) -> list[SourceRef] {
    return [source_ref_of_record(row) for row in self.ask("code_references", name)];
}

impl SessionClient.code_archetypes(kind: str) -> list[SymbolInfo] {
    return [symbol_info_of_record(row) for row in self.ask("code_archetypes", kind)];
}

impl SessionClient.code_walkers(node_type: str) -> list[EntryPoint] {
    return [entry_point_of_record(row) for row in self.ask("code_walkers", node_type)];
}

impl SessionClient.code_slice(name: str, depth: int) -> ContextSlice {
    return context_slice_of_record(self.ask("code_slice", name, depth));
}

impl SessionClient.code_diagnostics(file: str) -> list[CodeDiagnostic] {
    return [
        code_diagnostic_of_record(row)
        for row in self.ask("code_diagnostics", file)
    ];
}

impl SessionClient.code_refresh(file: str) {
    self.ask("code_refresh", file);
}

impl native_build_request_record(request: NativeBuildRequest) -> dict[str, any] {
    return {
        "roots": list(request.roots),
        "kind": request.kind,
        "output": request.output,
        "project_root": request.project_root,
        "search_paths": list(request.search_paths),
        "package_root": request.package_root,
        "options": options_record(request.options),
        "link_mode": request.link_mode,
        "native_unit": request.native_unit,
        "library_api": request.library_api,
        "callbacks": request.callbacks,
        "emit_c": request.emit_c,
        "refuse_python_imports": request.refuse_python_imports,
        "refuse_demoted": request.refuse_demoted,
        "require_entry": request.require_entry,
        "kernel_entries": request.kernel_entries,
        "assert_no_rc": request.assert_no_rc
    };
}

impl native_build_result_of(raw: dict[str, any]) -> NativeBuildResult {
    return NativeBuildResult(
        errors=[diagnostic_of_record(diag) for diag in raw["errors"]],
        warnings=[diagnostic_of_record(diag) for diag in raw["warnings"]],
        linked=raw["linked"],
        reused=raw["reused"],
        output=raw["output"],
        mode=raw["mode"],
        triple=raw["triple"],
        units=[
            LinkedUnit(path=row["path"], digest=row["digest"], stamp=row["stamp"])
            for row in raw["units"]
        ],
        recompiled=raw["recompiled"],
        analysed=raw["analysed"],
        lowered=raw["lowered"],
        generated=raw["generated"],
        sha256=raw["sha256"],
        plan_digest=raw["plan_digest"],
        layout_digest=raw["layout_digest"],
        root_native=raw["root_native"],
        has_entry=raw["has_entry"],
        python_imports=list(raw["python_imports"]),
        demoted=list(raw["demoted"]),
        rc_symbols=list(raw["rc_symbols"]),
        rc_probes=list(raw["rc_probes"]),
        libraries=list(raw["libraries"]),
        callbacks=[
            CallbackBinding(
                name=row["name"],
                symbol=row["symbol"],
                ret_type=row["ret_type"],
                param_types=list(row["param_types"])
            )
            for row in raw["callbacks"]
        ],
        log=list(raw["log"])
    );
}

impl call_native_build(request: NativeBuildRequest) -> NativeBuildResult {
    kernel = load_kernel();
    try {
        raw = kernel.native_build(native_build_request_record(request));
    } except kernel.KernelError as error {
        raise KernelError(str(error)) from error;
    }
    return native_build_result_of(raw);
}

impl element_space_of_record(raw: dict[str, any]) -> ElementSpace {
    return ElementSpace(
        name=raw["name"], space=raw["space"], line=raw["line"], dual=raw["dual"]
    );
}

impl import_space_of_record(raw: dict[str, any]) -> ImportSpace {
    return ImportSpace(
        target=raw["target"], line=raw["line"], client_only=raw["client_only"]
    );
}

impl marker_scan_of_record(raw: dict[str, any]) -> MarkerScan {
    return MarkerScan(
        text=raw["text"],
        changed=raw["changed"],
        claims=[element_space_of_record(row) for row in raw["claims"]],
        sv_imports=[import_space_of_record(row) for row in raw["sv_imports"]],
        note=raw["note"]
    );
}

impl access_plan_of_record(raw: dict[str, any]) -> AccessPlan {
    return AccessPlan(
        rewrites=[
            AccessRewrite(
                path=row["path"],
                line=row["line"],
                kind=row["kind"],
                name=row["name"],
                reason=row["reason"]
            )
            for row in raw["rewrites"]
        ],
        notes=list(raw["notes"])
    );
}

impl SessionClient.strip_markers(path: str, text: str) -> MarkerScan {
    return marker_scan_of_record(self.ask("strip_markers", path, text));
}

impl SessionClient.element_spaces(path: str) -> list[ElementSpace] {
    return [element_space_of_record(row) for row in self.ask("element_spaces", path)];
}

impl SessionClient.client_imports(path: str) -> list[ImportSpace] {
    return [import_space_of_record(row) for row in self.ask("client_imports", path)];
}

impl SessionClient.access_plan(project_root: str) -> AccessPlan {
    return access_plan_of_record(self.ask("access_plan", project_root));
}

impl SessionClient.package_api(base_root: str, exports: list[str]) -> str {
    return self.ask("package_api", base_root, list(exports));
}

impl SessionClient.shipped_wiring(arch_path: str, dropped: list[str]) -> str {
    return self.ask("shipped_wiring", arch_path, list(dropped));
}

impl SessionClient.stub_catalog(
    out_path: str, only: list[str], pkg_dir: str
) -> StubCatalogReport {
    raw = self.ask("stub_catalog", out_path, list(only), pkg_dir);
    return StubCatalogReport(
        summary=raw["summary"], load_failures=list(raw["load_failures"])
    );
}

impl SessionClient.npm_sources(project_root: str) -> list[NpmSource] {
    return [
        NpmSource(
            npm_path=row["npm_path"],
            source_path=row["source_path"],
            js=row["js"],
            dts=row["dts"],
            external_imports=list(row["external_imports"])
        )
        for row in self.ask("npm_sources", project_root)
    ];
}

impl SessionClient.definition_rows(path: str) -> list[str] {
    return list(self.ask("definition_rows", path));
}
