import os;
import copy;

glob KERNEL_API_VERSION: int = 1;

class KernelError(Exception) {}

obj SourceSpan {
    has path: str,
        line: int = 0,
        col: int = 0,
        end_line: int = 0,
        end_col: int = 0;

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> SourceSpan;
}

obj RelatedNote {
    has label: str,
        span: SourceSpan;

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> RelatedNote;
}

obj KernelDiagnostic {
    has code: str,
        severity: str,
        message: str,
        span: SourceSpan,
        help: str = "",
        pass_name: str = "",
        related: list[RelatedNote] = [];

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> KernelDiagnostic;
}

obj NativeDemotion {
    has symbol: str,
        kind: str,
        reason: str,
        code: str,
        span: SourceSpan;

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> NativeDemotion;
}

obj CompiledUnit {
    has path: str,
        module_name: str,
        bytecode: bytes = b"",
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

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> CompiledUnit;
}

obj CompileRequest {
    has paths: list[str],
        project_root: str = "",
        search_paths: list[str] = [],
        package_root: str = "",
        options: CompileOptions = CompileOptions(),
        sources: dict[str, str] = {},
        products: list[str] = ["bytecode"];

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> CompileRequest;
}

obj SourceRead {
    has path: str,
        digest: str;

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> SourceRead;
}

obj CompileResult {
    has units: list[CompiledUnit] = [],
        errors: list[KernelDiagnostic] = [],
        warnings: list[KernelDiagnostic] = [],
        reached: list[str] = [],
        reads: list[SourceRead] = [];

    def ok -> bool;
    def unit(path: str) -> CompiledUnit;

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> CompileResult;
}

obj CoverageRow {
    has path: str,
        outcome: str,
        code: str = "",
        detail: str = "",
        seams: list[str] = [],
        late: int = 0;

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> CoverageRow;
}

obj PlacementRow {
    has path: str,
        symbol: str,
        placement: str,
        reason: str = "";

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> PlacementRow;
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

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> CheckRequest;
}

obj CheckResult {
    has errors: list[KernelDiagnostic] = [],
        warnings: list[KernelDiagnostic] = [],
        reached: list[str] = [],
        coverage: list[CoverageRow] = [],
        placements: list[PlacementRow] = [];

    def ok -> bool;

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> CheckResult;
}

obj TextEdit {
    has span: SourceSpan,
        text: str;

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> TextEdit;
}

obj CompletionItem {
    has label: str,
        kind: str,
        detail: str = "",
        insert_text: str = "";

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> CompletionItem;
}

obj InlayHint {
    has line: int,
        col: int,
        label: str,
        kind: str;

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> InlayHint;
}

obj DocumentSymbol {
    has name: str,
        kind: str,
        span: SourceSpan,
        children: list[DocumentSymbol] = [];

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> DocumentSymbol;
}

obj KernelSession {
    has project_root: str,
        search_paths: list[str] = [],
        package_root: str = "",
        options: CompileOptions = CompileOptions(),
        _host: (ProjectHost | None) = None,
        _program: (JacProgram | None) = None,
        _versions: dict[str, int] = {},
        _analysed: dict[str, int] = {},
        _open: set[str] = set(),
        _entered: list[HostServices] = [];

    def postinit;
    def enter -> ProjectHost;
    def leave;
    def invalidate(real: str);
    def analysed(path: str) -> uni.Module;

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

def session_query(session: KernelSession, method: str, args: list[any]) -> any;

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

def other_compiler_diagnostic(path: str, tree: str) -> KernelDiagnostic;

def collect_diagnostics(
    program: JacProgram, errors: list[KernelDiagnostic], warnings: list[KernelDiagnostic]
);
