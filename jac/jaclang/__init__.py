"""The Jac Programming Language."""

import sys

from jaclang.meta_importer import JacMetaImporter  # noqa: E402

# Register JacMetaImporter BEFORE anything else, so .jac modules can be imported
if not any(isinstance(f, JacMetaImporter) for f in sys.meta_path):
    sys.meta_path.insert(0, JacMetaImporter())

# Put the current project's .jac/venv on sys.path so per-project dependencies
# (jac install [-e] <pkg>) and the on-demand feature capabilities (byllm, scale,
# ...) are importable. In the single binary this already ran via sitecustomize
# during interpreter startup; this call is the library-use fallback (plain
# `import jaclang` with no sitecustomize). The helper is idempotent and uses
# addsitedir, so editable .pth links are processed.
with __import__("contextlib").suppress(Exception):
    import _jac_finder as _jf

    _jf.add_project_venv_to_path()


# --- Lazy compiler/runtime bootstrap -------------------------------------
# The compiler and jac0core.runtime were previously imported eagerly here, which
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
    from jaclang.jac0core.runtime import JacRuntime, JacRuntimeInterface

    # The legacy `jaclang.runtimelib.runtime` import path is served lazily by the
    # forwarder module installed in `_install_runtime_shim()`, so no eager
    # sys.modules alias to the heavy runtime is registered here -- that would
    # defeat the laziness this bootstrap exists to preserve.
    globals().update(
        {
            "JacRuntime": JacRuntime,
            "JacRuntimeInterface": JacRuntimeInterface,
        }
    )


def _install_runtime_shim() -> None:
    # Preserve the legacy `import jaclang.runtimelib.runtime` /
    # `from jaclang.runtimelib.runtime import JacRuntime` surface without a
    # `runtime.py`/`runtime.jac` module on disk (the codebase forbids new .py
    # files) and without eagerly importing the heavy runtime.
    #
    # A meta-path finder is used rather than a pre-registered sys.modules entry:
    # pre-registering the leaf short-circuits CPython's parent-package import, so
    # `import jaclang.runtimelib.runtime` would then fail to bind `runtimelib` on
    # `jaclang`. The finder is consulted only after the parent package is
    # imported, and it synthesizes a forwarder module whose PEP 562 __getattr__
    # pulls the real `jaclang.jac0core.runtime` only on first attribute access --
    # so the `jac --version` / `--help` / `purge` fast paths stay cheap.
    import importlib.abc
    import importlib.machinery
    from types import ModuleType

    target = "jaclang.runtimelib.runtime"

    class _RuntimeAliasFinder(importlib.abc.MetaPathFinder, importlib.abc.Loader):
        def find_spec(
            self, name: str, path: object = None, target_mod: object = None
        ) -> object:
            if name != target:
                return None
            return importlib.machinery.ModuleSpec(name, self)

        def create_module(self, spec: object) -> object:
            shim = ModuleType(target)
            shim.__doc__ = "Lazy alias for jaclang.jac0core.runtime."

            def _forward(attr: str) -> object:
                import jaclang.jac0core.runtime as _runtime_mod

                return getattr(_runtime_mod, attr)

            shim.__getattr__ = _forward  # type: ignore[attr-defined]
            return shim

        def exec_module(self, module: object) -> None:
            pass

    # Append (not insert) so the JacMetaImporter's real-file lookup wins first;
    # this finder only catches the (now file-less) runtime alias.
    if not any(isinstance(f, _RuntimeAliasFinder) for f in sys.meta_path):
        sys.meta_path.append(_RuntimeAliasFinder())


_install_runtime_shim()


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
