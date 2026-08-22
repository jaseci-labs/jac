import from collections.abc { Sequence }
import from jaclang.jac0core.unitree {
    Ability,
    ArchHas,
    Archetype,
    Assignment,
    AstSymbolNode,
    AtomExpr,
    AtomTrailer,
    DisengageStmt,
    EdgeOpRef,
    EventSignature,
    ExprAsItem,
    FuncSignature,
    HasVar,
    ImplDef,
    InForStmt,
    InnerCompr,
    Name,
    ParamVar,
    SpecialVarRef,
    TypedCtxBlock,
    UniNode,
    VisitStmt
}
import from jaclang.jac0core.constant { ExprCtx }
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.passes.uni_pass { UniPass }
import from jaclang.jac0core.diagnostics { E2004, E2005, W2006, W2007, E2008, W2029 }

def inform_from_walker(nd: UniNode) -> None;

class SemanticAnalysisPass(UniPass) {
    def enter_archetype(self: SemanticAnalysisPass, nd: Archetype) -> None;
    def _check_archetype(self: SemanticAnalysisPass, nd: Archetype) -> None;
    def _property_type_names(
        self: SemanticAnalysisPass, methods: list[Ability]
    ) -> dict[str, str];

    def _update_ctx(self: SemanticAnalysisPass, nd: UniNode) -> None;
    def enter_has_var(self: SemanticAnalysisPass, nd: HasVar) -> None;
    def enter_param_var(self: SemanticAnalysisPass, nd: ParamVar) -> None;
    def enter_assignment(self: SemanticAnalysisPass, nd: Assignment) -> None;
    def enter_in_for_stmt(self: SemanticAnalysisPass, nd: InForStmt) -> None;
    def enter_expr_as_item(self: SemanticAnalysisPass, nd: ExprAsItem) -> None;
    def enter_inner_compr(self: SemanticAnalysisPass, nd: InnerCompr) -> None;
    def _change_atom_trailer_ctx(self: SemanticAnalysisPass, nd: AtomTrailer) -> None;
}
