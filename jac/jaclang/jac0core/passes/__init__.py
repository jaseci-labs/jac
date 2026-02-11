"""Jac0Core Passes - Bootstrap compiler passes.

This module contains the bootstrap-critical compiler passes:
- transform: Base Transform class for all passes
- uni_pass: UniPass base class for tree traversal
- sym_tab_build_pass: Symbol table construction
- pyast_gen_pass: Python AST generation (Jac -> Python)
- pybc_gen_pass: Bytecode generation
- annex_pass: Module annex loading
- def_impl_match_pass: Declaration-implementation matching
- semantic_analysis_pass: Semantic analysis
- ast_gen/: Shared AST generation utilities
"""

from jaclang.jac0core.passes.annex_pass import JacAnnexPass
from jaclang.jac0core.passes.def_impl_match_pass import DeclImplMatchPass
from jaclang.jac0core.passes.interop_analysis_pass import InteropAnalysisPass
from jaclang.jac0core.passes.pyast_gen_pass import PyastGenPass
from jaclang.jac0core.passes.pybc_gen_pass import PyBytecodeGenPass
from jaclang.jac0core.passes.semantic_analysis_pass import SemanticAnalysisPass
from jaclang.jac0core.passes.sym_tab_build_pass import SymTabBuildPass
from jaclang.jac0core.passes.transform import Alert, BaseTransform, Transform
from jaclang.jac0core.passes.uni_pass import UniPass

__all__ = [
    "Alert",
    "BaseTransform",
    "Transform",
    "UniPass",
    "SymTabBuildPass",
    "PyastGenPass",
    "PyBytecodeGenPass",
    "JacAnnexPass",
    "DeclImplMatchPass",
    "SemanticAnalysisPass",
    "InteropAnalysisPass",
]
