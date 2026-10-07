"""
JavaScript / TypeScript Recursive Descent Parser for js_engine.

Consumes the Token stream produced by the  Lexer and builds an AST
using the  ASTNode fat-node design.

Algorithm:
  - Statements  : simple recursive descent, one parse_* function per construct
  - Expressions : Pratt (top-down operator precedence) via parse_expr(min_prec)
  - TypeScript  : type annotations, `as` casts, `interface`/`type`/`enum`
                  declarations, generics are all silently stripped

Bun reference: bun/src/js_parser.zig (~8 000 lines)
ECMAScript spec: §13-16
"""

import from engine.src.parser.lexer { TokenType, Token, Lexer, make_lexer }
import from engine.src.parser.ast {
    ASTNodeType,
    ASTNode,
    SourceRange,
    ZERO_RANGE,
    make_range,
    make_program,
    make_block,
    make_expr_stmt,
    make_empty_stmt,
    make_var_decl,
    make_var_declarator,
    make_function_decl,
    make_function_expr,
    make_arrow,
    make_class_decl,
    make_class_expr,
    make_method_def,
    make_return,
    make_if,
    make_while,
    make_do_while,
    make_with,
    make_for,
    make_for_in,
    make_for_of,
    make_break,
    make_continue,
    make_throw,
    make_try,
    make_catch,
    make_switch,
    make_switch_case,
    make_labeled,
    make_debugger,
    make_import,
    make_export_named,
    make_export_default,
    make_export_all,
    make_import_specifier,
    make_export_specifier,
    make_identifier,
    make_literal,
    make_template_literal,
    make_template_element,
    make_binary,
    make_unary,
    make_logical,
    make_assignment,
    make_update,
    make_conditional,
    make_call,
    make_new,
    make_member,
    make_optional_chain,
    make_spread,
    make_array,
    make_elision,
    make_object,
    make_property,
    make_sequence,
    make_await,
    make_yield,
    make_tagged_template,
    make_meta_property,
    make_assignment_pattern,
    make_object_pattern,
    make_array_pattern,
    make_rest,
    is_null_node
}

# ══════════════════════════════════════════════════════════════════════════════
# Debug tracing
# ══════════════════════════════════════════════════════════════════════════════

"""Set to True to enable parser rule-entry debug output."""
glob PARSER_DEBUG_MODE: bool = False;

"""Set to True by parse() when the source contains syntax errors."""
glob:pub _PARSE_HAD_ERRORS: bool = False;

"""Print msg when PARSER_DEBUG_MODE is True."""
def parser_debug(msg: str) {
    print("[PARSER]", msg);
}

# ══════════════════════════════════════════════════════════════════════════════
# 1.  Precedence constants
# ══════════════════════════════════════════════════════════════════════════════

glob:pub PREC_COMMA: int = 1,
     PREC_YIELD: int = 2,
     PREC_ASSIGN: int = 3,
     PREC_COND: int = 4,
     PREC_NULLISH: int = 5,
     PREC_OR: int = 6,
     PREC_AND: int = 7,
     PREC_BOR: int = 8,
     PREC_BXOR: int = 9,
     PREC_BAND: int = 10,
     PREC_EQUAL: int = 11,
     PREC_RELAT: int = 12,
     PREC_SHIFT: int = 13,
     PREC_ADD: int = 14,
     PREC_MUL: int = 15,
     PREC_EXP: int = 16,
     PREC_UNARY: int = 17,
     PREC_POSTFIX: int = 18,
     PREC_CALL: int = 19;  # Comma / sequence  (lowest).

# Yield / Await.
# Assignment  = += -= etc.
# Conditional  a ? b : c.
# Nullish coalescing  ??.
# Logical OR  ||.
# Logical AND  &&.
# Bitwise OR  |.
# Bitwise XOR  ^.
# Bitwise AND  &.
# Equality  == != === !==.
# Relational  < > <= >= in instanceof.
# Shift  << >> >>>.
# Additive  + -.
# Multiplicative  * / %.
# Exponentiation  **  (right-assoc).
# Unary prefix.
# Postfix update  ++ --.
# Call / member / new-with-args  (highest).
# ══════════════════════════════════════════════════════════════════════════════
# 2.  Utilities
# ══════════════════════════════════════════════════════════════════════════════

"""Make a SourceRange from a token."""
def _range_of(tok: Token) -> SourceRange {
    return make_range(tok.start_offset, tok.end_offset, tok.line, tok.col);
}

"""True if `tok` can be a BindingIdentifier (a plain identifier or a contextual
keyword usable as a name).  Used to disambiguate `using x` (declaration) from a
bare `using` reference."""
def _tok_is_binding_ident(tok: Token) -> bool {
    tt: TokenType = tok.ttype;
    return tt == TokenType.Identifier
        or tt == TokenType.KwGet
        or tt == TokenType.KwSet
        or tt == TokenType.KwOf
        or tt == TokenType.KwFrom
        or tt == TokenType.KwAs
        or tt == TokenType.KwAsync
        or tt == TokenType.KwStatic;
}

"""Combine two ranges into one spanning both."""
def _range_span(start: SourceRange, end: SourceRange) -> SourceRange {
    return make_range(start.start, end.end, start.line, start.col);
}

"""Return the infix precedence for a binary/logical/assignment operator token.
Returns 0 if the token is not an infix operator."""
def _infix_prec(tt: TokenType) -> int {
    # Assignment operators — right-assoc; return PREC_ASSIGN so the caller
    # decides whether to recurse (by passing PREC_ASSIGN-1 when allowed)
    if tt == TokenType.Eq {
        return PREC_ASSIGN;
    }
    if tt == TokenType.PlusEq {
        return PREC_ASSIGN;
    }
    if tt == TokenType.MinusEq {
        return PREC_ASSIGN;
    }
    if tt == TokenType.StarEq {
        return PREC_ASSIGN;
    }
    if tt == TokenType.SlashEq {
        return PREC_ASSIGN;
    }
    if tt == TokenType.PercentEq {
        return PREC_ASSIGN;
    }
    if tt == TokenType.StarStarEq {
        return PREC_ASSIGN;
    }
    if tt == TokenType.AmpEq {
        return PREC_ASSIGN;
    }
    if tt == TokenType.PipeEq {
        return PREC_ASSIGN;
    }
    if tt == TokenType.CaretEq {
        return PREC_ASSIGN;
    }
    if tt == TokenType.LtLtEq {
        return PREC_ASSIGN;
    }
    if tt == TokenType.GtGtEq {
        return PREC_ASSIGN;
    }
    if tt == TokenType.GtGtGtEq {
        return PREC_ASSIGN;
    }
    if tt == TokenType.AmpAmpEq {
        return PREC_ASSIGN;
    }
    if tt == TokenType.PipePipeEq {
        return PREC_ASSIGN;
    }
    if tt == TokenType.QuestionQuestionEq {
        return PREC_ASSIGN;
    }
    # Conditional ? — handled inline
    # Nullish coalescing
    if tt == TokenType.QuestionQuestion {
        return PREC_NULLISH;
    }
    # Logical
    if tt == TokenType.PipePipe {
        return PREC_OR;
    }
    if tt == TokenType.AmpAmp {
        return PREC_AND;
    }
    # Bitwise
    if tt == TokenType.Pipe {
        return PREC_BOR;
    }
    if tt == TokenType.Caret {
        return PREC_BXOR;
    }
    if tt == TokenType.Amp {
        return PREC_BAND;
    }
    # Equality
    if tt == TokenType.EqEqEq {
        return PREC_EQUAL;
    }
    if tt == TokenType.BangEqEq {
        return PREC_EQUAL;
    }
    if tt == TokenType.EqEq {
        return PREC_EQUAL;
    }
    if tt == TokenType.BangEq {
        return PREC_EQUAL;
    }
    # Relational
    if tt == TokenType.Lt {
        return PREC_RELAT;
    }
    if tt == TokenType.Gt {
        return PREC_RELAT;
    }
    if tt == TokenType.LtEq {
        return PREC_RELAT;
    }
    if tt == TokenType.GtEq {
        return PREC_RELAT;
    }
    if tt == TokenType.KwIn {
        return PREC_RELAT;
    }
    if tt == TokenType.KwInstanceof {
        return PREC_RELAT;
    }
    # Shift
    if tt == TokenType.LtLt {
        return PREC_SHIFT;
    }
    if tt == TokenType.GtGt {
        return PREC_SHIFT;
    }
    if tt == TokenType.GtGtGt {
        return PREC_SHIFT;
    }
    # Additive
    if tt == TokenType.Plus {
        return PREC_ADD;
    }
    if tt == TokenType.Minus {
        return PREC_ADD;
    }
    # Multiplicative
    if tt == TokenType.Star {
        return PREC_MUL;
    }
    if tt == TokenType.Slash {
        return PREC_MUL;
    }
    if tt == TokenType.Percent {
        return PREC_MUL;
    }
    # Exponentiation (right-assoc, checked separately)
    if tt == TokenType.StarStar {
        return PREC_EXP;
    }
    return 0;
}

"""Return true if `tt` is a compound-assignment operator."""
def _is_assign_op(tt: TokenType) -> bool {
    return tt == TokenType.Eq
        or tt == TokenType.PlusEq
        or tt == TokenType.MinusEq
        or tt == TokenType.StarEq
        or tt == TokenType.SlashEq
        or tt == TokenType.PercentEq
        or tt == TokenType.StarStarEq
        or tt == TokenType.AmpEq
        or tt == TokenType.PipeEq
        or tt == TokenType.CaretEq
        or tt == TokenType.LtLtEq
        or tt == TokenType.GtGtEq
        or tt == TokenType.GtGtGtEq
        or tt == TokenType.AmpAmpEq
        or tt == TokenType.PipePipeEq
        or tt == TokenType.QuestionQuestionEq;
}

"""Return token value string for an operator token."""
def _op_str(tok: Token) -> str {
    return tok.value;
}

# ══════════════════════════════════════════════════════════════════════════════
# 3.  Parser object
# ══════════════════════════════════════════════════════════════════════════════

