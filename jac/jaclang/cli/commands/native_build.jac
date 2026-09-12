def native_build(  # jac:ignore[W3030]
    filename: str,
    output: str = "",
    lib: bool = False,
    target: str = "",
    debug: bool = False,
    memory: str = "",
    no_ir_cache: bool = False,
    entry_lib: bool = False
) -> int;

def native_build_sealed_pair(filename: str, exe_output: str, lib_output: str) -> int;
