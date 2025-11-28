"""The Jac Programming Language."""

import sys

from jaclang.runtimelib.meta_importer import JacMetaImporter
from jaclang.runtimelib.runtime import (
    JacRuntime,
    JacRuntimeImpl,
    JacRuntimeInterface,
    plugin_manager,
)

plugin_manager.register(JacRuntimeImpl)
plugin_manager.load_setuptools_entrypoints("jac")

if not any(isinstance(f, JacMetaImporter) for f in sys.meta_path):
    sys.meta_path.insert(0, JacMetaImporter())

__all__ = ["JacRuntimeInterface", "JacRuntime"]
