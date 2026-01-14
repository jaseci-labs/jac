"""The Jac Programming Language."""

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
from jaclang.pycore.helpers import get_disabled_plugins, load_plugins_with_disabling
from jaclang.pycore.runtime import (
    JacRuntime,
    JacRuntimeImpl,
    JacRuntimeInterface,
    plugin_manager,
)

sys.modules.setdefault("jaclang.runtimelib.runtime", _runtime_mod)

plugin_manager.register(JacRuntimeImpl)

# Load external plugins with disabling support
# Disabling can be configured via JAC_DISABLED_PLUGINS env var or jac.toml [plugins].disabled
# Use "*" to disable all external plugins, "package:*" for all from a package,
# or "package:plugin" for specific plugins
_disabled_list = get_disabled_plugins()
if _disabled_list:
    # Use qualified blocking for fine-grained control
    load_plugins_with_disabling(plugin_manager, _disabled_list)
else:
    # No disabling - load all plugins normally
    plugin_manager.load_setuptools_entrypoints("jac")

__all__ = ["JacRuntimeInterface", "JacRuntime"]
