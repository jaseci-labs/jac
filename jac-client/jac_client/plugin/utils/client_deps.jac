"""Client dependency checker utility for jac-client.

Provides a function to check if required npm dependencies are configured
and prompt the user to install defaults if missing.
"""

"""Check if client npm dependencies are configured, prompt to install if missing.

Takes a JacClientConfig instance, checks if dependencies and devDependencies
are both empty, and if so prompts the user to install default jac-client deps.

Returns True if deps are configured (or were just installed), False if user declined.
"""
def ensure_client_deps(config_loader: object) -> bool;
