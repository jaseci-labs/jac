"""View lowering pass — desugars `view` declarators into ordinary abilities.

The parser (`Parser.parse_view`) produces a *faithful* `Ability` for every
`view` declarator: `is_view = True`, the real `view` keyword token in the kid
list, the body kept as the author's raw statement template, and no synthetic
`:pub` / `-> JsxElement`. Doing the desugaring here — in a pass — rather than
in the parser keeps the AST source-faithful for the `jac format` pipeline
(which does not run this pass), so `view` syntax round-trips instead of being
rewritten into its lowered `def` form.

For every `is_view` ability this pass:

1. Checks the raw template for view-body rule violations (E2019/E2020/E2021,
   W2019) — the `view_body_check` rules.
2. Lowers the statement template into an accumulator: `acc = []`, every JSX
   statement (recursively, through control flow) does `acc.append(<jsx>)`,
   then `return <>{acc}</>;`. `.append` is O(1) amortized — the accumulator
   is built in linear time. On the client target `@jac/runtime`'s polymorphic
   `append` lowers it to `Array.prototype.push`.
3. Rewrites the declaration into `def:pub Name(...) -> JsxElement`: swaps the
   `view` token for `def`, inserts a `:pub` access tag, and synthesizes the
   `-> JsxElement` return type when the author omitted it.

After this pass a former `view` is structurally identical to a hand-written
`def:pub Name(...) -> JsxElement`, so every later pass (symbol table, type
check, codegen) handles it with no view-specific logic.

Runs first in the IR-generation schedule, before `ASTValidationPass`.
"""
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.passes { UniPass }
import from jaclang.jac0core.diagnostics { E2019, E2020, E2021, W2019 }

"""Name of the synthesized child accumulator local."""
glob VIEW_ACC: str = "__jac_view_kids";

