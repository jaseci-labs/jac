"""Collection of passes for Jac IR.

This module uses lazy imports to enable converting passes to Jac.
Bootstrap-critical passes are loaded eagerly, while analysis passes
that can be deferred are loaded lazily via __getattr__.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

# Bootstrap-critical passes (must remain Python for now)
from ..transform import Alert, BaseTransform, Transform
from .pyast_gen_pass import PyastGenPass
from .pyast_load_pass import PyastBuildPass  # type: ignore
from .pybc_gen_pass import PyBytecodeGenPass
from .sym_tab_build_pass import SymTabBuildPass, UniPass

# Passes that are imported lazily to allow .jac conversion
# These are loaded on first access via __getattr__
_LAZY_PASSES = {
    "JacAnnexPass": ".annex_pass",
    "CFGBuildPass": ".cfg_build_pass",
    "DeclImplMatchPass": ".def_impl_match_pass",
    "JacImportDepsPass": ".import_pass",
    "PyJacAstLinkPass": ".pyjac_ast_link_pass",
    "SemDefMatchPass": ".sem_def_match_pass",
    "SemanticAnalysisPass": ".semantic_analysis_pass",
    "TypeCheckPass": ".type_checker_pass",
    "DefUsePass": ".def_use_pass",
}

# Cache for lazily loaded passes
_lazy_cache: dict[str, type] = {}

if TYPE_CHECKING:
    from .annex_pass import JacAnnexPass as JacAnnexPass
    from .cfg_build_pass import CFGBuildPass as CFGBuildPass
    from .def_impl_match_pass import DeclImplMatchPass as DeclImplMatchPass
    from .def_use_pass import DefUsePass as DefUsePass
    from .import_pass import JacImportDepsPass as JacImportDepsPass
    from .pyjac_ast_link_pass import PyJacAstLinkPass as PyJacAstLinkPass
    from .sem_def_match_pass import SemDefMatchPass as SemDefMatchPass
    from .semantic_analysis_pass import SemanticAnalysisPass as SemanticAnalysisPass
    from .type_checker_pass import TypeCheckPass as TypeCheckPass


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
    "Alert",
    "BaseTransform",
    "Transform",
    "UniPass",
    "JacAnnexPass",
    "JacImportDepsPass",
    "TypeCheckPass",
    "SymTabBuildPass",
    "SemanticAnalysisPass",
    "DeclImplMatchPass",
    "SemDefMatchPass",
    "PyastBuildPass",
    "PyastGenPass",
    "PyBytecodeGenPass",
    "CFGBuildPass",
    "PyJacAstLinkPass",
    "DefUsePass",
]
