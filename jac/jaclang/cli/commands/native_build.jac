def native_build(
    filename: str,
    output: str = "",
    lib: bool = False,
    target: str = "",
    debug: bool = False,
    memory: str = "",
    no_ir_cache: bool = False,
    source_prefix_map: dict[str, str] | None = None
) -> int;