"""
Recursive descent / Pratt parser for JavaScript and TypeScript.

Usage:
    p = make_parser(source_code);
    program = p.parse_program();
"""
obj:pub Parser {
    has _lx: Lexer,
        _cur: Token,
        _peek: Token,
        _errors: list[str],
        _no_in: bool,
        in_generator_fn: bool = False,
        in_gen_params: bool = False,
        in_async_fn: bool = False,
        _prev: Token = Token(ttype=TokenType.EOF, value="", line=1, col=1);  # the underlying lexer

    # ── Internal helpers ──────────────────────────────────────────────────

    """Advance one token; returns the token that was current before advancing."""
    def _advance -> Token {
        prev: Token = self._cur;
        self._prev = prev;
        self._cur = self._peek;
        self._peek = self._lx.next_token();
        return prev;
    }

    """Save parser+lexer position for speculative parses (see _parser_restore)."""
    def _parser_checkpoint -> list[int] {
        snap: list[int] = self._lx.save_cursor();
        return snap;
    }

    """Rewind parser+lexer to a snapshot from _parser_checkpoint()."""
    def _parser_restore(snap: list[int]) {
        self._lx.restore_cursor(snap);
        self._cur = self._lx.next_token();
        self._peek = self._lx.next_token();
    }

    """Return current token type."""
    def _tt -> TokenType {
        return self._cur.ttype;
    }

    """Return true if current token type == expected."""
    def _is(tt: TokenType) -> bool {
        return self._cur.ttype == tt;
    }

    """Consume current token if it matches `tt`; return True on success."""
    def _eat(tt: TokenType) -> bool {
        if self._cur.ttype == tt {
            self._advance();
            return True;
        }
        return False;
    }

    """
    Consume current token, asserting it is `tt`.
    On mismatch, record an error and return the mismatched token anyway
    (error recovery: keep parsing).
    """
    def _expect(tt: TokenType) -> Token {
        tok: Token = self._cur;
        if tok.ttype != tt {
            msg: str = "Expected token "
                + str(tt)
                + " but got "
                + str(tok.ttype)
                + " ("
                + tok.value
                + ") at line "
                + str(tok.line);
            self._errors.append(msg);
        }
        return self._advance();
    }

    """Return true if current token is a semicolon or ASI applies."""
    def _semi -> bool {
        if self._is(TokenType.Semicolon) {
            self._advance();
            return True;
        }
        # ASI: newline before current token, end of block, or EOF
        if self._cur.has_newline_before {
            return True;
        }
        if self._is(TokenType.RBrace) {
            return True;
        }
        if self._is(TokenType.EOF) {
            return True;
        }
        return False;
    }

    """Skip a TypeScript type annotation starting at `:` (already consumed)."""
    def _skip_ts_type {
        # skip until we hit something that ends a type: , ; ) ] } = => { EOF
        # Handles nested < > for generics, ( ) for function types, [ ] for
        # tuple types, and { } for object types.
        depth: int = 0;
        running: bool = True;
        while running {
            tt: TokenType = self._tt();
            if tt == TokenType.EOF {
                running = False;
            } elif tt == TokenType.Lt {
                depth = depth + 1;
                self._advance();
            } elif tt == TokenType.Gt {
                if depth > 0 {
                    depth = depth - 1;
                }
                self._advance();
            } elif tt == TokenType.LParen {
                depth = depth + 1;
                self._advance();
            } elif tt == TokenType.RParen {
                if depth > 0 {
                    depth = depth - 1;
                    self._advance();
                } else {
                    running = False;
                }
            } elif tt == TokenType.LBracket {
                depth = depth + 1;
                self._advance();
            } elif tt == TokenType.RBracket {
                if depth > 0 {
                    depth = depth - 1;
                    self._advance();
                } else {
                    running = False;
                }
            } elif tt == TokenType.LBrace {
                depth = depth + 1;
                self._advance();
            } elif tt == TokenType.RBrace {
                if depth > 0 {
                    depth = depth - 1;
                    self._advance();
                } else {
                    running = False;
                }
            } elif depth == 0 {
                # Stop at these tokens when not inside brackets
                if tt == TokenType.Comma {
                    running = False;
                } elif tt == TokenType.Semicolon {
                    running = False;
                } elif tt == TokenType.Eq {
                    running = False;
                } elif tt == TokenType.Arrow {
                    running = False;
                } else {
                    self._advance();
                }
            } else {
                self._advance();
            }
        }
    }

    """Skip a TypeScript generic type argument list `<T, U>`."""
    def _skip_ts_generics {
        # Already past the `<`
        depth: int = 1;
        running: bool = True;
        while running and not self._is(TokenType.EOF) {
            tt: TokenType = self._tt();
            if tt == TokenType.Lt {
                depth = depth + 1;
                self._advance();
            } elif tt == TokenType.Gt {
                depth = depth - 1;
                self._advance();
                if depth == 0 {
                    running = False;
                }
            } else {
                self._advance();
            }
        }
    }

    # ── Range helper ──────────────────────────────────────────────────────

    def _loc -> SourceRange {
        return _range_of(self._cur);
    }

    """Span from `start` through the last consumed token (`_prev`).

    Must NOT use `_cur` (lookahead): after finishing a construct the current
    token is the *next* token, and ending there would leak trailing source into
    Function.prototype.toString (e.g. `}/* after */\\nassert…`)."""
    def _span(start: SourceRange) -> SourceRange {
        return _range_span(start, _range_of(self._prev));
    }

    # ══════════════════════════════════════════════════════════════════════
    # 4.  Top-level
    # ══════════════════════════════════════════════════════════════════════

    """Parse the whole source and return a Program node."""
    def:pub parse_program -> ASTNode {
        if PARSER_DEBUG_MODE {
            parser_debug("→ parse_program");
        }
        start: SourceRange = self._loc();
        body: list[ASTNode] = [];
        source_type: str = "script";

        # Detect module (presence of import/export at top level is common
        # but we default to script; callers can override)
        running: bool = True;
        while running {
            if self._is(TokenType.EOF) {
                running = False;
            } else {
                stmt: ASTNode = self._parse_stmt();
                body.append(stmt);
            }
        }
        return make_program(body, self._span(start), source_type);
    }

    # ══════════════════════════════════════════════════════════════════════
    # 5.  Statement parsing
    # ══════════════════════════════════════════════════════════════════════

    """Dispatch to the correct statement parser based on current token."""
    def _parse_stmt -> ASTNode {
        tt: TokenType = self._tt();

        # ── Leading decorators on a class declaration: `@dec class C {}` ──
        # (DecoratorList opt before `class`).  Decorators are parsed and discarded;
        # the following class statement is parsed normally.
        if tt == TokenType.At {
            self._skip_decorators();
            return self._parse_class_stmt();
        }

        # ── `using` declaration (explicit resource management) ──
        # `using` is a contextual keyword: it begins a declaration only when the
        # next token is a BindingIdentifier on the SAME line (ASI restriction —
        # `using\n x` is an expression statement `using;` then `x`).
        if self._is(TokenType.Identifier) and self._cur.value == "using" {
            if _tok_is_binding_ident(self._peek)
                and not self._peek.has_newline_before {
                return self._parse_var_stmt("using");
            }
        }
        # `await using x = …` — consume `await`, then the `using` declaration.
        # (Only valid where await is allowed; here we just parse the syntax.)
        if self._is(TokenType.KwAwait)
            and self._peek.ttype == TokenType.Identifier
            and self._peek.value == "using"
            and not self._peek.has_newline_before {
            self._advance();  # consume `await`
            return self._parse_var_stmt("await using");
        }

        # ── TypeScript declaration keywords (strip) ────────────────────
        # These are ordinary identifiers in JS ("type" is acorn's hottest local:
        # `type = keywords[word];` was being stripped as a TS alias, deleting the
        # assignment and mis-tokenizing every keyword). Only treat them as TS
        # when the FOLLOWING token makes the statement invalid JS: an identifier
        # (or the class/decl keyword for abstract/declare) on the SAME line —
        # `type X = …` is TS, `type = …` / `type(…)` / `type.x` are JS.
        if self._is(TokenType.Identifier) {
            v: str = self._cur.value;
            ts_next_ident: bool = self._peek.ttype == TokenType.Identifier
                and not self._peek.has_newline_before;
            if (v == "interface" or v == "type" or v == "namespace")
                and ts_next_ident {
                return self._parse_ts_decl_stmt();
            }
            if v == "abstract"
                and self._peek.ttype == TokenType.KwClass
                and not self._peek.has_newline_before {
                return self._parse_ts_decl_stmt();
            }
            if v == "declare"
                and not self._peek.has_newline_before
                and (
                    ts_next_ident
                    or self._peek.ttype == TokenType.KwVar
                    or self._peek.ttype == TokenType.KwLet
                    or self._peek.ttype == TokenType.KwConst
                    or self._peek.ttype == TokenType.KwFunction
                    or self._peek.ttype == TokenType.KwClass
                    or self._peek.ttype == TokenType.KwAsync
                ) {
                return self._parse_ts_decl_stmt();
            }
            if v == "enum" and ts_next_ident {
                return self._parse_ts_enum_stmt();
            }
        }

        # ── Async function ─────────────────────────────────────────────
        # `async [no LineTerminator here] function` (ES §15.8): a newline between
        # `async` and `function` breaks the AsyncFunctionDeclaration — `async` is a
        # plain identifier expression statement, and `function foo(){}` a separate
        # declaration.  (Newlines AFTER `function`, e.g. `async function\nfoo(){}`,
        # are fine — that is inside the declaration.)
        if self._is(TokenType.KwAsync)
            and self._peek.ttype == TokenType.KwFunction
            and not self._peek.has_newline_before {
            return self._parse_function_stmt(True);
        }

        if tt == TokenType.KwVar {
            return self._parse_var_stmt("var");
        }
        if tt == TokenType.KwLet {
            return self._parse_var_stmt("let");
        }
        if tt == TokenType.KwConst {
            return self._parse_var_stmt("const");
        }
        if tt == TokenType.KwFunction {
            return self._parse_function_stmt(False);
        }
        if tt == TokenType.KwClass {
            return self._parse_class_stmt();
        }
        if tt == TokenType.KwIf {
            return self._parse_if_stmt();
        }
        if tt == TokenType.KwWhile {
            return self._parse_while_stmt();
        }
        if tt == TokenType.KwWith {
            return self._parse_with_stmt();
        }
        if tt == TokenType.KwDo {
            return self._parse_do_while_stmt();
        }
        if tt == TokenType.KwFor {
            return self._parse_for_stmt();
        }
        if tt == TokenType.KwReturn {
            return self._parse_return_stmt();
        }
        if tt == TokenType.KwThrow {
            return self._parse_throw_stmt();
        }
        if tt == TokenType.KwTry {
            return self._parse_try_stmt();
        }
        if tt == TokenType.KwSwitch {
            return self._parse_switch_stmt();
        }
        if tt == TokenType.KwBreak {
            return self._parse_break_stmt();
        }
        if tt == TokenType.KwContinue {
            return self._parse_continue_stmt();
        }
        if tt == TokenType.KwDebugger {
            return self._parse_debugger_stmt();
        }
        if tt == TokenType.KwImport {
            # `import.meta` / dynamic `import()` at statement level — expression stmt
            if self._peek.ttype == TokenType.Dot {
                return self._parse_expr_stmt();
            }
            if self._peek.ttype == TokenType.LParen {
                return self._parse_expr_stmt();
            }
            return self._parse_import_stmt();
        }
        if tt == TokenType.KwExport {
            return self._parse_export_stmt();
        }
        if tt == TokenType.LBrace {
            return self._parse_block();
        }
        if tt == TokenType.Semicolon {
            start2: SourceRange = self._loc();
            self._advance();
            return make_empty_stmt(start2);
        }

        # Identifier followed by `:` → labeled statement. Contextual keywords that
        # are valid identifiers here (get/set/of/from/as/async/static, and
        # yield/await when NOT in a generator/async context) may also be a
        # LabelIdentifier (labeled/value-yield-non-strict, value-await-non-module).
        if self._peek.ttype == TokenType.Colon
            and (
                tt == TokenType.Identifier
                or _tok_is_binding_ident(self._cur)
                or (tt == TokenType.KwYield and not self.in_generator_fn)
                or (tt == TokenType.KwAwait and not self.in_async_fn)
            ) {
            return self._parse_labeled_stmt();
        }

        # Default: expression statement
        return self._parse_expr_stmt();
    }

    """Parse a block statement `{ stmt* }`."""
    def _parse_block -> ASTNode {
        start: SourceRange = self._loc();
        self._expect(TokenType.LBrace);
        body: list[ASTNode] = [];
        running: bool = True;
        while running {
            if self._is(TokenType.RBrace) or self._is(TokenType.EOF) {
                running = False;
            } else {
                body.append(self._parse_stmt());
            }
        }
        self._expect(TokenType.RBrace);
        return make_block(body, self._span(start));
    }

    """Parse `var/let/const` declaration."""
    def _parse_var_stmt(kind: str) -> ASTNode {
        start: SourceRange = self._loc();
        self._advance();  # consume var/let/const
        decls: list[ASTNode] = [];
        keep_going: bool = True;
        while keep_going {
            d: ASTNode = self._parse_var_declarator();
            decls.append(d);
            if self._eat(TokenType.Comma) {
                keep_going = True;
            } else {
                keep_going = False;
            }
        }
        self._semi();
        return make_var_decl(kind, decls, self._span(start));
    }

    """Parse a single declarator `id [= init]`."""
    def _parse_var_declarator -> ASTNode {
        start: SourceRange = self._loc();
        lhs: ASTNode = self._parse_binding_pattern();
        # TypeScript type annotation after identifier: `x: Type`
        if self._is(TokenType.Colon) {
            self._advance();
            self._skip_ts_type();
        }
        init: ASTNode | None = None;
        if self._eat(TokenType.Eq) {
            init = self._parse_assignment_expr();
        }
        return make_var_declarator(lhs, init, self._span(start));
    }

    """Parse a function declaration (or expression-statement form)."""
    def _parse_function_stmt(is_async: bool) -> ASTNode {
        start: SourceRange = self._loc();
        if is_async {
            self._advance();
        }  # consume `async`
        self._expect(TokenType.KwFunction);
        is_gen: bool = False;
        if self._eat(TokenType.Star) {
            is_gen = True;
        }
        # Skip optional TS type params `<T>`
        if self._is(TokenType.Lt) {
            self._advance();
            self._skip_ts_generics();
        }
        id: ASTNode | None = None;
        # The BindingIdentifier (name) is governed by the [Yield]/[Await] context of
        # the function BEING declared, not the enclosing one (ES §15.1): a
        # non-generator `function* yield(){}`… no — `function yield(){}` (non-gen) and
        # `async function await(){}` are legal (non-strict) because the name is
        # evaluated with the inner fn's [Yield]/[Await] = false/false.  Gate on
        # `is_gen`/`is_async`, matching the function-expression path.
        if self._is(TokenType.Identifier)
            or self._is(TokenType.KwGet)
            or self._is(TokenType.KwSet)
            or self._is(TokenType.KwStatic)
            or self._is(TokenType.KwFrom)
            or self._is(TokenType.KwAs)
            or self._is(TokenType.KwOf)
            or self._is(TokenType.KwAsync)
            or self._is(TokenType.KwLet)
            or self._is(TokenType.KwYield)
            or self._is(TokenType.KwAwait) {
            id = make_identifier(self._cur.value, self._loc());
            self._advance();
        }
        # A function DECLARATION's parameters are parsed in ITS OWN [Yield]/[Await]
        # context, NOT the enclosing one (§15.1). A non-generator `f` declared inside a
        # generator `g` parses `f(x = yield)` with `yield` as an IDENTIFIER, not a
        # YieldExpression (param-dflt-yield-non-strict). So set in_generator_fn /
        # in_async_fn to this function's own kind BEFORE parsing params.
        saved_gen: bool = self.in_generator_fn;
        saved_async: bool = self.in_async_fn;
        self.in_generator_fn = is_gen;
        self.in_async_fn = is_async;
        saved_gp: bool = self.in_gen_params;
        if is_gen {
            self.in_gen_params = True;
        }
        params: list[ASTNode] = self._parse_params();
        self.in_gen_params = saved_gp;
        # TS return type annotation
        if self._is(TokenType.Colon) {
            self._advance();
            self._skip_ts_type();
        }
        body: ASTNode = self._parse_block();
        self.in_generator_fn = saved_gen;
        self.in_async_fn = saved_async;
        return make_function_decl(
            id, params, body, self._span(start), is_async, is_gen
        );
    }

    """Parse a class declaration `class id [extends sup] { ... }`."""
    def _parse_class_stmt -> ASTNode {
        start: SourceRange = self._loc();
        self._expect(TokenType.KwClass);
        # Skip TS type params
        id: ASTNode | None = None;
        if self._is(TokenType.Identifier)
            or self._is(TokenType.KwGet)
            or self._is(TokenType.KwSet)
            or self._is(TokenType.KwStatic)
            or self._is(TokenType.KwFrom)
            or self._is(TokenType.KwAs)
            or self._is(TokenType.KwOf)
            or self._is(TokenType.KwAsync)
            or self._is(TokenType.KwLet)
            or (self._is(TokenType.KwYield) and not self.in_generator_fn)
            or (self._is(TokenType.KwAwait) and not self.in_async_fn) {
            id = make_identifier(self._cur.value, self._loc());
            self._advance();
        }
        if self._is(TokenType.Lt) {
            self._advance();
            self._skip_ts_generics();
        }
        sup: ASTNode | None = None;
        if self._eat(TokenType.KwExtends) {
            sup = self._parse_left_hand_expr();
            # TS type args for extends
            if self._is(TokenType.Lt) {
                self._advance();
                self._skip_ts_generics();
            }
        }
        body: list[ASTNode] = self._parse_class_body();
        return make_class_decl(id, sup, body, self._span(start));
    }

    """Parse class body `{ method* }`."""
    def _parse_class_body -> list[ASTNode] {
        self._expect(TokenType.LBrace);
        members: list[ASTNode] = [];
        running: bool = True;
        while running {
            if self._is(TokenType.RBrace) or self._is(TokenType.EOF) {
                running = False;
            } else {
                if self._is(TokenType.Semicolon) {
                    self._advance();
                } else {
                    m: ASTNode = self._parse_class_member();
                    members.append(m);
                }
            }
        }
        self._expect(TokenType.RBrace);
        return members;
    }

    """
    Parse and discard a DecoratorList (TC39 decorators proposal, Stage 3).
    js_engine does not yet *apply* decorators, but the syntax must parse so that
    decorated classes / class expressions / class members are accepted.

    Decorator := '@' ( DecoratorMemberExpression | DecoratorCallExpression
                       | DecoratorParenthesizedExpression )
    The operand is parsed via the normal call/member expression machinery and
    thrown away.  Returns True if at least one decorator was consumed.
    """
    def _skip_decorators -> bool {
        seen: bool = False;
        while self._is(TokenType.At) {
            seen = True;
            self._advance();  # consume '@'
            if self._is(TokenType.LParen) {
                # @( AssignmentExpression )
                self._advance();
                _ = self._parse_assignment_expr();
                self._expect(TokenType.RParen);
            } else {
                # @ DecoratorMemberExpression / DecoratorCallExpression —
                # parse a full call/member chain (handles `a`, `a.b`, `a.#b`,
                # `a.b.c`, `a()`, `a.b()`), then discard.
                _ = self._parse_call_member();
            }
        }
        return seen;
    }

    """Parse a single class member (method or field)."""
    def _parse_class_member -> ASTNode {
        start: SourceRange = self._loc();
        # Function.prototype.toString for methods uses MethodDefinition source
        # *excluding* the `static` keyword (engines / test262).  Track that
        # separately from the ClassElement span.
        src_start: SourceRange = start;
        is_static: bool = False;
        is_async: bool = False;
        is_gen: bool = False;
        kind: str = "method";
        forced_key: ASTNode | None = None;  # `static`/`get`/`set`/`async` used as a member NAME

        # Member decorators: `@dec method() {}` / `@dec field;`  (parsed, discarded).
        self._skip_decorators();

        if self._is(TokenType.KwStatic) {
            is_static = True;
            self._advance();
            # Static initialization block: `static { ... }` (ES2022 §15.7).
            # Distinguished from a method named "static" by a `{` following
            # `static`.  Represented as a MethodDefinition(kind="static-block")
            # whose value is a synthetic zero-arg function holding the block body;
            # the compiler runs it once at class-definition time with this=class.
            if self._is(TokenType.LBrace) {
                saved_gen_sb: bool = self.in_generator_fn;
                self.in_generator_fn = False;
                sb_body: ASTNode = self._parse_block();
                self.in_generator_fn = saved_gen_sb;
                sb_fn: ASTNode = make_function_expr(
                    None, [], sb_body, self._span(start), False, False
                );
                return make_method_def(
                    make_identifier("", ZERO_RANGE),
                    sb_fn,
                    "static-block",
                    True,
                    False,
                    self._span(start)
                );
            }
            # `static` is itself a valid ClassElementName (ES §15.7): `static;` / `static = v;`
            # / `static(){}` / `static` as the last member. When `static` is NOT followed by
            # another element name (i.e. the next token ends/assigns/opens the element), it IS
            # the member name, not the static modifier.
            if self._is(TokenType.Semicolon)
                or self._is(TokenType.Eq)
                or self._is(TokenType.LParen)
                or self._is(TokenType.RBrace)
                or self._is(TokenType.Colon) {
                is_static = False;
                forced_key = make_identifier("static", src_start);
            }
            src_start = self._loc();
        }

        if self._is(TokenType.KwAsync) and self._peek.ttype != TokenType.LParen {
            is_async = True;
            self._advance();
            if self._eat(TokenType.Star) {
                is_gen = True;
            }
        } elif self._eat(TokenType.Star) {
            is_gen = True;
        }

        # get / set accessors
        if self._is(TokenType.KwGet) or self._is(TokenType.KwSet) {
            kw_val: str = self._cur.value;
            # `get`/`set` is an accessor unless immediately followed by `(` (a method named
            # `get`/`set`) or `*` (a GENERATOR — accessors can't be generators, so `get\n
            # *a(){}` is a field named `get` + a generator method `a`; ES §15.7 + ASI,
            # test262 grammar-field-named-{get,set}-followed-by-generator-asi).
            if self._peek.ttype != TokenType.LParen
                and self._peek.ttype != TokenType.Star {
                kind = kw_val;
                self._advance();
            }
        }

        # Track whether this is a computed key `[expr]`
        cm_computed: bool = forced_key is None and self._is(TokenType.LBracket);

        key: ASTNode = forced_key if forced_key is not None else self._parse_prop_key();
        # Optional TS type params on method
        if self._is(TokenType.Lt) {
            self._advance();
            self._skip_ts_generics();
        }

        # Field (not a method): `x: Type = init;`
        if not self._is(TokenType.LParen) {
            if self._is(TokenType.Colon) {
                self._advance();
                self._skip_ts_type();
            }
            init: ASTNode | None = None;
            if self._eat(TokenType.Eq) {
                init = self._parse_assignment_expr();
            }
            self._semi();
            # Pass the initializer expression (or None) as the `value` field.
            # For fields without an initializer, use a null placeholder.
            field_val: ASTNode = init
                if init is not None
                else make_identifier("", ZERO_RANGE);
            return make_method_def(
                key, field_val, "field", is_static, cm_computed, self._span(start)
            );
        }

        saved_gp_cm: bool = self.in_gen_params;
        if is_gen {
            self.in_gen_params = True;
        }
        params: list[ASTNode] = self._parse_params();
        self.in_gen_params = saved_gp_cm;
        if self._is(TokenType.Colon) {
            self._advance();
            self._skip_ts_type();
        }
        saved_gen_cm: bool = self.in_generator_fn;
        saved_async_cm: bool = self.in_async_fn;
        self.in_generator_fn = is_gen;
        self.in_async_fn = is_async;
        body: ASTNode = self._parse_block();
        self.in_generator_fn = saved_gen_cm;
        self.in_async_fn = saved_async_cm;
        # Use src_start (post-`static`) so toString omits the static keyword.
        fn_node: ASTNode = make_function_expr(
            None, params, body, self._span(src_start), is_async, is_gen
        );
        fn_node.is_method = True;  # class method/accessor — no own `prototype`
        return make_method_def(
            key, fn_node, kind, is_static, cm_computed, self._span(start)
        );
    }

    """Parse an if statement."""
    def _parse_if_stmt -> ASTNode {
        start: SourceRange = self._loc();
        self._expect(TokenType.KwIf);
        self._expect(TokenType.LParen);
        cond: ASTNode = self._parse_expr(PREC_COMMA);
        self._expect(TokenType.RParen);
        cons: ASTNode = self._parse_stmt();
        alt: ASTNode | None = None;
        if self._eat(TokenType.KwElse) {
            alt = self._parse_stmt();
        }
        return make_if(cond, cons, alt, self._span(start));
    }

    """Parse a while statement."""
    def _parse_while_stmt -> ASTNode {
        start: SourceRange = self._loc();
        self._expect(TokenType.KwWhile);
        self._expect(TokenType.LParen);
        cond: ASTNode = self._parse_expr(PREC_COMMA);
        self._expect(TokenType.RParen);
        body: ASTNode = self._parse_stmt();
        return make_while(cond, body, self._span(start));
    }

    """Parse a with statement: `with (object) body`.  Strict-mode rejection
    (with is a SyntaxError under "use strict") is handled in the compiler, which
    is where strict mode is tracked."""
    def _parse_with_stmt -> ASTNode {
        start: SourceRange = self._loc();
        self._expect(TokenType.KwWith);
        self._expect(TokenType.LParen);
        with_obj: ASTNode = self._parse_expr(PREC_COMMA);
        self._expect(TokenType.RParen);
        body: ASTNode = self._parse_stmt();
        return make_with(with_obj, body, self._span(start));
    }

    """Parse a do-while statement."""
    def _parse_do_while_stmt -> ASTNode {
        start: SourceRange = self._loc();
        self._expect(TokenType.KwDo);
        body: ASTNode = self._parse_stmt();
        self._expect(TokenType.KwWhile);
        self._expect(TokenType.LParen);
        cond: ASTNode = self._parse_expr(PREC_COMMA);
        self._expect(TokenType.RParen);
        self._semi();
        return make_do_while(body, cond, self._span(start));
    }

    """Parse for / for-in / for-of statement."""
    def _parse_for_stmt -> ASTNode {
        start: SourceRange = self._loc();
        self._expect(TokenType.KwFor);
        is_await_for: bool = False;
        if self._is(TokenType.KwAwait) {
            is_await_for = True;
            self._advance();
        }
        self._expect(TokenType.LParen);

        # Check for `for (var/let/const/using x of/in ...)`
        left_kind: str = "";
        if self._is(TokenType.KwVar) {
            left_kind = "var";
        } elif self._is(TokenType.KwLet)
            and (
                _tok_is_binding_ident(self._peek)
                or self._peek.ttype == TokenType.LBracket
                or self._peek.ttype == TokenType.LBrace
            ) {
            # `let` in a for-header is a declaration keyword ONLY when followed by a binding
            # (identifier / `[` array pattern / `{` object pattern). `for (let in obj)`,
            # `for (let; ;)`, `for (let = 3; ;)`, `for (let.x of …)` use `let` as an ordinary
            # IDENTIFIER (non-strict) → fall through to the expression-init path below (test262
            # for-in/head-lhs-let, for/head-lhs-let, identifier-let-allowed-as-lefthandside).
            left_kind = "let";
        } elif self._is(TokenType.KwConst) {
            left_kind = "const";
        }
        # `for (using x of …)` / `for await (using x of …)` — `using` is a contextual
        # keyword (declaration only when followed by a binding identifier that is not
        # `of`/`in`, on the same line). `using` is valid only in for-of, not for-in.
        elif self._is(TokenType.Identifier)
            and self._cur.value == "using"
            and _tok_is_binding_ident(self._peek)
            and not self._peek.has_newline_before
            and self._peek.value != "of"
            and self._peek.value != "in" {
            left_kind = "using";
        }
        # `for await (await using x of …)`
        elif self._is(TokenType.KwAwait)
            and self._peek.ttype == TokenType.Identifier
            and self._peek.value == "using"
            and not self._peek.has_newline_before {
            self._advance();  # consume the leading `await` of `await using`
            left_kind = "await using";
        }

        if left_kind != "" {
            # Tentatively parse the first declarator to detect in/of
            decl_start: SourceRange = self._loc();
            self._advance();  # consume var/let/const
            lhs_pat: ASTNode = self._parse_binding_pattern();
            if self._is(TokenType.Colon) {
                self._advance();
                self._skip_ts_type();
            }
            if self._is(TokenType.KwIn) or self._is(TokenType.KwOf) {
                is_of: bool = self._is(TokenType.KwOf);
                self._advance();
                right: ASTNode = self._parse_expr(PREC_COMMA);
                self._expect(TokenType.RParen);
                body2: ASTNode = self._parse_stmt();
                decl2: ASTNode = make_var_decl(
                    left_kind,
                    [make_var_declarator(lhs_pat, None, decl_start)],
                    decl_start
                );
                if is_of {
                    return make_for_of(
                        decl2, right, body2, self._span(start), is_await_for
                    );
                } else {
                    return make_for_in(decl2, right, body2, self._span(start));
                }
            }
            # Normal for loop — continue parsing the rest of init
            init_decls: list[ASTNode] = [];
            if self._eat(TokenType.Eq) {
                init_val: ASTNode = self._parse_assignment_expr();
                init_decls.append(make_var_declarator(lhs_pat, init_val, decl_start));
            } else {
                init_decls.append(make_var_declarator(lhs_pat, None, decl_start));
            }
            while self._eat(TokenType.Comma) {
                init_decls.append(self._parse_var_declarator());
            }
            init_node: ASTNode = make_var_decl(left_kind, init_decls, decl_start);
            self._expect(TokenType.Semicolon);
            for_test: ASTNode | None = None;
            if not self._is(TokenType.Semicolon) {
                for_test = self._parse_expr(PREC_COMMA);
            }
            self._expect(TokenType.Semicolon);
            for_upd: ASTNode | None = None;
            if not self._is(TokenType.RParen) {
                for_upd = self._parse_expr(PREC_COMMA);
            }
            self._expect(TokenType.RParen);
            for_body: ASTNode = self._parse_stmt();
            return make_for(init_node, for_test, for_upd, for_body, self._span(start));
        }

        # No leading declaration keyword
        if self._is(TokenType.Semicolon) {
            # for (;
            self._advance();
            f_test: ASTNode | None = None;
            if not self._is(TokenType.Semicolon) {
                f_test = self._parse_expr(PREC_COMMA);
            }
            self._expect(TokenType.Semicolon);
            f_upd: ASTNode | None = None;
            if not self._is(TokenType.RParen) {
                f_upd = self._parse_expr(PREC_COMMA);
            }
            self._expect(TokenType.RParen);
            f_body: ASTNode = self._parse_stmt();
            return make_for(None, f_test, f_upd, f_body, self._span(start));
        }

        # Expression-based: could be for (x in y) or for (x of y) or for (expr;...)
        # Use _no_in to suppress `in` as binary operator — allows full expression
        # parsing (assignments, ternary, etc.) while still detecting for-in/for-of.
        self._no_in = True;
        lhs_expr: ASTNode = self._parse_expr(PREC_COMMA);
        self._no_in = False;
        if self._is(TokenType.KwIn) or self._is(TokenType.KwOf) {
            is_of2: bool = self._is(TokenType.KwOf);
            self._advance();
            rhs_expr: ASTNode = self._parse_expr(PREC_COMMA);
            self._expect(TokenType.RParen);
            b_expr: ASTNode = self._parse_stmt();
            if is_of2 {
                return make_for_of(
                    lhs_expr, rhs_expr, b_expr, self._span(start), is_await_for
                );
            } else {
                return make_for_in(lhs_expr, rhs_expr, b_expr, self._span(start));
            }
        }
        self._expect(TokenType.Semicolon);
        f2_test: ASTNode | None = None;
        if not self._is(TokenType.Semicolon) {
            f2_test = self._parse_expr(PREC_COMMA);
        }
        self._expect(TokenType.Semicolon);
        f2_upd: ASTNode | None = None;
        if not self._is(TokenType.RParen) {
            f2_upd = self._parse_expr(PREC_COMMA);
        }
        self._expect(TokenType.RParen);
        f2_body: ASTNode = self._parse_stmt();
        return make_for(lhs_expr, f2_test, f2_upd, f2_body, self._span(start));
    }

    """
    Return true if the current token can NOT start a new statement and therefore
    ASI must NOT be inserted before it even when `has_newline_before` is true.

    ECMAScript 12.10.1 — ASI is suppressed when the offending token is a
    *continuation* token: an infix/postfix operator, a property accessor, or
    an open bracket/paren.  The list below covers all tokens that can appear
    as the first token of the second line in a multi-line expression but that
    can never start an independent ExpressionStatement.
    """
    def _continues_expr -> bool {
        tt: TokenType = self._cur.ttype;
        # Ternary / nullish / optional-chain
        if tt == TokenType.Question {
            return True;
        }
        if tt == TokenType.QuestionQuestion {
            return True;
        }
        if tt == TokenType.QuestionDot {
            return True;
        }
        # Property access / call / index
        if tt == TokenType.Dot {
            return True;
        }
        if tt == TokenType.LParen {
            return True;
        }
        if tt == TokenType.LBracket {
            return True;
        }
        # Binary arithmetic / bitwise
        if tt == TokenType.Plus {
            return True;
        }
        if tt == TokenType.Minus {
            return True;
        }
        if tt == TokenType.Star {
            return True;
        }
        if tt == TokenType.StarStar {
            return True;
        }
        if tt == TokenType.Slash {
            return True;
        }
        if tt == TokenType.Percent {
            return True;
        }
        if tt == TokenType.Pipe {
            return True;
        }
        if tt == TokenType.PipePipe {
            return True;
        }
        if tt == TokenType.Colon {
            return True;
        }
        return False;
    }

    """Parse `return [expr];`."""
    def _parse_return_stmt -> ASTNode {
        start: SourceRange = self._loc();
        self._expect(TokenType.KwReturn);
        arg: ASTNode | None = None;
        # ASI after `return` is suppressed when the next token is a continuation
        # token (e.g. `?` for ternary, `.` for member access, `(` for call, etc.)
        # because those tokens cannot start a new statement.
        has_newline: bool = self._cur.has_newline_before;
        if not self._is(TokenType.Semicolon)
            and not self._is(TokenType.RBrace)
            and not self._is(TokenType.EOF)
            and (not has_newline or self._continues_expr()) {
            arg = self._parse_expr(PREC_COMMA);
        }
        self._semi();
        return make_return(arg, self._span(start));
    }

    """Parse `throw expr;`."""
    def _parse_throw_stmt -> ASTNode {
        start: SourceRange = self._loc();
        self._expect(TokenType.KwThrow);
        arg: ASTNode = self._parse_expr(PREC_COMMA);
        self._semi();
        return make_throw(arg, self._span(start));
    }

    """Parse try/catch/finally."""
    def _parse_try_stmt -> ASTNode {
        start: SourceRange = self._loc();
        self._expect(TokenType.KwTry);
        tr_body: ASTNode = self._parse_block();
        handler: ASTNode | None = None;
        finalizer: ASTNode | None = None;
        if self._eat(TokenType.KwCatch) {
            catch_start: SourceRange = self._loc();
            param: ASTNode | None = None;
            if self._eat(TokenType.LParen) {
                param = self._parse_binding_pattern();
                if self._is(TokenType.Colon) {
                    self._advance();
                    self._skip_ts_type();
                }
                self._expect(TokenType.RParen);
            }
            catch_body: ASTNode = self._parse_block();
            handler = make_catch(param, catch_body, self._span(catch_start));
        }
        if self._eat(TokenType.KwFinally) {
            finalizer = self._parse_block();
        }
        return make_try(tr_body, handler, finalizer, self._span(start));
    }

    """Parse switch statement."""
    def _parse_switch_stmt -> ASTNode {
        start: SourceRange = self._loc();
        self._expect(TokenType.KwSwitch);
        self._expect(TokenType.LParen);
        disc: ASTNode = self._parse_expr(PREC_COMMA);
        self._expect(TokenType.RParen);
        self._expect(TokenType.LBrace);
        cases: list[ASTNode] = [];
        has_default: bool = False;
        while not self._is(TokenType.RBrace) and not self._is(TokenType.EOF) {
            c_start: SourceRange = self._loc();
            c_test: ASTNode | None = None;
            if self._eat(TokenType.KwCase) {
                c_test = self._parse_expr(PREC_COMMA);
                self._expect(TokenType.Colon);
            } elif self._eat(TokenType.KwDefault) {
                if has_default {
                    self._errors.append(
                        "SyntaxError: More than one default clause in switch statement at line "
                            + str(self._cur.line)
                    );
                }
                has_default = True;
                self._expect(TokenType.Colon);
            } else {
                # malformed — consume to prevent infinite loop
                self._advance();
            }
            c_body: list[ASTNode] = [];
            while not self._is(TokenType.KwCase)
                and not self._is(TokenType.KwDefault)
                and not self._is(TokenType.RBrace)
                and not self._is(TokenType.EOF) {
                c_body.append(self._parse_stmt());
            }
            cases.append(make_switch_case(c_test, c_body, self._span(c_start)));
        }
        self._expect(TokenType.RBrace);
        return make_switch(disc, cases, self._span(start));
    }

    """Parse `break [label];`."""
    def _parse_break_stmt -> ASTNode {
        start: SourceRange = self._loc();
        self._expect(TokenType.KwBreak);
        lbl: str = "";
        if self._is(TokenType.Identifier) and not self._cur.has_newline_before {
            lbl = self._cur.value;
            self._advance();
        }
        self._semi();
        return make_break(lbl, self._span(start));
    }

    """Parse `continue [label];`."""
    def _parse_continue_stmt -> ASTNode {
        start: SourceRange = self._loc();
        self._expect(TokenType.KwContinue);
        lbl: str = "";
        if self._is(TokenType.Identifier) and not self._cur.has_newline_before {
            lbl = self._cur.value;
            self._advance();
        }
        self._semi();
        return make_continue(lbl, self._span(start));
    }

    """Parse `debugger;`."""
    def _parse_debugger_stmt -> ASTNode {
        start: SourceRange = self._loc();
        self._expect(TokenType.KwDebugger);
        self._semi();
        return make_debugger(self._span(start));
    }

    """Parse `label: stmt`."""
    def _parse_labeled_stmt -> ASTNode {
        start: SourceRange = self._loc();
        lbl_name: str = self._cur.value;
        self._advance();  # identifier
        self._expect(TokenType.Colon);
        body: ASTNode = self._parse_stmt();
        return make_labeled(lbl_name, body, self._span(start));
    }

    """Parse `import ...` statement."""
    def _parse_import_stmt -> ASTNode {
        start: SourceRange = self._loc();
        self._expect(TokenType.KwImport);

        # `import type ...` — TS
        if self._is(TokenType.Identifier) and self._cur.value == "type" {
            self._advance();
            # consume until end of import
            while not self._is(TokenType.Semicolon) and not self._is(TokenType.EOF) {
                self._advance();
            }
            self._semi();
            return make_empty_stmt(self._span(start));
        }

        # `import "module"` — bare import
        if self._is(TokenType.StringLiteral) {
            src: ASTNode = make_literal(self._cur.value, self._cur.value, self._loc());
            self._advance();
            self._semi();
            return make_import([], src, self._span(start));
        }

        # `import source name from "mod"` — source-phase import (WASM Module)
        if self._is(TokenType.Identifier) and self._cur.value == "source" {
            # Only treat as phase keyword when followed by a binding identifier
            # then `from` (not `import source from "x"` as default named source).
            peek_ok: bool = self._peek.ttype == TokenType.Identifier;
            if peek_ok {
                self._advance();  # consume `source`
                src_local: ASTNode = make_identifier(self._cur.value, self._loc());
                self._advance();
                self._expect(TokenType.KwFrom);
                src_path: ASTNode = make_literal(
                    self._cur.value, self._cur.value, self._loc()
                );
                self._advance();
                self._parse_import_attributes();
                self._semi();
                src_spec: ASTNode = make_import_specifier(
                    make_identifier("default", self._loc()), src_local, self._loc()
                );
                src_imp: ASTNode = make_import([src_spec], src_path, self._span(start));
                src_imp.kind = "source";
                return src_imp;
            }
        }

        # `import defer * as ns from "mod"` — deferred module evaluation (TC39)
        # Only treat `defer` as a phase keyword when followed by `* as`.
        if self._is(TokenType.Identifier) and self._cur.value == "defer" {
            if self._peek.ttype == TokenType.Star {
                self._advance();  # consume `defer`
                self._expect(TokenType.Star);
                self._expect(TokenType.KwAs);
                defer_ns: ASTNode = make_identifier(self._cur.value, self._loc());
                self._advance();
                self._expect(TokenType.KwFrom);
                defer_path: ASTNode = make_literal(
                    self._cur.value, self._cur.value, self._loc()
                );
                self._advance();
                self._parse_import_attributes();
                self._semi();
                defer_spec: ASTNode = make_import_specifier(
                    make_identifier("*", self._loc()), defer_ns, self._loc()
                );
                defer_imp: ASTNode = make_import(
                    [defer_spec], defer_path, self._span(start)
                );
                defer_imp.kind = "defer";
                return defer_imp;
            }
        }

        specs: list[ASTNode] = [];

        # `import defaultExport from "mod"`
        if self._is(TokenType.Identifier) {
            def_name: ASTNode = make_identifier(self._cur.value, self._loc());
            self._advance();
            def_spec: ASTNode = make_import_specifier(
                make_identifier("default", self._loc()), def_name, self._loc()
            );
            specs.append(def_spec);
            if not self._eat(TokenType.Comma) and not self._is(TokenType.KwFrom) {
                # nothing more to do; fall through
            }
        }

        # `import * as name from "mod"`
        if self._eat(TokenType.Star) {
            self._expect(TokenType.KwAs);
            ns_name: ASTNode = make_identifier(self._cur.value, self._loc());
            self._advance();
            specs.append(
                make_import_specifier(
                    make_identifier("*", self._loc()), ns_name, self._loc()
                )
            );
        }

        # `import { a, b as c } from "mod"`
        if self._eat(TokenType.LBrace) {
            while not self._is(TokenType.RBrace) and not self._is(TokenType.EOF) {
                imp_start: SourceRange = self._loc();
                imported_id: ASTNode = make_identifier(self._cur.value, self._loc());
                self._advance();
                local_id: ASTNode = imported_id;
                if self._eat(TokenType.KwAs) {
                    local_id = make_identifier(self._cur.value, self._loc());
                    self._advance();
                }
                specs.append(
                    make_import_specifier(imported_id, local_id, self._span(imp_start))
                );
                self._eat(TokenType.Comma);
            }
            self._expect(TokenType.RBrace);
        }

        self._expect(TokenType.KwFrom);
        src2: ASTNode = make_literal(self._cur.value, self._cur.value, self._loc());
        self._advance();  # string literal
        # Import attributes (ES import-attributes / legacy import-assertions):
        #   import x from "m" with { type: "json" };
        #   import x from "m" assert { type: "json" };  (legacy)
        # Parse the clause so the syntax is accepted. The attributes are consumed
        # but not yet threaded to the loader (JSON/text module types are a separate
        # feature); the loader currently infers type from the specifier extension.
        self._parse_import_attributes();
        self._semi();
        return make_import(specs, src2, self._span(start));
    }

    """Parse an optional `with { … }` / `assert { … }` import-attributes clause
    (ES §16.2.1). The `with`/`assert` keyword must be on the SAME line as the
    preceding token (no ASI break). Attribute keys are IdentifierName or String,
    values are String literals. Currently consumed and discarded."""
    def _parse_import_attributes -> None {
        has_with: bool = self._is(TokenType.KwWith)
            and not self._cur.has_newline_before;
        has_assert: bool = self._is(TokenType.Identifier)
            and self._cur.value == "assert"
            and not self._cur.has_newline_before;
        if not has_with and not has_assert {
            return;
        }
        self._advance();  # consume `with` / `assert`
        self._expect(TokenType.LBrace);
        while not self._is(TokenType.RBrace) and not self._is(TokenType.EOF) {
            # key : "value"
            if self._is(TokenType.Identifier) or self._is(TokenType.StringLiteral) {
                self._advance();
            } else {
                self._advance();
            }
            self._expect(TokenType.Colon);
            self._advance();  # the string-literal value
            if not self._eat(TokenType.Comma) {}
        }
        self._expect(TokenType.RBrace);
    }

    """Parse `export ...` statement."""
    def _parse_export_stmt -> ASTNode {
        start: SourceRange = self._loc();
        self._expect(TokenType.KwExport);

        # `export type ...` — TS
        if self._is(TokenType.Identifier) and self._cur.value == "type" {
            self._advance();
            while not self._is(TokenType.Semicolon) and not self._is(TokenType.EOF) {
                self._advance();
            }
            self._semi();
            return make_empty_stmt(self._span(start));
        }

        # `export default expr|decl`
        if self._eat(TokenType.KwDefault) {
            decl: ASTNode | None = None;
            if self._is(TokenType.KwFunction)
                or self._is(TokenType.KwClass)
                or (
                    self._is(TokenType.KwAsync)
                    and self._peek.ttype == TokenType.KwFunction
                ) {
                decl = self._parse_stmt();
            } else {
                decl = self._parse_expr(PREC_COMMA);
                self._semi();
            }
            return make_export_default(decl, self._span(start));
        }

        # `export * [as name] from "mod"`
        if self._eat(TokenType.Star) {
            exported_name: ASTNode | None = None;
            if self._eat(TokenType.KwAs) {
                exported_name = make_identifier(self._cur.value, self._loc());
                self._advance();
            }
            self._expect(TokenType.KwFrom);
            exp_src: ASTNode = make_literal(
                self._cur.value, self._cur.value, self._loc()
            );
            self._advance();
            self._semi();
            return make_export_all(exp_src, exported_name, self._span(start));
        }

        # `export { a, b as c } [from "mod"]`
        if self._is(TokenType.LBrace) {
            self._advance();
            exp_specs: list[ASTNode] = [];
            while not self._is(TokenType.RBrace) and not self._is(TokenType.EOF) {
                exp_s_start: SourceRange = self._loc();
                local_e: ASTNode = make_identifier(self._cur.value, self._loc());
                self._advance();
                exported_e: ASTNode = local_e;
                if self._eat(TokenType.KwAs) {
                    exported_e = make_identifier(self._cur.value, self._loc());
                    self._advance();
                }
                exp_specs.append(
                    make_export_specifier(local_e, exported_e, self._span(exp_s_start))
                );
                self._eat(TokenType.Comma);
            }
            self._expect(TokenType.RBrace);
            exp_src2: ASTNode | None = None;
            if self._eat(TokenType.KwFrom) {
                exp_src2 = make_literal(self._cur.value, self._cur.value, self._loc());
                self._advance();
            }
            self._semi();
            return make_export_named(exp_specs, None, exp_src2, self._span(start));
        }

        # `export var/let/const/function/class ...`
        inner: ASTNode = self._parse_stmt();
        return make_export_named([], inner, None, self._span(start));
    }

    """Strip TypeScript interface/type/namespace/abstract/declare declaration."""
    def _parse_ts_decl_stmt -> ASTNode {
        start: SourceRange = self._loc();
        self._advance();  # consume keyword identifier
        # Skip everything until we reach a statement boundary
        depth2: int = 0;
        running2: bool = True;
        while running2 {
            tt2: TokenType = self._tt();
            if tt2 == TokenType.EOF {
                running2 = False;
            } elif tt2 == TokenType.LBrace {
                depth2 = depth2 + 1;
                self._advance();
            } elif tt2 == TokenType.RBrace {
                if depth2 > 0 {
                    depth2 = depth2 - 1;
                    self._advance();
                }
                if depth2 == 0 {
                    running2 = False;
                }
            } elif tt2 == TokenType.Semicolon {
                self._advance();
                running2 = False;
            } else {
                self._advance();
            }
        }
        return make_empty_stmt(self._span(start));
    }

    """Strip TypeScript enum declaration (emitted as empty statement)."""
    def _parse_ts_enum_stmt -> ASTNode {
        start: SourceRange = self._loc();
        self._advance();  # consume `enum`
        self._advance();  # consumed name
        if self._eat(TokenType.LBrace) {
            depth3: int = 1;
            while depth3 > 0 and not self._is(TokenType.EOF) {
                if self._eat(TokenType.LBrace) {
                    depth3 = depth3 + 1;
                } elif self._eat(TokenType.RBrace) {
                    depth3 = depth3 - 1;
                } else {
                    self._advance();
                }
            }
        }
        return make_empty_stmt(self._span(start));
    }

    """Parse an expression statement."""
    def _parse_expr_stmt -> ASTNode {
        start: SourceRange = self._loc();
        expr: ASTNode = self._parse_expr(PREC_COMMA);
        self._semi();
        return make_expr_stmt(expr, self._span(start));
    }

    # ══════════════════════════════════════════════════════════════════════
    # 6.  Expression parsing (Pratt)
    # ══════════════════════════════════════════════════════════════════════

    """
    Pratt expression parser.
    Parses an expression whose binding power is >= `min_prec`.
    Call with min_prec=PREC_COMMA to parse any expression.
    Call with min_prec=PREC_ASSIGN to parse an assignment expression
    (i.e., no bare comma sequence).
    """
    def _parse_expr(min_prec: int) -> ASTNode {
        start: SourceRange = self._loc();
        left: ASTNode = self._parse_unary();

        running3: bool = True;
        while running3 {
            tt3: TokenType = self._tt();

            # Comma sequence (lowest precedence)
            if min_prec <= PREC_COMMA and tt3 == TokenType.Comma {
                self._advance();
                right2: ASTNode = self._parse_expr(PREC_ASSIGN);
                # build/extend a sequence
                if left.ntype == ASTNodeType.SequenceExpression {
                    left.expressions.append(right2);
                } else {
                    exprs2: list[ASTNode] = [left, right2];
                    left = make_sequence(exprs2, self._span(start));
                }
                continue;
            }

            # Yield expression (only inside a generator body — elsewhere `yield`
            # is a plain identifier per ES2015 §12.1, handled in _parse_primary).
            if min_prec <= PREC_YIELD
                and tt3 == TokenType.KwYield
                and self.in_generator_fn {
                self._advance();
                is_delegate: bool = False;
                if self._eat(TokenType.Star) {
                    is_delegate = True;
                }
                y_arg: ASTNode | None = None;
                # `yield * AssignmentExpression` (delegation) ALWAYS takes an
                # argument — the [no LineTerminator here] restriction sits between
                # `yield` and `*`, not between `*` and the operand, so a newline
                # before the operand does not trigger ASI (ES §14.4.14).  Plain
                # `yield` remains newline-sensitive (yields undefined on a newline).
                if is_delegate {
                    y_arg = self._parse_assignment_expr();
                } elif not self._is(TokenType.Semicolon)
                    and not self._cur.has_newline_before
                    and not self._is(TokenType.RBrace)
                    and not self._is(TokenType.EOF) {
                    y_arg = self._parse_assignment_expr();
                }
                left = make_yield(y_arg, is_delegate, self._span(start));
                continue;
            }

            # Conditional (ternary) — right-associative (ECMAScript §12.16).
            # Both branches are AssignmentExpressions: `a ? b : c ? d : e` is
            # `a ? b : (c ? d : e)` and `a ? b : c = v` is `a ? b : (c = v)`.
            # Parsing the alternate at PREC_COND left `= v` to the outer loop,
            # which built `(a ? b : c) = v` — a silent no-op (Babel's
            # `defined != null ? defined : defined = []` left `defined` unset and
            # @babel/types died loading).
            if min_prec <= PREC_COND
                and tt3 == TokenType.Question
                and self._peek.ttype != TokenType.Dot {
                self._advance();
                # ES §12.16 ConditionalExpression: both branches are
                # AssignmentExpression[+In] — `in` is ALWAYS allowed there, even inside a
                # for-loop initializer's [~In] context (`for (a ? '' in b : c;;)`). Clear
                # _no_in for the branches, restore for the (already-parsed) test.
                saved_no_in_cond: bool = self._no_in;
                self._no_in = False;
                cons2: ASTNode = self._parse_assignment_expr();
                self._expect(TokenType.Colon);
                alt2: ASTNode = self._parse_assignment_expr();
                self._no_in = saved_no_in_cond;
                left = make_conditional(left, cons2, alt2, self._span(start));
                continue;
            }

            # Assignment (right-associative)
            if min_prec <= PREC_ASSIGN and _is_assign_op(tt3) {
                op_tok: Token = self._advance();
                rhs2: ASTNode = self._parse_assignment_expr();
                left = make_assignment(_op_str(op_tok), left, rhs2, self._span(start));
                continue;
            }

            # When _no_in is set (for-loop init), suppress `in` as binary operator
            if self._no_in and tt3 == TokenType.KwIn {
                running3 = False;
                continue;
            }

            prec: int = _infix_prec(tt3);
            if prec == 0 or prec < min_prec {
                running3 = False;
                continue;
            }

            # `as` cast — TypeScript
            if tt3 == TokenType.KwAs {
                self._advance();
                self._skip_ts_type();
                continue;
            }

            op_tok2: Token = self._advance();
            # The right operand must collect every operator that binds strictly
            # tighter than `prec` (left-associative).  Exponentiation `**` is
            # right-associative, so it also collects operators at its own
            # precedence by recursing at `prec` rather than `prec + 1`.
            rhs_min: int = prec + 1;
            if tt3 == TokenType.StarStar {
                rhs_min = prec;
            }
            rhs3: ASTNode = self._parse_expr(rhs_min);

            # Classify as Binary vs Logical
            tt3_str: str = op_tok2.value;
            if tt3 == TokenType.AmpAmp
                or tt3 == TokenType.PipePipe
                or tt3 == TokenType.QuestionQuestion {
                left = make_logical(tt3_str, left, rhs3, self._span(start));
            } else {
                left = make_binary(tt3_str, left, rhs3, self._span(start));
            }
        }
        return left;
    }

    """Parse assignment expression (no comma sequence)."""
    def _parse_assignment_expr -> ASTNode {
        return self._parse_expr(PREC_ASSIGN);
    }

    """Parse a unary prefix expression."""
    def _parse_unary -> ASTNode {
        start: SourceRange = self._loc();
        tt5: TokenType = self._tt();

        # Await expression — only inside an async function body. Outside one,
        # `await` is a plain IdentifierReference (ES2017+) and falls through to
        # _parse_primary (mirrors the in_generator_fn handling of `yield`).
        if tt5 == TokenType.KwAwait and self.in_async_fn {
            self._advance();
            arg2: ASTNode = self._parse_unary();
            return make_await(arg2, self._span(start));
        }
        # `yield` in a generator's own parameter list is an early error
        # (ES2015 §14.4 — yield may not appear in generator FormalParameters).
        if tt5 == TokenType.KwYield and self.in_gen_params {
            self._errors.append(
                "SyntaxError: yield expression not allowed in generator parameter at line "
                    + str(self._cur.line)
            );
        }
        # Yield expression (prefix — highest-binding within assignment level).
        # Only a yield expression inside a generator body; outside one, `yield`
        # is a valid identifier (ES2015 §12.1) and falls through to _parse_primary.
        if tt5 == TokenType.KwYield and self.in_generator_fn {
            self._advance();
            is_delegate_y: bool = False;
            if self._eat(TokenType.Star) {
                is_delegate_y = True;
            }
            y_arg2: ASTNode | None = None;
            # `yield * AssignmentExpression` (delegation) ALWAYS takes an operand: the
            # [no LineTerminator here] restriction is between `yield` and `*`, not
            # between `*` and the operand, so a newline before it does not trigger
            # ASI (ES §14.4.14).
            if is_delegate_y {
                y_arg2 = self._parse_assignment_expr();
                # A plain YieldExpression's optional operand is an AssignmentExpression,
                # which cannot begin with a closing/separator token.  Treat `)`, `,`, `]`,
                # `:` (and `;`, `}`, EOF, newline) as "no operand" so `f(yield)`,
                # `[yield]`, `{k: yield}`, and `yield,` parse the bare yield expression.
            } elif not self._is(TokenType.Semicolon)
                and not self._is(TokenType.RBrace)
                and not self._is(TokenType.EOF)
                and not self._is(TokenType.RParen)
                and not self._is(TokenType.Comma)
                and not self._is(TokenType.RBracket)
                and not self._is(TokenType.Colon)
                and not self._cur.has_newline_before {
                y_arg2 = self._parse_assignment_expr();
            }
            return make_yield(y_arg2, is_delegate_y, self._span(start));
        }
        # Prefix ++ --
        if tt5 == TokenType.PlusPlus or tt5 == TokenType.MinusMinus {
            op_s: str = self._cur.value;
            self._advance();
            arg2b: ASTNode = self._parse_unary();
            return make_update(op_s, arg2b, True, self._span(start));
        }
        # typeof void delete ! ~ + -
        if tt5 == TokenType.KwTypeof {
            self._advance();
            arg3: ASTNode = self._parse_unary();
            return make_unary("typeof", arg3, True, self._span(start));
        }
        if tt5 == TokenType.KwVoid {
            self._advance();
            arg4: ASTNode = self._parse_unary();
            return make_unary("void", arg4, True, self._span(start));
        }
        if tt5 == TokenType.KwDelete {
            self._advance();
            arg5: ASTNode = self._parse_unary();
            return make_unary("delete", arg5, True, self._span(start));
        }
        if tt5 == TokenType.Bang {
            self._advance();
            arg6: ASTNode = self._parse_unary();
            return make_unary("!", arg6, True, self._span(start));
        }
        if tt5 == TokenType.Tilde {
            self._advance();
            arg7: ASTNode = self._parse_unary();
            return make_unary("~", arg7, True, self._span(start));
        }
        if tt5 == TokenType.Plus {
            self._advance();
            arg8: ASTNode = self._parse_unary();
            return make_unary("+", arg8, True, self._span(start));
        }
        if tt5 == TokenType.Minus {
            self._advance();
            arg9: ASTNode = self._parse_unary();
            return make_unary("-", arg9, True, self._span(start));
        }

        base: ASTNode = self._parse_postfix();
        return base;
    }

    """Parse postfix ++ / -- (after a left-hand-side expression)."""
    def _parse_postfix -> ASTNode {
        start: SourceRange = self._loc();
        base2: ASTNode = self._parse_call_member();
        if not self._cur.has_newline_before {
            if self._is(TokenType.PlusPlus) {
                op_post: str = "++";
                self._advance();
                return make_update(op_post, base2, False, self._span(start));
            }
            if self._is(TokenType.MinusMinus) {
                op_post2: str = "--";
                self._advance();
                return make_update(op_post2, base2, False, self._span(start));
            }
        }
        return base2;
    }

    """Parse call/member/optional-chain expressions."""
    def _parse_call_member -> ASTNode {
        start: SourceRange = self._loc();
        # `new.target` / `import.meta`
        if self._is(TokenType.KwNew) {
            # peek to see if it's `new.target` or actual `new Foo()`
            if self._peek.ttype == TokenType.Dot {
                self._advance();  # new
                self._advance();  # .
                prop_name: str = self._cur.value;
                self._advance();  # target
                nt_meta: ASTNode = make_meta_property(
                    "new", prop_name, self._span(start)
                );
                # `new.target` is a MemberExpression — allow trailing member/call/optional-chain
                # suffixes: `new.target?.()`, `new.target.foo`, etc. (test262
                # optional-chaining/new-target-optional-call).
                return self._parse_member_tail(nt_meta, start);
            }
            # After `new Ctor(args)`, any trailing `.prop` / `[idx]` / `(args)`
            # suffixes form a call/member chain on the constructed instance —
            # e.g. `new Error('oops').toString()` = `(new Error('oops')).toString()`
            nd_new: ASTNode = self._parse_new_expr();
            return self._parse_member_tail(nd_new, start);
        }
        if self._is(TokenType.KwImport) and self._peek.ttype == TokenType.Dot {
            self._advance();  # import
            self._advance();  # .
            meta_prop: str = self._cur.value;
            # `import.source(...)` / `import.defer(...)` — source-phase and
            # defer-phase dynamic import (Stage-3 proposals). These are ImportCall
            # forms with a phase, NOT a member access on `import`. Recognize only
            # when directly followed by `(` so `import.meta` still parses as a
            # MetaProperty. The phase is stashed on the Call node's `kind`.
            if (meta_prop == "source" or meta_prop == "defer")
                and self._peek.ttype == TokenType.LParen {
                self._advance();  # source / defer
                phase_callee: ASTNode = make_identifier("import", self._span(start));
                phase_args: list[ASTNode] = self._parse_args();
                phase_call: ASTNode = make_call(
                    phase_callee, phase_args, self._span(start)
                );
                phase_call.kind = meta_prop;
                return self._parse_member_tail(phase_call, start);
            }
            self._advance();
            im_nd: ASTNode = make_meta_property("import", meta_prop, self._span(start));
            return self._parse_member_tail(im_nd, start);
        }
        # Dynamic import(): `import("./foo.js")` → CallExpression with callee=Identifier("import")
        # ImportCall AssignmentExpressions are [+In] (ES §13.3.10): `in` is allowed even
        # when the call appears in a for-loop initializer (_no_in), e.g.
        # `for (p = import(m, 'k' in {} || undefined); …)`.
        if self._is(TokenType.KwImport) and self._peek.ttype == TokenType.LParen {
            self._advance();  # consume `import` keyword
            imp_callee: ASTNode = make_identifier("import", self._span(start));
            saved_no_in_imp: bool = self._no_in;
            self._no_in = False;
            imp_args: list[ASTNode] = self._parse_args();
            self._no_in = saved_no_in_imp;
            imp_call: ASTNode = make_call(imp_callee, imp_args, self._span(start));
            return self._parse_member_tail(imp_call, start);
        }

        nd: ASTNode = self._parse_primary();
        return self._parse_member_tail(nd, start);
    }

    """
    Parse a property key after `.` in member access.
    Disambiguates numeric-literal `..prop` (e.g. `0..toString(10)`) from `.prop`.
    """
    def _parse_member_dot_property(object_expr: ASTNode) -> ASTNode {
        self._advance();  # consume first `.`
        # N7: numeric literal + member access requires a second dot before the name
        if object_expr.ntype == ASTNodeType.Literal
            and object_expr.kind == "number"
            and self._is(TokenType.Dot) {
            self._advance();
        }
        return self._parse_prop_key_inner(False);
    }

    """Parse member/call/template suffix starting from `nd`."""
    def _parse_member_tail(nd: ASTNode, start: SourceRange) -> ASTNode {
        running4: bool = True;
        while running4 {
            tt6: TokenType = self._tt();

            # .prop
            if tt6 == TokenType.Dot {
                prop_id: ASTNode = self._parse_member_dot_property(nd);
                nd = make_member(nd, prop_id, False, self._span(start));
            }
            # [expr]
            elif tt6 == TokenType.LBracket {
                self._advance();
                prop_expr: ASTNode = self._parse_expr(PREC_COMMA);
                self._expect(TokenType.RBracket);
                nd = make_member(nd, prop_expr, True, self._span(start));
            }
            # (args)
            elif tt6 == TokenType.LParen {
                args: list[ASTNode] = self._parse_args();
                nd = make_call(nd, args, self._span(start));
            }
            # ?.
            elif tt6 == TokenType.QuestionDot {
                self._advance();
                if self._is(TokenType.LBracket) {
                    self._advance();
                    chain_prop: ASTNode = self._parse_expr(PREC_COMMA);
                    self._expect(TokenType.RBracket);
                    nd = make_optional_chain(nd, chain_prop, True, self._span(start));
                } elif self._is(TokenType.LParen) {
                    chain_args: list[ASTNode] = self._parse_args();
                    chain_call: ASTNode = make_optional_chain(
                        nd, make_identifier("()", ZERO_RANGE), False, self._span(start)
                    );
                    chain_call.arguments = chain_args;
                    nd = chain_call;
                } else {
                    chain_id: ASTNode = make_identifier(self._cur.value, self._loc());
                    self._advance();
                    nd = make_optional_chain(nd, chain_id, False, self._span(start));
                }
            }
            # Tagged template: `nd`...`
            elif tt6 == TokenType.TemplateLiteral or tt6 == TokenType.TemplateHead {
                tmpl: ASTNode = self._parse_template();
                nd = make_tagged_template(nd, tmpl, self._span(start));
            }
            # TS: skip type args on call  `fn<T>()`
            elif tt6 == TokenType.Lt {
                # Ambiguous: might be `<` comparison; we do a quick lookahead
                # heuristic — if we see identifier followed by `>` or `,` treat
                # as generic.  Otherwise stop.
                # (This is a simplified heuristic, not full TS lookahead.)
                running4 = False;
            } else {
                running4 = False;
            }
        }
        return nd;
    }

    """Parse `new Expr(args)`, possibly chained."""
    def _parse_new_expr -> ASTNode {
        start: SourceRange = self._loc();
        self._expect(TokenType.KwNew);
        # Allow chained: `new new Foo()()`
        callee: ASTNode;
        if self._is(TokenType.KwNew) {
            callee = self._parse_new_expr();
        } elif self._is(TokenType.KwImport) and self._peek.ttype == TokenType.Dot {
            # `new import.meta()` / `new import.meta.x()`: the constructor expression is the
            # `import.meta` MetaProperty. _parse_primary does NOT recognize it (that lives in
            # _parse_call_member), so handle it here — otherwise `import` is mis-parsed as a
            # bare identifier and yields a spurious ReferenceError instead of the correct
            # "not a constructor" TypeError (test262 import.meta/import-meta-is-an-ordinary-object).
            self._advance();  # import
            self._advance();  # .
            nm_prop: str = self._cur.value;
            self._advance();  # meta
            callee = make_meta_property("import", nm_prop, self._span(start));
            running_meta: bool = True;
            while running_meta {
                if self._is(TokenType.Dot) {
                    prop_m: ASTNode = self._parse_member_dot_property(callee);
                    callee = make_member(callee, prop_m, False, self._span(start));
                } elif self._is(TokenType.LBracket) {
                    self._advance();
                    idx_m: ASTNode = self._parse_expr(PREC_COMMA);
                    self._expect(TokenType.RBracket);
                    callee = make_member(callee, idx_m, True, self._span(start));
                } else {
                    running_meta = False;
                }
            }
            args_m: list[ASTNode] = [];
            if self._is(TokenType.LParen) {
                args_m = self._parse_args();
            }
            return make_new(callee, args_m, self._span(start));
        } else {
            callee = self._parse_primary();
            # Only allow member accesses (.prop / [idx]) on the callee —
            # NOT call expressions (args).  `(args)` belongs to the
            # NewExpression itself, not to a call wrapping the callee.
            running_new: bool = True;
            while running_new {
                if self._is(TokenType.Dot) {
                    prop_new: ASTNode = self._parse_member_dot_property(callee);
                    callee = make_member(callee, prop_new, False, self._span(start));
                } elif self._is(TokenType.LBracket) {
                    self._advance();
                    idx_new: ASTNode = self._parse_expr(PREC_COMMA);
                    self._expect(TokenType.RBracket);
                    callee = make_member(callee, idx_new, True, self._span(start));
                } else {
                    running_new = False;
                }
            }
        }
        args2: list[ASTNode] = [];
        if self._is(TokenType.LParen) {
            args2 = self._parse_args();
        }
        return make_new(callee, args2, self._span(start));
    }

    """Parse left-hand-side expression (member/call, no unary/binary)."""
    def _parse_left_hand_expr -> ASTNode {
        start: SourceRange = self._loc();
        obj2: ASTNode = self._parse_primary();
        return self._parse_member_tail(obj2, start);
    }

    """Parse argument list `( expr [, expr]* )`."""
    def _parse_args -> list[ASTNode] {
        self._expect(TokenType.LParen);
        # Call arguments are AssignmentExpressions inside `(...)`, where the `in`
        # operator is always permitted — the for-init `[NoIn]` restriction does not
        # reach into a parenthesized argument list (matches array/object literals).
        saved_ni_args: bool = self._no_in;
        self._no_in = False;
        args3: list[ASTNode] = [];
        while not self._is(TokenType.RParen) and not self._is(TokenType.EOF) {
            if self._is(TokenType.DotDotDot) {
                sp_start: SourceRange = self._loc();
                self._advance();
                sp_arg: ASTNode = self._parse_assignment_expr();
                args3.append(make_spread(sp_arg, self._span(sp_start)));
            } else {
                args3.append(self._parse_assignment_expr());
            }
            self._eat(TokenType.Comma);
        }
        self._expect(TokenType.RParen);
        self._no_in = saved_ni_args;
        return args3;
    }

    """
    Parse primary expressions:
    literals, identifiers, `this`, `super`, grouping, array/object literals,
    function/class/arrow expressions, template literals.
    """
    def _parse_primary -> ASTNode {
        start: SourceRange = self._loc();
        tt7: TokenType = self._tt();

        # Literals
        if tt7 == TokenType.NumericLiteral {
            v2: str = self._cur.value;
            r1: str = self._cur.value;
            self._advance();
            lit_num: ASTNode = make_literal(v2, r1, self._span(start));
            lit_num.kind = "number";
            return lit_num;
        }
        if tt7 == TokenType.BigIntLiteral {
            # BigInt literal: the lexer includes the trailing 'n' suffix in the
            # raw value (e.g. "7n", "18446744073709551615n").  Strip the suffix
            # so the compiler receives a clean decimal string.
            raw_bi: str = self._cur.value;
            self._advance();
            bi_len: int = len(raw_bi);
            bi_val: str = "";
            bi_i: int = 0;
            bi_end: int = bi_len;
            if bi_len > 0 and raw_bi[bi_len - 1] == "n" {
                bi_end = bi_len - 1;
            }
            while bi_i < bi_end {
                bi_val = bi_val + raw_bi[bi_i];
                bi_i = bi_i + 1;
            }
            lit_bi: ASTNode = make_literal(bi_val, raw_bi, self._span(start));
            lit_bi.kind = "bigint";
            return lit_bi;
        }
        if tt7 == TokenType.StringLiteral {
            v3: str = self._cur.value;
            r2: str = self._cur.value;
            self._advance();
            lit_str: ASTNode = make_literal(v3, r2, self._span(start));
            lit_str.kind = "string";
            return lit_str;
        }
        if tt7 == TokenType.KwTrue {
            self._advance();
            return make_literal("true", "true", self._span(start));
        }
        if tt7 == TokenType.KwFalse {
            self._advance();
            return make_literal("false", "false", self._span(start));
        }
        if tt7 == TokenType.KwNull {
            self._advance();
            return make_literal("null", "null", self._span(start));
        }
        if tt7 == TokenType.KwUndefined {
            self._advance();
            return make_identifier("undefined", self._span(start));
        }
        if tt7 == TokenType.RegExpLiteral {
            v4: str = self._cur.value;
            self._advance();
            re_lit: ASTNode = make_literal(v4, v4, self._span(start));
            re_lit.kind = "regexp";
            return re_lit;
        }

        # this / super
        if tt7 == TokenType.KwThis {
            self._advance();
            return make_identifier("this", self._span(start));
        }
        if tt7 == TokenType.KwSuper {
            self._advance();
            return make_identifier("super", self._span(start));
        }

        # Template literal
        if tt7 == TokenType.TemplateLiteral or tt7 == TokenType.TemplateHead {
            return self._parse_template();
        }

        # Array literal
        if tt7 == TokenType.LBracket {
            return self._parse_array_expr();
        }

        # Object literal
        if tt7 == TokenType.LBrace {
            return self._parse_object_expr();
        }

        # Grouping, arrow, or destructuring
        if tt7 == TokenType.LParen {
            return self._parse_paren_or_arrow(start);
        }

        # Decorated class expression: `@dec class {}` / `@a @b.c class X {}`
        # (DecoratorList opt before `class` in ClassExpression).  Decorators are
        # parsed and discarded; the class expression is then parsed normally.
        if tt7 == TokenType.At {
            self._skip_decorators();
            return self._parse_class_expr();
        }

        # class expression
        if tt7 == TokenType.KwClass {
            return self._parse_class_expr();
        }

        # function expression / async arrow
        if tt7 == TokenType.KwFunction {
            return self._parse_function_expr(False);
        }
        if tt7 == TokenType.KwAsync {
            # `async [no LineTerminator here] function` — a newline makes `async` a
            # plain identifier, not an async function expression (ES §15.8).
            if self._peek.ttype == TokenType.KwFunction
                and not self._peek.has_newline_before {
                return self._parse_function_expr(True);
            }
            # async arrow: `async x => ...` or `async (params) => ...`.
            # `async [no LineTerminator here] ArrowFormalParameters` (ES §15.8): a
            # newline between `async` and the params means this is NOT an async
            # arrow — `async` is a plain identifier and the rest parses separately
            # (`async\n x => {}` → the identifier `async`, then `x => {}`).
            if (
                self._peek.ttype == TokenType.Identifier
                or self._peek.ttype == TokenType.LParen
            )
                and not self._peek.has_newline_before {
                return self._parse_async_arrow();
            }
            # otherwise fall through as identifier
        }

        # Identifier (including keyword-as-identifier like `get`, `set`, etc.)
        if tt7 == TokenType.Identifier
            or tt7 == TokenType.KwGet
            or tt7 == TokenType.KwSet
            or tt7 == TokenType.KwStatic
            or tt7 == TokenType.KwFrom
            or tt7 == TokenType.KwAs
            or tt7 == TokenType.KwOf
            or tt7 == TokenType.KwAsync
            or tt7 == TokenType.KwLet
            or (tt7 == TokenType.KwYield and not self.in_generator_fn)
            or (tt7 == TokenType.KwAwait and not self.in_async_fn) {
            # `let` as an IDENTIFIER (non-strict) — e.g. `for (let in obj)`, `let = 3`. A strict
            # context makes it a reserved word (rejected by the strict early-error checks).
            name2: str = self._cur.value;
            self._advance();
            ident_node: ASTNode = make_identifier(name2, self._span(start));
            # Check for arrow function: `x => ...`
            if self._is(TokenType.Arrow) {
                self._advance();
                arrow_body: ASTNode = self._parse_arrow_body();
                p_list: list[ASTNode] = [ident_node];
                return make_arrow(
                    p_list,
                    arrow_body,
                    self._span(start),
                    False,
                    arrow_body.ntype != ASTNodeType.BlockStatement
                );
            }
            # TypeScript non-null assertion: `expr!`
            # (just ignore the `!` if it's right after identifier with no space)
            return ident_node;
        }

        # Private name as a primary expression — only valid as the LHS of
        # `#member in obj` (ES §13.10 RelationalExpression).  Parse it as an
        # Identifier carrying the `#name`; the compiler recognises the private-in
        # form and rejects a bare `#x` used anywhere else.
        if tt7 == TokenType.PrivateName {
            pn_prim: str = self._cur.value;
            self._advance();
            return make_identifier(pn_prim, self._span(start));
        }

        # Fallback: an unexpected token where a primary expression was required.
        # (B8) Record a hard parse error so `_PARSE_HAD_ERRORS` is set and
        # eval/Function throw a SyntaxError — BUT only for punctuators / operators /
        # EOF. A *keyword* token (TokenType >= KwVar) reaching here is almost always
        # a contextual keyword used as a plain identifier (`let`, `of`, `async`,
        # `yield`, `await`, `get`, …) — e.g. `for (var let of x)` — valid in sloppy
        # mode, so keep the lenient identifier-placeholder behaviour for those to
        # avoid false-positive parse errors.
        fb_tt: TokenType = self._tt();
        if fb_tt.value < TokenType.KwVar.value {
            self._errors.append(
                "SyntaxError: Unexpected token "
                    + str(fb_tt)
                    + " ("
                    + self._cur.value
                    + ") at line "
                    + str(self._cur.line)
            );
        }
        err_val: str = self._cur.value;
        # Do not advance past EOF (would loop); consume a real token otherwise.
        if fb_tt != TokenType.EOF {
            self._advance();
        }
        return make_identifier(err_val, self._span(start));
    }

    """Parse a template literal `` `...${...}...` ``."""
    def _parse_template -> ASTNode {
        start: SourceRange = self._loc();
        quasis_list: list[str] = [];
        exprs_list: list[ASTNode] = [];

        if self._is(TokenType.TemplateLiteral) {
            v5: str = self._cur.value;
            quasis_list.append(v5);
            self._advance();
            return make_template_literal(quasis_list, exprs_list, self._span(start));
        }

        # TemplateHead: `head${
        if self._is(TokenType.TemplateHead) {
            quasis_list.append(self._cur.value);
            self._advance();
            running5: bool = True;
            while running5 {
                exprs_list.append(self._parse_expr(PREC_COMMA));
                if self._is(TokenType.TemplateMiddle) {
                    quasis_list.append(self._cur.value);
                    self._advance();
                } elif self._is(TokenType.TemplateTail) {
                    quasis_list.append(self._cur.value);
                    self._advance();
                    running5 = False;
                } else {
                    running5 = False;
                }
            }
        }
        return make_template_literal(quasis_list, exprs_list, self._span(start));
    }

    """Parse an array literal `[a, ...b, c]`."""
    def _parse_array_expr -> ASTNode {
        start: SourceRange = self._loc();
        self._expect(TokenType.LBracket);
        # The `[NoIn]` for-head restriction does NOT propagate into a bracketed
        # sub-expression: `for ([ x = a in b ] of …)` allows `in` inside `[...]`
        # (ES §13.7 — NoIn is only on the top-level for-head). Re-enable it here.
        saved_ni_arr: bool = self._no_in;
        self._no_in = False;
        elems: list[ASTNode] = [];
        while not self._is(TokenType.RBracket) and not self._is(TokenType.EOF) {
            if self._is(TokenType.Comma) {
                elems.append(make_elision(self._loc()));
                self._advance();
            } elif self._is(TokenType.DotDotDot) {
                sp2_start: SourceRange = self._loc();
                self._advance();
                sp2_arg: ASTNode = self._parse_assignment_expr();
                elems.append(make_spread(sp2_arg, self._span(sp2_start)));
                self._eat(TokenType.Comma);
            } else {
                elems.append(self._parse_assignment_expr());
                self._eat(TokenType.Comma);
            }
        }
        self._expect(TokenType.RBracket);
        self._no_in = saved_ni_arr;
        return make_array(elems, self._span(start));
    }

    """Parse an object literal `{ key: val, [comp]: val, shorthand, ...spread }`."""
    def _parse_object_expr -> ASTNode {
        start: SourceRange = self._loc();
        self._expect(TokenType.LBrace);
        # NoIn (for-head) does not propagate into a braced sub-expression:
        # `for ({ p = a in b } of …)` allows `in` inside `{...}`.
        saved_ni_obj: bool = self._no_in;
        self._no_in = False;
        props: list[ASTNode] = [];
        while not self._is(TokenType.RBrace) and not self._is(TokenType.EOF) {
            p: ASTNode = self._parse_object_prop();
            props.append(p);
            self._eat(TokenType.Comma);
        }
        self._expect(TokenType.RBrace);
        return make_object(props, self._span(start));
    }

    """Parse a single object property."""
    def _parse_object_prop -> ASTNode {
        start: SourceRange = self._loc();

        # Spread: `...expr`
        if self._is(TokenType.DotDotDot) {
            self._advance();
            sp3_arg: ASTNode = self._parse_assignment_expr();
            return make_spread(sp3_arg, self._span(start));
        }

        is_async2: bool = False;
        is_gen2: bool = False;
        kind2: str = "init";

        # `async` is a method modifier only when a property name follows. Before `(`
        # it IS the name — `{ async(...args) {} }` (Babel's gensync-utils/async.js) —
        # and before `=` it is a shorthand-with-default (`({ async = 1 } = o)`).
        if self._is(TokenType.KwAsync)
            and self._peek.ttype != TokenType.Colon
            and self._peek.ttype != TokenType.Comma
            and self._peek.ttype != TokenType.RBrace
            and self._peek.ttype != TokenType.LParen
            and self._peek.ttype != TokenType.Eq {
            is_async2 = True;
            self._advance();
            if self._eat(TokenType.Star) {
                is_gen2 = True;
            }
        } elif self._eat(TokenType.Star) {
            is_gen2 = True;
        }

        if (self._is(TokenType.KwGet) or self._is(TokenType.KwSet))
            and self._peek.ttype != TokenType.Colon
            and self._peek.ttype != TokenType.Comma
            and self._peek.ttype != TokenType.RBrace
            and self._peek.ttype != TokenType.LParen {
            kind2 = self._cur.value;
            self._advance();
        }

        computed2: bool = False;
        if self._eat(TokenType.LBracket) {
            # Computed key
            computed2 = True;
        }
        prop_key2: ASTNode = self._parse_prop_key_inner(computed2);
        if computed2 {
            self._expect(TokenType.RBracket);
        }

        # Method shorthand: `{ key(params) { } }`
        if self._is(TokenType.LParen) {
            saved_gp_om: bool = self.in_gen_params;
            if is_gen2 {
                self.in_gen_params = True;
            }
            p2_list: list[ASTNode] = self._parse_params();
            self.in_gen_params = saved_gp_om;
            if self._is(TokenType.Colon) {
                self._advance();
                self._skip_ts_type();
            }
            saved_gen_om: bool = self.in_generator_fn;
            saved_async_om: bool = self.in_async_fn;
            self.in_generator_fn = is_gen2;
            self.in_async_fn = is_async2;
            m_body: ASTNode = self._parse_block();
            self.in_generator_fn = saved_gen_om;
            self.in_async_fn = saved_async_om;
            fn2: ASTNode = make_function_expr(
                None, p2_list, m_body, self._span(start), is_async2, is_gen2
            );
            fn2.is_method = True;  # concise object method/accessor — no own `prototype`
            return make_property(
                prop_key2, fn2, kind2, False, computed2, self._span(start)
            );
        }

        # Shorthand `{ x }` or `{ x = default }`
        if kind2 == "init" and not computed2 and not self._is(TokenType.Colon) {
            val2: ASTNode = prop_key2;
            if self._eat(TokenType.Eq) {
                dflt: ASTNode = self._parse_assignment_expr();
                val2 = make_assignment_pattern(prop_key2, dflt, self._span(start));
            }
            return make_property(
                prop_key2, val2, "init", True, False, self._span(start)
            );
        }

        # Normal `{ key: value }`
        self._expect(TokenType.Colon);
        prop_val2: ASTNode = self._parse_assignment_expr();
        return make_property(
            prop_key2, prop_val2, kind2, False, computed2, self._span(start)
        );
    }

    """Parse an object property key (identifier, string, number, computed)."""
    def _parse_prop_key -> ASTNode {
        computed3: bool = False;
        if self._eat(TokenType.LBracket) {
            computed3 = True;
        }
        k: ASTNode = self._parse_prop_key_inner(computed3);
        if computed3 {
            self._expect(TokenType.RBracket);
        }
        return k;
    }

    """Parse the inner part of a property key (after `[` already consumed for computed)."""
    def _parse_prop_key_inner(computed3: bool) -> ASTNode {
        start: SourceRange = self._loc();
        if computed3 {
            # A computed key `[AssignmentExpression]` is a fresh expression context:
            # the [NoIn] restriction from an enclosing for-loop header (`_no_in`)
            # does NOT apply inside the brackets, so `in` is a valid operator here
            # (e.g. `for (C = class { static get ['x' in obj]() {} };;)`). Clear and
            # restore _no_in around the key, mirroring array/object/args parsing.
            saved_ni_key: bool = self._no_in;
            self._no_in = False;
            key_expr: ASTNode = self._parse_assignment_expr();
            self._no_in = saved_ni_key;
            return key_expr;
        }
        tt8: TokenType = self._tt();
        if tt8 == TokenType.StringLiteral {
            v6: str = self._cur.value;
            self._advance();
            lit_s8: ASTNode = make_literal(v6, v6, self._span(start));
            lit_s8.kind = "string";
            return lit_s8;
        }
        if tt8 == TokenType.NumericLiteral {
            v7: str = self._cur.value;
            self._advance();
            lit_n8: ASTNode = make_literal(v7, v7, self._span(start));
            lit_n8.kind = "number";
            return lit_n8;
        }
        if tt8 == TokenType.PrivateName {
            pn_name: str = self._cur.value;  # includes # prefix
            self._advance();
            return make_identifier(pn_name, self._span(start));
        }
        # Keyword used as property name (e.g. `{ new: fn }`)
        name3: str = self._cur.value;
        self._advance();
        return make_identifier(name3, self._span(start));
    }

    """
    Reinterpret an expression that was speculatively parsed as an arrow-function
    parameter into the equivalent binding pattern.  Arrow params are parsed as
    assignment expressions before `=>` is confirmed, so `([a, b] = init)` arrives
    as AssignmentExpression(left=ArrayExpression, right=init).  This converts
    ArrayExpression→ArrayPattern, ObjectExpression→ObjectPattern,
    SpreadElement→RestElement, and AssignmentExpression(op="=")→AssignmentPattern
    recursively, so the existing destructured-parameter machinery in the compiler
    handles arrow patterns uniformly with function-declaration patterns.
    """
    def _expr_to_pattern(nd: ASTNode) -> ASTNode {
        if nd.ntype == ASTNodeType.ArrayExpression {
            conv_elems: list[ASTNode] = [];
            for ce in nd.elements {
                conv_elems.append(self._expr_to_pattern(ce));
            }
            return make_array_pattern(conv_elems, nd.loc);
        } elif nd.ntype == ASTNodeType.ObjectExpression {
            conv_props: list[ASTNode] = [];
            for cp in nd.properties {
                if cp.ntype == ASTNodeType.SpreadElement and cp.argument is not None {
                    conv_props.append(
                        make_rest(self._expr_to_pattern(cp.argument), cp.loc)
                    );
                } elif cp.ntype == ASTNodeType.Property and cp.key is not None {
                    new_val: ASTNode = cp.key;
                    if cp.expression is not None {
                        new_val = self._expr_to_pattern(cp.expression);
                    }
                    conv_props.append(
                        make_property(
                            cp.key, new_val, "init", cp.shorthand, cp.computed, cp.loc
                        )
                    );
                } else {
                    conv_props.append(self._expr_to_pattern(cp));
                }
            }
            return make_object_pattern(conv_props, nd.loc);
        } elif nd.ntype == ASTNodeType.SpreadElement and nd.argument is not None {
            return make_rest(self._expr_to_pattern(nd.argument), nd.loc);
        } elif nd.ntype == ASTNodeType.AssignmentExpression
            and nd.operator == "="
            and nd.left is not None
            and nd.right is not None {
            left_pat: ASTNode = self._expr_to_pattern(nd.left);
            return make_assignment_pattern(left_pat, nd.right, nd.loc);
        }
        # Identifiers and any other node (member exprs, etc.) pass through unchanged.
        return nd;
    }

    """
    Reinterpret a list of speculatively-parsed arrow params into binding patterns.
    RestElement / AssignmentPattern / Identifier nodes pass through `_expr_to_pattern`
    unchanged; ArrayExpression / ObjectExpression / AssignmentExpression are converted.
    """
    def _finalize_arrow_params(items: list[ASTNode]) -> list[ASTNode] {
        out_params: list[ASTNode] = [];
        for ip in items {
            out_params.append(self._expr_to_pattern(ip));
        }
        return out_params;
    }

    """Parse parenthesised expression, arrow function, or destructuring."""
    def _parse_paren_or_arrow(start: SourceRange) -> ASTNode {
        self._expect(TokenType.LParen);
        # Empty parens → must be arrow: `() => ...`
        if self._is(TokenType.RParen) {
            self._advance();
            self._expect(TokenType.Arrow);
            ab2: ASTNode = self._parse_arrow_body();
            return make_arrow(
                [],
                ab2,
                self._span(start),
                False,
                ab2.ntype != ASTNodeType.BlockStatement
            );
        }

        # Parse contents: collect expressions/patterns
        items: list[ASTNode] = [];
        has_rest2: bool = False;
        while not self._is(TokenType.RParen) and not self._is(TokenType.EOF) {
            if self._is(TokenType.DotDotDot) {
                has_rest2 = True;
                rest_start: SourceRange = self._loc();
                self._advance();
                rest_id2: ASTNode = self._parse_binding_pattern();
                items.append(make_rest(rest_id2, self._span(rest_start)));
                break;
            }
            items.append(self._parse_assignment_expr());
            self._eat(TokenType.Comma);
        }
        self._expect(TokenType.RParen);

        # TS type annotation on arrow return: `(params): ReturnType => body`
        # Guard: only consume `: <type>` when we can confirm `=>` follows.
        # We do NOT speculatively skip TS types based on peek heuristics —
        # bundled/transpiled JS never has TS return-type annotations, and any
        # heuristic here risks consuming ternary `:` as a type separator.
        # Instead: if we see `:` here and the next token is NOT `=>`, assume
        # this `:` belongs to an enclosing ternary and leave it unconsumed.
        # (Arrow functions that have a TS return type are handled below by
        # checking `=>` directly; the `: Type` is simply ignored.)

        # Arrow function?
        if self._is(TokenType.Arrow) {
            self._advance();
            ab3: ASTNode = self._parse_arrow_body();
            # Reinterpret speculatively-parsed expression items as binding patterns.
            # The parser parsed `(a = 99)` / `([a, b] = init)` / `({x})` as
            # expressions; after confirming `=>` each item is definitively a
            # parameter, so convert ArrayExpression→ArrayPattern, etc.
            arrow_params: list[ASTNode] = self._finalize_arrow_params(items);
            return make_arrow(
                arrow_params,
                ab3,
                self._span(start),
                False,
                ab3.ntype != ASTNodeType.BlockStatement
            );
        }

        # Plain grouped expression: mark the node as parenthesized so downstream
        # consumers can tell a CoverParenthesizedExpression from a bare form. Per
        # ES §13.15.2, `(x) = fn` must NOT NamedEvaluation `fn` (IsIdentifierRef is
        # false for a parenthesized LHS), unlike bare `x = fn`.
        if len(items) == 1 {
            items[0].parenthesized = True;
            return items[0];
        }
        return make_sequence(items, self._span(start));
    }

    """Parse the right-hand side of an arrow function."""
    def _parse_arrow_body -> ASTNode {
        # An arrow function does not propagate the generator's [Yield] context
        # into its body (ES2015 §14.2 — ConciseBody is [~Yield]). So `yield`
        # inside an arrow nested in a generator is NOT a yield expression.
        saved_gen_ab: bool = self.in_generator_fn;
        self.in_generator_fn = False;
        is_block_ab: bool = self._is(TokenType.LBrace);
        body_ab: ASTNode = self._parse_block()
            if is_block_ab
            else self._parse_assignment_expr();
        self.in_generator_fn = saved_gen_ab;
        return body_ab;
    }

    """Parse a function expression."""
    def _parse_function_expr(is_async3: bool) -> ASTNode {
        start: SourceRange = self._loc();
        if is_async3 {
            self._advance();
        }  # async
        self._expect(TokenType.KwFunction);
        is_gen3: bool = False;
        if self._eat(TokenType.Star) {
            is_gen3 = True;
        }
        if self._is(TokenType.Lt) {
            self._advance();
            self._skip_ts_generics();
        }
        fe_id: ASTNode | None = None;
        # The BindingIdentifier (name) of a function EXPRESSION is governed by the
        # [Yield]/[Await] context of the function BEING defined, not the enclosing
        # one (ES §15.2.1): a non-generator `function yield(){}` nested inside a
        # generator is legal (non-strict) because the inner fn's [Yield] is false.
        # So gate on `is_gen3`/`is_async3`, not the enclosing in_generator_fn flags.
        if self._is(TokenType.Identifier)
            or self._is(TokenType.KwGet)
            or self._is(TokenType.KwSet)
            or self._is(TokenType.KwStatic)
            or self._is(TokenType.KwFrom)
            or self._is(TokenType.KwAs)
            or self._is(TokenType.KwOf)
            or self._is(TokenType.KwAsync)
            or (self._is(TokenType.KwYield) and not is_gen3)
            or (self._is(TokenType.KwAwait) and not is_async3) {
            fe_id = make_identifier(self._cur.value, self._loc());
            self._advance();
        }
        # `await`/`yield` are operators only inside an async/generator's OWN body/params;
        # set the per-function [Await]/[Yield] context BEFORE parsing this function's params
        # so a nested NON-generator function's param default `yield` (or non-async `await`)
        # is an ordinary identifier referencing an outer binding — even when this function
        # expression is lexically inside an enclosing generator/async (test262
        # param-dflt-yield-non-strict). in_gen_params still forbids `yield` in a GENERATOR's
        # own params (an early error).
        saved_gen_fe: bool = self.in_generator_fn;
        saved_async_fe: bool = self.in_async_fn;
        self.in_generator_fn = is_gen3;
        self.in_async_fn = is_async3;
        saved_gp_fe: bool = self.in_gen_params;
        if is_gen3 {
            self.in_gen_params = True;
        }
        fe_params: list[ASTNode] = self._parse_params();
        self.in_gen_params = saved_gp_fe;
        if self._is(TokenType.Colon) {
            self._advance();
            self._skip_ts_type();
        }
        fe_body: ASTNode = self._parse_block();
        self.in_generator_fn = saved_gen_fe;
        self.in_async_fn = saved_async_fe;
        return make_function_expr(
            fe_id, fe_params, fe_body, self._span(start), is_async3, is_gen3
        );
    }

    """Parse an async arrow function `async x => ...` or `async (params) => ...`."""
    def _parse_async_arrow -> ASTNode {
        start: SourceRange = self._loc();
        self._advance();  # consume `async`
        aa_params: list[ASTNode] = [];
        if self._is(TokenType.LParen) {
            # CoverCallExpressionAndAsyncArrowHead (ES §13.3): `async(...)` is an async
            # arrow head only when `=>` follows on the same line; otherwise it is a CALL
            # of a binding named `async` (`const async = f; async(x)`). Parse the list
            # as call arguments (spreads anywhere) and reinterpret it as parameters
            # once `=>` is seen — the arrow-only parse printed "Expected token 43 but
            # got 31" and dropped the statement.
            aa_args: list[ASTNode] = self._parse_args();
            if not self._is(TokenType.Arrow) or self._cur.has_newline_before {
                return make_call(
                    make_identifier("async", start), aa_args, self._span(start)
                );
            }
            aa_params = self._finalize_arrow_params(aa_args);
        } else {
            aa_params.append(make_identifier(self._cur.value, self._loc()));
            self._advance();
        }
        if self._is(TokenType.Colon) {
            self._advance();
            self._skip_ts_type();
        }
        self._expect(TokenType.Arrow);
        # Async arrow: `await` is an operator inside its body.
        saved_async_aa: bool = self.in_async_fn;
        self.in_async_fn = True;
        aa_body: ASTNode = self._parse_arrow_body();
        self.in_async_fn = saved_async_aa;
        return make_arrow(
            aa_params,
            aa_body,
            self._span(start),
            True,
            aa_body.ntype != ASTNodeType.BlockStatement
        );
    }

    """Parse a class expression."""
    def _parse_class_expr -> ASTNode {
        start: SourceRange = self._loc();
        self._expect(TokenType.KwClass);
        ce_id: ASTNode | None = None;
        # A class BindingIdentifier accepts the soft/contextual keywords that are valid
        # identifiers here — including `await` (valid unless the goal is Module / inside an
        # async fn) and `yield` (valid unless inside a generator). ES §15.7 BindingIdentifier.
        if self._is(TokenType.Identifier)
            or self._is(TokenType.KwGet)
            or self._is(TokenType.KwSet)
            or self._is(TokenType.KwStatic)
            or self._is(TokenType.KwFrom)
            or self._is(TokenType.KwAs)
            or self._is(TokenType.KwOf)
            or self._is(TokenType.KwAsync)
            or self._is(TokenType.KwLet)
            or (self._is(TokenType.KwYield) and not self.in_generator_fn)
            or (self._is(TokenType.KwAwait) and not self.in_async_fn) {
            ce_id = make_identifier(self._cur.value, self._loc());
            self._advance();
        }
        if self._is(TokenType.Lt) {
            self._advance();
            self._skip_ts_generics();
        }
        ce_sup: ASTNode | None = None;
        if self._eat(TokenType.KwExtends) {
            ce_sup = self._parse_left_hand_expr();
            if self._is(TokenType.Lt) {
                self._advance();
                self._skip_ts_generics();
            }
        }
        ce_body: list[ASTNode] = self._parse_class_body();
        return make_class_expr(ce_id, ce_sup, ce_body, self._span(start));
    }

    # ── Parameter list ─────────────────────────────────────────────────────

    """Parse function parameter list `( params )`."""
    def _parse_params -> list[ASTNode] {
        self._expect(TokenType.LParen);
        result2: list[ASTNode] = self._parse_param_items();
        self._expect(TokenType.RParen);
        return result2;
    }

    """Parse a grouped expression as params (for arrow `(a, b) => ...`)."""
    def _parse_grouped_params -> list[ASTNode] {
        self._expect(TokenType.LParen);
        items2: list[ASTNode] = [];
        while not self._is(TokenType.RParen) and not self._is(TokenType.EOF) {
            if self._is(TokenType.DotDotDot) {
                rp_start: SourceRange = self._loc();
                self._advance();
                rp_id: ASTNode = self._parse_binding_pattern();
                items2.append(make_rest(rp_id, self._span(rp_start)));
                break;
            }
            items2.append(self._parse_assignment_expr());
            self._eat(TokenType.Comma);
        }
        self._expect(TokenType.RParen);
        return items2;
    }

    """Parse param items (inside parens, not consuming them)."""
    def _parse_param_items -> list[ASTNode] {
        params2: list[ASTNode] = [];
        while not self._is(TokenType.RParen) and not self._is(TokenType.EOF) {
            pm_start: SourceRange = self._loc();
            # rest param: `...rest`
            if self._is(TokenType.DotDotDot) {
                self._advance();
                rest_pat: ASTNode = self._parse_binding_pattern();
                params2.append(make_rest(rest_pat, self._span(pm_start)));
                break;
            }
            # TS access modifiers: public, private, protected, readonly — only when
            # the parameter itself follows (`readonly x`). Otherwise the word IS the
            # parameter name: plain JS `function f(node, readonly) {}` (@babel/parser's
            # tsParsePropertyOrMethodSignature) lost the parameter and failed to parse.
            if self._is(TokenType.Identifier) {
                mv: str = self._cur.value;
                if (
                    mv == "public"
                    or mv == "private"
                    or mv == "protected"
                    or mv == "readonly"
                )
                    and self._peek.ttype != TokenType.Comma
                    and self._peek.ttype != TokenType.RParen
                    and self._peek.ttype != TokenType.Eq
                    and self._peek.ttype != TokenType.Colon
                    and self._peek.ttype != TokenType.Question {
                    self._advance();
                }
            }
            pm_pat: ASTNode = self._parse_binding_pattern();
            # optional param: `x?`
            if self._is(TokenType.Question) {
                self._advance();
            }
            # type annotation: `: Type`
            if self._is(TokenType.Colon) {
                self._advance();
                self._skip_ts_type();
            }
            # default value: `= expr`
            if self._eat(TokenType.Eq) {
                dflt2: ASTNode = self._parse_assignment_expr();
                pm_pat = make_assignment_pattern(pm_pat, dflt2, self._span(pm_start));
            }
            params2.append(pm_pat);
            self._eat(TokenType.Comma);
        }
        return params2;
    }

    # ── Destructuring patterns ─────────────────────────────────────────────

    """Parse a binding pattern: identifier, `{ ... }` or `[ ... ]`."""
    def _parse_binding_pattern -> ASTNode {
        tt9: TokenType = self._tt();
        if tt9 == TokenType.LBrace {
            return self._parse_object_pattern();
        }
        if tt9 == TokenType.LBracket {
            return self._parse_array_pattern();
        }
        # simple identifier
        name4: str = self._cur.value;
        loc2: SourceRange = self._loc();
        self._advance();
        return make_identifier(name4, loc2);
    }

    """Parse `{ a, b: c, d = default, ...rest }` destructuring."""
    def _parse_object_pattern -> ASTNode {
        start: SourceRange = self._loc();
        self._expect(TokenType.LBrace);
        props2: list[ASTNode] = [];
        while not self._is(TokenType.RBrace) and not self._is(TokenType.EOF) {
            op2_start: SourceRange = self._loc();
            if self._is(TokenType.DotDotDot) {
                self._advance();
                rest_obj: ASTNode = self._parse_binding_pattern();
                props2.append(make_rest(rest_obj, self._span(op2_start)));
                break;
            }
            op_is_computed: bool = self._is(TokenType.LBracket);
            op_key: ASTNode = self._parse_prop_key();
            op_val: ASTNode | None = None;
            if self._eat(TokenType.Colon) {
                op_val = self._parse_binding_pattern();
            } else {
                op_val = op_key;
            }
            if self._eat(TokenType.Eq) {
                dflt3: ASTNode = self._parse_assignment_expr();
                op_val = make_assignment_pattern(op_val, dflt3, self._span(op2_start));
            }
            props2.append(
                make_property(
                    op_key,
                    op_val,
                    "init",
                    (op_val is op_key),
                    op_is_computed,
                    self._span(op2_start)
                )
            );
            self._eat(TokenType.Comma);
        }
        self._expect(TokenType.RBrace);
        return make_object_pattern(props2, self._span(start));
    }

    """Parse `[a, b = default, ...rest]` destructuring."""
    def _parse_array_pattern -> ASTNode {
        start: SourceRange = self._loc();
        self._expect(TokenType.LBracket);
        elems2: list[ASTNode] = [];
        while not self._is(TokenType.RBracket) and not self._is(TokenType.EOF) {
            ap_start: SourceRange = self._loc();
            if self._is(TokenType.Comma) {
                elems2.append(make_identifier("undefined", self._loc()));
                self._advance();
            } elif self._is(TokenType.DotDotDot) {
                self._advance();
                rest_arr: ASTNode = self._parse_binding_pattern();
                elems2.append(make_rest(rest_arr, self._span(ap_start)));
                break;
            } else {
                e2: ASTNode = self._parse_binding_pattern();
                if self._eat(TokenType.Eq) {
                    dflt4: ASTNode = self._parse_assignment_expr();
                    e2 = make_assignment_pattern(e2, dflt4, self._span(ap_start));
                }
                elems2.append(e2);
                self._eat(TokenType.Comma);
            }
        }
        self._expect(TokenType.RBracket);
        return make_array_pattern(elems2, self._span(start));
    }
}

