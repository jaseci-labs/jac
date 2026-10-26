glob _serving_probe: list[bool] = [False],
     _graphmend_disable_override: list[str] = [],
     GM_DEFER_BUFFERS_THREAD_SCOPED: bool = False;

def mark_process_serving;

def override_graphmend_disable(names: list[str]);

def graphmend_disable_override -> list[str];

def process_is_serving -> bool;

def defer_declines_here -> bool;

def resolved_graphmend_setting -> bool;

def resolved_graphmend_disable_setting -> list[str];

def resolved_graphmend_claim_imports_setting -> bool;

obj CancelToken {
    has requested: bool = False;

    def set;
    def clear;
    def is_set -> bool;
}

obj CompileOptions {
    has symtab_ir_only: bool = False,
        no_cgen: bool = False,
        native_parity: bool = False,
        native_required: bool = False,
        native_require: (list[str] | None) = None,
        iface_ok: bool = False,
        need_full_ast: bool = False,
        native_tree_demand: bool = False,
        skip_analysis: bool = False,
        skip_native_engine: bool = False,
        no_ir_cache: bool = False,
        resolve_annex_parent: bool = False,
        aot_mode: bool = False,
        graphmend: (bool | None) = None,
        graphmend_claim_imports: (bool | None) = None,
        graphmend_disable: (list[str] | None) = None,
        native_unit: bool = False,
        kernel_build: bool = False,
        native_link_mode: (str | None) = None,
        force_codespace: str = "",
        memory_profile: (str | None) = None,
        na_gc_mode: (str | None) = None,
        nogc_enforce_all: (bool | None) = None,
        memory_enforce: (list[str] | None) = None,
        memory_exempt: (list[str] | None) = None,
        native_threads: (int | None) = None,
        rc_debug_codegen: (bool | None) = None,
        native_target: (str | None) = None,
        native_debug: (bool | None) = None,
        opt_level: (int | None) = None,
        dump_ir_path: (str | None) = None,
        debug_ir: (bool | None) = None,
        rc_stats: (bool | None) = None,
        nogc_debug: (bool | None) = None,
        na_debug: (bool | None) = None,
        suppress_codes: list[str] = [],
        default_codespace: str = "",
        app_kind: str = "",
        target_app: str = "",
        entry_point: str = "",
        ui: str = "",
        project_root: (str | None) = None,
        native_module_walk_order: (str | None) = None,
        strict_dependencies: bool = False,
        package_canonical: bool = False,
        cancel_token: (CancelToken | None) = None;

    def postinit;
    def effective_triple -> str;
    def codegen_identity -> str;
    def codegen_fingerprint -> str;
    def analysis_identity -> str;
    def artifact_identity -> str;
    def analysis_fingerprint -> str;
    def base_codegen_identity -> str;
    def unit_codegen_identity(path: str) -> str;
    def dependency_projection(path: str) -> str;
    def module_projection -> str;
    def keeps_interfaces -> bool;
    def for_symbols(need_tree: bool = False) -> CompileOptions;
    def clone_for_native_import -> CompileOptions;
    def native_required_for(mod_path: str) -> bool;
    def nogc_enforced_for(mod_name: str) -> bool;
}

glob NATIVE_LINK_MODE_OBJECTS: str = "objects",
     NATIVE_LINK_MODE_BITCODE: str = "bitcode",
     NATIVE_LINK_MODES: tuple[str, str] = ("objects", "bitcode");

def effective_codegen_fingerprint -> str;


def effective_analysis_fingerprint -> str;

def link_fingerprint_mismatches(
    participants: list[tuple[str, str]], current_fp: str
) -> list[str];

def env_symmap_requested -> bool;

def env_na_debug -> bool;

def env_typed_pointers_enabled -> bool;

def push_native_target(triple: str) -> (str | None);

def pop_native_target(prev: (str | None));
