"""Implementation of jac-desktop runtime plugin hooks."""

import from jac_client.plugin.src.targets.registry { ClientTarget }
import from jac_desktop.targets.native_desktop_target { NativeDesktopTarget }

impl JacDesktopPlugin.get_client_targets -> list[ClientTarget] {
    return [NativeDesktopTarget()];
}
