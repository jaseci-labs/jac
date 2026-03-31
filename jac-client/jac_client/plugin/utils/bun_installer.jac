"""Bun installer utility for jac-client.

Provides functions to resolve the bun binary path, auto-installing
a project-local copy to .jac/bin/ if bun is not on the system PATH.
"""

"""Resolve the path to the bun binary.

Resolution order:
  1. System PATH (use the user's global bun if present)
  2. .jac/bin/bun (project-local, managed by jac)
  3. Auto-download to .jac/bin/ (silent, no prompt)

Returns the absolute path as a string, or None if unavailable.
"""
def get_bun -> str | None;

"""Check if bun is available (legacy entry point).

Delegates to get_bun() and ensures the resolved path is on PATH.
Returns True if bun is available, False otherwise.
"""
def ensure_bun_available -> bool;

"""Prompt user to install Bun (legacy, now auto-installs).

Kept for backward compatibility. Delegates to ensure_bun_available().
"""
def prompt_install_bun -> bool;
