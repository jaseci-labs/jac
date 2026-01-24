"""Bun installer utility for jac-client.

Provides functions to check for Bun availability and prompt for installation.
"""

"""Check if bun is available, add to PATH if needed, or prompt to install.

Returns True if bun is available (or was successfully installed), False otherwise.
"""
def ensure_bun_available -> bool;

"""Prompt user to install Bun and install if confirmed.

Returns True if installation succeeded, False otherwise.
"""
def prompt_install_bun -> bool;
