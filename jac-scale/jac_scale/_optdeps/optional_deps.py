"""Helpers for guarding optional dependencies."""


def require_optional(package: str, group: str) -> None:
    """Raise a helpful error if an optional dependency is missing."""
    try:
        __import__(package)
    except (ImportError, ValueError):
        raise ImportError(
            f"'{package}' is required for this feature. "
            f"Install it with: pip install jac-scale[{group}]"
        ) from None


def is_optional_available(package: str) -> bool:
    """Check if an optional dependency is installed without raising."""
    try:
        __import__(package)
        return True
    except (ImportError, ValueError):
        return False
