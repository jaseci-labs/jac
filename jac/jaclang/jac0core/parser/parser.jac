"""Hand-written recursive descent parser for Jac.

This parser uses explicit precedence-level methods instead of a Pratt parser
for native compilation compatibility. Each precedence level is a separate
method, enabling direct function calls with no dynamic dispatch.

This parser outputs unitree.py AST nodes directly.
"""

import from .tokens { Token, TokenKind, SourceLoc }
import from .lexer { Lexer, LexerError }

# Import unitree classes from Python
import from jaclang.jac0core.unitree {
    UniNode,
    Token as UniToken,
    Expr
}
import from jaclang.jac0core.codeinfo { CodeLocInfo }
import from jaclang.jac0core.passes.transform { Alert }
import from jaclang.jac0core.unitree { Name, String, Int, Float, Bool, Null }
import from jaclang.jac0core.unitree {
    Ellipsis as EllipsisLit,
    BuiltinType,
    SpecialVarRef,
    EmptyToken,
    Semi
}
import from jaclang.jac0core.unitree {
    Module,
    Source,
    GlobalVars,
    Test,
    ModuleCode,
    PyInlineCode
}
import from jaclang.jac0core.unitree { ClientBlock, ServerBlock, NativeBlock }
import from jaclang.jac0core.unitree { Import, ModulePath, ModuleItem }
import from jaclang.jac0core.unitree { CommentToken }
import from jaclang.jac0core.unitree { Archetype, Ability, Enum, ImplDef, SemDef }
import from jaclang.jac0core.unitree {
    ArchHas,
    HasVar,
    SubTag,
    ParamVar,
    ParamKind,
    FuncSignature,
    EventSignature
}
import from jaclang.jac0core.unitree {
    IfStmt,
    ElseIf,
    ElseStmt,
    WhileStmt,
    InForStmt,
    IterForStmt
}
import from jaclang.jac0core.unitree {
    TryStmt,
    Except,
    FinallyStmt,
    WithStmt,
    ExprAsItem
}
import from jaclang.jac0core.unitree { MatchStmt, MatchCase, SwitchStmt, SwitchCase }
import from jaclang.jac0core.unitree {
    Assignment,
    ReturnStmt,
    YieldExpr,
    RaiseStmt,
    AssertStmt,
    DeleteStmt
}
import from jaclang.jac0core.unitree {
    CtrlStmt,
    ReportStmt,
    VisitStmt,
    DisengageStmt,
    ExprStmt
}
import from jaclang.jac0core.unitree { TypedCtxBlock, GlobalStmt, NonLocalStmt }
import from jaclang.jac0core.unitree {
    BinaryExpr,
    UnaryExpr,
    CompareExpr,
    BoolExpr,
    IfElseExpr
}
import from jaclang.jac0core.unitree {
    AtomTrailer,
    AtomUnit,
    FuncCall,
    IndexSlice,
    EdgeRefTrailer
}
import from jaclang.jac0core.unitree {
    ListVal,
    TupleVal,
    SetVal,
    DictVal,
    KVPair,
    KWPair
}
import from jaclang.jac0core.unitree {
    ListCompr,
    SetCompr,
    DictCompr,
    GenCompr,
    InnerCompr
}
import from jaclang.jac0core.unitree {
    FString,
    FormattedValue,
    MultiString,
    LambdaExpr
}
import from jaclang.jac0core.unitree { AwaitExpr, ConcurrentExpr }
import from jaclang.jac0core.unitree { EdgeOpRef, FilterCompr, AssignCompr }
import from jaclang.jac0core.unitree { ConnectOp, DisconnectOp }
import from jaclang.jac0core.unitree {
    MatchOr,
    MatchAs,
    MatchWild,
    MatchValue,
    MatchSingleton
}
import from jaclang.jac0core.unitree {
    MatchSequence,
    MatchMapping,
    MatchKVPair,
    MatchStar,
    MatchArch
}
import from jaclang.jac0core.unitree {
    JsxElement,
    JsxElementName,
    JsxSpreadAttribute,
    JsxNormalAttribute
}
import from jaclang.jac0core.unitree { JsxText, JsxExpression }

