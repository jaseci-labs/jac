"""Implementation of jac-desktop runtime plugin hooks."""

impl JacDesktopPlugin.get_client_targets -> list[object] {
    import from jac_desktop.targets.pytauri_desktop_target { PyTauriDesktopTarget }
    return [PyTauriDesktopTarget()];
}
