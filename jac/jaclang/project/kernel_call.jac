"""The host's side of the kernel boundary. Host code speaks `kernel_api`
records and the kernel module `jac_kernel` speaks plain Python data named
after them: each call turns its request record into a dict, calls the loaded
kernel, and turns the result dict back into its record. A refusal the kernel
raises is a `KernelError`.

`SessionClient` is the host's typed handle on a `jac_kernel.Session`: tooling
(the language server, studio, MCP and the CLI tools) holds one and asks it
every question about code. Its calls are serialized, so threads may share it.
`tool_session` is the process's shared session for one-shot CLI tools."""
import sys;
import threading;

glob KERNEL_OPTION_FIELDS: tuple[str, ...] = (
         "symtab_ir_only",
         "no_cgen",
         "native_parity",
         "native_required",
         "native_require",
         "iface_ok",
         "need_full_ast",
         "native_tree_demand",
         "skip_analysis",
         "skip_native_engine",
         "no_ir_cache",
         "resolve_annex_parent",
         "aot_mode",
         "native_unit",
         "kernel_build",
         "native_link_mode",
         "force_codespace",
         "memory_profile",
         "na_gc_mode",
         "nogc_enforce_all",
         "na_borrow_infer",
         "memory_enforce",
         "memory_exempt",
         "native_threads",
         "rc_debug_codegen",
         "native_target",
         "native_tls",
         "native_sjlj",
         "native_unchecked_views",
         "native_direct_c_entries",
         "native_heap",
         "native_debug",
         "opt_level",
         "dump_ir_path",
         "debug_ir",
         "rc_stats",
         "nogc_debug",
         "na_debug",
         "suppress_codes",
         "default_codespace",
         "app_kind",
         "target_app",
         "entry_point",
         "ui",
         "project_root",
         "client_source_root",
         "native_module_walk_order",
         "strict_dependencies",
         "package_canonical",
         "na_move_flow"
     );

def options_record(options: CompileOptions) -> dict[str, any];

def compile_request_record(request: CompileRequest) -> dict[str, any];

def check_request_record(request: CheckRequest) -> dict[str, any];

def span_of_record(raw: dict[str, any]) -> SourceSpan;

def diagnostic_of_record(raw: dict[str, any]) -> KernelDiagnostic;

def demotion_of_record(raw: dict[str, any]) -> NativeDemotion;

def unit_of_record(raw: dict[str, any]) -> CompiledUnit;

def completion_of_record(raw: dict[str, any]) -> CompletionItem;

def hint_of_record(raw: dict[str, any]) -> InlayHint;

def symbol_of_record(raw: dict[str, any]) -> DocumentSymbol;

def edit_of_record(raw: dict[str, any]) -> TextEdit;

def output_of_record(raw: dict[str, any]) -> ToolOutput;

def grammar_of_record(raw: dict[str, any]) -> GrammarReport;

def arch_plan_of_record(raw: dict[str, any]) -> ArchPlan;

def outline_of_record(raw: dict[str, any]) -> ModuleOutline;

def edit_symbol_of_record(raw: dict[str, any]) -> EditSymbol;

def wiring_change_of_record(raw: dict[str, any]) -> WiringChange;

def wiring_model_of_record(raw: dict[str, any]) -> WiringModel;

def token_symbol_of_record(raw: dict[str, any]) -> TokenSymbol;

def token_stream_of_record(raw: dict[str, any]) -> TokenStream;

def symbol_info_of_record(raw: dict[str, any]) -> SymbolInfo;

def source_ref_of_record(raw: dict[str, any]) -> SourceRef;

def entry_point_of_record(raw: dict[str, any]) -> EntryPoint;

def context_slice_of_record(raw: dict[str, any]) -> ContextSlice;

def code_diagnostic_of_record(raw: dict[str, any]) -> CodeDiagnostic;

def compile_result_of(raw: dict[str, any]) -> CompileResult;

def check_result_of(raw: dict[str, any]) -> CheckResult;

def call_compile(request: CompileRequest) -> CompileResult;

def call_check(request: CheckRequest) -> CheckResult;

def native_build_request_record(request: NativeBuildRequest) -> dict[str, any];

def native_build_result_of(raw: dict[str, any]) -> NativeBuildResult;

def call_native_build(request: NativeBuildRequest) -> NativeBuildResult;

def element_space_of_record(raw: dict[str, any]) -> ElementSpace;

def import_space_of_record(raw: dict[str, any]) -> ImportSpace;

def marker_scan_of_record(raw: dict[str, any]) -> MarkerScan;

def access_plan_of_record(raw: dict[str, any]) -> AccessPlan;

def open_kernel_session(project_root: str) -> any;

obj SessionClient {
    has project_root: str = "",
        handle: any = None,
        _lock: any = threading.RLock();

    def postinit;
    def ask(method: str, *args: any) -> any;
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

    def compile(request: CompileRequest) -> CompileResult;
    def check(request: CheckRequest) -> CheckResult;
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

    def format_text(path: str, text: str, auto_lint: bool = False) -> ToolOutput;
    def with_text(path: str, text: str, query: Callable[[], any]) -> any;
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

glob _TOOL_SESSIONS: dict[str, SessionClient] = {};

def tool_session(project_root: str = "") -> SessionClient;

def diagnostic_text(diag: KernelDiagnostic) -> str;