import from jaclang.jac0core.constant {
    Tokens as Tok,
    SymbolAccess,
    SymbolType,
    EdgeDir,
    CodeContext
}

obj ParseError {
    has message: str,
        loc: SourceLoc;

    def __str__ -> str {
        return f"ParseError at line {self.loc.line}: {self.message}";
    }
}

glob TOKEN_KIND_TO_TOK: dict[TokenKind, str] = {
         # Literals
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
         # Identifiers
         TokenKind.NAME: Tok.NAME.value,
         TokenKind.KWESC_NAME: Tok.KWESC_NAME.value,
         # Built-in Types
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
         # Keywords
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
         TokenKind.KW_GLOBAL_REF: Tok.GLOBAL_OP.value,
         TokenKind.KW_NONLOCAL: Tok.NONLOCAL_OP.value,
         TokenKind.KW_IMPORT: Tok.KW_IMPORT.value,
         TokenKind.KW_INCLUDE: Tok.KW_INCLUDE.value,
         TokenKind.KW_FROM: Tok.KW_FROM.value,
         TokenKind.KW_AS: Tok.KW_AS.value,
         TokenKind.KW_IF: Tok.KW_IF.value,
         TokenKind.KW_ELIF: Tok.KW_ELIF.value,
         TokenKind.KW_ELSE: Tok.KW_ELSE.value,
         TokenKind.KW_FOR: Tok.KW_FOR.value,
         TokenKind.KW_TO: Tok.KW_TO.value,
         TokenKind.KW_BY: Tok.KW_BY.value,
         TokenKind.KW_WHILE: Tok.KW_WHILE.value,
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
         TokenKind.KW_CLIENT: Tok.KW_CLIENT.value,
         TokenKind.KW_SERVER: Tok.KW_SERVER.value,
         TokenKind.KW_NATIVE: Tok.KW_NATIVE.value,
         TokenKind.KW_SELF: Tok.KW_SELF.value,
         TokenKind.KW_PROPS: Tok.KW_PROPS.value,
         TokenKind.KW_INIT: Tok.KW_INIT.value,
         TokenKind.KW_SUPER: Tok.KW_SUPER.value,
         TokenKind.KW_POST_INIT: Tok.KW_POST_INIT.value,
         # Delimiters
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
         # Assignment Operators
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
         # Comparison Operators
         TokenKind.EE: Tok.EE.value,
         TokenKind.NE: Tok.NE.value,
         TokenKind.LT: Tok.LT.value,
         TokenKind.GT: Tok.GT.value,
         TokenKind.LTE: Tok.LTE.value,
         TokenKind.GTE: Tok.GTE.value,
         # Arithmetic Operators
         TokenKind.PLUS: Tok.PLUS.value,
         TokenKind.MINUS: Tok.MINUS.value,
         TokenKind.STAR_MUL: Tok.STAR_MUL.value,
         TokenKind.DIV: Tok.DIV.value,
         TokenKind.FLOOR_DIV: Tok.FLOOR_DIV.value,
         TokenKind.MOD: Tok.MOD.value,
         TokenKind.STAR_POW: Tok.STAR_POW.value,
         # Bitwise Operators
         TokenKind.BW_AND: Tok.BW_AND.value,
         TokenKind.BW_OR: Tok.BW_OR.value,
         TokenKind.BW_XOR: Tok.BW_XOR.value,
         TokenKind.BW_NOT: Tok.BW_NOT.value,
         TokenKind.LSHIFT: Tok.LSHIFT.value,
         TokenKind.RSHIFT: Tok.RSHIFT.value,
         # Pipe Operators
         TokenKind.PIPE_FWD: Tok.PIPE_FWD.value,
         TokenKind.PIPE_BKWD: Tok.PIPE_BKWD.value,
         TokenKind.A_PIPE_FWD: Tok.A_PIPE_FWD.value,
         TokenKind.A_PIPE_BKWD: Tok.A_PIPE_BKWD.value,
         TokenKind.DOT_FWD: Tok.DOT_FWD.value,
         TokenKind.DOT_BKWD: Tok.DOT_BKWD.value,
         # Arrow Operators
         TokenKind.ARROW_L: Tok.ARROW_L.value,
         TokenKind.ARROW_R: Tok.ARROW_R.value,
         TokenKind.ARROW_BI: Tok.ARROW_BI.value,
         TokenKind.ARROW_L_P1: Tok.ARROW_L_P1.value,
         TokenKind.ARROW_L_P2: Tok.ARROW_L_P2.value,
         TokenKind.ARROW_R_P1: Tok.ARROW_R_P1.value,
         TokenKind.ARROW_R_P2: Tok.ARROW_R_P2.value,
         # Connect Arrows
         TokenKind.CARROW_L: Tok.CARROW_L.value,
         TokenKind.CARROW_R: Tok.CARROW_R.value,
         TokenKind.CARROW_BI: Tok.CARROW_BI.value,
         TokenKind.CARROW_L_P1: Tok.CARROW_L_P1.value,
         TokenKind.CARROW_L_P2: Tok.CARROW_L_P2.value,
         TokenKind.CARROW_R_P1: Tok.CARROW_R_P1.value,
         TokenKind.CARROW_R_P2: Tok.CARROW_R_P2.value,
         # Special Operators
         TokenKind.RETURN_HINT: Tok.RETURN_HINT.value,
         TokenKind.NULL_OK: Tok.NULL_OK.value,
         TokenKind.DECOR_OP: Tok.DECOR_OP.value,
         # F-String Tokens
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
         # EOF
         TokenKind.EOF: "EOF"
     };

