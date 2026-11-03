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
        python_source: str = "",
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
        closure: bool = False,
        module_facts: bool = False;

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> CheckRequest;
}

obj ModuleFact {
    has path: str,
        app: str = "",
        spaces: list[str] = [],
        decided: str = "",
        client_declared: bool = False,
        errors: int = 0,
        imports: list[str] = [];

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> ModuleFact;
}

obj AppEdge {
    has consumer: str,
        provider: str;

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> AppEdge;
}

obj CheckResult {
    has errors: list[KernelDiagnostic] = [],
        warnings: list[KernelDiagnostic] = [],
        reached: list[str] = [],
        coverage: list[CoverageRow] = [],
        placements: list[PlacementRow] = [],
        modules: list[ModuleFact] = [],
        app_edges: list[AppEdge] = [];

    def ok -> bool;
    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> CheckResult;
}

obj NativeBuildRequest {
    has roots: list[str],
        kind: str,
        output: str = "",
        project_root: str = "",
        search_paths: list[str] = [],
        package_root: str = "",
        options: CompileOptions = CompileOptions(),
        link_mode: str = "",
        native_unit: bool = False,
        library_api: bool = False,
        callbacks: bool = False,
        emit_c: bool = False,
        refuse_python_imports: bool = False,
        refuse_demoted: bool = False,
        require_entry: bool = False,
        kernel_entries: bool = False,
        assert_no_rc: bool = False;

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> NativeBuildRequest;
}

obj LinkedUnit {
    has path: str,
        digest: str,
        stamp: NativeStamp = NativeStamp();

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> LinkedUnit;
}

obj CallbackBinding {
    has name: str,
        symbol: str,
        ret_type: str,
        param_types: list[str] = [];

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> CallbackBinding;
}

obj NativeBuildResult {
    has errors: list[KernelDiagnostic] = [],
        warnings: list[KernelDiagnostic] = [],
        linked: bool = False,
        reused: bool = False,
        output: str = "",
        mode: str = "",
        triple: str = "",
        units: list[LinkedUnit] = [],
        recompiled: int = 0,
        analysed: int = 0,
        lowered: int = 0,
        generated: int = 0,
        sha256: str = "",
        plan_digest: str = "",
        root_native: bool = False,
        has_entry: bool = False,
        python_imports: list[str] = [],
        demoted: list[str] = [],
        rc_symbols: list[str] = [],
        rc_probes: list[str] = [],
        libraries: list[str] = [],
        callbacks: list[CallbackBinding] = [],
        log: list[str] = [];

    def ok -> bool;
    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> NativeBuildResult;
}

obj ElementSpace {
    has name: str,
        space: str,
        line: int = 0,
        dual: bool = False;

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> ElementSpace;
}

obj ImportSpace {
    has target: str,
        line: int,
        client_only: bool = False;

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> ImportSpace;
}

obj MarkerScan {
    has text: str = "",
        changed: bool = False,
        claims: list[ElementSpace] = [],
        sv_imports: list[ImportSpace] = [],
        note: str = "";

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> MarkerScan;
}

obj AccessRewrite {
    has path: str,
        line: int,
        kind: str,
        name: str,
        reason: str;

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> AccessRewrite;
}

obj AccessPlan {
    has rewrites: list[AccessRewrite] = [],
        notes: list[str] = [];

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> AccessPlan;
}

obj StubCatalogReport {
    has summary: str = "",
        load_failures: list[str] = [];

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> StubCatalogReport;
}

obj NpmSource {
    has npm_path: str,
        source_path: str,
        js: str,
        dts: str,
        external_imports: list[str] = [];

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> NpmSource;
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

obj ToolOutput {
    has text: str = "",
        errors: list[KernelDiagnostic] = [],
        warnings: list[KernelDiagnostic] = [];

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> ToolOutput;
}

obj GrammarReport {
    has ebnf: str,
        rules: int,
        diagnostics: str = "",
        errors: list[KernelDiagnostic] = [];

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> GrammarReport;
}

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

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> ArchPlan;
}

obj SymbolInfo {
    has name: str,
        kind: str,
        file: str,
        line: int,
        col: int = 0,
        type_str: str = "",
        doc: str = "",
        signature: str = "",
        fields: list[str] = [],
        abilities: list[str] = [],
        base_classes: list[str] = [],
        is_genai: bool = False;

    def render -> str;
    def to_dict -> dict[str, any];
    static def from_dict(d: dict[str, any]) -> SymbolInfo;
}

obj SourceRef {
    has file: str,
        line: int,
        col: int = 0,
        role: str = "use",
        snippet: str = "";

    def render -> str;
    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> SourceRef;
}

obj CodeDiagnostic {
    has file: str,
        line: int,
        severity: str,
        message: str;

    def render -> str;
    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> CodeDiagnostic;
}

obj EntryPoint {
    has walker_name: str,
        ability: str,
        node_type: str,
        event: str,
        file: str = "",
        line: int = 0;

    def render -> str;
    def to_dict -> dict[str, any];
    static def from_dict(d: dict[str, any]) -> EntryPoint;
}

obj ContextSlice {
    has query: str,
        target: (SymbolInfo | None) = None,
        related: list[SymbolInfo] = [],
        uses: list[SourceRef] = [];

    def render -> str;
    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> ContextSlice;
}

obj OutlineSymbol {
    has kind: str,
        name: str,
        owner: str = "",
        file: str = "",
        line: int = 0,
        end_line: int = 0,
        col: int = 0,
        doc: str = "",
        bases: list[str] = [],
        signature: str = "",
        event: str = "",
        type_str: str = "",
        target: str = "";

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> OutlineSymbol;
}

