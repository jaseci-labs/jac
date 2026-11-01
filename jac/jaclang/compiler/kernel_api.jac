"""The kernel's interface: the only way anything outside the kernel reaches the
compiler.

The kernel is a JacPython native module (`jac_kernel`). Its binding
(`compiler/kernel_module.jac`) converts Python objects to these records and
back, and calls `compile_request`, `check_request` and `open_session`. Nothing
here calls back into the host: the kernel reads files, configuration and
caches itself, and every failure is a diagnostic or a raised `KernelError`,
never a quiet default.

Requests name files by absolute path. `sources` overlays unsaved editor text
on the file system for the paths it names."""
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
made by JacPython's compiler inside the kernel: an owned reference, NULL when
no bytecode was asked for, which the module binding hands to its caller. The
native products are present when the module is native."""
obj CompiledUnit {
    has path: str,
        module_name: str,
        code: ptr[PyObject] = ptr[PyObject](),
        interface: bytes = b"",
        placement: str = "",
        client_js: str = "",
        native_object: bytes = b"",
        native_iface: str = "",
        native_deps: list[str] = [],
        demoted: list[NativeDemotion] = [],
        jac_deps: list[str] = [];
}

obj CompileRequest {
    has paths: list[str],
        project_root: str = "",
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

"""An analysed project held across edits. Every tooling feature is a query on
a session; an edit re-analyses incrementally inside the kernel."""
obj KernelSession {
    has project_root: str;

    def update(path: str, text: str);
    def close(path: str);
    def forget(path: str);
    def rename_module(old_path: str, new_path: str);
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
    def format(path: str) -> str;
    def lint_fix(path: str) -> str;
    def compile(request: CompileRequest) -> CompileResult;
    def check(request: CheckRequest) -> CheckResult;
}

def compile_request(request: CompileRequest) -> CompileResult;

def check_request(request: CheckRequest) -> CheckResult;

def open_session(project_root: str) -> KernelSession;
