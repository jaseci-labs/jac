glob SHARED_INIT_SYMBOL: str = "__jac_shared_init",
     ENTRY_SYMBOL: str = "jac_entry",
     SHARED_MAIN_SYMBOL: str = "jac_main",
     WASM_INIT_SYMBOL: str = "__jac_glob_init",
     REGION_DIED_HOOK: str = "__jac_region_died_hook",
     STR_NEW_SYMBOL: str = "__jac_str_new",
     RC_THREADED_SYMBOL: str = "__jac_rc_threaded";

obj GlueUnit {
    has prefix: str,
        init_symbol: str = "",
        entry_symbol: str = "",
        probe: str = "",
        retain: bool = False,
        release: bool = False,
        str_new: str = "";
}

obj GlueSpec {
    has units: list[GlueUnit],
        root_index: int = -1,
        shared: bool = False,
        platform: str = "elf",
        static_musl: bool = False,
        triple: str = "",
        data_layout: str = "",
        clib_paths: list[str] = [],
        needs_atexit_shim: bool = False,
        needs_region_hook: bool = True;
}

def _decl_void_fn(name: str) -> str;

def entry_preamble_ir(spec: GlueSpec) -> str;

def rc_wrapper_ir(spec: GlueSpec) -> tuple[str, list[str]];

def atexit_shim_ir -> str;

def region_hook_ir -> str;

def argv_globals_ir -> str;

def _main_body -> str;

def init_array_runner_ir -> str;

def entry_elf_ir -> str;

def entry_elf_static_ir -> str;

def entry_macho_ir -> str;

def entry_pe_ir -> str;

def shared_entry_symbol(spec: GlueSpec) -> str;

def shared_main_ir(spec: GlueSpec) -> str;

def platform_entry_ir(spec: GlueSpec) -> str;

def shared_init_registration_ir(spec: GlueSpec) -> str;

def link_glue_ir(spec: GlueSpec) -> tuple[str, list[str]];

def init_object_codegen;

def bind_shared_callbacks(
    llvm_ir: str, bindings: list[InteropBinding]
) -> tuple[str, list[InteropBinding]];

def inject_heap_accounting(
    llvm_ir_str: str, managed: bool = False
) -> tuple[str, list[str]];
