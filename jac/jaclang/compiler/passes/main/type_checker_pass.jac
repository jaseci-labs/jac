import from jaclang.jac0core.unitree {
    Ability,
    ArchHas,
    Archetype,
    AssertStmt,
    Assignment,
    AstSymbolNode,
    AtomTrailer,
    BinaryExpr,
    BuiltinType,
    CodeBlockStmt,
    CompareExpr,
    DeleteStmt,
    EdgeRefTrailer,
    Enum,
    EventSignature,
    Expr,
    ExprAsItem,
    FilterCompr,
    FormattedValue,
    FuncCall,
    FuncSignature,
    HasVar,
    ImplDef,
    Import,
    InForStmt,
    IndexSlice,
    JsxElement,
    JsxElementName,
    KWPair,
    LambdaExpr,
    ListVal,
    Module,
    ModuleCode,
    ModuleItem,
    ModulePath,
    Name,
    Null,
    ParamVar,
    RaiseStmt,
    ReportStmt,
    ReturnStmt,
    Slice,
    SpecialVarRef,
    SubTag,
    Token,
    TupleVal,
    TypeAlias,
    UniNode,
    VisitStmt,
    WhileStmt,
    WithStmt,
    YieldExpr
}
import from jaclang.jac0core.passes.uni_pass { UniPass }
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.compiler.type_system.types {
    AnyType,
    ClassType,
    TypeBase,
    TypeVarType,
    UnionType,
    UnknownType
}
import from jaclang.compiler.type_system.type_utils {
    PropertyWriteKind,
    get_declared_generator_return_type,
    get_generator_yield_type,
    is_generator_family_type
}
import from jaclang.compiler.type_system.operations {
    ARITHMETIC_OPERATORS,
    AUG_OPERATOR_MAP,
    AUG_TO_BINARY_MAP,
    BINARY_OPERATOR_MAP,
    get_numeric_promotion_type,
    get_pow_result_type
}
import from jaclang.compiler.jsx_component { is_jsx_runtime_helper, return_type_is_jsx }
import from jaclang.jac0core.diagnostics {
    Category,
    DiagnosticInfo,
    E1001,
    E1002,
    E1003,
    E1004,
    E1005,
    E1010,
    E1011,
    E1020,
    E1021,
    E1022,
    E1042,
    E1060,
    E1061,
    E1090,
    E1091,
    E1092,
    E1093,
    E1094,
    E1095,
    E1106,
    E1107,
    E1108,
    E1109,
    E1112,
    E1113,
    E1116,
    E1117,
    E1119,
    E1124,
    E5095,
    W1036,
    W1037,
    W1052,
    W2014,
    W6008,
    E2015
}


class TypeCheckPass(UniPass) {
    has _lambda_depth: int = 0;
    static has PROVIDES: tuple = ('inference', ),
        inference_only: bool = False;

    def before_pass(self: TypeCheckPass) -> None;
    def after_pass(self: TypeCheckPass) -> None;
    def emit(
        self: TypeCheckPass,
        diag: DiagnosticInfo,
        node_override: (UniNode | None) = None,
        related: (list[tuple[str, UniNode]] | None) = None,
        help_text: (str | None) = None,
        **kwargs: any
    ) -> bool;

    def _insert_builtin_symbols(self: TypeCheckPass) -> None;
    def enter_ability(self: TypeCheckPass, nd: Ability) -> None;
    def exit_ability(self: TypeCheckPass, nd: Ability) -> None;
    def enter_lambda_expr(self: TypeCheckPass, nd: LambdaExpr) -> None;
    def exit_lambda_expr(self: TypeCheckPass, nd: LambdaExpr) -> None;
    def exit_type_alias(self: TypeCheckPass, nd: TypeAlias) -> None;
    def exit_archetype(self: TypeCheckPass, nd: Archetype) -> None;
    def exit_enum(self: TypeCheckPass, nd: Enum) -> None;
    def exit_import(self: TypeCheckPass, nd: Import) -> None;
    def exit_assignment(self: TypeCheckPass, nd: Assignment) -> None;
    def exit_atom_trailer(self: TypeCheckPass, nd: AtomTrailer) -> None;
    def exit_binary_expr(self: TypeCheckPass, nd: BinaryExpr) -> None;
    def exit_compare_expr(self: TypeCheckPass, nd: CompareExpr) -> None;
    def _diag_erased_membership(
        self: TypeCheckPass, nd: CompareExpr, hay: Expr, op_text: str
    ) -> None;

