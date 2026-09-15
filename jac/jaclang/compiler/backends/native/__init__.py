"""Native compilation passes, loaded when requested."""

import importlib
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from jaclang.compiler.backends.native.na_compile_pass import NativeCompilePass
    from jaclang.compiler.backends.native.na_ir_gen_pass import NaIRGenPass

_LAZY_EXPORTS = {
    "NativeCompilePass": "jaclang.compiler.backends.native.na_compile_pass",
    "NaIRGenPass": "jaclang.compiler.backends.native.na_ir_gen_pass",
}


def __getattr__(name: str) -> object:
    module = _LAZY_EXPORTS.get(name)
    if module is None:
        raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
    value = getattr(importlib.import_module(module), name)
    globals()[name] = value
    return value


__all__ = list(_LAZY_EXPORTS)
