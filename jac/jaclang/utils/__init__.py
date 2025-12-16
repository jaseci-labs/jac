"""Jaseci utility functions and libraries."""

import importlib

# lang_tools.py remains here as it's a high-level tool with many dependencies
# NonGPT.jac and symtable_test_helpers.jac remain here as well


def __getattr__(name: str) -> object:
    """Lazy load .jac modules."""
    if name == "NonGPT":
        # Import the NonGPT module (which is a .jac file)
        return importlib.import_module("jaclang.utils.NonGPT")
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
