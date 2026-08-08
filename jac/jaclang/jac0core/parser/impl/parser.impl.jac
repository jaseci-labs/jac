import from jaclang.jac0core.constant { Tokens as Tok, SymbolAccess, SymbolType }

impl Parser.current -> LexToken {
    if self.pos < self._tokens_len {
        return self.tokens[self.pos];
    }
    return self.tokens[-1];
}

impl Parser.peek(offset: int = 1) -> LexToken {
    idx = self.pos + offset;
    if idx < self._tokens_len {
        return self.tokens[idx];
    }
    return self.tokens[-1];
}

impl Parser.advance -> LexToken {
    tok = self.current();
    if self.pos < self._tokens_len - 1 {
        self.pos += 1;
    }
    return tok;
}

impl Parser.previous -> LexToken {
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

impl Parser.postinit{
    self.b = SyntaxArena();
}

impl Parser.match_tok(kind: TokenKind) -> LexToken | None {
    if self.check(kind) {
        return self.advance();
    }
    return None;
}

impl Parser.match_any(*kinds: TokenKind) -> LexToken | None {
    if self.current().kind in kinds {
        return self.advance();
    }
    return None;
}

impl Parser.expect_any(*kinds: TokenKind) -> LexToken {
    if self.current().kind in kinds {
        return self.advance();
    }
    expected = " | ".join([k.value for k in kinds]);
    self.emit_diag(
        f"Expected '{expected}', got '{self.current().kind.value}'", "E0001"
    );
    return self.advance();
}

impl Parser.expect(kind: TokenKind) -> LexToken {
    if self.check(kind) {
        return self.advance();
    }

    if kind
        in (
            TokenKind.RPAREN,
            TokenKind.RBRACE,
            TokenKind.RSQUARE,
            TokenKind.SEMI,
            TokenKind.COMMA
        ) {
        self.emit_diag(f"Missing '{kind.value}'", "E0002");
    } else {
        self.emit_diag(
            f"Expected '{kind.value}', got '{self.current().kind.value}'", "E0001"
        );
        return self.advance();
    }
    return self.current();
}

impl Parser.consume_uni(kind: TokenKind) -> int {
    tok = self.expect(kind);
    return self.make_uni_token(tok);
}

impl Parser.error(message: str) {
    self.error_count += 1;
    self.diags.append(
        SrcDiag(message=message, code_str="", loc=self.current().loc, is_error=True)
    );
}

impl Parser.emit_diag(
    message: str, code_str: str, loc: SourceLoc | None = None, help: str = ""
) {
    sloc = loc if loc is not None else self.current().loc;
    self.error_count += 1;
    self.diags.append(
        SrcDiag(message=message, code_str=code_str, loc=sloc, is_error=True, help=help)
    );
}

impl Parser.emit_warn(
    message: str, code_str: str, loc: SourceLoc | None = None, help: str = ""
) {
    sloc = loc if loc is not None else self.current().loc;
    self.diags.append(
        SrcDiag(message=message, code_str=code_str, loc=sloc, is_error=False, help=help)
    );
}

impl Parser.check_name -> bool {
    return self.check(TokenKind.NAME) or self.check(TokenKind.KWESC_NAME);
}

impl Parser.is_keyword_token -> bool {
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
        TokenKind.KW_GETTER,
        TokenKind.KW_SETTER,
        TokenKind.KW_DELETER,
        TokenKind.KW_SEM,
        TokenKind.KW_TEST,
        TokenKind.KW_GLOBAL,
        TokenKind.KW_IMPORT,
        TokenKind.KW_INCLUDE,
        TokenKind.KW_FROM,
        TokenKind.KW_AS,
        TokenKind.KW_IF,
        TokenKind.KW_ELIF,
        TokenKind.KW_ELSE,
        TokenKind.KW_FOR,
        TokenKind.KW_BY,
        TokenKind.KW_WHILE,
        TokenKind.KW_FOREVER,
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
        TokenKind.TYP_TYPE,
        TokenKind.TYP_I8,
        TokenKind.TYP_U8,
        TokenKind.TYP_I16,
        TokenKind.TYP_U16,
        TokenKind.TYP_I32,
        TokenKind.TYP_U32,
        TokenKind.TYP_I64,
        TokenKind.TYP_U64,
        TokenKind.TYP_F32,
        TokenKind.TYP_F64
    );
}

impl Parser.is_builtin_type_token -> bool {
    return self.check_any(
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
        TokenKind.TYP_TYPE,
        TokenKind.TYP_I8,
        TokenKind.TYP_U8,
        TokenKind.TYP_I16,
        TokenKind.TYP_U16,
        TokenKind.TYP_I32,
        TokenKind.TYP_U32,
        TokenKind.TYP_I64,
        TokenKind.TYP_U64,
        TokenKind.TYP_F32,
        TokenKind.TYP_F64
    );
}

impl Parser.expect_name -> LexToken {
    if self.check_name() {
        return self.advance();
    }
    self.emit_diag(f"Expected identifier, got '{self.current().kind.value}'", "E0003");
    return self.current();
}

