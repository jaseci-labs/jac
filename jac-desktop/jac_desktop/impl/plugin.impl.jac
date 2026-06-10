"""Implementation of jac-desktop runtime plugin hooks."""

import from jac_client.plugin.src.targets.registry { ClientTarget }
import from jac_desktop.targets.native_desktop_target { NativeDesktopTarget }
import from jac_desktop.targets.cef_desktop_target { CefDesktopTarget }

impl JacDesktopPlugin.get_client_targets -> list[ClientTarget] {
    # Always register both targets. The CLI selects based on engine config,
    # but both are available for discovery. The native target remains the
    # default; the CEF target activates when engine = "cef" in jac.toml.
    return [NativeDesktopTarget(), CefDesktopTarget()];
}
