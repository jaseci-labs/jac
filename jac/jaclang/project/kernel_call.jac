import os;
import sys;
import threading;

glob _TOOL_SESSIONS: dict[str, SessionClient] = {};

obj SessionClient {
    has project_root: str = "",
        _handle: int = 0,
        _local: (KernelSession | None) = None,
        _lock: any = threading.RLock();

    def postinit;
    def ask(method: str, args: list[any]) -> any;
    def release;
    def with_text(path: str, text: str, query: Callable[[], any]) -> any;
    def format_text(path: str, text: str, auto_lint: bool = False) -> ToolOutput;
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
    def code_lookup(name: str) -> list[SymbolInfo];
    def code_references(name: str) -> list[SourceRef];
    def code_archetypes(kind: str) -> list[SymbolInfo];
    def code_walkers(node_type: str) -> list[EntryPoint];
    def code_slice(name: str, depth: int) -> ContextSlice;
    def code_diagnostics(file: str) -> list[CodeDiagnostic];
    def code_refresh(file: str);
}

def world_paths -> tuple[list[str], str];

def call_compile(request: CompileRequest) -> CompileResult;

def call_check(request: CheckRequest) -> CheckResult;

def call_native_build(request: NativeBuildRequest) -> NativeBuildResult;

def tool_session(project_root: str = "") -> SessionClient;

def diagnostic_text(diag: KernelDiagnostic) -> str;