obj Parser {
    has tokens: list[Token],
        pos: int = 0,
        _tokens_len: int = 0,
        errors: list[ParseError] = [],
        file_path: str = "<input>",
        source_code: str = "",
        source: Source | None = None,
        prog: object | None = None;

    def current -> Token;
    def peek(offset: int = 1) -> Token;
    def advance -> Token;
    def previous -> Token;
    def at_end -> bool;
    def check(kind: TokenKind) -> bool;
    def check_any(*kinds: TokenKind) -> bool;
    def check_name -> bool;
    def is_keyword_token -> bool;
    def get_source -> Source;
    def match_tok(kind: TokenKind) -> Token | None;
    def expect(kind: TokenKind) -> Token;
    def consume_uni(kind: TokenKind) -> UniToken;
    def expect_name -> Token;
    def error(message: str);
    def make_uni_token(tok: Token) -> UniToken;
    def make_name(tok: Token, is_enum_stmt: bool = False) -> Name;
    def make_special_name(tok: Token) -> Name;
    def make_name_or_special(tok: Token) -> Name;
    def parse_access_tag -> SubTag | None;
    def make_string(tok: Token) -> String;
    def make_string_from_value(value: str) -> String;
    def make_int(tok: Token) -> Int;
    def make_float(tok: Token) -> Float;
    def make_bool(tok: Token) -> Bool;
    def make_null(tok: Token) -> Null;
    def make_ellipsis(tok: Token) -> EllipsisLit;
    def gen_token(tok_type: str, value: str | None = None) -> UniToken;
    def make_semi -> Semi;
    def synchronize;
    def parse -> Module;
    def parse_module -> Module;
    def parse_expression -> Expr;
    def parse_concurrent_expr -> Expr;
    def parse_walrus_assign -> Expr;
    def parse_by_expr -> Expr;
    def parse_pipe -> Expr;
    def parse_pipe_back -> Expr;
    def parse_bitwise_or -> Expr;
    def parse_bitwise_xor -> Expr;
    def parse_bitwise_and -> Expr;
    def parse_shift -> Expr;
    def parse_logical_or -> Expr;
    def parse_logical_and -> Expr;
    def parse_logical_not -> Expr;
    def parse_compare -> Expr;
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
    def parse_call_args(kid: list) -> list;
    def parse_call_arg -> Expr | KWPair;
    def parse_filter_compr_inner -> FilterCompr;
    def parse_assign_compr_inner -> AssignCompr;
    def parse_atom -> Expr;
    def parse_fstring -> FString;
    def parse_list_or_compr -> Expr;
    def parse_dict_or_set -> Expr;
    def parse_dict_with_spread(lbrace_uni: UniToken) -> DictVal;
    def parse_edge_ref_chain -> Expr;
    def continue_edge_ref_chain(start_expr: Expr, lsquare_uni: UniToken) -> Expr;
    def parse_comprehension_clauses -> list;
    def parse_lambda_expr -> Expr;
    def parse_lambda_params(sig_kid: list) -> list;
    # JSX parsing
    def parse_jsx_element -> Expr;
    def parse_jsx_opening_element -> tuple;
    def parse_jsx_attributes -> list;
    def parse_jsx_children -> list;
    def parse_jsx_child -> Expr;
    def parse_element_stmt;
    def parse_client_block -> ClientBlock;
    def parse_server_block -> ServerBlock;
    def parse_native_block -> NativeBlock;
    def parse_module_code -> ModuleCode;
    def parse_code_block_stmts -> list;
    def parse_statement;
    def parse_if_stmt -> IfStmt;
    def parse_elif_stmt -> ElseIf;
    def parse_else_stmt -> ElseStmt;
    def parse_while_stmt -> WhileStmt;
    def parse_for_stmt;
    def parse_try_stmt -> TryStmt;
    def parse_except_handler -> Except;
    def parse_with_stmt -> WithStmt;
    def parse_match_stmt -> MatchStmt;
    def parse_match_case -> MatchCase;
    def parse_pattern;
    def parse_or_pattern;
    def parse_single_pattern;
    def parse_sequence_pattern;
    def parse_tuple_sequence_pattern;
    def parse_mapping_pattern;
    def parse_literal_for_mapping;
    def parse_class_pattern_args(names: list, dot_unis: list | None = None);
    def parse_switch_stmt -> SwitchStmt;
    def parse_switch_case -> SwitchCase;
    def parse_return_stmt -> ReturnStmt;
    def parse_yield_stmt -> YieldExpr;
    def parse_raise_stmt -> RaiseStmt;
    def parse_assert_stmt -> AssertStmt;
    def parse_delete_stmt -> DeleteStmt;
    def parse_global_stmt -> GlobalStmt;
    def parse_nonlocal_stmt -> NonLocalStmt;
    def parse_visit_stmt -> VisitStmt;
    def parse_report_stmt -> ReportStmt;
    def parse_assignment_with_target(target: Expr) -> Assignment;
    def parse_import_stmt -> Import;
    def parse_archetype -> Archetype;
    def parse_archetype_member;
    def parse_has_stmt -> ArchHas;
    def parse_has_var -> HasVar;
    def parse_ability -> Ability;
    def parse_func_signature -> FuncSignature;
    def parse_func_params(kid: list) -> list;
    def parse_enum -> Enum;
    def parse_enum_member -> Assignment;
    def parse_test -> Test;
    def parse_global_var -> GlobalVars;
    def parse_global_var_assignment -> Assignment;
    def parse_impl_def -> ImplDef;
    def parse_impl_target_name -> Name;
    def parse_impl_enum_body -> list;
    def parse_sem_def -> SemDef;
    def parse_dotted_name -> Expr;
}

def parse(
    source: str, file_path: str = "<input>", prog: object | None = None
) -> tuple[Module, list[ParseError], list[LexerError]] {
    lexer = Lexer(source=source, file_path=file_path);
    tokens = lexer.tokenize();
    parser = Parser(tokens=tokens, file_path=file_path, source_code=source, prog=prog);
    module = parser.parse();
    # Transfer captured comments from lexer to module source
    if module.source and lexer.comments {
        for cdata in lexer.comments {
            # cdata is (value, line, end_line, col_start, col_end, pos_start, pos_end, is_block)
            ct = CommentToken(
                orig_src=module.source,
                name="COMMENT",
                value=cdata[0],
                line=cdata[1],
                end_line=cdata[2],
                col_start=cdata[3],
                col_end=cdata[4],
                pos_start=cdata[5],
                pos_end=cdata[6],
                kid=[],
                is_inline=False
            );
            module.source.comments.append(ct);
        }
    }
    return (module, parser.errors, lexer.errors);
}
