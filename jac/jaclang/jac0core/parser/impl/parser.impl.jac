"""Implementation blocks for the Jac parser.

This file contains the method implementations for the Parser class.
The signatures are defined in parser.jac.
"""

# Import unitree classes from Python
import from jaclang.jac0core.unitree {
    UniNode,
    Token as UniToken,
    Expr
}
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

import from jaclang.jac0core.constant { Tokens as Tok, SymbolAccess, SymbolType }
import from jaclang.jac0core.codeinfo { CodeLocInfo }
import from jaclang.jac0core.passes.transform { Alert }

impl Parser.current -> Token {
    if self.pos < self._tokens_len {
        return self.tokens[self.pos];
    }
    return self.tokens[-1];
}

impl Parser.peek(offset: int = 1) -> Token {
    idx = self.pos + offset;
    if idx < self._tokens_len {
        return self.tokens[idx];
    }
    return self.tokens[-1];
}

impl Parser.advance -> Token {
    tok = self.current();
    if self.pos < self._tokens_len - 1 {
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

impl Parser.check_peek(kind: TokenKind) -> bool {
    return self.peek().kind == kind;
}

impl Parser.check_peek_any(*kinds: TokenKind) -> bool {
    return self.peek().kind in kinds;
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
    # Generate user-friendly error messages for common missing tokens
    if kind == TokenKind.RPAREN {
        self.error("Missing RPAREN");
    } elif kind == TokenKind.RBRACE {
        self.error("Missing RBRACE");
    } elif kind == TokenKind.RSQUARE {
        self.error("Missing RSQUARE");
    } elif kind == TokenKind.SEMI {
        self.error("Missing SEMI");
    } elif kind == TokenKind.COMMA {
        self.error("Missing COMMA");
    } else {
        self.error(f"Expected {kind}, got {self.current().kind}");
        # Advance past the unexpected token to guarantee forward progress
        return self.advance();
    }
    return self.current();
}

impl Parser.consume_uni(kind: TokenKind) -> UniToken {
    # Consume a token via expect() and immediately return a UniToken
    # with the correct source position (avoids gen_token position bug)
    tok = self.expect(kind);
    return self.make_uni_token(tok);
}

impl Parser.error(message: str) {
    sloc = self.current().loc;
    self.errors.append(ParseError(message=message, loc=sloc));
    # Propagate to prog.errors_had as Alert if prog is available
    if self.prog is not None and hasattr(self.prog, "errors_had") {
        source = self.get_source();
        tok = UniToken(
            orig_src=source,
            name="ERROR",
            value="",
            line=sloc.line,
            end_line=sloc.end_line,
            col_start=sloc.col_start,
            col_end=sloc.col_end,
            pos_start=sloc.pos_start,
            pos_end=sloc.pos_end
        );
        loc = CodeLocInfo(tok, tok);
        alrt = Alert(message, loc, Parser);
        self.prog.errors_had.append(alrt);
    }
}

impl Parser.error_at(message: str, loc: SourceLoc) {
    self.errors.append(ParseError(message=message, loc=loc));
    if self.prog is not None and hasattr(self.prog, "errors_had") {
        source = self.get_source();
        tok = UniToken(
            orig_src=source,
            name="ERROR",
            value="",
            line=loc.line,
            end_line=loc.end_line,
            col_start=loc.col_start,
            col_end=loc.col_end,
            pos_start=loc.pos_start,
            pos_end=loc.pos_end
        );
        code_loc = CodeLocInfo(tok, tok);
        alrt = Alert(message, code_loc, Parser);
        self.prog.errors_had.append(alrt);
    }
}

impl Parser.warn_at(message: str, loc: SourceLoc) {
    if self.prog is not None and hasattr(self.prog, "warnings_had") {
        source = self.get_source();
        tok = UniToken(
            orig_src=source,
            name="WARNING",
            value="",
            line=loc.line,
            end_line=loc.end_line,
            col_start=loc.col_start,
            col_end=loc.col_end,
            pos_start=loc.pos_start,
            pos_end=loc.pos_end
        );
        code_loc = CodeLocInfo(tok, tok);
        alrt = Alert(message, code_loc, Parser);
        self.prog.warnings_had.append(alrt);
    }
}

impl Parser.check_name -> bool {
    # Check for NAME or KWESC_NAME (keyword-escaped identifier like `type)
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
        TokenKind.KW_INIT,
        TokenKind.KW_POST_INIT,
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

impl Parser.make_uni_token(tok: Token) -> UniToken {
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
    # Strip backtick prefix from keyword-escaped names
    val = tok.value;
    kwesc = False;
    if val.startswith("`") {
        val = val[1:];
        kwesc = True;
    } elif tok.kind == TokenKind.KWESC_NAME {
        kwesc = True;
    }
    # Reject Python/JS keywords that are not valid Jac identifiers
    if val == "pass" {
        self.error("'pass' keyword is not allowed in Jac");
        self.error("Jac does not allow this keyword in any syntactic position");
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
        is_enum_stmt=is_enum_stmt,
        is_kwesc=kwesc
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
        colon_uni = self.make_uni_token(self.previous());
        if self.check_any(TokenKind.KW_PUB, TokenKind.KW_PRIV, TokenKind.KW_PROT) {
            access_tok = self.advance();
            return SubTag(
                tag=(at := self.make_uni_token(access_tok)), kid=[colon_uni, at]
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
    # Generate a synthetic token for kid list construction.
    # Uses previous token position as approximation. Marks as synthetic
    # via _is_synthetic flag so downstream passes can distinguish from real tokens.
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
    tok = UniToken(
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
    tok._is_synthetic = True;
    return tok;
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
            TokenKind.KW_INCLUDE,
            TokenKind.KW_RETURN,
            TokenKind.KW_TEST,
            TokenKind.KW_GLOBAL,
            TokenKind.KW_IMPL,
            TokenKind.KW_ABSTRACT,
            TokenKind.KW_ASYNC,
            TokenKind.KW_WITH,
            TokenKind.KW_TRY,
            TokenKind.KW_PUB,
            TokenKind.KW_PRIV,
            TokenKind.KW_PROT,
            TokenKind.DECOR_OP,
            TokenKind.RBRACE,
            TokenKind.SEMI
        ) {
            return;
        }
        self.advance();
    }
}

impl Parser.parse -> Module {
    self._tokens_len = len(self.tokens);
    return self.parse_module();
}

impl Parser.parse_module -> Module {
    self.source = Source(self.source_code, self.file_path);
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
        before = self.pos;
        stmt = self.parse_element_stmt();
        if stmt is not None {
            body.append(stmt);
        }
        # Guard: ensure forward progress to prevent infinite loops
        if self.pos == before and not self.at_end() {
            self.advance();
        }
    }
    kid: list = [];
    if doc {
        kid.append(doc);
    }
    kid.extend(body);
    if len(kid) == 0 {
        kid.append(EmptyToken(orig_src=self.source));
    }
    mod_name = self.file_path;
    if mod_name {
        from
        pathlib
        import Path as _Path;
        _p = _Path(mod_name);
        # Use stem without .jac extension, e.g. "getme.impl" from "getme.impl.jac"
        mod_name = _p.name[:-4] if _p.name.endswith('.jac') else _p.stem;
    }
    module = Module(
        name=mod_name,
        source=self.get_source(),
        doc=doc,
        body=body,
        terminals=terminals,
        kid=kid
    );
    # Populate _in_mod_nodes with all unique nodes in the tree
    # (replicates old Lark parser's node_list behavior)
    node_list: list = [];
    seen: dict = {};
    stack: list = [module];
    while stack {
        nd = stack.pop();
        nid = id(nd);
        if nid not in seen {
            seen[nid] = True;
            node_list.append(nd);
            if hasattr(nd, "kid") {
                for child in nd.kid {
                    stack.append(child);
                }
            }
        }
    }
    module._in_mod_nodes = node_list;
    return module;
}

impl Parser.parse_expression -> Expr {
    if self.check(TokenKind.KW_LAMBDA) {
        return self.parse_lambda_expr();
    }
    expr = self.parse_concurrent_expr();
    if self.match_tok(TokenKind.KW_IF) {
        if_uni = self.make_uni_token(self.previous());
        condition = self.parse_expression();
        else_uni = self.consume_uni(TokenKind.KW_ELSE);
        else_value = self.parse_expression();
        return IfElseExpr(
            condition=condition,
            value=expr,
            else_value=else_value,
            kid=[expr, if_uni, condition, else_uni, else_value]
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
        by_uni = self.make_uni_token(self.previous());
        right = self.parse_by_expr();
        return BinaryExpr(left=left, op=by_uni, right=right, kid=[left, by_uni, right]);
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
        dir = EdgeDir.OUT
        if tok.kind == TokenKind.ARROW_R
        else EdgeDir.IN if tok.kind == TokenKind.ARROW_L else EdgeDir.ANY;
        return EdgeOpRef(filter_cond=None, edge_dir=dir, kid=[edge_op]);
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
        return EdgeOpRef(filter_cond=None, edge_dir=EdgeDir.OUT, kid=kid);
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
        return EdgeOpRef(filter_cond=None, edge_dir=EdgeDir.IN, kid=kid);
    }
    return None;
}

"""Parse connect operator (++>, <++, <++>, +>:Type:+>, etc.) or disconnect (del -->)."""
impl Parser.parse_connect_op -> ConnectOp | DisconnectOp | None {
    # Check for disconnect: del followed by edge_op_ref (-->, <--, <-->, or typed variants)
    if self.check(TokenKind.KW_DELETE)
    and self.check_peek_any(
        TokenKind.ARROW_R,
        TokenKind.ARROW_L,
        TokenKind.ARROW_BI,
        TokenKind.ARROW_R_P1,
        TokenKind.ARROW_L_P1
    ) {
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
            kid.append(self.make_uni_token(self.previous()));
            # Parse kw_expr_list for conn_assign
            assigns: list = [];
            ac_kid: list = [];
            while not self.check(TokenKind.CARROW_R_P2) and not self.at_end() {
                key_expr = self.parse_expression();
                if self.match_tok(TokenKind.EQ) {
                    eq_uni = self.make_uni_token(self.previous());
                    val_expr = self.parse_expression();
                    item = KWPair(
                        key=key_expr, value=val_expr, kid=[key_expr, eq_uni, val_expr]
                    );
                } else {
                    item = key_expr;
                }
                assigns.append(item);
                ac_kid.append(item);
                if not self.match_tok(TokenKind.COMMA) {
                    break;
                }
                ac_kid.append(self.make_uni_token(self.previous()));
            }
            if assigns {
                conn_assign = AssignCompr(assigns=assigns, kid=ac_kid);
                kid.append(conn_assign);
            }
        }
        end_uni = self.consume_uni(TokenKind.CARROW_R_P2);
        kid.append(end_uni);
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
            kid.append(self.make_uni_token(self.previous()));
            assigns: list = [];
            ac_kid: list = [];
            while not self.check_any(TokenKind.CARROW_L_P2, TokenKind.CARROW_R_P2)
            and not self.at_end() {
                key_expr = self.parse_expression();
                if self.match_tok(TokenKind.EQ) {
                    eq_uni = self.make_uni_token(self.previous());
                    val_expr = self.parse_expression();
                    item = KWPair(
                        key=key_expr, value=val_expr, kid=[key_expr, eq_uni, val_expr]
                    );
                } else {
                    item = key_expr;
                }
                assigns.append(item);
                ac_kid.append(item);
                if not self.match_tok(TokenKind.COMMA) {
                    break;
                }
                ac_kid.append(self.make_uni_token(self.previous()));
            }
            if assigns {
                conn_assign = AssignCompr(assigns=assigns, kid=ac_kid);
                kid.append(conn_assign);
            }
        }
        # Check if it's <+:Type:<+ (IN) or <+:Type:+> (ANY)
        if self.match_tok(TokenKind.CARROW_L_P2) {
            kid.append(self.make_uni_token(self.previous()));
            return ConnectOp(
                conn_type=conn_type,
                conn_assign=conn_assign,
                edge_dir=EdgeDir.IN,
                kid=kid
            );
        } elif self.match_tok(TokenKind.CARROW_R_P2) {
            kid.append(self.make_uni_token(self.previous()));
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
        or (
            self.check(TokenKind.NULL_OK)
            and not self.check_peek(TokenKind.LSQUARE)
            and self.match_tok(TokenKind.NULL_OK)
        )
        or self.match_tok(TokenKind.DOT_FWD)
        or self.match_tok(TokenKind.DOT_BKWD) {
            first_consumed_tok = self.previous();
            dot_kind = first_consumed_tok.kind;
            null_ok = dot_kind == TokenKind.NULL_OK;
            is_dot_fwd = dot_kind == TokenKind.DOT_FWD;
            is_dot_bkwd = dot_kind == TokenKind.DOT_BKWD;
            null_ok_uni: UniToken | None = None;
            dot_uni: UniToken | None = None;
            if null_ok {
                null_ok_uni = self.make_uni_token(first_consumed_tok);
            } else {
                dot_uni = self.make_uni_token(first_consumed_tok);
            }
            if null_ok
            and self.check_any(TokenKind.DOT, TokenKind.DOT_FWD, TokenKind.DOT_BKWD) {
                dot_kind2 = self.current().kind;
                is_dot_fwd = dot_kind2 == TokenKind.DOT_FWD;
                is_dot_bkwd = dot_kind2 == TokenKind.DOT_BKWD;
                dot_uni = self.make_uni_token(self.advance());
            }
            if not dot_uni and null_ok {
                dot_uni = null_ok_uni;
            }
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
            if not attr {
                # No attribute after dot (e.g. foo.) - create placeholder for LSP completion
                dot_tok = first_consumed_tok;
                attr = Name(
                    orig_src=self.get_source(),
                    name=Tok.NAME.value,
                    value="",
                    line=dot_tok.loc.end_line,
                    end_line=dot_tok.loc.end_line,
                    col_start=dot_tok.loc.col_end,
                    col_end=dot_tok.loc.col_end,
                    pos_start=dot_tok.loc.pos_end,
                    pos_end=dot_tok.loc.pos_end
                );
            }
            kid: list = [expr];
            if null_ok and null_ok_uni {
                kid.append(null_ok_uni);
            }
            kid.append(dot_uni);
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
        } elif self.check(TokenKind.LPAREN) {
            # Check if this is filter_compr: (?...) or (?:Type, ...)
            if self.check_peek(TokenKind.NULL_OK) {
                # Parse filter comprehension: (?val==10) or (?:Type, val==10)
                self.advance();  # consume LPAREN
                filter_expr = self.parse_filter_compr_inner();
                # Wrap in AtomTrailer
                kid = [expr, filter_expr];
                expr = AtomTrailer(
                    target=expr,
                    right=filter_expr,
                    is_attr=False,
                    is_null_ok=False,
                    kid=kid
                );
            } elif self.check_peek(TokenKind.EQ) {
                # Parse assign_compr: (=a=5, b=6)
                self.advance();  # consume LPAREN
                assign_expr = self.parse_assign_compr_inner();
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
                lp_uni = self.make_uni_token(self.advance());  # consume LPAREN
                kid = [expr, lp_uni];
                args = self.parse_call_args(kid);
                rp_uni = self.consume_uni(TokenKind.RPAREN);
                kid.append(rp_uni);
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
        } elif (self.check(TokenKind.NULL_OK) and self.check_peek(TokenKind.LSQUARE))
        or self.check(TokenKind.LSQUARE) {
            # Parse index or slice: a[x], a?[x], a[x,y], a[1:2], a[::3], etc.
            is_null_ok_index = False;
            null_ok_idx_uni: UniToken | None = None;
            if self.match_tok(TokenKind.NULL_OK) {
                is_null_ok_index = True;
                null_ok_idx_uni = self.make_uni_token(self.previous());
            }
            lsq_uni = self.consume_uni(TokenKind.LSQUARE);
            # First, parse optional first expression
            first_expr: UniNode | None = None;
            if not self.check_any(TokenKind.RSQUARE, TokenKind.COLON) {
                first_expr = self.parse_expression();
            }
            if self.check(TokenKind.COLON) {
                # Slice expression: expr? COLON expr? (COLON expr?)?
                # (COMMA expr? COLON expr? (COLON expr?)?)*
                slice_kid: list = [lsq_uni];
                slices: list = [];
                if first_expr is not None {
                    slice_kid.append(first_expr);
                }
                colon1_uni = self.consume_uni(TokenKind.COLON);
                slice_kid.append(colon1_uni);
                stop: UniNode | None = None;
                if not self.check_any(
                    TokenKind.COLON, TokenKind.RSQUARE, TokenKind.COMMA
                ) {
                    stop = self.parse_expression();
                    slice_kid.append(stop);
                }
                step: UniNode | None = None;
                if self.match_tok(TokenKind.COLON) {
                    slice_kid.append(self.make_uni_token(self.previous()));
                    if not self.check_any(TokenKind.RSQUARE, TokenKind.COMMA) {
                        step = self.parse_expression();
                        slice_kid.append(step);
                    }
                }
                slices.append(IndexSlice.Slice(start=first_expr, stop=stop, step=step));
                while self.match_tok(TokenKind.COMMA) {
                    slice_kid.append(self.make_uni_token(self.previous()));
                    s2: UniNode | None = None;
                    if not self.check(TokenKind.COLON) {
                        s2 = self.parse_expression();
                        slice_kid.append(s2);
                    }
                    colon_s2_uni = self.consume_uni(TokenKind.COLON);
                    slice_kid.append(colon_s2_uni);
                    e2: UniNode | None = None;
                    if not self.check_any(
                        TokenKind.COLON, TokenKind.RSQUARE, TokenKind.COMMA
                    ) {
                        e2 = self.parse_expression();
                        slice_kid.append(e2);
                    }
                    t2: UniNode | None = None;
                    if self.match_tok(TokenKind.COLON) {
                        slice_kid.append(self.make_uni_token(self.previous()));
                        if not self.check_any(TokenKind.RSQUARE, TokenKind.COMMA) {
                            t2 = self.parse_expression();
                            slice_kid.append(t2);
                        }
                    }
                    slices.append(IndexSlice.Slice(start=s2, stop=e2, step=t2));
                }
                rsq_uni = self.consume_uni(TokenKind.RSQUARE);
                slice_kid.append(rsq_uni);
                index_slice = IndexSlice(slices=slices, is_range=True, kid=slice_kid);
                kid = [expr];
                if is_null_ok_index and null_ok_idx_uni {
                    kid.append(null_ok_idx_uni);
                }
                kid.append(index_slice);
                expr = AtomTrailer(
                    target=expr,
                    right=index_slice,
                    is_attr=False,
                    is_null_ok=is_null_ok_index,
                    kid=kid
                );
            } else {
                # Regular index access: a[x] or a[x, y, ...]
                indices: list = [];
                list_kid: list = [lsq_uni];
                if first_expr is not None {
                    indices.append(first_expr);
                    list_kid.append(first_expr);
                    while self.match_tok(TokenKind.COMMA) {
                        list_kid.append(self.make_uni_token(self.previous()));
                        if self.check(TokenKind.RSQUARE) {
                            break;
                        }
                        idx = self.parse_expression();
                        indices.append(idx);
                        list_kid.append(idx);
                    }
                }
                rsq_idx_uni = self.consume_uni(TokenKind.RSQUARE);
                list_kid.append(rsq_idx_uni);
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
                kid = [expr];
                if is_null_ok_index and null_ok_idx_uni {
                    kid.append(null_ok_idx_uni);
                }
                kid.append(index_slice);
                expr = AtomTrailer(
                    target=expr,
                    right=index_slice,
                    is_attr=False,
                    is_null_ok=is_null_ok_index,
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
    # If current token clearly cannot start an argument, return empty
    # so that the caller's expect(RPAREN) generates "Missing RPAREN"
    if self.check(TokenKind.SEMI) or self.check(TokenKind.RBRACE) {
        return args;
    }
    arg = self.parse_call_arg();
    args.append(arg);
    kid.append(arg);
    while self.match_tok(TokenKind.COMMA) {
        kid.append(self.make_uni_token(self.previous()));
        if self.check(TokenKind.RPAREN) {
            break;
        }
        arg = self.parse_call_arg();
        args.append(arg);
        kid.append(arg);
    }
    # Check for missing comma between arguments
    if not self.check(TokenKind.RPAREN) and not self.at_end() {
        self.error("Missing COMMA");
        self.error("Unexpected token");
        # Skip to RPAREN or end to recover
        while not self.check(TokenKind.RPAREN) and not self.at_end() {
            self.advance();
        }
    }
    return args;
}

impl Parser.parse_call_arg -> Expr | KWPair {
    # Check for keyword argument: NAME = expr (also KWESC_NAME like `type)
    if (self.check_name() or self.is_keyword_token()) and self.check_peek(TokenKind.EQ) {
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
        eq_uni = self.make_uni_token(self.advance());  # consume '='
        value = self.parse_expression();
        return KWPair(key=name, value=value, kid=[name, eq_uni, value]);
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
    # If followed by 'for' or 'async for', it's a generator expression: all(x > 0 for x in items)
    if self.check(TokenKind.KW_FOR)
    or (self.check(TokenKind.KW_ASYNC) and self.check_peek(TokenKind.KW_FOR)) {
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
    #             | LPAREN NULL_OK COLON expression (COMMA filter_compare_list)? RPAREN
    # Note: LPAREN was already consumed by caller, use self.previous() for it
    lp_uni = self.make_uni_token(self.previous());
    kid: list = [lp_uni];
    f_type = None;
    # Consume ? (NULL_OK)
    null_ok_uni = self.consume_uni(TokenKind.NULL_OK);
    kid.append(null_ok_uni);
    # Check for typed variant: (?:Type, ...)
    if self.match_tok(TokenKind.COLON) {
        kid.append(self.make_uni_token(self.previous()));
        f_type = self.parse_expression();
        kid.append(f_type);
    }
    # Parse filter_compare_list (separated by commas)
    compares: list = [];
    # After f_type, consume comma separator before comparisons
    if f_type and self.match_tok(TokenKind.COMMA) {
        kid.append(self.make_uni_token(self.previous()));
    }
    if not self.check(TokenKind.RPAREN) {
        # Parse comparison: expr cmp_op expr
        comp = self.parse_compare();
        compares.append(comp);
        kid.append(comp);
        while self.match_tok(TokenKind.COMMA) {
            kid.append(self.make_uni_token(self.previous()));
            comp = self.parse_compare();
            compares.append(comp);
            kid.append(comp);
        }
    }
    rp_uni = self.consume_uni(TokenKind.RPAREN);
    kid.append(rp_uni);
    return FilterCompr(f_type=f_type, compares=compares, kid=kid);
}

impl Parser.parse_assign_compr_inner -> AssignCompr {
    # Parse inner part of assign_compr after LPAREN is consumed
    # assign_compr: LPAREN EQ kw_expr_list RPAREN
    # Note: LPAREN was already consumed by caller, use self.previous() for it
    lp_uni = self.make_uni_token(self.previous());
    kid: list = [lp_uni];
    eq_lead_uni = self.consume_uni(TokenKind.EQ);  # consume the leading =
    kid.append(eq_lead_uni);
    assigns: list = [];
    # Parse kw_expr_list: name=expr, name=expr, ...
    if not self.check(TokenKind.RPAREN) {
        name_tok = self.expect_name();
        name = self.make_name(name_tok);
        eq_uni = self.consume_uni(TokenKind.EQ);
        value = self.parse_expression();
        kw = KWPair(key=name, value=value, kid=[name, eq_uni, value]);
        assigns.append(kw);
        kid.append(kw);
        while self.match_tok(TokenKind.COMMA) {
            kid.append(self.make_uni_token(self.previous()));
            if self.check(TokenKind.RPAREN) {
                break;
            }
            name_tok = self.expect_name();
            name = self.make_name(name_tok);
            eq_uni2 = self.consume_uni(TokenKind.EQ);
            value = self.parse_expression();
            kw = KWPair(key=name, value=value, kid=[name, eq_uni2, value]);
            assigns.append(kw);
            kid.append(kw);
        }
    }
    rp_uni = self.consume_uni(TokenKind.RPAREN);
    kid.append(rp_uni);
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
            TokenKind.F_TSQ_START,
            TokenKind.RF_DQ_START,
            TokenKind.RF_SQ_START,
            TokenKind.RF_TDQ_START,
            TokenKind.RF_TSQ_START
        )
        or (
            self.check(TokenKind.NAME)
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
            and self.check_peek(TokenKind.STRING)
        ) {
            if self.check(TokenKind.NAME) and self.check_peek(TokenKind.STRING) {
                ptok = self.advance();
                stok = self.advance();
                s = self.make_string(stok);
                s.value = ptok.value + s.value;
                strings.append(s);
            } elif self.check(TokenKind.STRING) {
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
    if self.check_any(
        TokenKind.KW_SELF,
        TokenKind.KW_SUPER,
        TokenKind.KW_HERE,
        TokenKind.KW_ROOT,
        TokenKind.KW_VISITOR,
        TokenKind.KW_PROPS,
        TokenKind.KW_INIT,
        TokenKind.KW_POST_INIT
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
    and self.check_peek(TokenKind.STRING) {
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
            TokenKind.F_TSQ_START,
            TokenKind.RF_DQ_START,
            TokenKind.RF_SQ_START,
            TokenKind.RF_TDQ_START,
            TokenKind.RF_TSQ_START
        )
        or (
            self.check(TokenKind.NAME)
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
            and self.check_peek(TokenKind.STRING)
        ) {
            if self.check(TokenKind.NAME) and self.check_peek(TokenKind.STRING) {
                ptok = self.advance();
                stok = self.advance();
                s = self.make_string(stok);
                s.value = ptok.value + s.value;
                strings.append(s);
            } elif self.check(TokenKind.STRING) {
                tok = self.advance();
                strings.append(self.make_string(tok));
            } else {
                strings.append(self.parse_fstring());
            }
        }
        return MultiString(strings=strings, kid=strings);
    }
    if self.check(TokenKind.NAME) or self.check(TokenKind.KWESC_NAME) {
        # Reject JS-style 'new' keyword (e.g., new Foo()) — only when followed by a name
        # Allow 'new' as a regular variable name (e.g., new = out(), new.cnt)
        if self.check(TokenKind.NAME)
        and self.current().value == "new"
        and self.check_peek_any(TokenKind.NAME, TokenKind.KWESC_NAME) {
            self.error("The 'new' keyword is not supported in Jac");
            self.error(
                "Use `Reflect.construct(target, argumentsList)` method to create new instances"
            );
        }
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
        lp_uni = self.make_uni_token(self.previous());
        if self.check(TokenKind.RPAREN) {
            rp_uni = self.make_uni_token(self.advance());
            return TupleVal(values=[], kid=[lp_uni, rp_uni]);
        }
        # Parenthesized yield expression: (yield expr) or (yield from expr)
        if self.check(TokenKind.KW_YIELD) {
            yield_expr = self.parse_yield_stmt();
            rp_uni = self.consume_uni(TokenKind.RPAREN);
            return AtomUnit(value=yield_expr, kid=[lp_uni, yield_expr, rp_uni]);
        }
        # IIFE: (def func_name(params) { body })(args)
        if self.check_any(TokenKind.KW_DEF, TokenKind.KW_CAN, TokenKind.KW_ASYNC) {
            func_def = self.parse_ability();
            rp_uni = self.consume_uni(TokenKind.RPAREN);
            return AtomUnit(value=func_def, kid=[lp_uni, func_def, rp_uni]);
        }
        expr = self.parse_expression();
        # Standalone generator expression: (expr for x in items) or (expr async for x in items)
        if self.check(TokenKind.KW_FOR)
        or (self.check(TokenKind.KW_ASYNC) and self.check_peek(TokenKind.KW_FOR)) {
            comprs = self.parse_comprehension_clauses();
            gc_kid: list = [lp_uni, expr];
            gc_kid.extend(comprs);
            rp_uni = self.consume_uni(TokenKind.RPAREN);
            gc_kid.append(rp_uni);
            return GenCompr(out_expr=expr, compr=comprs, kid=gc_kid);
        }
        if self.match_tok(TokenKind.COMMA) {
            first_comma_uni = self.make_uni_token(self.previous());
            values = [expr];
            comma_unis: list = [first_comma_uni];
            trailing_comma = True;
            while not self.check(TokenKind.RPAREN) and not self.at_end() {
                values.append(self.parse_expression());
                if self.match_tok(TokenKind.COMMA) {
                    comma_unis.append(self.make_uni_token(self.previous()));
                    trailing_comma = True;
                } else {
                    trailing_comma = False;
                    break;
                }
            }
            rp_uni = self.consume_uni(TokenKind.RPAREN);
            kid: list = [lp_uni];
            comma_idx = 0;
            for (i, v) in enumerate(values) {
                kid.append(v);
                if i < len(values) - 1 and comma_idx < len(comma_unis) {
                    kid.append(comma_unis[comma_idx]);
                    comma_idx += 1;
                }
            }
            if trailing_comma and comma_idx < len(comma_unis) {
                kid.append(comma_unis[comma_idx]);
            }
            kid.append(rp_uni);
            return TupleVal(values=values, kid=kid);
        }
        rp_uni = self.consume_uni(TokenKind.RPAREN);
        return AtomUnit(value=expr, kid=[lp_uni, expr, rp_uni]);
    }
    if self.match_tok(TokenKind.LSQUARE) {
        # Check if this is an edge reference chain [-->], [<--], [<-->], [->:a:->], etc.
        # Note: [[<--]-->] is handled by parse_edge_ref_chain when it parses the start expression
        is_edge_ref = False;
        if self.check_any(
            TokenKind.ARROW_R,
            TokenKind.ARROW_L,
            TokenKind.ARROW_BI,
            TokenKind.ARROW_R_P1,
            TokenKind.ARROW_L_P1,
            TokenKind.RETURN_HINT,  # For typed edges like [->:a:->]
            TokenKind.KW_ASYNC
        ) {
            is_edge_ref = True;
        } elif self.check_any(TokenKind.KW_NODE, TokenKind.KW_EDGE) {
            # [node ...] or [edge ...] is only an edge ref if followed by an arrow
            if self.check_peek_any(
                TokenKind.ARROW_R,
                TokenKind.ARROW_L,
                TokenKind.ARROW_BI,
                TokenKind.ARROW_R_P1,
                TokenKind.ARROW_L_P1,
                TokenKind.RETURN_HINT,
                TokenKind.NAME,
                TokenKind.KW_ROOT,
                TokenKind.KW_SELF,
                TokenKind.KW_HERE,
                TokenKind.KW_SUPER,
                TokenKind.KW_VISITOR
            ) {
                is_edge_ref = True;
            }
        } elif self.check_any(
            TokenKind.NAME,
            TokenKind.KW_ROOT,
            TokenKind.KW_SELF,
            TokenKind.KW_HERE,
            TokenKind.KW_SUPER,
            TokenKind.KW_VISITOR
        ) {
            if self.check_peek_any(
                TokenKind.ARROW_R,
                TokenKind.ARROW_L,
                TokenKind.ARROW_BI,
                TokenKind.ARROW_R_P1,  # For typed edges like [self->:Type:->]
                TokenKind.ARROW_L_P1,  # For typed edges like [self<-:Type:<-]
                TokenKind.RETURN_HINT  # For [root->:a:->]
            ) {
                is_edge_ref = True;
            } elif self.check_peek(TokenKind.LSQUARE) {
                # Check for NAME[subscript]->... pattern (e.g., [parent[0]->:Edge:->])
                save_pos = self.pos;
                self.advance();  # skip NAME
                self.advance();  # skip [
                depth = 1;
                while depth > 0 and not self.at_end() {
                    if self.check(TokenKind.LSQUARE) {
                        depth += 1;
                    } elif self.check(TokenKind.RSQUARE) {
                        depth -= 1;
                    }
                    self.advance();
                }
                # Check if followed by arrow token
                is_edge_ref = self.check_any(
                    TokenKind.ARROW_R,
                    TokenKind.ARROW_L,
                    TokenKind.ARROW_BI,
                    TokenKind.ARROW_R_P1,
                    TokenKind.ARROW_L_P1,
                    TokenKind.RETURN_HINT
                );
                self.pos = save_pos;
            }
        }
        if is_edge_ref {
            return self.parse_edge_ref_chain();
        }
        return self.parse_list_or_compr();
    }
    if self.match_tok(TokenKind.LBRACE) {
        return self.parse_dict_or_set();
    }
    # F-string parsing (including raw f-strings rf"...")
    if self.check_any(
        TokenKind.F_DQ_START,
        TokenKind.F_SQ_START,
        TokenKind.F_TDQ_START,
        TokenKind.F_TSQ_START,
        TokenKind.RF_DQ_START,
        TokenKind.RF_SQ_START,
        TokenKind.RF_TDQ_START,
        TokenKind.RF_TSQ_START
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
            TokenKind.F_TSQ_START,
            TokenKind.RF_DQ_START,
            TokenKind.RF_SQ_START,
            TokenKind.RF_TDQ_START,
            TokenKind.RF_TSQ_START
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
    } elif start_tok.kind == TokenKind.F_TSQ_START {
        end_kind = TokenKind.F_TSQ_END;
        text_kind = TokenKind.F_TEXT_TSQ;
    } elif start_tok.kind == TokenKind.RF_DQ_START {
        end_kind = TokenKind.F_DQ_END;
        text_kind = TokenKind.F_TEXT_DQ;
    } elif start_tok.kind == TokenKind.RF_SQ_START {
        end_kind = TokenKind.F_SQ_END;
        text_kind = TokenKind.F_TEXT_SQ;
    } elif start_tok.kind == TokenKind.RF_TDQ_START {
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
            lbrace_uni = self.make_uni_token(self.previous());
            expr = self.parse_expression();
            conv = -1;
            fv_kid: list = [lbrace_uni, expr];
            # Handle conversion: !r, !s, !a
            if self.check(TokenKind.CONV) {
                conv_tok = self.advance();
                conv = ord(conv_tok.value[1]) if len(conv_tok.value) > 1 else -1;
                fv_kid.append(self.make_uni_token(conv_tok));
            }
            # Handle format spec: :format (may contain nested {expr} blocks)
            format_spec = None;
            if self.check(TokenKind.COLON) {
                self.advance();
                fv_kid.append(self.make_uni_token(self.previous()));
                # Collect format spec parts: plain text and nested {expr}
                spec_parts: list[str] = [];
                while not self.check(TokenKind.RBRACE) and not self.at_end() {
                    if self.match_tok(TokenKind.LBRACE) {
                        nested_lbrace_uni = self.make_uni_token(self.previous());
                        # Flush accumulated text as a String node
                        if spec_parts {
                            spec_text = "";
                            for sp in spec_parts {
                                spec_text += sp;
                            }
                            format_spec = self.make_string_from_value(spec_text);
                            fv_kid.append(format_spec);
                            spec_parts = [];
                        }
                        # Parse nested {expression} as a FormattedValue
                        nested_expr = self.parse_expression();
                        nested_conv = -1;
                        nested_fv_kid: list = [nested_lbrace_uni, nested_expr];
                        if self.check(TokenKind.CONV) {
                            nc_tok = self.advance();
                            nested_conv = ord(nc_tok.value[1])
                            if len(nc_tok.value) > 1
                            else -1;
                            nested_fv_kid.append(self.make_uni_token(nc_tok));
                        }
                        nested_fv_kid.append(self.consume_uni(TokenKind.RBRACE));
                        nested_fv = FormattedValue(
                            format_part=nested_expr,
                            conversion=nested_conv,
                            format_spec=None,
                            kid=nested_fv_kid
                        );
                        fv_kid.append(nested_fv);
                        format_spec = nested_fv;
                    } else {
                        spec_tok = self.advance();
                        spec_parts.append(spec_tok.value);
                    }
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
            fv_kid.append(self.consume_uni(TokenKind.RBRACE));
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
    lsquare_uni = self.make_uni_token(self.previous());
    if self.check(TokenKind.RSQUARE) {
        self.advance();
        return ListVal(
            values=[], kid=[lsquare_uni, self.make_uni_token(self.previous())]
        );
    }
    first = self.parse_expression();
    if self.check(TokenKind.KW_FOR)
    or (self.check(TokenKind.KW_ASYNC) and self.check_peek(TokenKind.KW_FOR)) {
        comprs = self.parse_comprehension_clauses();
        kid: list = [lsquare_uni, first];
        kid.extend(comprs);
        kid.append(self.consume_uni(TokenKind.RSQUARE));
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
        return self.continue_edge_ref_chain(first, lsquare_uni);
    }
    values = [first];
    kid = [lsquare_uni, first];
    while self.match_tok(TokenKind.COMMA) {
        kid.append(self.make_uni_token(self.previous()));
        if self.check(TokenKind.RSQUARE) {
            break;
        }
        val = self.parse_expression();
        values.append(val);
        kid.append(val);
    }
    kid.append(self.consume_uni(TokenKind.RSQUARE));
    return ListVal(values=values, kid=kid);
}

"""Continue parsing edge ref chain when start expression is already parsed."""
impl Parser.continue_edge_ref_chain(start_expr: Expr, lsquare_uni: UniToken) -> Expr {
    # Already consumed LSQUARE and parsed start_expr
    # This follows the same structure as parse_edge_ref_chain but with
    # an already-parsed starting expression.
    kid: list = [lsquare_uni, start_expr];
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
            end_uni = self.consume_uni(TokenKind.ARROW_R_P2);
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
            end_uni = self.consume_uni(TokenKind.ARROW_L_P2);
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
        # Check for filter expressions after edge operator: -->(?val==5) or -->(?:A)
        if self.check(TokenKind.LPAREN) {
            if self.check_peek(TokenKind.NULL_OK) {
                self.advance();
                filter_expr = self.parse_filter_compr_inner();
                chain.append(filter_expr);
                kid.append(filter_expr);
                # Note: parse_filter_compr_inner already consumes RPAREN
            } else {
                self.advance();
                kid.append(self.make_uni_token(self.previous()));
                filter_expr = self.parse_expression();
                chain.append(filter_expr);
                kid.append(filter_expr);
                kid.append(self.consume_uni(TokenKind.RPAREN));
            }
        }
    }
    kid.append(self.consume_uni(TokenKind.RSQUARE));
    return EdgeRefTrailer(chain=chain, edges_only=False, is_async=False, kid=kid);
}

impl Parser.parse_edge_ref_chain -> Expr {
    # Parse edge reference chain: [-->], [<--], [<-->], [root-->], [->:a:->], etc.
    # Already consumed LSQUARE
    kid: list = [self.make_uni_token(self.previous())];
    chain: list = [];
    is_async = False;
    edges_only = False;
    if self.match_tok(TokenKind.KW_ASYNC) {
        is_async = True;
        kid.append(self.make_uni_token(self.previous()));
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
        elif self.check(TokenKind.RETURN_HINT) and self.check_peek(TokenKind.COLON) {
            self.advance();  # ->
            arrow_r_tok = self.previous();
            self.advance();  # :
            start_uni = self.make_uni_token(arrow_r_tok);
            colon_uni = self.make_uni_token(self.previous());
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
                fcompr_kid.append(self.make_uni_token(self.previous()));
                if not self.check_any(TokenKind.ARROW_R_P2, TokenKind.ARROW_L_P2) {
                    cmp = self.parse_compare();
                    compares.append(cmp);
                    fcompr_kid.append(cmp);
                    while self.match_tok(TokenKind.COMMA) {
                        fcompr_kid.append(self.make_uni_token(self.previous()));
                        cmp = self.parse_compare();
                        compares.append(cmp);
                        fcompr_kid.append(cmp);
                    }
                }
            }
            fcond = FilterCompr(f_type=f_type, compares=compares, kid=fcompr_kid);
            # Expect closing :->
            end_uni = self.consume_uni(TokenKind.ARROW_R_P2);
            edge_op_ref = EdgeOpRef(
                filter_cond=fcond,
                edge_dir=EdgeDir.OUT,
                kid=[start_uni, colon_uni, fcond, end_uni]
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
                fcompr_kid.append(self.make_uni_token(self.previous()));
                if not self.check(TokenKind.ARROW_L_P2) {
                    cmp = self.parse_compare();
                    compares.append(cmp);
                    fcompr_kid.append(cmp);
                    while self.match_tok(TokenKind.COMMA) {
                        fcompr_kid.append(self.make_uni_token(self.previous()));
                        cmp = self.parse_compare();
                        compares.append(cmp);
                        fcompr_kid.append(cmp);
                    }
                }
            }
            fcond = FilterCompr(f_type=f_type, compares=compares, kid=fcompr_kid);
            end_uni = self.consume_uni(TokenKind.ARROW_L_P2);
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
            end_uni = self.consume_uni(TokenKind.ARROW_R_P2);
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
        # Check for filter expressions after edge operator: -->(?val==5) or -->(?:A)
        if self.check(TokenKind.LPAREN) {
            if self.check_peek(TokenKind.NULL_OK) {
                self.advance();
                filter_expr = self.parse_filter_compr_inner();
                chain.append(filter_expr);
                kid.append(filter_expr);
                # Note: parse_filter_compr_inner already consumes RPAREN
            } else {
                self.advance();
                kid.append(self.make_uni_token(self.previous()));
                filter_expr = self.parse_expression();
                chain.append(filter_expr);
                kid.append(filter_expr);
                kid.append(self.consume_uni(TokenKind.RPAREN));
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
    kid.append(self.consume_uni(TokenKind.RSQUARE));
    return EdgeRefTrailer(
        chain=chain, edges_only=edges_only, is_async=is_async, kid=kid
    );
}

impl Parser.parse_dict_or_set -> Expr {
    lbrace_uni = self.make_uni_token(self.previous());
    if self.check(TokenKind.RBRACE) {
        self.advance();
        return DictVal(
            kv_pairs=[], kid=[lbrace_uni, self.make_uni_token(self.previous())]
        );
    }
    # Check for dict spread: {**expr, ...}
    if self.check(TokenKind.STAR_POW) {
        return self.parse_dict_with_spread(lbrace_uni);
    }
    first = self.parse_expression();
    if self.match_tok(TokenKind.COLON) {
        colon_uni = self.make_uni_token(self.previous());
        value = self.parse_expression();
        if self.check(TokenKind.KW_FOR)
        or (self.check(TokenKind.KW_ASYNC) and self.check_peek(TokenKind.KW_FOR)) {
            comprs = self.parse_comprehension_clauses();
            kv = KVPair(key=first, value=value, kid=[first, colon_uni, value]);
            kid: list = [lbrace_uni, kv];
            kid.extend(comprs);
            kid.append(self.consume_uni(TokenKind.RBRACE));
            return DictCompr(kv_pair=kv, compr=comprs, kid=kid);
        }
        first_pair = KVPair(key=first, value=value, kid=[first, colon_uni, value]);
        pairs = [first_pair];
        kid: list = [lbrace_uni, first_pair];
        while self.match_tok(TokenKind.COMMA) {
            kid.append(self.make_uni_token(self.previous()));
            if self.check(TokenKind.RBRACE) {
                break;
            }
            if self.check(TokenKind.STAR_POW) {
                self.advance();
                star_pow_uni = self.make_uni_token(self.previous());
                spread_val = self.parse_expression();
                pair = KVPair(
                    key=None, value=spread_val, kid=[star_pow_uni, spread_val]
                );
            } else {
                key = self.parse_expression();
                kv_colon_uni = self.consume_uni(TokenKind.COLON);
                val = self.parse_expression();
                pair = KVPair(key=key, value=val, kid=[key, kv_colon_uni, val]);
            }
            pairs.append(pair);
            kid.append(pair);
        }
        kid.append(self.consume_uni(TokenKind.RBRACE));
        return DictVal(kv_pairs=pairs, kid=kid);
    }
    if self.check(TokenKind.KW_FOR)
    or (self.check(TokenKind.KW_ASYNC) and self.check_peek(TokenKind.KW_FOR)) {
        comprs = self.parse_comprehension_clauses();
        kid = [lbrace_uni, first];
        kid.extend(comprs);
        kid.append(self.consume_uni(TokenKind.RBRACE));
        return SetCompr(out_expr=first, compr=comprs, kid=kid);
    }
    values = [first];
    kid: list = [lbrace_uni, first];
    while self.match_tok(TokenKind.COMMA) {
        kid.append(self.make_uni_token(self.previous()));
        if self.check(TokenKind.RBRACE) {
            break;
        }
        val = self.parse_expression();
        values.append(val);
        kid.append(val);
    }
    kid.append(self.consume_uni(TokenKind.RBRACE));
    return SetVal(values=values, kid=kid);
}

impl Parser.parse_dict_with_spread(lbrace_uni: UniToken) -> DictVal {
    # Parse dict starting with **spread
    pairs: list = [];
    kid: list = [lbrace_uni];
    while not self.check(TokenKind.RBRACE) and not self.at_end() {
        if self.check(TokenKind.STAR_POW) {
            self.advance();
            star_pow_uni = self.make_uni_token(self.previous());
            spread_val = self.parse_expression();
            pair = KVPair(key=None, value=spread_val, kid=[star_pow_uni, spread_val]);
        } else {
            key = self.parse_expression();
            kv_colon_uni = self.consume_uni(TokenKind.COLON);
            val = self.parse_expression();
            pair = KVPair(key=key, value=val, kid=[key, kv_colon_uni, val]);
        }
        pairs.append(pair);
        kid.append(pair);
        if not self.match_tok(TokenKind.COMMA) {
            break;
        }
        kid.append(self.make_uni_token(self.previous()));
    }
    kid.append(self.consume_uni(TokenKind.RBRACE));
    return DictVal(kv_pairs=pairs, kid=kid);
}

impl Parser.parse_comprehension_clauses -> list {
    comprs: list = [];
    while self.check(TokenKind.KW_FOR)
    or (self.check(TokenKind.KW_ASYNC) and self.check_peek(TokenKind.KW_FOR)) {
        is_async = False;
        async_uni: UniToken | None = None;
        if self.match_tok(TokenKind.KW_ASYNC) {
            is_async = True;
            async_uni = self.make_uni_token(self.previous());
        }
        for_uni = self.consume_uni(TokenKind.KW_FOR);
        target = self.parse_atomic_chain();
        in_uni = self.consume_uni(TokenKind.KW_IN);
        iter_expr = self.parse_pipe_call();
        ifs: list = [];
        if_unis: list = [];
        while self.match_tok(TokenKind.KW_IF) {
            if_unis.append(self.make_uni_token(self.previous()));
            ifs.append(self.parse_walrus_assign());
        }
        kid: list = [];
        if async_uni {
            kid.append(async_uni);
        }
        kid.extend([for_uni, target, in_uni, iter_expr]);
        for i in range(len(ifs)) {
            kid.append(if_unis[i]);
            kid.append(ifs[i]);
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
    lambda_tok = self.consume_uni(TokenKind.KW_LAMBDA);
    # Build FuncSignature kid list
    sig_kid: list = [];
    if self.check(TokenKind.LPAREN) {
        # Parenthesized lambda params: lambda (x: int, y: str) -> ret { ... }
        self.advance();  # consume (
        sig_kid.append(self.make_uni_token(self.previous()));
        params = self.parse_func_params(sig_kid);
        sig_kid.append(self.consume_uni(TokenKind.RPAREN));
    } else {
        params = self.parse_lambda_params(sig_kid);
    }
    return_type = None;
    ret_hint_uni: UniToken | None = None;
    if self.match_tok(TokenKind.RETURN_HINT) {
        ret_hint_uni = self.make_uni_token(self.previous());
        return_type = self.parse_expression();
    }
    body: Expr | list;
    colon_uni: UniToken | None = None;
    lbrace_uni: UniToken | None = None;
    rbrace_uni: UniToken | None = None;
    if self.match_tok(TokenKind.COLON) {
        colon_uni = self.make_uni_token(self.previous());
        body = self.parse_expression();
    } elif self.match_tok(TokenKind.LBRACE) {
        lbrace_uni = self.make_uni_token(self.previous());
        body = self.parse_code_block_stmts();
        rbrace_uni = self.consume_uni(TokenKind.RBRACE);
    } else {
        self.error("Expected ':' or '{' after lambda parameters");
        body = self.parse_expression();
    }
    if return_type {
        sig_kid.append(ret_hint_uni);
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
        if colon_uni {
            kid.append(colon_uni);
        }
        kid.append(body);
    } else {
        if lbrace_uni {
            kid.append(lbrace_uni);
        }
        kid.extend(body);
        if rbrace_uni {
            kid.append(rbrace_uni);
        }
    }
    return LambdaExpr(body=body, kid=kid, signature=signature);
}

impl Parser.parse_lambda_params(sig_kid: list) -> list {
    params: list = [];
    while self.check_name()
    or self.is_keyword_token()
    or self.check_any(TokenKind.STAR_MUL, TokenKind.STAR_POW, TokenKind.DIV) {
        # Handle bare * (keyword-only separator)
        if self.check(TokenKind.STAR_MUL)
        and (
            self.check_peek(TokenKind.COMMA)
            or self.check_peek(TokenKind.COLON)
            or self.check_peek(TokenKind.RETURN_HINT)
            or self.check_peek(TokenKind.LBRACE)
        ) {
            star_tok = self.advance();
            star_uni = self.make_uni_token(star_tok);
            sig_kid.append(star_uni);
            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
            sig_kid.append(self.make_uni_token(self.previous()));
            continue;
        }
        # Handle / (positional-only separator)
        if self.check(TokenKind.DIV)
        and (
            self.check_peek(TokenKind.COMMA)
            or self.check_peek(TokenKind.COLON)
            or self.check_peek(TokenKind.RETURN_HINT)
            or self.check_peek(TokenKind.LBRACE)
        ) {
            div_tok = self.advance();
            div_uni = self.make_uni_token(div_tok);
            sig_kid.append(div_uni);
            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
            sig_kid.append(self.make_uni_token(self.previous()));
            continue;
        }
        # Handle *args or **kwargs
        unpack: UniToken | None = None;
        if self.check_any(TokenKind.STAR_MUL, TokenKind.STAR_POW) {
            unpack_tok = self.advance();
            unpack = self.make_uni_token(unpack_tok);
        }
        if not (self.check_name() or self.is_keyword_token()) {
            # No name follows - exit lambda params
            break;
        }
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
            next_tok = self.peek();
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
                after_type = self.peek(2);
                if after_type.kind in [
                    TokenKind.COMMA,
                    TokenKind.EQ,
                    TokenKind.COLON,
                    TokenKind.RETURN_HINT,
                    TokenKind.LBRACE
                ] {
                    is_type_annotation = True;
                }
            }
            if is_type_annotation {
                self.advance();  # consume COLON
                lam_colon = self.make_uni_token(self.previous());
                te = self.parse_pipe();
                type_tag = SubTag(tag=te, kid=[lam_colon, te]);
            }
        }
        default_val: Expr | None = None;
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
        pv = ParamVar(
            name=name, unpack=unpack, type_tag=type_tag, value=default_val, kid=kid
        );
        params.append(pv);
        sig_kid.append(pv);
        if not self.match_tok(TokenKind.COMMA) {
            break;
        }
        sig_kid.append(self.make_uni_token(self.previous()));
    }
    return params;
}

"""Parse a JSX element: <Tag>...</Tag> or <Tag /> or <>...</>"""
impl Parser.parse_jsx_element -> Expr {
    kid: list = [];
    # Check for fragment: <>...</>
    if self.check(TokenKind.JSX_FRAG_OPEN) {
        frag_open = self.advance();
        kid.append(self.make_uni_token(frag_open));
        children = self.parse_jsx_children();
        kid.extend(children);
        kid.append(self.consume_uni(TokenKind.JSX_FRAG_CLOSE));
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
    open_start_uni = self.consume_uni(TokenKind.JSX_OPEN_START);
    open_kid: list = [open_start_uni];
    # Parse tag name (may be dotted: UI.Button, Form.Input.Text)
    name_tok = self.expect(TokenKind.JSX_NAME);
    name = self.make_uni_token(name_tok);
    name_parts: list = [name];
    name_kid: list = [name];
    while self.match_tok(TokenKind.DOT) {
        name_kid.append(self.make_uni_token(self.previous()));
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
        open_kid.append(self.make_uni_token(self.previous()));
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
    open_kid.append(self.consume_uni(TokenKind.JSX_TAG_END));
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
    close_start_uni = self.consume_uni(TokenKind.JSX_CLOSE_START);
    close_kid: list = [close_start_uni];
    close_name_tok = self.expect(TokenKind.JSX_NAME);
    close_name_node = self.make_uni_token(close_name_tok);
    close_parts: list = [close_name_node];
    close_name_kid: list = [close_name_node];
    while self.match_tok(TokenKind.DOT) {
        close_name_kid.append(self.make_uni_token(self.previous()));
        cn_tok = self.expect(TokenKind.JSX_NAME);
        cn = self.make_uni_token(cn_tok);
        close_parts.append(cn);
        close_name_kid.append(cn);
    }
    close_elem_name = JsxElementName(parts=close_parts, kid=close_name_kid);
    close_kid.append(close_elem_name);
    close_kid.append(self.consume_uni(TokenKind.JSX_TAG_END));
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
                attr_kid.append(self.make_uni_token(self.previous()));
                # Check for string value or expression
                if self.check(TokenKind.STRING) {
                    str_tok = self.advance();
                    attr_value = self.make_string(str_tok);
                    attr_kid.append(attr_value);
                } elif self.check(TokenKind.LBRACE) {
                    self.advance();  # consume {
                    lbrace = self.make_uni_token(self.previous());
                    attr_value = self.parse_expression();
                    rbrace = self.consume_uni(TokenKind.RBRACE);
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
            spread_kid: list = [self.make_uni_token(self.previous())];
            if self.check(TokenKind.ELLIPSIS) {
                ellipsis_tok = self.advance();
                spread_kid.append(self.make_ellipsis(ellipsis_tok));
            }
            spread_expr = self.parse_expression();
            spread_kid.append(spread_expr);
            spread_kid.append(self.consume_uni(TokenKind.RBRACE));
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
    # Text content — store raw token; whitespace normalization is handled
    # downstream by JsxText.get_normalized_text() (single source of truth).
    if self.check(TokenKind.JSX_TEXT) {
        text_tok = self.advance();
        if not text_tok.value.strip() {
            # Whitespace-only text node, skip (structural decision)
            return self.parse_jsx_child();
        }
        text_node = self.make_uni_token(text_tok);
        return JsxText(value=text_node, kid=[text_node]);
    }
    # Expression: {expr}
    if self.check(TokenKind.LBRACE) {
        lbrace = self.advance();  # consume {
        lbrace_uni = self.make_uni_token(lbrace);
        expr = self.parse_expression();
        rbrace_uni = self.consume_uni(TokenKind.RBRACE);
        kid: list = [lbrace_uni, expr, rbrace_uni];
        return JsxExpression(expr=expr, kid=kid);
    }
    # Nested JSX element
    if self.check(TokenKind.JSX_OPEN_START) or self.check(TokenKind.JSX_FRAG_OPEN) {
        return self.parse_jsx_element();
    }
    # Nothing more to parse
    return None;
}

impl Parser.parse_element_stmt{
    while self.match_tok(TokenKind.SEMI) {
        continue;
    }
    if self.at_end() {
        return None;
    }
    # Handle client/server/native context blocks: cl { ... } or cl stmt
    if self.check(TokenKind.KW_CLIENT) {
        if self.check_peek(TokenKind.LBRACE) {
            return self.parse_client_block();
        } else {
            # Single statement: cl def ..., cl import ..., etc.
            self.advance();  # consume cl
            cl_tok = self.make_uni_token(self.previous());
            stmt = self.parse_element_stmt();
            if stmt is not None {
                stmt.add_kids_left([cl_tok]);
                if stmt?.code_context {
                    stmt.code_context = CodeContext.CLIENT;
                }
            }
            return stmt;
        }
    }
    if self.check(TokenKind.KW_SERVER) {
        if self.check_peek(TokenKind.LBRACE) {
            return self.parse_server_block();
        } else {
            self.advance();  # consume sv
            sv_tok = self.make_uni_token(self.previous());
            stmt = self.parse_element_stmt();
            if stmt is not None {
                stmt.add_kids_left([sv_tok]);
                if stmt?.code_context {
                    stmt.code_context = CodeContext.SERVER;
                }
            }
            return stmt;
        }
    }
    if self.check(TokenKind.KW_NATIVE) {
        if self.check_peek(TokenKind.LBRACE) {
            return self.parse_native_block();
        } else {
            self.advance();  # consume na
            na_tok = self.make_uni_token(self.previous());
            stmt = self.parse_element_stmt();
            if stmt is not None {
                stmt.add_kids_left([na_tok]);
                if stmt?.code_context {
                    stmt.code_context = CodeContext.NATIVE;
                }
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
        and self.check_peek_any(
            TokenKind.KW_OBJECT,
            TokenKind.KW_NODE,
            TokenKind.KW_EDGE,
            TokenKind.KW_WALKER,
            TokenKind.KW_CLASS
        )
    ) {
        return self.parse_archetype();
    }
    if self.check(TokenKind.KW_ENUM) {
        return self.parse_enum();
    }
    if self.check(TokenKind.STRING) and self.check_peek(TokenKind.KW_TEST) {
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
    and self.check_peek_any(
        TokenKind.KW_DEF,
        TokenKind.KW_CAN,
        TokenKind.KW_OVERRIDE,
        TokenKind.KW_STATIC,
        TokenKind.KW_ASYNC,
        TokenKind.DECOR_OP,
        TokenKind.KW_OBJECT,
        TokenKind.KW_NODE,
        TokenKind.KW_EDGE,
        TokenKind.KW_WALKER,
        TokenKind.KW_CLASS,
        TokenKind.KW_ABSTRACT,
        TokenKind.KW_IMPL
    ) {
        # Need to look ahead past decorators/async/abs to determine if ability, archetype, enum, or impl
        save_pos = self.pos;
        self.advance();  # skip STRING
        while self.check(TokenKind.DECOR_OP) {
            self.advance();
            self.parse_atomic_chain();
        }
        while self.check(TokenKind.KW_ASYNC) {
            self.advance();
        }
        if self.check(TokenKind.KW_ABSTRACT) {
            self.advance();
        }
        is_ability = self.check_any(TokenKind.KW_DEF, TokenKind.KW_CAN);
        is_archetype = self.check_any(
            TokenKind.KW_OBJECT,
            TokenKind.KW_NODE,
            TokenKind.KW_EDGE,
            TokenKind.KW_WALKER,
            TokenKind.KW_CLASS
        );
        is_enum = self.check(TokenKind.KW_ENUM);
        is_impl = self.check(TokenKind.KW_IMPL);
        self.pos = save_pos;
        doc_tok = self.advance();
        elem_doc = self.make_string(doc_tok);
        if is_archetype {
            arch = self.parse_archetype();
            arch.doc = elem_doc;
            arch.add_kids_left([elem_doc]);
            return arch;
        } elif is_enum {
            en = self.parse_enum();
            en.doc = elem_doc;
            en.add_kids_left([elem_doc]);
            return en;
        } elif is_impl {
            impl_def = self.parse_impl_def();
            impl_def.doc = elem_doc;
            impl_def.add_kids_left([elem_doc]);
            return impl_def;
        } else {
            ability = self.parse_ability();
            ability.doc = elem_doc;
            ability.add_kids_left([elem_doc]);
            return ability;
        }
    }
    if self.check(TokenKind.STRING) and self.check_peek(TokenKind.KW_ENUM) {
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
    if self.check(TokenKind.STRING) and self.check_peek(TokenKind.KW_GLOBAL) {
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
    if self.check(TokenKind.STRING) and self.check_peek(TokenKind.KW_IMPL) {
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
    if self.check(TokenKind.STRING) and self.check_peek(TokenKind.KW_WITH) {
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
        # Skip async if present
        while self.check(TokenKind.KW_ASYNC) {
            self.advance();
        }
        # Check for abs prefix - valid before archetypes, NOT before abilities
        has_abs_prefix = self.check(TokenKind.KW_ABSTRACT);
        if has_abs_prefix {
            self.advance();
        }
        # Now check what the decorated item is
        is_ability = self.check_any(TokenKind.KW_DEF, TokenKind.KW_CAN);
        is_enum = self.check(TokenKind.KW_ENUM);
        is_impl = self.check(TokenKind.KW_IMPL);
        self.pos = save_pos;  # Restore position
        if has_abs_prefix and is_ability {
            self.error(
                "'abs' is not a valid prefix for abilities (use 'abs' before archetype keywords only)"
            );
        }
        if is_ability and not has_abs_prefix {
            return self.parse_ability();
        } elif is_enum {
            return self.parse_enum();
        } elif is_impl {
            return self.parse_impl_def();
        } else {
            return self.parse_archetype();
        }
    }
    # Handle async prefix (abs is NOT a valid prefix per Lark grammar)
    if self.check(TokenKind.KW_ASYNC) {
        # Look ahead to see if it's an ability (def/can) or archetype (class/obj/etc)
        save_pos = self.pos;
        while self.check(TokenKind.KW_ASYNC) {
            self.advance();
        }
        is_ability = self.check_any(TokenKind.KW_DEF, TokenKind.KW_CAN);
        self.pos = save_pos;
        if is_ability {
            return self.parse_ability();
        }
        return self.parse_archetype();
    }
    self.error(f"Unexpected token '{self.current().value}'");
    self.synchronize();
    return EmptyToken();
}

"""Parse client block: cl { stmts } or cl stmt"""
impl Parser.parse_client_block -> ClientBlock {
    cl_tok = self.consume_uni(TokenKind.KW_CLIENT);
    kid: list = [cl_tok];
    body: list = [];
    if self.match_tok(TokenKind.LBRACE) {
        kid.append(self.make_uni_token(self.previous()));
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
        rb_uni = self.consume_uni(TokenKind.RBRACE);
        kid.append(rb_uni);
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
    sv_tok = self.consume_uni(TokenKind.KW_SERVER);
    kid: list = [sv_tok];
    body: list = [];
    if self.match_tok(TokenKind.LBRACE) {
        kid.append(self.make_uni_token(self.previous()));
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
        rb_uni = self.consume_uni(TokenKind.RBRACE);
        kid.append(rb_uni);
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

"""Parse native block: na { stmts } or na stmt"""
impl Parser.parse_native_block -> NativeBlock {
    na_tok = self.consume_uni(TokenKind.KW_NATIVE);
    kid: list = [na_tok];
    body: list = [];
    if self.match_tok(TokenKind.LBRACE) {
        kid.append(self.make_uni_token(self.previous()));
        while not self.check(TokenKind.RBRACE) and not self.at_end() {
            stmt = self.parse_element_stmt();
            if stmt is not None {
                body.append(stmt);
                kid.append(stmt);
                # Mark as native context
                if stmt?.code_context {
                    stmt.code_context = CodeContext.NATIVE;
                }
            }
        }
        rb_uni = self.consume_uni(TokenKind.RBRACE);
        kid.append(rb_uni);
    } else {
        stmt = self.parse_element_stmt();
        if stmt is not None {
            stmt.add_kids_left([na_tok]);
            return stmt;
        }
    }
    return NativeBlock(body=body, kid=kid);
}

impl Parser.parse_module_code -> ModuleCode {
    # Parse 'with entry { ... }' or 'with entry:__main__ { ... }'
    # Grammar: free_code: KW_WITH KW_ENTRY (COLON NAME)? code_block
    with_uni = self.consume_uni(TokenKind.KW_WITH);
    name = None;
    target_name = None;  # For :__main__ style target
    colon_uni = None;
    if self.check(TokenKind.KW_EXIT) {
        self.error("Module-level 'with' blocks only support 'entry', not 'exit'");
        name_tok = self.advance();
        name = self.make_uni_token(name_tok);
    } elif self.check(TokenKind.KW_ENTRY) {
        name_tok = self.advance();
        name = self.make_uni_token(name_tok);
    }
    # Check for optional :NAME after entry/exit (e.g., with entry:__main__)
    if self.match_tok(TokenKind.COLON) {
        colon_uni = self.make_uni_token(self.previous());
        target_tok = self.expect_name();
        target_name = self.make_name(target_tok);
    }
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    kid: list = [with_uni];
    if name {
        kid.append(name);
    }
    if target_name {
        kid.append(colon_uni);
        kid.append(target_name);
    }
    kid.append(lb_uni);
    kid.extend(body);
    kid.append(rb_uni);
    # Only use target_name (e.g. :__main__) as the name; entry/exit alone is not a name
    return ModuleCode(name=target_name, body=body, kid=kid, doc=None);
}

impl Parser.parse_code_block_stmts -> list {
    stmts: list = [];
    checked_first = False;
    while not self.check(TokenKind.RBRACE) and not self.at_end() {
        before = self.pos;
        stmt = self.parse_statement();
        if stmt is not None {
            # Reject Python-style docstrings as first statement in code block.
            # In Jac, semstrings go before the declaration, not inside.
            is_docstring = False;
            if (
                not checked_first
                and isinstance(stmt, ExprStmt)
                and not stmt.in_fstring
            ) {
                if isinstance(stmt.expr, String) {
                    is_docstring = True;
                } elif (
                    isinstance(stmt.expr, MultiString)
                    and all(isinstance(s, String) for s in stmt.expr.strings)
                ) {
                    is_docstring = True;
                }
            }
            if is_docstring {
                self.warn_at(
                    'Docstrings in Jac go before the declaration, not inside the body. ' + 'Move this string before the enclosing test/can/obj/etc.',
                    self.tokens[before].loc
                );
            }
            if not isinstance(stmt, Semi) {
                checked_first = True;
            }
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
        # Guard: ensure forward progress to prevent infinite loops
        if self.pos == before {
            self.advance();
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
    # Handle async for/with statements
    if self.check(TokenKind.KW_ASYNC) and self.check_peek(TokenKind.KW_FOR) {
        return self.parse_for_stmt();
    }
    if self.check(TokenKind.KW_ASYNC) and self.check_peek(TokenKind.KW_WITH) {
        return self.parse_with_stmt();
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
        break_uni = self.make_uni_token(self.previous());
        kid: list = [break_uni];
        if self.match_tok(TokenKind.SEMI) {
            kid.append(self.make_semi());
        }
        return CtrlStmt(ctrl=break_uni, kid=kid);
    }
    if self.check(TokenKind.KW_CONTINUE) {
        self.advance();
        cont_uni = self.make_uni_token(self.previous());
        kid: list = [cont_uni];
        if self.match_tok(TokenKind.SEMI) {
            kid.append(self.make_semi());
        }
        return CtrlStmt(ctrl=cont_uni, kid=kid);
    }
    if self.check(TokenKind.KW_SKIP) {
        self.advance();
        skip_uni = self.make_uni_token(self.previous());
        kid: list = [skip_uni];
        if self.match_tok(TokenKind.SEMI) {
            kid.append(self.make_semi());
        }
        return CtrlStmt(ctrl=skip_uni, kid=kid);
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
        dis_uni = self.make_uni_token(self.previous());
        kid: list = [dis_uni];
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
    # Handle impl inside code blocks
    if self.check(TokenKind.KW_IMPL) {
        return self.parse_impl_def();
    }
    # Handle has statements (in impl bodies and archetype bodies)
    if self.check(TokenKind.KW_HAS)
    or (self.check(TokenKind.KW_STATIC) and self.check_peek(TokenKind.KW_HAS)) {
        return self.parse_has_stmt();
    }
    # Handle inline Python: ::py:: ... ::py::
    if self.check(TokenKind.PYNLINE) {
        py_tok = self.advance();
        py_code = self.make_uni_token(py_tok);
        return PyInlineCode(code=py_code, kid=[py_code]);
    }
    # Handle typed context block: -> Type { ... }
    if self.check(TokenKind.RETURN_HINT) and not self.check_peek(TokenKind.SEMI) {
        self.advance();  # consume ->
        arrow_uni = self.make_uni_token(self.previous());
        type_ctx = self.parse_expression();
        lb_uni = self.consume_uni(TokenKind.LBRACE);
        body = self.parse_code_block_stmts();
        rb_uni = self.consume_uni(TokenKind.RBRACE);
        kid: list = [arrow_uni, type_ctx, lb_uni];
        kid.extend(body);
        kid.append(rb_uni);
        return TypedCtxBlock(type_ctx=type_ctx, body=body, kid=kid);
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
        TokenKind.MATMUL_EQ,
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
    if_uni = self.consume_uni(TokenKind.KW_IF);
    condition = self.parse_expression();
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    else_body = None;
    if self.check(TokenKind.KW_ELIF) {
        else_body = self.parse_elif_stmt();
    } elif self.check(TokenKind.KW_ELSE) {
        else_body = self.parse_else_stmt();
    }
    kid: list = [if_uni, condition, lb_uni];
    kid.extend(body);
    kid.append(rb_uni);
    if else_body {
        kid.append(else_body);
    }
    return IfStmt(condition=condition, body=body, else_body=else_body, kid=kid);
}

impl Parser.parse_elif_stmt -> ElseIf {
    elif_uni = self.consume_uni(TokenKind.KW_ELIF);
    condition = self.parse_expression();
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    else_body = None;
    if self.check(TokenKind.KW_ELIF) {
        else_body = self.parse_elif_stmt();
    } elif self.check(TokenKind.KW_ELSE) {
        else_body = self.parse_else_stmt();
    }
    kid: list = [elif_uni, condition, lb_uni];
    kid.extend(body);
    kid.append(rb_uni);
    if else_body {
        kid.append(else_body);
    }
    return ElseIf(condition=condition, body=body, else_body=else_body, kid=kid);
}

impl Parser.parse_else_stmt -> ElseStmt {
    else_uni = self.consume_uni(TokenKind.KW_ELSE);
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    kid: list = [else_uni, lb_uni];
    kid.extend(body);
    kid.append(rb_uni);
    return ElseStmt(body=body, kid=kid);
}

impl Parser.parse_while_stmt -> WhileStmt {
    while_uni = self.consume_uni(TokenKind.KW_WHILE);
    condition = self.parse_expression();
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    else_body = None;
    if self.check(TokenKind.KW_ELSE) {
        else_body = self.parse_else_stmt();
    }
    kid: list = [while_uni, condition, lb_uni];
    kid.extend(body);
    kid.append(rb_uni);
    if else_body {
        kid.append(else_body);
    }
    return WhileStmt(condition=condition, body=body, else_body=else_body, kid=kid);
}

impl Parser.parse_for_stmt{
    is_async = False;
    async_uni = None;
    if self.match_tok(TokenKind.KW_ASYNC) {
        is_async = True;
        async_uni = self.make_uni_token(self.previous());
    }
    for_uni = self.consume_uni(TokenKind.KW_FOR);
    # Parse target (could be assignment for iter_for_stmt or atomic_chain for in_for_stmt)
    target = self.parse_atomic_chain();
    # Check if this is a for...to...by loop (IterForStmt)
    if self.check(TokenKind.EQ) {
        # This is: for i = 0 to 10 by i += 1 { ... }
        eq_tok = self.advance();  # consume '='
        eq_uni = self.make_uni_token(eq_tok);
        start_val = self.parse_expression();
        to_uni = self.consume_uni(TokenKind.KW_TO);
        end_val = self.parse_pipe();
        by_uni = self.consume_uni(TokenKind.KW_BY);
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
            TokenKind.STAR_POW_EQ,
            TokenKind.MATMUL_EQ
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
        lb_uni = self.consume_uni(TokenKind.LBRACE);
        body = self.parse_code_block_stmts();
        rb_uni = self.consume_uni(TokenKind.RBRACE);
        else_body = None;
        if self.check(TokenKind.KW_ELSE) {
            else_body = self.parse_else_stmt();
        }
        # Create the initial assignment
        init_assign = Assignment(
            target=[target],
            value=start_val,
            type_tag=None,
            kid=[target, eq_uni, start_val],
            mutable=True,
            aug_op=None,
            is_enum_stmt=False
        );
        kid: list = [];
        if is_async {
            kid.append(async_uni);
        }
        kid.extend(
            [for_uni, init_assign, to_uni, end_val, by_uni, step_assign, lb_uni]
        );
        kid.extend(body);
        kid.append(rb_uni);
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
    in_uni = self.consume_uni(TokenKind.KW_IN);
    iter_expr = self.parse_expression();
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    else_body = None;
    if self.check(TokenKind.KW_ELSE) {
        else_body = self.parse_else_stmt();
    }
    kid: list = [];
    if is_async {
        kid.append(async_uni);
    }
    kid.extend([for_uni, target, in_uni, iter_expr]);
    kid.append(lb_uni);
    kid.extend(body);
    kid.append(rb_uni);
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
    try_uni = self.consume_uni(TokenKind.KW_TRY);
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
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
        fin_uni = self.make_uni_token(self.advance());
        fin_lb = self.consume_uni(TokenKind.LBRACE);
        finally_stmts = self.parse_code_block_stmts();
        fin_rb = self.consume_uni(TokenKind.RBRACE);
        fin_kid: list = [fin_uni, fin_lb];
        fin_kid.extend(finally_stmts);
        fin_kid.append(fin_rb);
        finally_body = FinallyStmt(body=finally_stmts, kid=fin_kid);
    }
    kid: list = [try_uni, lb_uni];
    kid.extend(body);
    kid.append(rb_uni);
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
    except_uni = self.consume_uni(TokenKind.KW_EXCEPT);
    exc_type = self.parse_expression();
    name = None;
    as_uni = None;
    if self.match_tok(TokenKind.KW_AS) {
        as_uni = self.make_uni_token(self.previous());
        name_tok = self.expect_name();
        name = self.make_name(name_tok);
    }
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    kid: list = [except_uni, exc_type];
    if name {
        kid.append(as_uni);
        kid.append(name);
    }
    kid.append(lb_uni);
    kid.extend(body);
    kid.append(rb_uni);
    return Except(ex_type=exc_type, name=name, body=body, kid=kid);
}

impl Parser.parse_with_stmt -> WithStmt {
    is_async = False;
    async_uni = None;
    if self.match_tok(TokenKind.KW_ASYNC) {
        is_async = True;
        async_uni = self.make_uni_token(self.previous());
    }
    with_uni = self.consume_uni(TokenKind.KW_WITH);
    exprs: list = [];
    expr = self.parse_expression();
    alias = None;
    as_uni = None;
    if self.match_tok(TokenKind.KW_AS) {
        as_uni = self.make_uni_token(self.previous());
        alias = self.parse_expression();
    }
    exprs.append(
        ExprAsItem(
            expr=expr, alias=alias, kid=[expr] if not alias else [expr, as_uni, alias]
        )
    );
    comma_unis: list = [];
    while self.match_tok(TokenKind.COMMA) {
        comma_unis.append(self.make_uni_token(self.previous()));
        expr = self.parse_expression();
        alias = None;
        as_uni = None;
        if self.match_tok(TokenKind.KW_AS) {
            as_uni = self.make_uni_token(self.previous());
            alias = self.parse_expression();
        }
        exprs.append(
            ExprAsItem(
                expr=expr,
                alias=alias,
                kid=[expr] if not alias else [expr, as_uni, alias]
            )
        );
    }
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    kid: list = [];
    if is_async {
        kid.append(async_uni);
    }
    kid.append(with_uni);
    for (i, e) in enumerate(exprs) {
        kid.append(e);
        if i < len(exprs) - 1 {
            kid.append(comma_unis[i]);
        }
    }
    kid.append(lb_uni);
    kid.extend(body);
    kid.append(rb_uni);
    return WithStmt(is_async=is_async, exprs=exprs, body=body, kid=kid);
}

impl Parser.parse_match_stmt -> MatchStmt {
    match_uni = self.consume_uni(TokenKind.KW_MATCH);
    expr = self.parse_expression();
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    cases: list = [];
    while self.check(TokenKind.KW_CASE) {
        cases.append(self.parse_match_case());
    }
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    kid: list = [match_uni, expr, lb_uni];
    kid.extend(cases);
    kid.append(rb_uni);
    return MatchStmt(target=expr, cases=cases, kid=kid);
}

impl Parser.parse_match_case -> MatchCase {
    case_uni = self.consume_uni(TokenKind.KW_CASE);
    pattern = self.parse_pattern();
    guard = None;
    guard_if_uni = None;
    if self.match_tok(TokenKind.KW_IF) {
        guard_if_uni = self.make_uni_token(self.previous());
        guard = self.parse_expression();
    }
    colon_uni = self.consume_uni(TokenKind.COLON);
    body: list = [];
    while not self.check_any(TokenKind.KW_CASE, TokenKind.RBRACE) and not self.at_end() {
        before = self.pos;
        stmt = self.parse_statement();
        if stmt is not None {
            body.append(stmt);
        }
        # Guard: ensure forward progress to prevent infinite loops
        if self.pos == before {
            self.advance();
        }
    }
    kid: list = [case_uni, pattern];
    if guard {
        kid.append(guard_if_uni);
        kid.append(guard);
    }
    kid.append(colon_uni);
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
        as_uni = self.make_uni_token(self.previous());
        name_tok = self.expect_name();
        name = self.make_name(name_tok);
        kid: list = [pattern, as_uni, name];
        return MatchAs(name=name, pattern=pattern, kid=kid);
    }
    return pattern;
}

impl Parser.parse_or_pattern{
    # or_pattern: (pattern BW_OR)* pattern
    patterns: list = [self.parse_single_pattern()];
    or_unis: list = [];
    while self.match_tok(TokenKind.BW_OR) {
        or_unis.append(self.make_uni_token(self.previous()));
        patterns.append(self.parse_single_pattern());
    }
    if len(patterns) == 1 {
        return patterns[0];
    }
    kid: list = [patterns[0]];
    for i in range(1, len(patterns)) {
        kid.append(or_unis[i - 1]);
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
    if self.check(TokenKind.STRING)
    or self.check_any(
        TokenKind.F_DQ_START,
        TokenKind.F_SQ_START,
        TokenKind.F_TDQ_START,
        TokenKind.F_TSQ_START,
        TokenKind.RF_DQ_START,
        TokenKind.RF_SQ_START,
        TokenKind.RF_TDQ_START,
        TokenKind.RF_TSQ_START
    ) {
        strings: list = [];
        if self.check(TokenKind.STRING) {
            tok = self.advance();
            strings.append(self.make_string(tok));
        } else {
            strings.append(self.parse_fstring());
        }
        while self.check(TokenKind.STRING)
        or self.check_any(
            TokenKind.F_DQ_START,
            TokenKind.F_SQ_START,
            TokenKind.F_TDQ_START,
            TokenKind.F_TSQ_START,
            TokenKind.RF_DQ_START,
            TokenKind.RF_SQ_START,
            TokenKind.RF_TDQ_START,
            TokenKind.RF_TSQ_START
        ) {
            if self.check(TokenKind.STRING) {
                next_tok = self.advance();
                strings.append(self.make_string(next_tok));
            } else {
                strings.append(self.parse_fstring());
            }
        }
        val = MultiString(strings=strings, kid=strings);
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
            dot_unis: list = [];
            while self.match_tok(TokenKind.DOT) {
                dot_unis.append(self.make_uni_token(self.previous()));
                next_tok = self.expect_name();
                names.append(self.make_name(next_tok));
            }
            # Check if it's a class pattern (followed by '(')
            if self.check(TokenKind.LPAREN) {
                return self.parse_class_pattern_args(names, dot_unis);
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
                    kid=[trailer, dot_unis[i - 1], names[i]]
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
    lsq_uni = self.consume_uni(TokenKind.LSQUARE);
    kid: list = [lsq_uni];
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
            comma_uni = self.consume_uni(TokenKind.COMMA);
            kid.append(comma_uni);
        }
    }
    rsq_uni = self.consume_uni(TokenKind.RSQUARE);
    kid.append(rsq_uni);
    return MatchSequence(values=values, kid=kid);
}

impl Parser.parse_tuple_sequence_pattern{
    # sequence_pattern: LPAREN list_inner_pattern (COMMA list_inner_pattern)* RPAREN
    lp_uni = self.consume_uni(TokenKind.LPAREN);
    kid: list = [lp_uni];
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
            comma_uni = self.consume_uni(TokenKind.COMMA);
            kid.append(comma_uni);
        }
    }
    rp_uni = self.consume_uni(TokenKind.RPAREN);
    kid.append(rp_uni);
    return MatchSequence(values=values, kid=kid);
}

impl Parser.parse_mapping_pattern{
    # mapping_pattern: LBRACE (dict_inner_pattern (COMMA dict_inner_pattern)*)? RBRACE
    # dict_inner_pattern: literal_pattern COLON pattern_seq | STAR_POW NAME
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    kid: list = [lb_uni];
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
            colon_uni = self.consume_uni(TokenKind.COLON);
            val = self.parse_pattern();
            kv = MatchKVPair(key=key, value=val, kid=[key, colon_uni, val]);
            values.append(kv);
            kid.append(kv);
        }
        if not self.check(TokenKind.RBRACE) {
            comma_uni = self.consume_uni(TokenKind.COMMA);
            kid.append(comma_uni);
        }
    }
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    kid.append(rb_uni);
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
    if self.check(TokenKind.STRING)
    or self.check_any(
        TokenKind.F_DQ_START,
        TokenKind.F_SQ_START,
        TokenKind.F_TDQ_START,
        TokenKind.F_TSQ_START,
        TokenKind.RF_DQ_START,
        TokenKind.RF_SQ_START,
        TokenKind.RF_TDQ_START,
        TokenKind.RF_TSQ_START
    ) {
        strings: list = [];
        if self.check(TokenKind.STRING) {
            tok = self.advance();
            strings.append(self.make_string(tok));
        } else {
            strings.append(self.parse_fstring());
        }
        while self.check(TokenKind.STRING)
        or self.check_any(
            TokenKind.F_DQ_START,
            TokenKind.F_SQ_START,
            TokenKind.F_TDQ_START,
            TokenKind.F_TSQ_START,
            TokenKind.RF_DQ_START,
            TokenKind.RF_SQ_START,
            TokenKind.RF_TDQ_START,
            TokenKind.RF_TSQ_START
        ) {
            if self.check(TokenKind.STRING) {
                next_tok = self.advance();
                strings.append(self.make_string(next_tok));
            } else {
                strings.append(self.parse_fstring());
            }
        }
        ms = MultiString(strings=strings, kid=strings);
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

impl Parser.parse_class_pattern_args(names: list, dot_unis: list | None = None) {
    # class_pattern: NAME (DOT NAME)* LPAREN kw_pattern_list? RPAREN
    #              | NAME (DOT NAME)* LPAREN pattern_list (COMMA kw_pattern_list)? RPAREN
    lparen_uni = self.consume_uni(TokenKind.LPAREN);
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
                kid=[class_name, dot_unis[i - 1], names[i]]
            );
        }
    }
    arg_patterns: list = [];
    kw_patterns: list = [];
    kid: list = [];
    # Add the class name
    kid.append(class_name);
    kid.append(lparen_uni);
    # Parse patterns
    while not self.check(TokenKind.RPAREN) and not self.at_end() {
        # Check if it's a keyword pattern (NAME EQ)
        if self.check_name() and self.check_peek(TokenKind.EQ) {
            # Keyword pattern
            name_tok = self.advance();
            eq_uni = self.consume_uni(TokenKind.EQ);
            val = self.parse_pattern();
            name = self.make_name(name_tok);
            kv = MatchKVPair(key=name, value=val, kid=[name, eq_uni, val]);
            kw_patterns.append(kv);
            kid.append(kv);
        } else {
            # Positional pattern
            pat = self.parse_pattern();
            arg_patterns.append(pat);
            kid.append(pat);
        }
        if not self.check(TokenKind.RPAREN) {
            comma_uni = self.consume_uni(TokenKind.COMMA);
            kid.append(comma_uni);
        }
    }
    rparen_uni = self.consume_uni(TokenKind.RPAREN);
    kid.append(rparen_uni);
    return MatchArch(
        name=class_name, arg_patterns=arg_patterns, kw_patterns=kw_patterns, kid=kid
    );
}

impl Parser.parse_return_stmt -> ReturnStmt {
    ret_uni = self.consume_uni(TokenKind.KW_RETURN);
    expr = None;
    if not self.check(TokenKind.SEMI) and not self.check(TokenKind.RBRACE) {
        expr = self.parse_expression();
    }
    kid: list = [ret_uni];
    if expr {
        kid.append(expr);
    }
    if self.match_tok(TokenKind.SEMI) {
        kid.append(self.make_semi());
    }
    return ReturnStmt(expr=expr, kid=kid);
}

impl Parser.parse_yield_stmt -> YieldExpr {
    yield_uni = self.consume_uni(TokenKind.KW_YIELD);
    with_from = False;
    from_uni: UniToken | None = None;
    if self.match_tok(TokenKind.KW_FROM) {
        with_from = True;
        from_uni = self.make_uni_token(self.previous());
    }
    expr = None;
    if not self.check(TokenKind.SEMI) and not self.check(TokenKind.RBRACE) {
        expr = self.parse_expression();
    }
    kid: list = [yield_uni];
    if from_uni {
        kid.append(from_uni);
    }
    if expr {
        kid.append(expr);
    }
    return YieldExpr(expr=expr, with_from=with_from, kid=kid);
}

impl Parser.parse_raise_stmt -> RaiseStmt {
    raise_uni = self.consume_uni(TokenKind.KW_RAISE);
    expr = None;
    from_target = None;
    if not self.check(TokenKind.SEMI) and not self.check(TokenKind.RBRACE) {
        expr = self.parse_expression();
    }
    from_kw_uni: UniToken | None = None;
    if self.match_tok(TokenKind.KW_FROM) {
        from_kw_uni = self.make_uni_token(self.previous());
        from_target = self.parse_expression();
    }
    kid: list = [raise_uni];
    if expr {
        kid.append(expr);
    }
    if from_target {
        kid.append(from_kw_uni);
        kid.append(from_target);
    }
    if self.match_tok(TokenKind.SEMI) {
        kid.append(self.make_semi());
    }
    return RaiseStmt(cause=expr, from_target=from_target, kid=kid);
}

impl Parser.parse_assert_stmt -> AssertStmt {
    assert_uni = self.consume_uni(TokenKind.KW_ASSERT);
    test = self.parse_expression();
    msg = None;
    comma_uni: UniToken | None = None;
    if self.match_tok(TokenKind.COMMA) {
        comma_uni = self.make_uni_token(self.previous());
        msg = self.parse_expression();
    }
    kid: list = [assert_uni, test];
    if msg {
        kid.append(comma_uni);
        kid.append(msg);
    }
    if self.match_tok(TokenKind.SEMI) {
        kid.append(self.make_semi());
    }
    return AssertStmt(condition=test, error_msg=msg, kid=kid);
}

impl Parser.parse_delete_stmt -> DeleteStmt {
    del_uni = self.consume_uni(TokenKind.KW_DELETE);
    target = self.parse_expression();
    kid: list = [del_uni, target];
    if self.match_tok(TokenKind.SEMI) {
        kid.append(self.make_semi());
    }
    return DeleteStmt(target=target, kid=kid);
}

impl Parser.parse_global_stmt -> GlobalStmt {
    # Parse: global name1, name2, ...;
    global_uni = self.consume_uni(TokenKind.KW_GLOBAL_REF);
    targets: list = [];
    kid: list = [global_uni];
    name_tok = self.expect_name();
    name = self.make_name(name_tok);
    targets.append(name);
    kid.append(name);
    while self.match_tok(TokenKind.COMMA) {
        kid.append(self.make_uni_token(self.previous()));
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
    nonlocal_uni = self.consume_uni(TokenKind.KW_NONLOCAL);
    targets: list = [];
    kid: list = [nonlocal_uni];
    name_tok = self.expect_name();
    name = self.make_name(name_tok);
    targets.append(name);
    kid.append(name);
    while self.match_tok(TokenKind.COMMA) {
        kid.append(self.make_uni_token(self.previous()));
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
        colon_uni = self.make_uni_token(self.previous());
        tp = self.parse_pipe();
        type_tag = SubTag(tag=tp, kid=[colon_uni, tp]);
    }
    value = None;
    aug_op = None;
    targets: list = [target];
    eq_unis: list = [];
    if self.match_tok(TokenKind.EQ) {
        eq_unis.append(self.make_uni_token(self.previous()));
        value = self.parse_yield_stmt()
        if self.check(TokenKind.KW_YIELD)
        else self.parse_expression();
        # Chain assignment: l1 = l2 = ... = expr
        while self.check(TokenKind.EQ)
        and not self.check_any(TokenKind.SEMI, TokenKind.RBRACE) {
            self.advance();
            eq_unis.append(self.make_uni_token(self.previous()));
            targets.append(value);
            value = self.parse_yield_stmt()
            if self.check(TokenKind.KW_YIELD)
            else self.parse_expression();
        }
    } elif self.check_any(
        TokenKind.ADD_EQ,
        TokenKind.SUB_EQ,
        TokenKind.MUL_EQ,
        TokenKind.DIV_EQ,
        TokenKind.FLOOR_DIV_EQ,
        TokenKind.MOD_EQ,
        TokenKind.STAR_POW_EQ,
        TokenKind.MATMUL_EQ,
        TokenKind.BW_AND_EQ,
        TokenKind.BW_OR_EQ,
        TokenKind.BW_XOR_EQ,
        TokenKind.LSHIFT_EQ,
        TokenKind.RSHIFT_EQ
    ) {
        aug_tok = self.advance();
        aug_op = self.make_uni_token(aug_tok);
        value = self.parse_yield_stmt()
        if self.check(TokenKind.KW_YIELD)
        else self.parse_expression();
    }
    kid: list = [];
    eq_idx = 0;
    for (ti, tgt) in enumerate(targets) {
        kid.append(tgt);
        if ti < len(targets) - 1 {
            kid.append(eq_unis[eq_idx]);
            eq_idx += 1;
        }
    }
    if type_tag {
        kid.append(type_tag);
    }
    if aug_op {
        kid.append(aug_op);
    } elif value {
        kid.append(eq_unis[eq_idx] if eq_idx < len(eq_unis) else eq_unis[-1]);
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

impl Parser.parse_import_stmt -> Import {
    is_include = self.check(TokenKind.KW_INCLUDE);
    hint_tok = self.advance();
    kid: list = [self.make_uni_token(hint_tok)];
    # Check for 'import from X { Y }' syntax
    from_loc: ModulePath | None = None;
    if self.match_tok(TokenKind.KW_FROM) {
        kid.append(self.make_uni_token(self.previous()));
        # Parse module path
        path_names: list = [];
        level = 0;
        path_kid: list = [];
        if self.check_any(TokenKind.DOT, TokenKind.ELLIPSIS) {
            # Relative import (.module, ..module, ...module) - count dots for level
            while self.check_any(TokenKind.DOT, TokenKind.ELLIPSIS) {
                if self.check(TokenKind.ELLIPSIS) {
                    tok = self.advance();
                    level += 3;
                    path_kid.append(self.make_ellipsis(tok));
                } else {
                    tok = self.advance();
                    level += 1;
                    path_kid.append(self.make_uni_token(tok));
                }
            }
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
                path_kid.append(self.make_uni_token(self.previous()));
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
            path_kid = [EmptyToken()];
        }
        from_loc = ModulePath(path=path_names, level=level, alias=None, kid=path_kid);
        kid.append(from_loc);
    }
    # Parse items in braces: { item1, item2, ... }
    items: list = [];
    if self.match_tok(TokenKind.LBRACE) {
        kid.append(self.make_uni_token(self.previous()));
        while not self.check(TokenKind.RBRACE) and not self.at_end() {
            item_name: Name;
            if self.check(TokenKind.STAR_MUL) {
                # Star import: import from X { * as Y }
                star_tok = self.advance();
                item_name = self.make_uni_token(star_tok);
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
            as_tok: Token | None = None;
            if self.match_tok(TokenKind.KW_AS) {
                as_tok = self.previous();
                alias_tok = self.expect_name();
                alias = self.make_name(alias_tok);
            }
            item_kid: list = [item_name];
            if alias is not None {
                item_kid.append(self.make_uni_token(as_tok));
                item_kid.append(alias);
            }
            item = ModuleItem(name=item_name, alias=alias, kid=item_kid);
            items.append(item);
            kid.append(item);
            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
            kid.append(self.make_uni_token(self.previous()));
        }
        rbrace_uni = self.consume_uni(TokenKind.RBRACE);
        kid.append(rbrace_uni);
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
                    path_kid.append(self.make_uni_token(self.previous()));
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
                as_uni = self.make_uni_token(self.previous());
                alias_tok = self.expect_name();
                alias = self.make_name(alias_tok);
                path_kid.append(as_uni);
                path_kid.append(alias);
            }
            path = ModulePath(path=path_names, level=0, alias=alias, kid=path_kid);
            items.append(path);
            kid.append(path);
            # Check for more imports
            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
            kid.append(self.make_uni_token(self.previous()));
        }
    }
    if from_loc is None and self.match_tok(TokenKind.SEMI) {
        kid.append(self.make_semi());
    }
    return Import(
        from_loc=from_loc, items=items, is_absorb=is_include, kid=kid, doc=None
    );
}

impl Parser.parse_archetype -> Archetype {
    decorators: list = [];
    decor_unis: list = [];
    while self.check(TokenKind.DECOR_OP) {
        decor_unis.append(self.make_uni_token(self.advance()));
        decorators.append(self.parse_atomic_chain());
    }
    is_async = False;
    async_uni = None;
    if self.match_tok(TokenKind.KW_ASYNC) {
        is_async = True;
        async_uni = self.make_uni_token(self.previous());
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
    lp_uni = None;
    rp_uni = None;
    arch_comma_unis: list = [];
    if self.match_tok(TokenKind.LPAREN) {
        lp_uni = self.make_uni_token(self.previous());
        if not self.check(TokenKind.RPAREN) {
            base_classes.append(self.parse_atomic_chain());
            while self.match_tok(TokenKind.COMMA) {
                arch_comma_unis.append(self.make_uni_token(self.previous()));
                base_classes.append(self.parse_atomic_chain());
            }
        }
        rp_uni = self.consume_uni(TokenKind.RPAREN);
    }
    body: list | None = None;
    has_body = False;
    body_lb_uni = None;
    body_rb_uni = None;
    if self.match_tok(TokenKind.LBRACE) {
        has_body = True;
        body_lb_uni = self.make_uni_token(self.previous());
        body = [];
        while not self.check(TokenKind.RBRACE) and not self.at_end() {
            before = self.pos;
            member = self.parse_archetype_member();
            if member is not None {
                body.append(member);
            }
            # Guard: ensure forward progress to prevent infinite loops
            if self.pos == before {
                self.advance();
            }
        }
        body_rb_uni = self.consume_uni(TokenKind.RBRACE);
    } else {
        self.match_tok(TokenKind.SEMI);
    }
    kid: list = [];
    if is_async {
        kid.append(async_uni);
    }
    for (i, d) in enumerate(decorators) {
        kid.append(decor_unis[i]);
        kid.append(d);
    }
    kid.append(arch_type);
    if access {
        kid.append(access);
    }
    kid.append(name);
    if base_classes {
        kid.append(lp_uni);
        for (i, bc) in enumerate(base_classes) {
            if i > 0 {
                kid.append(arch_comma_unis[i - 1]);
            }
            kid.append(bc);
        }
        kid.append(rp_uni);
    }
    if has_body {
        kid.append(body_lb_uni);
        kid.extend(body);
        kid.append(body_rb_uni);
    } else {
        kid.append(self.make_semi());
    }
    arch = Archetype(
        name=name,
        arch_type=arch_type,
        access=access,
        base_classes=base_classes,
        body=body,
        kid=kid,
        doc=None,
        decorators=decorators
    );
    if is_async {
        arch.is_async = True;
    }
    return arch;
}

impl Parser.parse_archetype_member{
    while self.match_tok(TokenKind.SEMI) {
        continue;
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
        if self.check_peek(TokenKind.KW_HAS) {
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
        and self.check_peek_any(
            TokenKind.KW_OBJECT,
            TokenKind.KW_NODE,
            TokenKind.KW_EDGE,
            TokenKind.KW_WALKER,
            TokenKind.KW_CLASS
        )
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
    # Handle impl blocks inside archetypes
    if self.check(TokenKind.KW_IMPL) {
        impl_node = self.parse_impl_def();
        if doc {
            impl_node.doc = doc;
            impl_node.add_kids_left([doc]);
        }
        return impl_node;
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
        with_tok = self.previous();  # capture the 'with' token
        if self.check_any(TokenKind.KW_ENTRY, TokenKind.KW_EXIT) {
            event_tok = self.advance();
            lb_uni = self.consume_uni(TokenKind.LBRACE);
            body = self.parse_code_block_stmts();
            rb_uni = self.consume_uni(TokenKind.RBRACE);
            kid: list = [
                self.make_uni_token(with_tok),
                self.make_uni_token(event_tok),
                lb_uni
            ];
            kid.extend(body);
            kid.append(rb_uni);
            return ModuleCode(name=None, body=body, kid=kid, doc=None);
        }
    }
    # Check for 'pass' keyword specifically
    if self.check(TokenKind.NAME) and self.current().value == "pass" {
        self.error("'pass' keyword is not allowed in Jac");
        self.error("Jac does not allow this keyword in any syntactic position");
    } else {
        self.error("Unexpected token in archetype body");
    }
    self.advance();
    return EmptyToken();
}

impl Parser.parse_has_stmt -> ArchHas {
    is_static = False;
    static_tok = None;
    if self.match_tok(TokenKind.KW_STATIC) {
        is_static = True;
        static_tok = self.previous();
    }
    has_tok = self.expect(TokenKind.KW_HAS);
    access = self.parse_access_tag();
    vars: list = [];
    has_comma_unis: list = [];
    vars.append(self.parse_has_var());
    while self.match_tok(TokenKind.COMMA) {
        has_comma_unis.append(self.make_uni_token(self.previous()));
        vars.append(self.parse_has_var());
    }
    self.expect(TokenKind.SEMI);
    kid: list = [];
    if is_static {
        kid.append(self.make_uni_token(static_tok));
    }
    kid.append(self.make_uni_token(has_tok));
    if access {
        kid.append(access);
    }
    # Add vars with commas between them
    for (i, v) in enumerate(vars) {
        if i > 0 {
            kid.append(has_comma_unis[i - 1]);
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
    colon_uni = self.consume_uni(TokenKind.COLON);
    type_expr = self.parse_pipe();
    type_tag = SubTag(tag=type_expr, kid=[colon_uni, type_expr]);
    value = None;
    defer = False;
    eq_uni: UniToken | None = None;
    by_uni: UniToken | None = None;
    if self.match_tok(TokenKind.EQ) {
        eq_uni = self.make_uni_token(self.previous());
        value = self.parse_expression();
    } elif self.match_tok(TokenKind.KW_BY) {
        by_uni = self.make_uni_token(self.previous());
        self.expect(TokenKind.KW_POST_INIT);
        defer = True;
    }
    kid: list = [name, type_tag];
    if value {
        kid.append(eq_uni);
        kid.append(value);
    }
    if defer {
        kid.append(by_uni);
        kid.append(self.make_special_name(self.previous()));
    }
    return HasVar(name=name, type_tag=type_tag, value=value, defer=defer, kid=kid);
}

impl Parser.parse_ability -> Ability {
    decorators: list = [];
    decor_unis: list = [];
    while self.check(TokenKind.DECOR_OP) {
        decor_unis.append(self.make_uni_token(self.advance()));
        decorators.append(self.parse_atomic_chain());
    }
    is_override = False;
    override_tok = None;
    if self.match_tok(TokenKind.KW_OVERRIDE) {
        is_override = True;
        override_tok = self.previous();
    }
    is_static = False;
    static_tok = None;
    if self.match_tok(TokenKind.KW_STATIC) {
        is_static = True;
        static_tok = self.previous();
    }
    is_async = False;
    async_tok = None;
    if self.match_tok(TokenKind.KW_ASYNC) {
        is_async = True;
        async_tok = self.previous();
        # Handle `async static/override def` ordering (async before modifiers)
        if not is_override and self.match_tok(TokenKind.KW_OVERRIDE) {
            is_override = True;
            override_tok = self.previous();
        }
        if not is_static and self.match_tok(TokenKind.KW_STATIC) {
            is_static = True;
            static_tok = self.previous();
        }
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
        with_uni = self.make_uni_token(self.advance());
        event_type = self.parse_expression()
        if not self.check_any(TokenKind.KW_ENTRY, TokenKind.KW_EXIT)
        else None;
        event_tok = self.advance();
        event_uni_tok = self.make_uni_token(event_tok);
        # Build EventSignature kid list
        sig_kid: list = [with_uni];
        if event_type {
            sig_kid.append(event_type);
        }
        sig_kid.append(event_uni_tok);
        signature = EventSignature(
            event=event_uni_tok, arch_tag_info=event_type, kid=sig_kid
        );
    } elif is_can {
        self.error(
            "Expected 'with' after 'can' ability name (use 'def' for function-style declarations)"
        );
        signature = self.parse_func_signature();
    } else {
        signature = self.parse_func_signature();
    }
    body: list | None = None;
    is_abstract = False;
    body_type = "semi";  # "brace", "by", or "semi"
    body_lb_uni = None;
    body_rb_uni = None;
    body_by_uni = None;
    body_abs_uni = None;
    if self.match_tok(TokenKind.LBRACE) {
        body_type = "brace";
        body_lb_uni = self.make_uni_token(self.previous());
        body = self.parse_code_block_stmts();
        body_rb_uni = self.consume_uni(TokenKind.RBRACE);
    } elif self.match_tok(TokenKind.KW_BY) {
        body_type = "by";
        body_by_uni = self.make_uni_token(self.previous());
        by_expr = self.parse_expression();
        self.expect(TokenKind.SEMI);
        by_expr.add_kids_left([body_by_uni]);
        by_expr.add_kids_right([self.make_semi()]);
        body = by_expr;
    } else {
        if self.match_tok(TokenKind.KW_ABSTRACT) {
            is_abstract = True;
            body_abs_uni = self.make_uni_token(self.previous());
        }
        self.expect(TokenKind.SEMI);
    }
    kid: list = [];
    for (di, d) in enumerate(decorators) {
        kid.append(decor_unis[di]);
        kid.append(d);
    }
    if is_override {
        kid.append(self.make_uni_token(override_tok));
    }
    if is_static {
        kid.append(self.make_uni_token(static_tok));
    }
    if is_async {
        kid.append(self.make_uni_token(async_tok));
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
    } else {
        signature = None;
    }
    if body_type == "brace" {
        kid.append(body_lb_uni);
        kid.extend(body);
        kid.append(body_rb_uni);
    } elif body_type == "by" {
        kid.append(body);
    } else {
        # Declaration-only: add abs token if abstract, then Semi
        if is_abstract {
            kid.append(body_abs_uni);
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
    all_params: list = [];
    return_type = None;
    kid: list = [];
    if self.match_tok(TokenKind.LPAREN) {
        kid.append(self.make_uni_token(self.previous()));
        if not self.check(TokenKind.RPAREN) {
            all_params = self.parse_func_params(kid);
        }
        rparen_uni = self.consume_uni(TokenKind.RPAREN);
        kid.append(rparen_uni);
    }
    if self.match_tok(TokenKind.RETURN_HINT) {
        kid.append(self.make_uni_token(self.previous()));
        return_type = self.parse_pipe();
        kid.append(return_type);
    }
    # Ensure non-empty kid list for unitree
    if len(kid) == 0 {
        kid.append(EmptyToken());
    }
    # Categorize params into positional-only, regular, keyword-only, *args, **kwargs
    posonly_params: list = [];
    regular_params: list = [];
    kwonly_params: list = [];
    varargs_param = None;
    kwargs_param = None;
    # Walk through kid to find separator tokens and categorize params
    saw_bare_star = False;
    saw_slash = False;
    for k in kid {
        if isinstance(k, ParamVar) {
            if k.unpack and k.unpack?.name and k.unpack.name == Tok.STAR_POW {
                kwargs_param = k;
            } elif k.unpack and k.unpack?.name and k.unpack.name == Tok.STAR_MUL {
                varargs_param = k;
                saw_bare_star = True;
            } elif saw_bare_star {
                kwonly_params.append(k);
            } else {
                regular_params.append(k);
            }
        } elif isinstance(k, UniToken) {
            if k.name == Tok.STAR_MUL {
                # Bare * separator (not *args, since *args would be a ParamVar)
                saw_bare_star = True;
            } elif k.name == Tok.DIV {
                # Bare / separator - all regular params so far are positional-only
                posonly_params = regular_params;
                regular_params = [];
                saw_slash = True;
            }
        }
    }
    # Validate parameter ordering rules (use elif to report one error per separator)
    has_slash = False;
    has_star = False;
    has_kwargs = False;
    for k in kid {
        if isinstance(k, UniToken) and k.name == Tok.DIV {
            if has_slash {
                self.error("Duplicate '/' in parameter list");
            } elif has_star {
                self.error("'/' must appear before '*' in parameter list");
            } elif has_kwargs {
                self.error("'/' must appear before '**kwargs' in parameter list");
            }
            has_slash = True;
        } elif isinstance(k, UniToken) and k.name == Tok.STAR_MUL {
            if has_star {
                self.error("Duplicate '*' in parameter list");
            } elif has_kwargs {
                self.error("'*' must appear before '**kwargs' in parameter list");
            }
            has_star = True;
        } elif isinstance(k, ParamVar) {
            if k.unpack and k.unpack?.name {
                if k.unpack.name == Tok.STAR_MUL {
                    if has_star {
                        self.error("Duplicate '*' in parameter list");
                    } elif has_kwargs {
                        self.error(
                            "'*' must appear before '**kwargs' in parameter list"
                        );
                    }
                    has_star = True;
                } elif k.unpack.name == Tok.STAR_POW {
                    if has_kwargs {
                        self.error("Duplicate '**kwargs' in parameter list");
                    }
                    has_kwargs = True;
                }
            }
        }
    }
    # Set param_kind on each ParamVar (default is NORMAL, must be overridden)
    for p in posonly_params {
        p.param_kind = ParamKind.POSONLY;
    }
    for p in kwonly_params {
        p.param_kind = ParamKind.KWONLY;
    }
    if varargs_param {
        varargs_param.param_kind = ParamKind.VARARG;
    }
    if kwargs_param {
        kwargs_param.param_kind = ParamKind.KWARG;
    }
    return FuncSignature(
        posonly_params=posonly_params,
        params=regular_params,
        varargs=varargs_param,
        kwonlyargs=kwonly_params,
        kwargs=kwargs_param,
        return_type=return_type,
        kid=kid
    );
}

impl Parser.parse_func_params(kid: list) -> list {
    params: list = [];
    while not self.check(TokenKind.RPAREN) {
        # Handle bare * (keyword-only separator) or / (positional-only separator)
        if self.check(TokenKind.STAR_MUL)
        and (self.check_peek(TokenKind.COMMA) or self.check_peek(TokenKind.RPAREN)) {
            star_tok = self.advance();
            star_uni = self.make_uni_token(star_tok);
            kid.append(star_uni);
            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
            kid.append(self.make_uni_token(self.previous()));
        } elif self.check(TokenKind.DIV)
        and (self.check_peek(TokenKind.COMMA) or self.check_peek(TokenKind.RPAREN)) {
            div_tok = self.advance();
            div_uni = self.make_uni_token(div_tok);
            kid.append(div_uni);
            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
            kid.append(self.make_uni_token(self.previous()));
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
                    param_colon_uni = self.make_uni_token(self.previous());
                    tp = self.parse_pipe();
                    type_tag = SubTag(tag=tp, kid=[param_colon_uni, tp]);
                }
                default_val: Expr | None = None;
                param_eq_uni: UniToken | None = None;
                if self.match_tok(TokenKind.EQ) {
                    param_eq_uni = self.make_uni_token(self.previous());
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
                    pv_kid.append(param_eq_uni);
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
            kid.append(self.make_uni_token(self.previous()));
        }
    }
    return params;
}

impl Parser.parse_enum -> Enum {
    decorators: list = [];
    enum_decor_unis: list = [];
    while self.check(TokenKind.DECOR_OP) {
        enum_decor_unis.append(self.make_uni_token(self.advance()));
        decorators.append(self.parse_atomic_chain());
    }
    enum_kw_uni = self.consume_uni(TokenKind.KW_ENUM);
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
    enum_lp_uni: UniToken | None = None;
    enum_rp_uni: UniToken | None = None;
    enum_base_comma_unis: list = [];
    if self.match_tok(TokenKind.LPAREN) {
        enum_lp_uni = self.make_uni_token(self.previous());
        if not self.check(TokenKind.RPAREN) {
            base_classes.append(self.parse_atomic_chain());
            while self.match_tok(TokenKind.COMMA) {
                enum_base_comma_unis.append(self.make_uni_token(self.previous()));
                base_classes.append(self.parse_atomic_chain());
            }
        }
        enum_rp_uni = self.consume_uni(TokenKind.RPAREN);
    }
    body: list | None = None;
    body_kid: list = [];
    has_body = False;
    enum_lb_uni: UniToken | None = None;
    enum_rb_uni: UniToken | None = None;
    if self.match_tok(TokenKind.LBRACE) {
        has_body = True;
        enum_lb_uni = self.make_uni_token(self.previous());
        body = [];
        while not self.check(TokenKind.RBRACE) and not self.at_end() {
            if self.check_name() {
                member = self.parse_enum_member();
                body.append(member);
                body_kid.append(member);
                if self.match_tok(TokenKind.COMMA) {
                    body_kid.append(self.make_uni_token(self.previous()));
                }
            } elif self.check(TokenKind.PYNLINE) {
                py_tok = self.advance();
                py_code = self.make_uni_token(py_tok);
                pynline = PyInlineCode(code=py_code, kid=[py_code]);
                pynline.is_enum_stmt = True;
                body.append(pynline);
                body_kid.append(pynline);
            } elif self.check(TokenKind.KW_WITH) {
                mc = self.parse_module_code();
                mc.is_enum_stmt = True;
                body.append(mc);
                body_kid.append(mc);
            } else {
                break;
            }
        }
        enum_rb_uni = self.consume_uni(TokenKind.RBRACE);
    } else {
        self.expect(TokenKind.SEMI);
    }
    kid: list = [];
    for (di, d) in enumerate(decorators) {
        kid.append(enum_decor_unis[di]);
        kid.append(d);
    }
    kid.append(enum_kw_uni);
    if access {
        kid.append(access);
    }
    kid.append(name);
    if base_classes {
        kid.append(enum_lp_uni);
        for (i, base) in enumerate(base_classes) {
            kid.append(base);
            if i < len(base_classes) - 1 {
                kid.append(enum_base_comma_unis[i]);
            }
        }
        kid.append(enum_rp_uni);
    }
    if has_body {
        kid.append(enum_lb_uni);
        kid.extend(body_kid);
        kid.append(enum_rb_uni);
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
    em_eq_uni: UniToken | None = None;
    if self.match_tok(TokenKind.EQ) {
        em_eq_uni = self.make_uni_token(self.previous());
        value = self.parse_expression();
    }
    kid: list = [name];
    if value {
        kid.append(em_eq_uni);
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
    import re;
    test_kw_uni = self.consume_uni(TokenKind.KW_TEST);
    # When no explicit description, create a placeholder empty name token
    cur = self.current();
    name: Name | UniToken = UniToken(
        orig_src=self.get_source(),
        name=Tok.NAME.value,
        value="",
        line=cur.loc.line,
        end_line=cur.loc.end_line,
        col_start=cur.loc.col_start,
        col_end=cur.loc.col_end,
        pos_start=cur.loc.pos_start,
        pos_end=cur.loc.pos_end
    );
    has_description = False;
    description: String | None = None;
    if self.check(TokenKind.STRING) {
        str_tok = self.advance();
        description = self.make_string(str_tok);
        # Derive a valid identifier from the string description
        desc_text = description.lit_value;
        ident = re.sub(r'[^a-zA-Z0-9]+', '_', desc_text).strip('_').lower();
        if not ident {
            ident = f"_jac_gen_{Test.TEST_COUNT + 1}";
        }
        name = Name(
            orig_src=self.get_source(),
            name=Tok.NAME.value,
            value=ident,
            line=str_tok.loc.line,
            end_line=str_tok.loc.end_line,
            col_start=str_tok.loc.col_start,
            col_end=str_tok.loc.col_end,
            pos_start=str_tok.loc.pos_start,
            pos_end=str_tok.loc.pos_end
        );
        has_description = True;
    }
    test_lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    test_rb_uni = self.consume_uni(TokenKind.RBRACE);
    kid: list = [test_kw_uni];
    if has_description {
        kid.append(description);
    }
    kid.append(test_lb_uni);
    kid.extend(body);
    kid.append(test_rb_uni);
    return Test(name=name, body=body, kid=kid, doc=None, description=description);
}

impl Parser.parse_switch_stmt -> SwitchStmt {
    switch_uni = self.consume_uni(TokenKind.KW_SWITCH);
    target = self.parse_expression();
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    cases: list = [];
    while self.check_any(TokenKind.KW_CASE, TokenKind.KW_DEFAULT) {
        cases.append(self.parse_switch_case());
    }
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    kid: list = [switch_uni, target, lb_uni];
    kid.extend(cases);
    kid.append(rb_uni);
    return SwitchStmt(target=target, cases=cases, kid=kid);
}

impl Parser.parse_switch_case -> SwitchCase {
    is_default = False;
    pattern = None;
    kw_uni = None;
    if self.match_tok(TokenKind.KW_DEFAULT) {
        is_default = True;
        kw_uni = self.make_uni_token(self.previous());
    } else {
        kw_uni = self.consume_uni(TokenKind.KW_CASE);
        pattern = self.parse_pattern();
    }
    colon_uni = self.consume_uni(TokenKind.COLON);
    body: list = [];
    while not self.check_any(TokenKind.KW_CASE, TokenKind.KW_DEFAULT, TokenKind.RBRACE)
    and not self.at_end() {
        before = self.pos;
        stmt = self.parse_statement();
        if stmt is not None {
            body.append(stmt);
        }
        # Guard: ensure forward progress to prevent infinite loops
        if self.pos == before {
            self.advance();
        }
    }
    kid: list = [kw_uni];
    if pattern {
        kid.append(pattern);
    }
    kid.append(colon_uni);
    kid.extend(body);
    return SwitchCase(pattern=pattern, body=body, kid=kid);
}

impl Parser.parse_global_var -> GlobalVars {
    glob_kw_uni = self.consume_uni(TokenKind.KW_GLOBAL);
    access = self.parse_access_tag();
    # Parse assignment list
    assignments: list = [];
    glob_comma_unis: list = [];
    assignments.append(self.parse_global_var_assignment());
    while self.match_tok(TokenKind.COMMA) {
        glob_comma_unis.append(self.make_uni_token(self.previous()));
        assignments.append(self.parse_global_var_assignment());
    }
    self.expect(TokenKind.SEMI);
    kid: list = [glob_kw_uni];
    if access {
        kid.append(access);
    }
    # Add assignments with commas between them
    for (i, a) in enumerate(assignments) {
        if i > 0 {
            kid.append(glob_comma_unis[i - 1]);
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
        gv_colon_uni = self.make_uni_token(self.previous());
        tp = self.parse_pipe();
        type_tag = SubTag(tag=tp, kid=[gv_colon_uni, tp]);
    }
    value = None;
    targets: list = [name];
    gv_eq_unis: list = [];
    if self.match_tok(TokenKind.EQ) {
        gv_eq_unis.append(self.make_uni_token(self.previous()));
        value = self.parse_expression();
        # Handle chained assignment: glob a = b=16 means targets=[a, b], value=16
        while self.check(TokenKind.EQ) {
            # 'value' was actually a target name, move it to targets
            targets.append(value);
            self.advance();  # consume =
            gv_eq_unis.append(self.make_uni_token(self.previous()));
            value = self.parse_expression();
        }
    }
    kid: list = [targets[0]];
    if type_tag {
        kid.append(type_tag);
    }
    gv_eq_idx = 0;
    for i in range(1, len(targets)) {
        kid.append(gv_eq_unis[gv_eq_idx]);
        gv_eq_idx += 1;
        kid.append(targets[i]);
    }
    if value {
        kid.append(
            gv_eq_unis[gv_eq_idx] if gv_eq_idx < len(gv_eq_unis) else gv_eq_unis[-1]
        );
        kid.append(value);
    }
    return Assignment(
        target=targets,
        value=value,
        type_tag=type_tag,
        kid=kid,
        mutable=True,
        aug_op=None,
        is_enum_stmt=False
    );
}

impl Parser.parse_impl_def -> ImplDef {
    decorators: list = [];
    impl_decor_unis: list = [];
    while self.check(TokenKind.DECOR_OP) {
        impl_decor_unis.append(self.make_uni_token(self.advance()));
        decorators.append(self.parse_atomic_chain());
    }
    impl_uni = self.consume_uni(TokenKind.KW_IMPL);
    # Parse dotted name as a list of Name objects (e.g., [MyClass, my_method])
    target_names: list = [];
    dot_unis: list = [];
    target_names.append(self.parse_impl_target_name());
    while self.match_tok(TokenKind.DOT) {
        dot_unis.append(self.make_uni_token(self.previous()));
        target_names.append(self.parse_impl_target_name());
    }
    # Parse optional impl_spec (inherited_archs, func_decl, or event_clause)
    spec: FuncSignature | EventSignature | list | None = None;
    base_classes: list = [];
    impl_inh_comma_unis: list = [];
    impl_inh_lp_tok: Token | None = None;
    impl_inh_rp_uni: UniToken | None = None;
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
            impl_inh_lp_tok = self.advance();  # consume LPAREN
            if not self.check(TokenKind.RPAREN) {
                base_classes.append(self.parse_atomic_chain());
                while self.match_tok(TokenKind.COMMA) {
                    impl_inh_comma_unis.append(self.make_uni_token(self.previous()));
                    base_classes.append(self.parse_atomic_chain());
                }
            }
            impl_inh_rp_uni = self.consume_uni(TokenKind.RPAREN);
            spec = base_classes;
        }
    } elif self.check(TokenKind.KW_WITH) {
        # event_clause
        with_tok = self.advance();
        event_type = self.parse_expression()
        if not self.check_any(TokenKind.KW_ENTRY, TokenKind.KW_EXIT)
        else None;
        event_tok = self.advance();
        ev_kid: list = [self.make_uni_token(with_tok)];
        if event_type is not None {
            ev_kid.append(event_type);
        }
        ev_kid.append(self.make_uni_token(event_tok));
        spec = EventSignature(
            event=self.make_uni_token(event_tok), arch_tag_info=event_type, kid=ev_kid
        );
    } elif self.check(TokenKind.RETURN_HINT)
    or (self.check(TokenKind.LPAREN) and not self.check(TokenKind.LBRACE)) {
        # func_decl
        spec = self.parse_func_signature();
    }
    # Parse impl_tail (enum_block or block_tail)
    body: list | Expr = [];
    lb_uni: UniToken | None = None;
    rb_uni: UniToken | None = None;
    if self.match_tok(TokenKind.LBRACE) {
        lb_uni = self.make_uni_token(self.previous());
        # Check if this is enum-style body (NAME = value, NAME = value, ... or NAME, NAME, ...)
        # Key distinction: enum-style uses commas, regular uses semicolons
        is_enum_style = False;
        # Bare name followed by comma is enum-style: impl Enum { Bar, Baz }
        if self.check_name() and self.check_peek(TokenKind.COMMA) {
            is_enum_style = True;
        }
        # NAME: type = value followed by comma is enum-style
        if not is_enum_style and self.check_name() and self.check_peek(TokenKind.COLON) {
            save_pos = self.pos;
            self.advance();  # consume NAME
            self.advance();  # consume COLON
            # Skip type expression to find EQ or COMMA
            depth = 0;
            while not self.at_end()
            and not (
                depth == 0
                and self.check_any(
                    TokenKind.EQ, TokenKind.COMMA, TokenKind.SEMI, TokenKind.RBRACE
                )
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
            if self.check(TokenKind.EQ) {
                self.advance();  # consume EQ
                # Skip value to find delimiter
                depth = 0;
                while not self.at_end()
                and not (
                    depth == 0
                    and self.check_any(
                        TokenKind.COMMA, TokenKind.SEMI, TokenKind.RBRACE
                    )
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
                if self.check(TokenKind.COMMA) {
                    is_enum_style = True;
                }
            } elif self.check(TokenKind.COMMA) {
                is_enum_style = True;
            }
            self.pos = save_pos;
        }
        # NAME = value followed by comma is enum-style
        if not is_enum_style and self.check_name() and self.check_peek(TokenKind.EQ) {
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
            self._impl_enum_comma_unis = [];
            body = self.parse_impl_enum_body();
        } else {
            body = self.parse_code_block_stmts();
        }
        rb_uni = self.consume_uni(TokenKind.RBRACE);
    } elif self.match_tok(TokenKind.KW_BY) {
        body = self.parse_expression();
        self.expect(TokenKind.SEMI);
    } else {
        self.error("Expected '{' or 'by' for impl body");
        self.expect(TokenKind.SEMI);
    }
    kid: list = [];
    for (di, d) in enumerate(decorators) {
        kid.append(impl_decor_unis[di]);
        kid.append(d);
    }
    kid.append(impl_uni);
    for (i, n) in enumerate(target_names) {
        kid.append(n);
        if i < len(dot_unis) {
            kid.append(dot_unis[i]);
        }
    }
    if isinstance(spec, FuncSignature) or isinstance(spec, EventSignature) {
        kid.append(spec);
    } elif isinstance(spec, list) and len(spec) > 0 {
        # inherited_archs in parens
        kid.append(self.make_uni_token(impl_inh_lp_tok));
        for (i, bc) in enumerate(spec) {
            if i > 0 {
                kid.append(impl_inh_comma_unis[i - 1]);
            }
            kid.append(bc);
        }
        kid.append(impl_inh_rp_uni);
    }
    if isinstance(body, list) {
        if lb_uni {
            kid.append(lb_uni);
        }
        impl_enum_commas = getattr(self, "_impl_enum_comma_unis", []);
        comma_idx = 0;
        for (i, item) in enumerate(body) {
            kid.append(item);
            # Add comma tokens between enum-style body items
            if getattr(item, "is_enum_stmt", False) and i < len(body) - 1 {
                if comma_idx < len(impl_enum_commas) {
                    kid.append(impl_enum_commas[comma_idx]);
                    comma_idx += 1;
                }
            }
        }
        if rb_uni {
            kid.append(rb_uni);
        }
    } else {
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
    } elif self.is_keyword_token() {
        name_tok = self.advance();
        return self.make_special_name(name_tok);
    } else {
        name_tok = self.expect(TokenKind.NAME);  # Will error
        return self.make_name(name_tok);
    }
}

impl Parser.parse_impl_enum_body -> list {
    # Parse enum-style impl body: NAME = value, NAME: type = value, ...
    # Comma-separated assignments (final comma optional)
    # Only Assignment nodes go into the body list (not COMMA tokens).
    # This matches how parse_enum separates body from body_kid.
    members: list = [];
    while not self.check(TokenKind.RBRACE) and not self.at_end() {
        if self.check_name() {
            name_tok = self.advance();
            name = self.make_name(name_tok, is_enum_stmt=True);
            type_tag: SubTag | None = None;
            value: Expr | None = None;
            # Optional type annotation: NAME: type
            if self.match_tok(TokenKind.COLON) {
                ieb_colon_uni = self.make_uni_token(self.previous());
                tp = self.parse_pipe();
                type_tag = SubTag(tag=tp, kid=[ieb_colon_uni, tp]);
            }
            ieb_eq_uni: UniToken | None = None;
            if self.match_tok(TokenKind.EQ) {
                ieb_eq_uni = self.make_uni_token(self.previous());
                value = self.parse_expression();
            }
            kid: list = [name];
            if type_tag {
                kid.append(type_tag);
            }
            if value {
                kid.append(ieb_eq_uni);
                kid.append(value);
            }
            members.append(
                Assignment(
                    target=[name],
                    value=value,
                    type_tag=type_tag,
                    kid=kid,
                    mutable=True,
                    aug_op=None,
                    is_enum_stmt=True
                )
            );
            # Consume optional comma (captured for caller)
            if self.match_tok(TokenKind.COMMA) {
                self._impl_enum_comma_unis.append(self.make_uni_token(self.previous()));
            }
        } else {
            break;
        }
    }
    return members;
}

impl Parser.parse_sem_def -> SemDef {
    # Parse semantic definition: sem name = "description";  or  sem name.attr = "description";
    sem_kw_uni = self.consume_uni(TokenKind.KW_SEM);
    target_names: list = [];
    sem_dot_unis: list = [];
    target_names.append(self.parse_impl_target_name());
    while self.match_tok(TokenKind.DOT) {
        sem_dot_unis.append(self.make_uni_token(self.previous()));
        target_names.append(self.parse_impl_target_name());
    }
    # Accept either '=' or 'is' per grammar: sem_def: KW_SEM dotted_name (EQ | KW_IS) STRING SEMI
    sep_uni: UniToken | None = None;
    if self.match_tok(TokenKind.EQ) {
        sep_uni = self.make_uni_token(self.previous());
    } elif self.match_tok(TokenKind.KW_IS) {
        sep_uni = self.make_uni_token(self.previous());
    } else {
        self.expect(TokenKind.EQ);  # Will error with expected '='
        sep_uni = self.make_uni_token(self.previous());
    }
    # SemDef value is a bare STRING, not a multistring expression
    value_tok = self.expect(TokenKind.STRING);
    value = self.make_string(value_tok);
    kid: list = [sem_kw_uni];
    for (i, n) in enumerate(target_names) {
        kid.append(n);
        if i < len(target_names) - 1 {
            kid.append(sem_dot_unis[i]);
        }
    }
    kid.append(sep_uni);
    kid.append(value);
    kid.append(self.make_semi());
    self.match_tok(TokenKind.SEMI);
    return SemDef(target=target_names, value=value, kid=kid);
}

impl Parser.parse_dotted_name -> Expr {
    name_tok = self.expect(TokenKind.NAME);
    result: Expr = self.make_name(name_tok);
    while self.match_tok(TokenKind.DOT) {
        dot_uni = self.make_uni_token(self.previous());
        next_name_tok = self.expect(TokenKind.NAME);
        next_name = self.make_name(next_name_tok);
        kid: list = [result, dot_uni, next_name];
        result = AtomTrailer(
            target=result, right=next_name, is_attr=True, is_null_ok=False, kid=kid
        );
    }
    return result;
}

impl Parser.parse_visit_stmt -> VisitStmt {
    visit_uni = self.consume_uni(TokenKind.KW_VISIT);
    # Check for optional insert location: visit :SomeExpr: target
    insert_loc = None;
    colon1_uni = None;
    colon2_uni = None;
    if self.match_tok(TokenKind.COLON) {
        colon1_uni = self.make_uni_token(self.previous());
        insert_loc = self.parse_expression();
        colon2_uni = self.consume_uni(TokenKind.COLON);
    }
    target = self.parse_expression();
    else_body = None;
    has_semi = False;
    if self.check(TokenKind.KW_ELSE) {
        else_body = self.parse_else_stmt();
    } elif self.match_tok(TokenKind.SEMI) {
        has_semi = True;
    }
    kid: list = [visit_uni];
    if insert_loc {
        kid.append(colon1_uni);
        kid.append(insert_loc);
        kid.append(colon2_uni);
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

impl Parser.parse_report_stmt -> ReportStmt {
    report_uni = self.consume_uni(TokenKind.KW_REPORT);
    expr = self.parse_expression();
    kid: list = [report_uni, expr];
    if self.match_tok(TokenKind.SEMI) {
        kid.append(self.make_semi());
    }
    return ReportStmt(expr=expr, kid=kid);
}

impl parse(
    source: str, file_path: str = "<input>"
) -> tuple[Module, list[ParseError], list[LexerError]] {
    lexer = Lexer(source=source, file_path=file_path);
    tokens = lexer.tokenize();
    parser = Parser(tokens=tokens, file_path=file_path, source_code=source);
    module = parser.parse();
    return (module, parser.errors, lexer.errors);
}
