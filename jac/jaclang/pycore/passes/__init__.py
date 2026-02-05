"""PyCore Passes module - Bootstrap-critical compiler passes.

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

from jaclang.pycore.passes.annex_pass import JacAnnexPass
from jaclang.pycore.passes.def_impl_match_pass import DeclImplMatchPass
from jaclang.pycore.passes.interop_analysis_pass import InteropAnalysisPass
from jaclang.pycore.passes.pyast_gen_pass import PyastGenPass
from jaclang.pycore.passes.pybc_gen_pass import PyBytecodeGenPass
from jaclang.pycore.passes.semantic_analysis_pass import SemanticAnalysisPass
from jaclang.pycore.passes.sym_tab_build_pass import SymTabBuildPass
from jaclang.pycore.passes.transform import Alert, BaseTransform, Transform
from jaclang.pycore.passes.uni_pass import UniPass

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
