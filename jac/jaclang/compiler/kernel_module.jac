"""The kernel as a JacPython extension module, `jac_kernel`.

`PyInit_jac_kernel` is the module's init function: `jac native build kernel`
links it into the development extension module, and a release links it into
the interpreter's table of built-in modules. The module has four functions,
`compile(request)`, `check(request)`, `native_build(request)` and
`open_session(project_root, search_paths, package_root)`, the
`Session` type whose methods are `KernelSession`'s, and the `KernelError`
exception.

Requests and results are plain Python data named after the records in
`kernel_api.jac`: a request is a dict of its record's fields (an absent field
keeps its default, an unknown one is a TypeError), and every result record is
a dict of all of its fields. Lists, strings, ints, bools and bytes cross as
themselves; a unit's `sections` is a dict from section tag to bytes and its
`code` is its code object, or None. A
`KernelError` raised in the kernel raises `jac_kernel.KernelError`; any other
failure escaping the kernel is a SystemError naming an internal compiler
error. Nothing calls back into the host."""
glob MODULE_DOC: str = "The Jac compiler kernel.",
     SESSION_DOC: str = "An analysed project held across edits; every query is a method.",
     METH_O: int = 8,
     METH_FASTCALL: int = 128;

obj KernelHandles {
    has error: ptr[PyObject] = NULL,
        session: ptr[PyObject] = NULL;
}

glob:priv handles: KernelHandles = KernelHandles();

obj SessionState(NativeState) {
    has session: KernelSession;

    def traverse_refs(visitor: ptr, context: ptr) -> i32;
    def clear;
}

obj DictEntry {
    has name: str,
        value: ptr[PyObject];
}

def:priv failure(kind: ptr[PyObject], message: str) -> boundary_failure;

def:priv kernel_failure(error: KernelError) -> ptr[PyObject];

def:priv internal_failure(error: Exception) -> ptr[PyObject];

def:priv entries_of(value: ptr[PyObject], what: str) -> list[DictEntry];

def:priv text_of(value: ptr[PyObject], what: str) -> str;

def:priv optional_text_of(value: ptr[PyObject], what: str) -> (str | None);

def:priv int_of(value: ptr[PyObject], what: str) -> int;

def:priv optional_int_of(value: ptr[PyObject], what: str) -> (int | None);

def:priv flag_of(value: ptr[PyObject], what: str) -> bool;

def:priv optional_flag_of(value: ptr[PyObject], what: str) -> (bool | None);

def:priv texts_of(value: ptr[PyObject], what: str) -> list[str];

def:priv optional_texts_of(value: ptr[PyObject], what: str) -> (list[str] | None);

def:priv text_map_of(value: ptr[PyObject], what: str) -> dict[str, str];

def:priv options_of(value: ptr[PyObject]) -> CompileOptions;

def:priv compile_request_of(value: ptr[PyObject]) -> CompileRequest;

def:priv check_request_of(value: ptr[PyObject]) -> CheckRequest;

def:priv put(record: ptr[PyObject], key: str, value: ptr[PyObject]);

def:priv append(items: ptr[PyObject], value: ptr[PyObject]);

def:priv new_record -> ptr[PyObject];

def:priv new_list -> ptr[PyObject];

def:priv int_object(value: int) -> ptr[PyObject];

def:priv flag_object(value: bool) -> ptr[PyObject];

def:priv none_object -> ptr[PyObject];

def:priv texts_object(values: list[str]) -> ptr[PyObject];

def:priv ints_object(values: list[int]) -> ptr[PyObject];

def:priv span_object(span: SourceSpan) -> ptr[PyObject];

def:priv spans_object(spans: list[SourceSpan]) -> ptr[PyObject];

def:priv diagnostic_object(diagnostic: KernelDiagnostic) -> ptr[PyObject];

def:priv diagnostics_object(diagnostics: list[KernelDiagnostic]) -> ptr[PyObject];

def:priv demotions_object(demotions: list[NativeDemotion]) -> ptr[PyObject];

def:priv code_object(unit: CompiledUnit) -> ptr[PyObject];

