"""Diagnostic context and bootstrap-critical analysis walkers.

Backend walkers live in compiler.backends and placement walkers in
compiler.placement. Keeping their exports separate avoids import cycles
while the seed compiler is loading.
"""

from jaclang.compiler.passes.ast_validation_pass import ASTValidationPass
from jaclang.compiler.passes.boundary_analysis_pass import BoundaryAnalysisPass
from jaclang.compiler.passes.decl_impl_match_pass import DeclImplMatchPass
from jaclang.compiler.passes.endpoint_effect_pass import EndpointEffectPass
from jaclang.compiler.passes.semantic_analysis_pass import SemanticAnalysisPass
from jaclang.compiler.passes.sym_tab_build_pass import SymTabBuildPass
from jaclang.compiler.passes.context import (
    Alert,
    CompileContext,
    DiagnosticPolicy,
)

__all__ = [
    "Alert",
    "CompileContext",
    "ASTValidationPass",
    "BoundaryAnalysisPass",
    "DeclImplMatchPass",
    "DiagnosticPolicy",
    "EndpointEffectPass",
    "SemanticAnalysisPass",
    "SymTabBuildPass",
]
