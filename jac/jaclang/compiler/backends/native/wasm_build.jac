import os;

def _wasm_libc_dir -> (str | None);

def _mod_functions(mod: ModuleRef) -> list[ValueRef];

def _mod_globals(mod: ModuleRef) -> list[ValueRef];

def _load_libc_module(libc_dir: str, triple: str) -> (ModuleRef | None);

glob _LATE_BOUND: set = {
         "memcpy",
         "memmove",
         "memset",
         "__multi3",
         "puts",
         "putchar",
         "strlen",
         "strcmp",
         "strncmp",
         "strchr",
         "strcpy",
         "stpcpy",
         "memcmp",
         "memchr",
         "calloc",
         "malloc",
         "free",
         "sqrt",
         "pow",
         "exp",
         "exp2",
         "log",
         "log2",
         "fabs",
         "fmod",
         "ldexp",
         "scalbn",

     },
     _BACKEND_BOUND: set = {"memcpy", "memmove", "memset", "__multi3"},
     _ABI64_ADAPTED: set[str] = {
         "strlen",
         "malloc",
         "calloc",
         "realloc",
         "malloc_usable_size",
         "memcpy",
         "memmove",
         "memset",
         "memcmp",
         "memmem",
         "strncmp",
         "strtol",
         "snprintf",

     };


def _assert_abi64_adapters(
    needed: list[str], provided: set[str], libc_dir: str
) -> None;

def _link_wasm_libc(mod: ModuleRef) -> bool;

def _internalize_late_bound(mod: ModuleRef);

def prepare_wasm_module(llvm_ir_str: str) -> tuple[ModuleRef, TargetMachine, bool];

def emit_wasm_from_ir(
    llvm_ir_str: str, export_funcs: list[str] = [], app_imports: (set | None) = None
) -> bytes;

def _exported_functions(mod: ModuleRef) -> list[str];

def link_wasm_object(
    obj_bytes: bytes,
    export_funcs: list[str],
    host_abi: (set | None) = None,
    host_module: str = "",
    app_imports: (set | None) = None
) -> bytes;

def _unexpected_import_message(link_error: str, host_module: str) -> str;

def app_declared_imports(ir_module: UniModule, plan: any = None) -> set[str];

def _project_gc_settings -> tuple[str, list[str], list[str]];

def _assert_ir_rc_free(llvm_ir_str: str, file_path: str);

def compile_to_wasm(file_path: str, export_funcs: list[str] = []) -> bytes;
