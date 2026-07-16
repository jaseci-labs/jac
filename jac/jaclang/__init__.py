"""The Jac Programming Language."""

import importlib
import sys

from jaclang.meta_importer import JacMetaImporter  # noqa: E402

# Register JacMetaImporter BEFORE anything else, so .jac modules can be imported
if not any(isinstance(f, JacMetaImporter) for f in sys.meta_path):
    sys.meta_path.insert(0, JacMetaImporter())

__all__ = ["JacRuntimeInterface", "JacRuntime", "compiler"]


def _ensure_runtime_exports() -> None:
    """Load compiler then runtime (parser ordering) and publish legacy exports."""
    if "JacRuntime" in globals():
        return
    # Import compiler first to ensure generated parsers exist before jac0core.parser
    # is loaded. Backwards-compatible import path for older code.
    import jaclang.compiler as _compiler  # noqa: F401
    import jaclang.jac0core.runtime as _runtime_mod  # noqa: F401
    from jaclang.jac0core.runtime import (  # noqa: F401
        JacRuntime,
        JacRuntimeInterface,
    )

    sys.modules.setdefault("jaclang.runtimelib.runtime", _runtime_mod)
    globals().update(
        {
            "compiler": _compiler,
            "_runtime_mod": _runtime_mod,
            "JacRuntime": JacRuntime,
            "JacRuntimeInterface": JacRuntimeInterface,
        }
    )


def __getattr__(name: str) -> object:
    if name == "compiler":
        mod = importlib.import_module("jaclang.compiler")
        globals()["compiler"] = mod
        return mod
    if name in ("JacRuntime", "JacRuntimeInterface"):
        _ensure_runtime_exports()
        return globals()[name]
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")


# Put the current project's .jac/venv on sys.path so per-project dependencies
# (jac install [-e] <pkg>) and the on-demand feature capabilities (byllm, scale,
# ...) are importable. In the single binary this already ran via sitecustomize
# during interpreter startup; this call is the library-use fallback (plain
# `import jaclang` with no sitecustomize). The helper is idempotent and uses
# addsitedir, so editable .pth links are processed.
with __import__("contextlib").suppress(Exception):
    import _jac_finder as _jf

    _jf.add_project_venv_to_path()

# Schedule deferred native acceleration if autonative is enabled in jac.toml
try:
    from jaclang.project.config import get_config as _get_jac_config

    _jac_cfg = _get_jac_config()
    if _jac_cfg and _jac_cfg.run.autonative:
        from jaclang.jac0core.native_accel import schedule_native_acceleration

        schedule_native_acceleration()
except Exception:
    pass  # Config not available or acceleration failed — continue normally
