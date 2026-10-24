import json;

glob WASM_MEMORY_PAGES: int = 256,
     WASM_STACK_BYTES: int = 1 << 18,
     WASM_GLOBAL_BASE: int = 1024;

def wasm_ld_args(
    output_path: str,
    inputs: list[str],
    export_funcs: list[str],
    allow_file: str = "",
    memory_pages: int = WASM_MEMORY_PAGES
) -> list[str];

def wasm_object_functions(obj_bytes: bytes) -> list[str];

def _symbol_table_functions(b: bytes, p: int) -> list[str];

def write_allowed_imports(path: str, names: list[str]);

def read_uleb128(b: bytes, o: int) -> tuple[int, int];

def encode_uleb128(v: int) -> bytes;

def read_leb_name(b: bytes, o: int) -> tuple[str, int];

def _name_bytes(name: str) -> bytes;

def rename_wasm_imports(wasm_bytes: bytes, names: set[str], module: str) -> bytes;

def wasm_import_map(wasm_bytes: bytes) -> dict[str, list[str]];

def wasm_assets(stem: str, content: bytes) -> dict[str, bytes];
