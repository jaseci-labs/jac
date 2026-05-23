"""jac-desktop runtime plugin — registers the PyTauri desktop client target."""

import from jaclang.jac0core.runtime { hookimpl, plugin_manager }


"""Runtime hooks for jac-desktop (client target contribution)."""
class JacDesktopPlugin {
    """Contribute the PyTauri desktop build target to jac-client."""
    @hookimpl
    static def get_client_targets -> list[object];
}

with entry {
    plugin_manager.register(JacDesktopPlugin());
}
