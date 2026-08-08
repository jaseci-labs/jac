import from .tokens { LexToken, TokenKind, SourceLoc, SrcDiag, CommentData }
import from .lexer { tokenize_full }

import from jaclang.jac0core.arena { NIL, SyntaxArena }
import from jaclang.jac0core.arena_schema {
    DOC_SLOTS,
    ENUM_STMT_SLOTS,
    KS_CONTEXT_AWARE_NODE,
    KS_EMPTY_TOKEN,
    KS_EVENT_SIGNATURE,
    KS_EXPR_STMT,
    KS_FUNC_SIGNATURE,
    KS_GEN_COMPR,
    KS_JSX_ELEMENT,
    KS_K_W_PAIR,
    KS_MULTI_STRING,
    KS_NAME,
    KS_PARAM_VAR,
    KS_SEMI,
    KS_STRING,
    KS_TOKEN
}

import from jaclang.jac0core.constant {
    Tokens as Tok,
    EdgeDir,
    CodeContext,
    OwnershipKind,
    ParamKind
}

glob TOKEN_KIND_TO_TOK: dict[str, str] = {
         TokenKind.INT.value: Tok.INT.value,
         TokenKind.HEX.value: Tok.HEX.value,
         TokenKind.BIN.value: Tok.BIN.value,
         TokenKind.OCT.value: Tok.OCT.value,
         TokenKind.FLOAT.value: Tok.FLOAT.value,
         TokenKind.STRING.value: Tok.STRING.value,
         TokenKind.BOOL.value: Tok.BOOL.value,
         TokenKind.NULL.value: Tok.NULL.value,
         TokenKind.ELLIPSIS.value: Tok.ELLIPSIS.value,
         TokenKind.PYNLINE.value: Tok.PYNLINE.value,
         TokenKind.NAME.value: Tok.NAME.value,
         TokenKind.KWESC_NAME.value: Tok.KWESC_NAME.value,
         TokenKind.TYP_STRING.value: Tok.TYP_STRING.value,
         TokenKind.TYP_INT.value: Tok.TYP_INT.value,
         TokenKind.TYP_FLOAT.value: Tok.TYP_FLOAT.value,
         TokenKind.TYP_LIST.value: Tok.TYP_LIST.value,
         TokenKind.TYP_TUPLE.value: Tok.TYP_TUPLE.value,
         TokenKind.TYP_SET.value: Tok.TYP_SET.value,
         TokenKind.TYP_DICT.value: Tok.TYP_DICT.value,
         TokenKind.TYP_BOOL.value: Tok.TYP_BOOL.value,
         TokenKind.TYP_BYTES.value: Tok.TYP_BYTES.value,
         TokenKind.TYP_ANY.value: Tok.TYP_ANY.value,
         TokenKind.TYP_TYPE.value: Tok.TYP_TYPE.value,
         TokenKind.TYP_I8.value: Tok.TYP_I8.value,
         TokenKind.TYP_U8.value: Tok.TYP_U8.value,
         TokenKind.TYP_I16.value: Tok.TYP_I16.value,
         TokenKind.TYP_U16.value: Tok.TYP_U16.value,
         TokenKind.TYP_I32.value: Tok.TYP_I32.value,
         TokenKind.TYP_U32.value: Tok.TYP_U32.value,
         TokenKind.TYP_I64.value: Tok.TYP_I64.value,
         TokenKind.TYP_U64.value: Tok.TYP_U64.value,
         TokenKind.TYP_F32.value: Tok.TYP_F32.value,
         TokenKind.TYP_F64.value: Tok.TYP_F64.value,
         TokenKind.KW_ABSTRACT.value: Tok.KW_ABSTRACT.value,
         TokenKind.KW_OBJECT.value: Tok.KW_OBJECT.value,
         TokenKind.KW_CLASS.value: Tok.KW_CLASS.value,
         TokenKind.KW_ENUM.value: Tok.KW_ENUM.value,
         TokenKind.KW_NODE.value: Tok.KW_NODE.value,
         TokenKind.KW_EDGE.value: Tok.KW_EDGE.value,
         TokenKind.KW_WALKER.value: Tok.KW_WALKER.value,
         TokenKind.KW_HAS.value: Tok.KW_HAS.value,
         TokenKind.KW_CAN.value: Tok.KW_CAN.value,
         TokenKind.KW_DEF.value: Tok.KW_DEF.value,
         TokenKind.KW_STATIC.value: Tok.KW_STATIC.value,
         TokenKind.KW_OVERRIDE.value: Tok.KW_OVERRIDE.value,
         TokenKind.KW_IMPL.value: Tok.KW_IMPL.value,
         TokenKind.KW_SEM.value: Tok.KW_SEM.value,
         TokenKind.KW_TEST.value: Tok.KW_TEST.value,
         TokenKind.KW_GLOBAL.value: Tok.KW_GLOBAL.value,
         TokenKind.KW_IMPORT.value: Tok.KW_IMPORT.value,
         TokenKind.KW_INCLUDE.value: Tok.KW_INCLUDE.value,
         TokenKind.KW_FROM.value: Tok.KW_FROM.value,
         TokenKind.KW_AS.value: Tok.KW_AS.value,
         TokenKind.KW_IF.value: Tok.KW_IF.value,
         TokenKind.KW_ELIF.value: Tok.KW_ELIF.value,
         TokenKind.KW_ELSE.value: Tok.KW_ELSE.value,
         TokenKind.KW_FOR.value: Tok.KW_FOR.value,
         TokenKind.KW_BY.value: Tok.KW_BY.value,
         TokenKind.KW_WHILE.value: Tok.KW_WHILE.value,
         TokenKind.KW_FOREVER.value: Tok.KW_FOREVER.value,
         TokenKind.KW_MATCH.value: Tok.KW_MATCH.value,
         TokenKind.KW_SWITCH.value: Tok.KW_SWITCH.value,
         TokenKind.KW_CASE.value: Tok.KW_CASE.value,
         TokenKind.KW_DEFAULT.value: Tok.KW_DEFAULT.value,
         TokenKind.KW_TRY.value: Tok.KW_TRY.value,
         TokenKind.KW_EXCEPT.value: Tok.KW_EXCEPT.value,
         TokenKind.KW_FINALLY.value: Tok.KW_FINALLY.value,
         TokenKind.KW_WITH.value: Tok.KW_WITH.value,
         TokenKind.KW_RETURN.value: Tok.KW_RETURN.value,
         TokenKind.KW_YIELD.value: Tok.KW_YIELD.value,
         TokenKind.KW_BREAK.value: Tok.KW_BREAK.value,
         TokenKind.KW_CONTINUE.value: Tok.KW_CONTINUE.value,
         TokenKind.KW_RAISE.value: Tok.KW_RAISE.value,
         TokenKind.KW_DELETE.value: Tok.KW_DELETE.value,
         TokenKind.KW_ASSERT.value: Tok.KW_ASSERT.value,
         TokenKind.KW_SKIP.value: Tok.KW_SKIP.value,
         TokenKind.KW_REPORT.value: Tok.KW_REPORT.value,
         TokenKind.KW_VISIT.value: Tok.KW_VISIT.value,
         TokenKind.KW_SPAWN.value: Tok.KW_SPAWN.value,
         TokenKind.KW_ENTRY.value: Tok.KW_ENTRY.value,
         TokenKind.KW_EXIT.value: Tok.KW_EXIT.value,
         TokenKind.KW_DISENGAGE.value: Tok.KW_DISENGAGE.value,
         TokenKind.KW_HERE.value: Tok.KW_HERE.value,
         TokenKind.KW_VISITOR.value: Tok.KW_VISITOR.value,
         TokenKind.KW_ROOT.value: Tok.KW_ROOT.value,
         TokenKind.KW_ASYNC.value: Tok.KW_ASYNC.value,
         TokenKind.KW_AWAIT.value: Tok.KW_AWAIT.value,
         TokenKind.KW_FLOW.value: Tok.KW_FLOW.value,
         TokenKind.KW_WAIT.value: Tok.KW_WAIT.value,
         TokenKind.KW_AND.value: Tok.KW_AND.value,
         TokenKind.KW_OR.value: Tok.KW_OR.value,
         TokenKind.KW_NOT.value: Tok.NOT.value,
         TokenKind.KW_IN.value: Tok.KW_IN.value,
         TokenKind.KW_IS.value: Tok.KW_IS.value,
         TokenKind.KW_NIN.value: Tok.KW_NIN.value,
         TokenKind.KW_ISN.value: Tok.KW_ISN.value,
         TokenKind.KW_LAMBDA.value: Tok.KW_LAMBDA.value,
         TokenKind.KW_PUB.value: Tok.KW_PUB.value,
         TokenKind.KW_PRIV.value: Tok.KW_PRIV.value,
         TokenKind.KW_PROT.value: Tok.KW_PROT.value,
         TokenKind.KW_SELF.value: Tok.KW_SELF.value,
         TokenKind.KW_PROPS.value: Tok.KW_PROPS.value,
         TokenKind.KW_INIT.value: Tok.KW_INIT.value,
         TokenKind.KW_SUPER.value: Tok.KW_SUPER.value,
         TokenKind.KW_POST_INIT.value: Tok.KW_POST_INIT.value,
         TokenKind.LPAREN.value: Tok.LPAREN.value,
         TokenKind.RPAREN.value: Tok.RPAREN.value,
         TokenKind.LBRACE.value: Tok.LBRACE.value,
         TokenKind.RBRACE.value: Tok.RBRACE.value,
         TokenKind.LSQUARE.value: Tok.LSQUARE.value,
         TokenKind.RSQUARE.value: Tok.RSQUARE.value,
         TokenKind.COMMA.value: Tok.COMMA.value,
         TokenKind.COLON.value: Tok.COLON.value,
         TokenKind.SEMI.value: Tok.SEMI.value,
         TokenKind.DOT.value: Tok.DOT.value,
         TokenKind.EQ.value: Tok.EQ.value,
         TokenKind.WALRUS_EQ.value: Tok.WALRUS_EQ.value,
         TokenKind.ADD_EQ.value: Tok.ADD_EQ.value,
         TokenKind.SUB_EQ.value: Tok.SUB_EQ.value,
         TokenKind.MUL_EQ.value: Tok.MUL_EQ.value,
         TokenKind.DIV_EQ.value: Tok.DIV_EQ.value,
         TokenKind.FLOOR_DIV_EQ.value: Tok.FLOOR_DIV_EQ.value,
         TokenKind.MOD_EQ.value: Tok.MOD_EQ.value,
         TokenKind.STAR_POW_EQ.value: Tok.STAR_POW_EQ.value,
         TokenKind.BW_AND_EQ.value: Tok.BW_AND_EQ.value,
         TokenKind.BW_OR_EQ.value: Tok.BW_OR_EQ.value,
         TokenKind.BW_XOR_EQ.value: Tok.BW_XOR_EQ.value,
         TokenKind.LSHIFT_EQ.value: Tok.LSHIFT_EQ.value,
         TokenKind.RSHIFT_EQ.value: Tok.RSHIFT_EQ.value,
         TokenKind.MATMUL_EQ.value: Tok.MATMUL_EQ.value,
         TokenKind.EE.value: Tok.EE.value,
         TokenKind.NE.value: Tok.NE.value,
         TokenKind.LT.value: Tok.LT.value,
         TokenKind.GT.value: Tok.GT.value,
         TokenKind.LTE.value: Tok.LTE.value,
         TokenKind.GTE.value: Tok.GTE.value,
         TokenKind.PLUS.value: Tok.PLUS.value,
         TokenKind.MINUS.value: Tok.MINUS.value,
         TokenKind.STAR_MUL.value: Tok.STAR_MUL.value,
         TokenKind.DIV.value: Tok.DIV.value,
         TokenKind.FLOOR_DIV.value: Tok.FLOOR_DIV.value,
         TokenKind.MOD.value: Tok.MOD.value,
         TokenKind.STAR_POW.value: Tok.STAR_POW.value,
         TokenKind.BW_AND.value: Tok.BW_AND.value,
         TokenKind.BW_OR.value: Tok.BW_OR.value,
         TokenKind.BW_XOR.value: Tok.BW_XOR.value,
         TokenKind.BW_NOT.value: Tok.BW_NOT.value,
         TokenKind.LSHIFT.value: Tok.LSHIFT.value,
         TokenKind.RSHIFT.value: Tok.RSHIFT.value,
         TokenKind.PIPE_FWD.value: Tok.PIPE_FWD.value,
         TokenKind.PIPE_BKWD.value: Tok.PIPE_BKWD.value,
         TokenKind.A_PIPE_FWD.value: Tok.A_PIPE_FWD.value,
         TokenKind.A_PIPE_BKWD.value: Tok.A_PIPE_BKWD.value,
         TokenKind.DOT_FWD.value: Tok.DOT_FWD.value,
         TokenKind.DOT_BKWD.value: Tok.DOT_BKWD.value,
         TokenKind.ARROW_L.value: Tok.ARROW_L.value,
         TokenKind.ARROW_R.value: Tok.ARROW_R.value,
         TokenKind.ARROW_BI.value: Tok.ARROW_BI.value,
         TokenKind.ARROW_L_P1.value: Tok.ARROW_L_P1.value,
         TokenKind.ARROW_L_P2.value: Tok.ARROW_L_P2.value,
         TokenKind.ARROW_R_P1.value: Tok.ARROW_R_P1.value,
         TokenKind.ARROW_R_P2.value: Tok.ARROW_R_P2.value,
         TokenKind.CARROW_L.value: Tok.CARROW_L.value,
         TokenKind.CARROW_R.value: Tok.CARROW_R.value,
         TokenKind.CARROW_BI.value: Tok.CARROW_BI.value,
         TokenKind.CARROW_L_P1.value: Tok.CARROW_L_P1.value,
         TokenKind.CARROW_L_P2.value: Tok.CARROW_L_P2.value,
         TokenKind.CARROW_R_P1.value: Tok.CARROW_R_P1.value,
         TokenKind.CARROW_R_P2.value: Tok.CARROW_R_P2.value,
         TokenKind.RETURN_HINT.value: Tok.RETURN_HINT.value,
         TokenKind.NULL_OK.value: Tok.NULL_OK.value,
         TokenKind.DECOR_OP.value: Tok.DECOR_OP.value,
         TokenKind.F_DQ_START.value: Tok.F_DQ_START.value,
         TokenKind.F_SQ_START.value: Tok.F_SQ_START.value,
         TokenKind.F_TDQ_START.value: Tok.F_TDQ_START.value,
         TokenKind.F_TSQ_START.value: Tok.F_TSQ_START.value,
         TokenKind.F_DQ_END.value: Tok.F_DQ_END.value,
         TokenKind.F_SQ_END.value: Tok.F_SQ_END.value,
         TokenKind.F_TDQ_END.value: Tok.F_TDQ_END.value,
         TokenKind.F_TSQ_END.value: Tok.F_TSQ_END.value,
         TokenKind.D_LBRACE.value: Tok.D_LBRACE.value,
         TokenKind.D_RBRACE.value: Tok.D_RBRACE.value,
         TokenKind.EOF.value: "EOF"
     };

