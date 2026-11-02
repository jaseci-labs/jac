import from collections.abc { Sequence }


def inform_from_walker(nd: UniNode) -> None;

walker SemanticAnalysisPass(TreePass) {
    static has contract: PassContract = PassContract(kernel_safe=True);

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
