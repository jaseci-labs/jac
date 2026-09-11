import from collections.abc { Sequence }
import from jaclang.compiler.ir.schema {
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
import from jaclang.compiler.ir.enums { ExprCtx }
import from jaclang.compiler.ir.enums { Tokens as Tok }
import from jaclang.compiler.pipeline.uni_pass { UniPass }
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
    can enter_archetype with Archetype entry;
    def _check_archetype(nd: Archetype) -> None;
    def _property_type_names(methods: list[Ability]) -> dict[str, str];
    def _update_ctx(nd: UniNode) -> None;
    can enter_has_var with HasVar entry;
    can enter_param_var with ParamVar entry;
    can enter_assignment with Assignment entry;
    can enter_in_for_stmt with InForStmt entry;
    can enter_expr_as_item with ExprAsItem entry;
    can enter_inner_compr with InnerCompr entry;
    def _change_atom_trailer_ctx(nd: AtomTrailer) -> None;
}