def:priv sections_object(sections: dict[int, bytes]) -> ptr[PyObject];

def:priv unit_object(unit: CompiledUnit) -> ptr[PyObject];

def:priv compile_result_object(result: CompileResult) -> ptr[PyObject];

def:priv check_result_object(result: CheckResult) -> ptr[PyObject];

def:priv completions_object(items: list[CompletionItem]) -> ptr[PyObject];

def:priv hints_object(hints: list[InlayHint]) -> ptr[PyObject];

def:priv symbol_object(symbol: DocumentSymbol) -> ptr[PyObject];

def:priv symbols_object(symbols: list[DocumentSymbol]) -> ptr[PyObject];

def:priv edits_object(edits: list[TextEdit]) -> ptr[PyObject];

def:priv python_ast_object(unit: CompiledUnit) -> ptr[PyObject];

def:priv output_object(output: ToolOutput) -> ptr[PyObject];

def:priv grammar_object(report: GrammarReport) -> ptr[PyObject];

def:priv arch_plan_object(plan: ArchPlan) -> ptr[PyObject];

def:priv compile_call(module: ptr[PyObject], request: ptr[PyObject]) -> ptr[PyObject];

def:priv check_call(module: ptr[PyObject], request: ptr[PyObject]) -> ptr[PyObject];