obj ModuleOutline {
    has path: str,
        doc: str = "",
        files: list[str] = [],
        symbols: list[OutlineSymbol] = [],
        error: str = "";

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> ModuleOutline;
}

obj EditSymbol {
    has key: str,
        kind: str,
        line: int,
        end_line: int,
        text: str,
        signature: str = "";

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> EditSymbol;
}

obj WiringChange {
    has kind: str,
        detail: str,
        module: str = "";

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> WiringChange;
}

obj WiredFiles {
    has owned: bool = False,
        files: list[str] = [];

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> WiredFiles;
}

obj WiringModule {
    has local: str,
        file: str = "",
        import_name: str = "",
        project: bool = False;

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> WiringModule;
}

obj WiringEdge {
    has provider: str,
        consumer: str,
        scope: list[str] = [],
        names: list[str] = [],
        form: str = "",
        injected: bool = True,
        line: int = 0,
        crosses: bool = False,
        rules: list[str] = [],
        violation: str = "",
        arms: list[str] = [];

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> WiringEdge;
}

obj WiringRule {
    has name: str,
        sources: list[str] = [],
        targets: list[str] = [],
        names: list[str] = [],
        governs: list[str] = [];

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> WiringRule;
}

obj WiringModel {
    has arch_path: str,
        parsed: bool = True,
        modules: list[WiringModule] = [],
        edges: list[WiringEdge] = [],
        rules: list[WiringRule] = [];

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> WiringModel;
}

obj TokenSymbol {
    has line: int,
        col: int,
        end_col: int,
        name: str,
        kind: str = "",
        dotted: str = "",
        decl_path: str = "",
        decl_line: int = 0,
        decl_col: int = 0;

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> TokenSymbol;
}

obj SourceToken {
    has kind: str,
        value: str,
        line: int,
        col: int,
        end_line: int,
        end_col: int;

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> SourceToken;
}

obj TokenStream {
    has tokens: list[SourceToken] = [],
        comments: list[SourceSpan] = [];

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> TokenStream;
}

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
        _open: set[str] = set(),
        _edges_seeded: bool = False,
        _intel: (CodeIntelligence | None) = None,
        _entered: list[HostServices | None] = [];

    def postinit;
    def live_program -> JacProgram;
    def live_host -> ProjectHost;
    def enter -> ProjectHost;
    def leave;
    def invalidate(real: str);
    def owner(real: str) -> str;
    def touch(real: str);
    def analysed(path: str) -> uni.Module;
    def app_targets(real: str) -> list[tuple[str, str, str]];
    def compile_for(real: str, target: (tuple[str, str, str] | None)) -> uni.Module;
    def own_files(real: str) -> set[str];
    def formatted(path: str, auto_lint: bool) -> ToolOutput;

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
    def completion(path: str, line: int, col: int) -> list[CompletionItem];
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

    def strip_markers(path: str, text: str) -> MarkerScan;
    def element_spaces(path: str) -> list[ElementSpace];
    def client_imports(path: str) -> list[ImportSpace];
    def access_plan(project_root: str) -> AccessPlan;
    def package_api(base_root: str, exports: list[str]) -> str;
    def stub_catalog(
        out_path: str, only: list[str], pkg_dir: str
    ) -> StubCatalogReport;

    def npm_sources(project_root: str) -> list[NpmSource];
    def definition_rows(path: str) -> list[str];

    def compile(request: CompileRequest) -> CompileResult;
    def check(request: CheckRequest) -> CheckResult;
    def module_outline(path: str) -> ModuleOutline;
    def edit_symbols(path: str, text: str) -> list[EditSymbol];
    def import_texts(path: str, text: str) -> list[str];
    def wiring_changes(path: str, old_text: str, new_text: str) -> list[WiringChange];
    def wired_dependents(head: str, names: list[str]) -> WiredFiles;
    def wiring_module_files(arch_path: str, consumers: list[str]) -> list[str];
    def wiring_model(arch_path: str) -> WiringModel;
    def token_symbols(path: str) -> list[TokenSymbol];
    def assignment_hints(path: str) -> list[InlayHint];
    def tokens(path: str, text: str) -> TokenStream;
    def code_index -> CodeIntelligence;
    def code_lookup(name: str) -> list[SymbolInfo];
    def code_references(name: str) -> list[SourceRef];
    def code_archetypes(kind: str) -> list[SymbolInfo];
    def code_walkers(node_type: str) -> list[EntryPoint];
    def code_slice(name: str, depth: int) -> ContextSlice;
    def code_diagnostics(file: str) -> list[CodeDiagnostic];
    def code_refresh(file: str);
}

def session_query(session: KernelSession, method: str, args: list[any]) -> any;

def compile_request(request: CompileRequest) -> CompileResult;

def check_request(request: CheckRequest) -> CheckResult;

def native_build_request(request: NativeBuildRequest) -> NativeBuildResult;

def run_native_build(
    program: JacProgram, host: ProjectHost, request: NativeBuildRequest
) -> NativeBuildResult;

def module_fact(
    program: JacProgram, real: str, module: uni.Module, app: str
) -> ModuleFact;

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

def compiled_unit(host: ProjectHost, real: str, want_source: bool) -> CompiledUnit;

def kernel_diagnostic(alert: Alert, severity: str) -> KernelDiagnostic;

def source_span(loc: Span) -> SourceSpan;

def node_span(loc: CodeLocInfo) -> SourceSpan;

def other_compiler_diagnostic(path: str, tree: str) -> KernelDiagnostic;

def collect_diagnostics(
    program: JacProgram, errors: list[KernelDiagnostic], warnings: list[KernelDiagnostic]
);

def merge_app_diagnostics(
    collected: list[tuple[str, list[KernelDiagnostic]]]
) -> list[KernelDiagnostic];
