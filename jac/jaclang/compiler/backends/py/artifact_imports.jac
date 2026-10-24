import dis;
import os;
import types;
import from pathlib { Path }

def import_specs(
    code: types.CodeType, source: str
) -> list[tuple[int, str, (tuple[str, ...] | None)]];

def resolve_imports(
    specs: list[tuple[int, str, (tuple[str, ...] | None)]], source: str, `root: str
) -> set[str];

def runtime_sources(code: types.CodeType, source: str, `root: str) -> set[str];

def package_sources(source: str, project_root: str) -> set[str];
