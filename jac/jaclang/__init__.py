"""The Jac Programming Language.

``import jaclang`` performs only the cheap *kernel* bootstrap
(:func:`jaclang.bootstrap.bootstrap_kernel`): it registers the Jac
meta-importer and the core ``JacRuntime`` plugin. The heavier *product* tier
(built-in providers, external plugins, native acceleration) is deferred and
triggered lazily -- see :mod:`jaclang.bootstrap`.

Set ``JAC_EAGER_BOOTSTRAP=1`` to restore the legacy eager behaviour (every
provider registered at import time); this is the transition shim used by the
test suite and will be removed once callers migrate to the lazy bootstrap.
"""

import os

from jaclang.bootstrap import bootstrap_kernel, bootstrap_product

# Kernel tier: meta-importer + core JacRuntime. Must run before anything that
# imports .jac modules (including the re-exports below).
bootstrap_kernel()

# Backwards-compatible exports. These imports are cheap now -- bootstrap_kernel
# already pulled jaclang.jac0core.runtime into sys.modules.
from jaclang.jac0core.runtime import (  # noqa: E402, F401
    JacRuntime,
    JacRuntimeImpl,
    JacRuntimeInterface,
    plugin_manager,
)

# TODO: remove JAC_EAGER_BOOTSTRAP once all callers are audited against the
# lazy bootstrap. Tests that inspect plugin_manager.get_plugins() directly
# should call bootstrap_product() in their fixture instead of relying on this.
if os.environ.get("JAC_EAGER_BOOTSTRAP") == "1":
    bootstrap_product()

__all__ = ["JacRuntimeInterface", "JacRuntime", "JacRuntimeImpl", "plugin_manager"]