# current (not yet consumed) token
# one-token look-ahead
# collected parse error messages
# suppress `in` as infix operator (for-loop init)
# True while parsing a generator function body
# True while parsing a generator's own parameter list (yield forbidden — early error)
# True while parsing an async function body (await is an operator; elsewhere it's an identifier)
# Last consumed token — used by `_span` so node ranges end at the closing
# token rather than extending into the following lookahead token (needed
# for Function.prototype.toString source fidelity).
# ══════════════════════════════════════════════════════════════════════════════
# 4.  Factory
# ══════════════════════════════════════════════════════════════════════════════

"""Create a Parser for the given JavaScript / TypeScript source string."""
def:pub make_parser(source: str) -> Parser {
    lx2: Lexer = make_lexer(source);
    t1: Token = lx2.next_token();
    t2: Token = lx2.next_token();
    return Parser(_lx=lx2, _cur=t1, _peek=t2, _errors=[], _no_in=False);
}

# ══════════════════════════════════════════════════════════════════════════════
# 5.  Public helper
# ══════════════════════════════════════════════════════════════════════════════

"""
Strip a Unix hashbang (#!...) from the first line of `source`.
ECMAScript / Node treat the entire first line as a comment when it begins with #!.
Without this, `#!/usr/bin/env node` is lexed as RegExp `/usr/` + flags `bin`.
"""
def _strip_hashbang(source: str) -> str {
    slen: int = len(source);
    if slen < 2 {
        return source;
    }
    if source[0] != "#" or source[1] != "!" {
        return source;
    }
    i: int = 2;
    while i < slen {
        c: str = source[i];
        if c == "\n" {
            i = i + 1;
            break;
        }
        if c == chr(13) {
            i = i + 1;
            if i < slen and source[i] == "\n" {
                i = i + 1;
            }
            break;
        }
        i = i + 1;
    }
    if i >= slen {
        return "";
    }
    return source[i:slen];
}