impl Parser.make_uni_token(tok: LexToken) -> int {
    tok_name: str = TOKEN_KIND_TO_TOK[tok.kind.value]
        if tok.kind.value in TOKEN_KIND_TO_TOK
        else tok.kind.value;
    return self.b.mk_token(
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

impl Parser.make_name(tok: LexToken, is_enum_stmt: bool = False) -> int {
    val = tok.value;
    kwesc = False;
    if val.startswith("`") {
        val = val[1:];
        kwesc = True;
    } elif tok.kind == TokenKind.KWESC_NAME {
        kwesc = True;
    }
    return self.b.mk_name(
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

impl Parser.make_special_name(tok: LexToken) -> int {
    tok_name: str = TOKEN_KIND_TO_TOK[tok.kind.value]
        if tok.kind.value in TOKEN_KIND_TO_TOK
        else tok.kind.value;
    return self.b.mk_name(
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

impl Parser.make_name_or_special(tok: LexToken) -> int {
    if tok.kind == TokenKind.NAME or tok.kind == TokenKind.KWESC_NAME {
        return self.make_name(tok);
    }
    return self.make_special_name(tok);
}

impl Parser.parse_access_tag -> int {
    if self.match_tok(TokenKind.COLON) {
        colon_uni = self.make_uni_token(self.previous());
        if self.check_any(TokenKind.KW_PUB, TokenKind.KW_PRIV, TokenKind.KW_PROT) {
            access_tok = self.expect_any(
                TokenKind.KW_PUB, TokenKind.KW_PRIV, TokenKind.KW_PROT
            );
            return self.b.mk_sub_tag(
                tag=(at := self.make_uni_token(access_tok)), kid=[colon_uni, at]
            );
        }
    }
    return NIL;
}

impl Parser.make_string(tok: LexToken) -> int {
    return self.b.mk_string(
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

impl Parser.make_string_from_value(value: str) -> int {
    return self.b.mk_string(
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

impl Parser.make_int(tok: LexToken) -> int {
    return self.b.mk_int(
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

impl Parser.make_float(tok: LexToken) -> int {
    return self.b.mk_float(
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

impl Parser.make_bool(tok: LexToken) -> int {
    return self.b.mk_bool(
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

impl Parser.make_null(tok: LexToken) -> int {
    return self.b.mk_null(
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

impl Parser.make_ellipsis(tok: LexToken) -> int {
    return self.b.mk_ellipsis(
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

impl Parser.make_semi -> int {
    prev = self.previous();
    return self.b.mk_semi(
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
            TokenKind.KW_FOREVER,
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

impl Parser.parse -> int {
    self._tokens_len = len(self.tokens);
    self.b.root_id = self.parse_module();
    return self.b.root_id;
}

impl Parser.parse_module -> int {
    doc: int = NIL;
    body: list[int] = [];
    terminals: list[int] = [];
    for tok in self.tokens {
        terminals.append(self.make_uni_token(tok));
    }
    if self.check(TokenKind.STRING) {
        tok = self.expect(TokenKind.STRING);
        doc = self.make_string(tok);
    }
    while not self.at_end() {
        before = self.pos;
        stmt = self.parse_element_stmt();
        if stmt != NIL {
            body.append(stmt);
        }

        if self.pos == before and not self.at_end() {
            self.advance();
        }
    }
    kid: list[int] = [];
    if doc {
        kid.append(doc);
    }
    kid.extend(body);
    if len(kid) == 0 {
        kid.append(self.b.mk_empty_token());
    }
    mod_name = self.file_path;
    if mod_name {
        while mod_name and (mod_name.endswith("/") or mod_name.endswith("\\")) {
            mod_name = mod_name[:-1];
        }
        slash = mod_name.rfind("/");
        bslash = mod_name.rfind("\\");
        cut = slash if slash > bslash else bslash;
        base = mod_name[cut + 1:];
        if base.endswith(".jac") {
            mod_name = base[:-4];
        } else {
            dot = base.rfind(".");
            mod_name = base[:dot] if dot > 0 else base;
        }
    }
    return self.b.mk_module(
        name=mod_name, doc=doc, body=body, terminals=terminals, kid=kid
    );
}

impl Parser.parse_expression(allow_cast: bool = True) -> int {
    if self.check(TokenKind.KW_LAMBDA) {
        return self.parse_lambda_expr();
    }

    expr = self.parse_concurrent_expr(allow_cast);
    if self._check_js_arrow_fault() {
        expr = self._recover_js_arrow_fault(expr);
    }
    if self.match_tok(TokenKind.KW_IF) {
        if_uni = self.make_uni_token(self.previous());
        condition = self.parse_expression(allow_cast);
        else_uni = self.consume_uni(TokenKind.KW_ELSE);
        else_value = self.parse_expression(allow_cast);
        cond_cfg = self.b.mk_cfg_expr(expr=condition, kid=[condition]);
        val_cfg = self.b.mk_cfg_expr(expr=expr, kid=[expr]);
        else_cfg = self.b.mk_cfg_expr(expr=else_value, kid=[else_value]);
        return self.b.mk_if_else_expr(
            condition=cond_cfg,
            value=val_cfg,
            else_value=else_cfg,
            kid=[val_cfg, if_uni, cond_cfg, else_uni, else_cfg]
        );
    }
    return expr;
}

impl Parser._check_js_arrow_fault -> bool {
    if not self.check(TokenKind.EQ) {
        return False;
    }
    nxt = self.peek();
    if nxt.kind != TokenKind.GT {
        return False;
    }
    return self.current().loc.pos_end == nxt.loc.pos_start;
}

impl Parser._recover_removed_marker -> int {
    self.error(
        f"'{self.current().value}' placement markers were removed: "
            + "placement is inferred (override via [placement.pins] in "
            + "jac.toml; declare services in [scale.microservices.routes]). "
            + "Run 'jac fix placement' to migrate this file."
    );
    self.advance();
    return self.parse_element_stmt();
}

impl Parser._recover_js_arrow_fault(left: int) -> int {
    eq_tok = self.advance();
    gt_tok = self.advance();

    _arrow_span = SourceLoc(
        file_path=eq_tok.loc.file_path,
        line=eq_tok.loc.line,
        end_line=gt_tok.loc.end_line,
        col_start=eq_tok.loc.col_start,
        col_end=gt_tok.loc.col_end,
        pos_start=eq_tok.loc.pos_start,
        pos_end=gt_tok.loc.pos_end
    );
    self.emit_diag(
        "JavaScript arrow function syntax ('=>') is not supported in Jac",
        "E0025",
        loc=_arrow_span,
        help="Use Jac lambda syntax instead: 'lambda (e: ChangeEvent) { ... }' or 'lambda (x: int) { x + 1; }'."
    );
    if self.check(TokenKind.LBRACE) {
        self.advance();
        self.parse_code_block_stmts();
        if self.check(TokenKind.RBRACE) {
            self.advance();
        }
    } elif not self.check_any(
        TokenKind.SEMI,
        TokenKind.RBRACE,
        TokenKind.RPAREN,
        TokenKind.RSQUARE,
        TokenKind.COMMA,
        TokenKind.EOF
    ) {
        self.parse_expression();
    }
    return left;
}

impl Parser.parse_concurrent_expr(allow_cast: bool = True) -> int {
    if self.check_any(TokenKind.KW_FLOW, TokenKind.KW_WAIT) {
        tok = self.expect_any(TokenKind.KW_FLOW, TokenKind.KW_WAIT);
        target = self.parse_walrus_assign(allow_cast);
        uni_tok = self.make_uni_token(tok);
        return self.b.mk_concurrent_expr(
            tok=uni_tok, target=target, kid=[uni_tok, target]
        );
    }
    return self.parse_walrus_assign(allow_cast);
}

impl Parser.parse_walrus_assign(allow_cast: bool = True) -> int {
    expr = self.parse_by_expr(allow_cast);
    if self.check(TokenKind.WALRUS_EQ) {
        walrus_tok = self.expect(TokenKind.WALRUS_EQ);
        value = self.parse_by_expr(allow_cast);
        op = self.make_uni_token(walrus_tok);
        return self.b.mk_binary_expr(
            left=expr, op=op, right=value, kid=[expr, op, value]
        );
    }
    return expr;
}

impl Parser.parse_by_expr(allow_cast: bool = True) -> int {
    left = self.parse_pipe(allow_cast);
    if self.match_tok(TokenKind.KW_BY) {
        by_uni = self.make_uni_token(self.previous());
        right = self.parse_by_expr(allow_cast);
        return self.b.mk_binary_expr(
            left=left, op=by_uni, right=right, kid=[left, by_uni, right]
        );
    }
    return left;
}

impl Parser.parse_cast(allow_cast: bool = True) -> int {
    expr = self.parse_bitwise_or();
    while allow_cast and self.match_tok(TokenKind.KW_AS) {
        as_uni = self.make_uni_token(self.previous());
        cast_type = self.parse_cast_type();
        expr = self.b.mk_cast_expr(
            value=expr, cast_type=cast_type, kid=[expr, as_uni, cast_type]
        );
    }
    return expr;
}

impl Parser.parse_cast_type -> int {
    left = self.parse_atomic_chain();
    while self.match_tok(TokenKind.BW_OR) {
        op = self.make_uni_token(self.previous());
        right = self.parse_atomic_chain();
        left = self.b.mk_binary_expr(
            left=left, op=op, right=right, kid=[left, op, right]
        );
    }
    return left;
}

impl Parser.parse_pipe(allow_cast: bool = True) -> int {
    left = self.parse_pipe_back(allow_cast);
    while self.match_tok(TokenKind.PIPE_FWD) {
        op = self.make_uni_token(self.previous());
        right = self.parse_pipe_back(allow_cast);
        left = self.b.mk_binary_expr(
            left=left, op=op, right=right, kid=[left, op, right]
        );
    }
    return left;
}

impl Parser.parse_pipe_back(allow_cast: bool = True) -> int {
    left = self.parse_logical_or(allow_cast);
    while self.match_tok(TokenKind.PIPE_BKWD) {
        op = self.make_uni_token(self.previous());
        right = self.parse_logical_or(allow_cast);
        left = self.b.mk_binary_expr(
            left=left, op=op, right=right, kid=[left, op, right]
        );
    }
    return left;
}

impl Parser.parse_bitwise_or -> int {
    left = self.parse_bitwise_xor();
    while self.match_tok(TokenKind.BW_OR) {
        op = self.make_uni_token(self.previous());
        right = self.parse_bitwise_xor();
        left = self.b.mk_binary_expr(
            left=left, op=op, right=right, kid=[left, op, right]
        );
    }
    return left;
}

impl Parser.parse_bitwise_xor -> int {
    left = self.parse_bitwise_and();
    while self.match_tok(TokenKind.BW_XOR) {
        op = self.make_uni_token(self.previous());
        right = self.parse_bitwise_and();
        left = self.b.mk_binary_expr(
            left=left, op=op, right=right, kid=[left, op, right]
        );
    }
    return left;
}

impl Parser.parse_bitwise_and -> int {
    left = self.parse_shift();
    while self.match_tok(TokenKind.BW_AND) {
        op = self.make_uni_token(self.previous());
        right = self.parse_shift();
        left = self.b.mk_binary_expr(
            left=left, op=op, right=right, kid=[left, op, right]
        );
    }
    return left;
}

impl Parser.parse_shift -> int {
    left = self.parse_arithmetic();
    while self.check_any(TokenKind.LSHIFT, TokenKind.RSHIFT) {
        tok = self.expect_any(TokenKind.LSHIFT, TokenKind.RSHIFT);
        op = self.make_uni_token(tok);
        right = self.parse_arithmetic();
        left = self.b.mk_binary_expr(
            left=left, op=op, right=right, kid=[left, op, right]
        );
    }
    return left;
}

impl Parser.parse_logical_or(allow_cast: bool = True) -> int {
    left = self.parse_logical_and(allow_cast);
    while self.match_tok(TokenKind.KW_OR) {
        values: list[int] = [left];
        op = self.make_uni_token(self.previous());
        while True {
            values.append(self.parse_logical_and(allow_cast));
            if not self.match_tok(TokenKind.KW_OR) {
                break;
            }
        }
        cfg_values = [self.b.mk_cfg_expr(expr=v, kid=[v]) for v in values];
        kid: list[int] = [];
        for (i, cv) in enumerate(cfg_values) {
            kid.append(cv);
            if i < len(cfg_values) - 1 {
                kid.append(op);
            }
        }
        left = self.b.mk_bool_expr(op=op, values=cfg_values, kid=kid);
    }
    return left;
}

impl Parser.parse_logical_and(allow_cast: bool = True) -> int {
    left = self.parse_logical_not(allow_cast);
    while self.match_tok(TokenKind.KW_AND) {
        values: list[int] = [left];
        op = self.make_uni_token(self.previous());
        while True {
            values.append(self.parse_logical_not(allow_cast));
            if not self.match_tok(TokenKind.KW_AND) {
                break;
            }
        }
        cfg_values = [self.b.mk_cfg_expr(expr=v, kid=[v]) for v in values];
        kid: list[int] = [];
        for (i, cv) in enumerate(cfg_values) {
            kid.append(cv);
            if i < len(cfg_values) - 1 {
                kid.append(op);
            }
        }
        left = self.b.mk_bool_expr(op=op, values=cfg_values, kid=kid);
    }
    return left;
}

impl Parser.parse_logical_not(allow_cast: bool = True) -> int {
    if self.match_tok(TokenKind.KW_NOT) {
        op = self.make_uni_token(self.previous());
        operand = self.parse_logical_not(allow_cast);
        return self.b.mk_unary_expr(operand=operand, op=op, kid=[op, operand]);
    }
    return self.parse_compare(allow_cast);
}

impl Parser.parse_compare(allow_cast: bool = True) -> int {
    left = self.parse_cast(allow_cast);
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
        rights: list[int] = [];
        ops: list[int] = [];
        kid: list[int] = [left];
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
            op_tok = self.expect_any(
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
            );
            op = self.make_uni_token(op_tok);
            ops.append(op);
            kid.append(op);
            right = self.parse_cast(allow_cast);
            rights.append(right);
            kid.append(right);
        }
        return self.b.mk_compare_expr(left=left, rights=rights, ops=ops, kid=kid);
    }
    return left;
}

impl Parser.parse_arithmetic -> int {
    left = self.parse_term();
    while self.check_any(TokenKind.PLUS, TokenKind.MINUS) {
        tok = self.expect_any(TokenKind.PLUS, TokenKind.MINUS);
        op = self.make_uni_token(tok);
        right = self.parse_term();
        left = self.b.mk_binary_expr(
            left=left, op=op, right=right, kid=[left, op, right]
        );
    }
    return left;
}

impl Parser.parse_term -> int {
    left = self.parse_power();
    while self.check_any(
        TokenKind.STAR_MUL,
        TokenKind.DIV,
        TokenKind.FLOOR_DIV,
        TokenKind.MOD,
        TokenKind.DECOR_OP
    ) {
        tok = self.expect_any(
            TokenKind.STAR_MUL,
            TokenKind.DIV,
            TokenKind.FLOOR_DIV,
            TokenKind.MOD,
            TokenKind.DECOR_OP
        );
        op = self.make_uni_token(tok);
        right = self.parse_power();
        left = self.b.mk_binary_expr(
            left=left, op=op, right=right, kid=[left, op, right]
        );
    }
    return left;
}

impl Parser.parse_power -> int {
    left = self.parse_factor();
    if self.match_tok(TokenKind.STAR_POW) {
        op = self.make_uni_token(self.previous());
        right = self.parse_power();
        left = self.b.mk_binary_expr(
            left=left, op=op, right=right, kid=[left, op, right]
        );
    }
    return left;
}

impl Parser.parse_factor -> int {
    if self.check_any(TokenKind.BW_NOT, TokenKind.MINUS, TokenKind.PLUS) {
        tok = self.expect_any(TokenKind.BW_NOT, TokenKind.MINUS, TokenKind.PLUS);
        op = self.make_uni_token(tok);
        operand = self.parse_factor();
        return self.b.mk_unary_expr(operand=operand, op=op, kid=[op, operand]);
    }
    return self.parse_connect();
}

impl Parser.parse_connect -> int {
    left = self.parse_atomic_pipe();
    while True {
        conn_op = self.parse_connect_op();
        if conn_op == NIL {
            break;
        }
        if self._recover_missing_connect_rhs() {
            break;
        }
        right = self.parse_atomic_pipe();
        kid: list[int] = [left, conn_op, right];
        left = self.b.mk_binary_expr(left=left, op=conn_op, right=right, kid=kid);
    }
    return left;
}

impl Parser._recover_missing_connect_rhs -> bool {
    if not self.check_any(
        TokenKind.SEMI,
        TokenKind.RBRACE,
        TokenKind.RPAREN,
        TokenKind.RSQUARE,
        TokenKind.COMMA,
        TokenKind.EOF
    ) {
        return False;
    }
    self.emit_diag(
        "Connect/disconnect operator requires a right operand",
        "E0026",
        help="Connect (`++>`, `+>:T:+>`) and disconnect (`del -->`, `del ->:T:->`) operators are binary -- supply the right-hand side, e.g. `a ++> b;` or `a del --> b;`."
    );
    return True;
}

impl Parser.parse_edge_op_ref_inline -> int {
    return self.parse_edge_op_ref();
}

impl Parser.parse_connect_op -> int {
    if self.check(TokenKind.KW_DELETE)
        and self.check_peek_any(
            TokenKind.ARROW_R,
            TokenKind.ARROW_L,
            TokenKind.ARROW_BI,
            TokenKind.ARROW_R_P1,
            TokenKind.ARROW_L_P1
        ) {
        del_tok = self.expect(TokenKind.KW_DELETE);

        edge_op = self.parse_edge_op_ref_inline();
        if edge_op {
            return self.b.mk_disconnect_op(
                edge_spec=edge_op, kid=[self.make_uni_token(del_tok), edge_op]
            );
        }
    }

    if self.match_tok(TokenKind.CARROW_R) {
        tok = self.make_uni_token(self.previous());
        return self.b.mk_connect_op(
            conn_type=NIL, conn_assign=NIL, edge_dir=EdgeDir.OUT, kid=[tok]
        );
    }
    if self.match_tok(TokenKind.CARROW_R_P1) {
        start_tok = self.make_uni_token(self.previous());
        conn_type = self.parse_expression();
        conn_assign: int = NIL;
        kid: list[int] = [start_tok, conn_type];
        if self.match_tok(TokenKind.COLON) {
            kid.append(self.make_uni_token(self.previous()));

            assigns: list[int] = [];
            ac_kid: list[int] = [];
            while not self.check(TokenKind.CARROW_R_P2) and not self.at_end() {
                key_name = self.make_name(self.expect_name());
                eq_uni = self.consume_uni(TokenKind.EQ);
                val_expr = self.parse_expression();
                item = self.b.mk_k_w_pair(
                    key=key_name, value=val_expr, kid=[key_name, eq_uni, val_expr]
                );
                assigns.append(item);
                ac_kid.append(item);
                if not self.match_tok(TokenKind.COMMA) {
                    break;
                }
                ac_kid.append(self.make_uni_token(self.previous()));
            }
            if assigns {
                conn_assign = self.b.mk_assign_compr(assigns=assigns, kid=ac_kid);
                kid.append(conn_assign);
            }
        }
        if not self.check(TokenKind.CARROW_R_P2) {
            self.emit_diag(
                "Expected ':+>' to close forward typed connection -- did you mean '+>: <EdgeType> :+> <node>'?",
                "E0027"
            );
            self.synchronize();
            return NIL;
        }
        end_uni = self.consume_uni(TokenKind.CARROW_R_P2);
        kid.append(end_uni);
        return self.b.mk_connect_op(
            conn_type=conn_type, conn_assign=conn_assign, edge_dir=EdgeDir.OUT, kid=kid
        );
    }

    if self.match_tok(TokenKind.CARROW_L) {
        tok = self.make_uni_token(self.previous());
        return self.b.mk_connect_op(
            conn_type=NIL, conn_assign=NIL, edge_dir=EdgeDir.IN, kid=[tok]
        );
    }
    if self.match_tok(TokenKind.CARROW_L_P1) {
        start_tok = self.make_uni_token(self.previous());
        conn_type = self.parse_expression();
        conn_assign: int = NIL;
        kid: list[int] = [start_tok, conn_type];
        if self.match_tok(TokenKind.COLON) {
            kid.append(self.make_uni_token(self.previous()));
            assigns: list[int] = [];
            ac_kid: list[int] = [];
            while not self.check_any(TokenKind.CARROW_L_P2, TokenKind.CARROW_R_P2)
                and not self.at_end() {
                key_name = self.make_name(self.expect_name());
                eq_uni = self.consume_uni(TokenKind.EQ);
                val_expr = self.parse_expression();
                item = self.b.mk_k_w_pair(
                    key=key_name, value=val_expr, kid=[key_name, eq_uni, val_expr]
                );
                assigns.append(item);
                ac_kid.append(item);
                if not self.match_tok(TokenKind.COMMA) {
                    break;
                }
                ac_kid.append(self.make_uni_token(self.previous()));
            }
            if assigns {
                conn_assign = self.b.mk_assign_compr(assigns=assigns, kid=ac_kid);
                kid.append(conn_assign);
            }
        }

        if self.match_tok(TokenKind.CARROW_L_P2) {
            kid.append(self.make_uni_token(self.previous()));
            return self.b.mk_connect_op(
                conn_type=conn_type,
                conn_assign=conn_assign,
                edge_dir=EdgeDir.IN,
                kid=kid
            );
        } elif self.match_tok(TokenKind.CARROW_R_P2) {
            kid.append(self.make_uni_token(self.previous()));
            return self.b.mk_connect_op(
                conn_type=conn_type,
                conn_assign=conn_assign,
                edge_dir=EdgeDir.ANY,
                kid=kid
            );
        } else {
            self.emit_diag(
                "Expected ':<+' or ':+>' to close backward typed connection -- did you mean '<+: <EdgeType> :<+ <node>' (backward) or '<+: <EdgeType> :+> <node>' (bidirectional)?",
                "E0028"
            );
            self.synchronize();
            return NIL;
        }
    }

    if self.match_tok(TokenKind.CARROW_BI) {
        tok = self.make_uni_token(self.previous());
        return self.b.mk_connect_op(
            conn_type=NIL, conn_assign=NIL, edge_dir=EdgeDir.ANY, kid=[tok]
        );
    }
    return NIL;
}

impl Parser.parse_atomic_pipe -> int {
    left = self.parse_atomic_pipe_back();
    while self.match_tok(TokenKind.A_PIPE_FWD) {
        op = self.make_uni_token(self.previous());
        right = self.parse_atomic_pipe_back();
        left = self.b.mk_binary_expr(
            left=left, op=op, right=right, kid=[left, op, right]
        );
    }
    return left;
}

impl Parser.parse_atomic_pipe_back -> int {
    left = self.parse_spawn();
    while self.match_tok(TokenKind.A_PIPE_BKWD) {
        op = self.make_uni_token(self.previous());
        right = self.parse_spawn();
        left = self.b.mk_binary_expr(
            left=left, op=op, right=right, kid=[left, op, right]
        );
    }
    return left;
}

impl Parser.parse_spawn -> int {
    if self.check(TokenKind.KW_SPAWN) {
        op_tok = self.expect(TokenKind.KW_SPAWN);
        op = self.make_uni_token(op_tok);
        target = self.parse_unpack();

        return self.b.mk_unary_expr(operand=target, op=op, kid=[op, target]);
    }
    left = self.parse_unpack();
    while self.match_tok(TokenKind.KW_SPAWN) {
        op = self.make_uni_token(self.previous());
        right = self.parse_unpack();
        left = self.b.mk_binary_expr(
            left=left, op=op, right=right, kid=[left, op, right]
        );
    }
    return left;
}

impl Parser.parse_unpack -> int {
    if self.match_tok(TokenKind.STAR_MUL) {
        op = self.make_uni_token(self.previous());
        target = self.parse_ref();
        return self.b.mk_unary_expr(operand=target, op=op, kid=[op, target]);
    }
    return self.parse_ref();
}

impl Parser.parse_ref -> int {
    if self.match_tok(TokenKind.KW_OWN) {
        own_op = self.make_uni_token(self.previous());
        own_target = self.parse_await_expr();
        return self.b.mk_unary_expr(
            operand=own_target,
            op=own_op,
            ownership=OwnershipKind.OWN,
            kid=[own_op, own_target]
        );
    }
    if self.match_tok(TokenKind.KW_IMM) {
        imm_op = self.make_uni_token(self.previous());
        imm_target = self.parse_await_expr();
        return self.b.mk_unary_expr(
            operand=imm_target,
            op=imm_op,
            ownership=OwnershipKind.IMM,
            kid=[imm_op, imm_target]
        );
    }
    if self.match_tok(TokenKind.BW_AND) {
        raw_tok = self.previous();
        op = self.make_uni_token(raw_tok);
        kids: list[int] = [op];

        if self.check(TokenKind.LPAREN)
            or (
                not self.at_end() and self.current().loc.pos_start > raw_tok.loc.pos_end
            ) {
            target = self.parse_await_expr();
            kids.append(target);
            return self.b.mk_unary_expr(
                operand=target, op=op, ownership=OwnershipKind.BORROW, kid=kids
            );
        }

        is_mut = False;
        if self.check(TokenKind.KW_MUT) {
            mut_tok = self.expect(TokenKind.KW_MUT);
            kids.append(self.make_uni_token(mut_tok));
            is_mut = True;
        }
        target = self.parse_await_expr();
        kids.append(target);
        return self.b.mk_unary_expr(
            operand=target,
            op=op,
            ownership=OwnershipKind.MUT_BORROW if is_mut else OwnershipKind.BORROW,
            kid=kids
        );
    }
    return self.parse_await_expr();
}

impl Parser.parse_await_expr -> int {
    if self.match_tok(TokenKind.KW_AWAIT) {
        await_tok = self.make_uni_token(self.previous());
        expr = self.parse_pipe_call();
        return self.b.mk_await_expr(target=expr, kid=[await_tok, expr]);
    }
    return self.parse_pipe_call();
}

impl Parser.parse_pipe_call -> int {
    if self.check_any(TokenKind.PIPE_FWD, TokenKind.A_PIPE_FWD) {
        tok = self.expect_any(TokenKind.PIPE_FWD, TokenKind.A_PIPE_FWD);
        op = self.make_uni_token(tok);
        target = self.parse_atomic_chain();
        return self.b.mk_unary_expr(operand=target, op=op, kid=[op, target]);
    }
    return self.parse_atomic_chain();
}

impl Parser.parse_atomic_chain -> int {
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
            null_ok_uni: int = NIL;
            dot_uni: int = NIL;
            if null_ok {
                null_ok_uni = self.make_uni_token(first_consumed_tok);
            } else {
                dot_uni = self.make_uni_token(first_consumed_tok);
            }
            if null_ok
                and self.check_any(
                    TokenKind.DOT, TokenKind.DOT_FWD, TokenKind.DOT_BKWD
                ) {
                dot_kind2 = self.current().kind;
                is_dot_fwd = dot_kind2 == TokenKind.DOT_FWD;
                is_dot_bkwd = dot_kind2 == TokenKind.DOT_BKWD;
                dot_uni = self.make_uni_token(
                    self.expect_any(
                        TokenKind.DOT, TokenKind.DOT_FWD, TokenKind.DOT_BKWD
                    )
                );
            }
            if not dot_uni and null_ok and null_ok_uni != NIL {
                dot_uni = null_ok_uni;
            }

            attr: int = NIL;
            if self.check_name() {
                name_tok = self.expect_name();
                attr = self.make_name(name_tok);
            } elif self.is_keyword_token() {
                name_tok = self.advance();
                attr = self._make_attr_from_keyword(name_tok);
            }
            if not attr {
                dot_tok = first_consumed_tok;
                attr = self.b.mk_name(
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
            kid: list[int] = [expr];
            if null_ok and null_ok_uni {
                kid.append(null_ok_uni);
            }
            kid.append(dot_uni);
            kid.append(attr);
            target_node = expr if not is_dot_bkwd else attr;
            right_node = attr if not is_dot_bkwd else expr;
            expr = self.b.mk_atom_trailer(
                target=target_node,
                right=right_node,
                is_attr=True,
                is_null_ok=null_ok,
                kid=kid
            );
        } elif self.check(TokenKind.LPAREN) {
            if self.check_peek(TokenKind.NULL_OK) {
                self.emit_diag(
                    "Parenthesized filter syntax '(?:...)' was removed. Use bracket syntax '[?:...]' instead.",
                    "E0048",
                    loc=self.current().loc,
                    help="Replace (?:Type, cond) with [?:Type, cond]"
                );
                self.expect(TokenKind.LPAREN);
                filter_expr: int = self.parse_filter_compr_inner();

                kid = [expr, filter_expr];
                expr = self.b.mk_atom_trailer(
                    target=expr,
                    right=filter_expr,
                    is_attr=False,
                    is_null_ok=False,
                    kid=kid
                );
            } elif self.check_peek(TokenKind.EQ) {
                self.expect(TokenKind.LPAREN);
                assign_expr = self.parse_assign_compr_inner();
                kid = [expr, assign_expr];
                expr = self.b.mk_atom_trailer(
                    target=expr,
                    right=assign_expr,
                    is_attr=False,
                    is_null_ok=False,
                    kid=kid
                );
            } else {
                lp_uni = self.make_uni_token(self.expect(TokenKind.LPAREN));
                call_kid: list[int] = [expr, lp_uni];
                args = self.parse_call_args(call_kid);
                rp_uni = self.consume_uni(TokenKind.RPAREN);
                call_kid.append(rp_uni);
                first_arg = args[0] if len(args) == 1 else NIL;
                if self.b.kind_of(first_arg) in KS_GEN_COMPR {
                    lparen_tok = call_kid[1];
                    rparen_tok = call_kid[len(call_kid) - 1];
                    new_gc_kid: list[int] = [lparen_tok];
                    for c in self.b.kid_ids(first_arg) {
                        new_gc_kid.append(c);
                    }
                    new_gc_kid.append(rparen_tok);
                    gencompr = self.b.mk_gen_compr(
                        out_expr=self.b.arg_node(first_arg, 0),
                        compr=self.b.arg_list(first_arg, 1),
                        kid=new_gc_kid
                    );
                    args = [gencompr];
                    call_kid = [expr, gencompr];
                }
                expr = self.b.mk_func_call(
                    target=expr, params=args, genai_call=NIL, kid=call_kid
                );
            }
        } elif self.check(TokenKind.LSQUARE) and self.check_peek(TokenKind.NULL_OK) {
            self.expect(TokenKind.LSQUARE);
            filter_expr = self.parse_filter_compr_bracket();
            kid = [expr, filter_expr];
            expr = self.b.mk_atom_trailer(
                target=expr, right=filter_expr, is_attr=False, is_null_ok=False, kid=kid
            );
        } elif (self.check(TokenKind.NULL_OK) and self.check_peek(TokenKind.LSQUARE))
            or self.check(TokenKind.LSQUARE) {
            is_null_ok_index = False;
            null_ok_idx_uni: int = NIL;
            if self.match_tok(TokenKind.NULL_OK) {
                is_null_ok_index = True;
                null_ok_idx_uni = self.make_uni_token(self.previous());
            }
            index_slice = self.parse_index_slice();
            kid = [expr];
            if is_null_ok_index and null_ok_idx_uni {
                kid.append(null_ok_idx_uni);
            }
            kid.append(index_slice);
            expr = self.b.mk_atom_trailer(
                target=expr,
                right=index_slice,
                is_attr=False,
                is_null_ok=is_null_ok_index,
                kid=kid
            );
        } else {
            break;
        }
    }
    return expr;
}

impl Parser._make_attr_from_keyword(name_tok: LexToken) -> (int) {
    special_kinds: list[TokenKind] = [
        TokenKind.KW_INIT,
        TokenKind.KW_POST_INIT,
        TokenKind.KW_SELF,
        TokenKind.KW_PROPS,
        TokenKind.KW_SUPER,
        TokenKind.KW_ROOT,
        TokenKind.KW_HERE,
        TokenKind.KW_VISITOR
    ];
    for sk in special_kinds {
        if name_tok.kind == sk {
            return self.b.mk_special_var_ref(
                var=self.make_special_name(name_tok), is_enum_stmt=False
            );
        }
    }
    return self.make_special_name(name_tok);
}

impl Parser.parse_index_slice -> int {
    lsq_uni = self.consume_uni(TokenKind.LSQUARE);
    first_expr: int = NIL;
    if not self.check_any(TokenKind.RSQUARE, TokenKind.COLON) {
        first_expr = self.parse_expression();
    }
    if self.check(TokenKind.COLON) {
        index_kid: list[int] = [lsq_uni];
        slices: list[int] = [];

        s1_kid: list[int] = [];
        if first_expr != NIL {
            s1_kid.append(first_expr);
        }
        colon1_uni = self.consume_uni(TokenKind.COLON);
        s1_kid.append(colon1_uni);
        stop: int = NIL;
        if not self.check_any(TokenKind.COLON, TokenKind.RSQUARE, TokenKind.COMMA) {
            stop = self.parse_expression();
            s1_kid.append(stop);
        }
        step: int = NIL;
        if self.match_tok(TokenKind.COLON) {
            s1_kid.append(self.make_uni_token(self.previous()));
            if not self.check_any(TokenKind.RSQUARE, TokenKind.COMMA) {
                step = self.parse_expression();
                s1_kid.append(step);
            }
        }
        slice1 = self.b.mk_slice(start=first_expr, stop=stop, step=step, kid=s1_kid);
        slices.append(slice1);
        index_kid.append(slice1);
        while self.match_tok(TokenKind.COMMA) {
            index_kid.append(self.make_uni_token(self.previous()));
            sn_kid: list[int] = [];
            s2: int = NIL;
            if not self.check(TokenKind.COLON) {
                s2 = self.parse_expression();
                sn_kid.append(s2);
            }
            colon_s2_uni = self.consume_uni(TokenKind.COLON);
            sn_kid.append(colon_s2_uni);
            e2: int = NIL;
            if not self.check_any(
                TokenKind.COLON, TokenKind.RSQUARE, TokenKind.COMMA
            ) {
                e2 = self.parse_expression();
                sn_kid.append(e2);
            }
            t2: int = NIL;
            if self.match_tok(TokenKind.COLON) {
                sn_kid.append(self.make_uni_token(self.previous()));
                if not self.check_any(TokenKind.RSQUARE, TokenKind.COMMA) {
                    t2 = self.parse_expression();
                    sn_kid.append(t2);
                }
            }
            slice_n = self.b.mk_slice(start=s2, stop=e2, step=t2, kid=sn_kid);
            slices.append(slice_n);
            index_kid.append(slice_n);
        }
        rsq_uni = self.consume_uni(TokenKind.RSQUARE);
        index_kid.append(rsq_uni);
        return self.b.mk_index_slice(slices=slices, is_range=True, kid=index_kid);
    } else {
        indices: list[int] = [];
        list_kid: list[int] = [lsq_uni];
        if first_expr != NIL {
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
        list_val = self.b.mk_list_val(values=indices, kid=list_kid);
        if len(indices) == 1 {
            idx_expr = indices[0];
            slice_node = self.b.mk_slice(
                start=idx_expr, stop=NIL, step=NIL, kid=[list_val]
            );
        } else {
            idx_expr = self.b.mk_tuple_val(values=indices, kid=list_kid);
            slice_node = self.b.mk_slice(
                start=idx_expr, stop=NIL, step=NIL, kid=[idx_expr]
            );
        }
        return self.b.mk_index_slice(
            slices=[slice_node], is_range=False, kid=[slice_node]
        );
    }
}

impl Parser.parse_call_args(kid: list[int]) -> list[int] {
    args: list[int] = [];
    if self.check(TokenKind.RPAREN) {
        return args;
    }

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

    if not self.check(TokenKind.RPAREN) and not self.at_end() {
        self.emit_diag("Missing ','", "E0002");
        self.emit_diag("Unexpected token", "E0006");

        while not self.check(TokenKind.RPAREN) and not self.at_end() {
            self.advance();
        }
    }
    return args;
}

impl Parser.parse_call_arg -> int {
    if (self.check_name() or self.is_keyword_token())
        and self.check_peek(TokenKind.EQ) {
        name_tok = self.advance();
        name: int;
        if name_tok.kind == TokenKind.NAME or name_tok.kind == TokenKind.KWESC_NAME {
            name = self.make_name(name_tok);
        } elif name_tok.kind
            in [
                TokenKind.KW_SELF,
                TokenKind.KW_PROPS,
                TokenKind.KW_SUPER,
                TokenKind.KW_ROOT,
                TokenKind.KW_HERE,
                TokenKind.KW_VISITOR
            ] {
            name = self.b.mk_special_var_ref(
                var=self.make_special_name(name_tok), is_enum_stmt=False
            );
        } else {
            name = self.make_special_name(name_tok);
        }
        eq_uni = self.consume_uni(TokenKind.EQ);
        value = self.parse_expression();
        return self.b.mk_k_w_pair(key=name, value=value, kid=[name, eq_uni, value]);
    }

    if self.check(TokenKind.STAR_POW) {
        star_tok = self.expect(TokenKind.STAR_POW);
        star = self.make_uni_token(star_tok);
        value = self.parse_expression();
        return self.b.mk_k_w_pair(key=NIL, value=value, kid=[star, value]);
    }

    if self.check(TokenKind.STAR_MUL) {
        star_tok = self.expect(TokenKind.STAR_MUL);
        star = self.make_uni_token(star_tok);
        value = self.parse_expression();
        return self.b.mk_unary_expr(op=star, operand=value, kid=[star, value]);
    }

    expr = self.parse_expression();

    if self.check(TokenKind.KW_FOR)
        or (self.check(TokenKind.KW_ASYNC) and self.check_peek(TokenKind.KW_FOR)) {
        comprs = self.parse_comprehension_clauses();
        kid: list[int] = [expr];
        kid.extend(comprs);
        return self.b.mk_gen_compr(compr=comprs, out_expr=expr, kid=kid);
    }
    return expr;
}

impl Parser.parse_filter_compr_inner -> int {
    lp_uni = self.make_uni_token(self.previous());
    kid: list[int] = [lp_uni];
    f_type = NIL;

    null_ok_uni = self.consume_uni(TokenKind.NULL_OK);
    kid.append(null_ok_uni);

    if self.match_tok(TokenKind.COLON) {
        kid.append(self.make_uni_token(self.previous()));
        f_type = self.parse_expression();
        kid.append(f_type);
    }

    compares: list[int] = [];

    if f_type and self.match_tok(TokenKind.COMMA) {
        kid.append(self.make_uni_token(self.previous()));
    }
    if not self.check(TokenKind.RPAREN) {
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
    return self.b.mk_filter_compr(f_type=f_type, compares=compares, kid=kid);
}

impl Parser.parse_filter_compr_bracket -> int {
    lsq_uni = self.make_uni_token(self.previous());
    kid: list[int] = [lsq_uni];
    f_type = NIL;

    null_ok_uni = self.consume_uni(TokenKind.NULL_OK);
    kid.append(null_ok_uni);

    if self.match_tok(TokenKind.COLON) {
        kid.append(self.make_uni_token(self.previous()));
        f_type = self.parse_expression();
        kid.append(f_type);
    }

    compares: list[int] = [];

    if f_type and self.match_tok(TokenKind.COMMA) {
        kid.append(self.make_uni_token(self.previous()));
    }
    if not self.check(TokenKind.RSQUARE) {
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
    rsq_uni = self.consume_uni(TokenKind.RSQUARE);
    kid.append(rsq_uni);
    return self.b.mk_filter_compr(f_type=f_type, compares=compares, kid=kid);
}

impl Parser.parse_assign_compr_inner -> int {
    lp_uni = self.make_uni_token(self.previous());
    kid: list[int] = [lp_uni];
    eq_lead_uni = self.consume_uni(TokenKind.EQ);
    kid.append(eq_lead_uni);
    assigns: list[int] = [];

    if not self.check(TokenKind.RPAREN) {
        name_tok = self.expect_name();
        name = self.make_name(name_tok);
        eq_uni = self.consume_uni(TokenKind.EQ);
        value = self.parse_expression();
        kw = self.b.mk_k_w_pair(key=name, value=value, kid=[name, eq_uni, value]);
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
            kw = self.b.mk_k_w_pair(key=name, value=value, kid=[name, eq_uni2, value]);
            assigns.append(kw);
            kid.append(kw);
        }
    }
    rp_uni = self.consume_uni(TokenKind.RPAREN);
    kid.append(rp_uni);
    return self.b.mk_assign_compr(assigns=assigns, kid=kid);
}

impl Parser.parse_atom_literal -> int {
    if self.check(TokenKind.INT) {
        tok = self.expect(TokenKind.INT);
        return self.make_int(tok);
    }
    if self.check_any(TokenKind.HEX, TokenKind.BIN, TokenKind.OCT) {
        tok = self.expect_any(TokenKind.HEX, TokenKind.BIN, TokenKind.OCT);
        return self.make_int(tok);
    }
    if self.check(TokenKind.FLOAT) {
        tok = self.expect(TokenKind.FLOAT);
        return self.make_float(tok);
    }
    if self.check(TokenKind.BOOL) {
        tok = self.expect(TokenKind.BOOL);
        return self.make_bool(tok);
    }
    if self.check(TokenKind.NULL) {
        tok = self.expect(TokenKind.NULL);
        return self.make_null(tok);
    }
    if self.check(TokenKind.ELLIPSIS) {
        tok = self.expect(TokenKind.ELLIPSIS);
        return self.make_ellipsis(tok);
    }
    return NIL;
}

impl Parser.parse_multistring -> int {
    strings: list[int] = [];

    if self.check(TokenKind.NAME)
        and self.current().value
            in ["r", "b", "rb", "br", "R", "B", "rB", "Rb", "bR", "Br", "BR", "RB"]
        and self.check_peek(TokenKind.STRING) {
        prefix_tok = self.expect(TokenKind.NAME);
        str_tok = self.expect(TokenKind.STRING);
        combined = self.make_string(str_tok);
        self.b.set_arg_str(
            combined, 1, prefix_tok.value + (self.b.arg_str(combined, 1) or "")
        );
        strings.append(combined);
    } elif self.check(TokenKind.STRING) {
        first_tok = self.expect(TokenKind.STRING);
        strings.append(self.make_string(first_tok));
    } elif self.check_any(
        TokenKind.F_DQ_START,
        TokenKind.F_SQ_START,
        TokenKind.F_TDQ_START,
        TokenKind.F_TSQ_START,
        TokenKind.RF_DQ_START,
        TokenKind.RF_SQ_START,
        TokenKind.RF_TDQ_START,
        TokenKind.RF_TSQ_START
    ) {
        strings.append(self.parse_fstring());
    } else {
        return NIL;
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
        )
        or (
            self.check(TokenKind.NAME)
            and self.current().value
                in ["r", "b", "rb", "br", "R", "B", "rB", "Rb", "bR", "Br", "BR", "RB"]
            and self.check_peek(TokenKind.STRING)
        ) {
        if self.check(TokenKind.NAME) and self.check_peek(TokenKind.STRING) {
            ptok = self.expect(TokenKind.NAME);
            stok = self.expect(TokenKind.STRING);
            s = self.make_string(stok);
            self.b.set_arg_str(s, 1, ptok.value + (self.b.arg_str(s, 1) or ""));
            strings.append(s);
        } elif self.check(TokenKind.STRING) {
            tok = self.expect(TokenKind.STRING);
            strings.append(self.make_string(tok));
        } else {
            strings.append(self.parse_fstring());
        }
    }
    return self.b.mk_multi_string(strings=strings, kid=strings);
}

impl Parser.parse_builtin_type -> int {
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
        TokenKind.TYP_TYPE,
        TokenKind.TYP_I8,
        TokenKind.TYP_U8,
        TokenKind.TYP_I16,
        TokenKind.TYP_U16,
        TokenKind.TYP_I32,
        TokenKind.TYP_U32,
        TokenKind.TYP_I64,
        TokenKind.TYP_U64,
        TokenKind.TYP_F32,
        TokenKind.TYP_F64
    ) {
        tok = self.expect_any(
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
            TokenKind.TYP_TYPE,
            TokenKind.TYP_I8,
            TokenKind.TYP_U8,
            TokenKind.TYP_I16,
            TokenKind.TYP_U16,
            TokenKind.TYP_I32,
            TokenKind.TYP_U32,
            TokenKind.TYP_I64,
            TokenKind.TYP_U64,
            TokenKind.TYP_F32,
            TokenKind.TYP_F64
        );
        builtin_name: str = TOKEN_KIND_TO_TOK[tok.kind.value]
            if tok.kind.value in TOKEN_KIND_TO_TOK
            else tok.kind.value;
        return self.b.mk_builtin_type(
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
    return NIL;
}

impl Parser.parse_special_ref -> int {
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
        return self.b.mk_special_var_ref(var=var_name, is_enum_stmt=False);
    }

    if self.check_any(
        TokenKind.KW_NODE,
        TokenKind.KW_EDGE,
        TokenKind.KW_WALKER,
        TokenKind.KW_OBJECT,
        TokenKind.KW_CLASS,
        TokenKind.KW_ENUM
    ) {
        tok = self.expect_any(
            TokenKind.KW_NODE,
            TokenKind.KW_EDGE,
            TokenKind.KW_WALKER,
            TokenKind.KW_OBJECT,
            TokenKind.KW_CLASS,
            TokenKind.KW_ENUM
        );
        return self.make_special_name(tok);
    }
    return NIL;
}

impl Parser.parse_atom -> int {
    if self.check_any(
        TokenKind.INT,
        TokenKind.HEX,
        TokenKind.BIN,
        TokenKind.OCT,
        TokenKind.FLOAT,
        TokenKind.BOOL,
        TokenKind.NULL,
        TokenKind.ELLIPSIS
    ) {
        lit = self.parse_atom_literal();
        if lit != NIL {
            return lit;
        }
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
        )
        or (
            self.check(TokenKind.NAME)
            and self.current().value
                in ["r", "b", "rb", "br", "R", "B", "rB", "Rb", "bR", "Br", "BR", "RB"]
            and self.check_peek(TokenKind.STRING)
        ) {
        ms_val = self.parse_multistring();
        if ms_val != NIL {
            return ms_val;
        }
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
        bt = self.parse_builtin_type();
        if bt != NIL {
            return bt;
        }
    }

    if self.check_any(
        TokenKind.KW_SELF,
        TokenKind.KW_SUPER,
        TokenKind.KW_HERE,
        TokenKind.KW_ROOT,
        TokenKind.KW_VISITOR,
        TokenKind.KW_PROPS,
        TokenKind.KW_INIT,
        TokenKind.KW_POST_INIT,
        TokenKind.KW_NODE,
        TokenKind.KW_EDGE,
        TokenKind.KW_WALKER,
        TokenKind.KW_OBJECT,
        TokenKind.KW_CLASS,
        TokenKind.KW_ENUM
    ) {
        sref = self.parse_special_ref();
        if sref != NIL {
            return sref;
        }
    }
    if self.check(TokenKind.NAME)
        or self.check(TokenKind.KWESC_NAME)
        or self.is_keyword_token() {
        tok = self.advance();
        if tok.kind != TokenKind.NAME and tok.kind != TokenKind.KWESC_NAME {
            return self.make_special_name(tok);
        }
        return self.make_name(tok);
    }

    if self.check(TokenKind.STAR_MUL) {
        star_tok = self.expect(TokenKind.STAR_MUL);
        star = self.make_uni_token(star_tok);
        operand = self.parse_expression();
        return self.b.mk_unary_expr(op=star, operand=operand, kid=[star, operand]);
    }
    if self.check(TokenKind.LPAREN) {
        return self.parse_paren_expr();
    }
    if self.check(TokenKind.LSQUARE) {
        return self.parse_bracket_expr();
    }
    if self.check(TokenKind.LBRACE) {
        return self.parse_brace_expr();
    }

    if self.check(TokenKind.JSX_OPEN_START) or self.check(TokenKind.JSX_FRAG_OPEN) {
        return self.parse_jsx_element();
    }
    self.emit_diag(
        f"Unexpected token in expression: '{self.current().kind.value}'", "E0004"
    );
    return self.make_name(self.advance());
}

impl Parser.parse_tuple_item -> int {
    if self.check(TokenKind.STAR_POW) {
        star = self.make_uni_token(self.expect(TokenKind.STAR_POW));
        value = self.parse_expression();
        return self.b.mk_k_w_pair(key=NIL, value=value, kid=[star, value]);
    }
    return self.parse_expression();
}

impl Parser.parse_paren_expr -> int {
    lp_uni = self.consume_uni(TokenKind.LPAREN);
    if self.check(TokenKind.RPAREN) {
        rp_uni = self.make_uni_token(self.expect(TokenKind.RPAREN));
        return self.b.mk_tuple_val(values=[], kid=[lp_uni, rp_uni]);
    }

    if self.check(TokenKind.KW_YIELD) {
        yield_expr = self.parse_yield_stmt();
        rp_uni = self.consume_uni(TokenKind.RPAREN);
        return self.b.mk_atom_unit(value=yield_expr, kid=[lp_uni, yield_expr, rp_uni]);
    }

    if self.check_any(TokenKind.KW_DEF, TokenKind.KW_CAN, TokenKind.KW_ASYNC) {
        func_def = self.parse_ability();
        rp_uni = self.consume_uni(TokenKind.RPAREN);
        return self.b.mk_atom_unit(value=func_def, kid=[lp_uni, func_def, rp_uni]);
    }
    first_item = self.parse_tuple_item();
    if not self.b.kind_of(first_item) in KS_K_W_PAIR {
        expr = first_item;
        if self.check(TokenKind.KW_FOR)
            or (self.check(TokenKind.KW_ASYNC) and self.check_peek(TokenKind.KW_FOR)) {
            comprs = self.parse_comprehension_clauses();
            gc_kid: list[int] = [lp_uni, expr];
            gc_kid.extend(comprs);
            rp_uni = self.consume_uni(TokenKind.RPAREN);
            gc_kid.append(rp_uni);
            return self.b.mk_gen_compr(out_expr=expr, compr=comprs, kid=gc_kid);
        }
    }
    if self.check(TokenKind.COMMA) or self.b.kind_of(first_item) in KS_K_W_PAIR {
        values: list[int] = [first_item];
        comma_unis: list[int] = [];
        trailing_comma = False;
        if self.match_tok(TokenKind.COMMA) {
            comma_unis.append(self.make_uni_token(self.previous()));
            trailing_comma = True;
        }
        while trailing_comma
            and not self.check(TokenKind.RPAREN)
            and not self.at_end() {
            values.append(self.parse_tuple_item());
            if self.match_tok(TokenKind.COMMA) {
                comma_unis.append(self.make_uni_token(self.previous()));
                trailing_comma = True;
            } else {
                trailing_comma = False;
                break;
            }
        }
        rp_uni = self.consume_uni(TokenKind.RPAREN);
        kid: list[int] = [lp_uni];
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
        return self.b.mk_tuple_val(values=values, kid=kid);
    }
    rp_uni = self.consume_uni(TokenKind.RPAREN);
    if self.b.kind_of(first_item) in KS_K_W_PAIR {
        return self.b.mk_tuple_val(
            values=[first_item], kid=[lp_uni, first_item, rp_uni]
        );
    }
    return self.b.mk_atom_unit(value=first_item, kid=[lp_uni, first_item, rp_uni]);
}

impl Parser.parse_bracket_expr -> int {
    self.expect(TokenKind.LSQUARE);

    if self.check(TokenKind.NULL_OK) {
        return self.parse_filter_compr_bracket();
    }
    if self._is_edge_ref_start() {
        return self.parse_edge_ref_chain();
    }
    return self.parse_list_or_compr();
}

impl Parser._is_edge_ref_start -> bool {
    if self.check_any(
        TokenKind.ARROW_R,
        TokenKind.ARROW_L,
        TokenKind.ARROW_BI,
        TokenKind.ARROW_R_P1,
        TokenKind.ARROW_L_P1,
        TokenKind.RETURN_HINT,
        TokenKind.KW_ASYNC
    ) {
        return True;
    }

    if self.check_any(TokenKind.KW_NODE, TokenKind.KW_EDGE)
        and self.check_peek_any(
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
        return True;
    }

    if self.check_any(
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
            TokenKind.ARROW_R_P1,
            TokenKind.ARROW_L_P1,
            TokenKind.RETURN_HINT
        ) {
            return True;
        }
        if self.check_peek(TokenKind.LSQUARE) {
            save_pos = self.pos;
            self.advance();
            self.advance();
            depth = 1;
            while depth > 0 and not self.at_end() {
                if self.check(TokenKind.LSQUARE) {
                    depth += 1;
                } elif self.check(TokenKind.RSQUARE) {
                    depth -= 1;
                }
                self.advance();
            }
            is_edge = self.check_any(
                TokenKind.ARROW_R,
                TokenKind.ARROW_L,
                TokenKind.ARROW_BI,
                TokenKind.ARROW_R_P1,
                TokenKind.ARROW_L_P1,
                TokenKind.RETURN_HINT
            );
            self.pos = save_pos;
            return is_edge;
        }
    }
    return False;
}

impl Parser.parse_brace_expr -> int {
    self.expect(TokenKind.LBRACE);
    return self.parse_dict_or_set();
}

impl Parser.parse_fstring -> int {
    start_tok = self.expect_any(
        TokenKind.F_DQ_START,
        TokenKind.F_SQ_START,
        TokenKind.F_TDQ_START,
        TokenKind.F_TSQ_START,
        TokenKind.RF_DQ_START,
        TokenKind.RF_SQ_START,
        TokenKind.RF_TDQ_START,
        TokenKind.RF_TSQ_START
    );
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
    parts: list[int] = [];
    kid: list[int] = [start];
    while not self.check(end_kind) and not self.at_end() {
        if self.check(text_kind) {
            text_tok = self.advance();
            part = self.make_string(text_tok);
            parts.append(part);
            kid.append(part);
        } elif self.check(TokenKind.D_LBRACE) {
            self.expect(TokenKind.D_LBRACE);
            part = self.make_string_from_value("{");
            parts.append(part);
            kid.append(part);
        } elif self.check(TokenKind.D_RBRACE) {
            self.expect(TokenKind.D_RBRACE);
            part = self.make_string_from_value("}");
            parts.append(part);
            kid.append(part);
        } elif self.match_tok(TokenKind.LBRACE) {
            lbrace_uni = self.make_uni_token(self.previous());
            expr = self.parse_expression();
            conv = -1;
            fv_kid: list[int] = [lbrace_uni, expr];
            if self.check(TokenKind.CONV) {
                conv_tok = self.expect(TokenKind.CONV);
                conv = ord(conv_tok.value[1]) if len(conv_tok.value) > 1 else -1;
                fv_kid.append(self.make_uni_token(conv_tok));
            }
            format_spec = NIL;
            if self.check(TokenKind.COLON) {
                self.expect(TokenKind.COLON);
                fv_kid.append(self.make_uni_token(self.previous()));

                spec_parts: list[str] = [];
                spec_nodes: list[int] = [];
                while not self.check(TokenKind.RBRACE) and not self.at_end() {
                    if self.match_tok(TokenKind.LBRACE) {
                        nested_lbrace_uni = self.make_uni_token(self.previous());

                        if spec_parts {
                            spec_text = "";
                            for sp in spec_parts {
                                spec_text += sp;
                            }
                            spec_nodes.append(self.make_string_from_value(spec_text));
                            spec_parts = [];
                        }

                        nested_expr = self.parse_expression();
                        nested_conv = -1;
                        nested_fv_kid: list[int] = [nested_lbrace_uni, nested_expr];
                        if self.check(TokenKind.CONV) {
                            nc_tok = self.expect(TokenKind.CONV);
                            nested_conv = ord(nc_tok.value[1])
                                if len(nc_tok.value) > 1
                                else -1;
                            nested_fv_kid.append(self.make_uni_token(nc_tok));
                        }
                        nested_fv_kid.append(self.consume_uni(TokenKind.RBRACE));
                        nested_fv = self.b.mk_formatted_value(
                            format_part=nested_expr,
                            conversion=nested_conv,
                            format_spec=NIL,
                            kid=nested_fv_kid
                        );
                        spec_nodes.append(nested_fv);
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
                    spec_nodes.append(self.make_string_from_value(spec_text));
                }
                if spec_nodes {
                    if len(spec_nodes) == 1
                        and self.b.kind_of(spec_nodes[0]) in KS_STRING {
                        format_spec = spec_nodes[0];
                    } else {
                        format_spec = self.b.mk_f_string(
                            start=NIL, parts=spec_nodes, end=NIL, kid=list(spec_nodes)
                        );
                    }
                    fv_kid.append(format_spec);
                }
            }
            fv_kid.append(self.consume_uni(TokenKind.RBRACE));
            fv = self.b.mk_formatted_value(
                format_part=expr, conversion=conv, format_spec=format_spec, kid=fv_kid
            );
            parts.append(fv);
            kid.append(fv);
        } else {
            self.advance();
        }
    }
    end: int = NIL;
    if self.check(end_kind) {
        end_tok = self.advance();
        end = self.make_uni_token(end_tok);
        kid.append(end);
    }
    return self.b.mk_f_string(start=start, parts=parts, end=end, kid=kid);
}

impl Parser.parse_list_or_compr -> int {
    lsquare_uni = self.make_uni_token(self.previous());
    if self.check(TokenKind.RSQUARE) {
        self.expect(TokenKind.RSQUARE);
        return self.b.mk_list_val(
            values=[], kid=[lsquare_uni, self.make_uni_token(self.previous())]
        );
    }
    first = self.parse_expression();
    if self.check(TokenKind.KW_FOR)
        or (self.check(TokenKind.KW_ASYNC) and self.check_peek(TokenKind.KW_FOR)) {
        comprs = self.parse_comprehension_clauses();
        kid: list[int] = [lsquare_uni, first];
        kid.extend(comprs);
        kid.append(self.consume_uni(TokenKind.RSQUARE));
        return self.b.mk_list_compr(out_expr=first, compr=comprs, kid=kid);
    }

    if self.check_any(
        TokenKind.ARROW_R,
        TokenKind.ARROW_L,
        TokenKind.ARROW_BI,
        TokenKind.ARROW_R_P1,
        TokenKind.ARROW_L_P1
    ) {
        return self._continue_edge_ref_chain(first, lsquare_uni);
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
    return self.b.mk_list_val(values=values, kid=kid);
}

impl Parser._continue_edge_ref_chain(start_expr: int, lsquare_uni: int) -> int {
    kid: list[int] = [lsquare_uni, start_expr];
    chain: list[int] = [start_expr];
    while True {
        edge_op_ref = self.parse_edge_op_ref();
        if edge_op_ref == NIL {
            break;
        }
        chain.append(edge_op_ref);
        kid.append(edge_op_ref);

        if self.check(TokenKind.LSQUARE) and self.check_peek(TokenKind.NULL_OK) {
            self.advance();
            filter_expr = self.parse_filter_compr_bracket();
            chain.append(filter_expr);
            kid.append(filter_expr);
        } elif self.check(TokenKind.LPAREN) {
            if self.check_peek(TokenKind.NULL_OK) {
                self.emit_diag(
                    "Parenthesized filter syntax '(?:...)' was removed. Use bracket syntax '[?:...]' instead.",
                    "E0048",
                    loc=self.current().loc,
                    help="Replace (?:Type, cond) with [?:Type, cond]"
                );
                self.advance();
                fc_expr = self.parse_filter_compr_inner();
                chain.append(fc_expr);
                kid.append(fc_expr);
            } else {
                self.advance();
                kid.append(self.make_uni_token(self.previous()));
                plain_expr = self.parse_expression();
                chain.append(plain_expr);
                kid.append(plain_expr);
                kid.append(self.consume_uni(TokenKind.RPAREN));
            }
        } elif self.check_any(
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
    return self.b.mk_edge_ref_trailer(
        chain=chain, edges_only=False, is_async=False, kid=kid
    );
}

impl Parser.parse_edge_ref_chain -> int {
    kid: list[int] = [self.make_uni_token(self.previous())];
    chain: list[int] = [];
    is_async = False;
    edges_only = False;
    if self.match_tok(TokenKind.KW_ASYNC) {
        is_async = True;
        kid.append(self.make_uni_token(self.previous()));
    }

    if self.check(TokenKind.KW_EDGE) {
        edges_only = True;
        filter_tok = self.expect(TokenKind.KW_EDGE);
        kid.append(self.make_uni_token(filter_tok));
    } elif self.check(TokenKind.KW_NODE) {
        self.expect(TokenKind.KW_NODE);
        kid.append(self.make_uni_token(self.previous()));
    }

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

    while True {
        edge_op_ref = self.parse_edge_op_ref();
        if edge_op_ref == NIL {
            break;
        }
        if edge_op_ref != NIL {
            chain.append(edge_op_ref);
            kid.append(edge_op_ref);
        }

        if self.check(TokenKind.LSQUARE) and self.check_peek(TokenKind.NULL_OK) {
            self.expect(TokenKind.LSQUARE);
            filter_expr = self.parse_filter_compr_bracket();
            chain.append(filter_expr);
            kid.append(filter_expr);
        } elif self.check(TokenKind.LPAREN) {
            if self.check_peek(TokenKind.NULL_OK) {
                self.emit_diag(
                    "Parenthesized filter syntax '(?:...)' was removed. Use bracket syntax '[?:...]' instead.",
                    "E0048",
                    loc=self.current().loc,
                    help="Replace (?:Type, cond) with [?:Type, cond]"
                );
                self.expect(TokenKind.LPAREN);
                fc_expr = self.parse_filter_compr_inner();
                chain.append(fc_expr);
                kid.append(fc_expr);
            } else {
                self.expect(TokenKind.LPAREN);
                kid.append(self.make_uni_token(self.previous()));
                plain_expr = self.parse_expression();
                chain.append(plain_expr);
                kid.append(plain_expr);
                kid.append(self.consume_uni(TokenKind.RPAREN));
            }
        } elif self.check_any(
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
    return self.b.mk_edge_ref_trailer(
        chain=chain, edges_only=edges_only, is_async=is_async, kid=kid
    );
}

impl Parser.parse_edge_op_ref -> int {
    if self.check_any(TokenKind.ARROW_R, TokenKind.ARROW_L, TokenKind.ARROW_BI) {
        edge_tok = self.expect_any(
            TokenKind.ARROW_R, TokenKind.ARROW_L, TokenKind.ARROW_BI
        );
        edge_uni = self.make_uni_token(edge_tok);
        dir = EdgeDir.OUT;
        if edge_tok.kind == TokenKind.ARROW_L {
            dir = EdgeDir.IN;
        } elif edge_tok.kind == TokenKind.ARROW_BI {
            dir = EdgeDir.ANY;
        }
        return self.b.mk_edge_op_ref(filter_cond=NIL, edge_dir=dir, kid=[edge_uni]);
    }

    if self.check(TokenKind.ARROW_R_P1) {
        self.expect(TokenKind.ARROW_R_P1);
        start_uni = self.make_uni_token(self.previous());
        f_type = NIL;
        compares: list[int] = [];
        fcompr_kid: list[int] = [];
        if self.check_name() or self.is_keyword_token() {
            f_type = self.parse_atom();
            fcompr_kid.append(f_type);
        }
        if self.check(TokenKind.COLON) and not self.check(TokenKind.ARROW_R_P2) {
            self.expect(TokenKind.COLON);
            fcompr_kid.append(self.make_uni_token(self.previous()));
            if not self.check(TokenKind.ARROW_R_P2) {
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
        fcond = self.b.mk_filter_compr(
            f_type=f_type, compares=compares, kid=fcompr_kid
        );
        end_uni = self.consume_uni(TokenKind.ARROW_R_P2);
        return self.b.mk_edge_op_ref(
            filter_cond=fcond, edge_dir=EdgeDir.OUT, kid=[start_uni, fcond, end_uni]
        );
    }

    if self.check(TokenKind.ARROW_L_P1) {
        self.expect(TokenKind.ARROW_L_P1);
        start_uni = self.make_uni_token(self.previous());
        f_type = NIL;
        compares: list[int] = [];
        fcompr_kid: list[int] = [];
        if self.check_name() or self.is_keyword_token() {
            f_type = self.parse_atom();
            fcompr_kid.append(f_type);
        }
        if self.check(TokenKind.COLON) and not self.check(TokenKind.ARROW_L_P2) {
            self.expect(TokenKind.COLON);
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
        fcond = self.b.mk_filter_compr(
            f_type=f_type, compares=compares, kid=fcompr_kid
        );
        end_uni = self.consume_uni(TokenKind.ARROW_L_P2);
        return self.b.mk_edge_op_ref(
            filter_cond=fcond, edge_dir=EdgeDir.IN, kid=[start_uni, fcond, end_uni]
        );
    }
    return NIL;
}

impl Parser.parse_dict_or_set -> int {
    lbrace_uni = self.make_uni_token(self.previous());
    if self.check(TokenKind.RBRACE) {
        self.expect(TokenKind.RBRACE);
        return self.b.mk_dict_val(
            kv_pairs=[], kid=[lbrace_uni, self.make_uni_token(self.previous())]
        );
    }

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
            kv = self.b.mk_k_v_pair(
                key=first, value=value, kid=[first, colon_uni, value]
            );
            kid: list[int] = [lbrace_uni, kv];
            kid.extend(comprs);
            kid.append(self.consume_uni(TokenKind.RBRACE));
            return self.b.mk_dict_compr(kv_pair=kv, compr=comprs, kid=kid);
        }
        first_pair = self.b.mk_k_v_pair(
            key=first, value=value, kid=[first, colon_uni, value]
        );
        pairs = [first_pair];
        kid: list[int] = [lbrace_uni, first_pair];
        while self.match_tok(TokenKind.COMMA) {
            kid.append(self.make_uni_token(self.previous()));
            if self.check(TokenKind.RBRACE) {
                break;
            }
            if self.check(TokenKind.STAR_POW) {
                self.expect(TokenKind.STAR_POW);
                star_pow_uni = self.make_uni_token(self.previous());
                spread_val = self.parse_expression();
                pair = self.b.mk_k_v_pair(
                    key=NIL, value=spread_val, kid=[star_pow_uni, spread_val]
                );
            } else {
                key = self.parse_expression();
                kv_colon_uni = self.consume_uni(TokenKind.COLON);
                val = self.parse_expression();
                pair = self.b.mk_k_v_pair(
                    key=key, value=val, kid=[key, kv_colon_uni, val]
                );
            }
            pairs.append(pair);
            kid.append(pair);
        }
        kid.append(self.consume_uni(TokenKind.RBRACE));
        return self.b.mk_dict_val(kv_pairs=pairs, kid=kid);
    }
    if self.check(TokenKind.KW_FOR)
        or (self.check(TokenKind.KW_ASYNC) and self.check_peek(TokenKind.KW_FOR)) {
        comprs = self.parse_comprehension_clauses();
        kid = [lbrace_uni, first];
        kid.extend(comprs);
        kid.append(self.consume_uni(TokenKind.RBRACE));
        return self.b.mk_set_compr(out_expr=first, compr=comprs, kid=kid);
    }
    values = [first];
    kid: list[int] = [lbrace_uni, first];
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
    return self.b.mk_set_val(values=values, kid=kid);
}

impl Parser.parse_dict_with_spread(lbrace_uni: int) -> int {
    pairs: list[int] = [];
    kid: list[int] = [lbrace_uni];

    pair = self.parse_dict_spread_entry();
    pairs.append(pair);
    kid.append(pair);

    while self.match_tok(TokenKind.COMMA) {
        kid.append(self.make_uni_token(self.previous()));
        if self.check(TokenKind.RBRACE) {
            break;
        }
        pair = self.parse_dict_spread_entry();
        pairs.append(pair);
        kid.append(pair);
    }
    kid.append(self.consume_uni(TokenKind.RBRACE));
    return self.b.mk_dict_val(kv_pairs=pairs, kid=kid);
}

impl Parser.parse_dict_spread_entry -> int {
    if self.check(TokenKind.STAR_POW) {
        self.expect(TokenKind.STAR_POW);
        star_pow_uni = self.make_uni_token(self.previous());
        spread_val = self.parse_expression();
        return self.b.mk_k_v_pair(
            key=NIL, value=spread_val, kid=[star_pow_uni, spread_val]
        );
    } else {
        key = self.parse_expression();
        kv_colon_uni = self.consume_uni(TokenKind.COLON);
        val = self.parse_expression();
        return self.b.mk_k_v_pair(key=key, value=val, kid=[key, kv_colon_uni, val]);
    }
}

impl Parser.parse_comprehension_clauses -> list {
    comprs: list[int] = [self.parse_compr_clause()];
    while self.check(TokenKind.KW_FOR)
        or (self.check(TokenKind.KW_ASYNC) and self.check_peek(TokenKind.KW_FOR)) {
        comprs.append(self.parse_compr_clause());
    }
    return comprs;
}

impl Parser.parse_compr_clause -> int {
    is_async = False;
    async_uni: int = NIL;
    if self.match_tok(TokenKind.KW_ASYNC) {
        is_async = True;
        async_uni = self.make_uni_token(self.previous());
    }
    for_uni = self.consume_uni(TokenKind.KW_FOR);
    target = self.parse_atomic_chain();
    in_uni = self.consume_uni(TokenKind.KW_IN);
    iter_expr = self.parse_pipe_call();
    ifs: list[int] = [];
    if_unis: list[int] = [];
    while self.match_tok(TokenKind.KW_IF) {
        if_unis.append(self.make_uni_token(self.previous()));
        ifs.append(self.parse_walrus_assign());
    }
    kid: list[int] = [];
    if async_uni {
        kid.append(async_uni);
    }
    kid.extend([for_uni, target, in_uni, iter_expr]);
    for i in range(len(ifs)) {
        kid.append(if_unis[i]);
        kid.append(ifs[i]);
    }
    return self.b.mk_inner_compr(
        is_async=is_async, target=target, collection=iter_expr, conditional=ifs, kid=kid
    );
}

impl Parser.parse_lambda_expr -> int {
    lambda_tok = self.consume_uni(TokenKind.KW_LAMBDA);

    sig_kid: list[int] = [];
    params: list[int] = [];
    if self.match_tok(TokenKind.LPAREN) {
        sig_kid.append(self.make_uni_token(self.previous()));
        params = self.parse_func_params(sig_kid);
        sig_kid.append(self.consume_uni(TokenKind.RPAREN));
    }
    return_type = NIL;
    ret_hint_uni: int = NIL;
    if self.match_tok(TokenKind.RETURN_HINT) {
        ret_hint_uni = self.make_uni_token(self.previous());
        return_type = self.parse_expression();
    }
    body_stmts2: (list[int] | None) = None;
    body_expr2: int = NIL;
    lbrace_uni: int = NIL;
    rbrace_uni: int = NIL;
    if self.match_tok(TokenKind.LBRACE) {
        lbrace_uni = self.make_uni_token(self.previous());
        body_stmts2 = self._apply_implicit_return(self.parse_code_block_stmts());
        rbrace_uni = self.consume_uni(TokenKind.RBRACE);
    } else {
        self.emit_diag(
            "Expected '{' after lambda parameters",
            "E0022",
            help="Lambda bodies are braced; a single expression statement is the implicit return, e.g. 'lambda (x: int) { x + 1; }'."
        );
        body_expr2 = self.parse_expression();
    }
    if return_type {
        sig_kid.append(ret_hint_uni);
        sig_kid.append(return_type);
    }

    if len(sig_kid) == 0 {
        sig_kid.append(self.b.mk_empty_token());
    }
    signature = self.b.mk_func_signature(
        posonly_params=[],
        params=params,
        varargs=NIL,
        kwonlyargs=[],
        kwargs=NIL,
        return_type=return_type,
        kid=sig_kid
    );

    has_sig_content = (
        len(sig_kid) > 0 and not self.b.kind_of(sig_kid[0]) in KS_EMPTY_TOKEN
    )
        or return_type != NIL;
    kid: list[int] = [lambda_tok];
    if has_sig_content {
        kid.append(signature);
    }

    if body_expr2 != NIL {
        kid.append(body_expr2);
    } else {
        if lbrace_uni {
            kid.append(lbrace_uni);
        }
        kid.extend(body_stmts2 or []);
        if rbrace_uni {
            kid.append(rbrace_uni);
        }
    }
    lam_body: any = body_stmts2 or [];
    if body_expr2 != NIL {
        lam_body = body_expr2;
    }
    return self.b.mk_lambda_expr(body=lam_body, kid=kid, signature=signature);
}

impl Parser.parse_jsx_element -> int {
    kid: list[int] = [];

    if self.check(TokenKind.JSX_FRAG_OPEN) {
        frag_open = self.expect(TokenKind.JSX_FRAG_OPEN);
        kid.append(self.make_uni_token(frag_open));
        children = self.parse_jsx_children();
        kid.extend(children);
        kid.append(self.consume_uni(TokenKind.JSX_FRAG_CLOSE));
        return self.b.mk_jsx_element(
            name=NIL,
            attributes=[],
            children=children,
            is_self_closing=False,
            is_fragment=True,
            kid=kid
        );
    }

    open_start_uni = self.consume_uni(TokenKind.JSX_OPEN_START);
    open_kid: list[int] = [open_start_uni];

    elem_name: int = NIL;
    dyn_tag: int = NIL;
    if self.check(TokenKind.DECOR_OP) {
        dyn_tag = self._parse_jsx_dynamic_tag(open_kid);
    } else {
        name_tok = self.expect(TokenKind.JSX_NAME);
        name = self.make_name(name_tok);
        name_parts: list[int] = [name];
        name_kid: list[int] = [name];
        while self.match_tok(TokenKind.DOT) {
            name_kid.append(self.make_uni_token(self.previous()));
            next_name_tok = self.expect(TokenKind.JSX_NAME);
            next_name = self.make_name(next_name_tok);
            name_parts.append(next_name);
            name_kid.append(next_name);
        }
        elem_name = self.b.mk_jsx_element_name(parts=name_parts, kid=name_kid);
        open_kid.append(elem_name);
    }

    attrs = self.parse_jsx_attributes();
    open_kid.extend(attrs);

    if self.check(TokenKind.JSX_SELF_CLOSE) {
        self.expect(TokenKind.JSX_SELF_CLOSE);
        open_kid.append(self.make_uni_token(self.previous()));
        return self.b.mk_jsx_element(
            name=elem_name,
            attributes=attrs,
            children=None,
            is_self_closing=True,
            is_fragment=False,
            dynamic_tag=dyn_tag,
            kid=open_kid
        );
    }

    open_kid.append(self.consume_uni(TokenKind.JSX_TAG_END));

    opening = self.b.mk_jsx_element(
        name=elem_name,
        attributes=attrs,
        children=None,
        is_self_closing=False,
        is_fragment=False,
        dynamic_tag=dyn_tag,
        kid=open_kid
    );
    kid.append(opening);

    children = self.parse_jsx_children();
    kid.extend(children);

    close_start_uni = self.consume_uni(TokenKind.JSX_CLOSE_START);
    close_kid: list[int] = [close_start_uni];
    close_elem_name: int = NIL;
    if self.check(TokenKind.DECOR_OP) {
        self._consume_jsx_dynamic_close(close_kid);
    } else {
        close_name_tok = self.expect(TokenKind.JSX_NAME);
        close_name_node = self.make_name(close_name_tok);
        close_parts: list[int] = [close_name_node];
        close_name_kid: list[int] = [close_name_node];
        while self.match_tok(TokenKind.DOT) {
            close_name_kid.append(self.make_uni_token(self.previous()));
            cn_tok = self.expect(TokenKind.JSX_NAME);
            cn = self.make_name(cn_tok);
            close_parts.append(cn);
            close_name_kid.append(cn);
        }
        close_elem_name = self.b.mk_jsx_element_name(
            parts=close_parts, kid=close_name_kid
        );
        close_kid.append(close_elem_name);
    }
    close_kid.append(self.consume_uni(TokenKind.JSX_TAG_END));
    closing = self.b.mk_jsx_element(
        name=close_elem_name,
        attributes=[],
        children=None,
        is_self_closing=False,
        is_fragment=False,
        kid=close_kid
    );
    kid.append(closing);
    return self.b.mk_jsx_element(
        name=elem_name,
        attributes=attrs,
        children=children,
        is_self_closing=False,
        is_fragment=False,
        dynamic_tag=dyn_tag,
        kid=kid
    );
}

impl Parser._parse_jsx_dynamic_tag(open_kid: list[int]) -> int {
    at_uni = self.make_uni_token(self.advance());
    open_kid.append(at_uni);
    if self.check(TokenKind.LBRACE) {
        lb_uni = self.make_uni_token(self.advance());
        expr = self.parse_expression();
        rb_uni = self.consume_uni(TokenKind.RBRACE);
        open_kid.append(lb_uni);
        open_kid.append(expr);
        open_kid.append(rb_uni);
        return expr;
    }
    name_tok = self.expect(TokenKind.JSX_NAME);
    expr = self.make_name(name_tok);
    while self.match_tok(TokenKind.DOT) {
        dot_uni = self.make_uni_token(self.previous());
        attr_tok = self.expect(TokenKind.JSX_NAME);
        attr = self.make_name(attr_tok);
        expr = self.b.mk_atom_trailer(
            target=expr,
            right=attr,
            is_attr=True,
            is_null_ok=False,
            kid=[expr, dot_uni, attr]
        );
    }
    open_kid.append(expr);
    return expr;
}

impl Parser._consume_jsx_dynamic_close(close_kid: list[int]) {
    close_kid.append(self.make_uni_token(self.advance()));
    if self.check(TokenKind.LBRACE) {
        close_kid.append(self.make_uni_token(self.advance()));
        close_kid.append(self.parse_expression());
        close_kid.append(self.consume_uni(TokenKind.RBRACE));
        return;
    }
    close_kid.append(self.make_name(self.expect(TokenKind.JSX_NAME)));
    while self.match_tok(TokenKind.DOT) {
        close_kid.append(self.make_uni_token(self.previous()));
        close_kid.append(self.make_name(self.expect(TokenKind.JSX_NAME)));
    }
}

impl Parser.parse_jsx_attributes -> list {
    attrs: list[int] = [];
    while True {
        if self.check(TokenKind.JSX_NAME) {
            attr_name_tok = self.expect(TokenKind.JSX_NAME);
            attr_name = self.make_uni_token(attr_name_tok);
            attr_value: int = NIL;
            attr_kid: list[int] = [attr_name];
            if self.match_tok(TokenKind.EQ) {
                attr_kid.append(self.make_uni_token(self.previous()));

                if self.check(TokenKind.LBRACE) {
                    self.expect(TokenKind.LBRACE);
                    lbrace = self.make_uni_token(self.previous());
                    attr_value = self.parse_expression();
                    rbrace = self.consume_uni(TokenKind.RBRACE);
                    attr_kid.append(lbrace);
                    attr_kid.append(attr_value);
                    attr_kid.append(rbrace);
                } elif self.check(TokenKind.STRING) {
                    str_tok = self.expect(TokenKind.STRING);
                    str_val: int = self.make_string(str_tok);
                    attr_value = str_val;
                    attr_kid.append(attr_value);
                }
            }
            attrs.append(
                self.b.mk_jsx_normal_attribute(
                    name=attr_name, value=attr_value, kid=attr_kid
                )
            );
        } elif self.check(TokenKind.LBRACE) {
            self.expect(TokenKind.LBRACE);
            lbrace_tok = self.make_uni_token(self.previous());
            saw_spread_marker: bool = False;
            spread_marker_kid: int = NIL;
            if self.check(TokenKind.STAR_POW) {
                star_tok = self.expect(TokenKind.STAR_POW);
                spread_marker_kid = self.make_uni_token(star_tok);
                saw_spread_marker = True;
            } elif self.check(TokenKind.ELLIPSIS) {
                self.emit_warn(
                    "JSX spread '{...expr}' is JS-idiomatic. Prefer '{**expr}' in Jac.",
                    "W0063",
                    loc=self.current().loc,
                    help="Jac uses ** for dict unpacking -- use {**expr} instead of {...expr} in JSX attributes."
                );
                ellipsis_tok = self.expect(TokenKind.ELLIPSIS);
                spread_marker_kid = self.make_ellipsis(ellipsis_tok);
                saw_spread_marker = True;
            }
            inner_expr = self.parse_expression();
            rbrace_tok = self.consume_uni(TokenKind.RBRACE);
            if not saw_spread_marker and self.b.kind_of(inner_expr) in KS_NAME {
                attrs.append(
                    self.b.mk_jsx_normal_attribute(
                        name=inner_expr,
                        value=inner_expr,
                        is_shorthand=True,
                        kid=[lbrace_tok, inner_expr, rbrace_tok]
                    )
                );
            } else {
                spread_kid: list[int] = [lbrace_tok];
                if spread_marker_kid != NIL {
                    spread_kid.append(spread_marker_kid);
                }
                spread_kid.append(inner_expr);
                spread_kid.append(rbrace_tok);
                attrs.append(
                    self.b.mk_jsx_spread_attribute(expr=inner_expr, kid=spread_kid)
                );
            }
        } else {
            break;
        }
    }
    return attrs;
}

impl Parser.parse_jsx_children -> list {
    children: list[int] = [];
    while not self.at_end() {
        if self.check(TokenKind.JSX_CLOSE_START)
            or self.check(TokenKind.JSX_FRAG_CLOSE) {
            break;
        }
        child = self.parse_jsx_child();
        if child {
            children.append(child);
        } else {
            break;
        }
    }
    return children;
}

impl Parser.parse_jsx_child -> int {
    if self.check(TokenKind.JSX_TEXT) {
        text_tok = self.expect(TokenKind.JSX_TEXT);
        raw = text_tok.value;
        if not raw.strip() and ('\n' in raw or '\r' in raw) {
            return self.parse_jsx_child();
        }
        text_node = self.make_uni_token(text_tok);
        return self.b.mk_jsx_text(value=text_node, kid=[text_node]);
    }

    if self.check(TokenKind.JSX_COMMENT) {
        cmt_tok = self.expect(TokenKind.JSX_COMMENT);
        cmt_node = self.make_uni_token(cmt_tok);
        return self.b.mk_jsx_comment(value=cmt_node, kid=[cmt_node]);
    }

    if self.check(TokenKind.LBRACE) {
        lbrace = self.expect(TokenKind.LBRACE);
        lbrace_uni = self.make_uni_token(lbrace);

        if self.check_any(
            TokenKind.KW_FOR,
            TokenKind.KW_WHILE,
            TokenKind.KW_FOREVER,
            TokenKind.KW_IF,
            TokenKind.KW_MATCH,
            TokenKind.KW_SWITCH,
            TokenKind.KW_WITH,
            TokenKind.KW_TRY,
            TokenKind.KW_RETURN,
            TokenKind.KW_SKIP
        ) {
            self._view_body_depth += 1;
            stmts = self.parse_code_block_stmts();
            self._view_body_depth -= 1;
            rbrace_uni = self.consume_uni(TokenKind.RBRACE);
            kid: list[int] = [lbrace_uni];
            for s in stmts {
                kid.append(s);
            }
            kid.append(rbrace_uni);
            return self.b.mk_jsx_slot(body=stmts, kid=kid);
        }

        expr = self.parse_expression();
        if self.check(TokenKind.SEMI) {
            first = self.b.mk_expr_stmt(expr=expr, in_fstring=False, kid=[expr]);
            stmts2: list[int] = [first];
            if self.match_tok(TokenKind.SEMI) {
                prev_semi = self.previous();
                stmts2.append(
                    self.b.mk_semi(
                        name=Tok.SEMI.value,
                        value=prev_semi.value,
                        line=prev_semi.loc.line,
                        end_line=prev_semi.loc.end_line,
                        col_start=prev_semi.loc.col_start,
                        col_end=prev_semi.loc.col_end,
                        pos_start=prev_semi.loc.pos_start,
                        pos_end=prev_semi.loc.pos_end
                    )
                );
            }
            self._view_body_depth += 1;
            stmts2.extend(self.parse_code_block_stmts());
            self._view_body_depth -= 1;
            rbrace_uni = self.consume_uni(TokenKind.RBRACE);
            kid2: list[int] = [lbrace_uni];
            for s in stmts2 {
                kid2.append(s);
            }
            kid2.append(rbrace_uni);
            return self.b.mk_jsx_slot(body=stmts2, kid=kid2);
        }
        rbrace_uni = self.consume_uni(TokenKind.RBRACE);
        kid_expr: list[int] = [lbrace_uni, expr, rbrace_uni];
        return self.b.mk_jsx_expression(expr=expr, kid=kid_expr);
    }

    if self.check(TokenKind.JSX_OPEN_START) or self.check(TokenKind.JSX_FRAG_OPEN) {
        return self.parse_jsx_element();
    }

    return NIL;
}

impl Parser.parse_element_stmt -> int {
    if self.check(TokenKind.SEMI) {
        self.emit_diag("Unexpected semicolon at module level", "E0030");
        self.expect(TokenKind.SEMI);
        return NIL;
    }
    if self.at_end() {
        return NIL;
    }

    if (
        self.check(TokenKind.NAME)
        and self.current().value in ('sv', 'cl', 'na')
        and (
            self.check_peek(TokenKind.LBRACE)
            or self.peek().kind
                in (
                    TokenKind.KW_IMPORT,
                    TokenKind.KW_INCLUDE,
                    TokenKind.KW_DEF,
                    TokenKind.KW_CAN,
                    TokenKind.KW_OBJECT,
                    TokenKind.KW_CLASS,
                    TokenKind.KW_ENUM,
                    TokenKind.KW_NODE,
                    TokenKind.KW_EDGE,
                    TokenKind.KW_WALKER,
                    TokenKind.KW_GLOBAL,
                    TokenKind.KW_TEST,
                    TokenKind.KW_IMPL,
                    TokenKind.KW_SEM,
                    TokenKind.KW_WITH,
                    TokenKind.KW_ASYNC
                )
        )
    ) {
        return self._recover_removed_marker();
    }
    if self.check(TokenKind.TYP_TYPE) {
        save = self.pos;
        self.expect(TokenKind.TYP_TYPE);

        if self.check_any(TokenKind.KW_PUB, TokenKind.KW_PRIV, TokenKind.KW_PROT) {
            self.expect_any(TokenKind.KW_PUB, TokenKind.KW_PRIV, TokenKind.KW_PROT);
        }
        if self.check_name() or self.check(TokenKind.KWESC_NAME) {
            self.advance();
            if self.check(TokenKind.EQ) or self.check(TokenKind.LSQUARE) {
                self.pos = save;
                return self.parse_type_alias();
            }
        }
        self.pos = save;
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

    if self.check(TokenKind.STRING)
        and self.check_peek_any(
            TokenKind.KW_TEST,
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
            TokenKind.KW_ENUM,
            TokenKind.KW_IMPL,
            TokenKind.TYP_TYPE,
            TokenKind.KW_GLOBAL,
            TokenKind.KW_WITH
        ) {
        return self.parse_docstring_target();
    }
    if self.check_any(TokenKind.KW_DEF, TokenKind.KW_CAN) {
        return self.parse_ability();
    }

    if self.check(TokenKind.KW_GLOBAL) {
        return self.parse_global_var();
    }

    if self.check(TokenKind.KW_IMPL) {
        return self.parse_impl_def();
    }

    if self.check(TokenKind.KW_SEM) {
        return self.parse_sem_def();
    }

    if self.check(TokenKind.PYNLINE) {
        py_tok = self.expect(TokenKind.PYNLINE);
        py_code = self.make_uni_token(py_tok);
        return self.b.mk_py_inline_code(code=py_code, kid=[py_code]);
    }

    if self.check(TokenKind.KW_WITH) {
        return self.parse_module_code();
    }

    if self.check(TokenKind.DECOR_OP) {
        return self._dispatch_decorated();
    }

    if self.check(TokenKind.KW_ASYNC) {
        return self._dispatch_async();
    }
    self.emit_diag(f"Unexpected token '{self.current().value}'", "E0005");
    self.synchronize();
    return self.b.mk_empty_token();
}

impl Parser._dispatch_decorated -> int {
    save_pos = self.pos;
    while self.check(TokenKind.DECOR_OP) {
        self.advance();
        self.parse_atomic_chain();
    }

    while self.check(TokenKind.KW_ASYNC) {
        self.advance();
    }

    if self.check(TokenKind.KW_OVERRIDE) {
        self.advance();
    }
    if self.check(TokenKind.KW_STATIC) {
        self.advance();
    }

    if self.check(TokenKind.KW_CLASS)
        and self.check_peek_any(
            TokenKind.KW_DEF, TokenKind.KW_CAN, TokenKind.KW_ASYNC
        ) {
        self.advance();
    }

    has_abs_prefix = self.check(TokenKind.KW_ABSTRACT);
    if has_abs_prefix {
        self.advance();
    }

    is_ability = self.check_any(TokenKind.KW_DEF, TokenKind.KW_CAN);
    is_enum = self.check(TokenKind.KW_ENUM);
    is_impl = self.check(TokenKind.KW_IMPL);
    is_test = self.check(TokenKind.KW_TEST);
    self.pos = save_pos;
    if is_test {
        return self.parse_test();
    } elif is_ability {
        return self.parse_ability();
    } elif is_enum {
        return self.parse_enum();
    } elif is_impl {
        return self.parse_impl_def();
    } else {
        return self.parse_archetype();
    }
}

impl Parser._dispatch_async -> (int) {
    save_pos = self.pos;
    while self.check(TokenKind.KW_ASYNC) {
        self.advance();
    }

    if self.check(TokenKind.KW_STATIC) {
        self.advance();
    }
    if self.check(TokenKind.KW_CLASS)
        and self.check_peek_any(TokenKind.KW_DEF, TokenKind.KW_CAN) {
        self.advance();
    }
    is_ability = self.check_any(TokenKind.KW_DEF, TokenKind.KW_CAN);
    self.pos = save_pos;
    if is_ability {
        return self.parse_ability();
    }
    return self.parse_archetype();
}

impl Parser._attach_doc(nd: int, elem_doc: int) -> int {
    self.b.set_arg_node(nd, DOC_SLOTS[self.b.kind_of(nd)], elem_doc);
    self.b.prepend_kids(nd, [elem_doc]);
    return nd;
}

impl Parser.parse_docstring_target -> int {
    doc_tok = self.expect(TokenKind.STRING);
    elem_doc = self.make_string(doc_tok);

    if self.check(TokenKind.KW_TEST) {
        return self._attach_doc(self.parse_test(), elem_doc);
    }
    if self.check(TokenKind.KW_ENUM) {
        return self._attach_doc(self.parse_enum(), elem_doc);
    }
    if self.check(TokenKind.TYP_TYPE) {
        return self._attach_doc(self.parse_type_alias(), elem_doc);
    }
    if self.check(TokenKind.KW_GLOBAL) {
        return self._attach_doc(self.parse_global_var(), elem_doc);
    }
    if self.check(TokenKind.KW_IMPL) {
        return self._attach_doc(self.parse_impl_def(), elem_doc);
    }
    if self.check(TokenKind.KW_WITH) {
        return self._attach_doc(self.parse_module_code(), elem_doc);
    }
    return self._attach_doc(self._dispatch_decorated(), elem_doc);
}

impl Parser.parse_module_code -> int {
    with_uni = self.consume_uni(TokenKind.KW_WITH);
    name = NIL;
    target_name = NIL;
    colon_uni = NIL;
    if self.check(TokenKind.KW_EXIT) {
        name_tok = self.expect(TokenKind.KW_EXIT);
        name = self.make_uni_token(name_tok);
    } elif self.check(TokenKind.KW_ENTRY) {
        name_tok = self.expect(TokenKind.KW_ENTRY);
        name = self.make_uni_token(name_tok);
    }

    if self.match_tok(TokenKind.COLON) {
        colon_uni = self.make_uni_token(self.previous());
        target_tok = self.expect_name();
        target_name = self.make_name(target_tok);
    }
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    kid: list[int] = [with_uni];
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

    return self.b.mk_module_code(name=target_name, body=body, kid=kid, doc=NIL);
}

impl Parser.parse_code_block_stmts -> list {
    stmts: list[int] = [];
    checked_first = False;
    while not self.check(TokenKind.RBRACE) and not self.at_end() {
        before = self.pos;
        stmt = self.parse_statement();
        if stmt != NIL {
            is_docstring = False;
            if (
                not checked_first
                and self._view_body_depth == 0
                and self.b.kind_of(stmt) in KS_EXPR_STMT
                and not self.b.arg_bool(stmt, 1)
                and self.b.arg_bool(stmt, 2)
            ) {
                _se = self.b.arg_node(stmt, 0);
                if self.b.kind_of(_se) in KS_STRING {
                    is_docstring = True;
                } elif (
                    self.b.kind_of(_se) in KS_MULTI_STRING
                    and all(
                        self.b.kind_of(sn) in KS_STRING
                        for sn in (self.b.arg_list(_se, 0) or [])
                    )
                ) {
                    is_docstring = True;
                }
            }
            if is_docstring {
                self.emit_warn(
                    "Docstrings in Jac go before the declaration, not inside the body. Move this string before the enclosing test/can/obj/etc.",
                    "W0060",
                    loc=self.tokens[before].loc
                );
            }
            if not self.b.kind_of(stmt) in KS_SEMI {
                checked_first = True;
            }
            stmts.append(stmt);

            if self.match_tok(TokenKind.SEMI) {
                prev = self.previous();
                stmts.append(
                    self.b.mk_semi(
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

        if self.pos == before {
            self.advance();
        }
    }
    return stmts;
}

impl Parser._apply_implicit_return(body: list[int]) -> list[int] {
    if len(body) == 0 {
        return body;
    }
    last = body[-1];
    if self.b.kind_of(last) in KS_EXPR_STMT
        and not self.b.arg_bool(last, 2)
        and not self.b.arg_bool(last, 1) {
        _le = self.b.arg_node(last, 0);
        body[-1] = self.b.mk_return_stmt(expr=_le, is_implicit=True, kid=[_le]);
    }
    return body;
}

impl Parser.parse_ctrl_stmt -> int {
    if self.check_any(TokenKind.KW_BREAK, TokenKind.KW_CONTINUE, TokenKind.KW_SKIP) {
        self.expect_any(TokenKind.KW_BREAK, TokenKind.KW_CONTINUE, TokenKind.KW_SKIP);
        ctrl_uni = self.make_uni_token(self.previous());
        kid: list[int] = [ctrl_uni];
        self.expect(TokenKind.SEMI);
        kid.append(self.make_semi());
        return self.b.mk_ctrl_stmt(ctrl=ctrl_uni, kid=kid);
    }
    if self.check(TokenKind.KW_DISENGAGE) {
        self.expect(TokenKind.KW_DISENGAGE);
        dis_uni = self.make_uni_token(self.previous());
        kid: list[int] = [dis_uni];
        self.expect(TokenKind.SEMI);
        kid.append(self.make_semi());
        return self.b.mk_disengage_stmt(kid=kid);
    }
    return NIL;
}

impl Parser.parse_statement -> int {
    if self.match_tok(TokenKind.SEMI) {
        return self.make_semi();
    }
    if self.check(TokenKind.RBRACE) or self.at_end() {
        return NIL;
    }

    if self._view_body_depth > 0
        and self.check_any(TokenKind.JSX_OPEN_START, TokenKind.JSX_FRAG_OPEN) {
        jsx = self.parse_jsx_element();
        jsx_kid: list[int] = [jsx];
        if self.match_tok(TokenKind.SEMI) {
            jsx_kid.append(self.make_semi());
        }
        return self.b.mk_expr_stmt(expr=jsx, in_fstring=False, kid=jsx_kid);
    }

    if self._view_body_depth > 0
        and self.check(TokenKind.LBRACE)
        and self.check_peek_any(
            TokenKind.KW_FOR,
            TokenKind.KW_WHILE,
            TokenKind.KW_FOREVER,
            TokenKind.KW_IF,
            TokenKind.KW_MATCH,
            TokenKind.KW_SWITCH,
            TokenKind.KW_WITH,
            TokenKind.KW_TRY,
            TokenKind.KW_RETURN,
            TokenKind.KW_SKIP
        ) {
        redundant_lbrace_loc = self.current().loc;
        peeked_kw = self.peek().value;
        self.emit_diag(
            "Redundant '{...}' slot wrapping inside a JSX slot body -- slot "
                + "bodies are already in slot mode. Drop the outer braces: write "
                + f"'{peeked_kw} ... {{ ... }}' directly instead of "
                + f"'{{{peeked_kw} ... {{ ... }}}}'.",
            "E2023",
            loc=redundant_lbrace_loc
        );
        self.advance();
        inner = self.parse_statement();

        self.match_tok(TokenKind.SEMI);
        if self.check(TokenKind.RBRACE) {
            self.expect(TokenKind.RBRACE);
        }
        return inner;
    }

    if self._view_body_depth > 0 and self.check(TokenKind.LBRACE) {
        save_pos = self.pos;
        saved_error_count = self.error_count;
        saved_diags_len = len(self.diags);

        redundant_lbrace_loc = self.current().loc;
        self.advance();
        inner_expr = self.parse_expression();
        parsed_clean = self.error_count == saved_error_count;
        if parsed_clean and self.check(TokenKind.RBRACE) {
            self.emit_diag(
                "Redundant '{...}' around a single expression inside a JSX slot "
                    + "body -- slot bodies are already in slot mode, so the value renders "
                    + "without the extra braces. Drop them: write the expression directly, "
                    + "terminated with ';' (e.g. 'name;' instead of '{name}').",
                "E2028",
                loc=redundant_lbrace_loc
            );
            self.advance();
            expr_kid: list[int] = [inner_expr];
            if self.match_tok(TokenKind.SEMI) {
                expr_kid.append(self.make_semi());
            }
            return self.b.mk_expr_stmt(expr=inner_expr, in_fstring=False, kid=expr_kid);
        }

        self.pos = save_pos;
        self.error_count = saved_error_count;
        del self.diags[saved_diags_len:];
    }

    if self.check_any(TokenKind.KW_IMPORT, TokenKind.KW_INCLUDE) {
        return self.parse_import_stmt();
    }
    if self.check(TokenKind.KW_IF) {
        return self.parse_if_stmt();
    }
    if self.check(TokenKind.KW_WHILE) {
        return self.parse_while_stmt();
    }
    if self.check(TokenKind.KW_IN) {
        return self.parse_open_stmt();
    }
    if self.check(TokenKind.KW_FOREVER) {
        return self.parse_forever_stmt();
    }

    if self.check(TokenKind.KW_ASYNC) and self.check_peek(TokenKind.KW_FOR) {
        return self.parse_for_stmt();
    }
    if self.check(TokenKind.KW_FLOW) and self.check_peek(TokenKind.KW_FOR) {
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

    if self.check(TokenKind.KW_SWITCH) {
        return self.parse_switch_stmt();
    }
    if self.check(TokenKind.KW_RETURN) {
        return self.parse_return_stmt();
    }
    if self.check(TokenKind.KW_YIELD) {
        yield_expr = self.parse_yield_stmt();
        es_kid: list[int] = [yield_expr];
        self.expect(TokenKind.SEMI);
        if self.b.arg_node(yield_expr, 0) == NIL {
            self.b.append_kids(yield_expr, [self.make_semi()]);
        } else {
            es_kid.append(self.make_semi());
        }
        return self.b.mk_expr_stmt(expr=yield_expr, in_fstring=False, kid=es_kid);
    }
    if self.check_any(TokenKind.KW_BREAK, TokenKind.KW_CONTINUE, TokenKind.KW_SKIP) {
        return self.parse_ctrl_stmt();
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
    if self.check(TokenKind.KW_GLOBAL) {
        return self.parse_global_var();
    }

    if self.check(TokenKind.KW_VISIT) {
        return self.parse_visit_stmt();
    }

    if self.check(TokenKind.KW_DISENGAGE) {
        return self.parse_ctrl_stmt();
    }

    if self.check(TokenKind.KW_REPORT) {
        return self.parse_report_stmt();
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
            TokenKind.KW_CLASS
        ) {
        return self.parse_docstring_target();
    }
    if self.check_any(TokenKind.KW_DEF, TokenKind.KW_CAN, TokenKind.KW_ASYNC) {
        return self.parse_ability();
    }

    if self.check(TokenKind.KW_STATIC)
        and self.check_peek_any(
            TokenKind.KW_DEF, TokenKind.KW_CAN, TokenKind.KW_ASYNC
        ) {
        return self.parse_ability();
    }
    if self.check(TokenKind.DECOR_OP) {
        return self._dispatch_decorated();
    }

    if self.check(TokenKind.KW_CLASS)
        and self.check_peek_any(
            TokenKind.KW_DEF, TokenKind.KW_CAN, TokenKind.KW_ASYNC
        ) {
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

    if self.check(TokenKind.KW_IMPL) {
        return self.parse_impl_def();
    }

    if self.check(TokenKind.KW_HAS)
        or (self.check(TokenKind.KW_STATIC) and self.check_peek(TokenKind.KW_HAS)) {
        return self.parse_has_stmt();
    }

    if self.check(TokenKind.PYNLINE) {
        py_tok = self.expect(TokenKind.PYNLINE);
        py_code = self.make_uni_token(py_tok);
        return self.b.mk_py_inline_code(code=py_code, kid=[py_code]);
    }

    if self.check_any(
        TokenKind.KW_ELIF,
        TokenKind.KW_ELSE,
        TokenKind.KW_EXCEPT,
        TokenKind.KW_FINALLY,
        TokenKind.KW_CASE
    ) {
        self.emit_diag(
            f"Unexpected '{self.current().value}' -- must follow its parent statement (if/try/match/switch)",
            "E0032"
        );
        self.expect_any(
            TokenKind.KW_ELIF,
            TokenKind.KW_ELSE,
            TokenKind.KW_EXCEPT,
            TokenKind.KW_FINALLY,
            TokenKind.KW_CASE
        );
        return NIL;
    }

    if self.check(TokenKind.RETURN_HINT) and not self.check_peek(TokenKind.SEMI) {
        self.expect(TokenKind.RETURN_HINT);
        arrow_uni = self.make_uni_token(self.previous());
        type_ctx = self.parse_expression();
        lb_uni = self.consume_uni(TokenKind.LBRACE);
        body = self.parse_code_block_stmts();
        rb_uni = self.consume_uni(TokenKind.RBRACE);
        kid: list[int] = [arrow_uni, type_ctx, lb_uni];
        kid.extend(body);
        kid.append(rb_uni);
        return self.b.mk_typed_ctx_block(type_ctx=type_ctx, body=body, kid=kid);
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

    expr_kid: list[int] = [expr];
    if self.match_tok(TokenKind.SEMI) {
        expr_kid.append(self.make_semi());
    } elif self.b.kind_of(expr) in KS_JSX_ELEMENT and self._view_body_depth > 0 { } elif self.b.kind_of(
        expr
    )
        in KS_NAME
        and self.b.arg_str(expr, 1) == "new" {
        self.emit_diag(
            "Use the `new(target, ...args)` ambient builtin to create new instances",
            "E0012",
            loc=self.current().loc,
            help="`new` is a portable constructor: it lowers to `Cls(*args)` on the server and to `Reflect.construct(Cls, [args])` in cl blocks."
        );
    } elif self.check(TokenKind.RBRACE) {
        return self.b.mk_expr_stmt(
            expr=expr, in_fstring=False, has_semi=False, kid=expr_kid
        );
    } else {
        self.emit_diag("Missing ';'", "E0002");
    }
    return self.b.mk_expr_stmt(expr=expr, in_fstring=False, kid=expr_kid);
}

impl Parser.parse_if_stmt -> int {
    if_uni = self.consume_uni(TokenKind.KW_IF);
    condition = self.parse_expression();
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    else_body = NIL;
    if self.check(TokenKind.KW_ELIF) {
        else_body = self.parse_elif_stmt();
    } elif self.check(TokenKind.KW_ELSE) {
        else_body = self.parse_else_stmt();
    }
    kid: list[int] = [if_uni, condition, lb_uni];
    kid.extend(body);
    kid.append(rb_uni);
    if else_body {
        kid.append(else_body);
    }
    return self.b.mk_if_stmt(
        condition=condition, body=body, else_body=else_body, kid=kid
    );
}

impl Parser.parse_elif_stmt -> int {
    elif_uni = self.consume_uni(TokenKind.KW_ELIF);
    condition = self.parse_expression();
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    else_body = NIL;
    if self.check(TokenKind.KW_ELIF) {
        else_body = self.parse_elif_stmt();
    } elif self.check(TokenKind.KW_ELSE) {
        else_body = self.parse_else_stmt();
    }
    kid: list[int] = [elif_uni, condition, lb_uni];
    kid.extend(body);
    kid.append(rb_uni);
    if else_body {
        kid.append(else_body);
    }
    return self.b.mk_else_if(
        condition=condition, body=body, else_body=else_body, kid=kid
    );
}

impl Parser.parse_else_stmt -> int {
    else_uni = self.consume_uni(TokenKind.KW_ELSE);
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    kid: list[int] = [else_uni, lb_uni];
    kid.extend(body);
    kid.append(rb_uni);
    return self.b.mk_else_stmt(body=body, kid=kid);
}

impl Parser.parse_while_stmt -> int {
    while_uni = self.consume_uni(TokenKind.KW_WHILE);
    condition = self.parse_expression();
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    else_body = NIL;
    if self.check(TokenKind.KW_ELSE) {
        else_body = self.parse_else_stmt();
    }
    kid: list[int] = [while_uni, condition, lb_uni];
    kid.extend(body);
    kid.append(rb_uni);
    if else_body {
        kid.append(else_body);
    }
    return self.b.mk_while_stmt(
        condition=condition, body=body, else_body=else_body, kid=kid
    );
}

impl Parser.parse_open_stmt -> int {
    in_uni = self.consume_uni(TokenKind.KW_IN);
    target = self.parse_expression();
    if not self.check(TokenKind.LBRACE) {
        self.error("expected '{' to open the region body after `in <handle>`");
    }
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    kid: list[int] = [in_uni, target, lb_uni];
    kid.extend(body);
    kid.append(rb_uni);
    return self.b.mk_open_stmt(target=target, body=body, kid=kid);
}

impl Parser.parse_forever_stmt -> int {
    forever_uni = self.consume_uni(TokenKind.KW_FOREVER);
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    kid: list[int] = [forever_uni, lb_uni];
    kid.extend(body);
    kid.append(rb_uni);
    return self.b.mk_forever_stmt(body=body, kid=kid);
}

impl Parser.parse_for_stmt -> (int) {
    is_async = False;
    async_uni = NIL;
    flow_uni = NIL;
    if self.match_tok(TokenKind.KW_ASYNC) {
        is_async = True;
        async_uni = self.make_uni_token(self.previous());
    }
    if self.match_tok(TokenKind.KW_FLOW) {
        flow_uni = self.make_uni_token(self.previous());
    }
    for_uni = self.consume_uni(TokenKind.KW_FOR);

    target = self.parse_atomic_chain();

    if self.check(TokenKind.EQ) {
        if flow_uni != NIL {
            self.error("`flow for` requires the `for <x> in <collection>` form");
        }
        eq_tok = self.expect(TokenKind.EQ);
        eq_uni = self.make_uni_token(eq_tok);
        start_val = self.parse_expression();
        while_uni = self.consume_uni(TokenKind.KW_WHILE);
        end_val = self.parse_expression();
        with_uni = self.consume_uni(TokenKind.KW_WITH);

        step_target = self.parse_atomic_chain();
        step_assign: int;
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
            step_assign = self.parse_assignment_with_target(
                step_target, require_semi=False
            );
        } else {
            step_assign = self.b.mk_assignment(
                target=[step_target],
                value=NIL,
                type_tag=NIL,
                kid=[step_target],
                mutable=True,
                aug_op=NIL,
                is_enum_stmt=False
            );
        }
        lb_uni = self.consume_uni(TokenKind.LBRACE);
        body = self.parse_code_block_stmts();
        rb_uni = self.consume_uni(TokenKind.RBRACE);
        else_body = NIL;
        if self.check(TokenKind.KW_ELSE) {
            else_body = self.parse_else_stmt();
        }

        init_assign = self.b.mk_assignment(
            target=[target],
            value=start_val,
            type_tag=NIL,
            kid=[target, eq_uni, start_val],
            mutable=True,
            aug_op=NIL,
            is_enum_stmt=False
        );
        kid: list[int] = [];
        if is_async {
            kid.append(async_uni);
        }
        kid.extend(
            [for_uni, init_assign, while_uni, end_val, with_uni, step_assign, lb_uni]
        );
        kid.extend(body);
        kid.append(rb_uni);
        if else_body {
            kid.append(else_body);
        }
        return self.b.mk_iter_for_stmt(
            iter=init_assign,
            is_async=is_async,
            condition=end_val,
            count_by=step_assign,
            body=body,
            else_body=else_body,
            kid=kid
        );
    }

    in_uni = self.consume_uni(TokenKind.KW_IN);
    iter_expr = self.parse_expression();
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    else_body = NIL;
    if self.check(TokenKind.KW_ELSE) {
        else_body = self.parse_else_stmt();
    }
    kid: list[int] = [];
    if is_async {
        kid.append(async_uni);
    }
    if flow_uni != NIL {
        kid.append(flow_uni);
    }
    kid.extend([for_uni, target, in_uni, iter_expr]);
    kid.append(lb_uni);
    kid.extend(body);
    kid.append(rb_uni);
    if else_body {
        kid.append(else_body);
    }
    return self.b.mk_in_for_stmt(
        target=target,
        is_async=is_async,
        collection=iter_expr,
        body=body,
        else_body=else_body,
        kid=kid
    );
}

impl Parser.parse_try_stmt -> int {
    try_uni = self.consume_uni(TokenKind.KW_TRY);
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);

    awaiting_body = NIL;
    if self.check(TokenKind.KW_AWAITING) {
        awaiting_uni = self.make_uni_token(self.expect(TokenKind.KW_AWAITING));
        awaiting_lb = self.consume_uni(TokenKind.LBRACE);
        awaiting_stmts = self.parse_code_block_stmts();
        awaiting_rb = self.consume_uni(TokenKind.RBRACE);
        awaiting_kid: list[int] = [awaiting_uni, awaiting_lb];
        awaiting_kid.extend(awaiting_stmts);
        awaiting_kid.append(awaiting_rb);
        awaiting_body = self.b.mk_awaiting_clause(
            body=awaiting_stmts, kid=awaiting_kid
        );
    }
    excepts: list[int] = [];
    while self.check(TokenKind.KW_EXCEPT) {
        excepts.append(self.parse_except_handler());
    }
    else_body = NIL;
    if self.check(TokenKind.KW_ELSE) {
        else_body = self.parse_else_stmt();
    }
    finally_body = NIL;
    if self.check(TokenKind.KW_FINALLY) {
        fin_uni = self.make_uni_token(self.expect(TokenKind.KW_FINALLY));
        fin_lb = self.consume_uni(TokenKind.LBRACE);
        finally_stmts = self.parse_code_block_stmts();
        fin_rb = self.consume_uni(TokenKind.RBRACE);
        fin_kid: list[int] = [fin_uni, fin_lb];
        fin_kid.extend(finally_stmts);
        fin_kid.append(fin_rb);
        finally_body = self.b.mk_finally_stmt(body=finally_stmts, kid=fin_kid);
    }
    kid: list[int] = [try_uni, lb_uni];
    kid.extend(body);
    kid.append(rb_uni);
    if awaiting_body {
        kid.append(awaiting_body);
    }
    kid.extend(excepts);
    if else_body {
        kid.append(else_body);
    }
    if finally_body {
        kid.append(finally_body);
    }
    return self.b.mk_try_stmt(
        body=body,
        excepts=excepts,
        else_body=else_body,
        awaiting_body=awaiting_body,
        finally_body=finally_body,
        kid=kid
    );
}

impl Parser.parse_except_handler -> int {
    except_uni = self.consume_uni(TokenKind.KW_EXCEPT);

    exc_type = self.parse_expression(allow_cast=False);
    name = NIL;
    as_uni = NIL;
    if self.match_tok(TokenKind.KW_AS) {
        as_uni = self.make_uni_token(self.previous());
        name_tok = self.expect_name();
        name = self.make_name(name_tok);
    }
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    kid: list[int] = [except_uni, exc_type];
    if name {
        kid.append(as_uni);
        kid.append(name);
    }
    kid.append(lb_uni);
    kid.extend(body);
    kid.append(rb_uni);
    return self.b.mk_except(ex_type=exc_type, name=name, body=body, kid=kid);
}

impl Parser.parse_with_stmt -> int {
    is_async = False;
    async_uni = NIL;
    if self.match_tok(TokenKind.KW_ASYNC) {
        is_async = True;
        async_uni = self.make_uni_token(self.previous());
    }
    with_uni = self.consume_uni(TokenKind.KW_WITH);
    exprs: list[int] = [];

    expr = self.parse_expression(allow_cast=False);
    alias = NIL;
    as_uni = NIL;
    if self.match_tok(TokenKind.KW_AS) {
        as_uni = self.make_uni_token(self.previous());
        alias = self.parse_expression();
    }
    exprs.append(
        self.b.mk_expr_as_item(
            expr=expr, alias=alias, kid=[expr] if not alias else [expr, as_uni, alias]
        )
    );
    comma_unis: list[int] = [];
    while self.match_tok(TokenKind.COMMA) {
        comma_unis.append(self.make_uni_token(self.previous()));
        expr = self.parse_expression(allow_cast=False);
        alias = NIL;
        as_uni = NIL;
        if self.match_tok(TokenKind.KW_AS) {
            as_uni = self.make_uni_token(self.previous());
            alias = self.parse_expression();
        }
        exprs.append(
            self.b.mk_expr_as_item(
                expr=expr,
                alias=alias,
                kid=[expr] if not alias else [expr, as_uni, alias]
            )
        );
    }
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    kid: list[int] = [];
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
    return self.b.mk_with_stmt(is_async=is_async, exprs=exprs, body=body, kid=kid);
}

impl Parser.parse_match_stmt -> int {
    match_uni = self.consume_uni(TokenKind.KW_MATCH);
    expr = self.parse_expression();
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    cases: list[int] = [];
    while self.check(TokenKind.KW_CASE) {
        cases.append(self.parse_match_case());
    }
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    kid: list[int] = [match_uni, expr, lb_uni];
    kid.extend(cases);
    kid.append(rb_uni);
    return self.b.mk_match_stmt(target=expr, cases=cases, kid=kid);
}

impl Parser.parse_match_case -> int {
    case_uni = self.consume_uni(TokenKind.KW_CASE);
    pattern = self.parse_pattern();
    guard = NIL;
    guard_if_uni = NIL;
    if self.match_tok(TokenKind.KW_IF) {
        guard_if_uni = self.make_uni_token(self.previous());
        guard = self.parse_expression();
    }
    colon_uni = self.consume_uni(TokenKind.COLON);
    body: list[int] = [];
    while not self.check_any(TokenKind.KW_CASE, TokenKind.RBRACE)
        and not self.at_end() {
        before = self.pos;
        stmt = self.parse_statement();
        if stmt != NIL {
            body.append(stmt);
        }

        if self.pos == before {
            self.advance();
        }
    }
    kid: list[int] = [case_uni, pattern];
    if guard {
        kid.append(guard_if_uni);
        kid.append(guard);
    }
    kid.append(colon_uni);
    kid.extend(body);
    return self.b.mk_match_case(pattern=pattern, guard=guard, body=body, kid=kid);
}

impl Parser.parse_pattern -> int {
    pattern = self.parse_or_pattern();

    if self.match_tok(TokenKind.KW_AS) {
        as_uni = self.make_uni_token(self.previous());
        name_tok = self.expect_name();
        name = self.make_name(name_tok);
        kid: list[int] = [pattern, as_uni, name];
        return self.b.mk_match_as(name=name, pattern=pattern, kid=kid);
    }
    return pattern;
}

impl Parser.parse_or_pattern -> int {
    patterns: list[int] = [self.parse_single_pattern()];
    or_unis: list[int] = [];
    while self.match_tok(TokenKind.BW_OR) {
        or_unis.append(self.make_uni_token(self.previous()));
        patterns.append(self.parse_single_pattern());
    }
    if len(patterns) == 1 {
        return patterns[0];
    }
    kid: list[int] = [patterns[0]];
    for i in range(1, len(patterns)) {
        kid.append(or_unis[i - 1]);
        kid.append(patterns[i]);
    }
    return self.b.mk_match_or(patterns=patterns, kid=kid);
}

impl Parser.parse_single_pattern -> int {
    if self.check(TokenKind.LSQUARE) {
        return self.parse_sequence_pattern();
    }
    if self.check(TokenKind.LPAREN) {
        return self.parse_tuple_sequence_pattern();
    }
    if self.check(TokenKind.LBRACE) {
        return self.parse_mapping_pattern();
    }

    if self.check(TokenKind.BOOL) {
        tok = self.expect(TokenKind.BOOL);
        bval = self.make_bool(tok);
        return self.b.mk_match_singleton(value=bval, kid=[bval]);
    }
    if self.check(TokenKind.NULL) {
        tok = self.expect(TokenKind.NULL);
        nval = self.make_null(tok);
        return self.b.mk_match_singleton(value=nval, kid=[nval]);
    }

    if self.check_any(TokenKind.INT, TokenKind.FLOAT, TokenKind.MINUS)
        or self.check(TokenKind.STRING) {
        return self.parse_literal_pattern();
    }

    if self.check_name()
        or self.is_keyword_token()
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
        return self.parse_name_pattern();
    }

    expr = self.parse_expression();
    return self.b.mk_match_value(value=expr, kid=[expr]);
}

impl Parser.parse_literal_pattern -> int {
    if self.check(TokenKind.INT) {
        tok = self.expect(TokenKind.INT);
        ival = self.make_int(tok);
        return self.b.mk_match_value(value=ival, kid=[ival]);
    }
    if self.check(TokenKind.FLOAT) {
        tok = self.expect(TokenKind.FLOAT);
        fval = self.make_float(tok);
        return self.b.mk_match_value(value=fval, kid=[fval]);
    }
    ms = self.parse_multistring();
    if ms != NIL {
        return self.b.mk_match_value(value=ms, kid=[ms]);
    }

    if self.check(TokenKind.MINUS) {
        minus_tok = self.expect(TokenKind.MINUS);
        if self.check(TokenKind.INT) {
            tok = self.expect(TokenKind.INT);
            inum = self.make_int(tok);
            mival = self.b.mk_unary_expr(
                operand=inum,
                op=self.make_uni_token(minus_tok),
                kid=[self.make_uni_token(minus_tok), inum]
            );
            return self.b.mk_match_value(value=mival, kid=[mival]);
        }
        if self.check(TokenKind.FLOAT) {
            tok = self.expect(TokenKind.FLOAT);
            fnum = self.make_float(tok);
            mfval = self.b.mk_unary_expr(
                operand=fnum,
                op=self.make_uni_token(minus_tok),
                kid=[self.make_uni_token(minus_tok), fnum]
            );
            return self.b.mk_match_value(value=mfval, kid=[mfval]);
        }
    }

    return self.parse_expression_pattern();
}

impl Parser.parse_expression_pattern -> int {
    expr = self.parse_expression();
    return self.b.mk_match_value(value=expr, kid=[expr]);
}

impl Parser.parse_name_pattern -> int {
    if self.check_name() {
        tok = self.expect_name();
        name = self.make_name(tok);

        if tok.value == "_" {
            return self.b.mk_match_wild(kid=[name]);
        }

        if self.check(TokenKind.DOT) {
            names: list[int] = [name];
            dot_unis: list[int] = [];
            while self.match_tok(TokenKind.DOT) {
                dot_unis.append(self.make_uni_token(self.previous()));
                next_tok = self.expect_name();
                names.append(self.make_name(next_tok));
            }
            if self.check(TokenKind.LPAREN) {
                return self.parse_class_pattern_args(names, dot_unis);
            }

            trailer = names[0];
            for i in range(1, len(names)) {
                trailer = self.b.mk_atom_trailer(
                    target=trailer,
                    right=names[i],
                    is_attr=True,
                    is_null_ok=False,
                    kid=[trailer, dot_unis[i - 1], names[i]]
                );
            }
            return self.b.mk_match_value(value=trailer, kid=[trailer]);
        }

        if self.check(TokenKind.LPAREN) {
            return self.parse_class_pattern_args([name]);
        }

        return self.b.mk_match_as(name=name, pattern=NIL, kid=[name]);
    }

    if self.is_keyword_token() {
        tok = self.advance();
        name = self.make_special_name(tok);
        if self.check(TokenKind.LPAREN) {
            return self.parse_class_pattern_args([name]);
        }
        return self.b.mk_match_value(value=name, kid=[name]);
    }

    return self.parse_expression_pattern();
}

impl Parser.parse_sequence_pattern -> int {
    lsq_uni = self.consume_uni(TokenKind.LSQUARE);
    kid: list[int] = [lsq_uni];
    values: list[int] = [];
    while not self.check(TokenKind.RSQUARE) and not self.at_end() {
        if self.check(TokenKind.STAR_MUL) {
            star_tok = self.expect(TokenKind.STAR_MUL);
            name_tok = self.expect_name();
            name = self.make_name(name_tok);
            star_pattern = self.b.mk_match_star(
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
    return self.b.mk_match_sequence(values=values, kid=kid);
}

impl Parser.parse_tuple_sequence_pattern -> int {
    lp_uni = self.consume_uni(TokenKind.LPAREN);
    kid: list[int] = [lp_uni];
    values: list[int] = [];
    while not self.check(TokenKind.RPAREN) and not self.at_end() {
        if self.check(TokenKind.STAR_MUL) {
            star_tok = self.expect(TokenKind.STAR_MUL);
            name_tok = self.expect_name();
            name = self.make_name(name_tok);
            star_pattern = self.b.mk_match_star(
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
    return self.b.mk_match_sequence(values=values, kid=kid);
}

impl Parser.parse_mapping_pattern -> int {
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    kid: list[int] = [lb_uni];
    values: list[int] = [];
    while not self.check(TokenKind.RBRACE) and not self.at_end() {
        if self.check(TokenKind.STAR_POW) {
            star_tok = self.expect(TokenKind.STAR_POW);
            name_tok = self.expect_name();
            name = self.make_name(name_tok);
            star_pattern = self.b.mk_match_star(
                name=name, is_list=False, kid=[self.make_uni_token(star_tok), name]
            );
            values.append(star_pattern);
            kid.append(star_pattern);
        } else {
            key = self.parse_literal_for_mapping();
            colon_uni = self.consume_uni(TokenKind.COLON);
            val = self.parse_pattern();
            kv = self.b.mk_match_k_v_pair(
                key=key, value=val, kid=[key, colon_uni, val]
            );
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
    return self.b.mk_match_mapping(values=values, kid=kid);
}

impl Parser.parse_literal_for_mapping -> (int) {
    if self.check(TokenKind.INT) {
        tok = self.expect(TokenKind.INT);
        ival = self.make_int(tok);
        return self.b.mk_match_value(value=ival, kid=[ival]);
    }
    if self.check(TokenKind.FLOAT) {
        tok = self.expect(TokenKind.FLOAT);
        fval = self.make_float(tok);
        return self.b.mk_match_value(value=fval, kid=[fval]);
    }
    ms = self.parse_multistring();
    if ms != NIL {
        return self.b.mk_match_value(value=ms, kid=[ms]);
    }
    if self.check(TokenKind.MINUS) {
        minus_tok = self.expect(TokenKind.MINUS);
        if self.check(TokenKind.INT) {
            tok = self.expect(TokenKind.INT);
            inum = self.make_int(tok);
            mival = self.b.mk_unary_expr(
                operand=inum,
                op=self.make_uni_token(minus_tok),
                kid=[self.make_uni_token(minus_tok), inum]
            );
            return self.b.mk_match_value(value=mival, kid=[mival]);
        }
        if self.check(TokenKind.FLOAT) {
            tok = self.expect(TokenKind.FLOAT);
            fnum = self.make_float(tok);
            mfval = self.b.mk_unary_expr(
                operand=fnum,
                op=self.make_uni_token(minus_tok),
                kid=[self.make_uni_token(minus_tok), fnum]
            );
            return self.b.mk_match_value(value=mfval, kid=[mfval]);
        }
    }

    self.emit_diag(
        "Expected literal (INT, FLOAT, or STRING) as mapping pattern key", "E0045"
    );
    return self.make_name(self.advance());
}

impl Parser.parse_class_pattern_args(
    names: list[int], dot_unis: (list[int] | None) = None
) -> int {
    dots: list[int] = dot_unis or [];
    lparen_uni = self.consume_uni(TokenKind.LPAREN);

    if len(names) == 1 {
        class_name = names[0];
    } else {
        class_name = names[0];
        for i in range(1, len(names)) {
            class_name = self.b.mk_atom_trailer(
                target=class_name,
                right=names[i],
                is_attr=True,
                is_null_ok=False,
                kid=[class_name, dots[i - 1], names[i]]
            );
        }
    }
    arg_patterns: list[int] = [];
    kw_patterns: list[int] = [];
    kid: list[int] = [];

    kid.append(class_name);
    kid.append(lparen_uni);

    while not self.check(TokenKind.RPAREN) and not self.at_end() {
        if self.check_name() and self.check_peek(TokenKind.EQ) {
            name_tok = self.expect_name();
            eq_uni = self.consume_uni(TokenKind.EQ);
            val = self.parse_pattern();
            name = self.make_name(name_tok);
            kv = self.b.mk_match_k_v_pair(key=name, value=val, kid=[name, eq_uni, val]);
            kw_patterns.append(kv);
            kid.append(kv);
        } else {
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
    return self.b.mk_match_arch(
        name=class_name, arg_patterns=arg_patterns, kw_patterns=kw_patterns, kid=kid
    );
}

impl Parser.parse_return_stmt -> int {
    ret_uni = self.consume_uni(TokenKind.KW_RETURN);
    expr = NIL;
    if not self.check(TokenKind.SEMI) and not self.check(TokenKind.RBRACE) {
        expr = self.parse_expression();
    }
    kid: list[int] = [ret_uni];
    if expr {
        kid.append(expr);
    }
    self.expect(TokenKind.SEMI);
    kid.append(self.make_semi());
    return self.b.mk_return_stmt(expr=expr, kid=kid);
}

impl Parser.parse_yield_stmt -> int {
    yield_uni = self.consume_uni(TokenKind.KW_YIELD);
    with_from = False;
    from_uni: int = NIL;
    if self.match_tok(TokenKind.KW_FROM) {
        with_from = True;
        from_uni = self.make_uni_token(self.previous());
    }
    expr = NIL;
    if not self.check(TokenKind.SEMI) and not self.check(TokenKind.RBRACE) {
        expr = self.parse_expression();
    }
    kid: list[int] = [yield_uni];
    if from_uni {
        kid.append(from_uni);
    }
    if expr {
        kid.append(expr);
    }
    return self.b.mk_yield_expr(expr=expr, with_from=with_from, kid=kid);
}

impl Parser.parse_raise_stmt -> int {
    raise_uni = self.consume_uni(TokenKind.KW_RAISE);
    expr = NIL;
    from_target = NIL;
    if not self.check(TokenKind.SEMI) and not self.check(TokenKind.RBRACE) {
        expr = self.parse_expression();
    }
    from_kw_uni: int = NIL;
    if self.match_tok(TokenKind.KW_FROM) {
        from_kw_uni = self.make_uni_token(self.previous());
        from_target = self.parse_expression();
    }
    kid: list[int] = [raise_uni];
    if expr {
        kid.append(expr);
    }
    if from_target {
        kid.append(from_kw_uni);
        kid.append(from_target);
    }
    self.expect(TokenKind.SEMI);
    kid.append(self.make_semi());
    return self.b.mk_raise_stmt(cause=expr, from_target=from_target, kid=kid);
}

impl Parser.parse_assert_stmt -> int {
    assert_uni = self.consume_uni(TokenKind.KW_ASSERT);
    test = self.parse_expression();
    msg = NIL;
    comma_uni: int = NIL;
    if self.match_tok(TokenKind.COMMA) {
        comma_uni = self.make_uni_token(self.previous());
        msg = self.parse_expression();
    }
    kid: list[int] = [assert_uni, test];
    if msg {
        kid.append(comma_uni);
        kid.append(msg);
    }
    self.expect(TokenKind.SEMI);
    kid.append(self.make_semi());
    return self.b.mk_assert_stmt(condition=test, error_msg=msg, kid=kid);
}

impl Parser.parse_delete_stmt -> int {
    del_uni = self.consume_uni(TokenKind.KW_DELETE);
    target = self.parse_expression();
    self._recover_misplaced_disconnect();
    kid: list[int] = [del_uni, target];
    self.expect(TokenKind.SEMI);
    kid.append(self.make_semi());
    return self.b.mk_delete_stmt(target=target, kid=kid);
}

impl Parser._recover_misplaced_disconnect -> None {
    if not self.check_any(
        TokenKind.ARROW_R,
        TokenKind.ARROW_L,
        TokenKind.ARROW_BI,
        TokenKind.ARROW_R_P1,
        TokenKind.ARROW_L_P1
    ) {
        return;
    }
    self.emit_diag(
        "Connect/disconnect operator requires a right operand",
        "E0026",
        help="Connect (`++>`, `+>:T:+>`) and disconnect (`del -->`, `del ->:T:->`) operators are binary -- supply the right-hand side, e.g. `a ++> b;` or `a del --> b;`."
    );
    while not self.at_end()
        and not self.check_any(
            TokenKind.SEMI, TokenKind.RBRACE, TokenKind.RPAREN, TokenKind.RSQUARE
        ) {
        self.advance();
    }
}

impl Parser.parse_ownership_prefix(kids: list) -> OwnershipKind {
    if self.check(TokenKind.KW_OWN) {
        own_tok = self.expect(TokenKind.KW_OWN);
        kids.append(self.make_uni_token(own_tok));
        return OwnershipKind.OWN;
    } elif self.check(TokenKind.KW_IMM) {
        imm_tok = self.expect(TokenKind.KW_IMM);
        kids.append(self.make_uni_token(imm_tok));
        return OwnershipKind.IMM;
    } elif self.check(TokenKind.BW_AND) {
        amp_tok = self.expect(TokenKind.BW_AND);
        kids.append(self.make_uni_token(amp_tok));
        if self.check(TokenKind.KW_MUT) {
            mut_tok = self.expect(TokenKind.KW_MUT);
            kids.append(self.make_uni_token(mut_tok));
            return OwnershipKind.MUT_BORROW;
        }
        return OwnershipKind.BORROW;
    }
    return OwnershipKind.NONE;
}

impl Parser.parse_assignment_with_target(
    target: int, require_semi: bool = True
) -> int {
    type_tag = NIL;
    if self.match_tok(TokenKind.COLON) {
        colon_uni = self.make_uni_token(self.previous());

        own_kid: list[int] = [colon_uni];
        own_kind = self.parse_ownership_prefix(own_kid);
        tp = self.parse_pipe();
        own_kid.append(tp);
        type_tag = self.b.mk_sub_tag(tag=tp, ownership=own_kind, kid=own_kid);
    }
    value = NIL;
    aug_op = NIL;
    targets: list[int] = [target];
    eq_unis: list[int] = [];
    if self.match_tok(TokenKind.EQ) {
        eq_unis.append(self.make_uni_token(self.previous()));
        value = self.parse_yield_stmt()
            if self.check(TokenKind.KW_YIELD)
            else self.parse_expression();

        while self.check(TokenKind.EQ)
            and not self.check_any(TokenKind.SEMI, TokenKind.RBRACE) {
            self.expect(TokenKind.EQ);
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
        aug_tok = self.expect_any(
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
        );
        aug_op = self.make_uni_token(aug_tok);
        value = self.parse_yield_stmt()
            if self.check(TokenKind.KW_YIELD)
            else self.parse_expression();
    }

    kid: list[int] = [];
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

    if require_semi {
        if not self.check(TokenKind.SEMI)
            and value != NIL
            and self.b.kind_of(value) in KS_NAME
            and self.b.arg_str(value, 1) == "new" {
            self.emit_diag(
                "Use the `new(target, ...args)` ambient builtin to create new instances",
                "E0012",
                loc=self.current().loc,
                help="`new` is a portable constructor: it lowers to `Cls(*args)` on the server and to `Reflect.construct(Cls, [args])` in cl blocks."
            );
        } else {
            self.expect(TokenKind.SEMI);
        }
        kid.append(self.make_semi());
    } elif self.match_tok(TokenKind.SEMI) {
        kid.append(self.make_semi());
    }
    return self.b.mk_assignment(
        target=targets,
        value=value,
        type_tag=type_tag,
        kid=kid,
        mutable=True,
        aug_op=aug_op,
        is_enum_stmt=False
    );
}

impl Parser.parse_import_stmt -> int {
    is_include = False;
    if self.match_tok(TokenKind.KW_INCLUDE) {
        is_include = True;
    } else {
        self.expect(TokenKind.KW_IMPORT);
    }
    kid: list[int] = [self.make_uni_token(self.previous())];

    is_typed = False;
    if not is_include and self.match_tok(TokenKind.TYP_TYPE) {
        is_typed = True;
        kid.append(self.make_uni_token(self.previous()));
    }

    from_loc: int = NIL;
    is_clib_import = False;
    if self.match_tok(TokenKind.KW_FROM) {
        kid.append(self.make_uni_token(self.previous()));
        result = self.parse_from_path();
        from_loc = result[0];
        is_clib_import = result[1];
        kid.append(from_loc);
    }

    items: list[int] = [];
    clib_decls: list[int] = [];
    if self.check(TokenKind.LBRACE) {
        (items, clib_decls) = self.parse_import_items(kid, is_clib_import);
    } elif from_loc == NIL {
        while True {
            path_names: list[int] = [];
            path_kid: list[int] = [];
            if self.check(TokenKind.STRING) {
                str_tok = self.expect(TokenKind.STRING);
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
                path_kid = [self.b.mk_empty_token()];
            }

            alias: int = NIL;
            if self.match_tok(TokenKind.KW_AS) {
                as_uni = self.make_uni_token(self.previous());
                alias_tok = self.expect_name();
                alias = self.make_name(alias_tok);
                path_kid.append(as_uni);
                path_kid.append(alias);
            }
            path = self.b.mk_module_path(
                path=path_names, level=0, alias=alias, kid=path_kid
            );
            items.append(path);
            kid.append(path);

            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
            kid.append(self.make_uni_token(self.previous()));
        }
    }
    if from_loc == NIL {
        self.expect(TokenKind.SEMI);
        kid.append(self.make_semi());
    }
    return self.b.mk_import(
        from_loc=from_loc,
        items=items,
        is_absorb=is_include,
        is_typed=is_typed,
        kid=kid,
        doc=NIL,
        clib_decls=clib_decls
    );
}

impl Parser.parse_from_path -> tuple[(int, bool)] {
    path_names: list[int] = [];
    level = 0;
    path_kid: list[int] = [];
    is_clib_import = False;
    if self.check_any(TokenKind.DOT, TokenKind.ELLIPSIS) {
        while self.check_any(TokenKind.DOT, TokenKind.ELLIPSIS) {
            if self.check(TokenKind.ELLIPSIS) {
                tok = self.expect(TokenKind.ELLIPSIS);
                level += 3;
                path_kid.append(self.make_ellipsis(tok));
            } else {
                tok = self.expect(TokenKind.DOT);
                level += 1;
                path_kid.append(self.make_uni_token(tok));
            }
        }
    }
    if self.check(TokenKind.STRING) {
        str_tok = self.expect(TokenKind.STRING);
        str_node = self.make_string(str_tok);
        path_names.append(str_node);
        path_kid.append(str_node);
        is_clib_import = True;
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
        path_kid = [self.b.mk_empty_token()];
    }
    from_loc = self.b.mk_module_path(
        path=path_names, level=level, alias=NIL, kid=path_kid
    );
    return (from_loc, is_clib_import);
}

impl Parser.parse_import_items(kid: list, is_clib_import: bool) -> tuple[(list, list)] {
    items: list[int] = [];
    clib_decls: list[int] = [];
    self.expect(TokenKind.LBRACE);
    kid.append(self.make_uni_token(self.previous()));

    if self.check_any(
        TokenKind.KW_DEF,
        TokenKind.KW_CAN,
        TokenKind.KW_OBJECT,
        TokenKind.KW_CLASS,
        TokenKind.KW_ENUM,
        TokenKind.KW_ASYNC,
        TokenKind.STRING,
        TokenKind.KW_GLOBAL,
        TokenKind.KW_HAS
    )
        and (is_clib_import or not self.check(TokenKind.STRING)) {
        while not self.check(TokenKind.RBRACE) and not self.at_end() {
            stmt = self.parse_element_stmt();
            if stmt != NIL {
                clib_decls.append(stmt);
                kid.append(stmt);
                if self.b.kind_of(stmt) in KS_CONTEXT_AWARE_NODE {
                    self.b.post_set(stmt, "code_context", 2);
                }
            }
        }
    } else {
        while not self.check(TokenKind.RBRACE) and not self.at_end() {
            item_name: int;
            if self.check(TokenKind.STAR_MUL) {
                star_tok = self.expect(TokenKind.STAR_MUL);
                item_name = self.make_uni_token(star_tok);
            } else {
                item_name_tok: LexToken;
                if self.check(TokenKind.KW_DEFAULT) {
                    item_name_tok = self.expect(TokenKind.KW_DEFAULT);
                    item_name = self.make_uni_token(item_name_tok);
                } elif self.check_name() {
                    item_name_tok = self.expect_name();
                    item_name = self.make_name(item_name_tok);
                } elif self.is_keyword_token() {
                    item_name_tok = self.advance();
                    item_name = self.make_name_or_special(item_name_tok);
                } else {
                    item_name_tok = self.expect_name();
                    item_name = self.make_name(item_name_tok);
                }
            }
            alias = NIL;
            as_tok: LexToken | None = None;
            if self.match_tok(TokenKind.KW_AS) {
                as_tok = self.previous();
                alias_tok = self.expect_name();
                alias = self.make_name(alias_tok);
            }
            item_kid: list[int] = [item_name];
            if alias != NIL and as_tok is not None {
                item_kid.append(self.make_uni_token(as_tok));
                item_kid.append(alias);
            }
            item = self.b.mk_module_item(name=item_name, alias=alias, kid=item_kid);
            items.append(item);
            kid.append(item);
            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
            kid.append(self.make_uni_token(self.previous()));
        }
    }
    rbrace_uni = self.consume_uni(TokenKind.RBRACE);
    kid.append(rbrace_uni);
    return (items, clib_decls);
}

impl Parser.parse_archetype -> int {
    decorators: list[int] = [];
    decor_unis: list[int] = [];
    while self.check(TokenKind.DECOR_OP) {
        decor_unis.append(self.make_uni_token(self.expect(TokenKind.DECOR_OP)));
        decorators.append(self.parse_atomic_chain());
    }
    is_async = False;
    async_uni = NIL;
    if self.match_tok(TokenKind.KW_ASYNC) {
        is_async = True;
        async_uni = self.make_uni_token(self.previous());
    }
    arch_tok = self.expect_any(
        TokenKind.KW_OBJECT,
        TokenKind.KW_NODE,
        TokenKind.KW_EDGE,
        TokenKind.KW_WALKER,
        TokenKind.KW_CLASS
    );
    arch_type = self.make_uni_token(arch_tok);
    access = self.parse_access_tag();
    name_tok: LexToken;
    if self.check_name() {
        name_tok = self.expect_name();
    } elif self.is_keyword_token() {
        name_tok = self.advance();
    } else {
        name_tok = self.expect_name();
    }
    name = self.make_name_or_special(name_tok);

    tp_list: list[int] = [];
    has_tp = False;
    tp_lb_uni: int = NIL;
    tp_rb_uni: int = NIL;
    tp_comma_unis: list[int] = [];
    if self.match_tok(TokenKind.LSQUARE) {
        tp_lb_uni = self.make_uni_token(self.previous());
        (tp_list, tp_comma_unis) = self.parse_type_params();
        has_tp = True;
        tp_rb_uni = self.consume_uni(TokenKind.RSQUARE);
    }
    base_classes: list[int] = [];
    lp_uni = NIL;
    rp_uni = NIL;
    arch_comma_unis: list[int] = [];
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

    src_endpoint = NIL;
    tgt_endpoint = NIL;
    ep_colon_uni = NIL;
    ep_arrow_uni = NIL;
    if self.check(TokenKind.COLON) {
        self.expect(TokenKind.COLON);
        ep_colon_uni = self.make_uni_token(self.previous());
        src_endpoint = self.parse_atomic_chain();
        ep_arrow_uni = self.consume_uni(TokenKind.ARROW_R);
        tgt_endpoint = self.parse_atomic_chain();
    }
    body_l: list[int] = [];
    has_body = False;
    body_lb_uni = NIL;
    body_rb_uni = NIL;
    if self.match_tok(TokenKind.LBRACE) {
        has_body = True;
        body_lb_uni = self.make_uni_token(self.previous());
        while not self.check(TokenKind.RBRACE) and not self.at_end() {
            before = self.pos;
            member = self.parse_archetype_member();
            if member != NIL {
                body_l.append(member);
            }

            if self.pos == before {
                self.advance();
            }
        }
        body_rb_uni = self.consume_uni(TokenKind.RBRACE);
    } else {
        self.expect(TokenKind.SEMI);
    }
    kid: list[int] = [];
    for (i, d) in enumerate(decorators) {
        kid.append(decor_unis[i]);
        kid.append(d);
    }
    if is_async {
        kid.append(async_uni);
    }
    kid.append(arch_type);
    if access {
        kid.append(access);
    }
    kid.append(name);
    if has_tp {
        kid.append(tp_lb_uni);
        for (i, tp) in enumerate(tp_list) {
            if i > 0 {
                kid.append(tp_comma_unis[i - 1]);
            }
            kid.append(tp);
        }
        kid.append(tp_rb_uni);
    }
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
    if src_endpoint != NIL {
        kid.append(ep_colon_uni);
        kid.append(src_endpoint);
        kid.append(ep_arrow_uni);
        kid.append(tgt_endpoint);
    }
    if has_body {
        kid.append(body_lb_uni);
        kid.extend(body_l);
        kid.append(body_rb_uni);
    } else {
        kid.append(self.make_semi());
    }
    tp_arg: any = None;
    if has_tp {
        tp_arg = tp_list;
    }
    ab_body_arg: any = None;
    if has_body {
        ab_body_arg = body_l;
    }
    arch = self.b.mk_archetype(
        name=name,
        arch_type=arch_type,
        access=access,
        base_classes=base_classes,
        body=ab_body_arg,
        kid=kid,
        doc=NIL,
        decorators=decorators,
        type_params=tp_arg,
        src_endpoint=src_endpoint,
        tgt_endpoint=tgt_endpoint
    );
    if is_async {
        self.b.set_arg_bool(arch, 1, True);
    }
    return arch;
}

impl Parser.parse_archetype_member -> (int) {
    self._skip_semicolons();
    if self.check(TokenKind.RBRACE) or self.at_end() {
        return NIL;
    }

    doc: int = NIL;
    if self.check(TokenKind.STRING) {
        doc_tok = self.expect(TokenKind.STRING);
        doc = self.make_string(doc_tok);
    }

    if self.check(TokenKind.DECOR_OP) {
        ability = self.parse_ability();
        if doc {
            _ = self._attach_doc(ability, doc);
        }
        return ability;
    }

    if self.check(TokenKind.KW_STATIC) {
        if self.check_peek(TokenKind.KW_HAS) {
            has_stmt = self.parse_has_stmt();
            if doc {
                _ = self._attach_doc(has_stmt, doc);
            }
            return has_stmt;
        }

        ability = self.parse_ability();
        if doc {
            _ = self._attach_doc(ability, doc);
        }
        return ability;
    }
    if self.check(TokenKind.KW_HAS) {
        has_stmt = self.parse_has_stmt();
        if doc {
            _ = self._attach_doc(has_stmt, doc);
        }
        return has_stmt;
    }

    if self.check(TokenKind.KW_ASYNC) {
        ability = self.parse_ability();
        if doc {
            _ = self._attach_doc(ability, doc);
        }
        return ability;
    }
    if self.check_any(TokenKind.KW_DEF, TokenKind.KW_CAN, TokenKind.KW_OVERRIDE) {
        ability = self.parse_ability();
        if doc {
            _ = self._attach_doc(ability, doc);
        }
        return ability;
    }

    if self.check(TokenKind.KW_CLASS)
        and self.check_peek_any(
            TokenKind.KW_DEF, TokenKind.KW_CAN, TokenKind.KW_ASYNC
        ) {
        ability = self.parse_ability();
        if doc {
            _ = self._attach_doc(ability, doc);
        }
        return ability;
    }
    if self.check_any(
        TokenKind.KW_OBJECT,
        TokenKind.KW_NODE,
        TokenKind.KW_EDGE,
        TokenKind.KW_WALKER,
        TokenKind.KW_CLASS
    ) {
        archetype = self.parse_archetype();
        if doc {
            _ = self._attach_doc(archetype, doc);
        }
        return archetype;
    }
    if self.check(TokenKind.KW_ENUM) {
        enum_node = self.parse_enum();
        if doc {
            _ = self._attach_doc(enum_node, doc);
        }
        return enum_node;
    }

    if self.check(TokenKind.KW_IMPL) {
        impl_node = self.parse_impl_def();
        if doc {
            _ = self._attach_doc(impl_node, doc);
        }
        return impl_node;
    }

    if self.check(TokenKind.PYNLINE) {
        py_tok = self.expect(TokenKind.PYNLINE);
        py_code = self.make_uni_token(py_tok);
        return self.b.mk_py_inline_code(code=py_code, kid=[py_code]);
    }

    if self.check(TokenKind.KW_WITH) {
        self.expect(TokenKind.KW_WITH);
        with_tok = self.previous();
        if self.check_any(TokenKind.KW_ENTRY, TokenKind.KW_EXIT) {
            event_tok = self.expect_any(TokenKind.KW_ENTRY, TokenKind.KW_EXIT);
            lb_uni = self.consume_uni(TokenKind.LBRACE);
            body = self.parse_code_block_stmts();
            rb_uni = self.consume_uni(TokenKind.RBRACE);
            kid: list[int] = [
                self.make_uni_token(with_tok),
                self.make_uni_token(event_tok),
                lb_uni
            ];
            kid.extend(body);
            kid.append(rb_uni);
            module_code = self.b.mk_module_code(name=NIL, body=body, kid=kid, doc=NIL);
            if doc {
                _ = self._attach_doc(module_code, doc);
            }
            return module_code;
        }
    }

    if self.check(TokenKind.NAME) {
        stmt = self.parse_statement();
        return stmt;
    }
    self._error_unexpected_member();
    return self.b.mk_empty_token();
}

impl Parser._skip_semicolons{
    while self.match_tok(TokenKind.SEMI) {
        continue;
    }
}

impl Parser._error_unexpected_member{
    self.emit_diag("Unexpected token in archetype body", "E0046");
    self.advance();
}

impl Parser.parse_has_stmt -> int {
    is_static = False;
    static_tok: LexToken | None = None;
    if self.match_tok(TokenKind.KW_STATIC) {
        is_static = True;
        static_tok = self.previous();
    }
    has_tok = self.expect(TokenKind.KW_HAS);
    access = self.parse_access_tag();
    vars: list[int] = [];
    has_comma_unis: list[int] = [];
    vars.append(self.parse_has_var());
    while self.match_tok(TokenKind.COMMA) {
        has_comma_unis.append(self.make_uni_token(self.previous()));
        vars.append(self.parse_has_var());
    }

    last_had_accessors = vars and (self.b.arg_list(vars[len(vars) - 1], 4) is not None);
    saw_semi = False;
    if last_had_accessors {
        saw_semi = self.match_tok(TokenKind.SEMI) is not None;
    } else {
        self.expect(TokenKind.SEMI);
        saw_semi = True;
    }
    kid: list[int] = [];
    if static_tok is not None {
        kid.append(self.make_uni_token(static_tok));
    }
    kid.append(self.make_uni_token(has_tok));
    if access {
        kid.append(access);
    }

    for (i, v) in enumerate(vars) {
        if i > 0 {
            kid.append(has_comma_unis[i - 1]);
        }
        kid.append(v);
    }

    if saw_semi {
        prev = self.previous();
        kid.append(
            self.b.mk_semi(
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
    return self.b.mk_arch_has(
        is_static=is_static, access=access, vars=vars, is_frozen=False, kid=kid, doc=NIL
    );
}

impl Parser.parse_has_var -> int {
    name_tok: LexToken;
    if self.check_name() {
        name_tok = self.expect_name();
    } elif self.is_keyword_token() {
        name_tok = self.advance();
    } else {
        name_tok = self.expect_name();
    }
    name: int;
    if name_tok.kind
        in [
            TokenKind.KW_SELF,
            TokenKind.KW_PROPS,
            TokenKind.KW_SUPER,
            TokenKind.KW_ROOT,
            TokenKind.KW_HERE,
            TokenKind.KW_VISITOR
        ] {
        name = self.b.mk_special_var_ref(
            var=self.make_special_name(name_tok), is_enum_stmt=False
        );
    } elif name_tok.kind == TokenKind.NAME or name_tok.kind == TokenKind.KWESC_NAME {
        name = self.make_name(name_tok);
    } else {
        name = self.make_special_name(name_tok);
    }
    colon_uni = self.consume_uni(TokenKind.COLON);
    type_expr = self.parse_pipe();
    type_tag = self.b.mk_sub_tag(tag=type_expr, kid=[colon_uni, type_expr]);
    value = NIL;
    defer = False;
    eq_uni: int = NIL;
    postinit_name: int = NIL;
    if self.match_tok(TokenKind.EQ) {
        eq_uni = self.make_uni_token(self.previous());
        value = self.parse_expression();
    } elif self.match_tok(TokenKind.KW_POST_INIT) {
        postinit_name = self.make_special_name(self.previous());
        defer = True;
    }

    acc_list: list[int] = [];
    has_acc = False;
    acc_lb_uni: int = NIL;
    acc_rb_uni: int = NIL;
    if self.check(TokenKind.LBRACE) {
        if value != NIL {
            self.emit_diag(
                "Property declarations cannot have an initializer",
                "E0080",
                help="Declare backing storage as a separate `has` field (e.g. `has _x: T = value;`) and reference it from your accessors."
            );
        }
        acc_lb_uni = self.consume_uni(TokenKind.LBRACE);
        has_acc = True;
        while not self.check(TokenKind.RBRACE) {
            acc_list.append(self.parse_accessor());
        }
        acc_rb_uni = self.consume_uni(TokenKind.RBRACE);
        if len(acc_list) == 0 {
            self.emit_diag(
                "Property declaration must contain at least one of `getter`, `setter`, `deleter`",
                "E0081"
            );
        }
    }
    kid: list[int] = [name, type_tag];
    if value {
        kid.append(eq_uni);
        kid.append(value);
    }
    if defer {
        kid.append(postinit_name);
    }
    if has_acc {
        kid.append(acc_lb_uni);
        for acc in acc_list {
            kid.append(acc);
        }
        kid.append(acc_rb_uni);
    }
    acc_arg: any = None;
    if has_acc {
        acc_arg = acc_list;
    }
    return self.b.mk_has_var(
        name=name,
        type_tag=type_tag,
        value=value,
        defer=defer,
        accessors=acc_arg,
        kid=kid
    );
}

impl Parser._consume_accessor_kind -> tuple[str, LexToken] {
    if self.check(TokenKind.KW_DELETER) {
        return ("deleter", self.advance());
    }
    if self.check(TokenKind.KW_SETTER) {
        return ("setter", self.advance());
    }
    if self.check(TokenKind.KW_GETTER) {
        return ("property", self.advance());
    }
    self.emit_diag(
        f"Expected 'getter' or 'setter', got '{self.current().kind.value}'", "E0001"
    );
    return ("property", self.advance());
}

impl Parser.parse_accessor -> int {
    (kind_str, kind_tok) = self._consume_accessor_kind();
    name = self.make_name(kind_tok);

    signature: int = self.parse_func_signature();
    has_sig_content = not (
        len(self.b.kid_ids(signature)) == 1
        and self.b.kind_of(self.b.kid_ids(signature)[0]) in KS_EMPTY_TOKEN
    );
    if not has_sig_content {
        signature = NIL;
    }

    body: (list[int] | None) = None;
    body_lb_uni: int = NIL;
    body_rb_uni: int = NIL;
    if self.match_tok(TokenKind.LBRACE) {
        body_lb_uni = self.make_uni_token(self.previous());
        body = self.parse_code_block_stmts();
        body_rb_uni = self.consume_uni(TokenKind.RBRACE);
    } else {
        self.expect(TokenKind.SEMI);
    }
    kid: list[int] = [name];
    if signature != NIL {
        kid.append(signature);
    }
    if body is not None {
        kid.append(body_lb_uni);
        kid.extend(body);
        kid.append(body_rb_uni);
    } else {
        kid.append(self.make_semi());
    }
    return self.b.mk_ability(
        name_ref=name,
        is_async=False,
        is_override=False,
        is_static=False,
        is_classmethod=False,
        is_abstract=False,
        access=NIL,
        signature=signature,
        body=body,
        kid=kid,
        doc=NIL,
        decorators=None,
        type_params=None,
        accessor_kind=kind_str
    );
}

impl Parser.parse_ability -> int {
    decorators: list[int] = [];
    decor_unis: list[int] = [];
    while self.check(TokenKind.DECOR_OP) {
        decor_unis.append(self.make_uni_token(self.expect(TokenKind.DECOR_OP)));
        decorators.append(self.parse_atomic_chain());
    }
    is_override = False;
    override_tok: LexToken | None = None;
    if self.match_tok(TokenKind.KW_OVERRIDE) {
        is_override = True;
        override_tok = self.previous();
    }
    is_classmethod = False;
    classmethod_tok: LexToken | None = None;
    if self.check(TokenKind.KW_CLASS)
        and self.check_peek_any(
            TokenKind.KW_DEF, TokenKind.KW_CAN, TokenKind.KW_ASYNC
        ) {
        self.expect(TokenKind.KW_CLASS);
        is_classmethod = True;
        classmethod_tok = self.previous();
    }
    is_static = False;
    static_tok: LexToken | None = None;
    if not is_classmethod and self.match_tok(TokenKind.KW_STATIC) {
        is_static = True;
        static_tok = self.previous();
    }
    is_async = False;
    async_tok: LexToken | None = None;
    if self.match_tok(TokenKind.KW_ASYNC) {
        is_async = True;
        async_tok = self.previous();

        (is_override, override_tok, is_static, static_tok) = self._parse_post_async_modifiers(
            is_override, override_tok, is_static, static_tok
        );
        if not is_classmethod
            and self.check(TokenKind.KW_CLASS)
            and self.check_peek_any(TokenKind.KW_DEF, TokenKind.KW_CAN) {
            self.expect(TokenKind.KW_CLASS);
            is_classmethod = True;
            classmethod_tok = self.previous();
        }
    }
    is_can = self.check(TokenKind.KW_CAN);
    ability_tok = self.expect_any(TokenKind.KW_DEF, TokenKind.KW_CAN);
    access = self.parse_access_tag();
    name = NIL;

    if self.check_name() {
        name_tok = self.expect_name();
        name = self.make_name(name_tok);
    } elif self.is_keyword_token() and not (is_can and self.check(TokenKind.KW_WITH)) {
        name_tok = self.advance();
        name = self._make_attr_from_keyword(name_tok);
    }

    tp_list: list[int] = [];
    has_tp = False;
    tp_lb_uni: int = NIL;
    tp_rb_uni: int = NIL;
    tp_comma_unis: list[int] = [];
    if self.match_tok(TokenKind.LSQUARE) {
        tp_lb_uni = self.make_uni_token(self.previous());
        (tp_list, tp_comma_unis) = self.parse_type_params();
        has_tp = True;
        tp_rb_uni = self.consume_uni(TokenKind.RSQUARE);
    }
    signature: int;
    if is_can and self.check(TokenKind.KW_WITH) {
        with_uni = self.make_uni_token(self.expect(TokenKind.KW_WITH));
        event_type = self.parse_expression()
            if not self.check_any(TokenKind.KW_ENTRY, TokenKind.KW_EXIT)
            else NIL;
        event_tok = self.expect_any(TokenKind.KW_ENTRY, TokenKind.KW_EXIT);
        event_uni_tok = self.make_uni_token(event_tok);

        sig_kid: list[int] = [with_uni];
        if event_type {
            sig_kid.append(event_type);
        }
        sig_kid.append(event_uni_tok);
        signature = self.b.mk_event_signature(
            event=event_uni_tok, arch_tag_info=event_type, kid=sig_kid
        );
    } elif is_can {
        self.emit_diag(
            "Expected 'with' after 'can' ability name (use 'def' for function-style declarations)",
            "E0034"
        );
        signature = self.parse_func_signature();
    } else {
        signature = self.parse_func_signature();
    }
    body_stmts: (list[int] | None) = None;
    body_expr: int = NIL;
    is_abstract = False;
    body_type = "semi";
    body_lb_uni = NIL;
    body_rb_uni = NIL;
    body_by_uni = NIL;
    body_abs_uni = NIL;
    if self.match_tok(TokenKind.LBRACE) {
        body_type = "brace";
        body_lb_uni = self.make_uni_token(self.previous());
        body_stmts = self.parse_code_block_stmts();
        body_stmts = self._apply_implicit_return(body_stmts);
        body_rb_uni = self.consume_uni(TokenKind.RBRACE);
    } elif self.match_tok(TokenKind.KW_BY) {
        body_type = "by";
        body_by_uni = self.make_uni_token(self.previous());
        by_expr = self.parse_expression();
        self.expect(TokenKind.SEMI);
        self.b.prepend_kids(by_expr, [body_by_uni]);
        self.b.append_kids(by_expr, [self.make_semi()]);
        body_expr = by_expr;
    } else {
        if self.match_tok(TokenKind.KW_ABSTRACT) {
            is_abstract = True;
            body_abs_uni = self.make_uni_token(self.previous());
        }
        self.expect(TokenKind.SEMI);
    }
    kid: list[int] = [];
    for (di, d) in enumerate(decorators) {
        kid.append(decor_unis[di]);
        kid.append(d);
    }
    if override_tok is not None {
        kid.append(self.make_uni_token(override_tok));
    }
    if classmethod_tok is not None {
        kid.append(self.make_uni_token(classmethod_tok));
    }
    if static_tok is not None {
        kid.append(self.make_uni_token(static_tok));
    }
    if async_tok is not None {
        kid.append(self.make_uni_token(async_tok));
    }
    kid.append(self.make_uni_token(ability_tok));
    if access {
        kid.append(access);
    }
    if name {
        kid.append(name);
    }
    if has_tp {
        kid.append(tp_lb_uni);
        for (i, tp) in enumerate(tp_list) {
            if i > 0 {
                kid.append(tp_comma_unis[i - 1]);
            }
            kid.append(tp);
        }
        kid.append(tp_rb_uni);
    }

    kid.append(signature);
    if body_type == "brace" and body_stmts is not None {
        if body_lb_uni != NIL {
            kid.append(body_lb_uni);
        }
        kid.extend(body_stmts);
        if body_rb_uni != NIL {
            kid.append(body_rb_uni);
        }
    } elif body_type == "by" and body_expr != NIL {
        kid.append(body_expr);
    } else {
        if is_abstract {
            kid.append(body_abs_uni);
        }
        kid.append(self.make_semi());
    }
    body_arg: any = None;
    if body_type == "brace" {
        body_arg = body_stmts;
    } elif body_type == "by" and body_expr != NIL {
        body_arg = body_expr;
    }
    tp_arg: any = None;
    if has_tp {
        tp_arg = tp_list;
    }
    return self.b.mk_ability(
        name_ref=name,
        is_async=is_async,
        is_override=is_override,
        is_static=is_static,
        is_classmethod=is_classmethod,
        is_abstract=is_abstract,
        access=access,
        signature=signature,
        body=body_arg,
        kid=kid,
        doc=NIL,
        decorators=decorators,
        type_params=tp_arg
    );
}

impl Parser._parse_post_async_modifiers(
    is_override: bool,
    override_tok: (LexToken | None),
    is_static: bool,
    static_tok: (LexToken | None)
) -> tuple[(bool, (LexToken | None), bool, (LexToken | None))] {
    if not is_override and self.match_tok(TokenKind.KW_OVERRIDE) {
        is_override = True;
        override_tok = self.previous();
    }
    if not is_static and self.match_tok(TokenKind.KW_STATIC) {
        is_static = True;
        static_tok = self.previous();
    }
    return (is_override, override_tok, is_static, static_tok);
}

impl Parser.parse_func_signature -> int {
    all_params: list[int] = [];
    return_type = NIL;
    kid: list[int] = [];
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

    if len(kid) == 0 {
        kid.append(self.b.mk_empty_token());
    }

    posonly_params: list[int] = [];
    regular_params: list[int] = [];
    kwonly_params: list[int] = [];
    varargs_param: int = NIL;
    kwargs_param: int = NIL;

    saw_bare_star = False;
    saw_slash = False;
    for k in kid {
        if self.b.kind_of(k) in KS_PARAM_VAR {
            _u = self.b.arg_node(k, 2);
            _un = self.b.arg_str(_u, 0) if _u != NIL else None;
            if _un is not None and _un == Tok.STAR_POW {
                kwargs_param = k;
            } elif _un is not None and _un == Tok.STAR_MUL {
                varargs_param = k;
                saw_bare_star = True;
            } elif saw_bare_star {
                kwonly_params.append(k);
            } else {
                regular_params.append(k);
            }
        } elif self.b.kind_of(k) in KS_TOKEN {
            _kn = self.b.arg_str(k, 0);
            if _kn == Tok.STAR_MUL {
                saw_bare_star = True;
            } elif _kn == Tok.DIV {
                posonly_params = regular_params;
                regular_params = [];
                saw_slash = True;
            }
        }
    }

    for p in posonly_params {
        self.b.post_set(p, "param_kind", ParamKind.POSONLY.value);
    }
    for p in kwonly_params {
        self.b.post_set(p, "param_kind", ParamKind.KWONLY.value);
    }
    if varargs_param != NIL {
        self.b.post_set(varargs_param, "param_kind", ParamKind.VARARG.value);
    }
    if kwargs_param != NIL {
        self.b.post_set(kwargs_param, "param_kind", ParamKind.KWARG.value);
    }
    return self.b.mk_func_signature(
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
    params: list[int] = [];
    while not self.check(TokenKind.RPAREN) {
        if self.check(TokenKind.STAR_MUL)
            and (
                self.check_peek(TokenKind.COMMA) or self.check_peek(TokenKind.RPAREN)
            ) {
            star_tok = self.expect(TokenKind.STAR_MUL);
            star_uni = self.make_uni_token(star_tok);
            kid.append(star_uni);
            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
            kid.append(self.make_uni_token(self.previous()));
        } elif self.check(TokenKind.DIV)
            and (
                self.check_peek(TokenKind.COMMA) or self.check_peek(TokenKind.RPAREN)
            ) {
            div_tok = self.expect(TokenKind.DIV);
            div_uni = self.make_uni_token(div_tok);
            kid.append(div_uni);
            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
            kid.append(self.make_uni_token(self.previous()));
        } else {
            pv = self.parse_param_var();
            if pv == NIL {
                break;
            }
            params.append(pv);
            kid.append(pv);
            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
            kid.append(self.make_uni_token(self.previous()));
        }
    }
    return params;
}

impl Parser.parse_param_var -> int {
    unpack: int = NIL;
    if self.check_any(TokenKind.STAR_MUL, TokenKind.STAR_POW) {
        unpack_tok = self.expect_any(TokenKind.STAR_MUL, TokenKind.STAR_POW);
        unpack = self.make_uni_token(unpack_tok);
    }

    if self.check_name() {
        name_tok = self.expect_name();
        name = self.make_name_or_special(name_tok);
    } elif self.check(TokenKind.KW_SELF) {
        name_tok = self.expect(TokenKind.KW_SELF);
        name = self.b.mk_special_var_ref(
            var=self.make_special_name(name_tok), is_enum_stmt=False
        );
    } elif self.check_any(
        TokenKind.KW_PROPS, TokenKind.KW_HERE, TokenKind.KW_VISITOR
    ) {
        name_tok = self.expect_any(
            TokenKind.KW_PROPS, TokenKind.KW_HERE, TokenKind.KW_VISITOR
        );
        name = self.b.mk_special_var_ref(
            var=self.make_special_name(name_tok), is_enum_stmt=False
        );
    } elif self.is_builtin_type_token() {
        name_tok = self.expect_any(
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
            TokenKind.TYP_TYPE,
            TokenKind.TYP_I8,
            TokenKind.TYP_U8,
            TokenKind.TYP_I16,
            TokenKind.TYP_U16,
            TokenKind.TYP_I32,
            TokenKind.TYP_U32,
            TokenKind.TYP_I64,
            TokenKind.TYP_U64,
            TokenKind.TYP_F32,
            TokenKind.TYP_F64
        );
        name = self.make_name_or_special(name_tok);
    } elif self.is_keyword_token() {
        kw = self.current().value;
        self.emit_diag(
            f"'{kw}' is a keyword and cannot be used as a parameter name (prefix with backtick to escape: `{kw})",
            "E0013"
        );
        name_tok = self.advance();
        name = self.make_name_or_special(name_tok);
    } else {
        return NIL;
    }
    type_tag: int = NIL;
    if self.match_tok(TokenKind.COLON) {
        param_colon_uni = self.make_uni_token(self.previous());
        param_type_kid: list[int] = [param_colon_uni];
        param_kind = self.parse_ownership_prefix(param_type_kid);
        tp = self.parse_pipe();
        param_type_kid.append(tp);
        type_tag = self.b.mk_sub_tag(tag=tp, ownership=param_kind, kid=param_type_kid);
    }
    default_val: int = NIL;
    param_eq_uni: int = NIL;
    if self.match_tok(TokenKind.EQ) {
        param_eq_uni = self.make_uni_token(self.previous());
        default_val = self.parse_expression();
    }
    pv_kid: list[int] = [];
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

    return self.b.mk_param_var(
        name=name, unpack=unpack, type_tag=type_tag, value=default_val, kid=pv_kid
    );
}

impl Parser.parse_enum -> int {
    decorators: list[int] = [];
    enum_decor_unis: list[int] = [];
    while self.check(TokenKind.DECOR_OP) {
        enum_decor_unis.append(self.make_uni_token(self.expect(TokenKind.DECOR_OP)));
        decorators.append(self.parse_atomic_chain());
    }
    enum_kw_uni = self.consume_uni(TokenKind.KW_ENUM);
    access = self.parse_access_tag();
    name_tok: LexToken;
    if self.check_name() {
        name_tok = self.expect_name();
    } elif self.is_keyword_token() {
        name_tok = self.advance();
    } else {
        name_tok = self.expect_name();
    }
    name = self.make_name_or_special(name_tok);
    value_type: int = NIL;
    enum_colon_uni: int = NIL;
    base_classes: list[int] = [];
    enum_lp_uni: int = NIL;
    enum_rp_uni: int = NIL;
    enum_base_comma_unis: list[int] = [];
    if self.match_tok(TokenKind.COLON) {
        enum_colon_uni = self.make_uni_token(self.previous());
        value_type = self.parse_atomic_chain();
    } elif self.match_tok(TokenKind.LPAREN) {
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
    body_l: list[int] = [];
    body_kid: list[int] = [];
    has_body = False;
    enum_lb_uni: int = NIL;
    enum_rb_uni: int = NIL;
    if self.match_tok(TokenKind.LBRACE) {
        has_body = True;
        enum_lb_uni = self.make_uni_token(self.previous());
        while not self.check(TokenKind.RBRACE) and not self.at_end() {
            if self.check_name() {
                member = self.parse_enum_member();
                body_l.append(member);
                body_kid.append(member);
                if self.match_tok(TokenKind.COMMA) {
                    body_kid.append(self.make_uni_token(self.previous()));
                }
            } elif self.check(TokenKind.PYNLINE) {
                py_tok = self.expect(TokenKind.PYNLINE);
                py_code = self.make_uni_token(py_tok);
                pynline = self.b.mk_py_inline_code(code=py_code, kid=[py_code]);
                self.b.set_arg_bool(pynline, 0, True);
                body_l.append(pynline);
                body_kid.append(pynline);
            } elif self.check(TokenKind.KW_WITH) {
                mc = self.parse_module_code();
                self.b.set_arg_bool(mc, 0, True);
                body_l.append(mc);
                body_kid.append(mc);
            } else {
                break;
            }
        }

        enum_rb_uni = self.consume_uni(TokenKind.RBRACE);
    } else {
        self.expect(TokenKind.SEMI);
    }
    kid: list[int] = [];
    for (di, d) in enumerate(decorators) {
        kid.append(enum_decor_unis[di]);
        kid.append(d);
    }
    kid.append(enum_kw_uni);
    if access {
        kid.append(access);
    }
    kid.append(name);
    if value_type {
        kid.append(enum_colon_uni);
        kid.append(value_type);
    } elif base_classes {
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
    ab_body_arg: any = None;
    if has_body {
        ab_body_arg = body_l;
    }
    return self.b.mk_enum(
        name=name,
        access=access,
        value_type=value_type,
        base_classes=base_classes,
        body=ab_body_arg,
        kid=kid,
        doc=NIL,
        decorators=decorators
    );
}

impl Parser.parse_enum_member -> int {
    name_tok = self.expect_name();
    name = self.make_name(name_tok, is_enum_stmt=True);
    value = NIL;
    em_eq_uni: int = NIL;
    if self.match_tok(TokenKind.EQ) {
        em_eq_uni = self.make_uni_token(self.previous());
        value = self.parse_expression();
    }
    kid: list[int] = [name];
    if value {
        kid.append(em_eq_uni);
        kid.append(value);
    }
    return self.b.mk_assignment(
        target=[name],
        value=value,
        type_tag=NIL,
        kid=kid,
        mutable=False,
        aug_op=NIL,
        is_enum_stmt=True
    );
}

impl Parser.parse_test -> int {
    decorators: list[int] = [];
    decor_unis: list[int] = [];
    while self.check(TokenKind.DECOR_OP) {
        decor_unis.append(self.make_uni_token(self.expect(TokenKind.DECOR_OP)));
        decorators.append(self.parse_atomic_chain());
    }
    test_kw_uni = self.consume_uni(TokenKind.KW_TEST);

    cur = self.current();
    name: int = self.b.mk_token(
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
    description: int = NIL;
    if self.check(TokenKind.STRING) {
        str_tok = self.expect(TokenKind.STRING);
        description = self.make_string(str_tok);

        desc_text = _string_lit_text(str_tok.value);
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
        ident = ident.lower();
        if not ident {
            self._gen_test_idx += 1;
            ident = f"_jac_gen_{self._gen_test_idx}";
        }
        name = self.b.mk_name(
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
    kid: list[int] = [];
    for (di, d) in enumerate(decorators) {
        kid.append(decor_unis[di]);
        kid.append(d);
    }
    kid.append(test_kw_uni);
    if has_description {
        kid.append(description);
    }
    kid.append(test_lb_uni);
    kid.extend(body);
    kid.append(test_rb_uni);
    return self.b.mk_test(
        name=name,
        body=body,
        kid=kid,
        doc=NIL,
        description=description,
        decorators=decorators
    );
}

impl Parser.parse_switch_stmt -> int {
    switch_uni = self.consume_uni(TokenKind.KW_SWITCH);
    target = self.parse_expression();
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    cases: list[int] = [];
    while self.check_any(TokenKind.KW_CASE, TokenKind.KW_DEFAULT) {
        cases.append(self.parse_switch_case());
    }

    rb_uni = self.consume_uni(TokenKind.RBRACE);
    kid: list[int] = [switch_uni, target, lb_uni];
    kid.extend(cases);
    kid.append(rb_uni);
    return self.b.mk_switch_stmt(target=target, cases=cases, kid=kid);
}

impl Parser.parse_switch_case -> int {
    is_default = False;
    pattern = NIL;
    kw_uni = NIL;
    if self.match_tok(TokenKind.KW_DEFAULT) {
        is_default = True;
        kw_uni = self.make_uni_token(self.previous());
    } else {
        kw_uni = self.consume_uni(TokenKind.KW_CASE);
        pattern = self.parse_pattern();
    }
    colon_uni = self.consume_uni(TokenKind.COLON);
    body: list[int] = [];
    while not self.check_any(TokenKind.KW_CASE, TokenKind.KW_DEFAULT, TokenKind.RBRACE)
        and not self.at_end() {
        before = self.pos;
        stmt = self.parse_statement();
        if stmt != NIL {
            body.append(stmt);
        }

        if self.pos == before {
            self.advance();
        }
    }
    kid: list[int] = [kw_uni];
    if pattern {
        kid.append(pattern);
    }
    kid.append(colon_uni);
    kid.extend(body);
    return self.b.mk_switch_case(pattern=pattern, body=body, kid=kid);
}

impl Parser.parse_global_var -> int {
    glob_kw_uni = self.consume_uni(TokenKind.KW_GLOBAL);
    access = self.parse_access_tag();

    assignments: list[int] = [];
    glob_comma_unis: list[int] = [];
    assignments.append(self.parse_global_var_assignment());
    while self.match_tok(TokenKind.COMMA) {
        glob_comma_unis.append(self.make_uni_token(self.previous()));
        assignments.append(self.parse_global_var_assignment());
    }
    self.expect(TokenKind.SEMI);
    kid: list[int] = [glob_kw_uni];
    if access {
        kid.append(access);
    }

    for (i, a) in enumerate(assignments) {
        if i > 0 {
            kid.append(glob_comma_unis[i - 1]);
        }
        kid.append(a);
    }

    kid.append(
        self.b.mk_semi(
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
    return self.b.mk_global_vars(
        access=access, assignments=assignments, is_frozen=False, kid=kid, doc=NIL
    );
}

impl Parser.parse_global_var_assignment -> int {
    name_tok: LexToken;
    if self.check_name() {
        name_tok = self.expect_name();
    } elif self.is_keyword_token() {
        name_tok = self.advance();
    } else {
        name_tok = self.expect_name();
    }
    name = self.make_name_or_special(name_tok);
    type_tag: int = NIL;
    if self.match_tok(TokenKind.COLON) {
        gv_colon_uni = self.make_uni_token(self.previous());
        gv_own_kid: list[int] = [gv_colon_uni];
        gv_own_kind = self.parse_ownership_prefix(gv_own_kid);
        tp = self.parse_pipe();
        gv_own_kid.append(tp);
        type_tag = self.b.mk_sub_tag(tag=tp, ownership=gv_own_kind, kid=gv_own_kid);
    }
    value = NIL;
    targets: list[int] = [name];
    gv_eq_unis: list[int] = [];
    if self.match_tok(TokenKind.EQ) {
        gv_eq_unis.append(self.make_uni_token(self.previous()));
        value = self.parse_expression();

        while self.check(TokenKind.EQ) {
            targets.append(value);
            self.expect(TokenKind.EQ);
            gv_eq_unis.append(self.make_uni_token(self.previous()));
            value = self.parse_expression();
        }
    }
    kid: list[int] = [targets[0]];
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
    return self.b.mk_assignment(
        target=targets,
        value=value,
        type_tag=type_tag,
        kid=kid,
        mutable=True,
        aug_op=NIL,
        is_enum_stmt=False
    );
}

impl Parser.parse_impl_def -> int {
    decorators: list[int] = [];
    impl_decor_unis: list[int] = [];
    while self.check(TokenKind.DECOR_OP) {
        impl_decor_unis.append(self.make_uni_token(self.expect(TokenKind.DECOR_OP)));
        decorators.append(self.parse_atomic_chain());
    }
    impl_uni = self.consume_uni(TokenKind.KW_IMPL);

    target_names: list[int] = [];
    dot_unis: list[int] = [];
    target_names.append(self.parse_impl_target_name());
    while self.match_tok(TokenKind.DOT) {
        dot_unis.append(self.make_uni_token(self.previous()));
        target_names.append(self.parse_impl_target_name());
    }

    spec_sig: int = NIL;
    spec_is_inh = False;
    base_classes: list[int] = [];
    impl_inh_comma_unis: list[int] = [];
    impl_inh_lp_tok: LexToken | None = None;
    impl_inh_rp_uni: int = NIL;
    if self.check(TokenKind.LPAREN) {
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
            is_func_params = True;
        }
        if is_func_params {
            spec_sig = self.parse_func_signature();
        } else {
            impl_inh_lp_tok = self.expect(TokenKind.LPAREN);
            if not self.check(TokenKind.RPAREN) {
                base_classes.append(self.parse_atomic_chain());
                while self.match_tok(TokenKind.COMMA) {
                    impl_inh_comma_unis.append(self.make_uni_token(self.previous()));
                    base_classes.append(self.parse_atomic_chain());
                }
            }
            impl_inh_rp_uni = self.consume_uni(TokenKind.RPAREN);
            spec_is_inh = True;
        }
    } elif self.check(TokenKind.KW_WITH) {
        with_tok = self.expect(TokenKind.KW_WITH);
        event_type = self.parse_expression()
            if not self.check_any(TokenKind.KW_ENTRY, TokenKind.KW_EXIT)
            else NIL;
        event_tok = self.expect_any(TokenKind.KW_ENTRY, TokenKind.KW_EXIT);
        ev_kid: list[int] = [self.make_uni_token(with_tok)];
        if event_type != NIL {
            ev_kid.append(event_type);
        }
        ev_kid.append(self.make_uni_token(event_tok));
        spec_sig = self.b.mk_event_signature(
            event=self.make_uni_token(event_tok), arch_tag_info=event_type, kid=ev_kid
        );
    } elif self.check(TokenKind.RETURN_HINT)
        or (self.check(TokenKind.LPAREN) and not self.check(TokenKind.LBRACE)) {
        spec_sig = self.parse_func_signature();
    }

    body_stmts3: list[int] = [];
    body_expr3: int = NIL;
    lb_uni: int = NIL;
    rb_uni: int = NIL;
    if self.match_tok(TokenKind.LBRACE) {
        lb_uni = self.make_uni_token(self.previous());
        if self._is_impl_enum_body() {
            self._impl_enum_comma_unis = [];
            body_stmts3 = self.parse_impl_enum_body();
        } else {
            body_stmts3 = self._apply_implicit_return(self.parse_code_block_stmts());
        }
        rb_uni = self.consume_uni(TokenKind.RBRACE);
    } elif self.match_tok(TokenKind.KW_BY) {
        body_expr3 = self.parse_expression();
        self.expect(TokenKind.SEMI);
    } else {
        self.emit_diag("Expected '{' or 'by' for impl body", "E0047");
        self.expect(TokenKind.SEMI);
    }
    kid: list[int] = [];
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
    if spec_sig != NIL {
        kid.append(spec_sig);
    } elif spec_is_inh and len(base_classes) > 0 and impl_inh_lp_tok is not None {
        kid.append(self.make_uni_token(impl_inh_lp_tok));
        for (i, bc) in enumerate(base_classes) {
            if i > 0 {
                kid.append(impl_inh_comma_unis[i - 1]);
            }
            kid.append(bc);
        }
        kid.append(impl_inh_rp_uni);
    }
    if body_expr3 == NIL {
        if lb_uni {
            kid.append(lb_uni);
        }
        impl_enum_commas = self._impl_enum_comma_unis;
        comma_idx = 0;
        for (i, item) in enumerate(body_stmts3) {
            kid.append(item);

            _es = ENUM_STMT_SLOTS.get(self.b.kind_of(item), -1);
            if _es >= 0 and self.b.arg_bool(item, _es) and i < len(body_stmts3) - 1 {
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
        kid.append(body_expr3);
    }
    spec_arg: any = None;
    if spec_sig != NIL {
        spec_arg = spec_sig;
    } elif spec_is_inh {
        spec_arg = base_classes;
    }
    impl_body_arg: any = body_stmts3;
    if body_expr3 != NIL {
        impl_body_arg = body_expr3;
    }
    return self.b.mk_impl_def(
        decorators=decorators,
        target=target_names,
        spec=spec_arg,
        body=impl_body_arg,
        kid=kid,
        doc=NIL
    );
}

impl Parser._is_impl_enum_body -> bool {
    if self.check_name() and self.check_peek(TokenKind.COMMA) {
        return True;
    }

    if self.check_name() and self.check_peek(TokenKind.COLON) {
        save_pos = self.pos;
        self.advance();
        self.advance();

        depth = 0;
        while not self.at_end()
            and not (
                depth == 0
                and self.check_any(
                    TokenKind.EQ, TokenKind.COMMA, TokenKind.SEMI, TokenKind.RBRACE
                )
            ) {
            if self.check_any(TokenKind.LPAREN, TokenKind.LBRACE, TokenKind.LSQUARE) {
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
        result = False;
        if self.check(TokenKind.EQ) {
            self.advance();
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
                result = True;
            }
        } elif self.check(TokenKind.COMMA) {
            result = True;
        }
        self.pos = save_pos;
        return result;
    }

    if self.check_name() and self.check_peek(TokenKind.EQ) {
        save_pos = self.pos;
        self.advance();
        self.advance();
        depth = 0;
        while not self.at_end()
            and not (
                depth == 0
                and self.check_any(TokenKind.COMMA, TokenKind.SEMI, TokenKind.RBRACE)
            ) {
            if self.check_any(TokenKind.LPAREN, TokenKind.LBRACE, TokenKind.LSQUARE) {
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
        result = self.check(TokenKind.COMMA);
        self.pos = save_pos;
        return result;
    }
    return False;
}

impl Parser.parse_impl_target_name -> int {
    if self.check_name() {
        name_tok = self.expect_name();
        return self.make_name(name_tok);
    } elif self.check_any(TokenKind.KW_INIT, TokenKind.KW_POST_INIT) {
        name_tok = self.expect_any(TokenKind.KW_INIT, TokenKind.KW_POST_INIT);
        return self.b.mk_special_var_ref(
            var=self.make_special_name(name_tok), is_enum_stmt=False
        );
    } elif self.check_any(
        TokenKind.KW_ENTRY, TokenKind.KW_EXIT, TokenKind.KW_DEFAULT
    ) {
        name_tok = self.expect_any(
            TokenKind.KW_ENTRY, TokenKind.KW_EXIT, TokenKind.KW_DEFAULT
        );
        return self.make_special_name(name_tok);
    } elif self.is_keyword_token() {
        name_tok = self.advance();
        return self.make_special_name(name_tok);
    } else {
        name_tok = self.expect(TokenKind.NAME);
        return self.make_name(name_tok);
    }
}

impl Parser.parse_impl_enum_body -> list {
    members: list[int] = [];
    while not self.check(TokenKind.RBRACE) and not self.at_end() {
        if self.check_name() {
            name_tok = self.expect_name();
            name = self.make_name(name_tok, is_enum_stmt=True);
            type_tag: int = NIL;
            value: int = NIL;

            if self.match_tok(TokenKind.COLON) {
                ieb_colon_uni = self.make_uni_token(self.previous());
                tp = self.parse_pipe();
                type_tag = self.b.mk_sub_tag(tag=tp, kid=[ieb_colon_uni, tp]);
            }
            ieb_eq_uni: int = NIL;
            if self.match_tok(TokenKind.EQ) {
                ieb_eq_uni = self.make_uni_token(self.previous());
                value = self.parse_expression();
            }
            kid: list[int] = [name];
            if type_tag {
                kid.append(type_tag);
            }
            if value {
                kid.append(ieb_eq_uni);
                kid.append(value);
            }
            members.append(
                self.b.mk_assignment(
                    target=[name],
                    value=value,
                    type_tag=type_tag,
                    kid=kid,
                    mutable=True,
                    aug_op=NIL,
                    is_enum_stmt=True
                )
            );

            if self.match_tok(TokenKind.COMMA) {
                self._impl_enum_comma_unis.append(self.make_uni_token(self.previous()));
            }
        } else {
            break;
        }
    }
    return members;
}

impl Parser.parse_sem_def -> int {
    sem_kw_uni = self.consume_uni(TokenKind.KW_SEM);
    target_names: list[int] = [];
    sem_dot_unis: list[int] = [];
    target_names.append(self.parse_impl_target_name());
    while self.match_tok(TokenKind.DOT) {
        sem_dot_unis.append(self.make_uni_token(self.previous()));
        target_names.append(self.parse_impl_target_name());
    }

    sep_uni: int = NIL;
    if self.match_tok(TokenKind.EQ) {
        sep_uni = self.make_uni_token(self.previous());
    } elif self.match_tok(TokenKind.KW_IS) {
        sep_uni = self.make_uni_token(self.previous());
    } else {
        self.expect(TokenKind.EQ);
        sep_uni = self.make_uni_token(self.previous());
    }

    str_nodes: list[int] = [self.make_string(self.expect(TokenKind.STRING))];
    while self.check(TokenKind.STRING) {
        str_nodes.append(self.make_string(self.expect(TokenKind.STRING)));
    }
    value = self.b.mk_multi_string(strings=str_nodes, kid=str_nodes);
    kid: list[int] = [sem_kw_uni];
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
    return self.b.mk_sem_def(target=target_names, value=value, kid=kid);
}

impl Parser.parse_type_alias -> int {
    type_kw_uni = self.consume_uni(TokenKind.TYP_TYPE);
    access = self.parse_access_tag();
    name_tok: LexToken;
    if self.check_name() {
        name_tok = self.expect_name();
    } elif self.is_keyword_token() {
        name_tok = self.advance();
    } else {
        name_tok = self.expect_name();
    }
    name = self.make_name_or_special(name_tok);
    tp_list: list[int] = [];
    has_tp = False;
    tp_lb_uni: int = NIL;
    tp_rb_uni: int = NIL;
    tp_comma_unis: list[int] = [];
    if self.match_tok(TokenKind.LSQUARE) {
        tp_lb_uni = self.make_uni_token(self.previous());
        (tp_list, tp_comma_unis) = self.parse_type_params();
        has_tp = True;
        tp_rb_uni = self.consume_uni(TokenKind.RSQUARE);
    }
    eq_uni = self.consume_uni(TokenKind.EQ);
    value = self.parse_pipe();
    self.expect(TokenKind.SEMI);
    kid: list[int] = [type_kw_uni];
    if access {
        kid.append(access);
    }
    kid.append(name);
    if has_tp {
        kid.append(tp_lb_uni);
        for (i, tp) in enumerate(tp_list) {
            if i > 0 {
                kid.append(tp_comma_unis[i - 1]);
            }
            kid.append(tp);
        }
        kid.append(tp_rb_uni);
    }
    kid.append(eq_uni);
    kid.append(value);
    kid.append(self.make_semi());
    tp_arg: any = None;
    if has_tp {
        tp_arg = tp_list;
    }
    return self.b.mk_type_alias(
        name=name, type_params=tp_arg, value=value, access=access, kid=kid, doc=NIL
    );
}

impl Parser.parse_type_params -> tuple[(list, list)] {
    params: list[int] = [];
    comma_unis: list[int] = [];

    name_tok = self.expect_name();
    name = self.make_name_or_special(name_tok);
    bound: int = NIL;
    default_val: int = NIL;
    tp_kid: list[int] = [name];
    if self.match_tok(TokenKind.COLON) {
        tp_kid.append(self.make_uni_token(self.previous()));
        bound = self.parse_pipe();
        tp_kid.append(bound);
    }
    if self.match_tok(TokenKind.EQ) {
        tp_kid.append(self.make_uni_token(self.previous()));
        default_val = self.parse_pipe();
        tp_kid.append(default_val);
    }
    params.append(
        self.b.mk_type_param(
            name=name, bound=bound, default_val=default_val, kid=tp_kid
        )
    );
    while self.match_tok(TokenKind.COMMA) {
        comma_unis.append(self.make_uni_token(self.previous()));
        if self.check(TokenKind.RSQUARE) {
            break;
        }
        name_tok = self.expect_name();
        name = self.make_name_or_special(name_tok);
        bound = NIL;
        default_val = NIL;
        tp_kid = [name];
        if self.match_tok(TokenKind.COLON) {
            tp_kid.append(self.make_uni_token(self.previous()));
            bound = self.parse_pipe();
            tp_kid.append(bound);
        }
        if self.match_tok(TokenKind.EQ) {
            tp_kid.append(self.make_uni_token(self.previous()));
            default_val = self.parse_pipe();
            tp_kid.append(default_val);
        }
        params.append(
            self.b.mk_type_param(
                name=name, bound=bound, default_val=default_val, kid=tp_kid
            )
        );
    }
    return (params, comma_unis);
}

impl Parser.parse_visit_stmt -> int {
    visit_uni = self.consume_uni(TokenKind.KW_VISIT);

    insert_loc = NIL;
    colon1_uni = NIL;
    colon2_uni = NIL;
    if self.match_tok(TokenKind.COLON) {
        colon1_uni = self.make_uni_token(self.previous());
        insert_loc = self.parse_expression();
        colon2_uni = self.consume_uni(TokenKind.COLON);
    }
    target = self.parse_expression();
    else_body = NIL;
    has_semi = False;
    if self.check(TokenKind.KW_ELSE) {
        else_body = self.parse_else_stmt();
    } elif self.match_tok(TokenKind.SEMI) {
        has_semi = True;
    }
    kid: list[int] = [visit_uni];
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
    return self.b.mk_visit_stmt(
        insert_loc=insert_loc, target=target, else_body=else_body, kid=kid
    );
}

impl Parser.parse_report_stmt -> int {
    report_uni = self.consume_uni(TokenKind.KW_REPORT);
    expr = self.parse_expression();
    self.expect(TokenKind.SEMI);
    kid: list[int] = [report_uni, expr, self.make_semi()];
    return self.b.mk_report_stmt(expr=expr, kid=kid);
}
