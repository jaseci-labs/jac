"""The Jac Programming Language."""

import os
import sys

from jaclang.meta_importer import JacMetaImporter

# Register JacMetaImporter BEFORE loading plugins, so .jac modules can be imported
if not any(isinstance(f, JacMetaImporter) for f in sys.meta_path):
    sys.meta_path.insert(0, JacMetaImporter())

# Import compiler first to ensure generated parsers exist before pycore.parser is loaded
# Backwards-compatible import path for older plugins/tests.
# Prefer `jaclang.pycore.runtime` going forward.
import jaclang.pycore.runtime as _runtime_mod
from jaclang import compiler as _compiler  # noqa: F401
from jaclang.pycore.runtime import (
    JacRuntime,
    JacRuntimeImpl,
    JacRuntimeInterface,
    plugin_manager,
)

sys.modules.setdefault("jaclang.runtimelib.runtime", _runtime_mod)

plugin_manager.register(JacRuntimeImpl)

# Load external plugins unless JAC_DISABLE_PLUGINS is set
# This is needed for subprocess-based tests that spawn new jac processes
if not os.environ.get("JAC_DISABLE_PLUGINS"):
    plugin_manager.load_setuptools_entrypoints("jac")

__all__ = ["JacRuntimeInterface", "JacRuntime"]