"""
Return True if `source` refers to a CommonJS binding — module.exports,
exports.x, require(...), __dirname or __filename. A substring sniff (no lexer
pass), so text in strings/comments counts too; callers pair it with
_source_is_module when that matters.
"""
def:pub _source_uses_cjs_bindings(source: str) -> bool {
    return (
        "exports" in source
        or "require(" in source
        or "__dirname" in source
        or "__filename" in source
    );
}

"""
Return True if `source` is an ECMAScript *module* (contains a top-level
ImportDeclaration or ExportDeclaration).  Uses a throwaway lexer pass so string
/ comment contents never trigger a false positive.  `import(` (dynamic import)
and `import.meta` are NOT module markers.
"""
def:pub _source_is_module(source: str) -> bool {
    sm_lx: Lexer = make_lexer(source);
    sm_prev: TokenType = TokenType.EOF;  # previous significant token type
    sm_tok: Token = sm_lx.next_token();
    while sm_tok.ttype != TokenType.EOF {
        if sm_tok.ttype == TokenType.KwExport {
            # `export`/`import` are IdentifierName in a property-key or member
            # position — NOT a module marker: `({export: x})`, `obj.export`,
            # `{ import }` (shorthand). Only a real ExportDeclaration follows with a
            # binding/declaration token. A preceding `.` (member) or a following `:`
            # (property key) means it is an ordinary name (port-escaped tests).
            nxt_e: Token = sm_lx.next_token();
            if sm_prev != TokenType.Dot and nxt_e.ttype != TokenType.Colon {
                return True;
            }
            sm_prev = sm_tok.ttype;
            sm_tok = nxt_e;
            continue;
        }
        if sm_tok.ttype == TokenType.KwImport {
            nxt: Token = sm_lx.next_token();
            # `import(` → dynamic import (not a module marker); `import.meta` likewise;
            # `import:` → property key; `.import` → member access — none are markers.
            if sm_prev != TokenType.Dot
                and nxt.ttype != TokenType.LParen
                and nxt.ttype != TokenType.Dot
                and nxt.ttype != TokenType.Colon {
                return True;
            }
            sm_prev = sm_tok.ttype;
            sm_tok = nxt;
            continue;
        }
        sm_prev = sm_tok.ttype;
        sm_tok = sm_lx.next_token();
    }
    return False;
}

