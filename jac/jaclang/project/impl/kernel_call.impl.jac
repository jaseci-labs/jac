impl world_paths -> tuple[list[str], str] {
    return ([path for path in sys.path if path and os.path.isabs(path)], package_root());
}

impl call_compile(request: CompileRequest) -> CompileResult {
    kernel = load_kernel();
    if kernel is None {
        return compile_request(request);
    }
    try {
        raw = kernel.compile(request.to_dict());
    } except RuntimeError as refused {
        raise KernelError(str(refused)) from refused;
    }
    return CompileResult.from_dict(raw);
}

impl call_check(request: CheckRequest) -> CheckResult {
    kernel = load_kernel();
    if kernel is None {
        return check_request(request);
    }
    try {
        raw = kernel.check(request.to_dict());
    } except RuntimeError as refused {
        raise KernelError(str(refused)) from refused;
    }
    return CheckResult.from_dict(raw);
}

impl call_native_build(request: NativeBuildRequest) -> NativeBuildResult {
    kernel = load_kernel();
    if kernel is None {
        return native_build_request(request);
    }
    try {
        raw = kernel.native_build(request.to_dict());
    } except RuntimeError as refused {
        raise KernelError(str(refused)) from refused;
    }
    return NativeBuildResult.from_dict(raw);
}

impl SessionClient.postinit {
    (search_paths, package) = world_paths();
    kernel = load_kernel();
    if kernel is None {
        self._local = open_session(self.project_root, search_paths, package);
        return;
    }
    try {
        self._handle = int(kernel.open_session(self.project_root, search_paths, package));
    } except RuntimeError as refused {
        raise KernelError(str(refused)) from refused;
    }
}

impl SessionClient.ask(method: str, args: list[any]) -> any {
    with self._lock {
        local = self._local;
        if local is not None {
            return session_query(local, method, args);
        }
        kernel = load_kernel();
        if kernel is None or not self._handle {
            raise KernelError("the kernel session is closed");
        }
        try {
            return kernel.session_query(self._handle, method, args);
        } except RuntimeError as refused {
            raise KernelError(str(refused)) from refused;
        }
    }
}

impl SessionClient.release {
    with self._lock {
        self._local = None;
        if self._handle {
            kernel = load_kernel();
            if kernel is not None {
                kernel.close_session(self._handle);
            }
            self._handle = 0;
        }
    }
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
        lambda -> ToolOutput { return self.lint_fix(path) if auto_lint else self.format(path); }
    );
}

impl SessionClient.update(path: str, text: str) {
    self.ask("update", [path, text]);
}

impl SessionClient.close(path: str) {
    self.ask("close", [path]);
}

impl SessionClient.forget(path: str) {
    self.ask("forget", [path]);
}

impl SessionClient.rename_module(old_path: str, new_path: str) {
    self.ask("rename_module", [old_path, new_path]);
}

impl SessionClient.dependents(path: str) -> list[str] {
    return [str(item) for item in self.ask("dependents", [path])];
}

impl SessionClient.set_shared_app_limit(limit: int) {
    self.ask("set_shared_app_limit", [limit]);
}

impl SessionClient.diagnostics(path: str) -> list[KernelDiagnostic] {
    return [KernelDiagnostic.from_dict(item) for item in self.ask("diagnostics", [path])];
}

impl SessionClient.hover(path: str, line: int, col: int) -> str {
    return str(self.ask("hover", [path, line, col]));
}

impl SessionClient.definition(path: str, line: int, col: int) -> list[SourceSpan] {
    return [SourceSpan.from_dict(item) for item in self.ask("definition", [path, line, col])];
}

impl SessionClient.references(path: str, line: int, col: int) -> list[SourceSpan] {
    return [SourceSpan.from_dict(item) for item in self.ask("references", [path, line, col])];
}

impl SessionClient.completion(path: str, line: int, col: int) -> list[CompletionItem] {
    return [CompletionItem.from_dict(item) for item in self.ask("completion", [path, line, col])];
}

impl SessionClient.semantic_tokens(path: str) -> list[int] {
    return [int(item) for item in self.ask("semantic_tokens", [path])];
}

impl SessionClient.inlay_hints(path: str, first_line: int, last_line: int) -> list[InlayHint] {
    return [InlayHint.from_dict(item) for item in self.ask("inlay_hints", [path, first_line, last_line])];
}

impl SessionClient.symbols(path: str) -> list[DocumentSymbol] {
    return [DocumentSymbol.from_dict(item) for item in self.ask("symbols", [path])];
}

impl SessionClient.rename(path: str, line: int, col: int, new_name: str) -> list[TextEdit] {
    return [TextEdit.from_dict(item) for item in self.ask("rename", [path, line, col, new_name])];
}

impl SessionClient.format(path: str) -> ToolOutput {
    return ToolOutput.from_dict(self.ask("format", [path]));
}

impl SessionClient.lint_fix(path: str) -> ToolOutput {
    return ToolOutput.from_dict(self.ask("lint_fix", [path]));
}

impl SessionClient.lint(path: str) -> ToolOutput {
    return ToolOutput.from_dict(self.ask("lint", [path]));
}

impl SessionClient.parse(path: str) -> ToolOutput {
    return ToolOutput.from_dict(self.ask("parse", [path]));
}

impl SessionClient.statements(path: str) -> list[SourceSpan] {
    return [SourceSpan.from_dict(item) for item in self.ask("statements", [path])];
}

