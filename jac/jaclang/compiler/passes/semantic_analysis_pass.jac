import from collections.abc { Sequence }
import from jaclang.compiler.frontend.unitree {
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
    Module,
    Name,
    ParamVar,
    SpecialVarRef,
    TypedCtxBlock,
    UniNode,
    VisitStmt
}
import from jaclang.compiler.frontend.constant { ExprCtx }
import from jaclang.compiler.frontend.constant { Tokens as Tok }
import from jaclang.compiler.passes.uni_pass { UniPass }
import from jaclang.compiler.frontend.diagnostics {
    E2004,
    E2005,
    W2006,
    W2007,
    E2008,
    W2029
}

def inform_from_walker(nd: UniNode) -> None;

walker SemanticAnalysisPass(UniPass) {
    def transform(ir_in: Module) -> Module;
    can enter_archetype with Archetype entry;
    def _analyze_archetype(nd: Archetype) -> None;
    def _check_archetype(nd: Archetype) -> None;
    def _property_type_names(methods: list[Ability]) -> dict[str, str];
    def _update_ctx(nd: UniNode) -> None;
    can enter_has_var with HasVar entry;
    def _analyze_has_var(nd: HasVar) -> None;
    can enter_param_var with ParamVar entry;
    def _analyze_param_var(nd: ParamVar) -> None;
    can enter_assignment with Assignment entry;
    def _analyze_assignment(nd: Assignment) -> None;
    can enter_in_for_stmt with InForStmt entry;
    def _analyze_in_for_stmt(nd: InForStmt) -> None;
    can enter_expr_as_item with ExprAsItem entry;
    def _analyze_expr_as_item(nd: ExprAsItem) -> None;
    can enter_inner_compr with InnerCompr entry;
    def _analyze_inner_compr(nd: InnerCompr) -> None;
    def _change_atom_trailer_ctx(nd: AtomTrailer) -> None;
}
