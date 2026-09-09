import from jaclang.compiler.frontend.unitree {
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
import from jaclang.compiler.frontend.constant { SymbolAccess }
import from jaclang.compiler.passes.uni_pass { UniPass }
import from jaclang.compiler.frontend.diagnostics { E0064, E0077 }

glob TEST_ASSERT_METHOD_NAMES: tuple[str, ...] = (
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

walker SymTabBuildPass(UniPass) {
    static has PROVIDES: tuple = ('SymOf', 'Defines', 'InScope', 'ScopeChild');
    has cur_sym_tab: list[UniScopeNode] = [];

    def before_pass -> None;
    def push_scope_and_link(key_node: UniScopeNode) -> None;
    def pop_scope -> UniScopeNode;

    has cur_scope: UniScopeNode { getter; }

    def _bind_import_path_symbols(module_path: ModulePath) -> None;
    can enter_module with Module entry;
    can exit_module with Module exit;
    can enter_type_alias with TypeAlias entry;
    can exit_type_alias with TypeAlias exit;
    can enter_type_param with TypeParam entry;
    can exit_global_vars with GlobalVars exit;
    can exit_assignment with Assignment exit;
    can exit_binary_expr with BinaryExpr exit;
    can enter_test with Test entry;
    can exit_test with Test exit;
    def _exit_import_absorb(nd: Import) -> None;
    can exit_import with Import exit;
    def import_binding_scope(nd: AstSymbolNode) -> UniScopeNode;
    can exit_module_path with ModulePath exit;
    can exit_module_item with ModuleItem exit;
    can enter_archetype with Archetype entry;
    can exit_archetype with Archetype exit;
    can enter_ability with Ability entry;
    can exit_ability with Ability exit;
    can enter_impl_def with ImplDef entry;
    can exit_impl_def with ImplDef exit;
    can enter_sem_def with SemDef entry;
    can exit_sem_def with SemDef exit;
    can enter_enum with Enum entry;
    can enter_has_var with HasVar entry;
    can enter_param_var with ParamVar entry;
    can exit_atom_trailer with AtomTrailer exit;
    def _is_self_member_assignment(nd: AtomTrailer) -> bool;
    can exit_enum with Enum exit;
    can enter_typed_ctx_block with TypedCtxBlock entry;
    can exit_typed_ctx_block with TypedCtxBlock exit;
    can enter_open_stmt with OpenStmt entry;
    can exit_open_stmt with OpenStmt exit;
    can enter_if_stmt with IfStmt entry;
    can exit_if_stmt with IfStmt exit;
    can enter_else_if with ElseIf entry;
    can exit_else_if with ElseIf exit;
    can enter_else_stmt with ElseStmt entry;
    can exit_else_stmt with ElseStmt exit;
    can enter_try_stmt with TryStmt entry;
    can exit_try_stmt with TryStmt exit;
    can enter_except with Except entry;
    can exit_except with Except exit;
    can enter_finally_stmt with FinallyStmt entry;
    can exit_finally_stmt with FinallyStmt exit;
    can enter_iter_for_stmt with IterForStmt entry;
    can exit_iter_for_stmt with IterForStmt exit;
    can enter_in_for_stmt with InForStmt entry;
    can exit_in_for_stmt with InForStmt exit;
    can enter_while_stmt with WhileStmt entry;
    can exit_while_stmt with WhileStmt exit;
    can enter_forever_stmt with ForeverStmt entry;
    can exit_forever_stmt with ForeverStmt exit;
    can enter_with_stmt with WithStmt entry;
    can exit_with_stmt with WithStmt exit;
    can exit_expr_as_item with ExprAsItem exit;
    can enter_lambda_expr with LambdaExpr entry;
    can exit_lambda_expr with LambdaExpr exit;
    can enter_list_compr with ListCompr entry;
    can exit_list_compr with ListCompr exit;
    can enter_set_compr with SetCompr entry;
    can exit_set_compr with SetCompr exit;
    can enter_gen_compr with GenCompr entry;
    can exit_gen_compr with GenCompr exit;
    can enter_dict_compr with DictCompr entry;
    can exit_dict_compr with DictCompr exit;
    can enter_inner_compr with InnerCompr entry;
    can exit_inner_compr with InnerCompr exit;
    can enter_match_case with MatchCase entry;
    can exit_match_case with MatchCase exit;
    can enter_switch_case with SwitchCase entry;
    can exit_switch_case with SwitchCase exit;
}
