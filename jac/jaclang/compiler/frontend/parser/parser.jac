glob _TOK_NAMED_BY_VALUE: frozenset[TokenKind] = frozenset(
         [
             TokenKind.KW_GETTER,
             TokenKind.KW_SETTER,
             TokenKind.KW_DELETER,
             TokenKind.KW_GRAPH,
             TokenKind.KW_AWAITING,
             TokenKind.KW_OWN,
             TokenKind.KW_LIN,
             TokenKind.KW_MUT,
             TokenKind.KW_IMM,
             TokenKind.RF_DQ_START,
             TokenKind.RF_SQ_START,
             TokenKind.RF_TDQ_START,
             TokenKind.RF_TSQ_START,
             TokenKind.JSX_SELF_CLOSE,
             TokenKind.JSX_CLOSE_START,
             TokenKind.JSX_FRAG_OPEN,
             TokenKind.JSX_FRAG_CLOSE
         ]
     ),
     TOKEN_KIND_TO_TOK: dict[TokenKind, str] = {
         kind: (
             "NOT"
                 if kind == TokenKind.KW_NOT
                 else (kind.value if kind in _TOK_NAMED_BY_VALUE else kind.name)
         ) for kind in TokenKind
     };

def _string_lit_text(raw: str) -> str;

def _test_ident_from_desc(desc_text: str) -> str;