def _string_lit_text(raw: str) -> str {
    v = raw;
    while v and v[0] in "rbfRBF" {
        v = v[1:];
    }
    if len(v) >= 6 and v.startswith('"""') and v.endswith('"""') {
        return v[3:-3];
    }
    if len(v) >= 6 and v.startswith("'''") and v.endswith("'''") {
        return v[3:-3];
    }
    if len(v) >= 2 and (v[0] == "'" or v[0] == '"') and v[-1] == v[0] {
        return v[1:-1];
    }
    return v;
}

obj Parser {
    has tokens: list[LexToken],
        pos: int = 0,
        _tokens_len: int = 0,
        error_count: int = 0,
        file_path: str = "<input>",
        source_code: str = "",
        b: SyntaxArena postinit,
        diags: list[SrcDiag] = [],
        _view_body_depth: int = 0,
        _gen_test_idx: int = 0,
        _impl_enum_comma_unis: list[int] = [];

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
    def is_builtin_type_token -> bool;
    def match_tok(kind: TokenKind) -> LexToken | None;
    def match_any(*kinds: TokenKind) -> LexToken | None;
    def expect(kind: TokenKind) -> LexToken;
    def expect_any(*kinds: TokenKind) -> LexToken;
    def consume_uni(kind: TokenKind) -> int;
    def expect_name -> LexToken;
    def error(message: str);
    def emit_diag(
        message: str, code_str: str, loc: SourceLoc | None = None, help: str = ""
    );

    def emit_warn(
        message: str, code_str: str, loc: SourceLoc | None = None, help: str = ""
    );

    def make_uni_token(tok: LexToken) -> int;
    def make_name(tok: LexToken, is_enum_stmt: bool = False) -> int;
    def make_special_name(tok: LexToken) -> int;
    def make_name_or_special(tok: LexToken) -> int;
    def parse_access_tag -> int;
    def make_string(tok: LexToken) -> int;
    def make_string_from_value(value: str) -> int;
    def make_int(tok: LexToken) -> int;
    def make_float(tok: LexToken) -> int;
    def make_bool(tok: LexToken) -> int;
    def make_null(tok: LexToken) -> int;
    def make_ellipsis(tok: LexToken) -> int;
    def make_semi -> int;
    def synchronize;
    def parse -> int;
    def parse_module -> int;
    def parse_expression(allow_cast: bool = True) -> int;
    def _check_js_arrow_fault -> bool;
    def _recover_js_arrow_fault(left: int) -> int;
    def _recover_removed_marker -> int;
    def _recover_missing_connect_rhs -> bool;
    def _recover_misplaced_disconnect -> None;
    def parse_concurrent_expr(allow_cast: bool = True) -> int;
    def parse_walrus_assign(allow_cast: bool = True) -> int;
    def parse_by_expr(allow_cast: bool = True) -> int;
    def parse_cast(allow_cast: bool = True) -> int;
    def parse_cast_type -> int;
    def parse_pipe(allow_cast: bool = True) -> int;
    def parse_pipe_back(allow_cast: bool = True) -> int;
    def parse_bitwise_or -> int;
    def parse_bitwise_xor -> int;
    def parse_bitwise_and -> int;
    def parse_shift -> int;
    def parse_logical_or(allow_cast: bool = True) -> int;
    def parse_logical_and(allow_cast: bool = True) -> int;
    def parse_logical_not(allow_cast: bool = True) -> int;
    def parse_compare(allow_cast: bool = True) -> int;
    def parse_arithmetic -> int;
    def parse_term -> int;
    def parse_power -> int;
    def parse_factor -> int;
    def parse_connect -> int;
    def parse_connect_op -> int;
    def parse_edge_op_ref_inline -> int;
    def parse_atomic_pipe -> int;
    def parse_atomic_pipe_back -> int;
    def parse_spawn -> int;
    def parse_unpack -> int;
    def parse_ref -> int;
    def parse_await_expr -> int;
    def parse_pipe_call -> int;
    def parse_atomic_chain -> int;
    def _make_attr_from_keyword(name_tok: LexToken) -> (int);
    def parse_index_slice -> int;
    def parse_call_args(kid: list[int]) -> list[int];
    def parse_call_arg -> int;
    def parse_filter_compr_inner -> int;
    def parse_filter_compr_bracket -> int;
    def parse_assign_compr_inner -> int;
    def parse_atom_literal -> int;
    def parse_multistring -> int;
    def parse_builtin_type -> int;
    def parse_special_ref -> int;
    def parse_atom -> int;
    def parse_tuple_item -> int;
    def parse_paren_expr -> int;
    def parse_bracket_expr -> int;
    def _is_edge_ref_start -> bool;
    def parse_brace_expr -> int;
    def parse_fstring -> int;
    def parse_list_or_compr -> int;
    def parse_dict_or_set -> int;
    def parse_dict_with_spread(lbrace_uni: int) -> int;
    def parse_dict_spread_entry -> int;
    def parse_edge_ref_chain -> int;
    def parse_edge_op_ref -> int;
    def _continue_edge_ref_chain(start_expr: int, lsquare_uni: int) -> int;
    def parse_comprehension_clauses -> list;
    def parse_compr_clause -> int;
    def parse_lambda_expr -> int;
    def parse_jsx_element -> int;
    def _parse_jsx_dynamic_tag(open_kid: list[int]) -> int;
    def _consume_jsx_dynamic_close(close_kid: list[int]);
    def parse_jsx_attributes -> list;
    def parse_jsx_children -> list;
    def parse_jsx_child -> int;
    def parse_element_stmt -> int;
    def _dispatch_decorated -> int;
    def _dispatch_async -> (int);
    def _attach_doc(nd: int, elem_doc: int) -> int;
    def parse_docstring_target -> int;
    def parse_module_code -> int;
    def parse_code_block_stmts -> list;
    def _apply_implicit_return(body: list[int]) -> list[int];
    def parse_ctrl_stmt -> int;
    def parse_statement -> int;
    def parse_if_stmt -> int;
    def parse_elif_stmt -> int;
    def parse_else_stmt -> int;
    def parse_while_stmt -> int;
    def parse_open_stmt -> int;
    def parse_forever_stmt -> int;
    def parse_for_stmt -> (int);
    def parse_try_stmt -> int;
    def parse_except_handler -> int;
    def parse_with_stmt -> int;
    def parse_match_stmt -> int;
    def parse_match_case -> int;
    def parse_pattern -> int;
    def parse_or_pattern -> int;
    def parse_single_pattern -> int;
    def parse_literal_pattern -> int;
    def parse_expression_pattern -> int;
    def parse_name_pattern -> int;
    def parse_sequence_pattern -> int;
    def parse_tuple_sequence_pattern -> int;
    def parse_mapping_pattern -> int;
    def parse_literal_for_mapping -> (int);
    def parse_class_pattern_args(
        names: list[int], dot_unis: (list[int] | None) = None
    ) -> int;

    def parse_switch_stmt -> int;
    def parse_switch_case -> int;
    def parse_return_stmt -> int;
    def parse_yield_stmt -> int;
    def parse_raise_stmt -> int;
    def parse_assert_stmt -> int;
    def parse_delete_stmt -> int;
    def parse_visit_stmt -> int;
    def parse_report_stmt -> int;
    def parse_assignment_with_target(target: int, require_semi: bool = True) -> int;
    def parse_ownership_prefix(kids: list) -> OwnershipKind;
    def parse_import_stmt -> int;
    def parse_from_path -> tuple[(int, bool)];
    def parse_import_items(kid: list, is_clib_import: bool) -> tuple[(list, list)];
    def parse_archetype -> int;
    def parse_archetype_member -> (int);
    def _skip_semicolons;
    def _error_unexpected_member;
    def parse_has_stmt -> int;
    def parse_has_var -> int;
    def parse_accessor -> int;
    def _consume_accessor_kind -> tuple[(str, LexToken)];
    def parse_ability -> int;
    def _parse_post_async_modifiers(
        is_override: bool,
        override_tok: (LexToken | None),
        is_static: bool,
        static_tok: (LexToken | None)
    ) -> tuple[(bool, (LexToken | None), bool, (LexToken | None))];

    def parse_func_signature -> int;
    def parse_func_params(kid: list) -> list;
    def parse_param_var -> int;
    def parse_enum -> int;
    def parse_enum_member -> int;
    def parse_test -> int;
    def parse_global_var -> int;
    def parse_global_var_assignment -> int;
    def parse_impl_def -> int;
    def _is_impl_enum_body -> bool;
    def parse_impl_target_name -> int;
    def parse_impl_enum_body -> list;
    def parse_sem_def -> int;
    def parse_type_alias -> int;
    def parse_type_params -> tuple[(list, list)];
}

def parse_source(
    tokens: list[LexToken], file_path: str, source_code: str
) -> tuple[(SyntaxArena, int, list[SrcDiag])] {
    parser = Parser(tokens=tokens, file_path=file_path, source_code=source_code);
    parser.parse();
    return (parser.b, parser.error_count, parser.diags);
}

def arena_strtab_blob(a: SyntaxArena) -> str {
    parts: list[str] = [];
    for entry in a.strtab {
        parts.append(f"{len(entry)}:{entry}");
    }
    return "".join(parts);
}


def parse_program(
    source: str, file_path: str
) -> tuple[(SyntaxArena, int, list[SrcDiag], list[CommentData], list[SrcDiag], int)] {
    (tokens, comments, lex_diags, lex_error_count) = tokenize_full(source, file_path);
    parser = Parser(tokens=tokens, file_path=file_path, source_code=source);
    parser.parse();
    return (
        parser.b,
        parser.error_count,
        parser.diags,
        comments,
        lex_diags,
        lex_error_count
    );
}
