"""The Jac Programming Language."""

import os
import sys

# Add vendor dir to sys.path early for lsprotocol/pygls imports.
_vendor_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "vendor")
if _vendor_dir not in sys.path:
    sys.path.insert(0, _vendor_dir)

from jaclang.meta_importer import JacMetaImporter  # noqa: E402

# Register JacMetaImporter BEFORE loading plugins, so .jac modules can be imported
if not any(isinstance(f, JacMetaImporter) for f in sys.meta_path):
    sys.meta_path.insert(0, JacMetaImporter())

# Import compiler first to ensure generated parsers exist before jac0core.parser is loaded
# Backwards-compatible import path for older plugins/tests.
# Prefer `jaclang.jac0core.runtime` going forward.
import jaclang.jac0core.runtime as _runtime_mod  # noqa: E402
from jaclang import compiler as _compiler  # noqa: E402, F401
from jaclang.jac0core.helpers import (  # noqa: E402
    get_disabled_plugins,
    load_plugins_with_disabling,
)
from jaclang.jac0core.runtime import (  # noqa: E402
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
