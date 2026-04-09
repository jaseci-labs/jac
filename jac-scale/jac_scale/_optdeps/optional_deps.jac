"""Helpers for guarding optional dependencies."""

"""Raise a helpful error if an optional dependency is missing."""
def require_optional(package: str, group: str) {
    try {
        __import__(package);
    } except (ImportError, ValueError) {
        raise ImportError(
            f"'{package}' is required for this feature. "
            f"Install it with: pip install jac-scale[{group}]"
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
