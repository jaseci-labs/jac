"""Hand-written recursive descent parser for Jac.

This parser uses explicit precedence-level methods instead of a Pratt parser
for native compilation compatibility. Each precedence level is a separate
method, enabling direct function calls with no dynamic dispatch.

This parser outputs unitree.py AST nodes directly.
"""

import from .tokens { Token, TokenKind, SourceLoc }
import from .lexer { Lexer, LexerError }

# Import unitree classes from Python
import from jaclang.pycore.unitree {
    UniNode,
    Token as UniToken,
    Expr
}
import from jaclang.pycore.unitree { Name, String, Int, Float, Bool, Null }
import from jaclang.pycore.unitree {
    Ellipsis as EllipsisLit,
    BuiltinType,
    SpecialVarRef,
    EmptyToken,
    Semi
}
import from jaclang.pycore.unitree {
    Module,
    Source,
    GlobalVars,
    Test,
    ModuleCode,
    PyInlineCode
}
import from jaclang.pycore.unitree { ClientBlock, ServerBlock, NativeBlock }
import from jaclang.pycore.unitree { Import, ModulePath, ModuleItem }
import from jaclang.pycore.unitree { Archetype, Ability, Enum, ImplDef, SemDef }
import from jaclang.pycore.unitree {
    ArchHas,
    HasVar,
    SubTag,
    ParamVar,
    FuncSignature,
    EventSignature
}
import from jaclang.pycore.unitree {
    IfStmt,
    ElseIf,
    ElseStmt,
    WhileStmt,
    InForStmt,
    IterForStmt
}
import from jaclang.pycore.unitree {
    TryStmt,
    Except,
    FinallyStmt,
    WithStmt,
    ExprAsItem
}
import from jaclang.pycore.unitree { MatchStmt, MatchCase, SwitchStmt, SwitchCase }
import from jaclang.pycore.unitree {
    Assignment,
    ReturnStmt,
    YieldExpr,
    RaiseStmt,
    AssertStmt,
    DeleteStmt
}
import from jaclang.pycore.unitree { CtrlStmt, ReportStmt, VisitStmt, DisengageStmt }
import from jaclang.pycore.unitree { TypedCtxBlock, GlobalStmt, NonLocalStmt }
import from jaclang.pycore.unitree {
    BinaryExpr,
    UnaryExpr,
    CompareExpr,
    BoolExpr,
    IfElseExpr
}
import from jaclang.pycore.unitree {
    AtomTrailer,
    AtomUnit,
    FuncCall,
    IndexSlice,
    Slice
}
import from jaclang.pycore.unitree {
    ListVal,
    TupleVal,
    SetVal,
    DictVal,
    KVPair,
    KWPair
}
import from jaclang.pycore.unitree {
    ListCompr,
    SetCompr,
    DictCompr,
    GenCompr,
    InnerCompr
}
import from jaclang.pycore.unitree { FString, FormattedValue, MultiString, LambdaExpr }
import from jaclang.pycore.unitree { AwaitExpr, ConcurrentExpr, TypeRef }
import from jaclang.pycore.unitree {
    EdgeOpRef,
    FilterCompr as UniFilterCompr,
    AssignCompr as UniAssignCompr
}
import from jaclang.pycore.unitree { ConnectOp, DisconnectOp }
import from jaclang.pycore.unitree {
    MatchOr,
    MatchAs,
    MatchWild,
    MatchValue,
    MatchSingleton
}
import from jaclang.pycore.unitree {
    MatchSequence,
    MatchMapping,
    MatchKVPair,
    MatchStar,
    MatchArch
}
import from jaclang.pycore.unitree {
    JsxElement,
    JsxElementName,
    JsxSpreadAttribute,
    JsxNormalAttribute
}
import from jaclang.pycore.unitree { JsxText, JsxExpression }

import from jaclang.pycore.constant { Tokens as Tok, SymbolAccess, SymbolType }
import from jaclang.pycore.codeinfo { CodeLocInfo }

# =============================================================================
# Parser Error
# =============================================================================
obj ParseError {
    has message: str,
        loc: SourceLoc;

    def __str__ -> str {
        return f"ParseError at line {self.loc.line}: {self.message}";
    }
}

