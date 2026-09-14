"""The Jac Programming Language."""

import sys
from importlib import import_module
from pathlib import Path
from typing import TYPE_CHECKING


def _install_importer() -> None:
    package_dir = Path(__file__).parent
    if (package_dir / "runtime.json").is_file():
        from jaclang.runtime.source_app import load_runtime

        load_runtime(package_dir)
        return

    # Source loading is an optional build service. Exported packages install
    # their prepared importer from the same initialization entry point.
    importer = import_module("jaclang.meta_importer").JacMetaImporter
    if not any(isinstance(f, importer) for f in sys.meta_path):
        sys.meta_path.insert(0, importer())

    # The binary already adds the project environment through sitecustomize;
    # ordinary Python library imports need the same idempotent setup.
    with __import__("contextlib").suppress(Exception):
        import _jac_finder as _jf

        _jf.add_project_venv_to_path()


# --- Lazy compiler/runtime bootstrap -------------------------------------
# The compiler and runtime.runtime were previously imported eagerly here, which
# pulled them (and the parser/codegen pipeline) in on every `import jaclang`
# and defeated the lazy CLI fast paths -- `jac --version` / `--help` / `purge`
# must stay light. They now load on first attribute access (PEP 562) so plain
# `import jaclang` stays cheap while `from jaclang import JacRuntime`,
# `import jaclang.compiler`, etc. keep working unchanged.
def _load_jac_runtime() -> None:
    # The runtime does not require the compiler to be pre-imported (it loads via
    # the jac0 bootstrap tier, not the full compiler), so we don't pull in
    # `jaclang.compiler` here -- doing so would re-introduce a heavy import on
    # the fast paths. `jaclang.compiler` stays available lazily via __getattr__.
    from jaclang.runtime.runtime import JacRuntime, JacRuntimeInterface

    globals().update(
        {
            "JacRuntime": JacRuntime,
            "JacRuntimeInterface": JacRuntimeInterface,
        }
    )


# The names below are bound at runtime by `_load_jac_runtime()` / `__getattr__`
# (PEP 562), which keeps `import jaclang` cheap. A type checker cannot see a
# name injected into globals(), so declare them here for static resolution
# only -- this block never executes, so the laziness is preserved.
if TYPE_CHECKING:
    import jaclang.compiler as compiler
    from jaclang.runtime.runtime import JacRuntime, JacRuntimeInterface


def __getattr__(name: str) -> object:
    if name in {"JacRuntime", "JacRuntimeInterface"}:
        _load_jac_runtime()
        return globals()[name]
    if name == "compiler":
        import jaclang.compiler as _compiler

        globals()["compiler"] = _compiler
        return _compiler
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")


__all__ = ["JacRuntimeInterface", "JacRuntime", "compiler"]

_install_importer()
