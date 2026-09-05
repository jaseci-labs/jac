import from jaclang.compiler.frontend.unitree {
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
    FString,
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
    Literal,
    Module,
    ModuleCode,
    ModuleItem,
    ModulePath,
    MultiString,
    Name,
    Null,
    ParamVar,
    RaiseStmt,
    ReportStmt,
    ReturnStmt,
    Slice,
    SpecialVarRef,
    Symbol,
    SubTag,
    Token,
    UnaryExpr,
    TupleVal,
    TypeAlias,
    UniNode,
    VisitStmt,
    in_type_position,
    type_only_import_of,
    IfStmt,
    ElseIf,
    WhileStmt,
    WithStmt,
    YieldExpr
}
import from jaclang.compiler.passes.uni_pass { UniPass }
import from jaclang.compiler.jsx_component { is_jsx_runtime_helper, return_type_is_jsx }
import from jaclang.compiler.frontend.constant { Tokens as Tok }
import from jaclang.compiler.frontend.diagnostics { E0033, E0108, E0109 }
import from jaclang.compiler.types.ct_value { CT_DEFERRED, CtValue }
import from jaclang.compiler.types.types {
    AnyType,
    ClassType,
    FunctionType,
    ModuleType,
    TypeBase,
    TypeVarType,
    UnionType,
    UnknownType
}
import from jaclang.compiler.types.type_utils {
    PropertyWriteKind,
    get_declared_generator_return_type,
    get_generator_yield_type,
    is_generator_family_type
}
import from jaclang.compiler.types.operations {
    ARITHMETIC_OPERATORS,
    AUG_OPERATOR_MAP,
    AUG_TO_BINARY_MAP,
    BINARY_OPERATOR_MAP,
    BITWISE_OPERATORS,
    SHIFT_OPERATORS,
    get_numeric_promotion_type,
    get_pow_result_type
}
import type from jaclang.compiler.types.type_evaluator { TypeEvaluator }
import type from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.diagnostics {
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
    E1132,
    E5095,
    E1133,
    W1036,
    W1037,
    W1052,
    W2014,
    W6008,
    E2015
}


glob FW_INTERVAL_OPS: dict[str, str] = {
         "PLUS": "+",
         "MINUS": "-",
         "STAR_MUL": "*"
     };

walker TypeCheckPass(UniPass) {
    has prog: JacProgram,
        evaluator: TypeEvaluator postinit,
        _lambda_depth: int = 0,
        _prev_eval_pass: any = None,
        _prev_ct_quiet: bool = False;

    def postinit -> None;

    static has PROVIDES: tuple = ('TypeOf', ),
        HOST_PASS: bool = True;

    def init(prog: JacProgram, **kwargs: any) -> None;
    def before_pass -> None;
    def after_pass -> None;
    def _stamp_fixed_width -> None;
    def _provably_in_range(nd: Expr, name: str) -> bool;
    def _insert_builtin_symbols -> None;
    def _install_client_state_setters -> None;
    def _client_state_field_owner(nd: HasVar) -> (Ability | None);
    can enter_ability with Ability entry;
    can exit_ability with Ability exit;
    can enter_lambda_expr with LambdaExpr entry;
    can exit_lambda_expr with LambdaExpr exit;
    can exit_type_alias with TypeAlias exit;
    can exit_archetype with Archetype exit;
    can exit_enum with Enum exit;
    can exit_import with Import exit;
    can exit_assignment with Assignment exit;
    can exit_atom_trailer with AtomTrailer exit;
    can exit_binary_expr with BinaryExpr exit;
    can exit_compare_expr with CompareExpr exit;
    def _diag_erased_membership(nd: CompareExpr, hay: Expr, op_text: str) -> None;
    can exit_func_call with FuncCall exit;
    def _check_intrinsic_call(nd: FuncCall) -> None;
    def _check_intrinsic_collision(nd: Ability) -> None;
    can exit_jsx_element with JsxElement exit;
    can exit_filter_compr with FilterCompr exit;
    can exit_return_stmt with ReturnStmt exit;
    can exit_formatted_value with FormattedValue exit;
    can exit_edge_ref_trailer with EdgeRefTrailer exit;
    can exit_special_var_ref with SpecialVarRef exit;
    can exit_name with Name exit;
    can exit_param_var with ParamVar exit;
    can exit_has_var with HasVar exit;
    can exit_in_for_stmt with InForStmt exit;
    can exit_raise_stmt with RaiseStmt exit;
    can enter_with_stmt with WithStmt entry;
    can exit_with_stmt with WithStmt exit;
    can enter_if_stmt with IfStmt entry;
    can enter_else_if with ElseIf entry;
    def _resolve_comptime_if(nd: IfStmt) -> None;
    def _in_comptime_context(nd: UniNode) -> bool;
    def _check_comptime_only_use(nd: Name) -> None;
    def _check_type_only_value_use(nd: Name) -> None;
    can exit_if_stmt with IfStmt exit;
    can exit_else_if with ElseIf exit;
    can exit_while_stmt with WhileStmt exit;
    can exit_assert_stmt with AssertStmt exit;
    can exit_yield_expr with YieldExpr exit;
    can exit_delete_stmt with DeleteStmt exit;
    can exit_visit_stmt with VisitStmt exit;
    can exit_report_stmt with ReportStmt exit;
    can exit_impl_def with ImplDef exit;
    can exit_sub_tag with SubTag exit;
    def _eval_unpacking_names(container: Expr) -> None;
    def _body_always_returns(body: list[CodeBlockStmt]) -> bool;
    def _check_bare_generic(ann_node: UniNode, ty: object) -> None;
    def _check_explicit_any(ann_node: UniNode) -> None;
    def _check_walker_reports_shape(nd: HasVar, declared_type: object) -> None;
    def _enclosing_walker_report_elem_type(nd: UniNode) -> (TypeBase | None);
    def _jsx_component_params(nd: Ability) -> (list[ParamVar] | None);
    def _is_ref_forward_tail_param(p: ParamVar) -> bool;
    def _check_props_bundle_is_exclusive(
        nd: Ability, comp_params: list[ParamVar]
    ) -> None;

    def _check_pages_entry_renders_children(nd: Ability) -> None;
    def _check_event_trigger_archetype(nd: Ability) -> None;
    def _check_unresolved_lambda_params -> None;
}
