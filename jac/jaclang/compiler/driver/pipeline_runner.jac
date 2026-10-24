import os;

def wasm_ir(program: JacProgram, file_path: str) -> tuple[str, set[str]];

def wasm_artifact(program: JacProgram, file_path: str, exports: list[str]) -> bytes;


def native_application(
    program: JacProgram,
    file_path: str,
    target: str = '',
    memory: str = '',
    debug: bool = False,
    no_ir_cache: bool = False
) -> tuple[uni.Module, CompileOptions];


def build_wasm(program: JacProgram, path: str, exports: list[str]) -> bytes;

def route_exports(program: JacProgram, path: str) -> tuple[str | None, str | None];

def compile_application(
    program: JacProgram, entry_path: str, options: CompileOptions
) -> uni.Module;
