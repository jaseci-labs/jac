"""The kernel's interface: the only way anything outside the kernel reaches the
compiler.

The kernel is a JacPython native module (`jac_kernel`). Its binding
(`compiler/kernel_module.jac`) converts Python objects to these records and
back, and calls `compile_request`, `check_request` and `open_session`. Nothing
here calls back into the host: the kernel reads files, configuration and
caches itself, and every failure is a diagnostic or a raised `KernelError`,
never a quiet default.

Requests name files by absolute path. `sources` overlays unsaved editor text
on the file system for the paths it names. `search_paths` is the
interpreter's module search path and `package_root` the jaclang package the
kernel was built from; the kernel resolves imports over them and raises a
`KernelError` when either is missing. Lines and columns are 1-based."""
import os;
import copy;

class KernelError(Exception) {}

obj SourceSpan {
    has path: str,
        line: int = 0,
        col: int = 0,
        end_line: int = 0,
        end_col: int = 0;
}

obj RelatedNote {
    has label: str,
        span: SourceSpan;
}

obj KernelDiagnostic {
    has code: str,
        severity: str,
        message: str,
        span: SourceSpan,
        help: str = "",
        pass_name: str = "",
        related: list[RelatedNote] = [];
}

"""Why a function or field could not be native, decided before lowering."""
obj NativeDemotion {
    has symbol: str,
        kind: str,
        reason: str,
        code: str,
        span: SourceSpan;
}

"""What one module compiled to. `code` is the module's JacPython code object,
made by JacPython's compiler inside the kernel (`kernel_code_object`) as an owned
reference (NULL when no bytecode was asked for) that the module binding hands to
its caller, and
`bytecode` is that code object marshalled, as caches store it. `python_ast` is
the generated Python as an owned `ast.Module` reference, present when the
request names the "python_ast" product. The native products are present when the module is
native."""
obj CompiledUnit {
    has path: str,
        module_name: str,
        code: ptr[PyObject] = ptr[PyObject](),
        bytecode: bytes = b"",
        python_ast: ptr[PyObject] = ptr[PyObject](),
        interface: bytes = b"",
        placement: str = "",
        client_js: str = "",
        native_object: bytes = b"",
        native_iface: str = "",
        native_deps: list[str] = [],
        native_ir: str = "",
        native_layout: str = "",
        demoted: list[NativeDemotion] = [],
        jac_deps: list[str] = [],
        app: str = "",
        persistence: list[str] = [],
        import_edges: list[str] = [],
        interop: str = "",
        client_manifest: str = "",
        iface_shape: str = "",
        effects: str = "",
        sections: dict[int, bytes] = {};
}

obj CompileRequest {
    has paths: list[str],
        project_root: str = "",
        search_paths: list[str] = [],
        package_root: str = "",
        options: CompileOptions = CompileOptions(),
        sources: dict[str, str] = {},
        products: list[str] = ["bytecode"];
}

"""A source the kernel read while compiling, with the digest of the text it
read."""
obj SourceRead {
    has path: str,
        digest: str;
}

"""`reached` names every module the compile analysed, the entries included,
and `reads` the sources it read, so a caller can tell when its products go
stale."""
obj CompileResult {
    has units: list[CompiledUnit] = [],
        errors: list[KernelDiagnostic] = [],
        warnings: list[KernelDiagnostic] = [],
        reached: list[str] = [],
        reads: list[SourceRead] = [];

    def ok -> bool;
    def unit(path: str) -> CompiledUnit;
}

obj CoverageRow {
    has path: str,
        native: int,
        demoted: list[NativeDemotion] = [];
}

obj PlacementRow {
    has path: str,
        symbol: str,
        placement: str,
        reason: str = "";
}

obj CheckRequest {
    has paths: list[str],
        project_root: str = "",
        search_paths: list[str] = [],
        package_root: str = "",
        options: CompileOptions = CompileOptions(),
        sources: dict[str, str] = {},
        native_coverage: bool = False,
        placements: bool = False,
        closure: bool = False;
}

obj CheckResult {
    has errors: list[KernelDiagnostic] = [],
        warnings: list[KernelDiagnostic] = [],
        reached: list[str] = [],
        coverage: list[CoverageRow] = [],
        placements: list[PlacementRow] = [];

    def ok -> bool;
}

obj TextEdit {
    has span: SourceSpan,
        text: str;
}

obj CompletionItem {
    has label: str,
        kind: str,
        detail: str = "",
        insert_text: str = "";
}

obj InlayHint {
    has line: int,
        col: int,
        label: str,
        kind: str;
}

obj DocumentSymbol {
    has name: str,
        kind: str,
        span: SourceSpan,
        children: list[DocumentSymbol] = [];
}

