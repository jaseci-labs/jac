"""The Jac Programming Language."""

import sys

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


# Activate the Python-level hijack: registers .jac as a first-class source
# suffix in importlib.machinery.SOURCE_SUFFIXES and installs a lightweight
# path-level loader. Makes every importlib-based tool (PyInstaller's
# analyzer, setuptools, Nuitka, IDE indexers) discover Jac packages with
# no per-tool adapters. Kept at the BOTTOM of this file so that line
# numbers of the public re-export block (used by langserver go-to-def
# tests) match main. install() is idempotent; if jaclang.pth already
# fired at interpreter startup, this is a no-op.
import _jac_finder  # noqa: E402

_jac_finder.install()
