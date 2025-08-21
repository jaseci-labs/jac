"""The Jac Programming Language."""

import sys

from jaclang.runtimelib.machine import (
    JacMachine,
    JacMachineImpl,
    JacMachineInterface,
    plugin_manager,
)
from jaclang.runtimelib.meta_importer import JacMetaImporter


plugin_manager.register(JacMachineImpl)
plugin_manager.load_setuptools_entrypoints("jac")

if not any(isinstance(f, JacMetaImporter) for f in sys.meta_path):
    sys.meta_path.insert(0, JacMetaImporter())

__all__ = ["JacMachineInterface", "JacMachine"]
