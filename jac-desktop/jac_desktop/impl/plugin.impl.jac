"""Implementation of jac-desktop runtime plugin hooks."""

import from jac_client.plugin.src.targets.registry { ClientTarget }
import from jac_desktop.targets.pytauri_desktop_target { PyTauriDesktopTarget }

impl JacDesktopPlugin.get_client_targets -> list[ClientTarget] {
    return [PyTauriDesktopTarget()];
}
