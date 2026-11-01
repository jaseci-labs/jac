"""The kernel as a JacPython extension module, `jac_kernel`.

`PyInit_jac_kernel` is the module's init function: `jac native build kernel`
links it into the development extension module, and a release links it into
the interpreter's table of built-in modules. The module has three functions,
`compile(request)`, `check(request)` and
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
             "completion(path, line, col, trigger='')\n--\n\nCompletions at a position.",
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
             "format(path)\n--\n\nThe file's formatted text.",
             METH_O
         ),
         MethodDefinition(
             "lint_fix",
             MethodCallbacks(positional=session_lint_fix),
             "lint_fix(path)\n--\n\nThe file's text with its lint fixes applied.",
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
