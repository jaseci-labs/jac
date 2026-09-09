"""Compiler pass bases and the seed-tier analysis passes.

The classes exported here are the pass infrastructure (Transform/UniPass
bases, diagnostics values) plus the bootstrap-critical analysis passes
the jac0 tier compiles. Codegen passes and their shared bases live in
jaclang.compiler.backends (common/, py/, es/, native/) and placement in
jaclang.compiler.placement; re-exporting them here would make this
package's init cyclic with the backends, which import pass bases from
this package's modules.
"""

from jaclang.compiler.passes.ast_validation_pass import ASTValidationPass
from jaclang.compiler.passes.boundary_analysis_pass import BoundaryAnalysisPass
from jaclang.compiler.passes.decl_impl_match_pass import DeclImplMatchPass
from jaclang.compiler.passes.endpoint_effect_pass import EndpointEffectPass
from jaclang.compiler.passes.semantic_analysis_pass import SemanticAnalysisPass
from jaclang.compiler.passes.sym_tab_build_pass import SymTabBuildPass
from jaclang.compiler.passes.transform import (
    Alert,
    BaseTransform,
    DiagnosticPolicy,
    Transform,
)
from jaclang.compiler.passes.uni_pass import UniPass

__all__ = [
    "Alert",
    "ASTValidationPass",
    "BaseTransform",
    "BoundaryAnalysisPass",
    "DeclImplMatchPass",
    "DiagnosticPolicy",
    "EndpointEffectPass",
    "SemanticAnalysisPass",
    "SymTabBuildPass",
    "Transform",
    "UniPass",
]