impl SessionClient.py_to_jac(path: str) -> ToolOutput {
    return ToolOutput.from_dict(self.ask("py_to_jac", [path]));
}

impl SessionClient.ast_view(path: str, view: str) -> ToolOutput {
    return ToolOutput.from_dict(self.ask("ast_view", [path, view]));
}

impl SessionClient.explain(path: str, topic: str, memory_profile: str = "") -> ToolOutput {
    return ToolOutput.from_dict(self.ask("explain", [path, topic, memory_profile]));
}

impl SessionClient.grammar -> GrammarReport {
    return GrammarReport.from_dict(self.ask("grammar", []));
}

impl SessionClient.arch_plan(arch_path: str, action: str, prune: bool = False, graph_format: str = "") -> ArchPlan {
    return ArchPlan.from_dict(self.ask("arch_plan", [arch_path, action, prune, graph_format]));
}

impl SessionClient.strip_markers(path: str, text: str) -> MarkerScan {
    return MarkerScan.from_dict(self.ask("strip_markers", [path, text]));
}

impl SessionClient.element_spaces(path: str) -> list[ElementSpace] {
    return [ElementSpace.from_dict(item) for item in self.ask("element_spaces", [path])];
}

impl SessionClient.client_imports(path: str) -> list[ImportSpace] {
    return [ImportSpace.from_dict(item) for item in self.ask("client_imports", [path])];
}

impl SessionClient.access_plan(project_root: str) -> AccessPlan {
    return AccessPlan.from_dict(self.ask("access_plan", [project_root]));
}

impl SessionClient.package_api(base_root: str, exports: list[str]) -> str {
    return str(self.ask("package_api", [base_root, exports]));
}

impl SessionClient.stub_catalog(out_path: str, only: list[str], pkg_dir: str) -> StubCatalogReport {
    return StubCatalogReport.from_dict(self.ask("stub_catalog", [out_path, only, pkg_dir]));
}

impl SessionClient.npm_sources(project_root: str) -> list[NpmSource] {
    return [NpmSource.from_dict(item) for item in self.ask("npm_sources", [project_root])];
}

impl SessionClient.definition_rows(path: str) -> list[str] {
    return [str(item) for item in self.ask("definition_rows", [path])];
}

impl SessionClient.compile(request: CompileRequest) -> CompileResult {
    return CompileResult.from_dict(self.ask("compile", [request.to_dict()]));
}

impl SessionClient.check(request: CheckRequest) -> CheckResult {
    return CheckResult.from_dict(self.ask("check", [request.to_dict()]));
}

impl SessionClient.module_outline(path: str) -> ModuleOutline {
    return ModuleOutline.from_dict(self.ask("module_outline", [path]));
}

impl SessionClient.edit_symbols(path: str, text: str) -> list[EditSymbol] {
    return [EditSymbol.from_dict(item) for item in self.ask("edit_symbols", [path, text])];
}

impl SessionClient.import_texts(path: str, text: str) -> list[str] {
    return [str(item) for item in self.ask("import_texts", [path, text])];
}

impl SessionClient.wiring_changes(path: str, old_text: str, new_text: str) -> list[WiringChange] {
    return [WiringChange.from_dict(item) for item in self.ask("wiring_changes", [path, old_text, new_text])];
}

impl SessionClient.wired_dependents(head: str, names: list[str]) -> WiredFiles {
    return WiredFiles.from_dict(self.ask("wired_dependents", [head, names]));
}

impl SessionClient.wiring_module_files(arch_path: str, consumers: list[str]) -> list[str] {
    return [str(item) for item in self.ask("wiring_module_files", [arch_path, consumers])];
}

impl SessionClient.wiring_model(arch_path: str) -> WiringModel {
    return WiringModel.from_dict(self.ask("wiring_model", [arch_path]));
}

impl SessionClient.token_symbols(path: str) -> list[TokenSymbol] {
    return [TokenSymbol.from_dict(item) for item in self.ask("token_symbols", [path])];
}

impl SessionClient.assignment_hints(path: str) -> list[InlayHint] {
    return [InlayHint.from_dict(item) for item in self.ask("assignment_hints", [path])];
}

impl SessionClient.tokens(path: str, text: str) -> TokenStream {
    return TokenStream.from_dict(self.ask("tokens", [path, text]));
}

impl SessionClient.code_lookup(name: str) -> list[SymbolInfo] {
    return [SymbolInfo.from_dict(item) for item in self.ask("code_lookup", [name])];
}

impl SessionClient.code_references(name: str) -> list[SourceRef] {
    return [SourceRef.from_dict(item) for item in self.ask("code_references", [name])];
}

impl SessionClient.code_archetypes(kind: str) -> list[SymbolInfo] {
    return [SymbolInfo.from_dict(item) for item in self.ask("code_archetypes", [kind])];
}

impl SessionClient.code_walkers(node_type: str) -> list[EntryPoint] {
    return [EntryPoint.from_dict(item) for item in self.ask("code_walkers", [node_type])];
}

impl SessionClient.code_slice(name: str, depth: int) -> ContextSlice {
    return ContextSlice.from_dict(self.ask("code_slice", [name, depth]));
}

impl SessionClient.code_diagnostics(file: str) -> list[CodeDiagnostic] {
    return [CodeDiagnostic.from_dict(item) for item in self.ask("code_diagnostics", [file])];
}

impl SessionClient.code_refresh(file: str) {
    self.ask("code_refresh", [file]);
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
