"""The host's side of the kernel boundary. Host code speaks `kernel_api`
records and the kernel module `jac_kernel` speaks plain Python data named
after them: each call turns its request record into a dict, calls the loaded
kernel, and turns the result dict back into its record. A refusal the kernel
raises is a `KernelError`."""
import sys;

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

def kernel_build_request_record(request: KernelBuildRequest) -> dict[str, any];

def span_of_record(raw: dict[str, any]) -> SourceSpan;

def diagnostic_of_record(raw: dict[str, any]) -> KernelDiagnostic;

def demotion_of_record(raw: dict[str, any]) -> NativeDemotion;

def unit_of_record(raw: dict[str, any]) -> CompiledUnit;

def compile_result_of(raw: dict[str, any]) -> CompileResult;

def check_result_of(raw: dict[str, any]) -> CheckResult;

def kernel_build_result_of(raw: dict[str, any]) -> KernelBuildResult;

def call_compile(request: CompileRequest) -> CompileResult;

def call_check(request: CheckRequest) -> CheckResult;

def call_build_kernel(request: KernelBuildRequest) -> KernelBuildResult;

def open_kernel_session(project_root: str) -> any;