"""Parse `source` and return the Program ASTNode.
If there are parse errors, prints them to stderr and sets had_parse_errors.

`force_module` forces the module goal (top-level await allowed) — set by the
.mjs / ESM entry loader.  `detect_module` enables a throwaway token pre-scan
that decides the module goal by looking for a top-level import/export.  That
scan is a full extra lex over the whole source, so callers that already know
the goal — notably the CommonJS/builtin loaders, whose source is wrapped in a
CJS function and can never be an ES module — should pass detect_module=False to
skip it.  Running it unconditionally over every builtin at startup cost ~30ms
(a real bootstrap regression).

NOTE: although detect_module defaults to True, the Jac native backend does not
reliably fill omitted default-valued parameters (an omitted arg can read as
False), so ALL callers pass force_module and detect_module explicitly rather
than relying on the defaults.  Keep it that way."""
def:pub parse(
    source: str, force_module: bool = False, detect_module: bool = True
) -> ASTNode {
    _PARSE_HAD_ERRORS = False;
    source = _strip_hashbang(source);
    if PARSER_DEBUG_MODE {
        parser_debug("→ parse  src_len=" + str(len(source)));
    }
    p2: Parser = make_parser(source);
    # Module-goal detection: a module permits top-level `await` as an operator (TLA).
    parse_module_goal: bool = force_module
        or (detect_module and _source_is_module(source));
    if parse_module_goal {
        p2.in_async_fn = True;
    }
    result: ASTNode = p2.parse_program();
    # Record the module goal on the Program node (reusing `is_async`) so the compiler
    # knows top-level `await` is allowed even in a module WITHOUT import/export — it
    # otherwise re-infers the goal from import/export presence alone and wrongly
    # rejects TLA in an import-less module (ES §16.2.1.6 / top-level-await tests).
    if parse_module_goal {
        result.is_async = True;
    }
    if len(p2._errors) > 0 {
        i: int = 0;
        while i < len(p2._errors) {
            print(p2._errors[i]);
            i = i + 1;
        }
        _PARSE_HAD_ERRORS = True;
    }
    if PARSER_DEBUG_MODE {
        parser_debug("← parse  done");
    }
    return result;
}
