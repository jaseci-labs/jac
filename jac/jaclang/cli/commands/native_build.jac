def native_build(
    filename: str,
    output: str = "",
    lib: bool = False,
    link_mode: str = "",
    target: str = "",
    debug: bool = False,
    memory: str = "",
    no_ir_cache: bool = False
) -> int;

def native_build_sealed_pair(filename: str, exe_output: str, lib_output: str) -> int;
