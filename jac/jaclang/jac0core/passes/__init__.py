"""Jac0Core Passes - Bootstrap compiler passes.

This module contains the bootstrap-critical compiler passes:
- transform: Base Transform class for all passes
- uni_pass: UniPass base class for tree traversal
- sym_tab_build_pass: Symbol table construction
- jcir_gen_pass: Compact codegen IR emission (Jac -> JCIR)
- jcir_bc_gen_pass: Code object transcription (JCIR -> CPython bytecode)
- annex_pass: Module annex loading
- decl_impl_match_pass: Declaration-implementation matching
- semantic_analysis_pass: Semantic analysis
- ast_gen/: Shared AST generation utilities
"""

from jaclang.jac0core.passes.annex_pass import JacAnnexPass
from jaclang.jac0core.passes.ast_validation_pass import ASTValidationPass
from jaclang.jac0core.passes.boundary_analysis_pass import BoundaryAnalysisPass
from jaclang.jac0core.passes.decl_impl_match_pass import DeclImplMatchPass
from jaclang.jac0core.passes.endpoint_effect_pass import EndpointEffectPass
from jaclang.jac0core.passes.jcir_bc_gen_pass import JcirBytecodeGenPass
from jaclang.jac0core.passes.jcir_gen_pass import JcirGenPass
from jaclang.jac0core.passes.module_codegen_pass import ModuleCodegenPass
from jaclang.jac0core.passes.semantic_analysis_pass import SemanticAnalysisPass
from jaclang.jac0core.passes.sym_tab_build_pass import SymTabBuildPass
from jaclang.jac0core.passes.transform import (
    Alert,
    BaseTransform,
    DiagnosticPolicy,
    Transform,
)
from jaclang.jac0core.passes.uni_pass import UniPass
from jaclang.jac0core.placement_solver import PlacementApplyPass

__all__ = [
    "Alert",
    "ASTValidationPass",
    "BaseTransform",
    "DiagnosticPolicy",
    "Transform",
    "UniPass",
    "SymTabBuildPass",
    "JcirGenPass",
    "JcirBytecodeGenPass",
    "JacAnnexPass",
    "DeclImplMatchPass",
    "SemanticAnalysisPass",
    "BoundaryAnalysisPass",
    "PlacementApplyPass",
    "EndpointEffectPass",
    "ModuleCodegenPass",
]
