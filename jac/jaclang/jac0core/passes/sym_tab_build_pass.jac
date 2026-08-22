import from jaclang.jac0core.unitree {
    Ability,
    ArchHas,
    Archetype,
    Assignment,
    AstSymbolNode,
    AtomTrailer,
    BinaryExpr,
    DictCompr,
    ElseIf,
    ElseStmt,
    Enum,
    Except,
    ExprAsItem,
    FinallyStmt,
    ForeverStmt,
    GenCompr,
    GlobalVars,
    HasVar,
    IfStmt,
    ImplDef,
    Import,
    InForStmt,
    InnerCompr,
    IterForStmt,
    LambdaExpr,
    ListCompr,
    MatchCase,
    Module,
    ModuleItem,
    ModulePath,
    Name,
    OpenStmt,
    ParamVar,
    SemDef,
    SetCompr,
    SwitchCase,
    Test,
    Token,
    TryStmt,
    TypeAlias,
    TypeParam,
    TypedCtxBlock,
    UniNode,
    UniScopeNode,
    WhileStmt,
    WithStmt,
    bind_assignment_targets,
    def_insert_unpacking,
    find_python_scope_node_of,
    record_cross_scope_rebind,
    rebind_or_def_insert
}
import from jaclang.jac0core.constant { SymbolAccess }
import from jaclang.jac0core.passes.uni_pass { UniPass }
import from jaclang.jac0core.diagnostics { E0064, E0077 }

glob TEST_ASSERT_METHOD_NAMES = (
         'assertAlmostEqual',
         'assertCountEqual',
         'assertDictEqual',
         'assertEndsWith',
         'assertEqual',
         'assertFalse',
         'assertGreater',
         'assertGreaterEqual',
         'assertHasAttr',
         'assertIn',
         'assertIs',
         'assertIsInstance',
         'assertIsNone',
         'assertIsNot',
         'assertIsNotNone',
         'assertIsSubclass',
         'assertLess',
         'assertLessEqual',
         'assertListEqual',
         'assertLogs',
         'assertMultiLineEqual',
         'assertNoLogs',
         'assertNotAlmostEqual',
         'assertNotEndsWith',
         'assertNotEqual',
         'assertNotHasAttr',
         'assertNotIn',
         'assertNotIsInstance',
         'assertNotIsSubclass',
         'assertNotRegex',
         'assertNotStartsWith',
         'assertRaises',
         'assertRaisesRegex',
         'assertRegex',
         'assertSequenceEqual',
         'assertSetEqual',
         'assertStartsWith',
         'assertTrue',
         'assertTupleEqual',
         'assertWarns',
         'assertWarnsRegex'
     );

class SymTabBuildPass(UniPass) {
    has cur_sym_tab: list[UniScopeNode];

    def before_pass(self: SymTabBuildPass) -> None;
    def push_scope_and_link(self: SymTabBuildPass, key_node: UniScopeNode) -> None;
    def pop_scope(self: SymTabBuildPass) -> UniScopeNode;

    has cur_scope: UniScopeNode { getter; }

    def _bind_import_path_symbols(
        self: SymTabBuildPass, module_path: ModulePath
    ) -> None;

