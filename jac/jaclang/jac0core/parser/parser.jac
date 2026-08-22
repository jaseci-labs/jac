import from .tokens {
    LexToken,
    TokenKind,
    SourceLoc,
    SrcDiag,
    CommentData,
    is_special_var_kind
}
import from .lexer { tokenize_full }

import from jaclang.jac0core.unitree {
    Ability,
    AstDocNode,
    ArchHas,
    Archetype,
    AssignCompr,
    Assignment,
    AtomTrailer,
    AtomUnit,
    AwaitExpr,
    AwaitingClause,
    BinaryExpr,
    Bool,
    BoolExpr,
    BuiltinType,
    CastExpr,
    CfgExpr,
    CodeBlockStmt,
    CommentToken,
    CompareExpr,
    ConcurrentExpr,
    ConnectOp,
    ContextAwareNode,
    CtrlStmt,
    DeleteStmt,
    DictCompr,
    DictVal,
    DisconnectOp,
    DisengageStmt,
    EdgeOpRef,
    EdgeRefTrailer,
    ElseIf,
    ElseStmt,
    ElementStmt,
    EmptyToken,
    EnumBlockStmt,
    Enum,
    EventSignature,
    Except,
    Expr,
    ExprAsItem,
    ExprStmt,
    FString,
    FilterCompr,
    FinallyStmt,
    Float,
    ForeverStmt,
    FormattedValue,
    FuncCall,
    FuncSignature,
    GenCompr,
    GlobalVars,
    HasVar,
    IfElseExpr,
    IfStmt,
    ImplDef,
    Import,
    InForStmt,
    IndexSlice,
    InnerCompr,
    Int,
    IterForStmt,
    JsxAttribute,
    JsxChild,
    JsxComment,
    JsxElement,
    JsxElementName,
    JsxExpression,
    JsxNormalAttribute,
    JsxSlot,
    JsxSpreadAttribute,
    JsxText,
    KVPair,
    KWPair,
    LambdaExpr,
    ListCompr,
    ListVal,
    MatchArch,
    MatchAs,
    MatchCase,
    MatchKVPair,
    MatchMapping,
    MatchOr,
    MatchPattern,
    MatchSequence,
    MatchSingleton,
    MatchStar,
    MatchStmt,
    MatchValue,
    MatchWild,
    Module,
    ModuleCode,
    ModuleItem,
    ModulePath,
    MultiString,
    Name,
    NameAtom,
    Null,
    OpenStmt,
    ParamVar,
    PyInlineCode,
    RaiseStmt,
    ReportStmt,
    ReturnStmt,
    SemDef,
    Semi,
    SetCompr,
    SetVal,
    Slice,
    Source,
    SpecialVarRef,
    String,
    SubTag,
    SwitchCase,
    SwitchStmt,
    Test,
    Token,
    TryStmt,
    TupleVal,
    TypeAlias,
    TypeParam,
    TypedCtxBlock,
    UnaryExpr,
    UniNode,
    VisitStmt,
    WhileStmt,
    WithStmt,
    YieldExpr,
    AssertStmt
}
import from jaclang.jac0core.unitree { Ellipsis as EllipsisLit }

import from jaclang.jac0core.constant {
    Tokens as Tok,
    EdgeDir,
    CodeContext,
    OwnershipKind,
    ParamKind
}

