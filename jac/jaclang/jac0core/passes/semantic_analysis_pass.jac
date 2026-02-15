"""Jac Semantic Analysis Pass."""
import ast as ast3;
import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.passes.uni_pass { UniPass }
"""Jac Semantic Analysis Pass."""
class SemanticAnalysisPass(UniPass) {
    def enter_archetype(self: SemanticAnalysisPass, `node: uni.Archetype) -> None;
    """Check a single archetype for issues with attributes and methods."""
    def _check_archetype(self: SemanticAnalysisPass, `node: uni.Archetype) -> None;

    def _update_ctx(self: SemanticAnalysisPass, `node: uni.UniNode) -> None;
    def enter_has_var(self: SemanticAnalysisPass, `node: uni.HasVar) -> None;
    def enter_param_var(self: SemanticAnalysisPass, `node: uni.ParamVar) -> None;
    def enter_assignment(self: SemanticAnalysisPass, `node: uni.Assignment) -> None;
    def enter_in_for_stmt(self: SemanticAnalysisPass, `node: uni.InForStmt) -> None;
    def enter_expr_as_item(self: SemanticAnalysisPass, `node: uni.ExprAsItem) -> None;
    def enter_inner_compr(self: SemanticAnalysisPass, `node: uni.InnerCompr) -> None;
    """Mark final element in trailer chain as a Store context."""
    def _change_atom_trailer_ctx(
        self: SemanticAnalysisPass, `node: uni.AtomTrailer
    ) -> None;
}