    def enter_module(self: SymTabBuildPass, nd: Module) -> None;
    def exit_module(self: SymTabBuildPass, nd: Module) -> None;
    def enter_type_alias(self: SymTabBuildPass, nd: TypeAlias) -> None;
    def exit_type_alias(self: SymTabBuildPass, nd: TypeAlias) -> None;
    def enter_type_param(self: SymTabBuildPass, nd: TypeParam) -> None;
    def exit_global_vars(self: SymTabBuildPass, nd: GlobalVars) -> None;
    def exit_assignment(self: SymTabBuildPass, nd: Assignment) -> None;
    def exit_binary_expr(self: SymTabBuildPass, nd: BinaryExpr) -> None;
    def enter_test(self: SymTabBuildPass, nd: Test) -> None;
    def exit_test(self: SymTabBuildPass, nd: Test) -> None;
    def _exit_import_absorb(self: SymTabBuildPass, nd: Import) -> None;
    def exit_import(self: SymTabBuildPass, nd: Import) -> None;
    def exit_module_path(self: SymTabBuildPass, nd: ModulePath) -> None;
    def exit_module_item(self: SymTabBuildPass, nd: ModuleItem) -> None;
    def enter_archetype(self: SymTabBuildPass, nd: Archetype) -> None;
    def exit_archetype(self: SymTabBuildPass, nd: Archetype) -> None;
    def enter_ability(self: SymTabBuildPass, nd: Ability) -> None;
    def exit_ability(self: SymTabBuildPass, nd: Ability) -> None;
    def enter_impl_def(self: SymTabBuildPass, nd: ImplDef) -> None;
    def exit_impl_def(self: SymTabBuildPass, nd: ImplDef) -> None;
    def enter_sem_def(self: SymTabBuildPass, nd: SemDef) -> None;
    def exit_sem_def(self: SymTabBuildPass, nd: SemDef) -> None;
    def enter_enum(self: SymTabBuildPass, nd: Enum) -> None;
    def enter_has_var(self: SymTabBuildPass, nd: HasVar) -> None;
    def enter_param_var(self: SymTabBuildPass, nd: ParamVar) -> None;
    def exit_atom_trailer(self: SymTabBuildPass, nd: AtomTrailer) -> None;
    def _is_self_member_assignment(self: SymTabBuildPass, nd: AtomTrailer) -> bool;
    def exit_enum(self: SymTabBuildPass, nd: Enum) -> None;
    def enter_typed_ctx_block(self: SymTabBuildPass, nd: TypedCtxBlock) -> None;
    def exit_typed_ctx_block(self: SymTabBuildPass, nd: TypedCtxBlock) -> None;
    def enter_open_stmt(self: SymTabBuildPass, nd: OpenStmt) -> None;
    def exit_open_stmt(self: SymTabBuildPass, nd: OpenStmt) -> None;
    def enter_if_stmt(self: SymTabBuildPass, nd: IfStmt) -> None;
    def exit_if_stmt(self: SymTabBuildPass, nd: IfStmt) -> None;
    def enter_else_if(self: SymTabBuildPass, nd: ElseIf) -> None;
    def exit_else_if(self: SymTabBuildPass, nd: ElseIf) -> None;
    def enter_else_stmt(self: SymTabBuildPass, nd: ElseStmt) -> None;
    def exit_else_stmt(self: SymTabBuildPass, nd: ElseStmt) -> None;
    def enter_try_stmt(self: SymTabBuildPass, nd: TryStmt) -> None;
    def exit_try_stmt(self: SymTabBuildPass, nd: TryStmt) -> None;
    def enter_except(self: SymTabBuildPass, nd: Except) -> None;
    def exit_except(self: SymTabBuildPass, nd: Except) -> None;
    def enter_finally_stmt(self: SymTabBuildPass, nd: FinallyStmt) -> None;
    def exit_finally_stmt(self: SymTabBuildPass, nd: FinallyStmt) -> None;
    def enter_iter_for_stmt(self: SymTabBuildPass, nd: IterForStmt) -> None;
    def exit_iter_for_stmt(self: SymTabBuildPass, nd: IterForStmt) -> None;
    def enter_in_for_stmt(self: SymTabBuildPass, nd: InForStmt) -> None;
    def exit_in_for_stmt(self: SymTabBuildPass, nd: InForStmt) -> None;
    def enter_while_stmt(self: SymTabBuildPass, nd: WhileStmt) -> None;
    def exit_while_stmt(self: SymTabBuildPass, nd: WhileStmt) -> None;
    def enter_forever_stmt(self: SymTabBuildPass, nd: ForeverStmt) -> None;
    def exit_forever_stmt(self: SymTabBuildPass, nd: ForeverStmt) -> None;
    def enter_with_stmt(self: SymTabBuildPass, nd: WithStmt) -> None;
    def exit_with_stmt(self: SymTabBuildPass, nd: WithStmt) -> None;
    def exit_expr_as_item(self: SymTabBuildPass, nd: ExprAsItem) -> None;
    def enter_lambda_expr(self: SymTabBuildPass, nd: LambdaExpr) -> None;
    def exit_lambda_expr(self: SymTabBuildPass, nd: LambdaExpr) -> None;
    def enter_list_compr(self: SymTabBuildPass, nd: ListCompr) -> None;
    def exit_list_compr(self: SymTabBuildPass, nd: ListCompr) -> None;
    def enter_set_compr(self: SymTabBuildPass, nd: SetCompr) -> None;
    def exit_set_compr(self: SymTabBuildPass, nd: SetCompr) -> None;
    def enter_gen_compr(self: SymTabBuildPass, nd: GenCompr) -> None;
    def exit_gen_compr(self: SymTabBuildPass, nd: GenCompr) -> None;
    def enter_dict_compr(self: SymTabBuildPass, nd: DictCompr) -> None;
    def exit_dict_compr(self: SymTabBuildPass, nd: DictCompr) -> None;
    def enter_inner_compr(self: SymTabBuildPass, nd: InnerCompr) -> None;
    def exit_inner_compr(self: SymTabBuildPass, nd: InnerCompr) -> None;
    def enter_match_case(self: SymTabBuildPass, nd: MatchCase) -> None;
    def exit_match_case(self: SymTabBuildPass, nd: MatchCase) -> None;
    def enter_switch_case(self: SymTabBuildPass, nd: SwitchCase) -> None;
    def exit_switch_case(self: SymTabBuildPass, nd: SwitchCase) -> None;
}
