"""Implementation blocks for the Jac parser.

This file contains the method implementations for the Parser class.
The signatures are defined in parser.jac.
"""

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
import from jaclang.pycore.unitree {
    CtrlStmt,
    ReportStmt,
    VisitStmt,
    DisengageStmt,
    ExprStmt
}
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
    EdgeRefTrailer
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
import from jaclang.pycore.unitree { EdgeOpRef, FilterCompr, AssignCompr }
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
# Token Access Implementations
# =============================================================================
impl Parser.current -> Token {
    if self.pos < len(self.tokens) {
        return self.tokens[self.pos];
    }
    return self.tokens[-1];
}

impl Parser.peek(offset: int = 1) -> Token {
    idx = self.pos + offset;
    if idx < len(self.tokens) {
        return self.tokens[idx];
    }
    return self.tokens[-1];
}

impl Parser.advance -> Token {
    tok = self.current();
    if self.pos < len(self.tokens) - 1 {
        self.pos += 1;
    }
    return tok;
}

impl Parser.previous -> Token {
    if self.pos > 0 {
        return self.tokens[self.pos - 1];
    }
    return self.tokens[0];
}

impl Parser.at_end -> bool {
    return self.current().kind == TokenKind.EOF;
}

impl Parser.check(kind: TokenKind) -> bool {
    return self.current().kind == kind;
}

impl Parser.check_any(*kinds: TokenKind) -> bool {
    return self.current().kind in kinds;
}

impl Parser.get_source -> Source {
    # Return the cached source (set in parse_module) or create new one
    # Note: self.source is guaranteed to be set in parse_module before any token creation
    src = self.source;
    if isinstance(src, Source) {
        return src;
    }
    # Fallback - should not happen in normal operation
    return Source(self.file_path, self.source_code);
}

impl Parser.match_tok(kind: TokenKind) -> Token | None {
    if self.check(kind) {
        return self.advance();
    }
    return None;
}

impl Parser.expect(kind: TokenKind) -> Token {
    if self.check(kind) {
        return self.advance();
    }
    self.error(f"Expected {kind}, got {self.current().kind}");
    return self.current();
}

impl Parser.error(message: str) {
    self.errors.append(ParseError(message=message, loc=self.current().loc));
}

impl Parser.check_name -> bool {
    # Check for NAME or KWESC_NAME (keyword-escaped identifier like <>type)
    return self.check(TokenKind.NAME) or self.check(TokenKind.KWESC_NAME);
}

impl Parser.is_keyword_token -> bool {
    # Check if current token is any keyword or built-in type (used for DOT access)
    return self.check_any(
        TokenKind.KW_ABSTRACT,
        TokenKind.KW_OBJECT,
        TokenKind.KW_CLASS,
        TokenKind.KW_ENUM,
        TokenKind.KW_NODE,
        TokenKind.KW_EDGE,
        TokenKind.KW_WALKER,
        TokenKind.KW_HAS,
        TokenKind.KW_CAN,
        TokenKind.KW_DEF,
        TokenKind.KW_STATIC,
        TokenKind.KW_OVERRIDE,
        TokenKind.KW_IMPL,
        TokenKind.KW_SEM,
        TokenKind.KW_TEST,
        TokenKind.KW_GLOBAL,
        TokenKind.KW_GLOBAL_REF,
        TokenKind.KW_NONLOCAL,
        TokenKind.KW_IMPORT,
        TokenKind.KW_INCLUDE,
        TokenKind.KW_FROM,
        TokenKind.KW_AS,
        TokenKind.KW_IF,
        TokenKind.KW_ELIF,
        TokenKind.KW_ELSE,
        TokenKind.KW_FOR,
        TokenKind.KW_TO,
        TokenKind.KW_BY,
        TokenKind.KW_WHILE,
        TokenKind.KW_MATCH,
        TokenKind.KW_SWITCH,
        TokenKind.KW_CASE,
        TokenKind.KW_DEFAULT,
        TokenKind.KW_TRY,
        TokenKind.KW_EXCEPT,
        TokenKind.KW_FINALLY,
        TokenKind.KW_WITH,
        TokenKind.KW_RETURN,
        TokenKind.KW_YIELD,
        TokenKind.KW_BREAK,
        TokenKind.KW_CONTINUE,
        TokenKind.KW_RAISE,
        TokenKind.KW_DELETE,
        TokenKind.KW_ASSERT,
        TokenKind.KW_SKIP,
        TokenKind.KW_REPORT,
        TokenKind.KW_VISIT,
        TokenKind.KW_SPAWN,
        TokenKind.KW_ENTRY,
        TokenKind.KW_EXIT,
        TokenKind.KW_DISENGAGE,
        TokenKind.KW_HERE,
        TokenKind.KW_VISITOR,
        TokenKind.KW_ROOT,
        TokenKind.KW_ASYNC,
        TokenKind.KW_AWAIT,
        TokenKind.KW_FLOW,
        TokenKind.KW_WAIT,
        TokenKind.KW_AND,
        TokenKind.KW_OR,
        TokenKind.KW_NOT,
        TokenKind.KW_IN,
        TokenKind.KW_IS,
        TokenKind.KW_LAMBDA,
        TokenKind.KW_PUB,
        TokenKind.KW_PRIV,
        TokenKind.KW_PROT,
        TokenKind.KW_CLIENT,
        TokenKind.KW_SERVER,
        TokenKind.KW_NATIVE,
        TokenKind.KW_SELF,
        TokenKind.KW_PROPS,
        TokenKind.KW_SUPER,
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
    );
}

impl Parser.expect_name -> Token {
    # Expect NAME or KWESC_NAME
    if self.check_name() {
        return self.advance();
    }
    self.error(f"Expected identifier, got {self.current().kind}");
    return self.current();
}