def:priv open_session_call(
    module: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv session_of(instance: ptr[PyObject]) -> KernelSession;

def:priv arguments(
    stack: ptr[ptr[PyObject]], count: i64, method: str, least: int, most: int
) -> list[ptr[PyObject]];

def:priv session_update(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv session_close(instance: ptr[PyObject], path: ptr[PyObject]) -> ptr[PyObject];

def:priv session_forget(instance: ptr[PyObject], path: ptr[PyObject]) -> ptr[PyObject];

def:priv session_rename_module(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv session_diagnostics(
    instance: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject];

def:priv session_hover(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv session_definition(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv session_references(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv session_completion(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv session_semantic_tokens(
    instance: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject];

def:priv session_inlay_hints(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv session_symbols(instance: ptr[PyObject], path: ptr[PyObject]) -> ptr[PyObject];

def:priv session_rename(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv session_format(instance: ptr[PyObject], path: ptr[PyObject]) -> ptr[PyObject];

def:priv session_lint_fix(
    instance: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject];

def:priv session_compile(
    instance: ptr[PyObject], request: ptr[PyObject]
) -> ptr[PyObject];

def:priv session_check(instance: ptr[PyObject], request: ptr[PyObject]) -> ptr[PyObject];

def:priv native_build_request_of(value: ptr[PyObject]) -> NativeBuildRequest;

def:priv native_build_result_object(result: NativeBuildResult) -> ptr[PyObject];

def:priv native_build_call(
    module: ptr[PyObject], request: ptr[PyObject]
) -> ptr[PyObject];

def:priv element_space_object(space: ElementSpace) -> ptr[PyObject];

def:priv element_spaces_object(spaces: list[ElementSpace]) -> ptr[PyObject];

def:priv import_spaces_object(spaces: list[ImportSpace]) -> ptr[PyObject];

def:priv marker_scan_object(scan: MarkerScan) -> ptr[PyObject];

def:priv access_plan_object(plan: AccessPlan) -> ptr[PyObject];

def:priv session_strip_markers(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv session_element_spaces(
    instance: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject];

def:priv session_client_imports(
    instance: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject];

def:priv session_access_plan(
    instance: ptr[PyObject], project_root: ptr[PyObject]
) -> ptr[PyObject];

def:priv session_package_api(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv session_stub_catalog(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv session_npm_sources(
    instance: ptr[PyObject], project_root: ptr[PyObject]
) -> ptr[PyObject];

def:priv session_definition_rows(
    instance: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject];

def:priv outline_object(outline: ModuleOutline) -> ptr[PyObject];

def:priv edit_symbols_object(rows: list[EditSymbol]) -> ptr[PyObject];

def:priv wiring_changes_object(rows: list[WiringChange]) -> ptr[PyObject];

def:priv wired_files_object(found: WiredFiles) -> ptr[PyObject];

def:priv wiring_model_object(model: WiringModel) -> ptr[PyObject];

def:priv token_symbols_object(rows: list[TokenSymbol]) -> ptr[PyObject];

def:priv token_stream_object(stream: TokenStream) -> ptr[PyObject];

def:priv symbol_info_object(info: SymbolInfo) -> ptr[PyObject];

def:priv symbol_infos_object(infos: list[SymbolInfo]) -> ptr[PyObject];

def:priv source_refs_object(refs: list[SourceRef]) -> ptr[PyObject];

def:priv entry_points_object(points: list[EntryPoint]) -> ptr[PyObject];

def:priv context_slice_object(found: ContextSlice) -> ptr[PyObject];

def:priv code_diagnostics_object(diags: list[CodeDiagnostic]) -> ptr[PyObject];

def:priv session_module_outline(
    instance: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject];

def:priv session_edit_symbols(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv session_import_texts(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv session_wiring_changes(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv session_wired_dependents(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv session_wiring_module_files(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv session_wiring_model(
    instance: ptr[PyObject], arch_path: ptr[PyObject]
) -> ptr[PyObject];

def:priv session_token_symbols(
    instance: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject];

def:priv session_assignment_hints(
    instance: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject];

def:priv session_tokens(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv session_code_lookup(
    instance: ptr[PyObject], name: ptr[PyObject]
) -> ptr[PyObject];

def:priv session_code_references(
    instance: ptr[PyObject], name: ptr[PyObject]
) -> ptr[PyObject];

def:priv session_code_archetypes(
    instance: ptr[PyObject], kind: ptr[PyObject]
) -> ptr[PyObject];

def:priv session_code_walkers(
    instance: ptr[PyObject], node_type: ptr[PyObject]
) -> ptr[PyObject];

def:priv session_code_slice(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv session_code_diagnostics(
    instance: ptr[PyObject], file: ptr[PyObject]
) -> ptr[PyObject];

def:priv session_code_refresh(
    instance: ptr[PyObject], file: ptr[PyObject]
) -> ptr[PyObject];

def:priv session_dependents(instance: ptr[PyObject], path: ptr[PyObject]) -> ptr[PyObject];

def:priv session_set_shared_app_limit(
    instance: ptr[PyObject], limit: ptr[PyObject]
) -> ptr[PyObject];

def:priv session_lint(instance: ptr[PyObject], path: ptr[PyObject]) -> ptr[PyObject];

def:priv session_parse(instance: ptr[PyObject], path: ptr[PyObject]) -> ptr[PyObject];

def:priv session_statements(
    instance: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject];

def:priv session_py_to_jac(
    instance: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject];

def:priv session_ast_view(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv session_explain(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv session_grammar(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv session_arch_plan(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv session_project_root(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def:priv session_dealloc(instance: ptr[PyObject]);

def:priv session_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32;

def:priv session_clear(instance: ptr[PyObject]) -> i32;

glob:priv session_methods: list[MethodDefinition] = [
         MethodDefinition(
             "update",
             MethodCallbacks(fast=session_update),
             "update(path, text)\n--\n\nReplace a file's text and re-analyse what it reaches.",
             METH_FASTCALL
         ),
         MethodDefinition(
             "close",
             MethodCallbacks(positional=session_close),
             "close(path)\n--\n\nDrop an editor's text for a file; the file system holds it again.",
             METH_O
         ),
         MethodDefinition(
             "forget",
             MethodCallbacks(positional=session_forget),
             "forget(path)\n--\n\nForget a deleted file.",
             METH_O
         ),
         MethodDefinition(
             "rename_module",
             MethodCallbacks(fast=session_rename_module),
             "rename_module(old_path, new_path)\n--\n\nMove a module's analysis to its new path.",
             METH_FASTCALL
         ),
         MethodDefinition(
             "diagnostics",
             MethodCallbacks(positional=session_diagnostics),
             "diagnostics(path)\n--\n\nThe file's diagnostics, as KernelDiagnostic dicts.",
             METH_O
         ),
         MethodDefinition(
             "hover",
             MethodCallbacks(fast=session_hover),
             "hover(path, line, col)\n--\n\nThe hover text at a position.",
             METH_FASTCALL
         ),
         MethodDefinition(
             "definition",
             MethodCallbacks(fast=session_definition),
             "definition(path, line, col)\n--\n\nWhere the name at a position is defined.",
             METH_FASTCALL
         ),
         MethodDefinition(
             "references",
             MethodCallbacks(fast=session_references),
             "references(path, line, col)\n--\n\nEvery use of the name at a position.",
             METH_FASTCALL
         ),
         MethodDefinition(
             "completion",
             MethodCallbacks(fast=session_completion),
             "completion(path, line, col)\n--\n\nCompletions at a position.",
             METH_FASTCALL
         ),
         MethodDefinition(
             "semantic_tokens",
             MethodCallbacks(positional=session_semantic_tokens),
             "semantic_tokens(path)\n--\n\nThe file's semantic tokens, LSP-encoded.",
             METH_O
         ),
         MethodDefinition(
             "inlay_hints",
             MethodCallbacks(fast=session_inlay_hints),
             "inlay_hints(path, first_line, last_line)\n--\n\nInlay hints over a line range.",
             METH_FASTCALL
         ),
         MethodDefinition(
             "symbols",
             MethodCallbacks(positional=session_symbols),
             "symbols(path)\n--\n\nThe file's document symbols.",
             METH_O
         ),
         MethodDefinition(
             "rename",
             MethodCallbacks(fast=session_rename),
             "rename(path, line, col, new_name)\n--\n\nThe edits that rename the name at a position.",
             METH_FASTCALL
         ),
         MethodDefinition(
             "format",
             MethodCallbacks(positional=session_format),
             "format(path)\n--\n\nThe file's formatted text, as a ToolOutput dict.",
             METH_O
         ),
         MethodDefinition(
             "lint_fix",
             MethodCallbacks(positional=session_lint_fix),
             "lint_fix(path)\n--\n\nThe file's text with its lint fixes applied, as a ToolOutput dict.",
             METH_O
         ),
         MethodDefinition(
             "compile",
             MethodCallbacks(positional=session_compile),
             "compile(request)\n--\n\nCompile within the session's analysis.",
             METH_O
         ),
         MethodDefinition(
             "check",
             MethodCallbacks(positional=session_check),
             "check(request)\n--\n\nCheck within the session's analysis.",
             METH_O
         ),
         MethodDefinition(
             "strip_markers",
             MethodCallbacks(fast=session_strip_markers),
             "strip_markers(path, text)\n--\n\nA source text with its retired placement markers stripped.",
             METH_FASTCALL
         ),
         MethodDefinition(
             "element_spaces",
             MethodCallbacks(positional=session_element_spaces),
             "element_spaces(path)\n--\n\nThe codespace of each top-level element of a file.",
             METH_O
         ),
         MethodDefinition(
             "client_imports",
             MethodCallbacks(positional=session_client_imports),
             "client_imports(path)\n--\n\nWhether only client code reads each import of a file.",
             METH_O
         ),
         MethodDefinition(
             "access_plan",
             MethodCallbacks(positional=session_access_plan),
             "access_plan(project_root)\n--\n\nThe served declarations that must declare :protect.",
             METH_O
         ),
         MethodDefinition(
             "package_api",
             MethodCallbacks(fast=session_package_api),
             "package_api(base_root, exports)\n--\n\nA package's API surface, as its canonical JSON text.",
             METH_FASTCALL
         ),
         MethodDefinition(
             "stub_catalog",
             MethodCallbacks(fast=session_stub_catalog),
             "stub_catalog(out_path, only, pkg_dir)\n--\n\nBuild the type stub catalog into out_path.",
             METH_FASTCALL
         ),
         MethodDefinition(
             "npm_sources",
             MethodCallbacks(positional=session_npm_sources),
             "npm_sources(project_root)\n--\n\nThe client modules a project publishes to npm.",
             METH_O
         ),
         MethodDefinition(
             "definition_rows",
             MethodCallbacks(positional=session_definition_rows),
             "definition_rows(path)\n--\n\nThe definition span rows of a file, parsed.",
             METH_O
         ),
         MethodDefinition(
             "module_outline",
             MethodCallbacks(positional=session_module_outline),
             "module_outline(path)\n--\n\nA module's declarations, woven with its annexes.",
             METH_O
         ),
         MethodDefinition(
             "edit_symbols",
             MethodCallbacks(fast=session_edit_symbols),
             "edit_symbols(path, text)\n--\n\nThe top-level declarations of a source text.",
             METH_FASTCALL
         ),
         MethodDefinition(
             "import_texts",
             MethodCallbacks(fast=session_import_texts),
             "import_texts(path, text)\n--\n\nThe import statements of a source text.",
             METH_FASTCALL
         ),
         MethodDefinition(
             "wiring_changes",
             MethodCallbacks(fast=session_wiring_changes),
             "wiring_changes(path, old_text, new_text)\n--\n\nThe wires and rules an archwire edit adds, removes or changes.",
             METH_FASTCALL
         ),
         MethodDefinition(
             "wired_dependents",
             MethodCallbacks(fast=session_wired_dependents),
             "wired_dependents(head, names)\n--\n\nThe module files a module's wires carrying any of the names feed.",
             METH_FASTCALL
         ),
         MethodDefinition(
             "wiring_module_files",
             MethodCallbacks(fast=session_wiring_module_files),
             "wiring_module_files(arch_path, consumers)\n--\n\nThe files of an archwire's consumer modules.",
             METH_FASTCALL
         ),
         MethodDefinition(
             "wiring_model",
             MethodCallbacks(positional=session_wiring_model),
             "wiring_model(arch_path)\n--\n\nAn archwire.jac as modules, wires and rules.",
             METH_O
         ),
         MethodDefinition(
             "token_symbols",
             MethodCallbacks(positional=session_token_symbols),
             "token_symbols(path)\n--\n\nThe symbol each name token of a file resolves to.",
             METH_O
         ),
         MethodDefinition(
             "assignment_hints",
             MethodCallbacks(positional=session_assignment_hints),
             "assignment_hints(path)\n--\n\nInferred-type hints for untyped single-name assignments.",
             METH_O
         ),
         MethodDefinition(
             "tokens",
             MethodCallbacks(fast=session_tokens),
             "tokens(path, text)\n--\n\nA text's lexical tokens and comments.",
             METH_FASTCALL
         ),
         MethodDefinition(
             "code_lookup",
             MethodCallbacks(positional=session_code_lookup),
             "code_lookup(name)\n--\n\nThe project's definitions of a name.",
             METH_O
         ),
         MethodDefinition(
             "code_references",
             MethodCallbacks(positional=session_code_references),
             "code_references(name)\n--\n\nEvery definition and use of a name in the project.",
             METH_O
         ),
         MethodDefinition(
             "code_archetypes",
             MethodCallbacks(positional=session_code_archetypes),
             "code_archetypes(kind)\n--\n\nThe project's archetypes, optionally of one kind.",
             METH_O
         ),
         MethodDefinition(
             "code_walkers",
             MethodCallbacks(positional=session_code_walkers),
             "code_walkers(node_type)\n--\n\nThe walker entry points that traverse a node type.",
             METH_O
         ),
         MethodDefinition(
             "code_slice",
             MethodCallbacks(fast=session_code_slice),
             "code_slice(name, depth)\n--\n\nThe typed neighbourhood of a symbol.",
             METH_FASTCALL
         ),
         MethodDefinition(
             "code_diagnostics",
             MethodCallbacks(positional=session_code_diagnostics),
             "code_diagnostics(file)\n--\n\nThe code index's diagnostics, for one file or all.",
             METH_O
         ),
         MethodDefinition(
             "code_refresh",
             MethodCallbacks(positional=session_code_refresh),
             "code_refresh(file)\n--\n\nRe-index a changed file, or the whole project.",
             METH_O
         ),
         MethodDefinition(
             "dependents",
             MethodCallbacks(positional=session_dependents),
             "dependents(path)\n--\n\nEvery module that depends on a file, transitively.",
             METH_O
         ),
         MethodDefinition(
             "set_shared_app_limit",
             MethodCallbacks(positional=session_set_shared_app_limit),
             "set_shared_app_limit(limit)\n--\n\nHow many apps a shared module is checked against.",
             METH_O
         ),
         MethodDefinition(
             "lint",
             MethodCallbacks(positional=session_lint),
             "lint(path)\n--\n\nThe file's lint diagnostics, as a ToolOutput dict.",
             METH_O
         ),
         MethodDefinition(
             "parse",
             MethodCallbacks(positional=session_parse),
             "parse(path)\n--\n\nThe file's syntax diagnostics, as a ToolOutput dict.",
             METH_O
         ),
         MethodDefinition(
             "statements",
             MethodCallbacks(positional=session_statements),
             "statements(path)\n--\n\nThe spans of the file's own top-level statements.",
             METH_O
         ),
         MethodDefinition(
             "py_to_jac",
             MethodCallbacks(positional=session_py_to_jac),
             "py_to_jac(path)\n--\n\nA Python file as formatted Jac, as a ToolOutput dict.",
             METH_O
         ),
         MethodDefinition(
             "ast_view",
             MethodCallbacks(fast=session_ast_view),
             "ast_view(path, view)\n--\n\nOne of the AST tool's views of a file.",
             METH_FASTCALL
         ),
         MethodDefinition(
             "explain",
             MethodCallbacks(fast=session_explain),
             "explain(path, topic, memory_profile='')\n--\n\nThe memory or native report for a file.",
             METH_FASTCALL
         ),
         MethodDefinition(
             "grammar",
             MethodCallbacks(fast=session_grammar),
             "grammar()\n--\n\nThe Jac grammar as EBNF, as a GrammarReport dict.",
             METH_FASTCALL
         ),
         MethodDefinition(
             "arch_plan",
             MethodCallbacks(fast=session_arch_plan),
             "arch_plan(arch_path, action, prune=False, graph_format='')\n--\n\nWhat `jac arch` would write for an archwire.jac.",
             METH_FASTCALL
         )
     ],
     session_type: TypeDefinition = TypeDefinition(
         "jac_kernel.Session",
         SESSION_DOC,
         session_methods,
         u64(
             TypeFlags.GC.value
                 | TypeFlags.IMMUTABLE.value
                 | TypeFlags.DISALLOW_INSTANTIATION.value
         ),
         TypeHooks(
             dealloc=session_dealloc,
             traverse=session_traverse,
             clear=session_clear
         ),
         properties=[
             PropertyDefinition(
                 "project_root",
                 PropertyCallbacks(read=session_project_root),
                 0,
                 "The project root the session was opened on."
             )
         ]
     ),
     module_methods: list[MethodDefinition] = [
         MethodDefinition(
             "compile",
             MethodCallbacks(positional=compile_call),
             "compile(request)\n--\n\nCompile a CompileRequest dict; returns a CompileResult dict.",
             METH_O
         ),
         MethodDefinition(
             "check",
             MethodCallbacks(positional=check_call),
             "check(request)\n--\n\nCheck a CheckRequest dict; returns a CheckResult dict.",
             METH_O
         ),
         MethodDefinition(
             "native_build",
             MethodCallbacks(positional=native_build_call),
             "native_build(request)\n--\n\nBuild a NativeBuildRequest dict; returns a NativeBuildResult dict.",
             METH_O
         ),
         MethodDefinition(
             "open_session",
             MethodCallbacks(fast=open_session_call),
             "open_session(project_root, search_paths, package_root)\n--\n\nOpen an analysed project held across edits.",
             METH_FASTCALL
         )
     ];

def:priv execute(module: ptr[PyObject]) -> i32;

glob:priv definition: ModuleDefinition = ModuleDefinition(
         "jac_kernel", MODULE_DOC, module_methods, ModuleHooks(execute=execute), 2
     );

def:pub PyInit_jac_kernel -> ptr[PyObject];
