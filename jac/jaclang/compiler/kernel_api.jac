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
        closure: bool = False,
        module_facts: bool = False;
}

"""What a check learned about one analysed module, present when the request
asks for `module_facts`. `spaces` are the codespaces its elements run in (its
decided codespace alone when it has one), `client_declared` whether it
declares client code, `errors` how many errors it owns, and `imports` the Jac
modules it imports, resolved to paths."""
obj ModuleFact {
    has path: str,
        app: str = "",
        spaces: list[str] = [],
        decided: str = "",
        client_declared: bool = False,
        errors: int = 0,
        imports: list[str] = [];
}

"""A cross-app edge an application's boundary facts declare: `consumer` calls
into `provider`."""
obj AppEdge {
    has consumer: str,
        provider: str;
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
}

"""A native artifact to build. `roots` are the closure's root modules and
`kind` one of "executable", "shared", "wasm" or "plan" (lower the closure
into the unit caches, link nothing). `output` is where the artifact goes;
with `emit_c` it receives the merged program as C source instead. The
`refuse_*` flags stop the build before linking when the closure imports
Python or carries demoted functions; `require_entry` stops it when the root
has no entry point; `kernel_entries` refuses a compiler kernel whose loader
entry points are missing; `assert_no_rc` refuses emitted IR that carries
refcount machinery; `callbacks` binds the root's callable native imports as
callbacks."""
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
}

obj LinkedUnit {
    has path: str,
        digest: str,
        stamp: str = "";
}

obj CallbackBinding {
    has name: str,
        symbol: str,
        ret_type: str,
        param_types: list[str] = [];
}

"""What a native build did. `linked` is False when the build stopped before
linking: on errors, or on a refusal its request asked for, whose facts
(`python_imports`, `demoted`, `rc_symbols`, `rc_probes`, `has_entry`,
`root_native`) say why. `recompiled` counts the units this build lowered and
`analysed`, `lowered` and `generated` the cache events behind them; `log`
holds the build's progress lines in order."""
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
        layout_digest: str = "",
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
}

"""A top-level element's codespace: `space` is where it runs, `dual` whether
it is placed on both sides. A marker scan reuses it for the elements a
retired placement marker claimed."""
obj ElementSpace {
    has name: str,
        space: str,
        line: int = 0,
        dual: bool = False;
}

"""An import statement's placement: `client_only` is True when only client
code reads what it imports. A marker scan reuses it for the retired
`sv import` statements it strips."""
obj ImportSpace {
    has target: str,
        line: int,
        client_only: bool = False;
}

"""The source with its retired placement markers stripped, what the markers
claimed, and `note` naming why the file was left alone (empty when it was
scanned)."""
obj MarkerScan {
    has text: str = "",
        changed: bool = False,
        claims: list[ElementSpace] = [],
        sv_imports: list[ImportSpace] = [],
        note: str = "";
}

obj AccessRewrite {
    has path: str,
        line: int,
        kind: str,
        name: str,
        reason: str;
}

obj AccessPlan {
    has rewrites: list[AccessRewrite] = [],
        notes: list[str] = [];
}

obj StubCatalogReport {
    has summary: str = "",
        load_failures: list[str] = [];
}

"""One client module a project publishes to npm: its linked JavaScript with
JSDoc, its TypeScript declarations, and the npm packages it imports."""
obj NpmSource {
    has npm_path: str,
        source_path: str,
        js: str,
        dts: str,
        external_imports: list[str] = [];
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

"""A symbol the project-wide code index knows by name (`jac code`, studio's
agent)."""
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
}

obj CodeDiagnostic {
    has file: str,
        line: int,
        severity: str,
        message: str;

    def render -> str;
    def to_dict -> dict[str, any];
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
}

"""A declaration of a module or one of its annexes. `owner` names the
archetype a field or method belongs to; an impl names its `target`."""
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
}

"""A module's declarations, woven with its annexes; `error` says why it could
not be parsed."""
obj ModuleOutline {
    has path: str,
        doc: str = "",
        files: list[str] = [],
        symbols: list[OutlineSymbol] = [],
        error: str = "";
}

"""One top-level declaration of a source text, keyed by its dotted name, with
the text and signature an edit review compares."""
obj EditSymbol {
    has key: str,
        kind: str,
        line: int,
        end_line: int,
        text: str,
        signature: str = "";
}

obj WiringChange {
    has kind: str,
        detail: str,
        module: str = "";
}

"""The module files a module's wires feed; `owned` is False when no
archwire.jac governs the module."""
obj WiredFiles {
    has owned: bool = False,
        files: list[str] = [];
}

obj WiringModule {
    has local: str,
        file: str = "",
        import_name: str = "",
        project: bool = False;
}

"""One wire into one consumer. `rules` names the rules admitting it, `arms`
the rule arms it matches as `rule<US>source<US>target`."""
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
}

obj WiringRule {
    has name: str,
        sources: list[str] = [],
        targets: list[str] = [],
        names: list[str] = [],
        governs: list[str] = [];
}

"""An archwire.jac as data: its modules, its wires per consumer and its
rules."""
obj WiringModel {
    has arch_path: str,
        parsed: bool = True,
        modules: list[WiringModule] = [],
        edges: list[WiringEdge] = [],
        rules: list[WiringRule] = [];
}

"""The symbol a token resolves to. Columns are 0-based, lines 1-based."""
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
}

obj SourceToken {
    has kind: str,
        value: str,
        line: int,
        col: int,
        end_line: int,
        end_col: int;
}

"""A text's lexical tokens and comments, for highlighting."""
obj TokenStream {
    has tokens: list[SourceToken] = [],
        comments: list[SourceSpan] = [];
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
        _open: set[str] = set(),
        _intel: (CodeIntelligence | None) = None;

    def postinit;
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

def compiled_unit(
    host: ProjectHost, real: str, want_code: bool, want_ast: bool = False
) -> CompiledUnit;

def kernel_diagnostic(alert: Alert, severity: str) -> KernelDiagnostic;

def source_span(loc: Span) -> SourceSpan;

def other_compiler_diagnostic(path: str, root: str) -> KernelDiagnostic;

def collect_diagnostics(
    program: JacProgram, errors: list[KernelDiagnostic], warnings: list[KernelDiagnostic]
);

def merge_app_diagnostics(
    collected: list[tuple[str, list[KernelDiagnostic]]]
) -> list[KernelDiagnostic];
