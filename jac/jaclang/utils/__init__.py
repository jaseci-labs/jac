import importlib


def __getattr__(name: str) -> object:
    """Lazy load .jac modules."""
    if name == "NonGPT":
        return importlib.import_module("jaclang.utils.NonGPT")
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
