"""The Jac Programming Language."""

import sys

from jaclang.meta_importer import JacMetaImporter  # noqa: E402

# Register JacMetaImporter BEFORE anything else, so .jac modules can be imported
if not any(isinstance(f, JacMetaImporter) for f in sys.meta_path):
    sys.meta_path.insert(0, JacMetaImporter())

# Import compiler first to ensure generated parsers exist before jac0core.parser is loaded
# Backwards-compatible import path for older code.
# Prefer `jaclang.jac0core.runtime` going forward.
import jaclang.jac0core.runtime as _runtime_mod  # noqa: E402
from jaclang import compiler as _compiler  # noqa: E402, F401
from jaclang.jac0core.runtime import (  # noqa: E402
    JacRuntime,
    JacRuntimeInterface,
)

sys.modules.setdefault("jaclang.runtimelib.runtime", _runtime_mod)

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

__all__ = ["JacRuntimeInterface", "JacRuntime"]