# =============================================================================
# UniToken Creation Implementations
# =============================================================================
impl Parser.make_uni_token(
    tok: Token
) -> UniToken {
    # Convert parser Token into unitree UniToken
    tok_name: str = TOKEN_KIND_TO_TOK[tok.kind]
    if tok.kind in TOKEN_KIND_TO_TOK
    else tok.kind.value;
    return UniToken(
        orig_src=self.get_source(),
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

impl Parser.make_name(tok: Token, is_enum_stmt: bool = False) -> Name {
    # Create a unitree Name from a token
    # Strip <>  prefix from keyword-escaped names
    val = tok.value;
    if val.startswith("<>") {
        val = val[2:];
    }
    return Name(
        orig_src=self.get_source(),
        name=Tok.NAME.value,
        value=val,
        line=tok.loc.line,
        end_line=tok.loc.end_line,
        col_start=tok.loc.col_start,
        col_end=tok.loc.col_end,
        pos_start=tok.loc.pos_start,
        pos_end=tok.loc.pos_end,
        is_enum_stmt=is_enum_stmt
    );
}

impl Parser.make_special_name(tok: Token) -> Name {
    # Create a unitree Name from a special token (self, super, etc.)
    # Using the token's kind as the name attribute for SpecialVarRef compatibility
    tok_name: str = TOKEN_KIND_TO_TOK[tok.kind]
    if tok.kind in TOKEN_KIND_TO_TOK
    else tok.kind.value;
    return Name(
        orig_src=self.get_source(),
        name=tok_name,
        value=tok.value,
        line=tok.loc.line,
        end_line=tok.loc.end_line,
        col_start=tok.loc.col_start,
        col_end=tok.loc.col_end,
        pos_start=tok.loc.pos_start,
        pos_end=tok.loc.pos_end,
        is_enum_stmt=False
    );
}

impl Parser.make_name_or_special(tok: Token) -> Name {
    # Create a Name or special Name depending on token kind.
    # NAME/KWESC_NAME tokens produce regular Names; keyword tokens produce
    # special names with the appropriate Tok mapping for SpecialVarRef.
    if tok.kind == TokenKind.NAME or tok.kind == TokenKind.KWESC_NAME {
        return self.make_name(tok);
    }
    return self.make_special_name(tok);
}

impl Parser.parse_access_tag -> SubTag | None {
    # Parse optional access modifier: :pub, :priv, or :prot
    # Returns a SubTag wrapping the access token, or None if not present.
    if self.match_tok(TokenKind.COLON) {
        if self.check_any(TokenKind.KW_PUB, TokenKind.KW_PRIV, TokenKind.KW_PROT) {
            access_tok = self.advance();
            return SubTag(
                tag=(at := self.make_uni_token(access_tok)),
                kid=[self.gen_token(Tok.COLON.value, ":"), at]
            );
        }
    }
    return None;
}

impl Parser.make_string(tok: Token) -> String {
    # Create a unitree String from a token
    return String(
        orig_src=self.get_source(),
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

impl Parser.make_string_from_value(value: str) -> String {
    # Create a unitree String from a raw value (used for f-string literal braces)
    return String(
        orig_src=self.get_source(),
        name=Tok.STRING.value,
        value=value,
        line=0,
        end_line=0,
        col_start=0,
        col_end=0,
        pos_start=0,
        pos_end=0
    );
}

impl Parser.make_int(tok: Token) -> Int {
    # Create a unitree Int from a token
    return Int(
        orig_src=self.get_source(),
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

impl Parser.make_float(tok: Token) -> Float {
    # Create a unitree Float from a token
    return Float(
        orig_src=self.get_source(),
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

impl Parser.make_bool(tok: Token) -> Bool {
    # Create a unitree Bool from a token
    return Bool(
        orig_src=self.get_source(),
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

impl Parser.make_null(tok: Token) -> Null {
    # Create a unitree Null from a token
    return Null(
        orig_src=self.get_source(),
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

impl Parser.make_ellipsis(tok: Token) -> EllipsisLit {
    # Create a unitree Ellipsis from a token
    return EllipsisLit(
        orig_src=self.get_source(),
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

impl Parser.gen_token(tok_type: str, value: str | None = None) -> UniToken {
    # Generate a synthetic token for kid list construction
    cur = self.current();
    actual_value = value;
    if actual_value is None {
        # Look up actual symbol from TOKEN_KIND_TO_TOK reverse mapping
        # e.g., "LBRACE" -> "{", "KW_GLOBAL" -> "glob", "EQ" -> "="
        for (kind, tok_name) in TOKEN_KIND_TO_TOK.items() {
            if tok_name == tok_type {
                actual_value = kind.value;
                break;
            }
        }
        if actual_value is None {
            actual_value = tok_type;
        }
    }
    return UniToken(
        orig_src=self.get_source(),
        name=tok_type,
        value=actual_value,
        line=cur.loc.line,
        end_line=cur.loc.end_line,
        col_start=cur.loc.col_start,
        col_end=cur.loc.col_end,
        pos_start=cur.loc.pos_start,
        pos_end=cur.loc.pos_end
    );
}

impl Parser.make_semi -> Semi {
    prev = self.previous();
    return Semi(
        orig_src=self.get_source(),
        name=Tok.SEMI.value,
        value=";",
        line=prev.loc.line,
        end_line=prev.loc.end_line,
        col_start=prev.loc.col_start,
        col_end=prev.loc.col_end,
        pos_start=prev.loc.pos_start,
        pos_end=prev.loc.pos_end
    );
}

# =============================================================================
# Synchronization (Error Recovery) Implementations
# =============================================================================
impl Parser.synchronize{
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

# =============================================================================
# Entry Point Implementations
# =============================================================================
impl Parser.parse -> Module {
    return self.parse_module();
}

impl Parser.parse_module -> Module {
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
        source=self.get_source(),
        doc=doc,
        body=body,
        terminals=terminals,
        kid=kid
    );
}

# =============================================================================
# EXPRESSION PARSING Implementations
# =============================================================================
impl Parser.parse_expression -> Expr {
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
            kid=[
                expr,
                self.gen_token(Tok.KW_IF.value),
                condition,
                self.gen_token(Tok.KW_ELSE.value),
                else_value
            ]
        );
    }
    return expr;
}

impl Parser.parse_concurrent_expr -> Expr {
    if self.check_any(TokenKind.KW_FLOW, TokenKind.KW_WAIT) {
        tok = self.advance();
        target = self.parse_walrus_assign();
        uni_tok = self.make_uni_token(tok);
        return ConcurrentExpr(tok=uni_tok, target=target, kid=[uni_tok, target]);
    }
    return self.parse_walrus_assign();
}

impl Parser.parse_walrus_assign -> Expr {
    expr = self.parse_by_expr();
    if self.check(TokenKind.WALRUS_EQ) {
        walrus_tok = self.advance();
        value = self.parse_by_expr();
        op = self.make_uni_token(walrus_tok);
        # Walrus assignment is a BinaryExpr, like in the existing parser
        return BinaryExpr(left=expr, op=op, right=value, kid=[expr, op, value]);
    }
    return expr;
}

impl Parser.parse_by_expr -> Expr {
    left = self.parse_pipe();
    if self.match_tok(TokenKind.KW_BY) {
        right = self.parse_by_expr();
        by_tok = self.gen_token(Tok.KW_BY.value, "by");
        return BinaryExpr(left=left, op=by_tok, right=right, kid=[left, by_tok, right]);
    }
    return left;
}

impl Parser.parse_pipe -> Expr {
    left = self.parse_pipe_back();
    while self.match_tok(TokenKind.PIPE_FWD) {
        op = self.make_uni_token(self.previous());
        right = self.parse_pipe_back();
        left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
    }
    return left;
}

impl Parser.parse_pipe_back -> Expr {
    left = self.parse_bitwise_or();
    while self.match_tok(TokenKind.PIPE_BKWD) {
        op = self.make_uni_token(self.previous());
        right = self.parse_bitwise_or();
        left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
    }
    return left;
}

impl Parser.parse_bitwise_or -> Expr {
    left = self.parse_bitwise_xor();
    while self.match_tok(TokenKind.BW_OR) {
        op = self.make_uni_token(self.previous());
        right = self.parse_bitwise_xor();
        left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
    }
    return left;
}

impl Parser.parse_bitwise_xor -> Expr {
    left = self.parse_bitwise_and();
    while self.match_tok(TokenKind.BW_XOR) {
        op = self.make_uni_token(self.previous());
        right = self.parse_bitwise_and();
        left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
    }
    return left;
}

impl Parser.parse_bitwise_and -> Expr {
    left = self.parse_shift();
    while self.match_tok(TokenKind.BW_AND) {
        op = self.make_uni_token(self.previous());
        right = self.parse_shift();
        left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
    }
    return left;
}

impl Parser.parse_shift -> Expr {
    left = self.parse_logical_or();
    while self.check_any(TokenKind.LSHIFT, TokenKind.RSHIFT) {
        tok = self.advance();
        op = self.make_uni_token(tok);
        right = self.parse_logical_or();
        left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
    }
    return left;
}

impl Parser.parse_logical_or -> Expr {
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

impl Parser.parse_logical_and -> Expr {
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

impl Parser.parse_logical_not -> Expr {
    if self.match_tok(TokenKind.KW_NOT) {
        op = self.make_uni_token(self.previous());
        operand = self.parse_logical_not();
        return UnaryExpr(operand=operand, op=op, kid=[op, operand]);
    }
    return self.parse_compare();
}

impl Parser.parse_compare -> Expr {
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

impl Parser.parse_arithmetic -> Expr {
    left = self.parse_term();
    while self.check_any(TokenKind.PLUS, TokenKind.MINUS) {
        tok = self.advance();
        op = self.make_uni_token(tok);
        right = self.parse_term();
        left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
    }
    return left;
}

impl Parser.parse_term -> Expr {
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

impl Parser.parse_power -> Expr {
    left = self.parse_factor();
    if self.match_tok(TokenKind.STAR_POW) {
        op = self.make_uni_token(self.previous());
        right = self.parse_power();
        left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
    }
    return left;
}

impl Parser.parse_factor -> Expr {
    if self.check_any(TokenKind.BW_NOT, TokenKind.MINUS, TokenKind.PLUS) {
        tok = self.advance();
        op = self.make_uni_token(tok);
        operand = self.parse_factor();
        return UnaryExpr(operand=operand, op=op, kid=[op, operand]);
    }
    return self.parse_connect();
}

"""Parse connect expressions: expr ++> expr, expr <++ expr, etc."""
impl Parser.parse_connect -> Expr {
    left = self.parse_atomic_pipe();
    while True {
        conn_op = self.parse_connect_op();
        if conn_op is None {
            break;
        }
        right = self.parse_atomic_pipe();
        kid: list = [left, conn_op, right];
        left = BinaryExpr(left=left, op=conn_op, right=right, kid=kid);
    }
    return left;
}

"""Parse edge op ref inline (-->, <--, <-->, or typed variants like ->:Type:->)."""
impl Parser.parse_edge_op_ref_inline -> EdgeOpRef | None {
    if self.check_any(TokenKind.ARROW_R, TokenKind.ARROW_L, TokenKind.ARROW_BI) {
        # Simple edge operator: -->, <--, <-->
        tok = self.advance();
        edge_op = self.make_uni_token(tok);
        return EdgeOpRef(filter_cond=None, edge_dir=edge_op, kid=[edge_op]);
    }
    if self.match_tok(TokenKind.ARROW_R_P1) {
        # Typed edge: ->:Type:->
        start = self.make_uni_token(self.previous());
        kid: list = [start];
        if self.check_name() {
            type_name = self.parse_atom();
            kid.append(type_name);
        }
        if self.match_tok(TokenKind.ARROW_R_P2) {
            end = self.make_uni_token(self.previous());
            kid.append(end);
        }
        return EdgeOpRef(filter_cond=None, edge_dir=start, kid=kid);
    }
    if self.match_tok(TokenKind.ARROW_L_P1) {
        # Typed edge: <-:Type:<-
        start = self.make_uni_token(self.previous());
        kid: list = [start];
        if self.check_name() {
            type_name = self.parse_atom();
            kid.append(type_name);
        }
        if self.match_tok(TokenKind.ARROW_L_P2) {
            end = self.make_uni_token(self.previous());
            kid.append(end);
        }
        return EdgeOpRef(filter_cond=None, edge_dir=start, kid=kid);
    }
    return None;
}

"""Parse connect operator (++>, <++, <++>, +>:Type:+>, etc.) or disconnect (del -->)."""
impl Parser.parse_connect_op -> ConnectOp | DisconnectOp | None {
    # Check for disconnect: del followed by edge_op_ref (-->, <--, <-->, or typed variants)
    if self.check(TokenKind.KW_DELETE)
    and self.peek().kind in [
        TokenKind.ARROW_R,
        TokenKind.ARROW_L,
        TokenKind.ARROW_BI,
        TokenKind.ARROW_R_P1,
        TokenKind.ARROW_L_P1
    ] {
        del_tok = self.advance();
        # Parse the edge op ref directly (not in brackets)
        edge_op = self.parse_edge_op_ref_inline();
        if edge_op {
            return DisconnectOp(
                edge_spec=edge_op, kid=[self.make_uni_token(del_tok), edge_op]
            );
        }
    }
    # Connect to: ++> or +>:Type:+>
    if self.match_tok(TokenKind.CARROW_R) {
        tok = self.make_uni_token(self.previous());
        return ConnectOp(
            conn_type=None, conn_assign=None, edge_dir=EdgeDir.OUT, kid=[tok]
        );
    }
    if self.match_tok(TokenKind.CARROW_R_P1) {
        start_tok = self.make_uni_token(self.previous());
        conn_type = self.parse_expression();
        conn_assign: AssignCompr | None = None;
        kid: list = [start_tok, conn_type];
        if self.match_tok(TokenKind.COLON) {
            kid.append(self.gen_token(Tok.COLON.value, ":"));
            # Parse kw_expr_list for conn_assign
            assigns: list = [];
            while not self.check(TokenKind.CARROW_R_P2) and not self.at_end() {
                key_expr = self.parse_expression();
                if self.match_tok(TokenKind.EQ) {
                    val_expr = self.parse_expression();
                    assigns.append(
                        KWPair(
                            key=key_expr,
                            value=val_expr,
                            kid=[key_expr, self.gen_token(Tok.EQ.value, "="), val_expr]
                        )
                    );
                } else {
                    assigns.append(key_expr);
                }
                if not self.match_tok(TokenKind.COMMA) {
                    break;
                }
            }
            if assigns {
                ac_kid: list = [];
                for (i, a) in enumerate(assigns) {
                    ac_kid.append(a);
                    if i < len(assigns) - 1 {
                        ac_kid.append(self.gen_token(Tok.COMMA.value, ","));
                    }
                }
                conn_assign = AssignCompr(assigns=assigns, kid=ac_kid);
                kid.append(conn_assign);
            }
        }
        self.expect(TokenKind.CARROW_R_P2);
        kid.append(self.gen_token(Tok.CARROW_R_P2.value, ":+>"));
        return ConnectOp(
            conn_type=conn_type, conn_assign=conn_assign, edge_dir=EdgeDir.OUT, kid=kid
        );
    }
    # Connect from: <++ or <+:Type:<+
    if self.match_tok(TokenKind.CARROW_L) {
        tok = self.make_uni_token(self.previous());
        return ConnectOp(
            conn_type=None, conn_assign=None, edge_dir=EdgeDir.IN, kid=[tok]
        );
    }
    if self.match_tok(TokenKind.CARROW_L_P1) {
        start_tok = self.make_uni_token(self.previous());
        conn_type = self.parse_expression();
        conn_assign: AssignCompr | None = None;
        kid: list = [start_tok, conn_type];
        if self.match_tok(TokenKind.COLON) {
            kid.append(self.gen_token(Tok.COLON.value, ":"));
            assigns: list = [];
            while not self.check_any(TokenKind.CARROW_L_P2, TokenKind.CARROW_R_P2)
            and not self.at_end() {
                key_expr = self.parse_expression();
                if self.match_tok(TokenKind.EQ) {
                    val_expr = self.parse_expression();
                    assigns.append(
                        KWPair(
                            key=key_expr,
                            value=val_expr,
                            kid=[key_expr, self.gen_token(Tok.EQ.value, "="), val_expr]
                        )
                    );
                } else {
                    assigns.append(key_expr);
                }
                if not self.match_tok(TokenKind.COMMA) {
                    break;
                }
            }
            if assigns {
                ac_kid: list = [];
                for (i, a) in enumerate(assigns) {
                    ac_kid.append(a);
                    if i < len(assigns) - 1 {
                        ac_kid.append(self.gen_token(Tok.COMMA.value, ","));
                    }
                }
                conn_assign = AssignCompr(assigns=assigns, kid=ac_kid);
                kid.append(conn_assign);
            }
        }
        # Check if it's <+:Type:<+ (IN) or <+:Type:+> (ANY)
        if self.match_tok(TokenKind.CARROW_L_P2) {
            kid.append(self.gen_token(Tok.CARROW_L_P2.value, ":<+"));
            return ConnectOp(
                conn_type=conn_type,
                conn_assign=conn_assign,
                edge_dir=EdgeDir.IN,
                kid=kid
            );
        } elif self.match_tok(TokenKind.CARROW_R_P2) {
            kid.append(self.gen_token(Tok.CARROW_R_P2.value, ":+>"));
            return ConnectOp(
                conn_type=conn_type,
                conn_assign=conn_assign,
                edge_dir=EdgeDir.ANY,
                kid=kid
            );
        } else {
            self.error("Expected :<+ or :+> to close connect operator");
            return None;
        }
    }
    # Connect bidirectional: <++>
    if self.match_tok(TokenKind.CARROW_BI) {
        tok = self.make_uni_token(self.previous());
        return ConnectOp(
            conn_type=None, conn_assign=None, edge_dir=EdgeDir.ANY, kid=[tok]
        );
    }
    return None;
}

impl Parser.parse_atomic_pipe -> Expr {
    left = self.parse_atomic_pipe_back();
    while self.match_tok(TokenKind.A_PIPE_FWD) {
        op = self.make_uni_token(self.previous());
        right = self.parse_atomic_pipe_back();
        left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
    }
    return left;
}

impl Parser.parse_atomic_pipe_back -> Expr {
    left = self.parse_spawn();
    while self.match_tok(TokenKind.A_PIPE_BKWD) {
        op = self.make_uni_token(self.previous());
        right = self.parse_spawn();
        left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
    }
    return left;
}

impl Parser.parse_spawn -> Expr {
    # os_spawn: (os_spawn KW_SPAWN)? unpack
    # This handles:
    #   - root spawn test_walker() (binary)
    #   - spawn Obj1 (prefix/unary)

    # Check for prefix spawn first
    if self.check(TokenKind.KW_SPAWN) {
        op_tok = self.advance();
        op = self.make_uni_token(op_tok);
        target = self.parse_unpack();
        # For prefix spawn, treat it as a unary expression
        return UnaryExpr(operand=target, op=op, kid=[op, target]);
    }
    left = self.parse_unpack();
    while self.match_tok(TokenKind.KW_SPAWN) {
        op = self.make_uni_token(self.previous());
        right = self.parse_unpack();
        left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
    }
    return left;
}

impl Parser.parse_unpack -> Expr {
    if self.match_tok(TokenKind.STAR_MUL) {
        op = self.make_uni_token(self.previous());
        target = self.parse_ref();
        return UnaryExpr(operand=target, op=op, kid=[op, target]);
    }
    return self.parse_ref();
}

impl Parser.parse_ref -> Expr {
    if self.match_tok(TokenKind.BW_AND) {
        op = self.make_uni_token(self.previous());
        target = self.parse_await_expr();
        return UnaryExpr(operand=target, op=op, kid=[op, target]);
    }
    return self.parse_await_expr();
}

impl Parser.parse_await_expr -> Expr {
    if self.match_tok(TokenKind.KW_AWAIT) {
        await_tok = self.make_uni_token(self.previous());
        expr = self.parse_pipe_call();
        return AwaitExpr(target=expr, kid=[await_tok, expr]);
    }
    return self.parse_pipe_call();
}

impl Parser.parse_pipe_call -> Expr {
    # Handle pipe operators as unary prefix (for standalone |> expr or <| expr)
    if self.check_any(TokenKind.PIPE_FWD, TokenKind.A_PIPE_FWD) {
        tok = self.advance();
        op = self.make_uni_token(tok);
        target = self.parse_atomic_chain();
        return UnaryExpr(operand=target, op=op, kid=[op, target]);
    }
    return self.parse_atomic_chain();
}

impl Parser.parse_atomic_chain -> Expr {
    expr = self.parse_atom();
    while True {
        if self.match_tok(TokenKind.DOT)
        or self.match_tok(TokenKind.NULL_OK)
        or self.match_tok(TokenKind.DOT_FWD)
        or self.match_tok(TokenKind.DOT_BKWD) {
            dot_kind = self.previous().kind;
            null_ok = dot_kind == TokenKind.NULL_OK;
            is_dot_fwd = dot_kind == TokenKind.DOT_FWD;
            is_dot_bkwd = dot_kind == TokenKind.DOT_BKWD;
            if null_ok
            and self.check_any(TokenKind.DOT, TokenKind.DOT_FWD, TokenKind.DOT_BKWD) {
                dot_kind2 = self.current().kind;
                is_dot_fwd = dot_kind2 == TokenKind.DOT_FWD;
                is_dot_bkwd = dot_kind2 == TokenKind.DOT_BKWD;
                self.advance();
            }
            dot_tok_name = Tok.DOT_FWD.value
            if is_dot_fwd
            else (Tok.DOT_BKWD.value if is_dot_bkwd else Tok.DOT.value);
            dot_tok_val = ".>" if is_dot_fwd else ("<." if is_dot_bkwd else ".");
            # Allow NAME, KWESC_NAME, or any keyword as attribute names after DOT
            attr: Name | None = None;
            if self.check_name() {
                name_tok = self.advance();
                attr = self.make_name(name_tok);
            } elif self.check_any(
                TokenKind.KW_INIT,
                TokenKind.KW_POST_INIT,
                TokenKind.KW_SELF,
                TokenKind.KW_PROPS,
                TokenKind.KW_SUPER,
                TokenKind.KW_ROOT,
                TokenKind.KW_HERE,
                TokenKind.KW_VISITOR
            ) {
                name_tok = self.advance();
                attr = SpecialVarRef(
                    var=self.make_special_name(name_tok), is_enum_stmt=False
                );
            } elif self.is_keyword_token() {
                name_tok = self.advance();
                attr = self.make_special_name(name_tok);
            }
            if attr {
                kid: list = [expr];
                if null_ok {
                    kid.append(self.gen_token(Tok.NULL_OK.value, "?"));
                }
                kid.append(self.gen_token(dot_tok_name, dot_tok_val));
                kid.append(attr);
                target_node = expr if not is_dot_bkwd else attr;
                right_node = attr if not is_dot_bkwd else expr;
                expr = AtomTrailer(
                    target=target_node,
                    right=right_node,
                    is_attr=True,
                    is_null_ok=null_ok,
                    kid=kid
                );
            }
        } elif self.check(TokenKind.LPAREN) {
            # Check if this is filter_compr: (? ...) or (`?Type ...)
            if self.peek().kind == TokenKind.NULL_OK
            or (
                self.peek().kind == TokenKind.TYPE_OP
                and self.peek(2).kind == TokenKind.NULL_OK
            ) {
                # Parse filter comprehension: (?val==10) or (`?Type:val==10)
                self.advance();  # consume LPAREN
                filter_expr = self.parse_filter_compr_inner();
                self.expect(TokenKind.RPAREN);
                # Wrap in AtomTrailer
                kid = [expr, filter_expr];
                expr = AtomTrailer(
                    target=expr,
                    right=filter_expr,
                    is_attr=False,
                    is_null_ok=False,
                    kid=kid
                );
            } elif self.peek().kind == TokenKind.EQ {
                # Parse assign_compr: (=a=5, b=6)
                self.advance();  # consume LPAREN
                assign_expr = self.parse_assign_compr_inner();
                self.expect(TokenKind.RPAREN);
                # Wrap in AtomTrailer
                kid = [expr, assign_expr];
                expr = AtomTrailer(
                    target=expr,
                    right=assign_expr,
                    is_attr=False,
                    is_null_ok=False,
                    kid=kid
                );
            } else {
                # Regular function call
                self.advance();  # consume LPAREN
                kid = [expr, self.gen_token(Tok.LPAREN.value, "(")];
                args = self.parse_call_args(kid);
                self.expect(TokenKind.RPAREN);
                kid.append(self.gen_token(Tok.RPAREN.value, ")"));
                # If the sole argument is a GenCompr, move parens into GenCompr
                # (Lark grammar: atomic_call uses gen_compr which includes parens)
                if len(args) == 1 and isinstance(args[0], GenCompr) {
                    old_gc = args[0];
                    lparen_tok = kid[1];
                    rparen_tok = kid[len(kid) - 1];
                    new_gc_kid: list = [lparen_tok];
                    for c in old_gc.kid {
                        new_gc_kid.append(c);
                    }
                    new_gc_kid.append(rparen_tok);
                    gencompr = GenCompr(
                        out_expr=old_gc.out_expr, compr=old_gc.compr, kid=new_gc_kid
                    );
                    args = [gencompr];
                    kid = [expr, gencompr];
                }
                expr = FuncCall(target=expr, params=args, genai_call=None, kid=kid);
            }
        } elif self.match_tok(TokenKind.LSQUARE) {
            # Parse index or slice: a[x], a[x,y], a[1:2], a[::3], etc.
            # First, parse optional first expression
            first_expr: UniNode | None = None;
            if not self.check_any(TokenKind.RSQUARE, TokenKind.COLON) {
                first_expr = self.parse_expression();
            }
            if self.check(TokenKind.COLON) {
                # Slice expression: expr? COLON expr? (COLON expr?)?
                # (COMMA expr? COLON expr? (COLON expr?)?)*
                slice_kid: list = [self.gen_token(Tok.LSQUARE.value, "[")];
                slices: list = [];
                if first_expr is not None {
                    slice_kid.append(first_expr);
                }
                self.expect(TokenKind.COLON);
                slice_kid.append(self.gen_token(Tok.COLON.value, ":"));
                stop: UniNode | None = None;
                if not self.check_any(
                    TokenKind.COLON, TokenKind.RSQUARE, TokenKind.COMMA
                ) {
                    stop = self.parse_expression();
                    slice_kid.append(stop);
                }
                step: UniNode | None = None;
                if self.match_tok(TokenKind.COLON) {
                    slice_kid.append(self.gen_token(Tok.COLON.value, ":"));
                    if not self.check_any(TokenKind.RSQUARE, TokenKind.COMMA) {
                        step = self.parse_expression();
                        slice_kid.append(step);
                    }
                }
                slices.append(IndexSlice.Slice(start=first_expr, stop=stop, step=step));
                while self.match_tok(TokenKind.COMMA) {
                    slice_kid.append(self.gen_token(Tok.COMMA.value, ","));
                    s2: UniNode | None = None;
                    if not self.check(TokenKind.COLON) {
                        s2 = self.parse_expression();
                        slice_kid.append(s2);
                    }
                    self.expect(TokenKind.COLON);
                    slice_kid.append(self.gen_token(Tok.COLON.value, ":"));
                    e2: UniNode | None = None;
                    if not self.check_any(
                        TokenKind.COLON, TokenKind.RSQUARE, TokenKind.COMMA
                    ) {
                        e2 = self.parse_expression();
                        slice_kid.append(e2);
                    }
                    t2: UniNode | None = None;
                    if self.match_tok(TokenKind.COLON) {
                        slice_kid.append(self.gen_token(Tok.COLON.value, ":"));
                        if not self.check_any(TokenKind.RSQUARE, TokenKind.COMMA) {
                            t2 = self.parse_expression();
                            slice_kid.append(t2);
                        }
                    }
                    slices.append(IndexSlice.Slice(start=s2, stop=e2, step=t2));
                }
                self.expect(TokenKind.RSQUARE);
                slice_kid.append(self.gen_token(Tok.RSQUARE.value, "]"));
                index_slice = IndexSlice(slices=slices, is_range=True, kid=slice_kid);
                kid = [expr, index_slice];
                expr = AtomTrailer(
                    target=expr,
                    right=index_slice,
                    is_attr=False,
                    is_null_ok=False,
                    kid=kid
                );
            } else {
                # Regular index access: a[x] or a[x, y, ...]
                indices: list = [];
                list_kid: list = [self.gen_token(Tok.LSQUARE.value, "[")];
                if first_expr is not None {
                    indices.append(first_expr);
                    list_kid.append(first_expr);
                    while self.match_tok(TokenKind.COMMA) {
                        list_kid.append(self.gen_token(Tok.COMMA.value, ","));
                        if self.check(TokenKind.RSQUARE) {
                            break;
                        }
                        idx = self.parse_expression();
                        indices.append(idx);
                        list_kid.append(idx);
                    }
                }
                self.expect(TokenKind.RSQUARE);
                list_kid.append(self.gen_token(Tok.RSQUARE.value, "]"));
                list_val = ListVal(values=indices, kid=list_kid);
                if len(indices) == 1 {
                    idx_expr = indices[0];
                    index_slice_kid: list = [list_val];
                } else {
                    idx_expr = TupleVal(values=indices, kid=list_kid);
                    index_slice_kid = [idx_expr];
                }
                index_slice = IndexSlice(
                    slices=[IndexSlice.Slice(start=idx_expr, stop=None, step=None)],
                    is_range=False,
                    kid=index_slice_kid
                );
                kid = [expr, index_slice];
                expr = AtomTrailer(
                    target=expr,
                    right=index_slice,
                    is_attr=False,
                    is_null_ok=False,
                    kid=kid
                );
            }
        } else {
            break;
        }
    }
    return expr;
}

impl Parser.parse_call_args(kid: list) -> list {
    args: list = [];
    if self.check(TokenKind.RPAREN) {
        return args;
    }
    arg = self.parse_call_arg();
    args.append(arg);
    kid.append(arg);
    while self.match_tok(TokenKind.COMMA) {
        kid.append(self.gen_token(Tok.COMMA.value, ","));
        if self.check(TokenKind.RPAREN) {
            break;
        }
        arg = self.parse_call_arg();
        args.append(arg);
        kid.append(arg);
    }
    return args;
}

impl Parser.parse_call_arg -> Expr | KWPair {
    # Check for keyword argument: NAME = expr (also KWESC_NAME like <>type)
    if (self.check_name() or self.is_keyword_token())
    and self.peek().kind == TokenKind.EQ {
        name_tok = self.advance();
        name: Name;
        if name_tok.kind == TokenKind.NAME or name_tok.kind == TokenKind.KWESC_NAME {
            name = self.make_name(name_tok);
        } elif name_tok.kind in [
            TokenKind.KW_SELF,
            TokenKind.KW_PROPS,
            TokenKind.KW_SUPER,
            TokenKind.KW_ROOT,
            TokenKind.KW_HERE,
            TokenKind.KW_VISITOR
        ] {
            name = SpecialVarRef(
                var=self.make_special_name(name_tok), is_enum_stmt=False
            );
        } else {
            name = self.make_special_name(name_tok);
        }
        self.advance();  # consume '='
        value = self.parse_expression();
        return KWPair(
            key=name, value=value, kid=[name, self.gen_token(Tok.EQ.value), value]
        );
    }
    # Check for **kwargs spread
    if self.check(TokenKind.STAR_POW) {
        star_tok = self.advance();
        star = self.make_uni_token(star_tok);
        value = self.parse_expression();
        return KWPair(key=None, value=value, kid=[star, value]);
    }
    # Check for *args spread
    if self.check(TokenKind.STAR_MUL) {
        star_tok = self.advance();
        star = self.make_uni_token(star_tok);
        value = self.parse_expression();
        return UnaryExpr(op=star, operand=value, kid=[star, value]);
    }
    # Parse expression, then check if it's a generator expression
    expr = self.parse_expression();
    # If followed by 'for', it's a generator expression: all(x > 0 for x in items)
    if self.check(TokenKind.KW_FOR) {
        comprs = self.parse_comprehension_clauses();
        kid: list = [expr];
        kid.extend(comprs);
        return GenCompr(compr=comprs, out_expr=expr, kid=kid);
    }
    return expr;
}

impl Parser.parse_filter_compr_inner -> FilterCompr {
    # Parse inner part of filter_compr after LPAREN is consumed
    # filter_compr: LPAREN NULL_OK filter_compare_list RPAREN
    #             | LPAREN TYPE_OP NULL_OK typed_filter_compare_list RPAREN
    kid: list = [self.gen_token(Tok.LPAREN.value, "(")];
    f_type = None;
    # Check for TYPE_OP variant: (`? Type: ...)
    if self.check(TokenKind.TYPE_OP) {
        kid.append(self.make_uni_token(self.advance()));  # consume `
        self.expect(TokenKind.NULL_OK);  # consume ?
        kid.append(self.gen_token(Tok.NULL_OK.value, "?"));
        f_type = self.parse_expression();
        kid.append(f_type);
        if self.match_tok(TokenKind.COLON) {
            kid.append(self.gen_token(Tok.COLON.value, ":"));
        }
    } else {
        # Simple form: (? ...)
        self.expect(TokenKind.NULL_OK);  # consume ?
        kid.append(self.gen_token(Tok.NULL_OK.value, "?"));
    }
    # Parse filter_compare_list
    compares: list = [];
    if not self.check(TokenKind.RPAREN) {
        # Parse comparison: expr cmp_op expr
        comp = self.parse_compare();
        compares.append(comp);
        kid.append(comp);
        while self.match_tok(TokenKind.COMMA) {
            kid.append(self.gen_token(Tok.COMMA.value, ","));
            comp = self.parse_compare();
            compares.append(comp);
            kid.append(comp);
        }
    }
    kid.append(self.gen_token(Tok.RPAREN.value, ")"));
    return FilterCompr(f_type=f_type, compares=compares, kid=kid);
}

impl Parser.parse_assign_compr_inner -> AssignCompr {
    # Parse inner part of assign_compr after LPAREN is consumed
    # assign_compr: LPAREN EQ kw_expr_list RPAREN
    kid: list = [self.gen_token(Tok.LPAREN.value, "(")];
    self.expect(TokenKind.EQ);  # consume the leading =
    kid.append(self.gen_token(Tok.EQ.value, "="));
    assigns: list = [];
    # Parse kw_expr_list: name=expr, name=expr, ...
    if not self.check(TokenKind.RPAREN) {
        name_tok = self.expect_name();
        name = self.make_name(name_tok);
        self.expect(TokenKind.EQ);
        value = self.parse_expression();
        kw = KWPair(
            key=name, value=value, kid=[name, self.gen_token(Tok.EQ.value), value]
        );
        assigns.append(kw);
        kid.append(kw);
        while self.match_tok(TokenKind.COMMA) {
            kid.append(self.gen_token(Tok.COMMA.value, ","));
            if self.check(TokenKind.RPAREN) {
                break;
            }
            name_tok = self.expect_name();
            name = self.make_name(name_tok);
            self.expect(TokenKind.EQ);
            value = self.parse_expression();
            kw = KWPair(
                key=name, value=value, kid=[name, self.gen_token(Tok.EQ.value), value]
            );
            assigns.append(kw);
            kid.append(kw);
        }
    }
    kid.append(self.gen_token(Tok.RPAREN.value, ")"));
    return AssignCompr(assigns=assigns, kid=kid);
}

impl Parser.parse_atom -> Expr {
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
        # Handle implicit string concatenation - collect consecutive strings
        strings: list = [];
        first_tok = self.advance();
        strings.append(self.make_string(first_tok));
        # Check for consecutive strings (implicit concatenation)
        while self.check(TokenKind.STRING)
        or self.check_any(
            TokenKind.F_DQ_START,
            TokenKind.F_SQ_START,
            TokenKind.F_TDQ_START,
            TokenKind.F_TSQ_START
        ) {
            if self.check(TokenKind.STRING) {
                tok = self.advance();
                strings.append(self.make_string(tok));
            } else {
                strings.append(self.parse_fstring());
            }
        }
        return MultiString(strings=strings, kid=strings);
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
        builtin_name: str = TOKEN_KIND_TO_TOK[tok.kind]
        if tok.kind in TOKEN_KIND_TO_TOK
        else tok.kind.value;
        return BuiltinType(
            orig_src=self.get_source(),
            name=builtin_name,
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
        # Handle optional type filter: `?Name (nullable type in edge filter)
        null_ok_tok: UniToken | None = None;
        if self.match_tok(TokenKind.NULL_OK) {
            null_ok_tok = self.make_uni_token(self.previous());
        }
        if self.check_name() {
            name_tok = self.advance();
            name = self.make_name(name_tok);
            kid: list = [type_op];
            if null_ok_tok {
                kid.append(null_ok_tok);
            }
            kid.append(name);
            return TypeRef(target=name, kid=kid);
        }
        # Handle archetype keywords: `node, `edge, `walker, etc.
        if self.check_any(
            TokenKind.KW_NODE,
            TokenKind.KW_EDGE,
            TokenKind.KW_WALKER,
            TokenKind.KW_OBJECT,
            TokenKind.KW_CLASS
        ) {
            tok = self.advance();
            name = self.make_special_name(tok);
            kid = [type_op];
            if null_ok_tok {
                kid.append(null_ok_tok);
            }
            kid.append(name);
            return TypeRef(target=name, kid=kid);
        }
        # Handle special var refs: `root, `self, `here, `visitor, `super
        if self.check_any(
            TokenKind.KW_ROOT,
            TokenKind.KW_SELF,
            TokenKind.KW_HERE,
            TokenKind.KW_VISITOR,
            TokenKind.KW_SUPER
        ) {
            tok = self.advance();
            var_name = self.make_special_name(tok);
            ref = SpecialVarRef(var=var_name, is_enum_stmt=False);
            kid = [type_op];
            if null_ok_tok {
                kid.append(null_ok_tok);
            }
            kid.append(ref);
            return TypeRef(target=ref, kid=kid);
        }
        # Handle builtin types: `int, `str, etc.
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
            builtin_name: str = TOKEN_KIND_TO_TOK[tok.kind]
            if tok.kind in TOKEN_KIND_TO_TOK
            else tok.kind.value;
            builtin = BuiltinType(
                orig_src=self.get_source(),
                name=builtin_name,
                value=tok.value,
                line=tok.loc.line,
                end_line=tok.loc.end_line,
                col_start=tok.loc.col_start,
                col_end=tok.loc.col_end,
                pos_start=tok.loc.pos_start,
                pos_end=tok.loc.pos_end
            );
            return TypeRef(target=builtin, kid=[type_op, builtin]);
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
        var_name = self.make_special_name(tok);
        return SpecialVarRef(var=var_name, is_enum_stmt=False);
    }
    # Handle archetype keywords as type names (node, edge, walker, object, class, enum)
    if self.check_any(
        TokenKind.KW_NODE,
        TokenKind.KW_EDGE,
        TokenKind.KW_WALKER,
        TokenKind.KW_OBJECT,
        TokenKind.KW_CLASS,
        TokenKind.KW_ENUM
    ) {
        tok = self.advance();
        return self.make_special_name(tok);
    }
    # Handle string prefixes: r'...', b'...', rb'...', br'...', etc.
    if self.check(TokenKind.NAME)
    and self.current().value in [
        "r",
        "b",
        "rb",
        "br",
        "R",
        "B",
        "rB",
        "Rb",
        "bR",
        "Br",
        "BR",
        "RB"
    ]
    and self.peek().kind == TokenKind.STRING {
        prefix_tok = self.advance();
        str_tok = self.advance();
        combined = self.make_string(str_tok);
        combined.value = prefix_tok.value + combined.value;
        strings: list = [combined];
        while self.check(TokenKind.STRING)
        or self.check_any(
            TokenKind.F_DQ_START,
            TokenKind.F_SQ_START,
            TokenKind.F_TDQ_START,
            TokenKind.F_TSQ_START
        ) {
            if self.check(TokenKind.STRING) {
                tok = self.advance();
                strings.append(self.make_string(tok));
            } else {
                strings.append(self.parse_fstring());
            }
        }
        return MultiString(strings=strings, kid=strings);
    }
    if self.check(TokenKind.NAME) or self.check(TokenKind.KWESC_NAME) {
        tok = self.advance();
        return self.make_name(tok);
    }
    # Contextual keywords: these are keywords that can also be used as
    # identifiers in expression context (Lark's ContextualLexer handles
    # this automatically; we handle it explicitly here)
    if self.is_keyword_token() {
        tok = self.advance();
        return self.make_special_name(tok);
    }
    # Star expressions: *args (unpack) and **kwargs (dict unpack)
    if self.check(TokenKind.STAR_MUL) {
        star_tok = self.advance();
        star = self.make_uni_token(star_tok);
        operand = self.parse_expression();
        return UnaryExpr(op=star, operand=operand, kid=[star, operand]);
    }
    if self.check(TokenKind.STAR_POW) {
        star_tok = self.advance();
        star = self.make_uni_token(star_tok);
        value = self.parse_expression();
        return KWPair(key=None, value=value, kid=[star, value]);
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
        # IIFE: (def func_name(params) { body })(args)
        if self.check_any(TokenKind.KW_DEF, TokenKind.KW_CAN, TokenKind.KW_ASYNC) {
            func_def = self.parse_ability();
            self.expect(TokenKind.RPAREN);
            return AtomUnit(
                value=func_def,
                kid=[
                    self.gen_token(Tok.LPAREN.value),
                    func_def,
                    self.gen_token(Tok.RPAREN.value)
                ]
            );
        }
        expr = self.parse_expression();
        # Standalone generator expression: (expr for x in items)
        if self.check(TokenKind.KW_FOR) {
            comprs = self.parse_comprehension_clauses();
            gc_kid: list = [self.gen_token(Tok.LPAREN.value), expr];
            gc_kid.extend(comprs);
            self.expect(TokenKind.RPAREN);
            gc_kid.append(self.gen_token(Tok.RPAREN.value));
            return GenCompr(out_expr=expr, compr=comprs, kid=gc_kid);
        }
        if self.match_tok(TokenKind.COMMA) {
            values = [expr];
            trailing_comma = True;
            while not self.check(TokenKind.RPAREN) and not self.at_end() {
                values.append(self.parse_expression());
                if self.match_tok(TokenKind.COMMA) {
                    trailing_comma = True;
                } else {
                    trailing_comma = False;
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
            if trailing_comma {
                kid.append(self.gen_token(Tok.COMMA.value, ","));
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
        # Check if this is an edge reference chain [-->], [<--], [<-->], [->:a:->], etc.
        # Note: [[<--]-->] is handled by parse_edge_ref_chain when it parses the start expression
        if self.check_any(
            TokenKind.ARROW_R,
            TokenKind.ARROW_L,
            TokenKind.ARROW_BI,
            TokenKind.ARROW_R_P1,
            TokenKind.ARROW_L_P1,
            TokenKind.RETURN_HINT,  # For typed edges like [->:a:->]
            TokenKind.KW_ASYNC,
            TokenKind.KW_NODE,
            TokenKind.KW_EDGE
        )
        or (
            self.check_any(
                TokenKind.NAME,
                TokenKind.KW_ROOT,
                TokenKind.KW_SELF,
                TokenKind.KW_HERE,
                TokenKind.KW_SUPER,
                TokenKind.KW_VISITOR
            )
            and self.peek().kind in [
                TokenKind.ARROW_R,
                TokenKind.ARROW_L,
                TokenKind.ARROW_BI,
                TokenKind.ARROW_R_P1,  # For typed edges like [self->:Type:->]
                TokenKind.ARROW_L_P1,  # For typed edges like [self<-:Type:<-]
                TokenKind.RETURN_HINT  # For [root->:a:->]
            ]
        ) {
            return self.parse_edge_ref_chain();
        }
        return self.parse_list_or_compr();
    }
    if self.match_tok(TokenKind.LBRACE) {
        return self.parse_dict_or_set();
    }
    # F-string parsing
    if self.check_any(
        TokenKind.F_DQ_START,
        TokenKind.F_SQ_START,
        TokenKind.F_TDQ_START,
        TokenKind.F_TSQ_START
    ) {
        # Handle implicit string concatenation starting with f-string
        strings: list = [];
        strings.append(self.parse_fstring());
        # Check for consecutive strings (implicit concatenation)
        while self.check(TokenKind.STRING)
        or self.check_any(
            TokenKind.F_DQ_START,
            TokenKind.F_SQ_START,
            TokenKind.F_TDQ_START,
            TokenKind.F_TSQ_START
        ) {
            if self.check(TokenKind.STRING) {
                tok = self.advance();
                strings.append(self.make_string(tok));
            } else {
                strings.append(self.parse_fstring());
            }
        }
        return MultiString(strings=strings, kid=strings);
    }
    # JSX element: <Tag>...</Tag> or <>...</>
    if self.check(TokenKind.JSX_OPEN_START) or self.check(TokenKind.JSX_FRAG_OPEN) {
        return self.parse_jsx_element();
    }
    self.error(f"Unexpected token in expression: {self.current().kind}");
    return self.make_name(self.advance());
}

impl Parser.parse_fstring -> FString {
    # Get the start token and determine end token type
    start_tok = self.advance();
    start = self.make_uni_token(start_tok);
    end_kind: TokenKind;
    text_kind: TokenKind;
    if start_tok.kind == TokenKind.F_DQ_START {
        end_kind = TokenKind.F_DQ_END;
        text_kind = TokenKind.F_TEXT_DQ;
    } elif start_tok.kind == TokenKind.F_SQ_START {
        end_kind = TokenKind.F_SQ_END;
        text_kind = TokenKind.F_TEXT_SQ;
    } elif start_tok.kind == TokenKind.F_TDQ_START {
        end_kind = TokenKind.F_TDQ_END;
        text_kind = TokenKind.F_TEXT_TDQ;
    } else {
        end_kind = TokenKind.F_TSQ_END;
        text_kind = TokenKind.F_TEXT_TSQ;
    }
    parts: list[String | FormattedValue] = [];
    kid: list = [start];
    while not self.check(end_kind) and not self.at_end() {
        if self.check(text_kind) {
            text_tok = self.advance();
            part = self.make_string(text_tok);
            parts.append(part);
            kid.append(part);
        } elif self.check(TokenKind.D_LBRACE) {
            # Escaped literal brace {{ → String with value "{"
            self.advance();
            part = self.make_string_from_value("{");
            parts.append(part);
            kid.append(part);
        } elif self.check(TokenKind.D_RBRACE) {
            # Escaped literal brace }} → String with value "}"
            self.advance();
            part = self.make_string_from_value("}");
            parts.append(part);
            kid.append(part);
        } elif self.match_tok(TokenKind.LBRACE) {
            # Parse expression inside braces, with optional !conv and :format_spec
            expr = self.parse_expression();
            conv = 0;
            fv_kid: list = [self.gen_token(Tok.LBRACE.value, "{"), expr];
            # Handle conversion: !r, !s, !a
            if self.check(TokenKind.CONV) {
                conv_tok = self.advance();
                conv = ord(conv_tok.value[1]) if len(conv_tok.value) > 1 else 0;
                fv_kid.append(self.make_uni_token(conv_tok));
            }
            # Handle format spec: :format
            format_spec = None;
            if self.check(TokenKind.COLON) {
                self.advance();
                fv_kid.append(self.gen_token(Tok.COLON.value, ":"));
                # Collect all tokens until RBRACE as format spec text
                spec_parts: list[str] = [];
                while not self.check(TokenKind.RBRACE) and not self.at_end() {
                    spec_tok = self.advance();
                    spec_parts.append(spec_tok.value);
                }
                if spec_parts {
                    spec_text = "";
                    for sp in spec_parts {
                        spec_text += sp;
                    }
                    format_spec = self.make_string_from_value(spec_text);
                    fv_kid.append(format_spec);
                }
            }
            self.expect(TokenKind.RBRACE);
            fv_kid.append(self.gen_token(Tok.RBRACE.value, "}"));
            fv = FormattedValue(
                format_part=expr, conversion=conv, format_spec=format_spec, kid=fv_kid
            );
            parts.append(fv);
            kid.append(fv);
        } else {
            # Skip unexpected tokens
            self.advance();
        }
    }
    end: UniToken | None = None;
    if self.check(end_kind) {
        end_tok = self.advance();
        end = self.make_uni_token(end_tok);
        kid.append(end);
    }
    return FString(start=start, parts=parts, end=end, kid=kid);
}

impl Parser.parse_list_or_compr -> Expr {
    if self.check(TokenKind.RSQUARE) {
        self.advance();
        return ListVal(
            values=[],
            kid=[self.gen_token(Tok.LSQUARE.value), self.gen_token(Tok.RSQUARE.value)]
        );
    }
    first = self.parse_expression();
    if self.check(TokenKind.KW_FOR) {
        comprs = self.parse_comprehension_clauses();
        self.expect(TokenKind.RSQUARE);
        kid: list = [self.gen_token(Tok.LSQUARE.value), first];
        kid.extend(comprs);
        kid.append(self.gen_token(Tok.RSQUARE.value));
        return ListCompr(out_expr=first, compr=comprs, kid=kid);
    }
    # Check if this is an edge ref chain with expression as start (like [[<--]-->])
    if self.check_any(
        TokenKind.ARROW_R,
        TokenKind.ARROW_L,
        TokenKind.ARROW_BI,
        TokenKind.ARROW_R_P1,
        TokenKind.ARROW_L_P1
    ) {
        # Continue parsing as edge ref chain with first as the start expression
        return self.continue_edge_ref_chain(first);
    }
    values = [first];
    kid = [self.gen_token(Tok.LSQUARE.value), first];
    while self.match_tok(TokenKind.COMMA) {
        kid.append(self.gen_token(Tok.COMMA.value, ","));
        if self.check(TokenKind.RSQUARE) {
            break;
        }
        val = self.parse_expression();
        values.append(val);
        kid.append(val);
    }
    self.expect(TokenKind.RSQUARE);
    kid.append(self.gen_token(Tok.RSQUARE.value));
    return ListVal(values=values, kid=kid);
}

"""Continue parsing edge ref chain when start expression is already parsed."""
impl Parser.continue_edge_ref_chain(start_expr: Expr) -> Expr {
    # Already consumed LSQUARE and parsed start_expr
    # This follows the same structure as parse_edge_ref_chain but with
    # an already-parsed starting expression.
    kid: list = [self.gen_token(Tok.LSQUARE.value), start_expr];
    chain: list = [start_expr];
    while True {
        edge_op_ref: EdgeOpRef | None = None;
        # Check for simple edge operators: -->, <--, <-->
        if self.check_any(TokenKind.ARROW_R, TokenKind.ARROW_L, TokenKind.ARROW_BI) {
            edge_tok = self.advance();
            edge_uni = self.make_uni_token(edge_tok);
            dir = EdgeDir.OUT;
            if edge_tok.kind == TokenKind.ARROW_L {
                dir = EdgeDir.IN;
            } elif edge_tok.kind == TokenKind.ARROW_BI {
                dir = EdgeDir.ANY;
            }
            edge_op_ref = EdgeOpRef(filter_cond=None, edge_dir=dir, kid=[edge_uni]);
        } elif self.check(TokenKind.ARROW_R_P1) {
            self.advance();
            start_uni = self.make_uni_token(self.previous());
            f_type = None;
            fcompr_kid: list = [];
            if self.check_name() {
                f_type = self.parse_atom();
                fcompr_kid.append(f_type);
            }
            fcond = FilterCompr(f_type=f_type, compares=[], kid=fcompr_kid);
            end_uni = self.gen_token(Tok.ARROW_R_P2.value);
            if self.check(TokenKind.ARROW_R_P2) {
                self.advance();
            }
            edge_op_ref = EdgeOpRef(
                filter_cond=fcond,
                edge_dir=EdgeDir.OUT,
                kid=[start_uni, fcond, end_uni]
            );
        } elif self.check(TokenKind.ARROW_L_P1) {
            self.advance();
            start_uni = self.make_uni_token(self.previous());
            f_type = None;
            fcompr_kid: list = [];
            if self.check_name() {
                f_type = self.parse_atom();
                fcompr_kid.append(f_type);
            }
            fcond = FilterCompr(f_type=f_type, compares=[], kid=fcompr_kid);
            end_uni = self.gen_token(Tok.ARROW_L_P2.value);
            if self.check(TokenKind.ARROW_L_P2) {
                self.advance();
            }
            edge_op_ref = EdgeOpRef(
                filter_cond=fcond, edge_dir=EdgeDir.IN, kid=[start_uni, fcond, end_uni]
            );
        } else {
            break;
        }
        if edge_op_ref is not None {
            chain.append(edge_op_ref);
            kid.append(edge_op_ref);
        }
        # Check for filter expressions after edge operator
        if self.check(TokenKind.LPAREN) {
            if self.peek().kind == TokenKind.NULL_OK
            or (
                self.peek().kind == TokenKind.TYPE_OP
                and self.peek(2).kind == TokenKind.NULL_OK
            ) {
                self.advance();
                filter_expr = self.parse_filter_compr_inner();
                chain.append(filter_expr);
                kid.append(filter_expr);
                self.expect(TokenKind.RPAREN);
            } else {
                self.advance();
                kid.append(self.gen_token(Tok.LPAREN.value));
                filter_expr = self.parse_expression();
                chain.append(filter_expr);
                kid.append(filter_expr);
                self.expect(TokenKind.RPAREN);
                kid.append(self.gen_token(Tok.RPAREN.value));
            }
        }
    }
    self.expect(TokenKind.RSQUARE);
    kid.append(self.gen_token(Tok.RSQUARE.value));
    return EdgeRefTrailer(chain=chain, edges_only=False, is_async=False, kid=kid);
}

impl Parser.parse_edge_ref_chain -> Expr {
    # Parse edge reference chain: [-->], [<--], [<-->], [root-->], [->:a:->], etc.
    # Already consumed LSQUARE
    kid: list = [self.gen_token(Tok.LSQUARE.value)];
    chain: list = [];
    is_async = False;
    edges_only = False;
    if self.match_tok(TokenKind.KW_ASYNC) {
        is_async = True;
        kid.append(self.gen_token(Tok.KW_ASYNC.value));
    }
    # Optional node/edge filter keyword
    if self.check(TokenKind.KW_EDGE) {
        edges_only = True;
        filter_tok = self.advance();
        kid.append(self.make_uni_token(filter_tok));
    } elif self.check(TokenKind.KW_NODE) {
        self.advance();
        kid.append(self.make_uni_token(self.previous()));
    }
    # Parse optional starting expression (e.g., root, self, here)
    if self.check_any(
        TokenKind.NAME,
        TokenKind.KWESC_NAME,
        TokenKind.KW_ROOT,
        TokenKind.KW_SELF,
        TokenKind.KW_HERE,
        TokenKind.KW_SUPER,
        TokenKind.KW_VISITOR,
        TokenKind.LSQUARE
    ) {
        start_expr = self.parse_atomic_chain();
        chain.append(start_expr);
        kid.append(start_expr);
    }
    # Parse edge operations
    while True {
        edge_op_ref: EdgeOpRef | None = None;
        # Simple edge operators: -->, <--, <-->
        if self.check_any(TokenKind.ARROW_R, TokenKind.ARROW_L, TokenKind.ARROW_BI) {
            edge_tok = self.advance();
            edge_uni = self.make_uni_token(edge_tok);
            dir = EdgeDir.OUT;
            if edge_tok.kind == TokenKind.ARROW_L {
                dir = EdgeDir.IN;
            } elif edge_tok.kind == TokenKind.ARROW_BI {
                dir = EdgeDir.ANY;
            }
            edge_op_ref = EdgeOpRef(filter_cond=None, edge_dir=dir, kid=[edge_uni]);
        }
        # Typed edge out: ->:type:-> (as RETURN_HINT + COLON ... ARROW_R_P2)
        elif self.check(TokenKind.RETURN_HINT) and self.peek().kind == TokenKind.COLON {
            self.advance();  # ->
            self.advance();  # :
            start_uni = self.gen_token(Tok.ARROW_R_P1.value);
            # Parse typed filter compare list
            f_type = None;
            compares: list = [];
            fcompr_kid: list = [];
            if self.check_name()
            or self.check_any(
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
                f_type = self.parse_atom();
                fcompr_kid.append(f_type);
            }
            # Parse optional filter conditions: :field==val,field2==val2
            if self.check(TokenKind.COLON)
            and not self.check_any(TokenKind.ARROW_R_P2, TokenKind.ARROW_L_P2) {
                self.advance();  # :
                fcompr_kid.append(self.gen_token(Tok.COLON.value));
                if not self.check_any(TokenKind.ARROW_R_P2, TokenKind.ARROW_L_P2) {
                    cmp = self.parse_compare();
                    compares.append(cmp);
                    fcompr_kid.append(cmp);
                    while self.match_tok(TokenKind.COMMA) {
                        fcompr_kid.append(self.gen_token(Tok.COMMA.value));
                        cmp = self.parse_compare();
                        compares.append(cmp);
                        fcompr_kid.append(cmp);
                    }
                }
            }
            fcond = FilterCompr(f_type=f_type, compares=compares, kid=fcompr_kid);
            # Expect closing :->
            end_uni = self.gen_token(Tok.ARROW_R_P2.value);
            if self.check(TokenKind.ARROW_R_P2) {
                self.advance();
            }
            edge_op_ref = EdgeOpRef(
                filter_cond=fcond,
                edge_dir=EdgeDir.OUT,
                kid=[start_uni, fcond, end_uni]
            );
        }
        # Typed edge in: <-:type:<- or <-:type:a==1,b==2:<-
        elif self.check(TokenKind.ARROW_L_P1) {
            self.advance();  # <-:
            start_uni = self.make_uni_token(self.previous());
            f_type = None;
            compares: list = [];
            fcompr_kid: list = [];
            if self.check_name() or self.is_keyword_token() {
                f_type = self.parse_atom();
                fcompr_kid.append(f_type);
            }
            if self.check(TokenKind.COLON) and not self.check(TokenKind.ARROW_L_P2) {
                self.advance();
                fcompr_kid.append(self.gen_token(Tok.COLON.value));
                if not self.check(TokenKind.ARROW_L_P2) {
                    cmp = self.parse_compare();
                    compares.append(cmp);
                    fcompr_kid.append(cmp);
                    while self.match_tok(TokenKind.COMMA) {
                        fcompr_kid.append(self.gen_token(Tok.COMMA.value));
                        cmp = self.parse_compare();
                        compares.append(cmp);
                        fcompr_kid.append(cmp);
                    }
                }
            }
            fcond = FilterCompr(f_type=f_type, compares=compares, kid=fcompr_kid);
            end_uni = self.gen_token(Tok.ARROW_L_P2.value);
            if self.check(TokenKind.ARROW_L_P2) {
                self.advance();
            }
            edge_op_ref = EdgeOpRef(
                filter_cond=fcond, edge_dir=EdgeDir.IN, kid=[start_uni, fcond, end_uni]
            );
        }
        # Typed edge as single tokens: ARROW_R_P1 ... ARROW_R_P2
        elif self.check(TokenKind.ARROW_R_P1) {
            self.advance();
            start_uni = self.make_uni_token(self.previous());
            f_type = None;
            compares: list = [];
            fcompr_kid: list = [];
            if self.check_name() {
                f_type = self.parse_atom();
                fcompr_kid.append(f_type);
            }
            fcond = FilterCompr(f_type=f_type, compares=compares, kid=fcompr_kid);
            end_uni = self.gen_token(Tok.ARROW_R_P2.value);
            if self.check(TokenKind.ARROW_R_P2) {
                self.advance();
            }
            edge_op_ref = EdgeOpRef(
                filter_cond=fcond,
                edge_dir=EdgeDir.OUT,
                kid=[start_uni, fcond, end_uni]
            );
        } else {
            break;
        }
        if edge_op_ref is not None {
            chain.append(edge_op_ref);
            kid.append(edge_op_ref);
        }
        # Check for filter expressions after edge operator: -->(?val==5) or -->(`?A)
        if self.check(TokenKind.LPAREN) {
            if self.peek().kind == TokenKind.NULL_OK
            or (
                self.peek().kind == TokenKind.TYPE_OP
                and self.peek(2).kind == TokenKind.NULL_OK
            ) {
                self.advance();
                filter_expr = self.parse_filter_compr_inner();
                chain.append(filter_expr);
                kid.append(filter_expr);
                self.expect(TokenKind.RPAREN);
            } else {
                self.advance();
                kid.append(self.gen_token(Tok.LPAREN.value));
                filter_expr = self.parse_expression();
                chain.append(filter_expr);
                kid.append(filter_expr);
                self.expect(TokenKind.RPAREN);
                kid.append(self.gen_token(Tok.RPAREN.value));
            }
        }
        # Check for target expression after edge operator
        elif self.check_any(
            TokenKind.NAME,
            TokenKind.KWESC_NAME,
            TokenKind.KW_SELF,
            TokenKind.KW_ROOT,
            TokenKind.KW_HERE,
            TokenKind.KW_SUPER
        ) {
            target_expr = self.parse_atomic_chain();
            chain.append(target_expr);
            kid.append(target_expr);
        }
    }
    self.expect(TokenKind.RSQUARE);
    kid.append(self.gen_token(Tok.RSQUARE.value));
    return EdgeRefTrailer(
        chain=chain, edges_only=edges_only, is_async=is_async, kid=kid
    );
}

impl Parser.parse_dict_or_set -> Expr {
    if self.check(TokenKind.RBRACE) {
        self.advance();
        return DictVal(
            kv_pairs=[],
            kid=[self.gen_token(Tok.LBRACE.value), self.gen_token(Tok.RBRACE.value)]
        );
    }
    # Check for dict spread: {**expr, ...}
    if self.check(TokenKind.STAR_POW) {
        return self.parse_dict_with_spread();
    }
    first = self.parse_expression();
    if self.match_tok(TokenKind.COLON) {
        value = self.parse_expression();
        if self.check(TokenKind.KW_FOR) {
            comprs = self.parse_comprehension_clauses();
            self.expect(TokenKind.RBRACE);
            kv = KVPair(
                key=first,
                value=value,
                kid=[first, self.gen_token(Tok.COLON.value), value]
            );
            kid: list = [self.gen_token(Tok.LBRACE.value), kv];
            kid.extend(comprs);
            kid.append(self.gen_token(Tok.RBRACE.value));
            return DictCompr(kv_pair=kv, compr=comprs, kid=kid);
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
            if self.check(TokenKind.STAR_POW) {
                self.advance();
                spread_val = self.parse_expression();
                pairs.append(
                    KVPair(
                        key=None,
                        value=spread_val,
                        kid=[self.gen_token(Tok.STAR_POW.value, "**"), spread_val]
                    )
                );
            } else {
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
        return SetCompr(out_expr=first, compr=comprs, kid=kid);
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

impl Parser.parse_dict_with_spread -> DictVal {
    # Parse dict starting with **spread
    pairs: list = [];
    while not self.check(TokenKind.RBRACE) and not self.at_end() {
        if self.check(TokenKind.STAR_POW) {
            self.advance();
            spread_val = self.parse_expression();
            pairs.append(
                KVPair(
                    key=None,
                    value=spread_val,
                    kid=[self.gen_token(Tok.STAR_POW.value, "**"), spread_val]
                )
            );
        } else {
            key = self.parse_expression();
            self.expect(TokenKind.COLON);
            val = self.parse_expression();
            pairs.append(
                KVPair(
                    key=key, value=val, kid=[key, self.gen_token(Tok.COLON.value), val]
                )
            );
        }
        if not self.match_tok(TokenKind.COMMA) {
            break;
        }
    }
    self.expect(TokenKind.RBRACE);
    kid: list = [self.gen_token(Tok.LBRACE.value)];
    for (i, p) in enumerate(pairs) {
        kid.append(p);
        if i < len(pairs) - 1 {
            kid.append(self.gen_token(Tok.COMMA.value));
        }
    }
    kid.append(self.gen_token(Tok.RBRACE.value));
    return DictVal(kv_pairs=pairs, kid=kid);
}

impl Parser.parse_comprehension_clauses -> list {
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
                is_async=is_async,
                target=target,
                collection=iter_expr,
                conditional=ifs,
                kid=kid
            )
        );
    }
    return comprs;
}

impl Parser.parse_lambda_expr -> Expr {
    self.expect(TokenKind.KW_LAMBDA);
    lambda_tok = self.gen_token(Tok.KW_LAMBDA.value);
    # Build FuncSignature kid list (lambda has no parens)
    sig_kid: list = [];
    params = self.parse_lambda_params(sig_kid);
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
    if return_type {
        sig_kid.append(self.gen_token(Tok.RETURN_HINT.value, "->"));
        sig_kid.append(return_type);
    }
    # Ensure non-empty kid list
    if len(sig_kid) == 0 {
        sig_kid.append(EmptyToken());
    }
    signature = FuncSignature(
        posonly_params=[],
        params=params,
        varargs=None,
        kwonlyargs=[],
        kwargs=None,
        return_type=return_type,
        kid=sig_kid
    );
    # Only include signature in kid list if it has params or return type
    # NOTE: params may be None due to Jac brace-scoping issue in parse_lambda_params,
    # so we check sig_kid length instead (sig_kid is passed by reference and modified in place)
    has_sig_content = (len(sig_kid) > 0 and not isinstance(sig_kid[0], EmptyToken))
    or return_type is not None;
    kid: list = [lambda_tok];
    if has_sig_content {
        kid.append(signature);
    }
    # Add colon separator between signature and body
    if not isinstance(body, list) {
        kid.append(self.gen_token(Tok.COLON.value, ":"));
        kid.append(body);
    } else {
        kid.append(self.gen_token(Tok.LBRACE.value));
        kid.extend(body);
        kid.append(self.gen_token(Tok.RBRACE.value));
    }
    return LambdaExpr(body=body, kid=kid, signature=signature);
}

impl Parser.parse_lambda_params(sig_kid: list) -> list {
    params: list = [];
    while self.check_name() or self.is_keyword_token() {
        name_tok = self.advance();
        name = self.make_name_or_special(name_tok);
        type_tag: SubTag | None = None;
        # Check for type annotation: name: type
        # But we need to distinguish from lambda body colon: lambda x, y: expr
        # Type annotation COLON is followed by a type and then COMMA, EQ, COLON (for more params), or RETURN_HINT
        # Body COLON is followed by an expression
        # Heuristic: if we see COLON, check if peek is a type-starting token (name, builtin)
        # and peek(2) is COMMA or EQ or RETURN_HINT - then it's a type annotation
        if self.check(TokenKind.COLON) {
            # Save position for potential backtrack
            next_tok = self.peek();
            # Type annotation should be: : TYPE (COMMA|EQ|COLON|RETURN_HINT|LBRACE)
            # For simple types, check if after type there's a comma or equals
            is_type_annotation = False;
            if next_tok.kind in [
                TokenKind.NAME,
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
            ] {
                # Check what follows the type
                after_type = self.peek(2);
                if after_type.kind in [
                    TokenKind.COMMA,
                    TokenKind.EQ,
                    TokenKind.COLON,  # Body colon for single-param typed lambda: lambda x: dict : body
                    TokenKind.RETURN_HINT,
                    TokenKind.LBRACE
                ] {
                    is_type_annotation = True;
                }
            }
            if is_type_annotation {
                self.advance();  # consume COLON
                lam_colon = self.gen_token(Tok.COLON.value, ":");
                te = self.parse_pipe();
                type_tag = SubTag(tag=te, kid=[lam_colon, te]);
            }
        }
        default_val: Expr | None = None;
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
        pv = ParamVar(
            name=name, unpack=None, type_tag=type_tag, value=default_val, kid=kid
        );
        params.append(pv);
        sig_kid.append(pv);
        if not self.match_tok(TokenKind.COMMA) {
            break;
        }
        sig_kid.append(self.gen_token(Tok.COMMA.value, ","));
    }
    return params;
}

# =============================================================================
# JSX PARSING Implementations
# =============================================================================
"""Parse a JSX element: <Tag>...</Tag> or <Tag /> or <>...</>"""
impl Parser.parse_jsx_element -> Expr {
    kid: list = [];
    # Check for fragment: <>...</>
    if self.check(TokenKind.JSX_FRAG_OPEN) {
        frag_open = self.advance();
        kid.append(self.make_uni_token(frag_open));
        children = self.parse_jsx_children();
        kid.extend(children);
        self.expect(TokenKind.JSX_FRAG_CLOSE);
        kid.append(self.gen_token(Tok.JSX_FRAG_CLOSE.value, "</>"));
        return JsxElement(
            name=None,
            attributes=[],
            children=children,
            is_self_closing=False,
            is_fragment=True,
            kid=kid
        );
    }
    # Regular element: <Tag>...</Tag> or <Tag />
    self.expect(TokenKind.JSX_OPEN_START);
    open_kid: list = [self.gen_token(Tok.LT.value, "<")];
    # Parse tag name (may be dotted: UI.Button, Form.Input.Text)
    name_tok = self.expect(TokenKind.JSX_NAME);
    name = self.make_uni_token(name_tok);
    name_parts: list = [name];
    name_kid: list = [name];
    while self.match_tok(TokenKind.DOT) {
        name_kid.append(self.gen_token(Tok.DOT.value, "."));
        next_name_tok = self.expect(TokenKind.JSX_NAME);
        next_name = self.make_uni_token(next_name_tok);
        name_parts.append(next_name);
        name_kid.append(next_name);
    }
    elem_name = JsxElementName(parts=name_parts, kid=name_kid);
    open_kid.append(elem_name);
    # Parse attributes
    attrs = self.parse_jsx_attributes();
    open_kid.extend(attrs);
    # Check for self-closing: />
    if self.check(TokenKind.JSX_SELF_CLOSE) {
        self.advance();
        open_kid.append(self.gen_token(Tok.JSX_SELF_CLOSE.value, "/>"));
        return JsxElement(
            name=elem_name,
            attributes=attrs,
            children=None,
            is_self_closing=True,
            is_fragment=False,
            kid=open_kid
        );
    }
    # Regular element with children
    self.expect(TokenKind.JSX_TAG_END);
    open_kid.append(self.gen_token(Tok.GT.value, ">"));
    # Create opening element wrapper
    opening = JsxElement(
        name=elem_name,
        attributes=attrs,
        children=None,
        is_self_closing=False,
        is_fragment=False,
        kid=open_kid
    );
    kid.append(opening);
    # Parse children
    children = self.parse_jsx_children();
    kid.extend(children);
    # Parse closing tag: </Tag>
    self.expect(TokenKind.JSX_CLOSE_START);
    close_kid: list = [self.gen_token(Tok.JSX_CLOSE_START.value, "</")];
    close_name_tok = self.expect(TokenKind.JSX_NAME);
    close_name_node = self.make_uni_token(close_name_tok);
    close_parts: list = [close_name_node];
    close_name_kid: list = [close_name_node];
    while self.match_tok(TokenKind.DOT) {
        close_name_kid.append(self.gen_token(Tok.DOT.value, "."));
        cn_tok = self.expect(TokenKind.JSX_NAME);
        cn = self.make_uni_token(cn_tok);
        close_parts.append(cn);
        close_name_kid.append(cn);
    }
    close_elem_name = JsxElementName(parts=close_parts, kid=close_name_kid);
    close_kid.append(close_elem_name);
    self.expect(TokenKind.JSX_TAG_END);
    close_kid.append(self.gen_token(Tok.GT.value, ">"));
    closing = JsxElement(
        name=close_elem_name,
        attributes=[],
        children=None,
        is_self_closing=False,
        is_fragment=False,
        kid=close_kid
    );
    kid.append(closing);
    return JsxElement(
        name=elem_name,
        attributes=attrs,
        children=children,
        is_self_closing=False,
        is_fragment=False,
        kid=kid
    );
}

"""Parse JSX opening element and return (name, attrs, is_self_closing)."""
impl Parser.parse_jsx_opening_element -> tuple {
    self.expect(TokenKind.JSX_OPEN_START);
    name_tok = self.expect(TokenKind.JSX_NAME);
    name = self.make_name(name_tok);
    attrs = self.parse_jsx_attributes();
    if self.check(TokenKind.JSX_SELF_CLOSE) {
        self.advance();
        return (name, attrs, True);
    }
    self.expect(TokenKind.JSX_TAG_END);
    return (name, attrs, False);
}

"""Parse JSX attributes: attr="value" or attr={expr}"""
impl Parser.parse_jsx_attributes -> list {
    attrs: list = [];
    while True {
        if self.check(TokenKind.JSX_NAME) {
            attr_name_tok = self.advance();
            attr_name = self.make_uni_token(attr_name_tok);
            attr_value: Expr | None = None;
            attr_kid: list = [attr_name];
            if self.match_tok(TokenKind.EQ) {
                attr_kid.append(self.gen_token(Tok.EQ.value, "="));
                # Check for string value or expression
                if self.check(TokenKind.STRING) {
                    str_tok = self.advance();
                    attr_value = self.make_string(str_tok);
                    attr_kid.append(attr_value);
                } elif self.check(TokenKind.LBRACE) {
                    self.advance();  # consume {
                    lbrace = self.gen_token(Tok.LBRACE.value, "{");
                    attr_value = self.parse_expression();
                    self.expect(TokenKind.RBRACE);
                    rbrace = self.gen_token(Tok.RBRACE.value, "}");
                    attr_kid.append(lbrace);
                    attr_kid.append(attr_value);
                    attr_kid.append(rbrace);
                }
            }
            attrs.append(
                JsxNormalAttribute(name=attr_name, value=attr_value, kid=attr_kid)
            );
        } elif self.check(TokenKind.LBRACE) {
            # Spread attribute: {...expr}
            self.advance();  # consume {
            spread_kid: list = [self.gen_token(Tok.LBRACE.value, "{")];
            if self.check(TokenKind.ELLIPSIS) {
                ellipsis_tok = self.advance();
                spread_kid.append(self.make_ellipsis(ellipsis_tok));
            }
            spread_expr = self.parse_expression();
            self.expect(TokenKind.RBRACE);
            spread_kid.append(spread_expr);
            spread_kid.append(self.gen_token(Tok.RBRACE.value, "}"));
            attrs.append(JsxSpreadAttribute(expr=spread_expr, kid=spread_kid));
        } else {
            break;
        }
    }
    return attrs;
}

"""Parse JSX children: text, expressions, or nested elements."""
impl Parser.parse_jsx_children -> list {
    children: list = [];
    while not self.at_end() {
        # Check for closing tag or fragment close
        if self.check(TokenKind.JSX_CLOSE_START)
        or self.check(TokenKind.JSX_FRAG_CLOSE) {
            break;
        }
        child = self.parse_jsx_child();
        if child {
            children.append(child);
        } else {
            # No progress possible — break to prevent infinite loop
            break;
        }
    }
    return children;
}

"""Parse a single JSX child: text, expression {expr}, or nested element."""
impl Parser.parse_jsx_child -> Expr {
    # Text content
    if self.check(TokenKind.JSX_TEXT) {
        text_tok = self.advance();
        text_node = self.make_uni_token(text_tok);
        return JsxText(value=text_tok.value, kid=[text_node]);
    }
    # Expression: {expr}
    if self.check(TokenKind.LBRACE) {
        lbrace = self.advance();  # consume {
        expr = self.parse_expression();
        self.expect(TokenKind.RBRACE);
        kid: list = [
            self.make_uni_token(lbrace),
            expr,
            self.gen_token(Tok.RBRACE.value, "}")
        ];
        return JsxExpression(expr=expr, kid=kid);
    }
    # Nested JSX element
    if self.check(TokenKind.JSX_OPEN_START) or self.check(TokenKind.JSX_FRAG_OPEN) {
        return self.parse_jsx_element();
    }
    # Nothing more to parse
    return None;
}

# =============================================================================
# STATEMENT PARSING Implementations
# =============================================================================
impl Parser.parse_element_stmt{
    while self.match_tok(TokenKind.SEMI) {
        skip;
    }
    if self.at_end() {
        return None;
    }
    # Handle client/server/native context blocks: cl { ... } or cl stmt
    if self.check(TokenKind.KW_CLIENT) {
        if self.peek().kind == TokenKind.LBRACE {
            return self.parse_client_block();
        } else {
            # Single statement: cl def ..., cl import ..., etc.
            self.advance();  # consume cl
            cl_tok = self.gen_token(Tok.KW_CLIENT.value, "cl");
            stmt = self.parse_element_stmt();
            if stmt is not None {
                stmt.add_kids_left([cl_tok]);
            }
            return stmt;
        }
    }
    if self.check(TokenKind.KW_SERVER) {
        if self.peek().kind == TokenKind.LBRACE {
            return self.parse_server_block();
        } else {
            self.advance();  # consume sv
            sv_tok = self.gen_token(Tok.KW_SERVER.value, "sv");
            stmt = self.parse_element_stmt();
            if stmt is not None {
                stmt.add_kids_left([sv_tok]);
            }
            return stmt;
        }
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
    )
    or (
        self.check(TokenKind.KW_ABSTRACT)
        and self.peek().kind in [
            TokenKind.KW_OBJECT,
            TokenKind.KW_NODE,
            TokenKind.KW_EDGE,
            TokenKind.KW_WALKER,
            TokenKind.KW_CLASS
        ]
    ) {
        return self.parse_archetype();
    }
    if self.check(TokenKind.KW_ENUM) {
        return self.parse_enum();
    }
    if self.check(TokenKind.STRING) and self.peek().kind == TokenKind.KW_TEST {
        doc_tok = self.advance();
        elem_doc = self.make_string(doc_tok);
        test = self.parse_test();
        test.doc = elem_doc;
        test.add_kids_left([elem_doc]);
        return test;
    }
    if self.check(TokenKind.KW_TEST) {
        return self.parse_test();
    }
    if self.check(TokenKind.STRING)
    and self.peek().kind in [
        TokenKind.KW_DEF,
        TokenKind.KW_CAN,
        TokenKind.KW_OVERRIDE,
        TokenKind.KW_STATIC,
        TokenKind.KW_ASYNC,
        TokenKind.KW_ABSTRACT,
        TokenKind.DECOR_OP
    ] {
        doc_tok = self.advance();
        elem_doc = self.make_string(doc_tok);
        ability = self.parse_ability();
        ability.doc = elem_doc;
        ability.add_kids_left([elem_doc]);
        return ability;
    }
    if self.check(TokenKind.STRING)
    and self.peek().kind in [
        TokenKind.KW_OBJECT,
        TokenKind.KW_NODE,
        TokenKind.KW_EDGE,
        TokenKind.KW_WALKER,
        TokenKind.KW_CLASS
    ] {
        doc_tok = self.advance();
        elem_doc = self.make_string(doc_tok);
        arch = self.parse_archetype();
        arch.doc = elem_doc;
        arch.add_kids_left([elem_doc]);
        return arch;
    }
    if self.check(TokenKind.STRING) and self.peek().kind == TokenKind.KW_ENUM {
        doc_tok = self.advance();
        elem_doc = self.make_string(doc_tok);
        en = self.parse_enum();
        en.doc = elem_doc;
        en.add_kids_left([elem_doc]);
        return en;
    }
    if self.check_any(TokenKind.KW_DEF, TokenKind.KW_CAN) {
        return self.parse_ability();
    }
    # Handle docstring before glob: "docstring" glob ...
    if self.check(TokenKind.STRING) and self.peek().kind == TokenKind.KW_GLOBAL {
        doc_tok = self.advance();
        elem_doc = self.make_string(doc_tok);
        gv = self.parse_global_var();
        gv.doc = elem_doc;
        gv.add_kids_left([elem_doc]);
        return gv;
    }
    # Handle global variables: glob VAR: type = value;
    if self.check(TokenKind.KW_GLOBAL) {
        return self.parse_global_var();
    }
    # Handle docstring before impl
    if self.check(TokenKind.STRING) and self.peek().kind == TokenKind.KW_IMPL {
        doc_tok = self.advance();
        elem_doc = self.make_string(doc_tok);
        impl_def = self.parse_impl_def();
        impl_def.doc = elem_doc;
        impl_def.add_kids_left([elem_doc]);
        return impl_def;
    }
    # Handle impl blocks at top level: impl Name.method { ... }
    if self.check(TokenKind.KW_IMPL) {
        return self.parse_impl_def();
    }
    # Handle semantic definitions: sem name = "description";
    if self.check(TokenKind.KW_SEM) {
        return self.parse_sem_def();
    }
    # Handle inline Python: ::py:: ... ::py::
    if self.check(TokenKind.PYNLINE) {
        py_tok = self.advance();
        py_code = self.make_uni_token(py_tok);
        return PyInlineCode(code=py_code, kid=[py_code]);
    }
    # Handle docstring before 'with entry { ... }' module code
    if self.check(TokenKind.STRING) and self.peek().kind == TokenKind.KW_WITH {
        doc_tok = self.advance();
        elem_doc = self.make_string(doc_tok);
        mc = self.parse_module_code();
        mc.doc = elem_doc;
        mc.add_kids_left([elem_doc]);
        return mc;
    }
    # Handle 'with entry { ... }' module code
    if self.check(TokenKind.KW_WITH) {
        return self.parse_module_code();
    }
    # Handle decorators for archetypes and abilities
    if self.check(TokenKind.DECOR_OP) {
        # Need to look ahead to see what the decorated item is
        # Consume decorators temporarily and peek at what follows
        save_pos = self.pos;
        while self.check(TokenKind.DECOR_OP) {
            self.advance();
            self.parse_atomic_chain();  # consume decorator expression
        }
        # Skip async/abstract if present
        while self.check_any(TokenKind.KW_ASYNC, TokenKind.KW_ABSTRACT) {
            self.advance();
        }
        # Now check what the decorated item is
        is_ability = self.check_any(TokenKind.KW_DEF, TokenKind.KW_CAN);
        is_enum = self.check(TokenKind.KW_ENUM);
        self.pos = save_pos;  # Restore position
        if is_ability {
            return self.parse_ability();
        } elif is_enum {
            return self.parse_enum();
        } else {
            return self.parse_archetype();
        }
    }
    # Handle abstract/async prefixes
    if self.check_any(TokenKind.KW_ABSTRACT, TokenKind.KW_ASYNC) {
        # Look ahead to see if it's an ability (def/can) or archetype (class/obj/etc)
        save_pos = self.pos;
        while self.check_any(TokenKind.KW_ABSTRACT, TokenKind.KW_ASYNC) {
            self.advance();
        }
        is_ability = self.check_any(TokenKind.KW_DEF, TokenKind.KW_CAN);
        self.pos = save_pos;
        if is_ability {
            return self.parse_ability();
        }
        return self.parse_archetype();
    }
    expr = self.parse_expression();
    self.match_tok(TokenKind.SEMI);
    return expr;
}

"""Parse client block: cl { stmts } or cl stmt"""
impl Parser.parse_client_block -> ClientBlock {
    self.expect(TokenKind.KW_CLIENT);
    cl_tok = self.gen_token(Tok.KW_CLIENT.value, "cl");
    kid: list = [cl_tok];
    body: list = [];
    if self.match_tok(TokenKind.LBRACE) {
        kid.append(self.gen_token(Tok.LBRACE.value, "{"));
        while not self.check(TokenKind.RBRACE) and not self.at_end() {
            stmt = self.parse_element_stmt();
            if stmt is not None {
                body.append(stmt);
                kid.append(stmt);
                # Mark as client context
                if stmt?.code_context {
                    stmt.code_context = CodeContext.CLIENT;
                }
            }
        }
        self.expect(TokenKind.RBRACE);
        kid.append(self.gen_token(Tok.RBRACE.value, "}"));
    } else {
        # Single statement after cl
        stmt = self.parse_element_stmt();
        if stmt is not None {
            body.append(stmt);
            kid.append(stmt);
        }
    }
    return ClientBlock(body=body, kid=kid);
}

"""Parse server block: sv { stmts } or sv stmt"""
impl Parser.parse_server_block -> ServerBlock {
    self.expect(TokenKind.KW_SERVER);
    sv_tok = self.gen_token(Tok.KW_SERVER.value, "sv");
    kid: list = [sv_tok];
    body: list = [];
    if self.match_tok(TokenKind.LBRACE) {
        kid.append(self.gen_token(Tok.LBRACE.value, "{"));
        while not self.check(TokenKind.RBRACE) and not self.at_end() {
            stmt = self.parse_element_stmt();
            if stmt is not None {
                body.append(stmt);
                kid.append(stmt);
                if stmt?.code_context {
                    stmt.code_context = CodeContext.SERVER;
                }
            }
        }
        self.expect(TokenKind.RBRACE);
        kid.append(self.gen_token(Tok.RBRACE.value, "}"));
    } else {
        # Single statement after sv - add sv token to element, don't wrap in ServerBlock
        stmt = self.parse_element_stmt();
        if stmt is not None {
            stmt.add_kids_left([sv_tok]);
            return stmt;
        }
    }
    return ServerBlock(body=body, kid=kid);
}

impl Parser.parse_module_code -> ModuleCode {
    # Parse 'with entry { ... }' or 'with entry:__main__ { ... }' or 'with exit { ... }'
    # Grammar: free_code: KW_WITH KW_ENTRY (COLON NAME)? code_block
    self.expect(TokenKind.KW_WITH);
    name = None;
    target_name = None;  # For :__main__ style target
    if self.check_any(TokenKind.KW_ENTRY, TokenKind.KW_EXIT) {
        name_tok = self.advance();
        name = self.make_uni_token(name_tok);
    }
    # Check for optional :NAME after entry/exit (e.g., with entry:__main__)
    if self.match_tok(TokenKind.COLON) {
        target_tok = self.expect_name();
        target_name = self.make_name(target_tok);
    }
    self.expect(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    self.expect(TokenKind.RBRACE);
    kid: list = [self.gen_token(Tok.KW_WITH.value)];
    if name {
        kid.append(name);
    }
    if target_name {
        kid.append(self.gen_token(Tok.COLON.value));
        kid.append(target_name);
    }
    kid.append(self.gen_token(Tok.LBRACE.value));
    kid.extend(body);
    kid.append(self.gen_token(Tok.RBRACE.value));
    # Use target_name as the name if provided
    return ModuleCode(name=target_name or name, body=body, kid=kid, doc=None);
}

impl Parser.parse_code_block_stmts -> list {
    stmts: list = [];
    while not self.check(TokenKind.RBRACE) and not self.at_end() {
        stmt = self.parse_statement();
        if stmt is not None {
            stmts.append(stmt);
            # Add Semi token if present (for statements like assignment SEMI)
            if self.match_tok(TokenKind.SEMI) {
                prev = self.previous();
                stmts.append(
                    Semi(
                        orig_src=self.get_source(),
                        name=Tok.SEMI.value,
                        value=";",
                        line=prev.loc.line,
                        end_line=prev.loc.end_line,
                        col_start=prev.loc.col_start,
                        col_end=prev.loc.col_end,
                        pos_start=prev.loc.pos_start,
                        pos_end=prev.loc.pos_end
                    )
                );
            }
        }
    }
    return stmts;
}

impl Parser.parse_statement{
    if self.match_tok(TokenKind.SEMI) {
        return self.make_semi();
    }
    if self.check(TokenKind.RBRACE) or self.at_end() {
        return None;
    }
    # Allow imports inside code blocks
    if self.check_any(TokenKind.KW_IMPORT, TokenKind.KW_INCLUDE) {
        return self.parse_import_stmt();
    }
    if self.check(TokenKind.KW_IF) {
        return self.parse_if_stmt();
    }
    if self.check(TokenKind.KW_WHILE) {
        return self.parse_while_stmt();
    }
    # Handle async for loops
    if self.check(TokenKind.KW_ASYNC) and self.peek().kind == TokenKind.KW_FOR {
        return self.parse_for_stmt();
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
    # Handle switch statements
    if self.check(TokenKind.KW_SWITCH) {
        return self.parse_switch_stmt();
    }
    if self.check(TokenKind.KW_RETURN) {
        return self.parse_return_stmt();
    }
    if self.check(TokenKind.KW_YIELD) {
        yield_expr = self.parse_yield_stmt();
        es_kid: list = [yield_expr];
        if self.match_tok(TokenKind.SEMI) {
            if yield_expr.expr is None {
                # Bare yield: Semi goes inside YieldExpr
                yield_expr.add_kids_right([self.make_semi()]);
            } else {
                # Yield with expression: Semi goes at ExprStmt level
                es_kid.append(self.make_semi());
            }
        }
        return ExprStmt(expr=yield_expr, in_fstring=False, kid=es_kid);
    }
    if self.check(TokenKind.KW_BREAK) {
        self.advance();
        kid: list = [self.gen_token(Tok.KW_BREAK.value)];
        if self.match_tok(TokenKind.SEMI) {
            kid.append(self.make_semi());
        }
        return CtrlStmt(ctrl=self.gen_token(Tok.KW_BREAK.value), kid=kid);
    }
    if self.check(TokenKind.KW_CONTINUE) {
        self.advance();
        kid: list = [self.gen_token(Tok.KW_CONTINUE.value)];
        if self.match_tok(TokenKind.SEMI) {
            kid.append(self.make_semi());
        }
        return CtrlStmt(ctrl=self.gen_token(Tok.KW_CONTINUE.value), kid=kid);
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
    # Handle global statement (inside functions): global a, b;
    if self.check(TokenKind.KW_GLOBAL_REF) {
        return self.parse_global_stmt();
    }
    # Handle nonlocal statement: nonlocal a, b;
    if self.check(TokenKind.KW_NONLOCAL) {
        return self.parse_nonlocal_stmt();
    }
    # Handle visit statement
    if self.check(TokenKind.KW_VISIT) {
        return self.parse_visit_stmt();
    }
    # Handle disengage statement
    if self.check(TokenKind.KW_DISENGAGE) {
        self.advance();
        kid: list = [self.gen_token(Tok.KW_DISENGAGE.value)];
        if self.match_tok(TokenKind.SEMI) {
            kid.append(self.make_semi());
        }
        return DisengageStmt(kid=kid);
    }
    # Handle report statement
    if self.check(TokenKind.KW_REPORT) {
        return self.parse_report_stmt();
    }
    # Handle nested function/ability definitions
    if self.check_any(TokenKind.KW_DEF, TokenKind.KW_CAN, TokenKind.KW_ASYNC) {
        return self.parse_ability();
    }
    # Handle decorators for nested functions
    if self.check(TokenKind.DECOR_OP) {
        return self.parse_ability();
    }
    # Handle nested class/archetype definitions
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
    # Handle has statements (in impl bodies and archetype bodies)
    if self.check(TokenKind.KW_HAS)
    or (self.check(TokenKind.KW_STATIC) and self.peek().kind == TokenKind.KW_HAS) {
        return self.parse_has_stmt();
    }
    # Handle inline Python: ::py:: ... ::py::
    if self.check(TokenKind.PYNLINE) {
        py_tok = self.advance();
        py_code = self.make_uni_token(py_tok);
        return PyInlineCode(code=py_code, kid=[py_code]);
    }
    expr = self.parse_expression();
    if self.check(TokenKind.EQ)
    or self.check(TokenKind.COLON)
    or self.check_any(
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
        return self.parse_assignment_with_target(expr);
    }
    # Wrap bare expression in ExprStmt with Semi
    semi_tok: Semi | None = None;
    if self.match_tok(TokenKind.SEMI) {
        prev = self.previous();
        semi_tok = Semi(
            orig_src=self.get_source(),
            name=Tok.SEMI.value,
            value=";",
            line=prev.loc.line,
            end_line=prev.loc.end_line,
            col_start=prev.loc.col_start,
            col_end=prev.loc.col_end,
            pos_start=prev.loc.pos_start,
            pos_end=prev.loc.pos_end
        );
    }
    expr_kid: list = [expr];
    if semi_tok is not None {
        expr_kid.append(semi_tok);
    }
    return ExprStmt(expr=expr, in_fstring=False, kid=expr_kid);
}

impl Parser.parse_if_stmt -> IfStmt {
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

impl Parser.parse_elif_stmt -> ElseIf {
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

impl Parser.parse_else_stmt -> ElseStmt {
    self.expect(TokenKind.KW_ELSE);
    self.expect(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    self.expect(TokenKind.RBRACE);
    kid: list = [self.gen_token(Tok.KW_ELSE.value), self.gen_token(Tok.LBRACE.value)];
    kid.extend(body);
    kid.append(self.gen_token(Tok.RBRACE.value));
    return ElseStmt(body=body, kid=kid);
}

impl Parser.parse_while_stmt -> WhileStmt {
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

impl Parser.parse_for_stmt{
    is_async = False;
    if self.match_tok(TokenKind.KW_ASYNC) {
        is_async = True;
    }
    self.expect(TokenKind.KW_FOR);
    # Parse target (could be assignment for iter_for_stmt or atomic_chain for in_for_stmt)
    target = self.parse_atomic_chain();
    # Check if this is a for...to...by loop (IterForStmt)
    if self.check(TokenKind.EQ) {
        # This is: for i = 0 to 10 by i += 1 { ... }
        self.advance();  # consume '='
        start_val = self.parse_expression();
        self.expect(TokenKind.KW_TO);
        end_val = self.parse_pipe();
        self.expect(TokenKind.KW_BY);
        # Parse the step assignment
        step_target = self.parse_atomic_chain();
        step_assign: Assignment;
        if self.check_any(
            TokenKind.ADD_EQ,
            TokenKind.SUB_EQ,
            TokenKind.MUL_EQ,
            TokenKind.DIV_EQ,
            TokenKind.FLOOR_DIV_EQ,
            TokenKind.MOD_EQ,
            TokenKind.STAR_POW_EQ
        ) {
            step_assign = self.parse_assignment_with_target(step_target);
        } else {
            self.error("Expected augmented assignment in for...to...by step");
            step_assign = Assignment(
                target=[step_target],
                value=None,
                type_tag=None,
                kid=[step_target],
                mutable=True,
                aug_op=None,
                is_enum_stmt=False
            );
        }
        self.expect(TokenKind.LBRACE);
        body = self.parse_code_block_stmts();
        self.expect(TokenKind.RBRACE);
        else_body = None;
        if self.check(TokenKind.KW_ELSE) {
            else_body = self.parse_else_stmt();
        }
        # Create the initial assignment
        init_assign = Assignment(
            target=[target],
            value=start_val,
            type_tag=None,
            kid=[target, self.gen_token(Tok.EQ.value), start_val],
            mutable=True,
            aug_op=None,
            is_enum_stmt=False
        );
        kid: list = [
            self.gen_token(Tok.KW_FOR.value),
            init_assign,
            self.gen_token(Tok.KW_TO.value),
            end_val,
            self.gen_token(Tok.KW_BY.value),
            step_assign,
            self.gen_token(Tok.LBRACE.value)
        ];
        kid.extend(body);
        kid.append(self.gen_token(Tok.RBRACE.value));
        if else_body {
            kid.append(else_body);
        }
        return IterForStmt(
            iter=init_assign,
            is_async=is_async,
            condition=end_val,
            count_by=step_assign,
            body=body,
            else_body=else_body,
            kid=kid
        );
    }
    # Standard for...in loop
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

impl Parser.parse_try_stmt -> TryStmt {
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
        fin_kid: list = [
            self.gen_token(Tok.KW_FINALLY.value),
            self.gen_token(Tok.LBRACE.value)
        ];
        fin_kid.extend(finally_stmts);
        fin_kid.append(self.gen_token(Tok.RBRACE.value));
        finally_body = FinallyStmt(body=finally_stmts, kid=fin_kid);
    }
    kid: list = [self.gen_token(Tok.KW_TRY.value), self.gen_token(Tok.LBRACE.value)];
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

impl Parser.parse_except_handler -> Except {
    self.expect(TokenKind.KW_EXCEPT);
    exc_type = self.parse_expression();
    name = None;
    if self.match_tok(TokenKind.KW_AS) {
        name_tok = self.expect_name();
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
    return Except(ex_type=exc_type, name=name, body=body, kid=kid);
}

impl Parser.parse_with_stmt -> WithStmt {
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
            expr=expr,
            alias=alias,
            kid=[expr] if not alias else [expr, self.gen_token(Tok.KW_AS.value), alias]
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
                expr=expr,
                alias=alias,
                kid=[expr]
                if not alias
                else [expr, self.gen_token(Tok.KW_AS.value), alias]
            )
        );
    }
    self.expect(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    self.expect(TokenKind.RBRACE);
    kid: list = [self.gen_token(Tok.KW_WITH.value)];
    for (i, e) in enumerate(exprs) {
        kid.append(e);
        if i < len(exprs) - 1 {
            kid.append(self.gen_token(Tok.COMMA.value, ","));
        }
    }
    kid.append(self.gen_token(Tok.LBRACE.value));
    kid.extend(body);
    kid.append(self.gen_token(Tok.RBRACE.value));
    return WithStmt(is_async=is_async, exprs=exprs, body=body, kid=kid);
}

impl Parser.parse_match_stmt -> MatchStmt {
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
    return MatchStmt(target=expr, cases=cases, kid=kid);
}

impl Parser.parse_match_case -> MatchCase {
    self.expect(TokenKind.KW_CASE);
    pattern = self.parse_pattern();
    guard = None;
    if self.match_tok(TokenKind.KW_IF) {
        guard = self.parse_expression();
    }
    self.expect(TokenKind.COLON);
    body: list = [];
    while not self.check_any(TokenKind.KW_CASE, TokenKind.RBRACE) and not self.at_end() {
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

impl Parser.parse_pattern{
    # pattern_seq: or_pattern | as_pattern
    # or_pattern: (pattern BW_OR)* pattern
    # as_pattern: or_pattern KW_AS NAME
    pattern = self.parse_or_pattern();
    # Check for 'as' binding
    if self.match_tok(TokenKind.KW_AS) {
        name_tok = self.expect_name();
        name = self.make_name(name_tok);
        kid: list = [pattern, self.gen_token(Tok.KW_AS.value), name];
        return MatchAs(name=name, pattern=pattern, kid=kid);
    }
    return pattern;
}

impl Parser.parse_or_pattern{
    # or_pattern: (pattern BW_OR)* pattern
    patterns: list = [self.parse_single_pattern()];
    while self.match_tok(TokenKind.BW_OR) {
        patterns.append(self.parse_single_pattern());
    }
    if len(patterns) == 1 {
        return patterns[0];
    }
    kid: list = [patterns[0]];
    for i in range(1, len(patterns)) {
        kid.append(self.gen_token(Tok.BW_OR.value));
        kid.append(patterns[i]);
    }
    return MatchOr(patterns=patterns, kid=kid);
}

impl Parser.parse_single_pattern{
    # pattern: literal_pattern | singleton_pattern | capture_pattern | sequence_pattern | mapping_pattern | attr_pattern | class_pattern

    # Check for sequence pattern: [...]
    if self.check(TokenKind.LSQUARE) {
        return self.parse_sequence_pattern();
    }
    # Check for sequence pattern: (...) -- tuple-like
    if self.check(TokenKind.LPAREN) {
        return self.parse_tuple_sequence_pattern();
    }
    # Check for mapping pattern: {...}
    if self.check(TokenKind.LBRACE) {
        return self.parse_mapping_pattern();
    }
    # Check for singleton patterns: True, False, None
    if self.check(TokenKind.BOOL) {
        tok = self.advance();
        val = self.make_bool(tok);
        return MatchSingleton(value=val, kid=[val]);
    }
    if self.check(TokenKind.NULL) {
        tok = self.advance();
        val = self.make_null(tok);
        return MatchSingleton(value=val, kid=[val]);
    }
    # Check for literal patterns: INT, FLOAT, STRING
    if self.check(TokenKind.INT) {
        tok = self.advance();
        val = self.make_int(tok);
        return MatchValue(value=val, kid=[val]);
    }
    if self.check(TokenKind.FLOAT) {
        tok = self.advance();
        val = self.make_float(tok);
        return MatchValue(value=val, kid=[val]);
    }
    if self.check(TokenKind.STRING) {
        tok = self.advance();
        str_val = self.make_string(tok);
        val = MultiString(strings=[str_val], kid=[str_val]);
        return MatchValue(value=val, kid=[val]);
    }
    if self.check_any(
        TokenKind.F_DQ_START,
        TokenKind.F_SQ_START,
        TokenKind.F_TDQ_START,
        TokenKind.F_TSQ_START
    ) {
        val = self.parse_fstring();
        return MatchValue(value=val, kid=[val]);
    }
    # Check for unary minus (negative literal)
    if self.check(TokenKind.MINUS) {
        minus_tok = self.advance();
        if self.check(TokenKind.INT) {
            tok = self.advance();
            # Create a unary expression for negative int
            num = self.make_int(tok);
            val = UnaryExpr(
                operand=num,
                op=self.make_uni_token(minus_tok),
                kid=[self.make_uni_token(minus_tok), num]
            );
            return MatchValue(value=val, kid=[val]);
        }
        if self.check(TokenKind.FLOAT) {
            tok = self.advance();
            # Create a unary expression for negative float
            num = self.make_float(tok);
            val = UnaryExpr(
                operand=num,
                op=self.make_uni_token(minus_tok),
                kid=[self.make_uni_token(minus_tok), num]
            );
            return MatchValue(value=val, kid=[val]);
        }
    }
    # Check for NAME (capture_pattern, class_pattern, or attr_pattern)
    if self.check_name() {
        tok = self.advance();
        name = self.make_name(tok);
        # Check for wildcard _
        if tok.value == "_" {
            return MatchWild(kid=[name]);
        }
        # Check for dotted name (attr_pattern) or class_pattern
        if self.check(TokenKind.DOT) {
            # Could be attr_pattern or class_pattern with dotted name
            names: list = [name];
            while self.match_tok(TokenKind.DOT) {
                next_tok = self.expect_name();
                names.append(self.make_name(next_tok));
            }
            # Check if it's a class pattern (followed by '(')
            if self.check(TokenKind.LPAREN) {
                return self.parse_class_pattern_args(names);
            }
            # It's an attr_pattern (value pattern like Enum.Member)
            # Build nested AtomTrailers for the dotted name
            trailer = names[0];
            for i in range(1, len(names)) {
                trailer = AtomTrailer(
                    target=trailer,
                    right=names[i],
                    is_attr=True,
                    is_null_ok=False,
                    kid=[trailer, self.gen_token(Tok.DOT.value), names[i]]
                );
            }
            return MatchValue(value=trailer, kid=[trailer]);
        }
        # Check for class pattern with simple name (followed by '(')
        if self.check(TokenKind.LPAREN) {
            return self.parse_class_pattern_args([name]);
        }
        # It's a simple capture pattern (capture_pattern: NAME -> MatchAs)
        return MatchAs(name=name, pattern=None, kid=[name]);
    }
    # Handle builtin types (tuple, type, list, etc.) used as class patterns
    if self.is_keyword_token()
    or self.check_any(
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
        name = self.make_special_name(tok);
        if self.check(TokenKind.LPAREN) {
            return self.parse_class_pattern_args([name]);
        }
        return MatchValue(value=name, kid=[name]);
    }
    # Fallback: try to parse as expression (shouldn't usually reach here)
    expr = self.parse_expression();
    return MatchValue(value=expr, kid=[expr]);
}

impl Parser.parse_sequence_pattern{
    # sequence_pattern: LSQUARE list_inner_pattern (COMMA list_inner_pattern)* RSQUARE
    self.expect(TokenKind.LSQUARE);
    kid: list = [self.gen_token(Tok.LSQUARE.value)];
    values: list = [];
    while not self.check(TokenKind.RSQUARE) and not self.at_end() {
        # list_inner_pattern: pattern_seq | STAR_MUL NAME
        if self.check(TokenKind.STAR_MUL) {
            star_tok = self.advance();
            name_tok = self.expect_name();
            name = self.make_name(name_tok);
            star_pattern = MatchStar(
                name=name, is_list=True, kid=[self.make_uni_token(star_tok), name]
            );
            values.append(star_pattern);
            kid.append(star_pattern);
        } else {
            pat = self.parse_pattern();
            values.append(pat);
            kid.append(pat);
        }
        if not self.check(TokenKind.RSQUARE) {
            self.expect(TokenKind.COMMA);
            kid.append(self.gen_token(Tok.COMMA.value));
        }
    }
    self.expect(TokenKind.RSQUARE);
    kid.append(self.gen_token(Tok.RSQUARE.value));
    return MatchSequence(values=values, kid=kid);
}

impl Parser.parse_tuple_sequence_pattern{
    # sequence_pattern: LPAREN list_inner_pattern (COMMA list_inner_pattern)* RPAREN
    self.expect(TokenKind.LPAREN);
    kid: list = [self.gen_token(Tok.LPAREN.value)];
    values: list = [];
    while not self.check(TokenKind.RPAREN) and not self.at_end() {
        if self.check(TokenKind.STAR_MUL) {
            star_tok = self.advance();
            name_tok = self.expect_name();
            name = self.make_name(name_tok);
            star_pattern = MatchStar(
                name=name, is_list=True, kid=[self.make_uni_token(star_tok), name]
            );
            values.append(star_pattern);
            kid.append(star_pattern);
        } else {
            pat = self.parse_pattern();
            values.append(pat);
            kid.append(pat);
        }
        if not self.check(TokenKind.RPAREN) {
            self.expect(TokenKind.COMMA);
            kid.append(self.gen_token(Tok.COMMA.value));
        }
    }
    self.expect(TokenKind.RPAREN);
    kid.append(self.gen_token(Tok.RPAREN.value));
    return MatchSequence(values=values, kid=kid);
}

impl Parser.parse_mapping_pattern{
    # mapping_pattern: LBRACE (dict_inner_pattern (COMMA dict_inner_pattern)*)? RBRACE
    # dict_inner_pattern: literal_pattern COLON pattern_seq | STAR_POW NAME
    self.expect(TokenKind.LBRACE);
    kid: list = [self.gen_token(Tok.LBRACE.value)];
    values: list = [];
    while not self.check(TokenKind.RBRACE) and not self.at_end() {
        # Check for **rest
        if self.check(TokenKind.STAR_POW) {
            star_tok = self.advance();
            name_tok = self.expect_name();
            name = self.make_name(name_tok);
            star_pattern = MatchStar(
                name=name, is_list=False, kid=[self.make_uni_token(star_tok), name]
            );
            values.append(star_pattern);
            kid.append(star_pattern);
        } else {
            # literal_pattern COLON pattern_seq
            # literal_pattern is INT, FLOAT, or STRING
            key = self.parse_literal_for_mapping();
            self.expect(TokenKind.COLON);
            val = self.parse_pattern();
            kv = MatchKVPair(
                key=key, value=val, kid=[key, self.gen_token(Tok.COLON.value), val]
            );
            values.append(kv);
            kid.append(kv);
        }
        if not self.check(TokenKind.RBRACE) {
            self.expect(TokenKind.COMMA);
            kid.append(self.gen_token(Tok.COMMA.value));
        }
    }
    self.expect(TokenKind.RBRACE);
    kid.append(self.gen_token(Tok.RBRACE.value));
    return MatchMapping(values=values, kid=kid);
}

impl Parser.parse_literal_for_mapping{
    # Parse literal for mapping pattern key: INT, FLOAT, or STRING
    # literal_pattern wraps the literal in MatchValue (and strings in MultiString)
    if self.check(TokenKind.INT) {
        tok = self.advance();
        val = self.make_int(tok);
        return MatchValue(value=val, kid=[val]);
    }
    if self.check(TokenKind.FLOAT) {
        tok = self.advance();
        val = self.make_float(tok);
        return MatchValue(value=val, kid=[val]);
    }
    if self.check(TokenKind.STRING) {
        tok = self.advance();
        str_val = self.make_string(tok);
        ms = MultiString(strings=[str_val], kid=[str_val]);
        return MatchValue(value=ms, kid=[ms]);
    }
    if self.check_any(
        TokenKind.F_DQ_START,
        TokenKind.F_SQ_START,
        TokenKind.F_TDQ_START,
        TokenKind.F_TSQ_START
    ) {
        fstr = self.parse_fstring();
        ms = MultiString(strings=[fstr], kid=[fstr]);
        return MatchValue(value=ms, kid=[ms]);
    }
    if self.check(TokenKind.MINUS) {
        minus_tok = self.advance();
        if self.check(TokenKind.INT) {
            tok = self.advance();
            num = self.make_int(tok);
            val = UnaryExpr(
                operand=num,
                op=self.make_uni_token(minus_tok),
                kid=[self.make_uni_token(minus_tok), num]
            );
            return MatchValue(value=val, kid=[val]);
        }
        if self.check(TokenKind.FLOAT) {
            tok = self.advance();
            num = self.make_float(tok);
            val = UnaryExpr(
                operand=num,
                op=self.make_uni_token(minus_tok),
                kid=[self.make_uni_token(minus_tok), num]
            );
            return MatchValue(value=val, kid=[val]);
        }
    }
    # Error fallback
    self.error("Expected literal (INT, FLOAT, or STRING) as mapping pattern key");
    return self.make_name(self.advance());
}

impl Parser.parse_class_pattern_args(names: list) {
    # class_pattern: NAME (DOT NAME)* LPAREN kw_pattern_list? RPAREN
    #              | NAME (DOT NAME)* LPAREN pattern_list (COMMA kw_pattern_list)? RPAREN
    self.expect(TokenKind.LPAREN);
    # Build name for class
    if len(names) == 1 {
        class_name = names[0];
    } else {
        # Build nested AtomTrailers for dotted name
        class_name = names[0];
        for i in range(1, len(names)) {
            class_name = AtomTrailer(
                target=class_name,
                right=names[i],
                is_attr=True,
                is_null_ok=False,
                kid=[class_name, self.gen_token(Tok.DOT.value), names[i]]
            );
        }
    }
    arg_patterns: list = [];
    kw_patterns: list = [];
    kid: list = [];
    # Add the class name
    kid.append(class_name);
    kid.append(self.gen_token(Tok.LPAREN.value));
    # Parse patterns
    while not self.check(TokenKind.RPAREN) and not self.at_end() {
        # Check if it's a keyword pattern (NAME EQ)
        if self.check_name() and self.peek().kind == TokenKind.EQ {
            # Keyword pattern
            name_tok = self.advance();
            self.expect(TokenKind.EQ);
            val = self.parse_pattern();
            name = self.make_name(name_tok);
            kv = MatchKVPair(
                key=name, value=val, kid=[name, self.gen_token(Tok.EQ.value), val]
            );
            kw_patterns.append(kv);
            kid.append(kv);
        } else {
            # Positional pattern
            pat = self.parse_pattern();
            arg_patterns.append(pat);
            kid.append(pat);
        }
        if not self.check(TokenKind.RPAREN) {
            self.expect(TokenKind.COMMA);
            kid.append(self.gen_token(Tok.COMMA.value));
        }
    }
    self.expect(TokenKind.RPAREN);
    kid.append(self.gen_token(Tok.RPAREN.value));
    return MatchArch(
        name=class_name, arg_patterns=arg_patterns, kw_patterns=kw_patterns, kid=kid
    );
}

impl Parser.parse_return_stmt -> ReturnStmt {
    self.expect(TokenKind.KW_RETURN);
    expr = None;
    if not self.check(TokenKind.SEMI) and not self.check(TokenKind.RBRACE) {
        expr = self.parse_expression();
    }
    kid: list = [self.gen_token(Tok.KW_RETURN.value)];
    if expr {
        kid.append(expr);
    }
    if self.match_tok(TokenKind.SEMI) {
        kid.append(self.make_semi());
    }
    return ReturnStmt(expr=expr, kid=kid);
}

impl Parser.parse_yield_stmt -> YieldExpr {
    self.expect(TokenKind.KW_YIELD);
    with_from = False;
    if self.match_tok(TokenKind.KW_FROM) {
        with_from = True;
    }
    expr = None;
    if not self.check(TokenKind.SEMI) and not self.check(TokenKind.RBRACE) {
        expr = self.parse_expression();
    }
    kid: list = [self.gen_token(Tok.KW_YIELD.value)];
    if with_from {
        kid.append(self.gen_token(Tok.KW_FROM.value));
    }
    if expr {
        kid.append(expr);
    }
    return YieldExpr(expr=expr, with_from=with_from, kid=kid);
}

impl Parser.parse_raise_stmt -> RaiseStmt {
    self.expect(TokenKind.KW_RAISE);
    expr = None;
    from_target = None;
    if not self.check(TokenKind.SEMI) and not self.check(TokenKind.RBRACE) {
        expr = self.parse_expression();
    }
    if self.match_tok(TokenKind.KW_FROM) {
        from_target = self.parse_expression();
    }
    kid: list = [self.gen_token(Tok.KW_RAISE.value)];
    if expr {
        kid.append(expr);
    }
    if from_target {
        kid.append(self.gen_token(Tok.KW_FROM.value));
        kid.append(from_target);
    }
    if self.match_tok(TokenKind.SEMI) {
        kid.append(self.make_semi());
    }
    return RaiseStmt(cause=expr, from_target=from_target, kid=kid);
}

impl Parser.parse_assert_stmt -> AssertStmt {
    self.expect(TokenKind.KW_ASSERT);
    test = self.parse_expression();
    msg = None;
    if self.match_tok(TokenKind.COMMA) {
        msg = self.parse_expression();
    }
    kid: list = [self.gen_token(Tok.KW_ASSERT.value), test];
    if msg {
        kid.append(self.gen_token(Tok.COMMA.value));
        kid.append(msg);
    }
    if self.match_tok(TokenKind.SEMI) {
        kid.append(self.make_semi());
    }
    return AssertStmt(condition=test, error_msg=msg, kid=kid);
}

impl Parser.parse_delete_stmt -> DeleteStmt {
    self.expect(TokenKind.KW_DELETE);
    target = self.parse_expression();
    kid: list = [self.gen_token(Tok.KW_DELETE.value), target];
    if self.match_tok(TokenKind.SEMI) {
        kid.append(self.make_semi());
    }
    return DeleteStmt(target=target, kid=kid);
}

impl Parser.parse_global_stmt -> GlobalStmt {
    # Parse: global name1, name2, ...;
    self.expect(TokenKind.KW_GLOBAL_REF);
    targets: list = [];
    kid: list = [self.gen_token("global")];
    name_tok = self.expect_name();
    name = self.make_name(name_tok);
    targets.append(name);
    kid.append(name);
    while self.match_tok(TokenKind.COMMA) {
        kid.append(self.gen_token(Tok.COMMA.value));
        name_tok = self.expect_name();
        name = self.make_name(name_tok);
        targets.append(name);
        kid.append(name);
    }
    if self.match_tok(TokenKind.SEMI) {
        kid.append(self.make_semi());
    }
    return GlobalStmt(target=targets, kid=kid);
}

impl Parser.parse_nonlocal_stmt -> NonLocalStmt {
    # Parse: nonlocal name1, name2, ...;
    self.expect(TokenKind.KW_NONLOCAL);
    targets: list = [];
    kid: list = [self.gen_token("nonlocal")];
    name_tok = self.expect_name();
    name = self.make_name(name_tok);
    targets.append(name);
    kid.append(name);
    while self.match_tok(TokenKind.COMMA) {
        kid.append(self.gen_token(Tok.COMMA.value));
        name_tok = self.expect_name();
        name = self.make_name(name_tok);
        targets.append(name);
        kid.append(name);
    }
    if self.match_tok(TokenKind.SEMI) {
        kid.append(self.make_semi());
    }
    return NonLocalStmt(target=targets, kid=kid);
}

impl Parser.parse_assignment_with_target(target: Expr) -> Assignment {
    type_tag = None;
    if self.match_tok(TokenKind.COLON) {
        colon_tok = self.gen_token(Tok.COLON.value, ":");
        tp = self.parse_pipe();
        type_tag = SubTag(tag=tp, kid=[colon_tok, tp]);
    }
    value = None;
    aug_op = None;
    targets: list = [target];
    if self.match_tok(TokenKind.EQ) {
        value = self.parse_expression();
        # Chain assignment: l1 = l2 = ... = expr
        while self.check(TokenKind.EQ)
        and not self.check_any(TokenKind.SEMI, TokenKind.RBRACE) {
            self.advance();
            targets.append(value);
            value = self.parse_expression();
        }
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
    kid: list = [];
    for (ti, tgt) in enumerate(targets) {
        kid.append(tgt);
        if ti < len(targets) - 1 {
            kid.append(self.gen_token(Tok.EQ.value));
        }
    }
    if type_tag {
        kid.append(type_tag);
    }
    if aug_op {
        kid.append(aug_op);
    } elif value {
        kid.append(self.gen_token(Tok.EQ.value));
    }
    if value {
        kid.append(value);
    }
    # Add Semi as child of Assignment (matching Lark structure)
    if self.match_tok(TokenKind.SEMI) {
        prev = self.previous();
        kid.append(
            Semi(
                orig_src=self.get_source(),
                name=Tok.SEMI.value,
                value=";",
                line=prev.loc.line,
                end_line=prev.loc.end_line,
                col_start=prev.loc.col_start,
                col_end=prev.loc.col_end,
                pos_start=prev.loc.pos_start,
                pos_end=prev.loc.pos_end
            )
        );
    }
    return Assignment(
        target=targets,
        value=value,
        type_tag=type_tag,
        kid=kid,
        mutable=True,
        aug_op=aug_op,
        is_enum_stmt=False
    );
}

# =============================================================================
# DECLARATION PARSING Implementations
# =============================================================================
impl Parser.parse_import_stmt -> Import {
    is_include = self.check(TokenKind.KW_INCLUDE);
    hint_tok = self.advance();
    kid: list = [self.make_uni_token(hint_tok)];
    # Check for 'import from X { Y }' syntax
    from_loc: ModulePath | None = None;
    if self.match_tok(TokenKind.KW_FROM) {
        kid.append(self.gen_token(Tok.KW_FROM.value));
        # Parse module path
        path_names: list = [];
        if self.check_any(TokenKind.DOT, TokenKind.ELLIPSIS) {
            # Relative import (.module, ..module, ...module)
            while self.check_any(TokenKind.DOT, TokenKind.ELLIPSIS) {
                if self.check(TokenKind.ELLIPSIS) {
                    path_names.append(self.make_ellipsis(self.advance()));
                } else {
                    path_names.append(self.make_uni_token(self.advance()));
                }
            }
        }
        path_kid: list = [];
        # Add leading dot tokens to path_kid for relative imports
        for pn in path_names {
            path_kid.append(pn);
        }
        if self.check(TokenKind.STRING) {
            # String import path: import from "@jac/runtime" { ... }
            str_tok = self.advance();
            str_node = self.make_string(str_tok);
            path_names.append(str_node);
            path_kid.append(str_node);
        } elif self.check_name() or self.is_keyword_token() {
            name_tok = self.advance();
            nm = self.make_name_or_special(name_tok);
            path_names.append(nm);
            path_kid.append(nm);
            while self.match_tok(TokenKind.DOT) {
                path_kid.append(self.gen_token(Tok.DOT.value, "."));
                if self.check_name() or self.is_keyword_token() {
                    name_tok = self.advance();
                    nm = self.make_name_or_special(name_tok);
                } else {
                    name_tok = self.expect(TokenKind.NAME);
                    nm = self.make_name(name_tok);
                }
                path_names.append(nm);
                path_kid.append(nm);
            }
        }
        if len(path_kid) == 0 {
            path_kid = path_names or [EmptyToken()];
        }
        from_loc = ModulePath(path=path_names, level=0, alias=None, kid=path_kid);
        kid.append(from_loc);
    }
    # Parse items in braces: { item1, item2, ... }
    items: list = [];
    if self.match_tok(TokenKind.LBRACE) {
        kid.append(self.gen_token(Tok.LBRACE.value));
        while not self.check(TokenKind.RBRACE) and not self.at_end() {
            item_name: Name;
            if self.check(TokenKind.STAR_MUL) {
                # Star import: import from X { * as Y }
                self.advance();
                item_name = self.gen_token(Tok.STAR_MUL.value, "*");
            } else {
                item_name_tok: Token;
                if self.check(TokenKind.KW_DEFAULT) {
                    # KW_DEFAULT stays as a Token in imports
                    item_name_tok = self.advance();
                    item_name = self.make_uni_token(item_name_tok);
                } elif self.check_name() {
                    item_name_tok = self.advance();
                    item_name = self.make_name(item_name_tok);
                } elif self.is_keyword_token() {
                    item_name_tok = self.advance();
                    item_name = self.make_name_or_special(item_name_tok);
                } else {
                    item_name_tok = self.expect_name();
                    item_name = self.make_name(item_name_tok);
                }
            }
            alias = None;
            if self.match_tok(TokenKind.KW_AS) {
                alias_tok = self.expect_name();
                alias = self.make_name(alias_tok);
            }
            item_kid: list = [item_name];
            if alias is not None {
                item_kid.append(self.gen_token(Tok.KW_AS.value, "as"));
                item_kid.append(alias);
            }
            item = ModuleItem(name=item_name, alias=alias, kid=item_kid);
            items.append(item);
            kid.append(item);
            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
            kid.append(self.gen_token(Tok.COMMA.value));
        }
        self.expect(TokenKind.RBRACE);
        kid.append(self.gen_token(Tok.RBRACE.value));
    } elif from_loc is None {
        # Simple import: import module.path [as alias] [, module.path [as alias], ...]
        while True {
            path_names: list = [];
            path_kid: list = [];
            if self.check(TokenKind.STRING) {
                str_tok = self.advance();
                str_node = self.make_string(str_tok);
                path_names.append(str_node);
                path_kid.append(str_node);
            } elif self.check_name() or self.is_keyword_token() {
                name_tok = self.advance();
                nm = self.make_name_or_special(name_tok);
                path_names.append(nm);
                path_kid.append(nm);
                while self.match_tok(TokenKind.DOT) {
                    path_kid.append(self.gen_token(Tok.DOT.value, "."));
                    if self.check_name() or self.is_keyword_token() {
                        name_tok = self.advance();
                    } else {
                        name_tok = self.expect_name();
                    }
                    nm = self.make_name_or_special(name_tok);
                    path_names.append(nm);
                    path_kid.append(nm);
                }
            }
            if len(path_kid) == 0 {
                path_kid = [EmptyToken()];
            }
            # Handle alias: import X as Y
            alias: Name | None = None;
            if self.match_tok(TokenKind.KW_AS) {
                alias_tok = self.expect_name();
                alias = self.make_name(alias_tok);
                path_kid.append(self.gen_token(Tok.KW_AS.value, "as"));
                path_kid.append(alias);
            }
            path = ModulePath(path=path_names, level=0, alias=alias, kid=path_kid);
            item = ModuleItem(
                name=path_names[-1]
                if path_names
                else self.gen_token(Tok.NAME.value, ""),
                alias=alias,
                kid=[path] if alias is None else [path, alias]
            );
            items.append(item);
            kid.append(path);
            # Check for more imports
            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
            kid.append(self.gen_token(Tok.COMMA.value));
        }
    }
    if self.match_tok(TokenKind.SEMI) {
        kid.append(self.make_semi());
    }
    return Import(
        from_loc=from_loc, items=items, is_absorb=is_include, kid=kid, doc=None
    );
}

impl Parser.parse_archetype -> Archetype {
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
    access = self.parse_access_tag();
    name_tok: Token;
    if self.check_name() {
        name_tok = self.advance();
    } elif self.is_keyword_token() {
        name_tok = self.advance();
    } else {
        name_tok = self.expect_name();
    }
    name = self.make_name_or_special(name_tok);
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
    has_body = False;
    if self.match_tok(TokenKind.LBRACE) {
        has_body = True;
        while not self.check(TokenKind.RBRACE) and not self.at_end() {
            member = self.parse_archetype_member();
            if member is not None {
                body.append(member);
            }
        }
        self.expect(TokenKind.RBRACE);
    } else {
        self.match_tok(TokenKind.SEMI);
    }
    kid: list = [];
    for d in decorators {
        kid.append(self.gen_token(Tok.DECOR_OP.value, "@"));
        kid.append(d);
    }
    if is_async {
        kid.append(self.gen_token(Tok.KW_ASYNC.value, "async"));
    }
    kid.append(arch_type);
    if access {
        kid.append(access);
    }
    kid.append(name);
    if base_classes {
        kid.append(self.gen_token(Tok.LPAREN.value));
        for (i, bc) in enumerate(base_classes) {
            if i > 0 {
                kid.append(self.gen_token(Tok.COMMA.value, ","));
            }
            kid.append(bc);
        }
        kid.append(self.gen_token(Tok.RPAREN.value));
    }
    if has_body {
        kid.append(self.gen_token(Tok.LBRACE.value));
        kid.extend(body);
        kid.append(self.gen_token(Tok.RBRACE.value));
    } else {
        kid.append(self.make_semi());
    }
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

impl Parser.parse_archetype_member{
    while self.match_tok(TokenKind.SEMI) {
        skip;
    }
    if self.check(TokenKind.RBRACE) or self.at_end() {
        return None;
    }
    # Check for optional docstring before member
    doc: String | None = None;
    if self.check(TokenKind.STRING) {
        doc_tok = self.advance();
        doc = self.make_string(doc_tok);
    }
    # Handle decorators for methods
    if self.check(TokenKind.DECOR_OP) {
        ability = self.parse_ability();
        if doc {
            ability.doc = doc;
            ability.add_kids_left([doc]);
        }
        return ability;
    }
    # Handle static has or static def/can
    if self.check(TokenKind.KW_STATIC) {
        # Look ahead to see if it's static has or static def/can
        if self.peek().kind == TokenKind.KW_HAS {
            has_stmt = self.parse_has_stmt();
            if doc {
                has_stmt.doc = doc;
                has_stmt.add_kids_left([doc]);
            }
            return has_stmt;
        }
        # static def or static can
        ability = self.parse_ability();
        if doc {
            ability.doc = doc;
            ability.add_kids_left([doc]);
        }
        return ability;
    }
    if self.check(TokenKind.KW_HAS) {
        has_stmt = self.parse_has_stmt();
        if doc {
            has_stmt.doc = doc;
            has_stmt.add_kids_left([doc]);
        }
        return has_stmt;
    }
    # Handle async def/can methods
    if self.check(TokenKind.KW_ASYNC) {
        ability = self.parse_ability();
        if doc {
            ability.doc = doc;
            ability.add_kids_left([doc]);
        }
        return ability;
    }
    if self.check_any(TokenKind.KW_DEF, TokenKind.KW_CAN, TokenKind.KW_OVERRIDE) {
        ability = self.parse_ability();
        if doc {
            ability.doc = doc;
            ability.add_kids_left([doc]);
        }
        return ability;
    }
    if self.check_any(
        TokenKind.KW_OBJECT,
        TokenKind.KW_NODE,
        TokenKind.KW_EDGE,
        TokenKind.KW_WALKER,
        TokenKind.KW_CLASS
    )
    or (
        self.check(TokenKind.KW_ABSTRACT)
        and self.peek().kind in [
            TokenKind.KW_OBJECT,
            TokenKind.KW_NODE,
            TokenKind.KW_EDGE,
            TokenKind.KW_WALKER,
            TokenKind.KW_CLASS
        ]
    ) {
        archetype = self.parse_archetype();
        if doc {
            archetype.doc = doc;
            archetype.add_kids_left([doc]);
        }
        return archetype;
    }
    if self.check(TokenKind.KW_ENUM) {
        enum_node = self.parse_enum();
        if doc {
            enum_node.doc = doc;
            enum_node.add_kids_left([doc]);
        }
        return enum_node;
    }
    # Handle inline Python: ::py:: ... ::py::
    if self.check(TokenKind.PYNLINE) {
        py_tok = self.advance();
        py_code = self.make_uni_token(py_tok);
        return PyInlineCode(code=py_code, kid=[py_code]);
    }
    # Handle with entry/exit blocks
    if self.check(TokenKind.KW_WITH) {
        self.advance();  # consume 'with'
        if self.check_any(TokenKind.KW_ENTRY, TokenKind.KW_EXIT) {
            event_tok = self.advance();
            self.expect(TokenKind.LBRACE);
            body = self.parse_code_block_stmts();
            self.expect(TokenKind.RBRACE);
            kid: list = [
                self.gen_token(Tok.KW_WITH.value),
                self.make_uni_token(event_tok),
                self.gen_token(Tok.LBRACE.value)
            ];
            kid.extend(body);
            kid.append(self.gen_token(Tok.RBRACE.value));
            return ModuleCode(name=None, body=body, kid=kid, doc=None);
        }
    }
    expr = self.parse_expression();
    self.match_tok(TokenKind.SEMI);
    return expr;
}

impl Parser.parse_has_stmt -> ArchHas {
    is_static = False;
    if self.match_tok(TokenKind.KW_STATIC) {
        is_static = True;
    }
    self.expect(TokenKind.KW_HAS);
    access = self.parse_access_tag();
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
        kid.append(access);
    }
    # Add vars with commas between them
    for (i, v) in enumerate(vars) {
        if i > 0 {
            kid.append(self.gen_token(Tok.COMMA.value));
        }
        kid.append(v);
    }
    # Add trailing Semi
    prev = self.previous();
    kid.append(
        Semi(
            orig_src=self.get_source(),
            name=Tok.SEMI.value,
            value=";",
            line=prev.loc.line,
            end_line=prev.loc.end_line,
            col_start=prev.loc.col_start,
            col_end=prev.loc.col_end,
            pos_start=prev.loc.pos_start,
            pos_end=prev.loc.pos_end
        )
    );
    return ArchHas(
        is_static=is_static,
        access=access,
        vars=vars,
        is_frozen=False,
        kid=kid,
        doc=None
    );
}

impl Parser.parse_has_var -> HasVar {
    # Check for per-variable access modifier: :pub name: type
    # Note: HasVar doesn't have access field - access modifiers are at ArchHas level
    if self.match_tok(TokenKind.COLON) {
        if self.check_any(TokenKind.KW_PUB, TokenKind.KW_PRIV, TokenKind.KW_PROT) {
            # Skip the access modifier token - it's consumed but not stored per-var
            self.advance();
        }
    }
    name_tok: Token;
    if self.check_name() {
        name_tok = self.advance();
    } elif self.is_keyword_token() {
        name_tok = self.advance();
    } else {
        name_tok = self.expect_name();
    }
    name: Name;
    if name_tok.kind in [
        TokenKind.KW_SELF,
        TokenKind.KW_PROPS,
        TokenKind.KW_SUPER,
        TokenKind.KW_ROOT,
        TokenKind.KW_HERE,
        TokenKind.KW_VISITOR
    ] {
        name = SpecialVarRef(var=self.make_special_name(name_tok), is_enum_stmt=False);
    } elif name_tok.kind == TokenKind.NAME or name_tok.kind == TokenKind.KWESC_NAME {
        name = self.make_name(name_tok);
    } else {
        name = self.make_special_name(name_tok);
    }
    self.expect(TokenKind.COLON);
    type_expr = self.parse_pipe();
    colon_tok = self.gen_token(Tok.COLON.value);
    type_tag = SubTag(tag=type_expr, kid=[colon_tok, type_expr]);
    value = None;
    defer = False;
    if self.match_tok(TokenKind.EQ) {
        value = self.parse_expression();
    } elif self.match_tok(TokenKind.KW_BY) {
        self.expect(TokenKind.KW_POST_INIT);
        defer = True;
    }
    kid: list = [name, type_tag];
    if value {
        kid.append(self.gen_token(Tok.EQ.value));
        kid.append(value);
    }
    if defer {
        kid.append(self.gen_token(Tok.KW_BY.value));
        kid.append(self.make_special_name(self.previous()));
    }
    return HasVar(name=name, type_tag=type_tag, value=value, defer=defer, kid=kid);
}

impl Parser.parse_ability -> Ability {
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
    access = self.parse_access_tag();
    name = None;
    # Allow NAME or certain keywords as method names (per named_ref grammar)
    if self.check_name() {
        name_tok = self.advance();
        name = self.make_name(name_tok);
    } elif self.check_any(
        TokenKind.KW_INIT,
        TokenKind.KW_POST_INIT,
        TokenKind.KW_ROOT,
        TokenKind.KW_SUPER,
        TokenKind.KW_SELF,
        TokenKind.KW_PROPS,
        TokenKind.KW_HERE,
        TokenKind.KW_VISITOR
    ) {
        name_tok = self.advance();
        name = SpecialVarRef(var=self.make_special_name(name_tok), is_enum_stmt=False);
    } elif self.is_keyword_token() and not (is_can and self.check(TokenKind.KW_WITH)) {
        name_tok = self.advance();
        name = self.make_special_name(name_tok);
    }
    signature: FuncSignature | EventSignature;
    if is_can and self.check(TokenKind.KW_WITH) {
        self.advance();
        event_type = self.parse_expression()
        if not self.check_any(TokenKind.KW_ENTRY, TokenKind.KW_EXIT)
        else None;
        event_tok = self.advance();
        event_uni_tok = self.make_uni_token(event_tok);
        # Build EventSignature kid list
        sig_kid: list = [self.gen_token(Tok.KW_WITH.value)];
        if event_type {
            sig_kid.append(event_type);
        }
        sig_kid.append(event_uni_tok);
        signature = EventSignature(
            event=event_uni_tok, arch_tag_info=event_type, kid=sig_kid
        );
    } else {
        signature = self.parse_func_signature();
    }
    body: list = [];
    is_abstract = False;
    body_type = "semi";  # "brace", "by", or "semi"
    if self.match_tok(TokenKind.LBRACE) {
        body_type = "brace";
        body = self.parse_code_block_stmts();
        self.expect(TokenKind.RBRACE);
    } elif self.match_tok(TokenKind.KW_BY) {
        body_type = "by";
        by_expr = self.parse_expression();
        self.expect(TokenKind.SEMI);
        by_expr.add_kids_left([self.gen_token(Tok.KW_BY.value)]);
        by_expr.add_kids_right([self.make_semi()]);
        body = [by_expr];
    } else {
        if self.match_tok(TokenKind.KW_ABSTRACT) {
            is_abstract = True;
        }
        self.expect(TokenKind.SEMI);
    }
    kid: list = [];
    for d in decorators {
        kid.append(self.gen_token(Tok.DECOR_OP.value, "@"));
        kid.append(d);
    }
    if is_override {
        kid.append(self.gen_token(Tok.KW_OVERRIDE.value));
    }
    if is_static {
        kid.append(self.gen_token(Tok.KW_STATIC.value));
    }
    if is_async {
        kid.append(self.gen_token(Tok.KW_ASYNC.value));
    }
    kid.append(self.make_uni_token(ability_tok));
    if access {
        kid.append(access);
    }
    if name {
        kid.append(name);
    }
    # Only add signature if it has actual content (parens/return type present)
    has_sig_content = not (
        len(signature.kid) == 1 and isinstance(signature.kid[0], EmptyToken)
    );
    if has_sig_content {
        kid.append(signature);
    }
    if body_type == "brace" {
        kid.append(self.gen_token(Tok.LBRACE.value));
        kid.extend(body);
        kid.append(self.gen_token(Tok.RBRACE.value));
    } elif body_type == "by" {
        kid.extend(body);
    } else {
        # Declaration-only: add abs token if abstract, then Semi
        if is_abstract {
            kid.append(self.gen_token(Tok.KW_ABSTRACT.value));
        }
        kid.append(self.make_semi());
    }
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

impl Parser.parse_func_signature -> FuncSignature {
    params: list = [];
    return_type = None;
    kid: list = [];
    if self.match_tok(TokenKind.LPAREN) {
        kid.append(self.gen_token(Tok.LPAREN.value, "("));
        if not self.check(TokenKind.RPAREN) {
            params = self.parse_func_params(kid);
        }
        self.expect(TokenKind.RPAREN);
        kid.append(self.gen_token(Tok.RPAREN.value, ")"));
    }
    if self.match_tok(TokenKind.RETURN_HINT) {
        kid.append(self.gen_token(Tok.RETURN_HINT.value, "->"));
        return_type = self.parse_pipe();
        kid.append(return_type);
    }
    # Ensure non-empty kid list for unitree
    if len(kid) == 0 {
        kid.append(EmptyToken());
    }
    return FuncSignature(
        posonly_params=[],
        params=params,
        varargs=None,
        kwonlyargs=[],
        kwargs=None,
        return_type=return_type,
        kid=kid
    );
}

impl Parser.parse_func_params(kid: list) -> list {
    params: list = [];
    while not self.check(TokenKind.RPAREN) {
        # Handle bare * (keyword-only separator) or / (positional-only separator)
        if self.check(TokenKind.STAR_MUL)
        and (
            self.peek().kind == TokenKind.COMMA or self.peek().kind == TokenKind.RPAREN
        ) {
            star_tok = self.advance();
            star_uni = self.make_uni_token(star_tok);
            kid.append(star_uni);
            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
            kid.append(self.gen_token(Tok.COMMA.value, ","));
        } elif self.check(TokenKind.DIV)
        and (
            self.peek().kind == TokenKind.COMMA or self.peek().kind == TokenKind.RPAREN
        ) {
            div_tok = self.advance();
            div_uni = self.make_uni_token(div_tok);
            kid.append(div_uni);
            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
            kid.append(self.gen_token(Tok.COMMA.value, ","));
        } else {
            unpack = None;
            if self.check_any(TokenKind.STAR_MUL, TokenKind.STAR_POW) {
                unpack_tok = self.advance();
                unpack = self.make_uni_token(unpack_tok);
            }
            # Allow NAME, KWESC_NAME, self, or any keyword as parameter names
            if self.check_name() {
                name_tok = self.advance();
                name = self.make_name(name_tok);
            } elif self.check(TokenKind.KW_SELF) {
                name_tok = self.advance();
                name = SpecialVarRef(
                    var=self.make_special_name(name_tok), is_enum_stmt=False
                );
            } elif self.is_keyword_token() {
                name_tok = self.advance();
                if name_tok.kind in [
                    TokenKind.KW_SELF,
                    TokenKind.KW_PROPS,
                    TokenKind.KW_SUPER,
                    TokenKind.KW_ROOT,
                    TokenKind.KW_HERE,
                    TokenKind.KW_VISITOR
                ] {
                    name = SpecialVarRef(
                        var=self.make_special_name(name_tok), is_enum_stmt=False
                    );
                } else {
                    name = self.make_special_name(name_tok);
                }
            } else {
                break;
            }
            if name {
                type_tag: SubTag | None = None;
                if self.match_tok(TokenKind.COLON) {
                    colon_tok = self.gen_token(Tok.COLON.value, ":");
                    tp = self.parse_pipe();
                    type_tag = SubTag(tag=tp, kid=[colon_tok, tp]);
                }
                default_val: Expr | None = None;
                if self.match_tok(TokenKind.EQ) {
                    default_val = self.parse_expression();
                }
                pv_kid: list = [];
                if unpack {
                    pv_kid.append(unpack);
                }
                pv_kid.append(name);
                if type_tag {
                    pv_kid.append(type_tag);
                }
                if default_val {
                    pv_kid.append(self.gen_token(Tok.EQ.value, "="));
                    pv_kid.append(default_val);
                }
                # Cast type_tag for ParamVar - runtime accepts None despite type hint
                tag_param: SubTag = type_tag
                if isinstance(type_tag, SubTag)
                else type_tag;
                pv = ParamVar(
                    name=name,
                    unpack=unpack,
                    type_tag=tag_param,
                    value=default_val,
                    kid=pv_kid
                );
                params.append(pv);
                kid.append(pv);
            }
            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
            kid.append(self.gen_token(Tok.COMMA.value, ","));
        }
    }
    return params;
}

impl Parser.parse_enum -> Enum {
    decorators: list = [];
    while self.check(TokenKind.DECOR_OP) {
        self.advance();
        decorators.append(self.parse_atomic_chain());
    }
    self.expect(TokenKind.KW_ENUM);
    access = self.parse_access_tag();
    name_tok: Token;
    if self.check_name() {
        name_tok = self.advance();
    } elif self.is_keyword_token() {
        name_tok = self.advance();
    } else {
        name_tok = self.expect_name();
    }
    name = self.make_name_or_special(name_tok);
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
    body_kid: list = [];
    has_body = False;
    if self.match_tok(TokenKind.LBRACE) {
        has_body = True;
        while not self.check(TokenKind.RBRACE) and not self.at_end() {
            if self.check_name() {
                member = self.parse_enum_member();
                body.append(member);
                body_kid.append(member);
                if self.match_tok(TokenKind.COMMA) {
                    body_kid.append(self.gen_token(Tok.COMMA.value, ","));
                }
            } else {
                break;
            }
        }
        self.expect(TokenKind.RBRACE);
    } else {
        self.expect(TokenKind.SEMI);
    }
    kid: list = [];
    for d in decorators {
        kid.append(self.gen_token(Tok.DECOR_OP.value, "@"));
        kid.append(d);
    }
    kid.append(self.gen_token(Tok.KW_ENUM.value));
    if access {
        kid.append(access);
    }
    kid.append(name);
    if has_body {
        kid.append(self.gen_token(Tok.LBRACE.value));
        kid.extend(body_kid);
        kid.append(self.gen_token(Tok.RBRACE.value));
    } else {
        kid.append(self.make_semi());
    }
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

impl Parser.parse_enum_member -> Assignment {
    name_tok = self.expect_name();
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

impl Parser.parse_test -> Test {
    self.expect(TokenKind.KW_TEST);
    # When no explicit name, use a Token to trigger auto-generated name
    name: Name | UniToken = self.gen_token(Tok.NAME.value, "");
    has_explicit_name = False;
    if self.check(TokenKind.NAME) {
        name_tok = self.advance();
        name = self.make_name(name_tok);
        has_explicit_name = True;
    }
    self.expect(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    self.expect(TokenKind.RBRACE);
    kid: list = [self.gen_token(Tok.KW_TEST.value)];
    if has_explicit_name {
        kid.append(name);
    }
    kid.append(self.gen_token(Tok.LBRACE.value));
    kid.extend(body);
    kid.append(self.gen_token(Tok.RBRACE.value));
    return Test(name=name, body=body, kid=kid, doc=None);
}

# =============================================================================
# Switch Statement Implementation
# =============================================================================
impl Parser.parse_switch_stmt -> SwitchStmt {
    self.expect(TokenKind.KW_SWITCH);
    target = self.parse_expression();
    self.expect(TokenKind.LBRACE);
    cases: list = [];
    while self.check_any(TokenKind.KW_CASE, TokenKind.KW_DEFAULT) {
        cases.append(self.parse_switch_case());
    }
    self.expect(TokenKind.RBRACE);
    kid: list = [
        self.gen_token(Tok.KW_SWITCH.value),
        target,
        self.gen_token(Tok.LBRACE.value)
    ];
    kid.extend(cases);
    kid.append(self.gen_token(Tok.RBRACE.value));
    return SwitchStmt(target=target, cases=cases, kid=kid);
}

impl Parser.parse_switch_case -> SwitchCase {
    is_default = False;
    pattern = None;
    if self.match_tok(TokenKind.KW_DEFAULT) {
        is_default = True;
    } else {
        self.expect(TokenKind.KW_CASE);
        pattern = self.parse_pattern();
    }
    self.expect(TokenKind.COLON);
    body: list = [];
    while not self.check_any(TokenKind.KW_CASE, TokenKind.KW_DEFAULT, TokenKind.RBRACE)
    and not self.at_end() {
        stmt = self.parse_statement();
        if stmt is not None {
            body.append(stmt);
        }
    }
    kid: list = [];
    if is_default {
        kid.append(self.gen_token(Tok.KW_DEFAULT.value));
    } else {
        kid.append(self.gen_token(Tok.KW_CASE.value));
        if pattern {
            kid.append(pattern);
        }
    }
    kid.append(self.gen_token(Tok.COLON.value));
    kid.extend(body);
    return SwitchCase(pattern=pattern, body=body, kid=kid);
}

# =============================================================================
# Global Variable Implementation
# =============================================================================
impl Parser.parse_global_var -> GlobalVars {
    self.expect(TokenKind.KW_GLOBAL);
    access = self.parse_access_tag();
    # Parse assignment list
    assignments: list = [];
    assignments.append(self.parse_global_var_assignment());
    while self.match_tok(TokenKind.COMMA) {
        assignments.append(self.parse_global_var_assignment());
    }
    self.expect(TokenKind.SEMI);
    kid: list = [self.gen_token(Tok.KW_GLOBAL.value)];
    if access {
        kid.append(access);
    }
    # Add assignments with commas between them
    for (i, a) in enumerate(assignments) {
        if i > 0 {
            kid.append(self.gen_token(Tok.COMMA.value));
        }
        kid.append(a);
    }
    # Add trailing Semi
    kid.append(
        Semi(
            orig_src=self.get_source(),
            name=Tok.SEMI.value,
            value=";",
            line=self.previous().loc.line,
            end_line=self.previous().loc.end_line,
            col_start=self.previous().loc.col_start,
            col_end=self.previous().loc.col_end,
            pos_start=self.previous().loc.pos_start,
            pos_end=self.previous().loc.pos_end
        )
    );
    return GlobalVars(
        access=access, assignments=assignments, is_frozen=False, kid=kid, doc=None
    );
}

impl Parser.parse_global_var_assignment -> Assignment {
    name_tok: Token;
    if self.check_name() {
        name_tok = self.advance();
    } elif self.is_keyword_token() {
        name_tok = self.advance();
    } else {
        name_tok = self.expect_name();
    }
    name = self.make_name_or_special(name_tok);
    type_tag: SubTag | None = None;
    if self.match_tok(TokenKind.COLON) {
        gv_colon = self.gen_token(Tok.COLON.value, ":");
        tp = self.parse_pipe();
        type_tag = SubTag(tag=tp, kid=[gv_colon, tp]);
    }
    value = None;
    if self.match_tok(TokenKind.EQ) {
        value = self.parse_expression();
    }
    kid: list = [name];
    if type_tag {
        kid.append(type_tag);
    }
    if value {
        kid.append(self.gen_token(Tok.EQ.value));
        kid.append(value);
    }
    return Assignment(
        target=[name],
        value=value,
        type_tag=type_tag,
        kid=kid,
        mutable=True,
        aug_op=None,
        is_enum_stmt=False
    );
}

# =============================================================================
# Impl Definition Implementation
# =============================================================================
impl Parser.parse_impl_def -> ImplDef {
    decorators: list = [];
    while self.check(TokenKind.DECOR_OP) {
        self.advance();
        decorators.append(self.parse_atomic_chain());
    }
    self.expect(TokenKind.KW_IMPL);
    # Parse dotted name as a list of Name objects (e.g., [MyClass, my_method])
    target_names: list = [];
    target_names.append(self.parse_impl_target_name());
    while self.match_tok(TokenKind.DOT) {
        target_names.append(self.parse_impl_target_name());
    }
    # Parse optional impl_spec (inherited_archs, func_decl, or event_clause)
    spec: FuncSignature | EventSignature | list | None = None;
    base_classes: list = [];
    if self.check(TokenKind.LPAREN) {
        # Need to distinguish between func_decl (params) and inherited_archs
        # func_decl params have the form: name: type
        # inherited_archs have the form: TypeName, TypeName2
        # Peek ahead to check if it looks like parameters (NAME COLON)
        is_func_params = False;
        pk1 = self.peek(1).kind;
        if self.peek(2).kind == TokenKind.COLON and pk1 != TokenKind.RPAREN {
            is_func_params = True;
        } elif self.peek(1).kind == TokenKind.KW_SELF {
            is_func_params = True;
        } elif self.peek(1).kind == TokenKind.STAR_MUL
        or self.peek(1).kind == TokenKind.STAR_POW {
            is_func_params = True;
        } elif self.peek(1).kind == TokenKind.RPAREN {
            # Empty parens - could be either, treat as func params
            is_func_params = True;
        }
        if is_func_params {
            spec = self.parse_func_signature();
        } else {
            # inherited_archs
            self.advance();  # consume LPAREN
            if not self.check(TokenKind.RPAREN) {
                base_classes.append(self.parse_atomic_chain());
                while self.match_tok(TokenKind.COMMA) {
                    base_classes.append(self.parse_atomic_chain());
                }
            }
            self.expect(TokenKind.RPAREN);
            spec = base_classes;
        }
    } elif self.check(TokenKind.KW_WITH) {
        # event_clause
        self.advance();
        event_type = self.parse_expression()
        if not self.check_any(TokenKind.KW_ENTRY, TokenKind.KW_EXIT)
        else None;
        event_tok = self.advance();
        spec = EventSignature(
            event=self.make_uni_token(event_tok),
            arch_tag_info=event_type,
            kid=[self.make_uni_token(event_tok)]
            if event_type is None
            else [event_type, self.make_uni_token(event_tok)]
        );
    } elif self.check(TokenKind.RETURN_HINT)
    or (self.check(TokenKind.LPAREN) and not self.check(TokenKind.LBRACE)) {
        # func_decl
        spec = self.parse_func_signature();
    }
    # Parse impl_tail (enum_block or block_tail)
    body: list | Expr = [];
    if self.match_tok(TokenKind.LBRACE) {
        # Check if this is enum-style body (NAME = value, NAME = value, ... or NAME, NAME, ...)
        # Key distinction: enum-style uses commas, regular uses semicolons
        is_enum_style = False;
        # Bare name followed by comma is enum-style: impl Enum { Bar, Baz }
        if self.check_name() and self.peek().kind == TokenKind.COMMA {
            is_enum_style = True;
        }
        # NAME = value followed by comma is enum-style
        if not is_enum_style and self.check_name() and self.peek().kind == TokenKind.EQ {
            # Look further ahead to find COMMA or SEMI after the value
            save_pos = self.pos;
            self.advance();  # consume NAME
            self.advance();  # consume EQ
            # Skip the value expression to find delimiter
            depth = 0;
            while not self.at_end()
            and not (
                depth == 0
                and self.check_any(TokenKind.COMMA, TokenKind.SEMI, TokenKind.RBRACE)
            ) {
                if self.check_any(
                    TokenKind.LPAREN, TokenKind.LBRACE, TokenKind.LSQUARE
                ) {
                    depth += 1;
                } elif self.check_any(
                    TokenKind.RPAREN, TokenKind.RBRACE, TokenKind.RSQUARE
                ) {
                    if depth > 0 {
                        depth -= 1;
                    } else {
                        break;
                    }
                }
                self.advance();
            }
            # Check if we found comma (enum-style) or semicolon/rbrace (regular)
            if self.check(TokenKind.COMMA) {
                is_enum_style = True;
            }
            self.pos = save_pos;  # Restore position
        }
        if is_enum_style {
            body = self.parse_impl_enum_body();
        } else {
            body = self.parse_code_block_stmts();
        }
        self.expect(TokenKind.RBRACE);
    } elif self.match_tok(TokenKind.KW_BY) {
        body = self.parse_expression();
        self.expect(TokenKind.SEMI);
    } else {
        self.expect(TokenKind.SEMI);
    }
    kid: list = [];
    for d in decorators {
        kid.append(self.gen_token(Tok.DECOR_OP.value, "@"));
        kid.append(d);
    }
    kid.append(self.gen_token(Tok.KW_IMPL.value));
    for (i, n) in enumerate(target_names) {
        kid.append(n);
        if i < len(target_names) - 1 {
            kid.append(self.gen_token(Tok.DOT.value));
        }
    }
    if isinstance(spec, FuncSignature) or isinstance(spec, EventSignature) {
        kid.append(spec);
    } elif isinstance(spec, list) and len(spec) > 0 {
        # inherited_archs in parens
        kid.append(self.gen_token(Tok.LPAREN.value, "("));
        for (i, bc) in enumerate(spec) {
            if i > 0 {
                kid.append(self.gen_token(Tok.COMMA.value, ","));
            }
            kid.append(bc);
        }
        kid.append(self.gen_token(Tok.RPAREN.value, ")"));
    }
    if isinstance(body, list) {
        kid.append(self.gen_token(Tok.LBRACE.value));
        kid.extend(body);
        kid.append(self.gen_token(Tok.RBRACE.value));
    } else {
        kid.append(self.gen_token(Tok.KW_BY.value));
        kid.append(body);
    }
    return ImplDef(
        decorators=decorators,
        target=target_names,
        spec=spec,
        body=body,
        kid=kid,
        doc=None
    );
}

impl Parser.parse_impl_target_name -> Name {
    # Accept NAME, KWESC_NAME, or certain keywords as impl target names
    if self.check_name() {
        name_tok = self.advance();
        return self.make_name(name_tok);
    } elif self.check_any(TokenKind.KW_INIT, TokenKind.KW_POST_INIT) {
        name_tok = self.advance();
        return SpecialVarRef(var=self.make_special_name(name_tok), is_enum_stmt=False);
    } elif self.check_any(TokenKind.KW_ENTRY, TokenKind.KW_EXIT, TokenKind.KW_DEFAULT) {
        name_tok = self.advance();
        return self.make_special_name(name_tok);
    } else {
        name_tok = self.expect(TokenKind.NAME);  # Will error
        return self.make_name(name_tok);
    }
}

impl Parser.parse_impl_enum_body -> list {
    # Parse enum-style impl body: NAME = value, NAME = value, ...
    # Comma-separated assignments (final comma optional)
    members: list = [];
    while not self.check(TokenKind.RBRACE) and not self.at_end() {
        if self.check_name() {
            name_tok = self.advance();
            name = self.make_name(name_tok, is_enum_stmt=True);
            value: Expr | None = None;
            if self.match_tok(TokenKind.EQ) {
                value = self.parse_expression();
            }
            kid: list = [name];
            if value {
                kid.append(self.gen_token(Tok.EQ.value));
                kid.append(value);
            }
            members.append(
                Assignment(
                    target=[name],
                    value=value,
                    type_tag=None,
                    kid=kid,
                    mutable=True,
                    aug_op=None,
                    is_enum_stmt=True
                )
            );
            # Consume optional comma and add to members list
            if self.match_tok(TokenKind.COMMA) {
                members.append(self.gen_token(Tok.COMMA.value, ","));
            }
        } else {
            break;
        }
    }
    return members;
}

impl Parser.parse_sem_def -> SemDef {
    # Parse semantic definition: sem name = "description";  or  sem name.attr = "description";
    self.expect(TokenKind.KW_SEM);
    target_names: list = [];
    target_names.append(self.parse_impl_target_name());
    while self.match_tok(TokenKind.DOT) {
        target_names.append(self.parse_impl_target_name());
    }
    self.expect(TokenKind.EQ);
    # SemDef value is a bare STRING, not a multistring expression
    value_tok = self.expect(TokenKind.STRING);
    value = self.make_string(value_tok);
    kid: list = [self.gen_token(Tok.KW_SEM.value)];
    for (i, n) in enumerate(target_names) {
        kid.append(n);
        if i < len(target_names) - 1 {
            kid.append(self.gen_token(Tok.DOT.value));
        }
    }
    kid.append(self.gen_token(Tok.EQ.value));
    kid.append(value);
    kid.append(self.make_semi());
    self.match_tok(TokenKind.SEMI);
    return SemDef(target=target_names, value=value, kid=kid);
}

impl Parser.parse_dotted_name -> Expr {
    name_tok = self.expect(TokenKind.NAME);
    result: Expr = self.make_name(name_tok);
    while self.match_tok(TokenKind.DOT) {
        next_name_tok = self.expect(TokenKind.NAME);
        next_name = self.make_name(next_name_tok);
        kid: list = [result, self.gen_token(Tok.DOT.value, "."), next_name];
        result = AtomTrailer(
            target=result, right=next_name, is_attr=True, is_null_ok=False, kid=kid
        );
    }
    return result;
}

# =============================================================================
# Visit Statement Implementation
# =============================================================================
impl Parser.parse_visit_stmt -> VisitStmt {
    self.expect(TokenKind.KW_VISIT);
    # Check for optional insert location: visit :SomeExpr: target
    insert_loc = None;
    if self.match_tok(TokenKind.COLON) {
        insert_loc = self.parse_expression();
        self.expect(TokenKind.COLON);
    }
    target = self.parse_expression();
    else_body = None;
    has_semi = False;
    if self.check(TokenKind.KW_ELSE) {
        else_body = self.parse_else_stmt();
    } elif self.match_tok(TokenKind.SEMI) {
        has_semi = True;
    }
    kid: list = [self.gen_token(Tok.KW_VISIT.value)];
    if insert_loc {
        kid.append(self.gen_token(Tok.COLON.value));
        kid.append(insert_loc);
        kid.append(self.gen_token(Tok.COLON.value));
    }
    kid.append(target);
    if else_body {
        kid.append(else_body);
    } elif has_semi {
        kid.append(self.make_semi());
    }
    return VisitStmt(
        insert_loc=insert_loc, target=target, else_body=else_body, kid=kid
    );
}

# =============================================================================
# Report Statement Implementation
# =============================================================================
impl Parser.parse_report_stmt -> ReportStmt {
    self.expect(TokenKind.KW_REPORT);
    expr = self.parse_expression();
    kid: list = [self.gen_token(Tok.KW_REPORT.value), expr];
    if self.match_tok(TokenKind.SEMI) {
        kid.append(self.make_semi());
    }
    return ReportStmt(expr=expr, kid=kid);
}

# =============================================================================
# Convenience Function Implementation
# =============================================================================
impl parse(
    source: str, file_path: str = "<input>"
) -> tuple[Module, list[ParseError], list[LexerError]] {
    lexer = Lexer(source=source, file_path=file_path);
    tokens = lexer.tokenize();
    parser = Parser(tokens=tokens, file_path=file_path, source_code=source);
    module = parser.parse();
    return (module, parser.errors, lexer.errors);
}