obj Parser {
    has tokens: list[LexToken],
        pos: int = 0,
        _tokens_len: int = 0,
        error_count: int = 0,
        file_path: str = "<input>",
        source_code: str = "",
        source: Source postinit,
        diags: list[SrcDiag] = [],
        _view_body_depth: int = 0,
        _lambda_block: bool = False,
        _no_connect_op_depth: int = 0,
        _gen_test_idx: int = 0;

    def postinit;
    def current -> LexToken;
    def peek(offset: int = 1) -> LexToken;
    def advance -> LexToken;
    def previous -> LexToken;
    def at_end -> bool;
    def check(kind: TokenKind) -> bool;
    def check_any(*kinds: TokenKind) -> bool;
    def check_peek(kind: TokenKind) -> bool;
    def check_peek_any(*kinds: TokenKind) -> bool;
    def check_name -> bool;
    def is_keyword_token -> bool;
    def is_name_usable_token -> bool;
    def is_builtin_type_token -> bool;
    def match_tok(kind: TokenKind) -> LexToken | None;
    def match_any(*kinds: TokenKind) -> LexToken | None;
    def expect(kind: TokenKind) -> LexToken;
    def expect_any(*kinds: TokenKind) -> LexToken;
    def consume_uni(kind: TokenKind, value: str | None = None) -> Token;
    def expect_name(context: str = "identifier") -> LexToken;
    def error(message: str);
    def emit_diag(
        message: str, code_str: str, loc: SourceLoc | None = None, help: str = ""
    );

    def emit_warn(
        message: str, code_str: str, loc: SourceLoc | None = None, help: str = ""
    );

    def _reject_paren_filter;
    def make_uni_token(tok: LexToken) -> Token;
    def make_name(tok: LexToken, is_enum_stmt: bool = False) -> Name;
    def make_special_name(tok: LexToken) -> Name;
    def make_name_or_special(tok: LexToken) -> Name;
    def parse_access_tag -> SubTag | None;
    def make_string(tok: LexToken) -> String;
    def make_string_from_value(value: str) -> String;
    def make_int(tok: LexToken) -> Int;
    def make_float(tok: LexToken) -> Float;
    def make_bool(tok: LexToken) -> Bool;
    def make_null(tok: LexToken) -> Null;
    def make_ellipsis(tok: LexToken) -> EllipsisLit;
    def make_semi -> Semi;
    def synchronize;
    def parse -> Module;
    def parse_module -> Module;
    def parse_expression(allow_cast: bool = True) -> Expr;
    def _check_js_arrow_fault -> bool;
    def _recover_js_arrow_fault(left: Expr) -> Expr;
    def _recover_removed_marker -> ElementStmt | EmptyToken | None;
    def _recover_missing_connect_rhs -> bool;
    def _recover_misplaced_disconnect -> None;
    def parse_concurrent_expr(allow_cast: bool = True) -> Expr;
    def parse_walrus_assign(allow_cast: bool = True) -> Expr;
    def parse_by_expr(allow_cast: bool = True) -> Expr;
    def parse_cast(allow_cast: bool = True) -> Expr;
    def parse_cast_type -> Expr;
    def parse_pipe(allow_cast: bool = True) -> Expr;
    def parse_pipe_back(allow_cast: bool = True) -> Expr;
    def parse_bitwise_or -> Expr;
    def parse_bitwise_xor -> Expr;
    def parse_bitwise_and -> Expr;
    def parse_shift -> Expr;
    def parse_logical_or(allow_cast: bool = True) -> Expr;
    def parse_logical_and(allow_cast: bool = True) -> Expr;
    def parse_logical_not(allow_cast: bool = True) -> Expr;
    def parse_compare(allow_cast: bool = True) -> Expr;
    def parse_arithmetic -> Expr;
    def parse_term -> Expr;
    def parse_power -> Expr;
    def parse_factor -> Expr;
    def parse_connect -> Expr;
    def parse_edge_endpoint -> Expr;
    def parse_connect_op -> ConnectOp | DisconnectOp | None;
    def parse_edge_op_ref_inline -> EdgeOpRef | None;
    def parse_atomic_pipe -> Expr;
    def parse_atomic_pipe_back -> Expr;
    def parse_spawn -> Expr;
    def parse_unpack -> Expr;
    def parse_ref -> Expr;
    def parse_await_expr -> Expr;
    def parse_pipe_call -> Expr;
    def parse_atomic_chain -> Expr;
    def _make_attr_from_keyword(name_tok: LexToken) -> Name;
    def parse_index_slice -> IndexSlice;
    def parse_call_args(kid: list[UniNode]) -> list[Expr | KWPair];
    def parse_call_arg -> Expr | KWPair;
    def parse_filter_compr_inner -> FilterCompr;
    def parse_filter_compr_bracket -> FilterCompr;
    def parse_assign_compr_inner -> AssignCompr;
    def parse_atom_literal -> Expr | None;
    def parse_multistring -> Expr | None;
    def parse_builtin_type -> Expr | None;
    def parse_special_ref -> Expr | None;
    def parse_atom -> Expr;
    def parse_graph_expr -> GraphExpr;
    def parse_tuple_item -> Expr | KWPair;
    def parse_paren_expr -> Expr;
    def parse_bracket_expr -> Expr;
    def _is_edge_ref_start -> bool;
    def parse_brace_expr -> Expr;
    def parse_fstring -> FString;
    def parse_list_or_compr -> Expr;
    def parse_dict_or_set -> Expr;
    def parse_dict_with_spread(lbrace_uni: Token) -> DictVal;
    def parse_dict_spread_entry -> KVPair;
    def parse_edge_ref_chain -> Expr;
    def parse_edge_op_ref -> EdgeOpRef | None;
    def _continue_edge_ref_chain(start_expr: Expr, lsquare_uni: Token) -> Expr;
    def parse_comprehension_clauses -> list[InnerCompr];
    def parse_compr_clause -> InnerCompr;
    def parse_lambda_expr -> Expr;
    def parse_jsx_element -> JsxElement;
    def _parse_jsx_dynamic_tag(open_kid: list[UniNode]) -> Expr | None;
    def _consume_jsx_dynamic_close(close_kid: list[UniNode]);
    def parse_jsx_attributes -> list[JsxAttribute];
    def parse_jsx_children -> list[JsxChild | JsxElement];
    def parse_jsx_child -> JsxChild | JsxElement | None;
    def parse_element_stmt -> ElementStmt | EmptyToken | None;
    def _dispatch_decorated -> ElementStmt | None;
    def _dispatch_decorated_stmt -> CodeBlockStmt | None;
    def _dispatch_async -> ElementStmt | None;
    def _attach_doc(nd: AstDocNode, elem_doc: String) -> None;
    def parse_docstring_target -> ElementStmt | None;
    def parse_module_code -> ModuleCode;
    def parse_code_block_stmts -> list[CodeBlockStmt];
    def _apply_implicit_return(body: list[CodeBlockStmt]) -> list[CodeBlockStmt];
    def parse_ctrl_stmt -> CtrlStmt | DisengageStmt | None;
    def parse_statement -> CodeBlockStmt | None;
    def _lookahead_advance -> None;
    def parse_if_stmt -> IfStmt;
    def parse_elif_stmt -> ElseIf;
    def parse_else_stmt -> ElseStmt;
    def parse_while_stmt -> WhileStmt;
    def parse_open_stmt -> OpenStmt;
    def parse_forever_stmt -> ForeverStmt;
    def parse_for_stmt -> IterForStmt | InForStmt;
    def parse_try_stmt -> TryStmt;
    def parse_except_handler -> Except;
    def parse_with_stmt -> WithStmt;
    def parse_match_stmt -> MatchStmt;
    def parse_match_case -> MatchCase;
    def parse_pattern -> MatchPattern;
    def parse_or_pattern -> MatchPattern;
    def parse_single_pattern -> MatchPattern;
    def parse_literal_pattern -> MatchValue;
    def parse_expression_pattern -> MatchValue;
    def parse_name_pattern -> MatchPattern;
    def parse_sequence_pattern -> MatchPattern;
    def parse_tuple_sequence_pattern -> MatchPattern;
    def parse_mapping_pattern -> MatchPattern;
    def parse_literal_for_mapping -> MatchPattern | NameAtom | None;
    def parse_class_pattern_args(
        names: list[Name], dot_unis: (list[Token] | None) = None
    ) -> MatchPattern;

    def parse_switch_stmt -> SwitchStmt;
    def parse_switch_case -> SwitchCase;
    def parse_return_stmt -> ReturnStmt;
    def parse_yield_stmt -> YieldExpr;
    def parse_raise_stmt -> RaiseStmt;
    def parse_assert_stmt -> AssertStmt;
    def parse_delete_stmt -> DeleteStmt;
    def parse_visit_stmt -> VisitStmt;
    def parse_report_stmt -> ReportStmt;
    def parse_assignment_with_target(
        target: Expr, require_semi: bool = True
    ) -> Assignment;

    def parse_ownership_prefix(kids: list[UniNode]) -> tuple[OwnershipKind, bool];
    def parse_import_stmt -> Import;
    def parse_from_path -> tuple[(ModulePath | None, bool)];
    def parse_import_items(
        kid: list[UniNode], is_clib_import: bool
    ) -> tuple[(list[ModuleItem | ModulePath], list[UniNode])];

    def parse_archetype -> Archetype;
    def parse_archetype_member -> UniNode | None;
    def _skip_semicolons;
    def _error_unexpected_member;
    def parse_has_stmt -> ArchHas;
    def parse_has_var -> HasVar;
    def parse_accessor -> Ability;
    def _consume_accessor_kind -> tuple[(str, LexToken)];
    def parse_ability -> Ability;
    def _parse_post_async_modifiers(
        is_override: bool,
        override_tok: (LexToken | None),
        is_static: bool,
        static_tok: (LexToken | None)
    ) -> tuple[(bool, (LexToken | None), bool, (LexToken | None))];

    def parse_func_signature -> FuncSignature;
    def parse_func_params(kid: list[UniNode]) -> list[ParamVar];
    def parse_param_var -> ParamVar | None;
    def parse_enum -> Enum;
    def parse_enum_member -> Assignment;
    def parse_test -> Test;
    def parse_global_var -> GlobalVars;
    def parse_global_var_assignment -> Assignment;
    def parse_comptime_element -> ElementStmt | EmptyToken | None;
    def parse_comptime_global -> GlobalVars;
    def parse_comptime_stmt -> CodeBlockStmt | None;
    def parse_impl_def -> ImplDef;
    def _is_impl_enum_body -> bool;
    def parse_impl_target_name -> NameAtom;
    def parse_impl_enum_body -> tuple[(list[Assignment], list[Token])];
    def parse_graph_import -> GraphImport;
    def parse_import_rule -> ImportRule | None;
    def parse_import_wire -> ImportWire | None;
    def parse_module_pattern -> ModulePattern;
    def parse_wire_module_path(context: str) -> ModulePath;
    def parse_wire_target(is_absorb: bool, provider: ModulePath) -> WireTarget | None;
    def parse_wire_payload(kid: list[UniNode], in_rule: bool) -> list[WireItem];
    def _expect_wire_arrow(kid: list[UniNode]) -> bool;
    def _expect_rule_arrow(kid: list[UniNode]) -> None;
    def _wire_path_ahead -> bool;
    def _skip_wiring_stmt(open_lists: int = 0) -> None;
    def parse_sem_def -> SemDef;
    def parse_type_alias -> TypeAlias;
    def parse_type_params -> tuple[(list[TypeParam], list[Token])];
}


def parse_expression(
    source: str, file_path: str = "<input>"
) -> tuple[Expr, bool, list[SrcDiag], list[SrcDiag]];