    def exit_func_call(self: TypeCheckPass, nd: FuncCall) -> None;
    def _check_intrinsic_call(self: TypeCheckPass, nd: FuncCall) -> None;
    def _check_intrinsic_collision(self: TypeCheckPass, nd: Ability) -> None;
    def exit_jsx_element(self: TypeCheckPass, nd: JsxElement) -> None;
    def exit_filter_compr(self: TypeCheckPass, nd: FilterCompr) -> None;
    def exit_return_stmt(self: TypeCheckPass, nd: ReturnStmt) -> None;
    def exit_formatted_value(self: TypeCheckPass, nd: FormattedValue) -> None;
    def exit_edge_ref_trailer(self: TypeCheckPass, nd: EdgeRefTrailer) -> None;
    def exit_special_var_ref(self: TypeCheckPass, nd: SpecialVarRef) -> None;
    def exit_name(self: TypeCheckPass, nd: Name) -> None;
    def exit_param_var(self: TypeCheckPass, nd: ParamVar) -> None;
    def exit_has_var(self: TypeCheckPass, nd: HasVar) -> None;
    def exit_in_for_stmt(self: TypeCheckPass, nd: InForStmt) -> None;
    def exit_raise_stmt(self: TypeCheckPass, nd: RaiseStmt) -> None;
    def enter_with_stmt(self: TypeCheckPass, nd: WithStmt) -> None;
    def exit_with_stmt(self: TypeCheckPass, nd: WithStmt) -> None;
    def exit_while_stmt(self: TypeCheckPass, nd: WhileStmt) -> None;
    def exit_assert_stmt(self: TypeCheckPass, nd: AssertStmt) -> None;
    def exit_yield_expr(self: TypeCheckPass, nd: YieldExpr) -> None;
    def exit_delete_stmt(self: TypeCheckPass, nd: DeleteStmt) -> None;
    def exit_visit_stmt(self: TypeCheckPass, nd: VisitStmt) -> None;
    def exit_report_stmt(self: TypeCheckPass, nd: ReportStmt) -> None;
    def exit_impl_def(self: TypeCheckPass, nd: ImplDef) -> None;
    def exit_sub_tag(self: TypeCheckPass, nd: SubTag) -> None;
    def _eval_unpacking_names(self: TypeCheckPass, container: Expr) -> None;
    def _body_always_returns(self: TypeCheckPass, body: list[CodeBlockStmt]) -> bool;
    def _check_bare_generic(
        self: TypeCheckPass, ann_node: UniNode, ty: object
    ) -> None;

    def _check_explicit_any(self: TypeCheckPass, ann_node: UniNode) -> None;
    def _check_walker_reports_shape(
        self: TypeCheckPass, nd: HasVar, declared_type: object
    ) -> None;

    def _enclosing_walker_report_elem_type(self: TypeCheckPass, nd: UniNode) -> object;
    def _jsx_component_params(
        self: TypeCheckPass, nd: Ability
    ) -> (list[ParamVar] | None);

    def _check_props_bundle_is_exclusive(
        self: TypeCheckPass, nd: Ability, comp_params: list[ParamVar]
    ) -> None;

    def _check_pages_entry_renders_children(self: TypeCheckPass, nd: Ability) -> None;
    def _check_event_trigger_archetype(self: TypeCheckPass, nd: Ability) -> None;
    def _check_unresolved_lambda_params(self: TypeCheckPass) -> None;
}

class TypeInferencePass(TypeCheckPass) {
    static has inference_only: bool = True;
}
