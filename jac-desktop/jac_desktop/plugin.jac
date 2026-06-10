"""jac-desktop runtime plugin - registers the Jac-native desktop client target."""

import from jac_client.plugin.client_plugin { client_hookimpl }
import from jac_client.plugin.src.targets.registry { ClientTarget }


"""Runtime hooks for jac-desktop (client target contribution)."""
class JacDesktopPlugin {
    """Contribute the Jac-native desktop build target to jac-client."""
    @client_hookimpl
    static def get_client_targets -> (list[ClientTarget] | ClientTarget);
}