glob TOKEN_KIND_TO_TOK: dict[TokenKind, str] = {
         TokenKind.INT: Tok.INT.value,
         TokenKind.HEX: Tok.HEX.value,
         TokenKind.BIN: Tok.BIN.value,
         TokenKind.OCT: Tok.OCT.value,
         TokenKind.FLOAT: Tok.FLOAT.value,
         TokenKind.STRING: Tok.STRING.value,
         TokenKind.BOOL: Tok.BOOL.value,
         TokenKind.NULL: Tok.NULL.value,
         TokenKind.ELLIPSIS: Tok.ELLIPSIS.value,
         TokenKind.PYNLINE: Tok.PYNLINE.value,
         TokenKind.NAME: Tok.NAME.value,
         TokenKind.KWESC_NAME: Tok.KWESC_NAME.value,
         TokenKind.TYP_STRING: Tok.TYP_STRING.value,
         TokenKind.TYP_INT: Tok.TYP_INT.value,
         TokenKind.TYP_FLOAT: Tok.TYP_FLOAT.value,
         TokenKind.TYP_LIST: Tok.TYP_LIST.value,
         TokenKind.TYP_TUPLE: Tok.TYP_TUPLE.value,
         TokenKind.TYP_SET: Tok.TYP_SET.value,
         TokenKind.TYP_DICT: Tok.TYP_DICT.value,
         TokenKind.TYP_BOOL: Tok.TYP_BOOL.value,
         TokenKind.TYP_BYTES: Tok.TYP_BYTES.value,
         TokenKind.TYP_ANY: Tok.TYP_ANY.value,
         TokenKind.TYP_TYPE: Tok.TYP_TYPE.value,
         TokenKind.TYP_I8: Tok.TYP_I8.value,
         TokenKind.TYP_U8: Tok.TYP_U8.value,
         TokenKind.TYP_I16: Tok.TYP_I16.value,
         TokenKind.TYP_U16: Tok.TYP_U16.value,
         TokenKind.TYP_I32: Tok.TYP_I32.value,
         TokenKind.TYP_U32: Tok.TYP_U32.value,
         TokenKind.TYP_I64: Tok.TYP_I64.value,
         TokenKind.TYP_U64: Tok.TYP_U64.value,
         TokenKind.TYP_F32: Tok.TYP_F32.value,
         TokenKind.TYP_F64: Tok.TYP_F64.value,
         TokenKind.KW_ABSTRACT: Tok.KW_ABSTRACT.value,
         TokenKind.KW_OBJECT: Tok.KW_OBJECT.value,
         TokenKind.KW_CLASS: Tok.KW_CLASS.value,
         TokenKind.KW_ENUM: Tok.KW_ENUM.value,
         TokenKind.KW_NODE: Tok.KW_NODE.value,
         TokenKind.KW_EDGE: Tok.KW_EDGE.value,
         TokenKind.KW_WALKER: Tok.KW_WALKER.value,
         TokenKind.KW_HAS: Tok.KW_HAS.value,
         TokenKind.KW_CAN: Tok.KW_CAN.value,
         TokenKind.KW_DEF: Tok.KW_DEF.value,
         TokenKind.KW_STATIC: Tok.KW_STATIC.value,
         TokenKind.KW_OVERRIDE: Tok.KW_OVERRIDE.value,
         TokenKind.KW_IMPL: Tok.KW_IMPL.value,
         TokenKind.KW_SEM: Tok.KW_SEM.value,
         TokenKind.KW_TEST: Tok.KW_TEST.value,
         TokenKind.KW_GLOBAL: Tok.KW_GLOBAL.value,
         TokenKind.KW_IMPORT: Tok.KW_IMPORT.value,
         TokenKind.KW_INCLUDE: Tok.KW_INCLUDE.value,
         TokenKind.KW_FROM: Tok.KW_FROM.value,
         TokenKind.KW_AS: Tok.KW_AS.value,
         TokenKind.KW_IF: Tok.KW_IF.value,
         TokenKind.KW_ELIF: Tok.KW_ELIF.value,
         TokenKind.KW_ELSE: Tok.KW_ELSE.value,
         TokenKind.KW_FOR: Tok.KW_FOR.value,
         TokenKind.KW_BY: Tok.KW_BY.value,
         TokenKind.KW_WHILE: Tok.KW_WHILE.value,
         TokenKind.KW_FOREVER: Tok.KW_FOREVER.value,
         TokenKind.KW_MATCH: Tok.KW_MATCH.value,
         TokenKind.KW_SWITCH: Tok.KW_SWITCH.value,
         TokenKind.KW_CASE: Tok.KW_CASE.value,
         TokenKind.KW_DEFAULT: Tok.KW_DEFAULT.value,
         TokenKind.KW_TRY: Tok.KW_TRY.value,
         TokenKind.KW_EXCEPT: Tok.KW_EXCEPT.value,
         TokenKind.KW_FINALLY: Tok.KW_FINALLY.value,
         TokenKind.KW_WITH: Tok.KW_WITH.value,
         TokenKind.KW_RETURN: Tok.KW_RETURN.value,
         TokenKind.KW_YIELD: Tok.KW_YIELD.value,
         TokenKind.KW_BREAK: Tok.KW_BREAK.value,
         TokenKind.KW_CONTINUE: Tok.KW_CONTINUE.value,
         TokenKind.KW_RAISE: Tok.KW_RAISE.value,
         TokenKind.KW_DELETE: Tok.KW_DELETE.value,
         TokenKind.KW_ASSERT: Tok.KW_ASSERT.value,
         TokenKind.KW_SKIP: Tok.KW_SKIP.value,
         TokenKind.KW_REPORT: Tok.KW_REPORT.value,
         TokenKind.KW_VISIT: Tok.KW_VISIT.value,
         TokenKind.KW_SPAWN: Tok.KW_SPAWN.value,
         TokenKind.KW_ENTRY: Tok.KW_ENTRY.value,
         TokenKind.KW_EXIT: Tok.KW_EXIT.value,
         TokenKind.KW_DISENGAGE: Tok.KW_DISENGAGE.value,
         TokenKind.KW_HERE: Tok.KW_HERE.value,
         TokenKind.KW_VISITOR: Tok.KW_VISITOR.value,
         TokenKind.KW_ROOT: Tok.KW_ROOT.value,
         TokenKind.KW_ASYNC: Tok.KW_ASYNC.value,
         TokenKind.KW_AWAIT: Tok.KW_AWAIT.value,
         TokenKind.KW_FLOW: Tok.KW_FLOW.value,
         TokenKind.KW_WAIT: Tok.KW_WAIT.value,
         TokenKind.KW_AND: Tok.KW_AND.value,
         TokenKind.KW_OR: Tok.KW_OR.value,
         TokenKind.KW_NOT: Tok.NOT.value,
         TokenKind.KW_IN: Tok.KW_IN.value,
         TokenKind.KW_IS: Tok.KW_IS.value,
         TokenKind.KW_NIN: Tok.KW_NIN.value,
         TokenKind.KW_ISN: Tok.KW_ISN.value,
         TokenKind.KW_LAMBDA: Tok.KW_LAMBDA.value,
         TokenKind.KW_PUB: Tok.KW_PUB.value,
         TokenKind.KW_PRIV: Tok.KW_PRIV.value,
         TokenKind.KW_PROT: Tok.KW_PROT.value,
         TokenKind.KW_SELF: Tok.KW_SELF.value,
         TokenKind.KW_PROPS: Tok.KW_PROPS.value,
         TokenKind.KW_INIT: Tok.KW_INIT.value,
         TokenKind.KW_SUPER: Tok.KW_SUPER.value,
         TokenKind.KW_POST_INIT: Tok.KW_POST_INIT.value,
         TokenKind.LPAREN: Tok.LPAREN.value,
         TokenKind.RPAREN: Tok.RPAREN.value,
         TokenKind.LBRACE: Tok.LBRACE.value,
         TokenKind.RBRACE: Tok.RBRACE.value,
         TokenKind.LSQUARE: Tok.LSQUARE.value,
         TokenKind.RSQUARE: Tok.RSQUARE.value,
         TokenKind.COMMA: Tok.COMMA.value,
         TokenKind.COLON: Tok.COLON.value,
         TokenKind.SEMI: Tok.SEMI.value,
         TokenKind.DOT: Tok.DOT.value,
         TokenKind.EQ: Tok.EQ.value,
         TokenKind.WALRUS_EQ: Tok.WALRUS_EQ.value,
         TokenKind.ADD_EQ: Tok.ADD_EQ.value,
         TokenKind.SUB_EQ: Tok.SUB_EQ.value,
         TokenKind.MUL_EQ: Tok.MUL_EQ.value,
         TokenKind.DIV_EQ: Tok.DIV_EQ.value,
         TokenKind.FLOOR_DIV_EQ: Tok.FLOOR_DIV_EQ.value,
         TokenKind.MOD_EQ: Tok.MOD_EQ.value,
         TokenKind.STAR_POW_EQ: Tok.STAR_POW_EQ.value,
         TokenKind.BW_AND_EQ: Tok.BW_AND_EQ.value,
         TokenKind.BW_OR_EQ: Tok.BW_OR_EQ.value,
         TokenKind.BW_XOR_EQ: Tok.BW_XOR_EQ.value,
         TokenKind.LSHIFT_EQ: Tok.LSHIFT_EQ.value,
         TokenKind.RSHIFT_EQ: Tok.RSHIFT_EQ.value,
         TokenKind.MATMUL_EQ: Tok.MATMUL_EQ.value,
         TokenKind.EE: Tok.EE.value,
         TokenKind.NE: Tok.NE.value,
         TokenKind.LT: Tok.LT.value,
         TokenKind.GT: Tok.GT.value,
         TokenKind.LTE: Tok.LTE.value,
         TokenKind.GTE: Tok.GTE.value,
         TokenKind.PLUS: Tok.PLUS.value,
         TokenKind.MINUS: Tok.MINUS.value,
         TokenKind.STAR_MUL: Tok.STAR_MUL.value,
         TokenKind.DIV: Tok.DIV.value,
         TokenKind.FLOOR_DIV: Tok.FLOOR_DIV.value,
         TokenKind.MOD: Tok.MOD.value,
         TokenKind.STAR_POW: Tok.STAR_POW.value,
         TokenKind.BW_AND: Tok.BW_AND.value,
         TokenKind.BW_OR: Tok.BW_OR.value,
         TokenKind.BW_XOR: Tok.BW_XOR.value,
         TokenKind.BW_NOT: Tok.BW_NOT.value,
         TokenKind.LSHIFT: Tok.LSHIFT.value,
         TokenKind.RSHIFT: Tok.RSHIFT.value,
         TokenKind.PIPE_FWD: Tok.PIPE_FWD.value,
         TokenKind.PIPE_BKWD: Tok.PIPE_BKWD.value,
         TokenKind.A_PIPE_FWD: Tok.A_PIPE_FWD.value,
         TokenKind.A_PIPE_BKWD: Tok.A_PIPE_BKWD.value,
         TokenKind.DOT_FWD: Tok.DOT_FWD.value,
         TokenKind.DOT_BKWD: Tok.DOT_BKWD.value,
         TokenKind.ARROW_L: Tok.ARROW_L.value,
         TokenKind.ARROW_R: Tok.ARROW_R.value,
         TokenKind.ARROW_BI: Tok.ARROW_BI.value,
         TokenKind.ARROW_L_P1: Tok.ARROW_L_P1.value,
         TokenKind.ARROW_L_P2: Tok.ARROW_L_P2.value,
         TokenKind.ARROW_R_P1: Tok.ARROW_R_P1.value,
         TokenKind.ARROW_R_P2: Tok.ARROW_R_P2.value,
         TokenKind.CARROW_L: Tok.CARROW_L.value,
         TokenKind.CARROW_R: Tok.CARROW_R.value,
         TokenKind.CARROW_BI: Tok.CARROW_BI.value,
         TokenKind.CARROW_L_P1: Tok.CARROW_L_P1.value,
         TokenKind.CARROW_L_P2: Tok.CARROW_L_P2.value,
         TokenKind.CARROW_R_P1: Tok.CARROW_R_P1.value,
         TokenKind.CARROW_R_P2: Tok.CARROW_R_P2.value,
         TokenKind.RETURN_HINT: Tok.RETURN_HINT.value,
         TokenKind.NULL_OK: Tok.NULL_OK.value,
         TokenKind.DECOR_OP: Tok.DECOR_OP.value,
         TokenKind.F_DQ_START: Tok.F_DQ_START.value,
         TokenKind.F_SQ_START: Tok.F_SQ_START.value,
         TokenKind.F_TDQ_START: Tok.F_TDQ_START.value,
         TokenKind.F_TSQ_START: Tok.F_TSQ_START.value,
         TokenKind.F_DQ_END: Tok.F_DQ_END.value,
         TokenKind.F_SQ_END: Tok.F_SQ_END.value,
         TokenKind.F_TDQ_END: Tok.F_TDQ_END.value,
         TokenKind.F_TSQ_END: Tok.F_TSQ_END.value,
         TokenKind.D_LBRACE: Tok.D_LBRACE.value,
         TokenKind.D_RBRACE: Tok.D_RBRACE.value,
         TokenKind.EOF: "EOF"
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

def _test_ident_from_desc(desc_text: str) -> str {
    ident_chars: list[str] = [];
    prev_sep = False;
    for ch in desc_text {
        is_word = ("a" <= ch and ch <= "z")
            or ("A" <= ch and ch <= "Z")
            or ("0" <= ch and ch <= "9");
        if is_word {
            ident_chars.append(ch);
            prev_sep = False;
        } elif not prev_sep {
            ident_chars.append("_");
            prev_sep = True;
        }
    }
    ident: str = str("".join(ident_chars));
    if ident.startswith("_") {
        ident = ident[1:];
    }
    if ident.endswith("_") {
        ident = ident[:-1];
    }
    return ident.lower();
}

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
    def consume_uni(kind: TokenKind) -> Token;
    def expect_name(context: str = "identifier") -> LexToken;
    def error(message: str);
    def emit_diag(
        message: str, code_str: str, loc: SourceLoc | None = None, help: str = ""
    );

    def emit_warn(
        message: str, code_str: str, loc: SourceLoc | None = None, help: str = ""
    );

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
    def parse_in_target(example: str) -> Expr;
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

    def parse_ownership_prefix(kids: list[UniNode]) -> OwnershipKind;
    def parse_import_stmt -> Import;
    def parse_from_path -> tuple[(ModulePath | None, bool)];
    def parse_import_items(
        kid: list[UniNode], is_clib_import: bool
    ) -> tuple[(list, list)];

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
    def parse_impl_def -> ImplDef;
    def _is_impl_enum_body -> bool;
    def parse_impl_target_name -> NameAtom;
    def parse_impl_enum_body -> tuple[(list[Assignment], list[Token])];
    def parse_sem_def -> SemDef;
    def parse_type_alias -> TypeAlias;
    def parse_type_params -> tuple[(list, list)];
}

def parse_source(
    tokens: list[LexToken], file_path: str, source_code: str
) -> tuple[(Module, int, list[SrcDiag])] {
    parser = Parser(tokens=tokens, file_path=file_path, source_code=source_code);
    mod = parser.parse();
    return (mod, parser.error_count, parser.diags);
}


def parse_program(
    source: str, file_path: str
) -> tuple[(Module, int, list[SrcDiag], list[CommentData], list[SrcDiag], int)] {
    (tokens, comments, lex_diags, lex_error_count) = tokenize_full(source, file_path);
    parser = Parser(tokens=tokens, file_path=file_path, source_code=source);
    mod = parser.parse();
    return (
        mod,
        parser.error_count,
        parser.diags,
        comments,
        lex_diags,
        lex_error_count
    );
}
