import from pathlib { Path }


def write_native_product(
    source_path: str,
    directory: Path,
    relative: Path,
    shared: bool = True,
    memory: str = '',
    emit_source: bool = True,
    program: JacProgram | None = None
) -> dict[str, any];
