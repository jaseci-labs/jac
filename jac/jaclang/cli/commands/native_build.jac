import from jaclang.compiler.backends.common.artifact_store { artifact_for }
def native_build(
    filename: str,
    output: str = "",
    lib: bool = False,
    target: str = "",
    debug: bool = False,
    memory: str = "",
    no_ir_cache: bool = False
) -> int;
