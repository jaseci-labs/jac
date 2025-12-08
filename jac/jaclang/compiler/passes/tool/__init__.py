"""Collection of tool passes for Jac IR.

This module uses lazy imports to enable converting passes to Jac.
All tool passes are loaded lazily via __getattr__ since they're only
used after the main compilation completes.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

# Passes that are imported lazily to allow .jac conversion
_LAZY_PASSES = {
    "CommentInjectionPass": ".comment_injection_pass",
    "DocIRGenPass": ".doc_ir_gen_pass",
    "JacFormatPass": ".jac_formatter_pass",
}

# Cache for lazily loaded passes
_lazy_cache: dict[str, type] = {}

if TYPE_CHECKING:
    from .comment_injection_pass import CommentInjectionPass as CommentInjectionPass
    from .doc_ir_gen_pass import DocIRGenPass as DocIRGenPass
    from .jac_formatter_pass import JacFormatPass as JacFormatPass


def __getattr__(name: str) -> type:
    """Lazily load passes on first access."""
    if name in _lazy_cache:
        return _lazy_cache[name]

    if name in _LAZY_PASSES:
        import importlib

        module_name = _LAZY_PASSES[name]
        module = importlib.import_module(module_name, package=__name__)
        cls = getattr(module, name)
        _lazy_cache[name] = cls
        return cls

    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")


__all__ = [
    "CommentInjectionPass",
    "DocIRGenPass",
    "JacFormatPass",
]
