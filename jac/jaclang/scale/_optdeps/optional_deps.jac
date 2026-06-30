"""Helpers for guarding optional dependencies."""

import from jaclang.project.capabilities { missing_capability_error }

"""Raise a capability-oriented error if an optional dependency is missing.

`capability` is a capability name from the core registry (e.g. "data.mongo",
"deploy.k8s"); the actionable install guidance is sourced from there, so the
dependency taxonomy lives in exactly one place instead of being duplicated as
per-shim extras strings.
"""
def require_optional(package: str, capability: str) {
    try {
        __import__(package);
    } except (ImportError, ValueError) {
        raise ImportError(
            f"'{package}' is required for this feature. "
            f"{missing_capability_error(capability)}"
        );
    }
}

"""Check if an optional dependency is installed without raising."""
def is_optional_available(package: str) -> bool {
    try {
        __import__(package);
        return True;
    } except (ImportError, ValueError) {
        return False;
    }
}
