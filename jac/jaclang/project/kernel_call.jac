import os;

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
     ),
     KERNEL_PRODUCTS: tuple[str, ...] = (
         "bytecode",
         "interface",
         "placement",
         "client",
         "native"
     );

def options_record(options: CompileOptions) -> dict[str, any];

def compile_request_record(
    path: str, options: CompileOptions, source: (str | None) = None
) -> dict[str, any];

def check_request_record(
    path: str,
    options: CompileOptions,
    source: (str | None) = None,
    closure: bool = False,
    native_coverage: bool = False,
    placements: bool = False
) -> dict[str, any];

def span_of_record(raw: dict[str, any]) -> DiagSpan;

def diag_of_record(raw: dict[str, any]) -> AnalysisDiag;

def analysis_report_of(result: dict[str, any], entry_path: str) -> AnalysisReport;

def unit_of_record(raw: dict[str, any]) -> UnitProducts;

def compile_report_of(result: dict[str, any], entry_path: str) -> CompileReport;

def kernel_analysis(
    path: str, options: CompileOptions, source: (str | None) = None
) -> dict[str, any];
