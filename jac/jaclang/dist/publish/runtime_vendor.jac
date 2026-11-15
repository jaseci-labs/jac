import ast as py_ast;
import json;
import tempfile;
import from pathlib { Path }

def _pkg_root -> Path;

def _module_to_file(pkg_root: Path, mod: str) -> Path | None;

def scan_jaclang_imports(
    py_src: str | py_ast.Module,
    module: str = '',
    package: bool = False,
    include_symbols: bool = True
) -> set[str];

def _runtime_dependencies(
    pkg_root: Path, source: py_ast.Module, module: str = '', package: bool = False
) -> set[str];

def _declared_literal(tree: py_ast.Module, name: str) -> object;

def _compile_runtime_module(
    pkg_root: Path,
    path: Path,
    prog: JacProgram,
    native: dict[str, any] | None = None,
    native_sources: bool = True
) -> str;


def _runtime_module_options(path: Path) -> CompileOptions;

def build_runtime_closure(
    user_codes: list[str],
    include_byllm: bool = False,
    extra_seeds: list[str] | None = None,
    prepared: bool = True,
    native_sources: bool = True
) -> dict[str, bytes];

def vendor_runtime(
    backend_dir: Path,
    user_codes: list[str],
    include_byllm: bool = False,
    extra_seeds: list[str] | None = None,
    prepared: bool = True
) -> int;
