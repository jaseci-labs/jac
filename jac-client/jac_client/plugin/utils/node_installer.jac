"""Automatic Node.js installation utility using NVM."""

import os;
import platform;
import subprocess;
import from pathlib { Path }

"""Handles Node.js installation and detection."""
obj NodeInstaller {
    static has DEFAULT_NODE_VERSION: str = "20",
        NVM_INSTALL_URL: str = "https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh",
        DEFAULT_PNPM_VERSION: str = "10";

    """Check if Node.js is installed and accessible."""
    static def is_node_installed -> bool;

    """Check if npm is installed and accessible."""
    static def is_npm_installed -> bool;

    """Check if pnpm is installed and accessible."""
    static def is_pnpm_installed -> bool;

    """Check if NVM is installed."""
    static def is_nvm_installed -> bool;

    """Get the currently installed Node.js version."""
    static def get_node_version -> (str | None);

    """Get the currently installed pnpm version."""
    static def get_pnpm_version -> (str | None);

    """Install NVM (Node Version Manager)."""
    static def install_nvm -> tuple[bool, str];

    """Install Node.js using NVM."""
    static def install_node_via_nvm(version: str = "20") -> tuple[bool, str];

    """Install pnpm using npm."""
    static def install_pnpm_via_npm -> tuple[bool, str];

    """Ensure Node.js is installed, installing automatically if needed.

    Returns tuple of (success: bool, message: str, was_just_installed: bool)
    """
    static def ensure_node_installed(
        interactive: bool = True
    ) -> tuple[bool, str, bool];

    """Ensure pnpm is installed, installing automatically if needed.
    Returns tuple of (success: bool, message: str, was_just_installed: bool)
    """
    static def ensure_pnpm_installed(
        interactive: bool = True
    ) -> tuple[bool, str, bool];

    """Run pnpm command with NVM environment properly sourced."""
    static def run_pnpm_with_nvm(args: list, cwd: Path, timeout: int = 300) -> object;
}