"""Lowers `view` declarators into ordinary `def:pub -> JsxElement` abilities."""
obj ViewLowerPass(UniPass) {
    """Lower one `view` declarator once its body has been fully traversed."""
    def exit_ability(nd: uni.Ability) -> None {
        if not nd.is_view {
            return;
        }
        anchor: uni.UniNode = nd.name_ref if nd.name_ref is not None else nd;
        raw_body: list = list(nd.body);
        # 1. Diagnose view-body rule violations on the un-lowered template.
        self._check_body(raw_body, False, "");
        # 2. Lower the statement template into an accumulator + fragment return.
        lowered = self._lower_body(raw_body, anchor);
        # 3. Rewrite the declaration so it reads as `def:pub -> JsxElement`.
        self._rewrite_decl(nd, raw_body, lowered, anchor);
    }

    # ----- view_body_check diagnostics -------------------------------------
    """Walk the raw template and emit view-body rule diagnostics.

    `in_loop` is True inside a template `for`/`while`; `loop_kw` names it.
    Nested `def` handlers are not descended into — their `return`s are their
    own."""
    def _check_body(stmts: list, in_loop: bool, loop_kw: str) {
        for s in stmts {
            if isinstance(s, uni.ReturnStmt) {
                if s.expr is not None {
                    self.emit(E2019, node_override=s);
                } elif in_loop {
                    self.emit(E2020, node_override=s, loop=loop_kw);
                }
            } elif isinstance(s, uni.CtrlStmt) {
                if in_loop and s.ctrl.value in ["break", "skip"] {
                    self.emit(E2021, node_override=s, kw=s.ctrl.value, loop=loop_kw);
                }
            } elif isinstance(s, uni.WhileStmt) {
                if self._emits_keyless_jsx(s.body) {
                    self.emit(W2019, node_override=s);
                }
                self._check_body(s.body, True, "while");
                self._check_else(s.else_body, in_loop, loop_kw);
            } elif isinstance(s, uni.InForStmt) or isinstance(s, uni.IterForStmt) {
                self._check_body(s.body, True, "for");
                self._check_else(s.else_body, in_loop, loop_kw);
            } elif isinstance(s, uni.IfStmt) {
                # IfStmt also matches ElseIf (a subclass).
                self._check_body(s.body, in_loop, loop_kw);
                self._check_else(s.else_body, in_loop, loop_kw);
            } elif isinstance(s, uni.WithStmt) {
                self._check_body(s.body, in_loop, loop_kw);
            } elif isinstance(s, uni.TryStmt) {
                self._check_body(s.body, in_loop, loop_kw);
                for ex in s.excepts {
                    self._check_body(ex.body, in_loop, loop_kw);
                }
                self._check_else(s.else_body, in_loop, loop_kw);
                if s.finally_body is not None {
                    self._check_body(s.finally_body.body, in_loop, loop_kw);
                }
            } elif isinstance(s, uni.MatchStmt) {
                for cs in s.cases {
                    self._check_body(cs.body, in_loop, loop_kw);
                }
            } elif isinstance(s, uni.SwitchStmt) {
                for cs in s.cases {
                    self._check_body(cs.body, in_loop, loop_kw);
                }
            }
        }
    }

    """Recurse view-body checks into an optional `else`/`elif` clause."""
    def _check_else(else_body: object, in_loop: bool, loop_kw: str) -> None {
        if else_body is None {
            return;
        }
        if isinstance(else_body, uni.IfStmt) {
            self._check_body([else_body], in_loop, loop_kw);
        } elif isinstance(else_body, uni.ElseStmt) {
            self._check_body(else_body.body, in_loop, loop_kw);
        }
    }

    """True when `stmts` (recursively) render a JSX element with no `key`.

    Mirrors the recursion in `_check_body` — descends through every
    block-bodied construct that can yield template content (loops, `with`,
    `if`/`else`, `match`/`switch`, and `try` including each `except` arm,
    the `else` clause, and the `finally` body)."""
    def _emits_keyless_jsx(stmts: list) -> bool {
        for s in stmts {
            if isinstance(s, uni.ExprStmt) and isinstance(s.expr, uni.JsxElement) {
                el = s.expr;
                if (
                    not el.is_fragment
                    and el.dynamic_tag is None
                    and not self._has_key_attr(el)
                ) {
                    return True;
                }
            } elif isinstance(s, uni.WhileStmt)
            or isinstance(s, uni.InForStmt)
            or isinstance(s, uni.IterForStmt)
            or isinstance(s, uni.WithStmt) {
                if self._emits_keyless_jsx(s.body) {
                    return True;
                }
            } elif isinstance(s, uni.IfStmt) or isinstance(s, uni.ElseStmt) {
                if self._emits_keyless_jsx(s.body) {
                    return True;
                }
            } elif isinstance(s, uni.TryStmt) {
                if self._emits_keyless_jsx(s.body) {
                    return True;
                }
                for ex in s.excepts {
                    if self._emits_keyless_jsx(ex.body) {
                        return True;
                    }
                }
                if s.else_body is not None
                and isinstance(s.else_body, uni.ElseStmt)
                and self._emits_keyless_jsx(s.else_body.body) {
                    return True;
                }
                if s.finally_body is not None
                and self._emits_keyless_jsx(s.finally_body.body) {
                    return True;
                }
            } elif isinstance(s, uni.MatchStmt) or isinstance(s, uni.SwitchStmt) {
                for cs in s.cases {
                    if self._emits_keyless_jsx(cs.body) {
                        return True;
                    }
                }
            }
        }
        return False;
    }

    """True when a JSX element carries a `key=` attribute."""
    def _has_key_attr(el: uni.JsxElement) -> bool {
        if el.attributes is None {
            return False;
        }
        for a in el.attributes {
            if (
                isinstance(a, uni.JsxNormalAttribute)
                and a.name is not None
                and a.name.value == "key"
            ) {
                return True;
            }
        }
        return False;
    }

    # ----- lowering --------------------------------------------------------
    """Lower a view body into an accumulator-backed `def` body.

    Emits `acc = [];`, then the lowered statements (JSX statements rewritten
    to `acc.append(<jsx>)`), then `return <>{acc}</>;`."""
    def _lower_body(stmts: list, anchor: uni.UniNode) -> list {
        lowered = self._lower_stmt_list(stmts, None, anchor);
        # acc = [];
        acc_name = self._synth_name(VIEW_ACC, anchor);
        eq_uni = self._synth_tok("EQ", "=", anchor);
        empty_list = uni.ListVal(
            values=[],
            kid=[
                self._synth_tok("LSQUARE", "[", anchor),
                self._synth_tok("RSQUARE", "]", anchor)
            ]
        );
        init_assign = uni.Assignment(
            target=[acc_name],
            value=empty_list,
            type_tag=None,
            kid=[acc_name, eq_uni, empty_list, self._synth_semi(anchor)],
            mutable=True,
            aug_op=None,
            is_enum_stmt=False
        );
        # return <>{acc}</>;
        frag = self._make_fragment(anchor);
        ret_uni = self._synth_tok("KW_RETURN", "return", anchor);
        ret_stmt = uni.ReturnStmt(
            expr=frag, kid=[ret_uni, frag, self._synth_semi(anchor)]
        );
        return [init_assign] + lowered + [ret_stmt];
    }

    """Lower a list of view-body statements.

    Returns a new list with each bare JSX statement rewritten as
    `acc.append(<jsx>)`. Block-bodied control flow yields content, so the
    lowering recurses into nested block bodies. When `owner` is given, its
    `.kid` is patched so swapped statements stay reachable by tree walks."""
    def _lower_stmt_list(stmts: list, owner: object, anchor: uni.UniNode) -> list {
        new_stmts: list = [];
        for s in stmts {
            new_stmts.append(self._lower_one(s, anchor));
        }
        if owner is not None {
            changed = False;
            new_kid: list = [];
            for k in owner.kid {
                replacement = k;
                idx = 0;
                for ob in stmts {
                    if ob is k {
                        replacement = new_stmts[idx];
                        if replacement is not k {
                            changed = True;
                        }
                        break;
                    }
                    idx += 1;
                }
                new_kid.append(replacement);
            }
            if changed {
                owner.set_kids(new_kid);
            }
        }
        return new_stmts;
    }

    """Lower one view-body statement, returning the (possibly new) node.

    A bare JSX statement becomes `acc.append(<jsx>)`; a `return` is rewritten
    into `return <>{acc}</>;` (early-exit guard). Block-bodied control flow
    keeps its identity — only its nested block bodies are recursively lowered.
    Other statements (assignments, `has`, nested `def` handlers) pass through
    unchanged; nested `def` bodies are deliberately not descended into."""
    def _lower_one(stmt: object, anchor: uni.UniNode) -> object {
        s = stmt;
        if isinstance(s, uni.ExprStmt) {
            if isinstance(s.expr, uni.JsxElement) {
                return self._make_append(s.expr, anchor);
            }
            return s;
        }
        if isinstance(s, uni.ReturnStmt) {
            # Any `return` in a view body becomes the fragment guard return.
            # A `return expr;` was already flagged E2019; discarding the value
            # here keeps lowering robust and avoids a spurious type error.
            frag = self._make_fragment(anchor);
            ret_uni = self._synth_tok("KW_RETURN", "return", anchor);
            s.expr = frag;
            s.set_kids([ret_uni, frag, self._synth_semi(anchor)]);
            return s;
        }
        if isinstance(s, uni.IfStmt) {
            # IfStmt also matches ElseIf (a subclass).
            s.body = self._lower_stmt_list(s.body, s, anchor);
            if s.else_body is not None {
                self._lower_one(s.else_body, anchor);
            }
            return s;
        }
        if isinstance(s, uni.ElseStmt) {
            s.body = self._lower_stmt_list(s.body, s, anchor);
            return s;
        }
        if isinstance(s, uni.WhileStmt)
        or isinstance(s, uni.InForStmt)
        or isinstance(s, uni.IterForStmt) {
            s.body = self._lower_stmt_list(s.body, s, anchor);
            if s.else_body is not None {
                self._lower_one(s.else_body, anchor);
            }
            return s;
        }
        if isinstance(s, uni.WithStmt) {
            s.body = self._lower_stmt_list(s.body, s, anchor);
            return s;
        }
        if isinstance(s, uni.TryStmt) {
            s.body = self._lower_stmt_list(s.body, s, anchor);
            for ex in s.excepts {
                self._lower_one(ex, anchor);
            }
            if s.else_body is not None {
                self._lower_one(s.else_body, anchor);
            }
            if s.finally_body is not None {
                self._lower_one(s.finally_body, anchor);
            }
            return s;
        }
        if isinstance(s, uni.Except) or isinstance(s, uni.FinallyStmt) {
            s.body = self._lower_stmt_list(s.body, s, anchor);
            return s;
        }
        if isinstance(s, uni.MatchStmt) {
            for cs in s.cases {
                self._lower_one(cs, anchor);
            }
            return s;
        }
        if isinstance(s, uni.SwitchStmt) {
            for cs in s.cases {
                self._lower_one(cs, anchor);
            }
            return s;
        }
        if isinstance(s, uni.MatchCase) or isinstance(s, uni.SwitchCase) {
            s.body = self._lower_stmt_list(s.body, s, anchor);
            return s;
        }
        return s;
    }

    """Build `acc.append(<jsx>);` — append one template element in O(1)."""
    def _make_append(jsx: uni.Expr, anchor: uni.UniNode) -> uni.ExprStmt {
        acc_ref = self._synth_name(VIEW_ACC, anchor);
        dot_uni = self._synth_tok("DOT", ".", anchor);
        append_name = self._synth_name("append", anchor);
        callee = uni.AtomTrailer(
            target=acc_ref,
            right=append_name,
            is_attr=True,
            is_null_ok=False,
            kid=[acc_ref, dot_uni, append_name]
        );
        lp_uni = self._synth_tok("LPAREN", "(", anchor);
        rp_uni = self._synth_tok("RPAREN", ")", anchor);
        call = uni.FuncCall(
            target=callee,
            params=[jsx],
            genai_call=None,
            kid=[callee, lp_uni, jsx, rp_uni]
        );
        return uni.ExprStmt(
            expr=call, in_fstring=False, kid=[call, self._synth_semi(anchor)]
        );
    }

    """Build `<>{acc}</>` — the fragment of all template content so far."""
    def _make_fragment(anchor: uni.UniNode) -> uni.JsxElement {
        lb = self._synth_tok("LBRACE", "{", anchor);
        acc_ref = self._synth_name(VIEW_ACC, anchor);
        rb = self._synth_tok("RBRACE", "}", anchor);
        jsx_expr = uni.JsxExpression(expr=acc_ref, kid=[lb, acc_ref, rb]);
        return uni.JsxElement(
            name=None,
            attributes=[],
            children=[jsx_expr],
            is_self_closing=False,
            is_fragment=True,
            kid=[
                self._synth_tok("JSX_FRAG_OPEN", "<>", anchor),
                jsx_expr,
                self._synth_tok("JSX_FRAG_CLOSE", "</>", anchor)
            ]
        );
    }

    # ----- declaration rewrite ---------------------------------------------
    """Rewrite a `view` ability in place so it reads as `def:pub -> JsxElement`.

    Swaps the `view` keyword token for `def`, inserts a `:pub` access tag,
    synthesizes the `-> JsxElement` return type when omitted, and splices the
    lowered body into the kid list in place of the raw template."""
    def _rewrite_decl(
        nd: uni.Ability, raw_body: list, lowered: list, anchor: uni.UniNode
    ) {
        nd.body = lowered;
        # `:pub` access tag — a view is always a public component.
        colon_uni = self._synth_tok("COLON", ":", anchor);
        pub_uni = self._synth_tok("KW_PUB", "pub", anchor);
        access = uni.SubTag(tag=pub_uni, kid=[colon_uni, pub_uni]);
        nd.access = access;
        # A view always returns JsxElement — synthesize the annotation.
        if isinstance(nd.signature, uni.FuncSignature)
        and nd.signature.return_type is None {
            ret_hint = self._synth_tok("RETURN_HINT", "->", anchor);
            ret_type = self._synth_name("JsxElement", anchor);
            nd.signature.return_type = ret_type;
            nd.signature.add_kids_right([ret_hint, ret_type]);
        }
        # Rebuild the kid list: `view` token -> `def` + access tag; the raw
        # body statements -> the lowered body, spliced after the body `{`.
        def_uni = self._synth_tok("KW_DEF", "def", anchor);
        raw_ids: set = set();
        for rb in raw_body {
            raw_ids.add(id(rb));
        }
        new_kid: list = [];
        body_spliced = False;
        for k in nd.kid {
            if isinstance(k, uni.Token) and k.name == Tok.KW_VIEW.value {
                new_kid.append(def_uni);
                new_kid.append(access);
            } elif id(k) in raw_ids {
                continue;
            } else {
                new_kid.append(k);
                if (
                    not body_spliced
                    and isinstance(k, uni.Token)
                    and k.name == Tok.LBRACE.value
                ) {
                    new_kid.extend(lowered);
                    body_spliced = True;
                }
            }
        }
        nd.set_kids(new_kid);
    }

    # ----- synthetic-node builders -----------------------------------------
    """Build a synthetic Name node anchored at the given node's location."""
    def _synth_name(value: str, anchor: uni.UniNode) -> uni.Name {
        return uni.Name(
            orig_src=anchor.loc.orig_src,
            name=Tok.NAME.value,
            value=value,
            line=anchor.loc.first_line,
            end_line=anchor.loc.last_line,
            col_start=anchor.loc.col_start,
            col_end=anchor.loc.col_end,
            pos_start=anchor.loc.pos_start,
            pos_end=anchor.loc.pos_end,
            is_enum_stmt=False,
            is_kwesc=False
        );
    }

    """Build a synthetic UniToken anchored at the given node's location."""
    def _synth_tok(tok_type: str, value: str, anchor: uni.UniNode) -> uni.Token {
        tok = uni.Token(
            orig_src=anchor.loc.orig_src,
            name=tok_type,
            value=value,
            line=anchor.loc.first_line,
            end_line=anchor.loc.last_line,
            col_start=anchor.loc.col_start,
            col_end=anchor.loc.col_end,
            pos_start=anchor.loc.pos_start,
            pos_end=anchor.loc.pos_end
        );
        tok._is_synthetic = True;
        return tok;
    }

    """Build a synthetic Semi node anchored at the given node's location."""
    def _synth_semi(anchor: uni.UniNode) -> uni.Semi {
        return uni.Semi(
            orig_src=anchor.loc.orig_src,
            name=Tok.SEMI.value,
            value=";",
            line=anchor.loc.first_line,
            end_line=anchor.loc.last_line,
            col_start=anchor.loc.col_start,
            col_end=anchor.loc.col_end,
            pos_start=anchor.loc.pos_start,
            pos_end=anchor.loc.pos_end
        );
    }
}
