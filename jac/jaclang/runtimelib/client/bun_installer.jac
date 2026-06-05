"""Bun installer utility for jac-client.

Provides functions to resolve the bun binary path, auto-installing
a project-local copy to .jac/bin/ if bun is not on the system PATH.
"""

# Canonical pinned bun version. Single source of truth across the project
# (also reused by deployment targets that pre-install bun in container images).
# Bump this when a new bun release is validated.
glob BUN_VERSION = "1.3.11";

"""Resolve the path to the bun binary, auto-installing if needed.

Resolution order:
  1. System PATH (use the user's global bun if present)
  2. .jac/bin/bun (project-local, managed by jac)
  3. Auto-download to .jac/bin/ (silent, no prompt)

On success the resolved directory is prepended to PATH.
Returns the absolute path as a string, or None if unavailable.
"""
def get_bun -> str | None;
