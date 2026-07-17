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
    import jaclang.jac0core.runtime as _runtime_mod
    from jaclang.jac0core.runtime import JacRuntime, JacRuntimeInterface

    # Backwards-compatible import path for older code that imports
    # `jaclang.runtimelib.runtime` (no real module lives there).
    sys.modules.setdefault("jaclang.runtimelib.runtime", _runtime_mod)
    globals().update(
        {
            "JacRuntime": JacRuntime,
            "JacRuntimeInterface": JacRuntimeInterface,
        }
    )

    # Schedule deferred native acceleration if autonative is enabled in jac.toml.
    # Coupled to the runtime (it accelerates runtime hot loops), so it runs once
    # the runtime is available; fast paths that never load the runtime
    # (jac --version / --help / purge) skip it entirely.
    try:
        from jaclang.project.config import get_config as _get_jac_config

        _jac_cfg = _get_jac_config()
        if _jac_cfg and _jac_cfg.run.autonative:
            from jaclang.jac0core.native_accel import schedule_native_acceleration

            schedule_native_acceleration()
    except Exception:
        pass  # Config not available or acceleration failed — continue normally


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
