"""Hand-written recursive descent parser for Jac.

This parser uses explicit precedence-level methods instead of a Pratt parser
for native compilation compatibility. Each precedence level is a separate
method, enabling direct function calls with no dynamic dispatch.
"""

import from .tokens { Token, TokenKind, SourceLoc }
import from .lexer { Lexer, LexerError }
import from .ast {
    AstNode,
    Expr,
    Stmt,
    CodeBlockStmt,
    ElementStmt,
    ArchBlockStmt,
    IntLiteral,
    FloatLiteral,
    StringLiteral,
    MultiString,
    BoolLiteral,
    NullLiteral,
    EllipsisLiteral,
    NameExpr,
    TypeRef,
    ListExpr,
    TupleExpr,
    SetExpr,
    DictExpr,
    DictEntry,
    ListCompr,
    SetCompr,
    DictCompr,
    GeneratorExpr,
    ComprGenerator,
    BinaryExpr,
    UnaryExpr,
    CompareExpr,
    Comparison,
    IfElseExpr,
    WalrusExpr,
    FuncCall,
    KeywordArg,
    AttrAccess,
    IndexExpr,
    SliceExpr,
    LambdaExpr,
    SpawnExpr,
    AwaitExpr,
    YieldExpr,
    PipeExpr,
    AtomicPipeExpr,
    ByExpr,
    ConcurrentExpr,
    UnpackExpr,
    RefExpr,
    EdgeExpr,
    ConnectExpr,
    DisconnectExpr,
    EdgeRefChain,
    EdgeOp,
    FilterCompr,
    FilterItem,
    AssignCompr,
    FString,
    FStringPart,
    FStringText,
    FStringExpr,
    JsxElement,
    JsxAttr,
    JsxChild,
    JsxChildExpr,
    JsxChildText,
    JsxFragment,
    ExprStmt,
    Assignment,
    IfStmt,
    ElseIf,
    ElseStmt,
    WhileStmt,
    ForStmt,
    RangeForStmt,
    TryStmt,
    ExceptHandler,
    WithStmt,
    WithItem,
    MatchStmt,
    MatchCase,
    MatchPattern,
    LiteralPattern,
    CapturePattern,
    WildcardPattern,
    SequencePattern,
    MappingPattern,
    MappingPatternEntry,
    StarPattern,
    SingletonPattern,
    AttrPattern,
    ClassPattern,
    KeywordPattern,
    OrPattern,
    AsPattern,
    SwitchStmt,
    SwitchCase,
    ReturnStmt,
    YieldStmt,
    BreakStmt,
    ContinueStmt,
    RaiseStmt,
    AssertStmt,
    DeleteStmt,
    PassStmt,
    VisitStmt,
    DisengageStmt,
    ReportStmt,
    GlobalStmt,
    NonLocalStmt,
    TypedContextBlock,
    TypeExpr,
    SimpleType,
    GenericType,
    UnionType,
    OptionalType,
    ParamVar,
    FuncSignature,
    EventSignature,
    Archetype,
    Ability,
    HasStmt,
    HasVarDecl,
    HasVar,
    Enum,
    EnumMember,
    ImplDef,
    TestDef,
    GlobalVarDef,
    ImportStmt,
    ImportItem,
    ContextBlock,
    EntryBlock,
    SemDef,
    PyCodeBlock,
    TypeAliasStmt,
    Module
}

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
# Parser
# =============================================================================
obj Parser {
    has tokens: list[Token],
        pos: int = 0,
        errors: list[ParseError] = [],
        file_path: str = "<input>";

    # -------------------------------------------------------------------------
    # Token Access
    # -------------------------------------------------------------------------
    def current -> Token {
        if self.pos < len(self.tokens) {
            return self.tokens[self.pos];
        }
        return self.tokens[-1];  # EOF

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
        return self.current();  # Return current for error recovery

    }

    def error(message: str) {
        self.errors.append(ParseError(message=message, loc=self.current().loc));
    }

    # -------------------------------------------------------------------------
    # Synchronization (Error Recovery)
    # -------------------------------------------------------------------------
    def synchronize {
        self.advance();

        while not self.at_end() {
            # Statement boundaries
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
        doc: StringLiteral | None = None;
        body: list[ElementStmt] = [];

        # Optional docstring
        if self.check(TokenKind.STRING) {
            tok = self.advance();
            doc = StringLiteral(token=tok, value=tok.value);
        }

        # Parse top-level statements
        while not self.at_end() {
            stmt = self.parse_element_stmt();
            if stmt is not None {
                body.append(stmt);
            }
        }

        return Module(
            name=self.file_path, file_path=self.file_path, doc=doc, body=body
        );
    }

    # =========================================================================
    # EXPRESSION PARSING - Explicit Precedence Levels
    # =========================================================================
    #
    # Precedence chain matches jac.lark (lowest to highest):
    #
    #  1. expression      - Entry point: ternary wrapper + lambda
    #  2. concurrent_expr - flow/wait prefix
    #  3. walrus_assign   - walrus operator :=
    #  4. by_expr         - by expression (right-associative)
    #  5. pipe            - forward pipe |>
    #  6. pipe_back       - backward pipe <|
    #  7. bitwise_or      - bitwise |
    #  8. bitwise_xor     - bitwise ^
    #  9. bitwise_and     - bitwise &
    # 10. shift           - << >>
    # 11. logical_or      - keyword or
    # 12. logical_and     - keyword and
    # 13. logical_not     - keyword not
    # 14. compare         - comparisons == != < > <= >= in is
    # 15. arithmetic      - + -
    # 16. term            - * / // % @
    # 17. power           - ** (right-associative)
    # 18. factor          - unary - + ~
    # 19. connect         - edge connect/disconnect
    # 20. atomic_pipe     - :> forward
    # 21. atomic_pipe_bk  - <: backward
    # 22. spawn_prefix    - spawn prefix
    # 23. unpack          - *expr
    # 24. ref             - &expr
    # 25. await_expr      - await prefix
    # 26. pipe_call       - prefix pipe/spawn on atomic
    # 27. atomic_chain    - postfix operations
    # 28. primary         - atoms
    def parse_expression -> Expr {
        # Lambda at expression level
        if self.check(TokenKind.KW_LAMBDA) {
            return self.parse_lambda_expr();
        }

        # Parse the main expression (concurrent_expr handles the rest)
        expr = self.parse_concurrent_expr();

        # Check for ternary conditional
        if self.match_tok(TokenKind.KW_IF) {
            condition = self.parse_expression();
            self.expect(TokenKind.KW_ELSE);
            else_value = self.parse_expression();
            return IfElseExpr(value=expr, condition=condition, else_value=else_value);
        }

        return expr;
    }

    # Level 1: Lambda expressions
    def parse_lambda_expr -> Expr {
        self.expect(TokenKind.KW_LAMBDA);

        # Parse parameters (optional)
        params: list[ParamVar] = [];
        if not self.check_any(TokenKind.COLON, TokenKind.LBRACE, TokenKind.RETURN_HINT) {
            params = self.parse_lambda_params();
        }

        # Optional return type hint
        return_type: Expr | None = None;
        if self.match_tok(TokenKind.RETURN_HINT) {
            return_type = self.parse_type_expr();
        }

        # Body: either : expr or { stmts }
        if self.match_tok(TokenKind.COLON) {
            body = self.parse_expression();
            return LambdaExpr(params=params, body=body);
        } elif self.check(TokenKind.LBRACE) {
            # Block body - parse as code block, return last expr
            stmts = self.parse_code_block();
            # For now, wrap in a placeholder - proper handling needs more work
            self.error("Lambda with block body not fully implemented");
            return LambdaExpr(params=params, body=NullLiteral(token=self.current()));
        }

        self.error("Expected ':' or '{' after lambda parameters");
        return LambdaExpr(params=params, body=NullLiteral(token=self.current()));
    }

    def parse_lambda_params -> list[ParamVar] {
        params: list[ParamVar] = [];

        while not self.check_any(
            TokenKind.COLON, TokenKind.LBRACE, TokenKind.RETURN_HINT
        ) {
            # Handle *args and **kwargs
            is_star = self.match_tok(TokenKind.STAR_MUL) is not None;
            is_kwargs = is_star and self.match_tok(TokenKind.STAR_MUL) is not None;

            name = self.expect(TokenKind.NAME);
            type_tag: Expr | None = None;

            if self.match_tok(TokenKind.COLON) {
                type_tag = self.parse_type_expr();
            }

            default_val: Expr | None = None;
            if self.match_tok(TokenKind.EQ) {
                default_val = self.parse_expression();
            }

            params.append(
                ParamVar(
                    name=name,
                    type_tag=type_tag,
                    default=default_val,
                    is_star=is_star,
                    is_kwargs=is_kwargs
                )
            );

            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
        }

        return params;
    }

    # Level 2: Concurrent expressions (flow/wait)
    def parse_concurrent_expr -> Expr {
        if self.check_any(TokenKind.KW_FLOW, TokenKind.KW_WAIT) {
            kind = self.advance();
            target = self.parse_walrus_expr();
            return ConcurrentExpr(kind=kind, target=target);
        }
        return self.parse_walrus_expr();
    }

    # Level 3: Walrus assignment (:=)
    def parse_walrus_expr -> Expr {
        # Check for walrus pattern: NAME :=
        if self.check(TokenKind.NAME) and self.peek().kind == TokenKind.WALRUS_EQ {
            name = self.advance();
            self.advance();  # consume :=
            value = self.parse_by_expr();
            return WalrusExpr(target=NameExpr(name=name), value=value);
        }
        return self.parse_by_expr();
    }

    # Level 4: By expression (right-associative)
    def parse_by_expr -> Expr {
        left = self.parse_pipe_expr();

        if self.match_tok(TokenKind.KW_BY) {
            by_clause = self.parse_by_expr();  # Right-associative
            return ByExpr(target=left, by_clause=by_clause);
        }

        return left;
    }

    # Level 5: Forward pipe (|>)
    def parse_pipe_expr -> Expr {
        left = self.parse_pipe_back_expr();

        while self.match_tok(TokenKind.PIPE_FWD) {
            op = self.tokens[self.pos - 1];
            right = self.parse_pipe_back_expr();
            left = PipeExpr(left=left, op=op, right=right);
        }

        return left;
    }

    # Level 6: Backward pipe (<|)
    def parse_pipe_back_expr -> Expr {
        left = self.parse_bitor_expr();

        while self.match_tok(TokenKind.PIPE_BKWD) {
            op = self.tokens[self.pos - 1];
            right = self.parse_bitor_expr();
            left = PipeExpr(left=left, op=op, right=right);
        }

        return left;
    }

    # Level 7: Bitwise OR
    def parse_bitor_expr -> Expr {
        left = self.parse_bitxor_expr();

        while self.match_tok(TokenKind.BW_OR) {
            op = self.tokens[self.pos - 1];
            right = self.parse_bitxor_expr();
            left = BinaryExpr(left=left, op=op, right=right);
        }

        return left;
    }

    # Level 8: Bitwise XOR
    def parse_bitxor_expr -> Expr {
        left = self.parse_bitand_expr();

        while self.match_tok(TokenKind.BW_XOR) {
            op = self.tokens[self.pos - 1];
            right = self.parse_bitand_expr();
            left = BinaryExpr(left=left, op=op, right=right);
        }

        return left;
    }

    # Level 9: Bitwise AND
    def parse_bitand_expr -> Expr {
        left = self.parse_shift_expr();

        while self.match_tok(TokenKind.BW_AND) {
            op = self.tokens[self.pos - 1];
            right = self.parse_shift_expr();
            left = BinaryExpr(left=left, op=op, right=right);
        }

        return left;
    }

    # Level 10: Shift
    def parse_shift_expr -> Expr {
        left = self.parse_or_expr();

        while self.check_any(TokenKind.LSHIFT, TokenKind.RSHIFT) {
            op = self.advance();
            right = self.parse_or_expr();
            left = BinaryExpr(left=left, op=op, right=right);
        }

        return left;
    }

    # Level 11: Logical OR
    def parse_or_expr -> Expr {
        left = self.parse_and_expr();

        while self.match_tok(TokenKind.KW_OR) {
            op = self.tokens[self.pos - 1];
            right = self.parse_and_expr();
            left = BinaryExpr(left=left, op=op, right=right);
        }

        return left;
    }

    # Level 12: Logical AND
    def parse_and_expr -> Expr {
        left = self.parse_not_expr();

        while self.match_tok(TokenKind.KW_AND) {
            op = self.tokens[self.pos - 1];
            right = self.parse_not_expr();
            left = BinaryExpr(left=left, op=op, right=right);
        }

        return left;
    }

    # Level 13: Logical NOT
    def parse_not_expr -> Expr {
        if self.match_tok(TokenKind.KW_NOT) {
            op = self.tokens[self.pos - 1];
            operand = self.parse_not_expr();  # Right-associative
            return UnaryExpr(op=op, operand=operand);
        }
        return self.parse_compare_expr();
    }

    # Level 14: Comparisons
    def parse_compare_expr -> Expr {
        left = self.parse_add_expr();

        comparisons: list[Comparison] = [];
        while self.is_compare_op() {
            op = self.advance();
            right = self.parse_add_expr();
            comparisons.append(Comparison(op=op, right=right));
        }

        if len(comparisons) == 0 {
            return left;
        } elif len(comparisons) == 1 {
            return BinaryExpr(
                left=left, op=comparisons[0].op, right=comparisons[0].right
            );
        }
        return CompareExpr(first=left, comparisons=comparisons);
    }

    def is_compare_op -> bool {
        return self.check_any(
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
    }

    # Level 15: Addition/Subtraction
    def parse_add_expr -> Expr {
        left = self.parse_mul_expr();

        while self.check_any(TokenKind.PLUS, TokenKind.MINUS) {
            op = self.advance();
            right = self.parse_mul_expr();
            left = BinaryExpr(left=left, op=op, right=right);
        }

        return left;
    }

    # Level 16: Multiplication/Division/Modulo/Matmul
    def parse_mul_expr -> Expr {
        left = self.parse_power_expr();

        while self.check_any(
            TokenKind.STAR_MUL,
            TokenKind.DIV,
            TokenKind.FLOOR_DIV,
            TokenKind.MOD,
            TokenKind.DECOR_OP
        ) {
            op = self.advance();
            right = self.parse_power_expr();
            left = BinaryExpr(left=left, op=op, right=right);
        }

        return left;
    }

    # Level 17: Power (right-associative)
    def parse_power_expr -> Expr {
        left = self.parse_factor_expr();

        if self.match_tok(TokenKind.STAR_POW) {
            op = self.tokens[self.pos - 1];
            right = self.parse_power_expr();  # Right-associative
            return BinaryExpr(left=left, op=op, right=right);
        }

        return left;
    }

    # Level 18: Factor (unary)
    def parse_factor_expr -> Expr {
        if self.check_any(TokenKind.MINUS, TokenKind.PLUS, TokenKind.BW_NOT) {
            op = self.advance();
            operand = self.parse_factor_expr();  # Right-associative
            return UnaryExpr(op=op, operand=operand);
        }
        return self.parse_connect_expr();
    }

    # Level 19: Connect expressions (edge operations)
    def parse_connect_expr -> Expr {
        left = self.parse_atomic_pipe_expr();

        while self.is_connect_op() {
            op = self.advance();
            right = self.parse_atomic_pipe_expr();
            left = ConnectExpr(source=left, direction=op, target=right);
        }

        return left;
    }

    def is_connect_op -> bool {
        return self.check_any(
            TokenKind.CARROW_R,
            TokenKind.CARROW_L,
            TokenKind.CARROW_BI,
            TokenKind.CARROW_R_P1,
            TokenKind.CARROW_R_P2,
            TokenKind.CARROW_L_P1,
            TokenKind.CARROW_L_P2
        );
    }

    # Level 20: Atomic pipe (:>)
    def parse_atomic_pipe_expr -> Expr {
        left = self.parse_atomic_pipe_back_expr();

        while self.match_tok(TokenKind.A_PIPE_FWD) {
            op = self.tokens[self.pos - 1];
            right = self.parse_atomic_pipe_back_expr();
            left = AtomicPipeExpr(left=left, op=op, right=right);
        }

        return left;
    }

    # Level 21: Atomic pipe back (<:)
    def parse_atomic_pipe_back_expr -> Expr {
        left = self.parse_spawn_prefix_expr();

        while self.match_tok(TokenKind.A_PIPE_BKWD) {
            op = self.tokens[self.pos - 1];
            right = self.parse_spawn_prefix_expr();
            left = AtomicPipeExpr(left=left, op=op, right=right);
        }

        return left;
    }

    # Level 22: Spawn prefix
    def parse_spawn_prefix_expr -> Expr {
        if self.match_tok(TokenKind.KW_SPAWN) {
            target = self.parse_unpack_expr();
            return SpawnExpr(target=target, location=None);
        }
        return self.parse_unpack_expr();
    }

    # Level 23: Unpack (*expr)
    def parse_unpack_expr -> Expr {
        if self.match_tok(TokenKind.STAR_MUL) {
            target = self.parse_ref_expr();
            return UnpackExpr(target=target);
        }
        return self.parse_ref_expr();
    }

    # Level 24: Reference (&expr)
    def parse_ref_expr -> Expr {
        if self.match_tok(TokenKind.BW_AND) {
            target = self.parse_await_expr();
            return RefExpr(target=target);
        }
        return self.parse_await_expr();
    }

    # Level 25: Await
    def parse_await_expr -> Expr {
        if self.match_tok(TokenKind.KW_AWAIT) {
            target = self.parse_pipe_call_expr();
            return AwaitExpr(target=target);
        }
        return self.parse_pipe_call_expr();
    }

    # Level 26: Pipe call prefix
    def parse_pipe_call_expr -> Expr {
        # These are prefix operators that can appear before atomic_chain
        if self.match_tok(TokenKind.PIPE_FWD) {
            op = self.tokens[self.pos - 1];
            target = self.parse_atomic_chain();
            # This is a special pipe-call form
            return PipeExpr(left=NullLiteral(token=op), op=op, right=target);
        }
        if self.match_tok(TokenKind.A_PIPE_FWD) {
            op = self.tokens[self.pos - 1];
            target = self.parse_atomic_chain();
            return AtomicPipeExpr(left=NullLiteral(token=op), op=op, right=target);
        }
        return self.parse_atomic_chain();
    }

    # Level 27: Atomic chain (postfix operations)
    def parse_atomic_chain -> Expr {
        expr = self.parse_primary_expr();

        while True {
            # Attribute access: obj.attr
            if self.match_tok(TokenKind.DOT) {
                attr = self.expect(TokenKind.NAME);
                expr = AttrAccess(target=expr, attr=attr);
            }
            # Forward dot: obj.>attr
            elif self.match_tok(TokenKind.DOT_FWD) {
                attr = self.expect(TokenKind.NAME);
                expr = AttrAccess(target=expr, attr=attr);  # TODO: distinguish from regular dot
            }
            # Backward dot: obj<.attr
            elif self.match_tok(TokenKind.DOT_BKWD) {
                attr = self.expect(TokenKind.NAME);
                expr = AttrAccess(target=expr, attr=attr);  # TODO: distinguish from regular dot
            }
            # Null-safe access: obj?.attr
            elif self.match_tok(TokenKind.NULL_OK) {
                attr = self.expect(TokenKind.NAME);
                expr = AttrAccess(target=expr, attr=attr, null_ok=True);
            }
            # Function call: func(args) or generator comprehension
            elif self.match_tok(TokenKind.LPAREN) {
                # Check for filter comprehension (?...)
                if self.check(TokenKind.NULL_OK) {
                    expr = self.parse_filter_compr(expr);
                }
                # Check for assign comprehension (=...)
                elif self.check(TokenKind.EQ) {
                    expr = self.parse_assign_compr(expr);
                } else {
                    expr = self.parse_call_args(expr);
                }
            }
            # Index or slice: obj[index]
            elif self.match_tok(TokenKind.LSQUARE) {
                expr = self.parse_index_or_slice(expr);
            }
            # Type backtick: expr`Type
            elif self.match_tok(TokenKind.TYPE_OP) {
                expr = TypeRef(type_op=self.tokens[self.pos - 1], target=expr);
            } else {
                break;
            }
        }

        return expr;
    }

    def parse_filter_compr(target: Expr) -> Expr {
        self.expect(TokenKind.NULL_OK);

        # Check for typed filter: `?type:filters
        is_typed = self.match_tok(TokenKind.TYPE_OP) is not None;
        type_filter: Expr | None = None;
        filters: list[FilterItem] = [];

        if is_typed {
            type_filter = self.parse_expression();
            if self.match_tok(TokenKind.COLON) {
                filters = self.parse_filter_list();
            }
        } else {
            filters = self.parse_filter_list();
        }

        self.expect(TokenKind.RPAREN);
        return FilterCompr(
            is_typed=is_typed, type_filter=type_filter, null_ok=True, filters=filters
        );
    }

    def parse_filter_list -> list[FilterItem] {
        filters: list[FilterItem] = [];

        while not self.check(TokenKind.RPAREN) {
            name = self.expect(TokenKind.NAME);
            if not self.is_compare_op() {
                self.error("Expected comparison operator in filter");
                break;
            }
            op = self.advance();
            value = self.parse_expression();
            filters.append(FilterItem(name=name, op=op, value=value));

            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
        }

        return filters;
    }

    def parse_assign_compr(target: Expr) -> Expr {
        self.expect(TokenKind.EQ);

        assignments: list[KeywordArg] = [];
        while not self.check(TokenKind.RPAREN) {
            name = self.expect(TokenKind.NAME);
            self.expect(TokenKind.EQ);
            value = self.parse_expression();
            assignments.append(KeywordArg(name=name, value=value));

            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
        }

        self.expect(TokenKind.RPAREN);
        return AssignCompr(assignments=assignments);
    }

    def parse_call_args(target: Expr) -> FuncCall {
        args: list[Expr] = [];
        kwargs: list[KeywordArg] = [];

        while not self.check(TokenKind.RPAREN) and not self.at_end() {
            # Check for keyword argument
            if self.check(TokenKind.NAME) and self.peek().kind == TokenKind.EQ {
                name = self.advance();
                self.advance();  # Skip =
                value = self.parse_expression();
                kwargs.append(KeywordArg(name=name, value=value));
            }
            # Check for *args
            elif self.match_tok(TokenKind.STAR_MUL) {
                value = self.parse_expression();
                # Handle star expansion
                args.append(UnaryExpr(op=self.tokens[self.pos - 1], operand=value));
            }
            # Check for **kwargs
            elif self.match_tok(TokenKind.STAR_POW) {
                value = self.parse_expression();
                args.append(UnaryExpr(op=self.tokens[self.pos - 1], operand=value));
            } else {
                args.append(self.parse_expression());
            }

            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
        }

        self.expect(TokenKind.RPAREN);
        return FuncCall(target=target, args=args, kwargs=kwargs);
    }

    def parse_index_or_slice(target: Expr) -> Expr {
        # Check for slice
        if self.check(TokenKind.COLON) {
            return self.parse_slice(target, None);
        }

        index = self.parse_expression();

        # Check if this is a slice
        if self.match_tok(TokenKind.COLON) {
            return self.parse_slice(target, index);
        }

        self.expect(TokenKind.RSQUARE);
        return IndexExpr(target=target, index=index);
    }

    def parse_slice(target: Expr, start: Expr | None) -> SliceExpr {
        stop: Expr | None = None;
        step: Expr | None = None;

        if not self.check_any(TokenKind.COLON, TokenKind.RSQUARE) {
            stop = self.parse_expression();
        }

        if self.match_tok(TokenKind.COLON) {
            if not self.check(TokenKind.RSQUARE) {
                step = self.parse_expression();
            }
        }

        self.expect(TokenKind.RSQUARE);
        return SliceExpr(target=target, start=start, stop=stop, step=step);
    }

    # Level 17: Primary (atoms)
    def parse_primary_expr -> Expr {
        # Integer literal
        if self.check_any(TokenKind.INT, TokenKind.HEX, TokenKind.BIN, TokenKind.OCT) {
            tok = self.advance();
            return IntLiteral(token=tok, value=0);  # Value parsed from token

        }

        # Float literal
        if self.check(TokenKind.FLOAT) {
            tok = self.advance();
            return FloatLiteral(token=tok, value=0.0);
        }

        # String literal (with multistring support for adjacent strings)
        if self.check(TokenKind.STRING) {
            return self.parse_multistring();
        }

        # Boolean literal
        if self.check(TokenKind.BOOL) {
            tok = self.advance();
            return BoolLiteral(token=tok, value=tok.value == "True");
        }

        # Null literal
        if self.check(TokenKind.NULL) {
            tok = self.advance();
            return NullLiteral(token=tok);
        }

        # Ellipsis
        if self.check(TokenKind.ELLIPSIS) {
            tok = self.advance();
            return EllipsisLiteral(token=tok);
        }

        # Name/identifier
        if self.check(TokenKind.NAME) {
            tok = self.advance();
            return NameExpr(name=tok);
        }

        # Special identifiers
        if self.check_any(
            TokenKind.KW_SELF,
            TokenKind.KW_SUPER,
            TokenKind.KW_HERE,
            TokenKind.KW_ROOT,
            TokenKind.KW_VISITOR
        ) {
            tok = self.advance();
            return NameExpr(name=tok);
        }

        # Parenthesized expression or tuple
        if self.match_tok(TokenKind.LPAREN) {
            return self.parse_paren_expr();
        }

        # List or list comprehension
        if self.match_tok(TokenKind.LSQUARE) {
            return self.parse_list_expr();
        }

        # Set or dict or comprehension
        if self.match_tok(TokenKind.LBRACE) {
            return self.parse_brace_expr();
        }

        # Spawn expression (at primary level - note: also handled at precedence level 22)
        if self.match_tok(TokenKind.KW_SPAWN) {
            target = self.parse_atomic_chain();
            location: Expr | None = None;
            if self.match_tok(TokenKind.KW_ON) or self.match_tok(TokenKind.ARROW_R) {
                location = self.parse_expression();
            }
            return SpawnExpr(target=target, location=location);
        }

        # Type reference
        if self.match_tok(TokenKind.TYPE_OP) {
            type_op = self.tokens[self.pos - 1];
            target = self.parse_primary_expr();
            return TypeRef(type_op=type_op, target=target);
        }

        # F-string (with multistring support)
        if self.is_fstring_start() {
            return self.parse_multistring();
        }

        # JSX element: <Tag>...</Tag> or <>...</>
        if self.check(TokenKind.JSX_FRAG_OPEN) {
            return self.parse_jsx_fragment();
        }
        if self.check(TokenKind.LT) and self.is_jsx_start() {
            return self.parse_jsx_element();
        }

        # Edge reference chain: [-->], [<--], etc.
        if self.check(TokenKind.LSQUARE) and self.is_edge_ref_start() {
            return self.parse_edge_ref_chain();
        }

        self.error(f"Unexpected token in expression: {self.current().kind}");
        return NameExpr(name=self.advance());  # Error recovery

    }

    def is_edge_ref_start -> bool {
        # Look ahead to see if this is [-->], [<--], [async ...], [node ...], etc.
        saved_pos = self.pos;
        self.advance();  # Skip [

        result = self.check_any(
            TokenKind.ARROW_R,
            TokenKind.ARROW_L,
            TokenKind.ARROW_BI,
            TokenKind.ARROW_R_P1,
            TokenKind.ARROW_L_P1,
            TokenKind.KW_ASYNC,
            TokenKind.KW_NODE,
            TokenKind.KW_EDGE
        );

        # Also check if it starts with an expression followed by edge operator
        if not result and not self.check(TokenKind.RSQUARE) {
            # Try to parse expression and see if edge op follows
            # This is a simplified heuristic - we look for common patterns
            tok = self.current();
            if tok.kind == TokenKind.NAME or tok.kind == TokenKind.KW_SELF {
                self.advance();
                result = self.check_any(
                    TokenKind.ARROW_R,
                    TokenKind.ARROW_L,
                    TokenKind.ARROW_BI,
                    TokenKind.ARROW_R_P1,
                    TokenKind.ARROW_L_P1
                );
            }
        }

        self.pos = saved_pos;  # Restore position
        return result;
    }

    def parse_edge_ref_chain -> EdgeRefChain {
        self.expect(TokenKind.LSQUARE);

        is_async = self.match_tok(TokenKind.KW_ASYNC) is not None;
        arch_kind: Token | None = None;

        # Optional node/edge keyword
        if self.check_any(TokenKind.KW_NODE, TokenKind.KW_EDGE) {
            arch_kind = self.advance();
        }

        # Optional base expression
        base: Expr | None = None;
        if not self.is_edge_direction_op() {
            base = self.parse_expression();
        }

        # Parse edge operations
        operations: list[EdgeOp] = [];
        while self.is_edge_direction_op() {
            direction = self.advance();
            filter_type: Expr | None = None;
            filter_expr: Expr | None = None;

            # Check for parameterized edge: ->:Type:->
            if direction.kind in [TokenKind.ARROW_R_P1, TokenKind.ARROW_L_P1] {
                filter_type = self.parse_expression();
                # Expect closing arrow part
                if direction.kind == TokenKind.ARROW_R_P1 {
                    self.expect(TokenKind.ARROW_R_P2);
                } else {
                    self.expect(TokenKind.ARROW_L_P2);
                }
            }

            # Optional filter expression after edge op
            if not self.check(TokenKind.RSQUARE) and not self.is_edge_direction_op() {
                # Could be filter comprehension or expression
                if self.check(TokenKind.LPAREN) {
                    filter_expr = self.parse_expression();
                } elif not self.check(TokenKind.RSQUARE) {
                    filter_expr = self.parse_expression();
                }
            }

            operations.append(
                EdgeOp(
                    direction=direction,
                    filter_type=filter_type,
                    filter_expr=filter_expr
                )
            );
        }

        self.expect(TokenKind.RSQUARE);
        return EdgeRefChain(
            base=base, is_async=is_async, arch_kind=arch_kind, operations=operations
        );
    }

    def is_edge_direction_op -> bool {
        return self.check_any(
            TokenKind.ARROW_R,
            TokenKind.ARROW_L,
            TokenKind.ARROW_BI,
            TokenKind.ARROW_R_P1,
            TokenKind.ARROW_L_P1
        );
    }

    def parse_paren_expr -> Expr {
        # Empty tuple
        if self.match_tok(TokenKind.RPAREN) {
            return TupleExpr(elements=[]);
        }

        # Generator expression check
        first = self.parse_expression();

        # Check for comprehension
        if self.check(TokenKind.KW_FOR) {
            generators = self.parse_comprehension_clauses();
            self.expect(TokenKind.RPAREN);
            return GeneratorExpr(element=first, generators=generators);
        }

        # Tuple with trailing comma or multiple elements
        if self.match_tok(TokenKind.COMMA) {
            elements = [first];
            while not self.check(TokenKind.RPAREN) and not self.at_end() {
                elements.append(self.parse_expression());
                if not self.match_tok(TokenKind.COMMA) {
                    break;
                }
            }
            self.expect(TokenKind.RPAREN);
            return TupleExpr(elements=elements);
        }

        # Single parenthesized expression
        self.expect(TokenKind.RPAREN);
        return first;
    }

    def parse_list_expr -> Expr {
        # Empty list
        if self.match_tok(TokenKind.RSQUARE) {
            return ListExpr(elements=[]);
        }

        first = self.parse_expression();

        # Check for comprehension
        if self.check(TokenKind.KW_FOR) {
            generators = self.parse_comprehension_clauses();
            self.expect(TokenKind.RSQUARE);
            return ListCompr(element=first, generators=generators);
        }

        # Regular list
        elements = [first];
        while self.match_tok(TokenKind.COMMA) {
            if self.check(TokenKind.RSQUARE) {
                break;  # Trailing comma
            }
            elements.append(self.parse_expression());
        }

        self.expect(TokenKind.RSQUARE);
        return ListExpr(elements=elements);
    }

    def parse_brace_expr -> Expr {
        # Empty dict
        if self.match_tok(TokenKind.RBRACE) {
            return DictExpr(entries=[]);
        }

        first = self.parse_expression();

        # Check for dict (key: value)
        if self.match_tok(TokenKind.COLON) {
            value = self.parse_expression();
            # Dict comprehension
            if self.check(TokenKind.KW_FOR) {
                generators = self.parse_comprehension_clauses();
                self.expect(TokenKind.RBRACE);
                return DictCompr(key=first, value=value, generators=generators);
            }
            # Regular dict
            entries = [DictEntry(key=first, value=value)];
            while self.match_tok(TokenKind.COMMA) {
                if self.check(TokenKind.RBRACE) {
                    break;
                }
                key = self.parse_expression();
                self.expect(TokenKind.COLON);
                val = self.parse_expression();
                entries.append(DictEntry(key=key, value=val));
            }
            self.expect(TokenKind.RBRACE);
            return DictExpr(entries=entries);
        }

        # Set comprehension
        if self.check(TokenKind.KW_FOR) {
            generators = self.parse_comprehension_clauses();
            self.expect(TokenKind.RBRACE);
            return SetCompr(element=first, generators=generators);
        }

        # Regular set
        elements = [first];
        while self.match_tok(TokenKind.COMMA) {
            if self.check(TokenKind.RBRACE) {
                break;
            }
            elements.append(self.parse_expression());
        }

        self.expect(TokenKind.RBRACE);
        return SetExpr(elements=elements);
    }

    def parse_comprehension_clauses -> list[ComprGenerator] {
        generators: list[ComprGenerator] = [];

        while self.check_any(TokenKind.KW_FOR, TokenKind.KW_ASYNC) {
            is_async = self.match_tok(TokenKind.KW_ASYNC) is not None;
            self.expect(TokenKind.KW_FOR);

            target = self.parse_expression();
            self.expect(TokenKind.KW_IN);
            iter = self.parse_or_expr();  # Don't parse full expression (no if-else)

            conditions: list[Expr] = [];
            while self.match_tok(TokenKind.KW_IF) {
                conditions.append(self.parse_or_expr());
            }

            generators.append(
                ComprGenerator(
                    target=target, iter=iter, conditions=conditions, is_async=is_async
                )
            );
        }

        return generators;
    }

    def parse_multistring -> Expr {
        parts: list[Expr] = [];

        # Collect all adjacent strings and f-strings
        while self.is_string_start() {
            if self.check(TokenKind.STRING) {
                tok = self.advance();
                parts.append(StringLiteral(token=tok, value=tok.value));
            } elif self.is_fstring_start() {
                parts.append(self.parse_fstring());
            } else {
                break;
            }
        }

        # Single string - return as-is
        if len(parts) == 1 {
            return parts[0];
        }

        # Multiple adjacent strings - return as MultiString
        return MultiString(parts=parts);
    }

    def is_string_start -> bool {
        return self.check(TokenKind.STRING) or self.is_fstring_start();
    }

    def is_fstring_start -> bool {
        return self.check_any(
            TokenKind.F_DQ_START,
            TokenKind.F_SQ_START,
            TokenKind.F_TDQ_START,
            TokenKind.F_TSQ_START,
            TokenKind.RF_DQ_START,
            TokenKind.RF_SQ_START,
            TokenKind.RF_TDQ_START,
            TokenKind.RF_TSQ_START
        );
    }

    def is_jsx_start -> bool {
        if not self.check(TokenKind.LT) {
            return False;
        }
        # Look at next character to see if it's a valid JSX tag name start
        # JSX tags start with uppercase letter or lowercase for built-in HTML tags
        next_tok = self.peek();
        return next_tok.kind == TokenKind.NAME or next_tok.kind == TokenKind.JSX_NAME;
    }

    def parse_jsx_element -> JsxElement {
        self.expect(TokenKind.LT);

        # Parse tag name
        tag: Token;
        if self.check(TokenKind.JSX_NAME) {
            tag = self.advance();
        } else {
            tag = self.expect(TokenKind.NAME);
        }

        # Parse attributes
        attrs = self.parse_jsx_attributes();

        # Self-closing tag: <Tag ... />
        if self.match_tok(TokenKind.JSX_SELF_CLOSE) {
            return JsxElement(tag=tag, attrs=attrs, is_self_closing=True);
        }

        # Opening tag end: >
        self.expect(TokenKind.GT);

        # Parse children
        children = self.parse_jsx_children(tag.value);

        # Closing tag: </Tag>
        self.expect(TokenKind.JSX_CLOSE_START);
        close_tag = self.expect(TokenKind.NAME);
        if close_tag.value != tag.value {
            self.error(
                f"JSX tag mismatch: opening <{tag.value}> closed with </{close_tag.value}>"
            );
        }
        self.expect(TokenKind.GT);

        return JsxElement(tag=tag, attrs=attrs, children=children);
    }

    def parse_jsx_fragment -> JsxFragment {
        self.expect(TokenKind.JSX_FRAG_OPEN);
        children = self.parse_jsx_children_until_frag_close();
        self.expect(TokenKind.JSX_FRAG_CLOSE);
        return JsxFragment(children=children);
    }

    def parse_jsx_attributes -> list[JsxAttr] {
        attrs: list[JsxAttr] = [];

        while not self.check_any(TokenKind.GT, TokenKind.JSX_SELF_CLOSE)
        and not self.at_end() {
            # Spread attribute: {...expr}
            if self.match_tok(TokenKind.LBRACE) {
                self.expect(TokenKind.ELLIPSIS);
                expr = self.parse_expression();
                self.expect(TokenKind.RBRACE);
                # Create a spread attribute with special marker
                attrs.append(
                    JsxAttr(
                        name=Token(
                            kind=TokenKind.ELLIPSIS, value="...", loc=SourceLoc()
                        ),
                        value=expr
                    )
                );
            }
            # Normal attribute: name or name=value
            elif self.check_any(TokenKind.NAME, TokenKind.JSX_NAME) {
                name = self.advance();
                value: Expr | None = None;
                if self.match_tok(TokenKind.EQ) {
                    # Value can be string literal or {expression}
                    if self.check(TokenKind.STRING) {
                        tok = self.advance();
                        value = StringLiteral(token=tok, value=tok.value);
                    } elif self.match_tok(TokenKind.LBRACE) {
                        value = self.parse_expression();
                        self.expect(TokenKind.RBRACE);
                    }
                }
                attrs.append(JsxAttr(name=name, value=value));
            } else {
                break;
            }
        }

        return attrs;
    }

    def parse_jsx_children(parent_tag: str) -> list[JsxChild] {
        children: list[JsxChild] = [];

        while not self.at_end() {
            # Check for closing tag
            if self.check(TokenKind.JSX_CLOSE_START) {
                break;
            }

            # Nested element
            if self.check(TokenKind.JSX_FRAG_OPEN) {
                frag = self.parse_jsx_fragment();
                children.append(JsxChildExpr(expr=frag));
            } elif self.check(TokenKind.LT) and self.is_jsx_start() {
                elem = self.parse_jsx_element();
                children.append(JsxChildExpr(expr=elem));
            }
            # Expression: {expr}
            elif self.match_tok(TokenKind.LBRACE) {
                expr = self.parse_expression();
                self.expect(TokenKind.RBRACE);
                children.append(JsxChildExpr(expr=expr));
            }
            # Text content
            elif self.check(TokenKind.JSX_TEXT) {
                text = self.advance();
                children.append(JsxChildText(text=text.value));
            }
            # Whitespace or regular text - accumulate as text
            elif self.check(TokenKind.NAME) {
                # This can happen if text content starts with something that looks like a name
                text = self.advance();
                children.append(JsxChildText(text=text.value));
            } else {
                # Unknown content - might be more text or an error
                break;
            }
        }

        return children;
    }

    def parse_jsx_children_until_frag_close -> list[JsxChild] {
        children: list[JsxChild] = [];

        while not self.at_end() {
            if self.check(TokenKind.JSX_FRAG_CLOSE) {
                break;
            }

            # Same logic as parse_jsx_children
            if self.check(TokenKind.JSX_FRAG_OPEN) {
                frag = self.parse_jsx_fragment();
                children.append(JsxChildExpr(expr=frag));
            } elif self.check(TokenKind.LT) and self.is_jsx_start() {
                elem = self.parse_jsx_element();
                children.append(JsxChildExpr(expr=elem));
            } elif self.match_tok(TokenKind.LBRACE) {
                expr = self.parse_expression();
                self.expect(TokenKind.RBRACE);
                children.append(JsxChildExpr(expr=expr));
            } elif self.check(TokenKind.JSX_TEXT) {
                text = self.advance();
                children.append(JsxChildText(text=text.value));
            } else {
                break;
            }
        }

        return children;
    }

    def parse_fstring -> FString {
        start_tok = self.advance();  # Consume f-string start token
        parts: list[FStringPart] = [];

        # Determine the end token kind based on start
        end_kind: TokenKind;
        match start_tok.kind {
            case TokenKind.F_DQ_START | TokenKind.RF_DQ_START:
                end_kind = TokenKind.F_DQ_END;

            case TokenKind.F_SQ_START | TokenKind.RF_SQ_START:
                end_kind = TokenKind.F_SQ_END;

            case TokenKind.F_TDQ_START | TokenKind.RF_TDQ_START:
                end_kind = TokenKind.F_TDQ_END;

            case TokenKind.F_TSQ_START | TokenKind.RF_TSQ_START:
                end_kind = TokenKind.F_TSQ_END;

            case _:
                end_kind = TokenKind.F_DQ_END;

        }

        while not self.at_end() {
            # Check for end of f-string
            if self.check(end_kind) {
                self.advance();
                break;
            }

            # Text content
            if self.check_any(
                TokenKind.F_TEXT_DQ,
                TokenKind.F_TEXT_SQ,
                TokenKind.F_TEXT_TDQ,
                TokenKind.F_TEXT_TSQ,
                TokenKind.RF_TEXT_DQ,
                TokenKind.RF_TEXT_SQ,
                TokenKind.RF_TEXT_TDQ,
                TokenKind.RF_TEXT_TSQ
            ) {
                text_tok = self.advance();
                parts.append(FStringText(text=text_tok.value));
            }
            # Escaped braces {{ or }}
            elif self.check(TokenKind.D_LBRACE) {
                self.advance();
                parts.append(FStringText(text="{"));
            } elif self.check(TokenKind.D_RBRACE) {
                self.advance();
                parts.append(FStringText(text="}"));
            }
            # Expression start
            elif self.match_tok(TokenKind.LBRACE) {
                expr = self.parse_expression();
                # Optional conversion specifier
                conversion: str | None = None;
                if self.check(TokenKind.CONV) {
                    conv_tok = self.advance();
                    conversion = conv_tok.value;
                }
                # Optional format spec
                format_spec: str | None = None;
                if self.match_tok(TokenKind.COLON) {
                    format_spec = self.parse_fstring_format_spec();
                }
                self.expect(TokenKind.RBRACE);
                parts.append(
                    FStringExpr(
                        expr=expr, conversion=conversion, format_spec=format_spec
                    )
                );
            } else {
                # Unexpected token - error recovery
                self.error(f"Unexpected token in f-string: {self.current().kind}");
                self.advance();
                break;
            }
        }

        return FString(parts=parts);
    }

    def parse_fstring_format_spec -> str {
        spec = "";

        # Format spec can contain text, nested f-string expressions, etc.
        # For simplicity, we just collect text until we hit }
        while not self.check(TokenKind.RBRACE) and not self.at_end() {
            if self.check(TokenKind.F_FORMAT_TEXT) {
                spec += self.advance().value;
            } elif self.check(TokenKind.LBRACE) {
                # Nested expression in format spec - recursively parse
                self.advance();
                nested_expr = self.parse_expression();
                self.expect(TokenKind.RBRACE);
                spec += "{...}";  # Placeholder for now
            } else {
                # Consume any other token as part of format spec
                spec += self.advance().value;
            }
        }

        return spec;
    }

    def parse_type_expr -> Expr {
        # For now, use regular expression parsing
        # A more complete implementation would handle:
        # - Generic types: list[int]
        # - Union types: int | str
        # - Optional: int?
        return self.parse_expression();
    }

    # =========================================================================
    # STATEMENT PARSING
    # =========================================================================
    def parse_statement -> CodeBlockStmt {
        match self.current().kind {
            # Control flow
            case TokenKind.KW_IF:
                return self.parse_if_stmt();

            case TokenKind.KW_WHILE:
                return self.parse_while_stmt();

            case TokenKind.KW_FOR:
                return self.parse_for_stmt();

            case TokenKind.KW_TRY:
                return self.parse_try_stmt();

            case TokenKind.KW_WITH:
                return self.parse_with_stmt();

            case TokenKind.KW_MATCH:
                return self.parse_match_stmt();

            case TokenKind.KW_SWITCH:
                return self.parse_switch_stmt();

            # Typed context block: -> Type { }
            case TokenKind.RETURN_HINT:
                return self.parse_typed_ctx_block();

            # Jump statements
            case TokenKind.KW_RETURN:
                return self.parse_return_stmt();

            case TokenKind.KW_YIELD:
                return self.parse_yield_stmt();

            case TokenKind.KW_BREAK:
                self.advance();
                self.match_tok(TokenKind.SEMI);
                return BreakStmt();

            case TokenKind.KW_CONTINUE:
                self.advance();
                self.match_tok(TokenKind.SEMI);
                return ContinueStmt();

            case TokenKind.KW_RAISE:
                return self.parse_raise_stmt();

            case TokenKind.KW_ASSERT:
                return self.parse_assert_stmt();

            case TokenKind.KW_DELETE:
                return self.parse_delete_stmt();

            case TokenKind.KW_SKIP:
                self.advance();
                self.match_tok(TokenKind.SEMI);
                return PassStmt();

            # Walker statements
            case TokenKind.KW_VISIT:
                return self.parse_visit_stmt();

            case TokenKind.KW_DISENGAGE:
                self.advance();
                self.match_tok(TokenKind.SEMI);
                return DisengageStmt();

            case TokenKind.KW_REPORT:
                return self.parse_report_stmt();

            # Scope
            case TokenKind.KW_GLOBAL:
                return self.parse_global_stmt();

            case TokenKind.NONLOCAL_OP:
                return self.parse_nonlocal_stmt();

            # Inline Python
            case TokenKind.PYNLINE:
                return self.parse_py_code_block();

            # Default: expression or assignment
            case _:
                return self.parse_expr_or_assignment();

        }
    }

    def parse_if_stmt -> IfStmt {
        self.expect(TokenKind.KW_IF);
        condition = self.parse_expression();
        body = self.parse_code_block();

        else_body: ElseClause | None = None;
        if self.match_tok(TokenKind.KW_ELIF) {
            # Put back the elif token and parse as else_if
            self.pos -= 1;
            else_body = self.parse_elif_stmt();
        } elif self.match_tok(TokenKind.KW_ELSE) {
            else_stmts = self.parse_code_block();
            else_body = ElseStmt(body=else_stmts);
        }

        return IfStmt(condition=condition, body=body, else_body=else_body);
    }

    def parse_elif_stmt -> ElseIf {
        self.expect(TokenKind.KW_ELIF);
        condition = self.parse_expression();
        body = self.parse_code_block();

        else_body: ElseClause | None = None;
        if self.match_tok(TokenKind.KW_ELIF) {
            self.pos -= 1;
            else_body = self.parse_elif_stmt();
        } elif self.match_tok(TokenKind.KW_ELSE) {
            else_stmts = self.parse_code_block();
            else_body = ElseStmt(body=else_stmts);
        }

        return ElseIf(condition=condition, body=body, else_body=else_body);
    }

    def parse_while_stmt -> WhileStmt {
        self.expect(TokenKind.KW_WHILE);
        condition = self.parse_expression();
        body = self.parse_code_block();

        # Optional else clause (executed if loop completes without break)
        else_body: list[CodeBlockStmt] = [];
        if self.match_tok(TokenKind.KW_ELSE) {
            else_body = self.parse_code_block();
        }

        return WhileStmt(condition=condition, body=body, else_body=else_body);
    }

    def parse_for_stmt -> CodeBlockStmt {
        self.expect(TokenKind.KW_FOR);

        is_async = self.match_tok(TokenKind.KW_ASYNC) is not None;
        target = self.parse_expression();

        # Range for: for i to n by step { } else { }
        if self.match_tok(TokenKind.KW_TO) {
            end = self.parse_expression();
            step: Expr | None = None;
            if self.match_tok(TokenKind.KW_BY) {
                step = self.parse_expression();
            }
            body = self.parse_code_block();
            # Optional else clause
            else_body: list[CodeBlockStmt] = [];
            if self.match_tok(TokenKind.KW_ELSE) {
                else_body = self.parse_code_block();
            }
            if isinstance(target, NameExpr) {
                return RangeForStmt(
                    target=target,
                    start=IntLiteral(token=target.name, value=0),
                    end=end,
                    step=step,
                    body=body,
                    else_body=else_body
                );
            }
        }

        # Iterator for: for x in iter { } else { }
        self.expect(TokenKind.KW_IN);
        iter = self.parse_expression();
        body = self.parse_code_block();

        # Optional else clause
        else_body: list[CodeBlockStmt] = [];
        if self.match_tok(TokenKind.KW_ELSE) {
            else_body = self.parse_code_block();
        }

        return ForStmt(
            target=target, iter=iter, body=body, else_body=else_body, is_async=is_async
        );
    }

    def parse_try_stmt -> TryStmt {
        self.expect(TokenKind.KW_TRY);
        body = self.parse_code_block();

        handlers: list[ExceptHandler] = [];
        else_body: list[CodeBlockStmt] = [];
        finally_body: list[CodeBlockStmt] = [];

        while self.match_tok(TokenKind.KW_EXCEPT) {
            exc_type: Expr | None = None;
            name: Token | None = None;

            if not self.check(TokenKind.LBRACE) {
                exc_type = self.parse_expression();
                if self.match_tok(TokenKind.KW_AS) {
                    name = self.expect(TokenKind.NAME);
                }
            }

            handler_body = self.parse_code_block();
            handlers.append(
                ExceptHandler(exc_type=exc_type, name=name, body=handler_body)
            );
        }

        if self.match_tok(TokenKind.KW_ELSE) {
            else_body = self.parse_code_block();
        }

        if self.match_tok(TokenKind.KW_FINALLY) {
            finally_body = self.parse_code_block();
        }

        return TryStmt(
            body=body,
            handlers=handlers,
            else_body=else_body,
            finally_body=finally_body
        );
    }

    def parse_with_stmt -> WithStmt {
        self.expect(TokenKind.KW_WITH);

        items: list[WithItem] = [];

        # First item
        context = self.parse_expression();
        name: Token | None = None;
        if self.match_tok(TokenKind.KW_AS) {
            name = self.expect(TokenKind.NAME);
        }
        items.append(WithItem(context=context, name=name));

        # Additional items
        while self.match_tok(TokenKind.COMMA) {
            ctx = self.parse_expression();
            n: Token | None = None;
            if self.match_tok(TokenKind.KW_AS) {
                n = self.expect(TokenKind.NAME);
            }
            items.append(WithItem(context=ctx, name=n));
        }

        body = self.parse_code_block();
        return WithStmt(items=items, body=body);
    }

    def parse_match_stmt -> MatchStmt {
        self.expect(TokenKind.KW_MATCH);
        target = self.parse_expression();
        self.expect(TokenKind.LBRACE);

        cases: list[MatchCase] = [];
        while self.match_tok(TokenKind.KW_CASE) {
            pattern = self.parse_match_pattern();
            guard: Expr | None = None;
            if self.match_tok(TokenKind.KW_IF) {
                guard = self.parse_expression();
            }
            self.expect(TokenKind.COLON);
            body = self.parse_case_body();
            cases.append(MatchCase(pattern=pattern, guard=guard, body=body));
        }

        self.expect(TokenKind.RBRACE);
        return MatchStmt(target=target, cases=cases);
    }

    def parse_match_pattern -> MatchPattern {
        return self.parse_or_pattern();
    }

    def parse_or_pattern -> MatchPattern {
        left = self.parse_base_pattern();

        patterns = [left];
        while self.match_tok(TokenKind.BW_OR) {
            patterns.append(self.parse_base_pattern());
        }

        # Check for 'as' pattern
        if self.match_tok(TokenKind.KW_AS) {
            name = self.expect(TokenKind.NAME);
            if len(patterns) == 1 {
                return AsPattern(pattern=patterns[0], name=name);
            } else {
                return AsPattern(pattern=OrPattern(patterns=patterns), name=name);
            }
        }

        if len(patterns) == 1 {
            return patterns[0];
        }
        return OrPattern(patterns=patterns);
    }

    def parse_base_pattern -> MatchPattern {
        # Wildcard: _
        if self.check(TokenKind.NAME) and self.current().value == "_" {
            self.advance();
            return WildcardPattern();
        }

        # Star pattern: *name (for sequence unpacking)
        if self.match_tok(TokenKind.STAR_MUL) {
            name = self.expect(TokenKind.NAME);
            return StarPattern(name=name);
        }

        # Singleton patterns: None, True, False
        if self.check(TokenKind.NULL) {
            tok = self.advance();
            return SingletonPattern(value=NullLiteral(token=tok));
        }
        if self.check(TokenKind.BOOL) {
            tok = self.advance();
            return SingletonPattern(
                value=BoolLiteral(token=tok, value=tok.value == "True")
            );
        }

        # Literal patterns: numbers, strings
        if self.check_any(TokenKind.INT, TokenKind.HEX, TokenKind.BIN, TokenKind.OCT) {
            tok = self.advance();
            return LiteralPattern(value=IntLiteral(token=tok));
        }
        if self.check(TokenKind.FLOAT) {
            tok = self.advance();
            return LiteralPattern(value=FloatLiteral(token=tok));
        }
        if self.check(TokenKind.STRING) {
            tok = self.advance();
            return LiteralPattern(value=StringLiteral(token=tok, value=tok.value));
        }
        # Also handle negative numbers
        if self.check(TokenKind.MINUS) {
            op = self.advance();
            if self.check_any(TokenKind.INT, TokenKind.FLOAT) {
                tok = self.advance();
                expr = IntLiteral(token=tok)
                if tok.kind == TokenKind.INT
                else FloatLiteral(token=tok);
                return LiteralPattern(value=UnaryExpr(op=op, operand=expr));
            }
            self.error("Expected number after minus in pattern");
        }

        # Sequence pattern: [pattern, pattern, ...]
        if self.match_tok(TokenKind.LSQUARE) {
            return self.parse_sequence_pattern(TokenKind.RSQUARE);
        }

        # Tuple pattern: (pattern, pattern, ...)
        if self.match_tok(TokenKind.LPAREN) {
            return self.parse_sequence_pattern(TokenKind.RPAREN);
        }

        # Mapping pattern: {key: pattern, **rest}
        if self.match_tok(TokenKind.LBRACE) {
            return self.parse_mapping_pattern();
        }

        # Name-based patterns: capture, attr, or class pattern
        if self.check(TokenKind.NAME) {
            return self.parse_name_pattern();
        }

        self.error(f"Unexpected token in pattern: {self.current().kind}");
        return WildcardPattern();  # Error recovery

    }

    def parse_sequence_pattern(end_token: TokenKind) -> SequencePattern {
        elements: list[MatchPattern] = [];

        while not self.check(end_token) and not self.at_end() {
            if self.match_tok(TokenKind.STAR_MUL) {
                name = self.expect(TokenKind.NAME);
                elements.append(StarPattern(name=name));
            } else {
                elements.append(self.parse_match_pattern());
            }

            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
        }

        self.expect(end_token);
        return SequencePattern(elements=elements);
    }

    def parse_mapping_pattern -> MappingPattern {
        entries: list[MappingPatternEntry] = [];
        rest_name: Token | None = None;

        while not self.check(TokenKind.RBRACE) and not self.at_end() {
            # Check for **rest
            if self.match_tok(TokenKind.STAR_POW) {
                rest_name = self.expect(TokenKind.NAME);
                # **rest must be last
                if self.check(TokenKind.COMMA) {
                    self.advance();
                }
                break;
            }

            # Parse key: pattern
            key: Expr;
            if self.check(TokenKind.STRING) {
                tok = self.advance();
                key = StringLiteral(token=tok, value=tok.value);
            } elif self.check_any(TokenKind.INT, TokenKind.FLOAT) {
                tok = self.advance();
                key = IntLiteral(token=tok)
                if tok.kind == TokenKind.INT
                else FloatLiteral(token=tok);
            } else {
                self.error("Expected literal key in mapping pattern");
                key = StringLiteral(token=self.current(), value="");
            }

            self.expect(TokenKind.COLON);
            pattern = self.parse_match_pattern();
            entries.append(MappingPatternEntry(key=key, pattern=pattern));

            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
        }

        self.expect(TokenKind.RBRACE);
        return MappingPattern(entries=entries, rest_name=rest_name);
    }

    def parse_name_pattern -> MatchPattern {
        first_name = self.advance();
        names = [first_name];

        # Check for attribute pattern or class pattern: Name.attr.attr...
        while self.match_tok(TokenKind.DOT) {
            names.append(self.expect(TokenKind.NAME));
        }

        # Check for class pattern: Name(...) or Name.Nested(...)
        if self.match_tok(TokenKind.LPAREN) {
            return self.parse_class_pattern_args(names);
        }

        # Attribute pattern: Name.attr.attr (must have at least 2 parts)
        if len(names) > 1 {
            return AttrPattern(names=names);
        }

        # Simple capture pattern
        return CapturePattern(name=first_name);
    }

    def parse_class_pattern_args(names: list[Token]) -> ClassPattern {
        args: list[MatchPattern] = [];
        kwargs: list[KeywordPattern] = [];

        while not self.check(TokenKind.RPAREN) and not self.at_end() {
            # Check for keyword pattern: name=pattern
            if self.check(TokenKind.NAME) and self.peek().kind == TokenKind.EQ {
                name = self.advance();
                self.advance();  # Skip =
                pattern = self.parse_match_pattern();
                kwargs.append(KeywordPattern(name=name, pattern=pattern));
            } else {
                # Positional pattern
                args.append(self.parse_match_pattern());
            }

            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
        }

        self.expect(TokenKind.RPAREN);

        # Build the class expression from names
        cls: Expr = NameExpr(name=names[0]);
        for i in range(1, len(names)) {
            cls = AttrAccess(target=cls, attr=names[i]);
        }

        return ClassPattern(cls=cls, args=args, kwargs=kwargs);
    }

    def parse_case_body -> list[CodeBlockStmt] {
        if self.check(TokenKind.LBRACE) {
            return self.parse_code_block();
        }

        # Single statement
        stmt = self.parse_statement();
        return [stmt];
    }

    def parse_switch_stmt -> SwitchStmt {
        self.expect(TokenKind.KW_SWITCH);
        target = self.parse_expression();
        self.expect(TokenKind.LBRACE);

        cases: list[SwitchCase] = [];

        while self.check_any(TokenKind.KW_CASE, TokenKind.KW_DEFAULT) {
            is_default = self.match_tok(TokenKind.KW_DEFAULT) is not None;
            patterns: list[MatchPattern] = [];

            if not is_default {
                self.expect(TokenKind.KW_CASE);
                # Parse pattern(s) - can have multiple with |
                patterns.append(self.parse_match_pattern());
                while self.match_tok(TokenKind.BW_OR) {
                    patterns.append(self.parse_match_pattern());
                }
            }

            self.expect(TokenKind.COLON);
            body = self.parse_switch_case_body();

            cases.append(
                SwitchCase(patterns=patterns, is_default=is_default, body=body)
            );
        }

        self.expect(TokenKind.RBRACE);
        return SwitchStmt(target=target, cases=cases);
    }

    def parse_switch_case_body -> list[CodeBlockStmt] {
        stmts: list[CodeBlockStmt] = [];

        while not self.check_any(
            TokenKind.KW_CASE, TokenKind.KW_DEFAULT, TokenKind.RBRACE
        )
        and not self.at_end() {
            stmts.append(self.parse_statement());
        }

        return stmts;
    }

    def parse_typed_ctx_block -> TypedContextBlock {
        self.expect(TokenKind.RETURN_HINT);
        type_expr = self.parse_expression();
        body = self.parse_code_block();
        return TypedContextBlock(type_expr=type_expr, body=body);
    }

    def parse_nonlocal_stmt -> NonLocalStmt {
        self.expect(TokenKind.NONLOCAL_OP);
        names: list[Token] = [self.expect(TokenKind.NAME)];

        while self.match_tok(TokenKind.COMMA) {
            names.append(self.expect(TokenKind.NAME));
        }

        self.match_tok(TokenKind.SEMI);
        return NonLocalStmt(names=names);
    }

    def parse_return_stmt -> ReturnStmt {
        self.expect(TokenKind.KW_RETURN);
        value: Expr | None = None;

        if not self.check_any(TokenKind.SEMI, TokenKind.RBRACE, TokenKind.EOF) {
            value = self.parse_expression();
        }

        self.match_tok(TokenKind.SEMI);
        return ReturnStmt(value=value);
    }

    def parse_yield_stmt -> YieldStmt {
        self.expect(TokenKind.KW_YIELD);
        is_from = self.match_tok(TokenKind.KW_FROM) is not None;
        value: Expr | None = None;

        if not self.check_any(TokenKind.SEMI, TokenKind.RBRACE) {
            value = self.parse_expression();
        }

        self.match_tok(TokenKind.SEMI);
        return YieldStmt(value=value, is_from=is_from);
    }

    def parse_raise_stmt -> RaiseStmt {
        self.expect(TokenKind.KW_RAISE);
        exc: Expr | None = None;
        cause: Expr | None = None;

        if not self.check_any(TokenKind.SEMI, TokenKind.RBRACE) {
            exc = self.parse_expression();
            if self.match_tok(TokenKind.KW_FROM) {
                cause = self.parse_expression();
            }
        }

        self.match_tok(TokenKind.SEMI);
        return RaiseStmt(exc=exc, cause=cause);
    }

    def parse_assert_stmt -> AssertStmt {
        self.expect(TokenKind.KW_ASSERT);
        condition = self.parse_expression();
        message: Expr | None = None;

        if self.match_tok(TokenKind.COMMA) {
            message = self.parse_expression();
        }

        self.match_tok(TokenKind.SEMI);
        return AssertStmt(condition=condition, message=message);
    }

    def parse_delete_stmt -> DeleteStmt {
        self.expect(TokenKind.KW_DELETE);
        target = self.parse_expression();
        self.match_tok(TokenKind.SEMI);
        return DeleteStmt(target=target);
    }

    def parse_visit_stmt -> VisitStmt {
        self.expect(TokenKind.KW_VISIT);

        # Check for optional filter: :filter:
        filter: Expr | None = None;
        if self.match_tok(TokenKind.COLON) {
            filter = self.parse_expression();
            self.expect(TokenKind.COLON);
        }

        target = self.parse_expression();

        # Check for else clause
        else_body: list[CodeBlockStmt] = [];
        if self.match_tok(TokenKind.KW_ELSE) {
            else_body = self.parse_code_block();
        } else {
            self.match_tok(TokenKind.SEMI);
        }

        return VisitStmt(filter=filter, target=target, else_body=else_body);
    }

    def parse_report_stmt -> ReportStmt {
        self.expect(TokenKind.KW_REPORT);
        value = self.parse_expression();
        self.match_tok(TokenKind.SEMI);
        return ReportStmt(value=value);
    }

    def parse_global_stmt -> GlobalStmt {
        self.expect(TokenKind.KW_GLOBAL);
        names: list[Token] = [self.expect(TokenKind.NAME)];

        while self.match_tok(TokenKind.COMMA) {
            names.append(self.expect(TokenKind.NAME));
        }

        self.match_tok(TokenKind.SEMI);
        return GlobalStmt(names=names);
    }

    def parse_expr_or_assignment -> CodeBlockStmt {
        expr = self.parse_expression();

        # Check for assignment
        if self.check(TokenKind.EQ) {
            targets = [expr];
            while self.match_tok(TokenKind.EQ) {
                targets.append(self.parse_expression());
            }
            value = targets.pop();
            self.match_tok(TokenKind.SEMI);
            return Assignment(targets=targets, value=value);
        }

        # Augmented assignment
        if self.current().is_assignment() and self.current().kind != TokenKind.EQ {
            aug_op = self.advance();
            value = self.parse_expression();
            self.match_tok(TokenKind.SEMI);
            return Assignment(targets=[expr], value=value, aug_op=aug_op);
        }

        # Type annotation
        if self.match_tok(TokenKind.COLON) {
            type_tag = self.parse_type_expr();
            value: Expr | None = None;
            if self.match_tok(TokenKind.EQ) {
                value = self.parse_expression();
            }
            self.match_tok(TokenKind.SEMI);
            return Assignment(targets=[expr], type_tag=type_tag, value=value);
        }

        self.match_tok(TokenKind.SEMI);
        return ExprStmt(expr=expr);
    }

    def parse_code_block -> list[CodeBlockStmt] {
        self.expect(TokenKind.LBRACE);
        stmts: list[CodeBlockStmt] = [];

        while not self.check(TokenKind.RBRACE) and not self.at_end() {
            stmt = self.parse_statement();
            stmts.append(stmt);
        }

        self.expect(TokenKind.RBRACE);
        return stmts;
    }

    # =========================================================================
    # TOP-LEVEL DECLARATIONS
    # =========================================================================
    def parse_element_stmt -> ElementStmt | None {
        # Handle decorators
        decorators: list[Expr] = [];
        while self.match_tok(TokenKind.DECOR_OP) {
            decorators.append(self.parse_expression());
        }

        match self.current().kind {
            case TokenKind.KW_IMPORT | TokenKind.KW_INCLUDE:
                return self.parse_import_stmt();

            case TokenKind.KW_OBJECT | TokenKind.KW_NODE | TokenKind.KW_EDGE | TokenKind.KW_WALKER | TokenKind.KW_CLASS:
                return self.parse_archetype(decorators);

            case TokenKind.KW_ENUM:
                return self.parse_enum(decorators);

            case TokenKind.KW_CAN | TokenKind.KW_DEF:
                return self.parse_ability(decorators);

            case TokenKind.KW_IMPL:
                return self.parse_impl(decorators);

            case TokenKind.KW_TEST:
                return self.parse_test();

            case TokenKind.KW_GLOBAL:
                return self.parse_global_var();

            case TokenKind.KW_SEM:
                return self.parse_sem_def();

            case TokenKind.KW_WITH:
                return self.parse_entry_block();

            case TokenKind.KW_CLIENT | TokenKind.KW_SERVER | TokenKind.KW_NATIVE:
                return self.parse_context_block();

            case TokenKind.PYNLINE:
                return self.parse_py_code_block();

            case TokenKind.TYPE_OP_ALIAS:
                return self.parse_type_alias();

            case _:
                self.error(f"Unexpected token at top level: {self.current().kind}");
                self.synchronize();
                return None;

        }
    }

    def parse_type_alias -> TypeAlias {
        self.expect(TokenKind.TYPE_OP_ALIAS);
        name = self.expect(TokenKind.NAME);
        self.expect(TokenKind.EQ);
        value = self.parse_type_expr();
        self.match_tok(TokenKind.SEMI);
        return TypeAliasStmt(name=name, value=value);
    }

    def parse_py_code_block -> PyCodeBlock {
        tok = self.expect(TokenKind.PYNLINE);
        return PyCodeBlock(code=tok.value, token=tok);
    }

    def parse_import_stmt -> ImportStmt {
        is_include = self.current().kind == TokenKind.KW_INCLUDE;
        self.advance();

        # Jac-style: import from path { items }
        if self.match_tok(TokenKind.KW_FROM) {
            # Handle relative imports with leading dots
            leading_dots: list[Token] = [];
            while self.check_any(TokenKind.DOT, TokenKind.ELLIPSIS) {
                leading_dots.append(self.advance());
            }
            path = self.parse_dotted_path();
            # Check for Jac-style braces or Python-style import keyword
            if self.match_tok(TokenKind.LBRACE) {
                # Jac-style: import from path { items }
                items: list[ImportItem] = [];
                if self.match_tok(TokenKind.STAR_MUL) {
                    items.append(ImportItem(name=self.tokens[self.pos - 1]));
                } else {
                    items = self.parse_import_items();
                }
                self.expect(TokenKind.RBRACE);
                return ImportStmt(
                    path=path,
                    items=items,
                    is_include=is_include,
                    leading_dots=len(leading_dots)
                );
            } elif self.match_tok(TokenKind.KW_IMPORT) {
                # Python-style: from path import items
                items: list[ImportItem] = [];
                if self.match_tok(TokenKind.STAR_MUL) {
                    items.append(ImportItem(name=self.tokens[self.pos - 1]));
                } else {
                    items = self.parse_import_items();
                }
                self.match_tok(TokenKind.SEMI);
                return ImportStmt(
                    path=path,
                    items=items,
                    is_include=is_include,
                    leading_dots=len(leading_dots)
                );
            } else {
                self.error("Expected '{' or 'import' after import path");
            }
        }

        # Simple import: import path (as alias)?
        path = self.parse_dotted_path();
        alias: Token | None = None;
        if self.match_tok(TokenKind.KW_AS) {
            alias = self.expect(TokenKind.NAME);
        }

        self.match_tok(TokenKind.SEMI);
        return ImportStmt(path=path, alias=alias, is_include=is_include);
    }

    def parse_dotted_path -> list[Token] {
        path: list[Token] = [self.expect(TokenKind.NAME)];

        while self.match_tok(TokenKind.DOT) {
            path.append(self.expect(TokenKind.NAME));
        }

        return path;
    }

    def parse_import_items -> list[ImportItem] {
        items: list[ImportItem] = [];

        items.append(self.parse_import_item());
        while self.match_tok(TokenKind.COMMA) {
            items.append(self.parse_import_item());
        }

        return items;
    }

    def parse_import_item -> ImportItem {
        name = self.expect(TokenKind.NAME);
        alias: Token | None = None;
        if self.match_tok(TokenKind.KW_AS) {
            alias = self.expect(TokenKind.NAME);
        }
        return ImportItem(name=name, alias=alias);
    }

    def parse_archetype(decorators: list[Expr]) -> Archetype {
        is_async = self.match_tok(TokenKind.KW_ASYNC) is not None;
        is_abstract = self.match_tok(TokenKind.KW_ABSTRACT) is not None;

        arch_type = self.advance();  # obj, node, edge, walker, class
        access = self.parse_access_tag();
        name = self.expect(TokenKind.NAME);

        # Base classes
        base_classes: list[Expr] = [];
        if self.match_tok(TokenKind.LPAREN) {
            while not self.check(TokenKind.RPAREN) {
                base_classes.append(self.parse_expression());
                if not self.match_tok(TokenKind.COMMA) {
                    break;
                }
            }
            self.expect(TokenKind.RPAREN);
        }

        # Doc string and body
        doc: StringLiteral | None = None;
        body: list[ArchBlockStmt] = [];

        if self.match_tok(TokenKind.LBRACE) {
            # Optional docstring
            if self.check(TokenKind.STRING) {
                tok = self.advance();
                doc = StringLiteral(token=tok, value=tok.value);
            }
            while not self.check(TokenKind.RBRACE) and not self.at_end() {
                stmt = self.parse_arch_member();
                if stmt is not None {
                    body.append(stmt);
                }
            }
            self.expect(TokenKind.RBRACE);
        } else {
            self.expect(TokenKind.SEMI);
        }

        return Archetype(
            arch_type=arch_type,
            name=name,
            access=access,
            base_classes=base_classes,
            body=body,
            decorators=decorators,
            is_async=is_async,
            is_abstract=is_abstract,
            doc=doc
        );
    }

    def parse_access_tag -> Token | None {
        if self.match_tok(TokenKind.COLON) {
            if self.check_any(TokenKind.KW_PUB, TokenKind.KW_PRIV, TokenKind.KW_PROT) {
                return self.advance();
            }
            self.error("Expected access modifier after ':'");
        }
        return None;
    }

    def parse_arch_member -> ArchBlockStmt | None {
        decorators: list[Expr] = [];
        while self.match_tok(TokenKind.DECOR_OP) {
            decorators.append(self.parse_expression());
        }

        match self.current().kind {
            case TokenKind.KW_HAS:
                return self.parse_has_var();

            case TokenKind.KW_CAN | TokenKind.KW_DEF:
                return self.parse_ability(decorators);

            case TokenKind.KW_OBJECT | TokenKind.KW_NODE | TokenKind.KW_EDGE | TokenKind.KW_WALKER | TokenKind.KW_CLASS:
                return self.parse_archetype(decorators);

            case TokenKind.KW_ENUM:
                return self.parse_enum(decorators);

            case TokenKind.PYNLINE:
                return self.parse_py_code_block();

            case _:
                self.error(
                    f"Unexpected token in archetype body: {self.current().kind}"
                );
                self.synchronize();
                return None;

        }
    }

    def parse_has_var -> ArchBlockStmt {
        self.expect(TokenKind.KW_HAS);

        is_static = self.match_tok(TokenKind.KW_STATIC) is not None;
        access = self.parse_access_tag();

        # Parse first variable
        vars: list[HasVarDecl] = [];
        vars.append(self.parse_has_var_decl());

        # Parse additional comma-separated variables
        while self.match_tok(TokenKind.COMMA) {
            vars.append(self.parse_has_var_decl());
        }

        self.match_tok(TokenKind.SEMI);

        # If single variable, return simple HasVar for backward compatibility
        if len(vars) == 1 {
            v = vars[0];
            return HasVar(
                name=v.name,
                access=access,
                type_tag=v.type_tag,
                value=v.value,
                is_static=is_static,
                is_frozen=v.is_frozen
            );
        }

        return HasStmt(is_static=is_static, access=access, vars=vars);
    }

    def parse_has_var_decl -> HasVarDecl {
        name = self.expect(TokenKind.NAME);

        type_tag: Expr | None = None;
        if self.match_tok(TokenKind.COLON) {
            type_tag = self.parse_type_expr();
        }

        value: Expr | None = None;
        is_post_init = False;

        if self.match_tok(TokenKind.EQ) {
            value = self.parse_expression();
        } elif self.match_tok(TokenKind.KW_BY) {
            # by post_init
            if self.match_tok(TokenKind.KW_POST_INIT) {
                is_post_init = True;
            } else {
                self.error("Expected 'post_init' after 'by' in has declaration");
            }
        }

        return HasVarDecl(
            name=name, type_tag=type_tag, value=value, is_post_init=is_post_init
        );
    }

    def parse_ability(decorators: list[Expr]) -> Ability {
        is_async = self.match_tok(TokenKind.KW_ASYNC) is not None;
        is_override = self.match_tok(TokenKind.KW_OVERRIDE) is not None;
        is_static = self.match_tok(TokenKind.KW_STATIC) is not None;

        ability_type = self.advance();  # can or def
        access = self.parse_access_tag();
        name = self.expect(TokenKind.NAME);

        # Parse signature
        signature: FuncSignature | EventSignature;

        if self.match_tok(TokenKind.KW_WITH) {
            # Event signature: with Type entry/exit
            arch_tag: Expr | None = None;
            if not self.check_any(TokenKind.KW_ENTRY, TokenKind.KW_EXIT) {
                arch_tag = self.parse_expression();
            }
            event_type = self.advance();  # entry or exit
            signature = EventSignature(arch_tag=arch_tag, event_type=event_type);
        } else {
            # Function signature
            signature = self.parse_func_signature();
        }

        # Body
        body: list[CodeBlockStmt] = [];
        is_abstract = False;

        if self.check(TokenKind.LBRACE) {
            body = self.parse_code_block();
        } elif self.match_tok(TokenKind.KW_BY) {
            # Abstract with expression
            expr = self.parse_expression();
            self.expect(TokenKind.SEMI);
            body = [ExprStmt(expr=expr)];
        } else {
            self.expect(TokenKind.SEMI);
            is_abstract = True;
        }

        return Ability(
            ability_type=ability_type,
            name=name,
            access=access,
            signature=signature,
            body=body,
            decorators=decorators,
            is_async=is_async,
            is_static=is_static,
            is_override=is_override,
            is_abstract=is_abstract
        );
    }

    def parse_func_signature -> FuncSignature {
        self.expect(TokenKind.LPAREN);

        params: list[ParamVar] = [];
        while not self.check(TokenKind.RPAREN) {
            params.append(self.parse_param_var());
            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
        }

        self.expect(TokenKind.RPAREN);

        return_type: Expr | None = None;
        if self.match_tok(TokenKind.RETURN_HINT) {
            return_type = self.parse_type_expr();
        }

        return FuncSignature(params=params, return_type=return_type);
    }

    def parse_param_var -> ParamVar {
        is_star = self.match_tok(TokenKind.STAR_MUL) is not None;
        is_kwargs = is_star and self.match_tok(TokenKind.STAR_MUL) is not None;

        name = self.expect(TokenKind.NAME);

        type_tag: Expr | None = None;
        if self.match_tok(TokenKind.COLON) {
            type_tag = self.parse_type_expr();
        }

        default_val: Expr | None = None;
        if self.match_tok(TokenKind.EQ) {
            default_val = self.parse_expression();
        }

        return ParamVar(
            name=name,
            type_tag=type_tag,
            default=default_val,
            is_star=is_star,
            is_kwargs=is_kwargs
        );
    }

    def parse_enum(decorators: list[Expr]) -> Enum {
        self.expect(TokenKind.KW_ENUM);
        access = self.parse_access_tag();
        name = self.expect(TokenKind.NAME);

        members: list[EnumMember] = [];

        if self.match_tok(TokenKind.LBRACE) {
            while not self.check(TokenKind.RBRACE) and not self.at_end() {
                member_name = self.expect(TokenKind.NAME);
                value: Expr | None = None;
                if self.match_tok(TokenKind.EQ) {
                    value = self.parse_expression();
                }
                members.append(EnumMember(name=member_name, value=value));
                self.match_tok(TokenKind.COMMA);
            }
            self.expect(TokenKind.RBRACE);
        } else {
            self.expect(TokenKind.SEMI);
        }

        return Enum(name=name, access=access, members=members, decorators=decorators);
    }

    def parse_impl(decorators: list[Expr]) -> ImplDef {
        self.expect(TokenKind.KW_IMPL);
        target = self.parse_expression();

        for_type: Expr | None = None;
        if self.match_tok(TokenKind.KW_FOR) {
            for_type = self.parse_expression();
        }

        body: list[ArchBlockStmt] = [];
        self.expect(TokenKind.LBRACE);
        while not self.check(TokenKind.RBRACE) and not self.at_end() {
            stmt = self.parse_arch_member();
            if stmt is not None {
                body.append(stmt);
            }
        }
        self.expect(TokenKind.RBRACE);

        return ImplDef(
            target=target, for_type=for_type, body=body, decorators=decorators
        );
    }

    def parse_test -> TestDef {
        self.expect(TokenKind.KW_TEST);

        name_tok = self.expect(TokenKind.STRING);
        name = StringLiteral(token=name_tok, value=name_tok.value);

        body = self.parse_code_block();
        return TestDef(name=name, body=body);
    }

    def parse_global_var -> GlobalVarDef {
        self.expect(TokenKind.KW_GLOBAL);
        name = self.expect(TokenKind.NAME);

        type_tag: Expr | None = None;
        if self.match_tok(TokenKind.COLON) {
            type_tag = self.parse_type_expr();
        }

        value: Expr | None = None;
        if self.match_tok(TokenKind.EQ) {
            value = self.parse_expression();
        }

        self.match_tok(TokenKind.SEMI);
        return GlobalVarDef(name=name, type_tag=type_tag, value=value);
    }

    def parse_sem_def -> SemDef {
        self.expect(TokenKind.KW_SEM);
        target = self.parse_expression();
        self.expect(TokenKind.EQ);
        desc_tok = self.expect(TokenKind.STRING);
        description = StringLiteral(token=desc_tok, value=desc_tok.value);
        self.match_tok(TokenKind.SEMI);
        return SemDef(target=target, description=description);
    }

    def parse_entry_block -> EntryBlock {
        self.expect(TokenKind.KW_WITH);
        is_exit = self.match_tok(TokenKind.KW_EXIT) is not None;
        if not is_exit {
            self.expect(TokenKind.KW_ENTRY);
        }

        # Optional target name: :name
        target_name: Token | None = None;
        if self.match_tok(TokenKind.COLON) {
            target_name = self.expect(TokenKind.NAME);
        }

        body = self.parse_code_block();
        return EntryBlock(is_exit=is_exit, target_name=target_name, body=body);
    }

    def parse_context_block -> ContextBlock {
        context = self.advance();  # cl, sv, na

        body: list[ElementStmt] = [];
        self.expect(TokenKind.LBRACE);
        while not self.check(TokenKind.RBRACE) and not self.at_end() {
            stmt = self.parse_element_stmt();
            if stmt is not None {
                body.append(stmt);
            }
        }
        self.expect(TokenKind.RBRACE);

        return ContextBlock(context=context, body=body);
    }
}

# =============================================================================
# Convenience Function
# =============================================================================
def parse(
    source: str, file_path: str = "<input>"
) -> tuple[Module, list[ParseError]] {
    lexer = Lexer(source=source, file_path=file_path);
    tokens = lexer.tokenize();

    parser = Parser(tokens=tokens, file_path=file_path);
    module = parser.parse();

    errors: list[ParseError] = [];
    for err in lexer.errors {
        errors.append(ParseError(message=err.message, loc=err.loc));
    }
    errors.extend(parser.errors);

    return (module, errors);
}
