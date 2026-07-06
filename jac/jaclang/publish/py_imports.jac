import from pathlib { Path }

def wheel_module_name(wheel_path: str) -> str;

def rewrite_imports(
    py_source: str, source_path: Path, module_map: dict[str, str],
) -> str;
