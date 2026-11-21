"""ECMAScript AST and code generation, loaded when requested."""

import importlib
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from jaclang.compiler.backends.es.esast_gen_pass import EsastGenPass
    from jaclang.compiler.backends.es.estree import (
        Declaration,
        Expression,
        Pattern,
        Program,
        Statement,
        es_node_to_dict,
    )

_LAZY_EXPORTS = {
    "EsastGenPass": "jaclang.compiler.backends.es.esast_gen_pass",
    "Declaration": "jaclang.compiler.backends.es.estree",
    "Expression": "jaclang.compiler.backends.es.estree",
    "Pattern": "jaclang.compiler.backends.es.estree",
    "Program": "jaclang.compiler.backends.es.estree",
    "Statement": "jaclang.compiler.backends.es.estree",
    "es_node_to_dict": "jaclang.compiler.backends.es.estree",
}


def __getattr__(name: str) -> object:
    module = _LAZY_EXPORTS.get(name)
    if module is None:
        raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
    value = getattr(importlib.import_module(module), name)
    globals()[name] = value
    return value


__all__ = list(_LAZY_EXPORTS)