"""What a text-producing tool made of one file: the text (empty when the file
did not parse) and the diagnostics the tool raised on the way."""
obj ToolOutput {
    has text: str = "",
        errors: list[KernelDiagnostic] = [],
        warnings: list[KernelDiagnostic] = [];
}

"""The Jac grammar as EBNF, extracted from the parser's own source."""
obj GrammarReport {
    has ebnf: str,
        rules: int,
        diagnostics: str = "",
        errors: list[KernelDiagnostic] = [];
}

"""What `jac arch` would write for one archwire.jac. `text` is the formatted
archwire (or the rendered graph for the "graph" action); `refusal` names why
nothing can be written, with `hint` saying what to do instead. `modules` are
the module files the wiring governs and `fed` the ones a pruned wire fed."""
obj ArchPlan {
    has arch_path: str,
        text: str = "",
        modules: list[str] = [],
        fed: list[str] = [],
        added: int = 0,
        dropped: int = 0,
        rules: int = 0,
        rules_added: int = 0,
        refusal: str = "",
        hint: str = "";
}

"""An analysed project held across edits. Every tooling feature is a query on
a session; an edit re-analyses incrementally inside the kernel. A query on an
annex answers from the module that owns it."""
obj KernelSession {
    has project_root: str,
        search_paths: list[str] = [],
        package_root: str = "",
        options: CompileOptions = CompileOptions(),
        _host: (ProjectHost | None) = None,
        _program: (JacProgram | None) = None,
        shared_app_limit: int = 4,
        _versions: dict[str, int] = {},
        _analysed: dict[str, int] = {},
        _diagnosed: dict[str, list[KernelDiagnostic]] = {},
        _open: set[str] = set();

    def postinit;
    def enter -> ProjectHost;
    def leave;
    def invalidate(real: str);
    def owner(real: str) -> str;
    def analysed(path: str) -> uni.Module;
    def app_targets(real: str) -> list[tuple[str, str, str]];
    def app_diagnostics(real: str) -> list[KernelDiagnostic];
    def formatted(path: str, auto_lint: bool) -> ToolOutput;
    def tool_program -> JacProgram;

    def update(path: str, text: str);
    def close(path: str);
    def forget(path: str);
    def rename_module(old_path: str, new_path: str);
    def dependents(path: str) -> list[str];
    def set_shared_app_limit(limit: int);
    def diagnostics(path: str) -> list[KernelDiagnostic];
    def hover(path: str, line: int, col: int) -> str;
    def definition(path: str, line: int, col: int) -> list[SourceSpan];
    def references(path: str, line: int, col: int) -> list[SourceSpan];
    def completion(
        path: str, line: int, col: int, trigger: str = ""
    ) -> list[CompletionItem];

    def semantic_tokens(path: str) -> list[int];
    def inlay_hints(path: str, first_line: int, last_line: int) -> list[InlayHint];
    def symbols(path: str) -> list[DocumentSymbol];
    def rename(path: str, line: int, col: int, new_name: str) -> list[TextEdit];
    def format(path: str) -> ToolOutput;
    def lint_fix(path: str) -> ToolOutput;
    def lint(path: str) -> ToolOutput;
    def parse(path: str) -> ToolOutput;
    def statements(path: str) -> list[SourceSpan];
    def py_to_jac(path: str) -> ToolOutput;
    def ast_view(path: str, view: str) -> ToolOutput;
    def explain(path: str, topic: str, memory_profile: str = "") -> ToolOutput;
    def grammar -> GrammarReport;
    def arch_plan(
        arch_path: str, action: str, prune: bool = False, graph_format: str = ""
    ) -> ArchPlan;

    def compile(request: CompileRequest) -> CompileResult;
    def check(request: CheckRequest) -> CheckResult;
}

def compile_request(request: CompileRequest) -> CompileResult;

def check_request(request: CheckRequest) -> CheckResult;

def open_session(
    project_root: str, search_paths: list[str], package_root: str
) -> KernelSession;

def enter_world(project_root: str, search_paths: list[str], package_root: str);

def run_compile(
    program: JacProgram, host: ProjectHost, request: CompileRequest
) -> CompileResult;

def run_check(
    program: JacProgram, host: ProjectHost, request: CheckRequest
) -> CheckResult;

def emitted_paths(host: ProjectHost, requested: list[str]) -> list[str];

def compiled_unit(host: ProjectHost, real: str, want_code: bool) -> CompiledUnit;

def kernel_diagnostic(alert: Alert, severity: str) -> KernelDiagnostic;

def source_span(loc: Span) -> SourceSpan;

def other_compiler_diagnostic(path: str, root: str) -> KernelDiagnostic;

def collect_diagnostics(
    program: JacProgram, errors: list[KernelDiagnostic], warnings: list[KernelDiagnostic]
);

def merge_app_diagnostics(
    collected: list[tuple[str, list[KernelDiagnostic]]]
) -> list[KernelDiagnostic];