# =============================================================================
# Token Kind to Tok Mapping
# =============================================================================
glob TOKEN_KIND_TO_TOK:
         dict[TokenKind, str] = {
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
         TokenKind.TYPE_OP: Tok.TYPE_OP.value,
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

# =============================================================================
# Parser
# =============================================================================
obj Parser {
    has tokens: list[Token],
        pos: int = 0,
        errors: list[ParseError] = [],
        file_path: str = "<input>",
        source_code: str = "",
        source: Source | None = None;

    # -------------------------------------------------------------------------
    # Token Access
    # -------------------------------------------------------------------------
    def current -> Token {
        if self.pos < len(self.tokens) {
            return self.tokens[self.pos];
        }
        return self.tokens[-1];
    }

    def peek(offset: int = 1) -> Token {
        idx = self.pos + offset;
        if idx < len(self.tokens) {
            return self.tokens[idx];
        }
        return self.tokens[-1];
    }

    def advance -> Token {
        tok = self.current();
        if self.pos < len(self.tokens) - 1 {
            self.pos += 1;
        }
        return tok;
    }

    def previous -> Token {
        if self.pos > 0 {
            return self.tokens[self.pos - 1];
        }
        return self.tokens[0];
    }

    def at_end -> bool {
        return self.current().kind == TokenKind.EOF;
    }

    def check(kind: TokenKind) -> bool {
        return self.current().kind == kind;
    }

    def check_any(*kinds: TokenKind) -> bool {
        return self.current().kind in kinds;
    }

    def match_tok(kind: TokenKind) -> Token | None {
        if self.check(kind) {
            return self.advance();
        }
        return None;
    }

    def expect(kind: TokenKind) -> Token {
        if self.check(kind) {
            return self.advance();
        }
        self.error(f"Expected {kind}, got {self.current().kind}");
        return self.current();
    }

    def error(message: str) {
        self.errors.append(ParseError(message=message, loc=self.current().loc));
    }

    # -------------------------------------------------------------------------
    # UniToken Creation
    # -------------------------------------------------------------------------
    def make_uni_token(tok: Token) -> UniToken {
        # Convert parser Token into unitree UniToken
        tok_name = TOKEN_KIND_TO_TOK.get(tok.kind, tok.kind.value);
        return UniToken(
            orig_src=self.source,
            name=tok_name,
            value=tok.value,
            line=tok.loc.line,
            end_line=tok.loc.end_line,
            col_start=tok.loc.col_start,
            col_end=tok.loc.col_end,
            pos_start=tok.loc.pos_start,
            pos_end=tok.loc.pos_end
        );
    }

    def make_name(tok: Token, is_enum_stmt: bool = False) -> Name {
        # Create a unitree Name from a token
        return Name(
            orig_src=self.source,
            name=Tok.NAME.value,
            value=tok.value,
            line=tok.loc.line,
            end_line=tok.loc.end_line,
            col_start=tok.loc.col_start,
            col_end=tok.loc.col_end,
            pos_start=tok.loc.pos_start,
            pos_end=tok.loc.pos_end,
            is_enum_stmt=is_enum_stmt
        );
    }

    def make_string(tok: Token) -> String {
        # Create a unitree String from a token
        return String(
            orig_src=self.source,
            name=Tok.STRING.value,
            value=tok.value,
            line=tok.loc.line,
            end_line=tok.loc.end_line,
            col_start=tok.loc.col_start,
            col_end=tok.loc.col_end,
            pos_start=tok.loc.pos_start,
            pos_end=tok.loc.pos_end
        );
    }

    def make_int(tok: Token) -> Int {
        # Create a unitree Int from a token
        return Int(
            orig_src=self.source,
            name=Tok.INT.value,
            value=tok.value,
            line=tok.loc.line,
            end_line=tok.loc.end_line,
            col_start=tok.loc.col_start,
            col_end=tok.loc.col_end,
            pos_start=tok.loc.pos_start,
            pos_end=tok.loc.pos_end
        );
    }

    def make_float(tok: Token) -> Float {
        # Create a unitree Float from a token
        return Float(
            orig_src=self.source,
            name=Tok.FLOAT.value,
            value=tok.value,
            line=tok.loc.line,
            end_line=tok.loc.end_line,
            col_start=tok.loc.col_start,
            col_end=tok.loc.col_end,
            pos_start=tok.loc.pos_start,
            pos_end=tok.loc.pos_end
        );
    }

    def make_bool(tok: Token) -> Bool {
        # Create a unitree Bool from a token
        return Bool(
            orig_src=self.source,
            name=Tok.BOOL.value,
            value=tok.value,
            line=tok.loc.line,
            end_line=tok.loc.end_line,
            col_start=tok.loc.col_start,
            col_end=tok.loc.col_end,
            pos_start=tok.loc.pos_start,
            pos_end=tok.loc.pos_end
        );
    }

    def make_null(tok: Token) -> Null {
        # Create a unitree Null from a token
        return Null(
            orig_src=self.source,
            name=Tok.NULL.value,
            value=tok.value,
            line=tok.loc.line,
            end_line=tok.loc.end_line,
            col_start=tok.loc.col_start,
            col_end=tok.loc.col_end,
            pos_start=tok.loc.pos_start,
            pos_end=tok.loc.pos_end
        );
    }

    def make_ellipsis(tok: Token) -> EllipsisLit {
        # Create a unitree Ellipsis from a token
        return EllipsisLit(
            orig_src=self.source,
            name=Tok.ELLIPSIS.value,
            value=tok.value,
            line=tok.loc.line,
            end_line=tok.loc.end_line,
            col_start=tok.loc.col_start,
            col_end=tok.loc.col_end,
            pos_start=tok.loc.pos_start,
            pos_end=tok.loc.pos_end
        );
    }

    def gen_token(tok_type: str, value: str | None = None) -> UniToken {
        # Generate a synthetic token for kid list construction
        cur = self.current();
        return UniToken(
            orig_src=self.source,
            name=tok_type,
            value=value or tok_type,
            line=cur.loc.line,
            end_line=cur.loc.end_line,
            col_start=cur.loc.col_start,
            col_end=cur.loc.col_end,
            pos_start=cur.loc.pos_start,
            pos_end=cur.loc.pos_end
        );
    }

    # -------------------------------------------------------------------------
    # Synchronization (Error Recovery)
    # -------------------------------------------------------------------------
    def synchronize {
        self.advance();

        while not self.at_end() {
            if self.check_any(
                TokenKind.KW_IF,
                TokenKind.KW_WHILE,
                TokenKind.KW_FOR,
                TokenKind.KW_DEF,
                TokenKind.KW_CAN,
                TokenKind.KW_OBJECT,
                TokenKind.KW_NODE,
                TokenKind.KW_EDGE,
                TokenKind.KW_WALKER,
                TokenKind.KW_CLASS,
                TokenKind.KW_ENUM,
                TokenKind.KW_IMPORT,
                TokenKind.KW_RETURN,
                TokenKind.RBRACE,
                TokenKind.SEMI
            ) {
                return;
            }
            self.advance();
        }
    }

    # -------------------------------------------------------------------------
    # Entry Point
    # -------------------------------------------------------------------------
    def parse -> Module {
        return self.parse_module();
    }

    def parse_module -> Module {
        self.source = Source(self.file_path, self.source_code);

        doc: String | None = None;
        body: list = [];
        terminals: list = [];

        for tok in self.tokens {
            terminals.append(self.make_uni_token(tok));
        }

        if self.check(TokenKind.STRING) {
            tok = self.advance();
            doc = self.make_string(tok);
        }

        while not self.at_end() {
            stmt = self.parse_element_stmt();
            if stmt is not None {
                body.append(stmt);
            }
        }

        kid: list = [];
        if doc {
            kid.append(doc);
        }
        kid.extend(body);
        if len(kid) == 0 {
            kid.append(EmptyToken());
        }

        return Module(
            name=self.file_path,
            source=self.source,
            doc=doc,
            body=body,
            terminals=terminals,
            kid=kid
        );
    }

    # =========================================================================
    # EXPRESSION PARSING
    # =========================================================================
    def parse_expression -> Expr {
        if self.check(TokenKind.KW_LAMBDA) {
            return self.parse_lambda_expr();
        }
        expr = self.parse_concurrent_expr();
        if self.match_tok(TokenKind.KW_IF) {
            condition = self.parse_expression();
            self.expect(TokenKind.KW_ELSE);
            else_value = self.parse_expression();
            return IfElseExpr(
                condition=condition,
                value=expr,
                else_value=else_value,
                kid=[expr, condition, else_value]
            );
        }
        return expr;
    }

    def parse_concurrent_expr -> Expr {
        if self.check_any(TokenKind.KW_FLOW, TokenKind.KW_WAIT) {
            tok = self.advance();
            target = self.parse_walrus_assign();
            uni_tok = self.make_uni_token(tok);
            return ConcurrentExpr(tok=uni_tok, target=target, kid=[uni_tok, target]);
        }
        return self.parse_walrus_assign();
    }

    def parse_walrus_assign -> Expr {
        expr = self.parse_by_expr();
        if self.check(TokenKind.WALRUS_EQ) {
            walrus_tok = self.advance();
            value = self.parse_by_expr();
            op = self.make_uni_token(walrus_tok);
            return Assignment(
                target=[expr],
                value=value,
                type_tag=None,
                kid=[expr, op, value],
                mutable=True,
                aug_op=None,
                is_enum_stmt=False
            );
        }
        return expr;
    }

    def parse_by_expr -> Expr {
        left = self.parse_pipe();
        if self.match_tok(TokenKind.KW_BY) {
            right = self.parse_by_expr();
            by_tok = self.gen_token(Tok.KW_BY.value, "by");
            return BinaryExpr(
                left=left, op=by_tok, right=right, kid=[left, by_tok, right]
            );
        }
        return left;
    }

    def parse_pipe -> Expr {
        left = self.parse_pipe_back();
        while self.match_tok(TokenKind.PIPE_FWD) {
            op = self.make_uni_token(self.previous());
            right = self.parse_pipe_back();
            left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
        }
        return left;
    }

    def parse_pipe_back -> Expr {
        left = self.parse_bitwise_or();
        while self.match_tok(TokenKind.PIPE_BKWD) {
            op = self.make_uni_token(self.previous());
            right = self.parse_bitwise_or();
            left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
        }
        return left;
    }

    def parse_bitwise_or -> Expr {
        left = self.parse_bitwise_xor();
        while self.match_tok(TokenKind.BW_OR) {
            op = self.make_uni_token(self.previous());
            right = self.parse_bitwise_xor();
            left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
        }
        return left;
    }

    def parse_bitwise_xor -> Expr {
        left = self.parse_bitwise_and();
        while self.match_tok(TokenKind.BW_XOR) {
            op = self.make_uni_token(self.previous());
            right = self.parse_bitwise_and();
            left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
        }
        return left;
    }

    def parse_bitwise_and -> Expr {
        left = self.parse_shift();
        while self.match_tok(TokenKind.BW_AND) {
            op = self.make_uni_token(self.previous());
            right = self.parse_shift();
            left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
        }
        return left;
    }

    def parse_shift -> Expr {
        left = self.parse_logical_or();
        while self.check_any(TokenKind.LSHIFT, TokenKind.RSHIFT) {
            tok = self.advance();
            op = self.make_uni_token(tok);
            right = self.parse_logical_or();
            left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
        }
        return left;
    }

    def parse_logical_or -> Expr {
        left = self.parse_logical_and();
        while self.match_tok(TokenKind.KW_OR) {
            values = [left];
            op = self.make_uni_token(self.previous());
            while True {
                values.append(self.parse_logical_and());
                if not self.match_tok(TokenKind.KW_OR) {
                    break;
                }
            }
            kid: list = [];
            for (i, v) in enumerate(values) {
                kid.append(v);
                if i < len(values) - 1 {
                    kid.append(op);
                }
            }
            left = BoolExpr(op=op, values=values, kid=kid);
        }
        return left;
    }

    def parse_logical_and -> Expr {
        left = self.parse_logical_not();
        while self.match_tok(TokenKind.KW_AND) {
            values = [left];
            op = self.make_uni_token(self.previous());
            while True {
                values.append(self.parse_logical_not());
                if not self.match_tok(TokenKind.KW_AND) {
                    break;
                }
            }
            kid: list = [];
            for (i, v) in enumerate(values) {
                kid.append(v);
                if i < len(values) - 1 {
                    kid.append(op);
                }
            }
            left = BoolExpr(op=op, values=values, kid=kid);
        }
        return left;
    }

    def parse_logical_not -> Expr {
        if self.match_tok(TokenKind.KW_NOT) {
            op = self.make_uni_token(self.previous());
            operand = self.parse_logical_not();
            return UnaryExpr(operand=operand, op=op, kid=[op, operand]);
        }
        return self.parse_compare();
    }

    def parse_compare -> Expr {
        left = self.parse_arithmetic();
        if self.check_any(
            TokenKind.EE,
            TokenKind.NE,
            TokenKind.LT,
            TokenKind.GT,
            TokenKind.LTE,
            TokenKind.GTE,
            TokenKind.KW_IN,
            TokenKind.KW_IS,
            TokenKind.KW_NIN,
            TokenKind.KW_ISN
        ) {
            rights: list = [];
            ops: list = [];
            kid: list = [left];
            while self.check_any(
                TokenKind.EE,
                TokenKind.NE,
                TokenKind.LT,
                TokenKind.GT,
                TokenKind.LTE,
                TokenKind.GTE,
                TokenKind.KW_IN,
                TokenKind.KW_IS,
                TokenKind.KW_NIN,
                TokenKind.KW_ISN
            ) {
                op_tok = self.advance();
                op = self.make_uni_token(op_tok);
                ops.append(op);
                kid.append(op);
                right = self.parse_arithmetic();
                rights.append(right);
                kid.append(right);
            }
            return CompareExpr(left=left, rights=rights, ops=ops, kid=kid);
        }
        return left;
    }

    def parse_arithmetic -> Expr {
        left = self.parse_term();
        while self.check_any(TokenKind.PLUS, TokenKind.MINUS) {
            tok = self.advance();
            op = self.make_uni_token(tok);
            right = self.parse_term();
            left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
        }
        return left;
    }

    def parse_term -> Expr {
        left = self.parse_power();
        while self.check_any(
            TokenKind.STAR_MUL,
            TokenKind.DIV,
            TokenKind.FLOOR_DIV,
            TokenKind.MOD,
            TokenKind.DECOR_OP
        ) {
            tok = self.advance();
            op = self.make_uni_token(tok);
            right = self.parse_power();
            left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
        }
        return left;
    }

    def parse_power -> Expr {
        left = self.parse_factor();
        if self.match_tok(TokenKind.STAR_POW) {
            op = self.make_uni_token(self.previous());
            right = self.parse_power();
            left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
        }
        return left;
    }

    def parse_factor -> Expr {
        if self.check_any(TokenKind.BW_NOT, TokenKind.MINUS, TokenKind.PLUS) {
            tok = self.advance();
            op = self.make_uni_token(tok);
            operand = self.parse_factor();
            return UnaryExpr(operand=operand, op=op, kid=[op, operand]);
        }
        return self.parse_atomic_pipe();
    }

    def parse_atomic_pipe -> Expr {
        left = self.parse_atomic_pipe_back();
        while self.match_tok(TokenKind.A_PIPE_FWD) {
            op = self.make_uni_token(self.previous());
            right = self.parse_atomic_pipe_back();
            left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
        }
        return left;
    }

    def parse_atomic_pipe_back -> Expr {
        left = self.parse_unpack();
        while self.match_tok(TokenKind.A_PIPE_BKWD) {
            op = self.make_uni_token(self.previous());
            right = self.parse_unpack();
            left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
        }
        return left;
    }

    def parse_unpack -> Expr {
        if self.match_tok(TokenKind.STAR_MUL) {
            op = self.make_uni_token(self.previous());
            target = self.parse_ref();
            return UnaryExpr(operand=target, op=op, kid=[op, target]);
        }
        return self.parse_ref();
    }

    def parse_ref -> Expr {
        if self.match_tok(TokenKind.BW_AND) {
            op = self.make_uni_token(self.previous());
            target = self.parse_await_expr();
            return UnaryExpr(operand=target, op=op, kid=[op, target]);
        }
        return self.parse_await_expr();
    }

    def parse_await_expr -> Expr {
        if self.match_tok(TokenKind.KW_AWAIT) {
            await_tok = self.make_uni_token(self.previous());
            expr = self.parse_pipe_call();
            return AwaitExpr(expr=expr, kid=[await_tok, expr]);
        }
        return self.parse_pipe_call();
    }

    def parse_pipe_call -> Expr {
        if self.check_any(TokenKind.PIPE_FWD, TokenKind.A_PIPE_FWD, TokenKind.KW_SPAWN) {
            tok = self.advance();
            op = self.make_uni_token(tok);
            target = self.parse_atomic_chain();
            return UnaryExpr(operand=target, op=op, kid=[op, target]);
        }
        return self.parse_atomic_chain();
    }

    def parse_atomic_chain -> Expr {
        expr = self.parse_atom();
        while True {
            if self.match_tok(TokenKind.DOT) or self.match_tok(TokenKind.NULL_OK) {
                null_ok = self.previous().kind == TokenKind.NULL_OK;
                if null_ok and self.check(TokenKind.DOT) {
                    self.advance();
                }
                if self.check(TokenKind.NAME) {
                    name_tok = self.advance();
                    attr = self.make_name(name_tok);
                    kid: list = [expr];
                    if null_ok {
                        kid.append(self.gen_token(Tok.NULL_OK.value, "?"));
                    }
                    kid.append(self.gen_token(Tok.DOT.value, "."));
                    kid.append(attr);
                    expr = AtomTrailer(value=expr, kid=kid);
                }
            } elif self.match_tok(TokenKind.LPAREN) {
                args = self.parse_call_args();
                self.expect(TokenKind.RPAREN);
                kid = [expr, self.gen_token(Tok.LPAREN.value, "(")];
                kid.extend(args);
                kid.append(self.gen_token(Tok.RPAREN.value, ")"));
                expr = FuncCall(target=expr, params=args, genai_call=None, kid=kid);
            } elif self.match_tok(TokenKind.LSQUARE) {
                index = self.parse_expression();
                self.expect(TokenKind.RSQUARE);
                slices = [Slice(start=None, stop=index, step=None, is_range=False)];
                kid = [
                    expr,
                    self.gen_token(Tok.LSQUARE.value, "["),
                    index,
                    self.gen_token(Tok.RSQUARE.value, "]")
                ];
                expr = IndexSlice(slices=slices, is_range=False, kid=kid);
            } else {
                break;
            }
        }
        return expr;
    }

    def parse_call_args -> list {
        args: list = [];
        if self.check(TokenKind.RPAREN) {
            return args;
        }
        args.append(self.parse_expression());
        while self.match_tok(TokenKind.COMMA) {
            if self.check(TokenKind.RPAREN) {
                break;
            }
            args.append(self.parse_expression());
        }
        return args;
    }

    def parse_atom -> Expr {
        if self.check(TokenKind.INT) {
            tok = self.advance();
            return self.make_int(tok);
        }
        if self.check_any(TokenKind.HEX, TokenKind.BIN, TokenKind.OCT) {
            tok = self.advance();
            return self.make_int(tok);
        }
        if self.check(TokenKind.FLOAT) {
            tok = self.advance();
            return self.make_float(tok);
        }
        if self.check(TokenKind.STRING) {
            tok = self.advance();
            return self.make_string(tok);
        }
        if self.check(TokenKind.BOOL) {
            tok = self.advance();
            return self.make_bool(tok);
        }
        if self.check(TokenKind.NULL) {
            tok = self.advance();
            return self.make_null(tok);
        }
        if self.check(TokenKind.ELLIPSIS) {
            tok = self.advance();
            return self.make_ellipsis(tok);
        }
        if self.check_any(
            TokenKind.TYP_STRING,
            TokenKind.TYP_INT,
            TokenKind.TYP_FLOAT,
            TokenKind.TYP_LIST,
            TokenKind.TYP_TUPLE,
            TokenKind.TYP_SET,
            TokenKind.TYP_DICT,
            TokenKind.TYP_BOOL,
            TokenKind.TYP_BYTES,
            TokenKind.TYP_ANY,
            TokenKind.TYP_TYPE
        ) {
            tok = self.advance();
            return BuiltinType(
                orig_src=self.source,
                name=TOKEN_KIND_TO_TOK.get(tok.kind, tok.kind.value),
                value=tok.value,
                line=tok.loc.line,
                end_line=tok.loc.end_line,
                col_start=tok.loc.col_start,
                col_end=tok.loc.col_end,
                pos_start=tok.loc.pos_start,
                pos_end=tok.loc.pos_end
            );
        }
        if self.match_tok(TokenKind.TYPE_OP) {
            type_op = self.make_uni_token(self.previous());
            if self.check(TokenKind.NAME) {
                name_tok = self.advance();
                name = self.make_name(name_tok);
                return TypeRef(name=name, type_params=None, kid=[type_op, name]);
            }
        }
        if self.check_any(
            TokenKind.KW_SELF,
            TokenKind.KW_SUPER,
            TokenKind.KW_HERE,
            TokenKind.KW_ROOT,
            TokenKind.KW_VISITOR,
            TokenKind.KW_PROPS
        ) {
            tok = self.advance();
            return SpecialVarRef(
                orig_src=self.source,
                name=TOKEN_KIND_TO_TOK.get(tok.kind, tok.kind.value),
                value=tok.value,
                line=tok.loc.line,
                end_line=tok.loc.end_line,
                col_start=tok.loc.col_start,
                col_end=tok.loc.col_end,
                pos_start=tok.loc.pos_start,
                pos_end=tok.loc.pos_end,
                var=tok.value,
                is_enum_stmt=False
            );
        }
        if self.check(TokenKind.NAME) or self.check(TokenKind.KWESC_NAME) {
            tok = self.advance();
            return self.make_name(tok);
        }
        if self.match_tok(TokenKind.LPAREN) {
            if self.check(TokenKind.RPAREN) {
                self.advance();
                return TupleVal(
                    values=[],
                    kid=[
                        self.gen_token(Tok.LPAREN.value),
                        self.gen_token(Tok.RPAREN.value)
                    ]
                );
            }
            expr = self.parse_expression();
            if self.match_tok(TokenKind.COMMA) {
                values = [expr];
                while not self.check(TokenKind.RPAREN) and not self.at_end() {
                    values.append(self.parse_expression());
                    if not self.match_tok(TokenKind.COMMA) {
                        break;
                    }
                }
                self.expect(TokenKind.RPAREN);
                kid: list = [self.gen_token(Tok.LPAREN.value)];
                for (i, v) in enumerate(values) {
                    kid.append(v);
                    if i < len(values) - 1 {
                        kid.append(self.gen_token(Tok.COMMA.value));
                    }
                }
                kid.append(self.gen_token(Tok.RPAREN.value));
                return TupleVal(values=values, kid=kid);
            }
            self.expect(TokenKind.RPAREN);
            return AtomUnit(
                value=expr,
                kid=[
                    self.gen_token(Tok.LPAREN.value),
                    expr,
                    self.gen_token(Tok.RPAREN.value)
                ]
            );
        }
        if self.match_tok(TokenKind.LSQUARE) {
            return self.parse_list_or_compr();
        }
        if self.match_tok(TokenKind.LBRACE) {
            return self.parse_dict_or_set();
        }
        self.error(f"Unexpected token in expression: {self.current().kind}");
        return self.make_name(self.advance());
    }

    def parse_list_or_compr -> Expr {
        if self.check(TokenKind.RSQUARE) {
            self.advance();
            return ListVal(
                values=[],
                kid=[
                    self.gen_token(Tok.LSQUARE.value),
                    self.gen_token(Tok.RSQUARE.value)
                ]
            );
        }
        first = self.parse_expression();
        if self.check(TokenKind.KW_FOR) {
            comprs = self.parse_comprehension_clauses();
            self.expect(TokenKind.RSQUARE);
            kid: list = [self.gen_token(Tok.LSQUARE.value), first];
            kid.extend(comprs);
            kid.append(self.gen_token(Tok.RSQUARE.value));
            return ListCompr(comprehensions=comprs, expr=first, kid=kid);
        }
        values = [first];
        while self.match_tok(TokenKind.COMMA) {
            if self.check(TokenKind.RSQUARE) {
                break;
            }
            values.append(self.parse_expression());
        }
        self.expect(TokenKind.RSQUARE);
        kid = [self.gen_token(Tok.LSQUARE.value)];
        for (i, v) in enumerate(values) {
            kid.append(v);
            if i < len(values) - 1 {
                kid.append(self.gen_token(Tok.COMMA.value));
            }
        }
        kid.append(self.gen_token(Tok.RSQUARE.value));
        return ListVal(values=values, kid=kid);
    }

    def parse_dict_or_set -> Expr {
        if self.check(TokenKind.RBRACE) {
            self.advance();
            return DictVal(
                kv_pairs=[],
                kid=[
                    self.gen_token(Tok.LBRACE.value),
                    self.gen_token(Tok.RBRACE.value)
                ]
            );
        }
        first = self.parse_expression();
        if self.match_tok(TokenKind.COLON) {
            value = self.parse_expression();
            if self.check(TokenKind.KW_FOR) {
                comprs = self.parse_comprehension_clauses();
                self.expect(TokenKind.RBRACE);
                kid: list = [
                    self.gen_token(Tok.LBRACE.value),
                    first,
                    self.gen_token(Tok.COLON.value),
                    value
                ];
                kid.extend(comprs);
                kid.append(self.gen_token(Tok.RBRACE.value));
                return DictCompr(
                    key_expr=first, value_expr=value, comprehensions=comprs, kid=kid
                );
            }
            pairs = [
                KVPair(
                    key=first,
                    value=value,
                    kid=[first, self.gen_token(Tok.COLON.value), value]
                )
            ];
            while self.match_tok(TokenKind.COMMA) {
                if self.check(TokenKind.RBRACE) {
                    break;
                }
                key = self.parse_expression();
                self.expect(TokenKind.COLON);
                val = self.parse_expression();
                pairs.append(
                    KVPair(
                        key=key,
                        value=val,
                        kid=[key, self.gen_token(Tok.COLON.value), val]
                    )
                );
            }
            self.expect(TokenKind.RBRACE);
            kid = [self.gen_token(Tok.LBRACE.value)];
            for (i, p) in enumerate(pairs) {
                kid.append(p);
                if i < len(pairs) - 1 {
                    kid.append(self.gen_token(Tok.COMMA.value));
                }
            }
            kid.append(self.gen_token(Tok.RBRACE.value));
            return DictVal(kv_pairs=pairs, kid=kid);
        }
        if self.check(TokenKind.KW_FOR) {
            comprs = self.parse_comprehension_clauses();
            self.expect(TokenKind.RBRACE);
            kid = [self.gen_token(Tok.LBRACE.value), first];
            kid.extend(comprs);
            kid.append(self.gen_token(Tok.RBRACE.value));
            return SetCompr(comprehensions=comprs, expr=first, kid=kid);
        }
        values = [first];
        while self.match_tok(TokenKind.COMMA) {
            if self.check(TokenKind.RBRACE) {
                break;
            }
            values.append(self.parse_expression());
        }
        self.expect(TokenKind.RBRACE);
        kid = [self.gen_token(Tok.LBRACE.value)];
        for (i, v) in enumerate(values) {
            kid.append(v);
            if i < len(values) - 1 {
                kid.append(self.gen_token(Tok.COMMA.value));
            }
        }
        kid.append(self.gen_token(Tok.RBRACE.value));
        return SetVal(values=values, kid=kid);
    }

    def parse_comprehension_clauses -> list {
        comprs: list = [];
        while self.match_tok(TokenKind.KW_FOR) {
            is_async = False;
            if self.check(TokenKind.KW_ASYNC) {
                self.advance();
                is_async = True;
            }
            target = self.parse_atomic_chain();
            self.expect(TokenKind.KW_IN);
            iter_expr = self.parse_pipe_call();
            ifs: list = [];
            while self.match_tok(TokenKind.KW_IF) {
                ifs.append(self.parse_walrus_assign());
            }
            kid: list = [
                self.gen_token(Tok.KW_FOR.value),
                target,
                self.gen_token(Tok.KW_IN.value),
                iter_expr
            ];
            for if_expr in ifs {
                kid.append(self.gen_token(Tok.KW_IF.value));
                kid.append(if_expr);
            }
            comprs.append(
                InnerCompr(
                    target=target, iter=iter_expr, ifs=ifs, is_async=is_async, kid=kid
                )
            );
        }
        return comprs;
    }

    def parse_lambda_expr -> Expr {
        self.expect(TokenKind.KW_LAMBDA);
        lambda_tok = self.gen_token(Tok.KW_LAMBDA.value);
        params = self.parse_lambda_params();
        return_type = None;
        if self.match_tok(TokenKind.RETURN_HINT) {
            return_type = self.parse_expression();
        }
        body: Expr | list;
        if self.match_tok(TokenKind.COLON) {
            body = self.parse_expression();
        } elif self.match_tok(TokenKind.LBRACE) {
            body = self.parse_code_block_stmts();
            self.expect(TokenKind.RBRACE);
        } else {
            self.error("Expected ':' or '{' after lambda parameters");
            body = self.parse_expression();
        }
        signature = FuncSignature(
            posonly_params=[],
            params=params,
            varargs=None,
            kwonlyargs=[],
            kwargs=None,
            return_type=return_type,
            kid=[]
        );
        kid: list = [lambda_tok];
        kid.extend(params);
        if isinstance(body, list) {
            kid.extend(body);
        } else {
            kid.append(body);
        }
        return LambdaExpr(body=body, kid=kid, signature=signature);
    }

    def parse_lambda_params -> list {
        params: list = [];
        while self.check(TokenKind.NAME) {
            name_tok = self.advance();
            name = self.make_name(name_tok);
            type_tag = None;
            if self.match_tok(TokenKind.COLON) {
                type_tag = SubTag(tag=self.parse_expression(), kid=[]);
            }
            default_val = None;
            if self.match_tok(TokenKind.EQ) {
                default_val = self.parse_expression();
            }
            kid: list = [name];
            if type_tag {
                kid.append(type_tag);
            }
            if default_val {
                kid.append(default_val);
            }
            params.append(
                ParamVar(
                    name=name,
                    unpack=None,
                    type_tag=type_tag,
                    value=default_val,
                    kid=kid
                )
            );
            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
        }
        return params;
    }

    # =========================================================================
    # STATEMENT PARSING
    # =========================================================================
    def parse_element_stmt {
        while self.match_tok(TokenKind.SEMI) {
            skip;
        }
        if self.at_end() {
            return None;
        }
        if self.check_any(TokenKind.KW_IMPORT, TokenKind.KW_INCLUDE) {
            return self.parse_import_stmt();
        }
        if self.check_any(
            TokenKind.KW_OBJECT,
            TokenKind.KW_NODE,
            TokenKind.KW_EDGE,
            TokenKind.KW_WALKER,
            TokenKind.KW_CLASS
        ) {
            return self.parse_archetype();
        }
        if self.check(TokenKind.KW_ENUM) {
            return self.parse_enum();
        }
        if self.check(TokenKind.KW_TEST) {
            return self.parse_test();
        }
        if self.check_any(TokenKind.KW_DEF, TokenKind.KW_CAN) {
            return self.parse_ability();
        }
        expr = self.parse_expression();
        self.match_tok(TokenKind.SEMI);
        return expr;
    }

    def parse_code_block_stmts -> list {
        stmts: list = [];
        while not self.check(TokenKind.RBRACE) and not self.at_end() {
            stmt = self.parse_statement();
            if stmt is not None {
                stmts.append(stmt);
            }
        }
        return stmts;
    }

    def parse_statement {
        while self.match_tok(TokenKind.SEMI) {
            skip;
        }
        if self.check(TokenKind.RBRACE) or self.at_end() {
            return None;
        }
        if self.check(TokenKind.KW_IF) {
            return self.parse_if_stmt();
        }
        if self.check(TokenKind.KW_WHILE) {
            return self.parse_while_stmt();
        }
        if self.check(TokenKind.KW_FOR) {
            return self.parse_for_stmt();
        }
        if self.check(TokenKind.KW_TRY) {
            return self.parse_try_stmt();
        }
        if self.check(TokenKind.KW_WITH) {
            return self.parse_with_stmt();
        }
        if self.check(TokenKind.KW_MATCH) {
            return self.parse_match_stmt();
        }
        if self.check(TokenKind.KW_RETURN) {
            return self.parse_return_stmt();
        }
        if self.check(TokenKind.KW_YIELD) {
            return self.parse_yield_stmt();
        }
        if self.check(TokenKind.KW_BREAK) {
            self.advance();
            self.match_tok(TokenKind.SEMI);
            return CtrlStmt(
                tag=self.gen_token(Tok.KW_BREAK.value),
                kid=[self.gen_token(Tok.KW_BREAK.value)]
            );
        }
        if self.check(TokenKind.KW_CONTINUE) {
            self.advance();
            self.match_tok(TokenKind.SEMI);
            return CtrlStmt(
                tag=self.gen_token(Tok.KW_CONTINUE.value),
                kid=[self.gen_token(Tok.KW_CONTINUE.value)]
            );
        }
        if self.check(TokenKind.KW_RAISE) {
            return self.parse_raise_stmt();
        }
        if self.check(TokenKind.KW_ASSERT) {
            return self.parse_assert_stmt();
        }
        if self.check(TokenKind.KW_DELETE) {
            return self.parse_delete_stmt();
        }
        expr = self.parse_expression();
        if self.check(TokenKind.EQ) or self.check(TokenKind.COLON) {
            return self.parse_assignment_with_target(expr);
        }
        self.match_tok(TokenKind.SEMI);
        return expr;
    }

    def parse_if_stmt -> IfStmt {
        self.expect(TokenKind.KW_IF);
        condition = self.parse_expression();
        self.expect(TokenKind.LBRACE);
        body = self.parse_code_block_stmts();
        self.expect(TokenKind.RBRACE);
        else_body = None;
        if self.check(TokenKind.KW_ELIF) {
            else_body = self.parse_elif_stmt();
        } elif self.check(TokenKind.KW_ELSE) {
            else_body = self.parse_else_stmt();
        }
        kid: list = [
            self.gen_token(Tok.KW_IF.value),
            condition,
            self.gen_token(Tok.LBRACE.value)
        ];
        kid.extend(body);
        kid.append(self.gen_token(Tok.RBRACE.value));
        if else_body {
            kid.append(else_body);
        }
        return IfStmt(condition=condition, body=body, else_body=else_body, kid=kid);
    }

    def parse_elif_stmt -> ElseIf {
        self.expect(TokenKind.KW_ELIF);
        condition = self.parse_expression();
        self.expect(TokenKind.LBRACE);
        body = self.parse_code_block_stmts();
        self.expect(TokenKind.RBRACE);
        else_body = None;
        if self.check(TokenKind.KW_ELIF) {
            else_body = self.parse_elif_stmt();
        } elif self.check(TokenKind.KW_ELSE) {
            else_body = self.parse_else_stmt();
        }
        kid: list = [
            self.gen_token(Tok.KW_ELIF.value),
            condition,
            self.gen_token(Tok.LBRACE.value)
        ];
        kid.extend(body);
        kid.append(self.gen_token(Tok.RBRACE.value));
        if else_body {
            kid.append(else_body);
        }
        return ElseIf(condition=condition, body=body, else_body=else_body, kid=kid);
    }

    def parse_else_stmt -> ElseStmt {
        self.expect(TokenKind.KW_ELSE);
        self.expect(TokenKind.LBRACE);
        body = self.parse_code_block_stmts();
        self.expect(TokenKind.RBRACE);
        kid: list = [
            self.gen_token(Tok.KW_ELSE.value),
            self.gen_token(Tok.LBRACE.value)
        ];
        kid.extend(body);
        kid.append(self.gen_token(Tok.RBRACE.value));
        return ElseStmt(body=body, kid=kid);
    }

    def parse_while_stmt -> WhileStmt {
        self.expect(TokenKind.KW_WHILE);
        condition = self.parse_expression();
        self.expect(TokenKind.LBRACE);
        body = self.parse_code_block_stmts();
        self.expect(TokenKind.RBRACE);
        else_body = None;
        if self.check(TokenKind.KW_ELSE) {
            else_body = self.parse_else_stmt();
        }
        kid: list = [
            self.gen_token(Tok.KW_WHILE.value),
            condition,
            self.gen_token(Tok.LBRACE.value)
        ];
        kid.extend(body);
        kid.append(self.gen_token(Tok.RBRACE.value));
        if else_body {
            kid.append(else_body);
        }
        return WhileStmt(condition=condition, body=body, else_body=else_body, kid=kid);
    }

    def parse_for_stmt {
        is_async = False;
        if self.match_tok(TokenKind.KW_ASYNC) {
            is_async = True;
        }
        self.expect(TokenKind.KW_FOR);
        target = self.parse_atomic_chain();
        self.expect(TokenKind.KW_IN);
        iter_expr = self.parse_expression();
        self.expect(TokenKind.LBRACE);
        body = self.parse_code_block_stmts();
        self.expect(TokenKind.RBRACE);
        else_body = None;
        if self.check(TokenKind.KW_ELSE) {
            else_body = self.parse_else_stmt();
        }
        kid: list = [
            self.gen_token(Tok.KW_FOR.value),
            target,
            self.gen_token(Tok.KW_IN.value),
            iter_expr
        ];
        kid.append(self.gen_token(Tok.LBRACE.value));
        kid.extend(body);
        kid.append(self.gen_token(Tok.RBRACE.value));
        if else_body {
            kid.append(else_body);
        }
        return InForStmt(
            target=target,
            is_async=is_async,
            collection=iter_expr,
            body=body,
            else_body=else_body,
            kid=kid
        );
    }

    def parse_try_stmt -> TryStmt {
        self.expect(TokenKind.KW_TRY);
        self.expect(TokenKind.LBRACE);
        body = self.parse_code_block_stmts();
        self.expect(TokenKind.RBRACE);
        excepts: list = [];
        while self.check(TokenKind.KW_EXCEPT) {
            excepts.append(self.parse_except_handler());
        }
        else_body = None;
        if self.check(TokenKind.KW_ELSE) {
            else_body = self.parse_else_stmt();
        }
        finally_body = None;
        if self.check(TokenKind.KW_FINALLY) {
            self.advance();
            self.expect(TokenKind.LBRACE);
            finally_stmts = self.parse_code_block_stmts();
            self.expect(TokenKind.RBRACE);
            finally_body = FinallyStmt(body=finally_stmts, kid=finally_stmts);
        }
        kid: list = [
            self.gen_token(Tok.KW_TRY.value),
            self.gen_token(Tok.LBRACE.value)
        ];
        kid.extend(body);
        kid.append(self.gen_token(Tok.RBRACE.value));
        kid.extend(excepts);
        if else_body {
            kid.append(else_body);
        }
        if finally_body {
            kid.append(finally_body);
        }
        return TryStmt(
            body=body,
            excepts=excepts,
            else_body=else_body,
            finally_body=finally_body,
            kid=kid
        );
    }

    def parse_except_handler -> Except {
        self.expect(TokenKind.KW_EXCEPT);
        exc_type = self.parse_expression();
        name = None;
        if self.match_tok(TokenKind.KW_AS) {
            name_tok = self.expect(TokenKind.NAME);
            name = self.make_name(name_tok);
        }
        self.expect(TokenKind.LBRACE);
        body = self.parse_code_block_stmts();
        self.expect(TokenKind.RBRACE);
        kid: list = [self.gen_token(Tok.KW_EXCEPT.value), exc_type];
        if name {
            kid.append(self.gen_token(Tok.KW_AS.value));
            kid.append(name);
        }
        kid.append(self.gen_token(Tok.LBRACE.value));
        kid.extend(body);
        kid.append(self.gen_token(Tok.RBRACE.value));
        return Except(exception=exc_type, body=body, kid=kid);
    }

    def parse_with_stmt -> WithStmt {
        is_async = False;
        if self.match_tok(TokenKind.KW_ASYNC) {
            is_async = True;
        }
        self.expect(TokenKind.KW_WITH);
        exprs: list = [];
        expr = self.parse_expression();
        alias = None;
        if self.match_tok(TokenKind.KW_AS) {
            alias = self.parse_expression();
        }
        exprs.append(
            ExprAsItem(
                expr=expr, alias=alias, kid=[expr] if not alias else [expr, alias]
            )
        );
        while self.match_tok(TokenKind.COMMA) {
            expr = self.parse_expression();
            alias = None;
            if self.match_tok(TokenKind.KW_AS) {
                alias = self.parse_expression();
            }
            exprs.append(
                ExprAsItem(
                    expr=expr, alias=alias, kid=[expr] if not alias else [expr, alias]
                )
            );
        }
        self.expect(TokenKind.LBRACE);
        body = self.parse_code_block_stmts();
        self.expect(TokenKind.RBRACE);
        kid: list = [self.gen_token(Tok.KW_WITH.value)];
        kid.extend(exprs);
        kid.append(self.gen_token(Tok.LBRACE.value));
        kid.extend(body);
        kid.append(self.gen_token(Tok.RBRACE.value));
        return WithStmt(is_async=is_async, exprs=exprs, body=body, kid=kid);
    }

    def parse_match_stmt -> MatchStmt {
        self.expect(TokenKind.KW_MATCH);
        expr = self.parse_expression();
        self.expect(TokenKind.LBRACE);
        cases: list = [];
        while self.check(TokenKind.KW_CASE) {
            cases.append(self.parse_match_case());
        }
        self.expect(TokenKind.RBRACE);
        kid: list = [
            self.gen_token(Tok.KW_MATCH.value),
            expr,
            self.gen_token(Tok.LBRACE.value)
        ];
        kid.extend(cases);
        kid.append(self.gen_token(Tok.RBRACE.value));
        return MatchStmt(expr=expr, cases=cases, kid=kid);
    }

    def parse_match_case -> MatchCase {
        self.expect(TokenKind.KW_CASE);
        pattern = self.parse_pattern();
        guard = None;
        if self.match_tok(TokenKind.KW_IF) {
            guard = self.parse_expression();
        }
        self.expect(TokenKind.COLON);
        body: list = [];
        while not self.check_any(TokenKind.KW_CASE, TokenKind.RBRACE)
        and not self.at_end() {
            stmt = self.parse_statement();
            if stmt is not None {
                body.append(stmt);
            }
        }
        kid: list = [self.gen_token(Tok.KW_CASE.value), pattern];
        if guard {
            kid.append(self.gen_token(Tok.KW_IF.value));
            kid.append(guard);
        }
        kid.append(self.gen_token(Tok.COLON.value));
        kid.extend(body);
        return MatchCase(pattern=pattern, guard=guard, body=body, kid=kid);
    }

    def parse_pattern {
        if self.check(TokenKind.NAME) {
            tok = self.advance();
            if tok.value == "_" {
                return MatchWild(kid=[self.make_name(tok)]);
            }
            return MatchValue(expr=self.make_name(tok), kid=[self.make_name(tok)]);
        }
        expr = self.parse_expression();
        return MatchValue(expr=expr, kid=[expr]);
    }

    def parse_return_stmt -> ReturnStmt {
        self.expect(TokenKind.KW_RETURN);
        expr = None;
        if not self.check(TokenKind.SEMI) and not self.check(TokenKind.RBRACE) {
            expr = self.parse_expression();
        }
        self.match_tok(TokenKind.SEMI);
        kid: list = [self.gen_token(Tok.KW_RETURN.value)];
        if expr {
            kid.append(expr);
        }
        return ReturnStmt(expr=expr, kid=kid);
    }

    def parse_yield_stmt -> YieldExpr {
        self.expect(TokenKind.KW_YIELD);
        with_from = False;
        if self.match_tok(TokenKind.KW_FROM) {
            with_from = True;
        }
        expr = None;
        if not self.check(TokenKind.SEMI) and not self.check(TokenKind.RBRACE) {
            expr = self.parse_expression();
        }
        self.match_tok(TokenKind.SEMI);
        kid: list = [self.gen_token(Tok.KW_YIELD.value)];
        if with_from {
            kid.append(self.gen_token(Tok.KW_FROM.value));
        }
        if expr {
            kid.append(expr);
        }
        return YieldExpr(expr=expr, with_from=with_from, kid=kid);
    }

    def parse_raise_stmt -> RaiseStmt {
        self.expect(TokenKind.KW_RAISE);
        expr = None;
        if not self.check(TokenKind.SEMI) and not self.check(TokenKind.RBRACE) {
            expr = self.parse_expression();
        }
        self.match_tok(TokenKind.SEMI);
        kid: list = [self.gen_token(Tok.KW_RAISE.value)];
        if expr {
            kid.append(expr);
        }
        return RaiseStmt(expr=expr, kid=kid);
    }

    def parse_assert_stmt -> AssertStmt {
        self.expect(TokenKind.KW_ASSERT);
        test = self.parse_expression();
        msg = None;
        if self.match_tok(TokenKind.COMMA) {
            msg = self.parse_expression();
        }
        self.match_tok(TokenKind.SEMI);
        kid: list = [self.gen_token(Tok.KW_ASSERT.value), test];
        if msg {
            kid.append(self.gen_token(Tok.COMMA.value));
            kid.append(msg);
        }
        return AssertStmt(test=test, msg=msg, kid=kid);
    }

    def parse_delete_stmt -> DeleteStmt {
        self.expect(TokenKind.KW_DELETE);
        target = self.parse_expression();
        self.match_tok(TokenKind.SEMI);
        return DeleteStmt(
            targets=[target], kid=[self.gen_token(Tok.KW_DELETE.value), target]
        );
    }

    def parse_assignment_with_target(target: Expr) -> Assignment {
        type_tag = None;
        if self.match_tok(TokenKind.COLON) {
            type_tag = SubTag(tag=self.parse_pipe(), kid=[]);
        }
        value = None;
        aug_op = None;
        if self.match_tok(TokenKind.EQ) {
            value = self.parse_expression();
        } elif self.check_any(
            TokenKind.ADD_EQ,
            TokenKind.SUB_EQ,
            TokenKind.MUL_EQ,
            TokenKind.DIV_EQ,
            TokenKind.FLOOR_DIV_EQ,
            TokenKind.MOD_EQ,
            TokenKind.STAR_POW_EQ,
            TokenKind.BW_AND_EQ,
            TokenKind.BW_OR_EQ,
            TokenKind.BW_XOR_EQ,
            TokenKind.LSHIFT_EQ,
            TokenKind.RSHIFT_EQ
        ) {
            aug_tok = self.advance();
            aug_op = self.make_uni_token(aug_tok);
            value = self.parse_expression();
        }
        self.match_tok(TokenKind.SEMI);
        kid: list = [target];
        if type_tag {
            kid.append(self.gen_token(Tok.COLON.value));
            kid.append(type_tag.tag);
        }
        if aug_op {
            kid.append(aug_op);
        } elif value {
            kid.append(self.gen_token(Tok.EQ.value));
        }
        if value {
            kid.append(value);
        }
        return Assignment(
            target=[target],
            value=value,
            type_tag=type_tag,
            kid=kid,
            mutable=True,
            aug_op=aug_op,
            is_enum_stmt=False
        );
    }

    # =========================================================================
    # DECLARATION PARSING
    # =========================================================================
    def parse_import_stmt -> Import {
        is_include = self.check(TokenKind.KW_INCLUDE);
        hint_tok = self.advance();
        path_names: list = [];
        if self.check(TokenKind.NAME) {
            name_tok = self.advance();
            path_names.append(self.make_name(name_tok));
            while self.match_tok(TokenKind.DOT) {
                name_tok = self.expect(TokenKind.NAME);
                path_names.append(self.make_name(name_tok));
            }
        }
        self.match_tok(TokenKind.SEMI);
        path = ModulePath(kid=path_names);
        kid: list = [self.make_uni_token(hint_tok), path];
        return Import(access=None, targets=[ModuleItem(kid=[path])], kid=kid, doc=None);
    }

    def parse_archetype -> Archetype {
        decorators: list = [];
        while self.check(TokenKind.DECOR_OP) {
            self.advance();
            decorators.append(self.parse_atomic_chain());
        }
        is_async = False;
        if self.match_tok(TokenKind.KW_ASYNC) {
            is_async = True;
        }
        is_abstract = False;
        if self.match_tok(TokenKind.KW_ABSTRACT) {
            is_abstract = True;
        }
        arch_tok = self.advance();
        arch_type = self.make_uni_token(arch_tok);
        access = None;
        if self.match_tok(TokenKind.COLON) {
            if self.check_any(TokenKind.KW_PUB, TokenKind.KW_PRIV, TokenKind.KW_PROT) {
                access_tok = self.advance();
                access = SubTag(tag=self.make_uni_token(access_tok), kid=[]);
            }
        }
        name_tok = self.expect(TokenKind.NAME);
        name = self.make_name(name_tok);
        base_classes: list = [];
        if self.match_tok(TokenKind.LPAREN) {
            if not self.check(TokenKind.RPAREN) {
                base_classes.append(self.parse_atomic_chain());
                while self.match_tok(TokenKind.COMMA) {
                    base_classes.append(self.parse_atomic_chain());
                }
            }
            self.expect(TokenKind.RPAREN);
        }
        body: list = [];
        if self.match_tok(TokenKind.LBRACE) {
            while not self.check(TokenKind.RBRACE) and not self.at_end() {
                member = self.parse_archetype_member();
                if member is not None {
                    body.append(member);
                }
            }
            self.expect(TokenKind.RBRACE);
        } else {
            self.expect(TokenKind.SEMI);
        }
        kid: list = [];
        kid.extend(decorators);
        kid.append(arch_type);
        if access {
            kid.append(access);
        }
        kid.append(name);
        if base_classes {
            kid.append(self.gen_token(Tok.LPAREN.value));
            kid.extend(base_classes);
            kid.append(self.gen_token(Tok.RPAREN.value));
        }
        kid.append(self.gen_token(Tok.LBRACE.value));
        kid.extend(body);
        kid.append(self.gen_token(Tok.RBRACE.value));
        return Archetype(
            name=name,
            arch_type=arch_type,
            access=access,
            base_classes=base_classes,
            body=body,
            kid=kid,
            doc=None,
            decorators=decorators
        );
    }

    def parse_archetype_member {
        while self.match_tok(TokenKind.SEMI) {
            skip;
        }
        if self.check(TokenKind.RBRACE) or self.at_end() {
            return None;
        }
        if self.check(TokenKind.KW_HAS) or self.check(TokenKind.KW_STATIC) {
            return self.parse_has_stmt();
        }
        if self.check_any(TokenKind.KW_DEF, TokenKind.KW_CAN, TokenKind.KW_OVERRIDE) {
            return self.parse_ability();
        }
        if self.check_any(
            TokenKind.KW_OBJECT,
            TokenKind.KW_NODE,
            TokenKind.KW_EDGE,
            TokenKind.KW_WALKER,
            TokenKind.KW_CLASS
        ) {
            return self.parse_archetype();
        }
        if self.check(TokenKind.KW_ENUM) {
            return self.parse_enum();
        }
        expr = self.parse_expression();
        self.match_tok(TokenKind.SEMI);
        return expr;
    }

    def parse_has_stmt -> ArchHas {
        is_static = False;
        if self.match_tok(TokenKind.KW_STATIC) {
            is_static = True;
        }
        self.expect(TokenKind.KW_HAS);
        access = None;
        if self.match_tok(TokenKind.COLON) {
            if self.check_any(TokenKind.KW_PUB, TokenKind.KW_PRIV, TokenKind.KW_PROT) {
                access_tok = self.advance();
                access = SubTag(tag=self.make_uni_token(access_tok), kid=[]);
            }
        }
        vars: list = [];
        vars.append(self.parse_has_var());
        while self.match_tok(TokenKind.COMMA) {
            vars.append(self.parse_has_var());
        }
        self.expect(TokenKind.SEMI);
        kid: list = [];
        if is_static {
            kid.append(self.gen_token(Tok.KW_STATIC.value));
        }
        kid.append(self.gen_token(Tok.KW_HAS.value));
        if access {
            kid.append(self.gen_token(Tok.COLON.value));
            kid.append(access);
        }
        kid.extend(vars);
        return ArchHas(access=access, is_frozen=False, vars=vars, kid=kid, doc=None);
    }

    def parse_has_var -> HasVar {
        name_tok = self.expect(TokenKind.NAME);
        name = self.make_name(name_tok);
        self.expect(TokenKind.COLON);
        type_expr = self.parse_pipe();
        type_tag = SubTag(tag=type_expr, kid=[type_expr]);
        value = None;
        if self.match_tok(TokenKind.EQ) {
            value = self.parse_expression();
        } elif self.match_tok(TokenKind.KW_BY) {
            self.expect(TokenKind.KW_POST_INIT);
        }
        kid: list = [name, self.gen_token(Tok.COLON.value), type_expr];
        if value {
            kid.append(self.gen_token(Tok.EQ.value));
            kid.append(value);
        }
        return HasVar(
            name=name, mutable=True, type_tag=type_tag, value=value, kid=kid, doc=None
        );
    }

    def parse_ability -> Ability {
        decorators: list = [];
        while self.check(TokenKind.DECOR_OP) {
            self.advance();
            decorators.append(self.parse_atomic_chain());
        }
        is_override = False;
        if self.match_tok(TokenKind.KW_OVERRIDE) {
            is_override = True;
        }
        is_static = False;
        if self.match_tok(TokenKind.KW_STATIC) {
            is_static = True;
        }
        is_async = False;
        if self.match_tok(TokenKind.KW_ASYNC) {
            is_async = True;
        }
        is_can = self.check(TokenKind.KW_CAN);
        ability_tok = self.advance();
        access = None;
        if self.match_tok(TokenKind.COLON) {
            if self.check_any(TokenKind.KW_PUB, TokenKind.KW_PRIV, TokenKind.KW_PROT) {
                access_tok = self.advance();
                access = SubTag(tag=self.make_uni_token(access_tok), kid=[]);
            }
        }
        name = None;
        if self.check(TokenKind.NAME) {
            name_tok = self.advance();
            name = self.make_name(name_tok);
        }
        signature: FuncSignature | EventSignature;
        if is_can and self.check(TokenKind.KW_WITH) {
            self.advance();
            event_type = self.parse_expression()
            if not self.check_any(TokenKind.KW_ENTRY, TokenKind.KW_EXIT)
            else None;
            event_tok = self.advance();
            signature = EventSignature(
                event=self.make_uni_token(event_tok), arch_tag_info=event_type, kid=[]
            );
        } else {
            signature = self.parse_func_signature();
        }
        body: list = [];
        is_abstract = False;
        if self.match_tok(TokenKind.LBRACE) {
            body = self.parse_code_block_stmts();
            self.expect(TokenKind.RBRACE);
        } elif self.match_tok(TokenKind.KW_BY) {
            expr = self.parse_expression();
            self.expect(TokenKind.SEMI);
            body = [expr];
        } else {
            if self.match_tok(TokenKind.KW_ABSTRACT) {
                is_abstract = True;
            }
            self.expect(TokenKind.SEMI);
        }
        kid: list = [];
        kid.extend(decorators);
        if is_override {
            kid.append(self.gen_token(Tok.KW_OVERRIDE.value));
        }
        if is_static {
            kid.append(self.gen_token(Tok.KW_STATIC.value));
        }
        kid.append(self.make_uni_token(ability_tok));
        if access {
            kid.append(access);
        }
        if name {
            kid.append(name);
        }
        kid.append(self.gen_token(Tok.LBRACE.value));
        kid.extend(body);
        kid.append(self.gen_token(Tok.RBRACE.value));
        return Ability(
            name_ref=name,
            is_async=is_async,
            is_override=is_override,
            is_static=is_static,
            is_abstract=is_abstract,
            access=access,
            signature=signature,
            body=body,
            kid=kid,
            doc=None,
            decorators=decorators
        );
    }

    def parse_func_signature -> FuncSignature {
        params: list = [];
        return_type = None;
        if self.match_tok(TokenKind.LPAREN) {
            if not self.check(TokenKind.RPAREN) {
                params = self.parse_func_params();
            }
            self.expect(TokenKind.RPAREN);
        }
        if self.match_tok(TokenKind.RETURN_HINT) {
            return_type = self.parse_pipe();
        }
        return FuncSignature(
            posonly_params=[],
            params=params,
            varargs=None,
            kwonlyargs=[],
            kwargs=None,
            return_type=return_type,
            kid=[]
        );
    }

    def parse_func_params -> list {
        params: list = [];
        while not self.check(TokenKind.RPAREN) {
            unpack = None;
            if self.check_any(TokenKind.STAR_MUL, TokenKind.STAR_POW) {
                unpack_tok = self.advance();
                unpack = self.make_uni_token(unpack_tok);
            }
            if self.check(TokenKind.NAME) {
                name_tok = self.advance();
                name = self.make_name(name_tok);
                type_tag = None;
                if self.match_tok(TokenKind.COLON) {
                    type_tag = SubTag(tag=self.parse_pipe(), kid=[]);
                }
                default_val = None;
                if self.match_tok(TokenKind.EQ) {
                    default_val = self.parse_expression();
                }
                kid: list = [];
                if unpack {
                    kid.append(unpack);
                }
                kid.append(name);
                if type_tag {
                    kid.append(type_tag);
                }
                if default_val {
                    kid.append(default_val);
                }
                params.append(
                    ParamVar(
                        name=name,
                        unpack=unpack,
                        type_tag=type_tag,
                        value=default_val,
                        kid=kid
                    )
                );
            }
            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
        }
        return params;
    }

    def parse_enum -> Enum {
        decorators: list = [];
        while self.check(TokenKind.DECOR_OP) {
            self.advance();
            decorators.append(self.parse_atomic_chain());
        }
        self.expect(TokenKind.KW_ENUM);
        access = None;
        if self.match_tok(TokenKind.COLON) {
            if self.check_any(TokenKind.KW_PUB, TokenKind.KW_PRIV, TokenKind.KW_PROT) {
                access_tok = self.advance();
                access = SubTag(tag=self.make_uni_token(access_tok), kid=[]);
            }
        }
        name_tok = self.expect(TokenKind.NAME);
        name = self.make_name(name_tok);
        base_classes: list = [];
        if self.match_tok(TokenKind.LPAREN) {
            if not self.check(TokenKind.RPAREN) {
                base_classes.append(self.parse_atomic_chain());
                while self.match_tok(TokenKind.COMMA) {
                    base_classes.append(self.parse_atomic_chain());
                }
            }
            self.expect(TokenKind.RPAREN);
        }
        body: list = [];
        if self.match_tok(TokenKind.LBRACE) {
            while not self.check(TokenKind.RBRACE) and not self.at_end() {
                if self.check(TokenKind.NAME) {
                    member = self.parse_enum_member();
                    body.append(member);
                    self.match_tok(TokenKind.COMMA);
                } else {
                    break;
                }
            }
            self.expect(TokenKind.RBRACE);
        } else {
            self.expect(TokenKind.SEMI);
        }
        kid: list = [];
        kid.extend(decorators);
        kid.append(self.gen_token(Tok.KW_ENUM.value));
        if access {
            kid.append(access);
        }
        kid.append(name);
        kid.append(self.gen_token(Tok.LBRACE.value));
        kid.extend(body);
        kid.append(self.gen_token(Tok.RBRACE.value));
        return Enum(
            name=name,
            access=access,
            base_classes=base_classes,
            body=body,
            kid=kid,
            doc=None,
            decorators=decorators
        );
    }

    def parse_enum_member -> Assignment {
        name_tok = self.expect(TokenKind.NAME);
        name = self.make_name(name_tok, is_enum_stmt=True);
        value = None;
        if self.match_tok(TokenKind.EQ) {
            value = self.parse_expression();
        }
        kid: list = [name];
        if value {
            kid.append(self.gen_token(Tok.EQ.value));
            kid.append(value);
        }
        return Assignment(
            target=[name],
            value=value,
            type_tag=None,
            kid=kid,
            mutable=False,
            aug_op=None,
            is_enum_stmt=True
        );
    }

    def parse_test -> Test {
        self.expect(TokenKind.KW_TEST);
        name = None;
        if self.check(TokenKind.NAME) {
            name_tok = self.advance();
            name = self.make_name(name_tok);
        }
        self.expect(TokenKind.LBRACE);
        body = self.parse_code_block_stmts();
        self.expect(TokenKind.RBRACE);
        kid: list = [self.gen_token(Tok.KW_TEST.value)];
        if name {
            kid.append(name);
        }
        kid.append(self.gen_token(Tok.LBRACE.value));
        kid.extend(body);
        kid.append(self.gen_token(Tok.RBRACE.value));
        return Test(
            access=None, signature=name, body=body, kid=kid, doc=None, decorators=None
        );
    }
}

# =============================================================================
# Convenience Functions
# =============================================================================
def parse(
    source: str, file_path: str = "<input>"
) -> tuple[Module, list[ParseError], list[LexerError]] {
    lexer = Lexer(source=source, file_path=file_path);
    tokens = lexer.tokenize();
    parser = Parser(tokens=tokens, file_path=file_path, source_code=source);
    module = parser.parse();
    return (module, parser.errors, lexer.errors);
}
