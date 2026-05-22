"""JSX slot lowering pass — turns `{...}` slot bodies into accumulator IIFEs.

The parser produces a faithful `JsxSlot` for every `{...}` slot in JSX
child position whose body is statement-form (begins with `if`/`for`/
`while`/`match`/`switch`/`with`/`try`/`skip`, or contains multiple
statements separated by `;`). The body is preserved as the author's raw
statement template so the `jac format` pipeline (which does not run this
pass) round-trips the source verbatim.

For every `JsxSlot` this pass:

1. Checks the raw body for slot-body rule violations (E2019/E2020/E2021,
   W2019).
2. Lowers the body into an accumulator pattern: `__jac_view_kids = []`,
   every JSX statement (recursively, through control flow) does
   `__jac_view_kids.append(<jsx>)`, then `return <>{__jac_view_kids}</>;`.
   `skip;` inside the body is rewritten to the same `return <>{acc}</>;`
   shape — the slot early-exit guard. `.append` is O(1) amortized --
   the accumulator is built in linear time. On the client target
   `@jac/runtime`'s polymorphic `append` lowers it to
   `Array.prototype.push`.

After this pass the es-codegen wraps the lowered body in an arrow
function and invokes it inline; the slot's expression value is the
accumulated JSX fragment.

Runs first in the IR-generation schedule, before `ASTValidationPass`.
"""
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.passes { UniPass }
import from jaclang.jac0core.diagnostics {
    E2019,
    E2020,
    E2021,
    E2022,
    E2024,
    W2019,
    W2020,
    W2021
}

"""Name of the synthesized child accumulator local."""
glob VIEW_ACC: str = "__jac_view_kids";

"""Lowers JSX `{...}` slot bodies into accumulator IIFEs.

A `JsxSlot` holds raw author statements between `{` and `}` inside a
JSX child position. The lowering transforms the body in place: a
`__jac_view_kids = []` is prepended, every JSX statement is rewritten
to `__jac_view_kids.append(<jsx>)`, control flow yielding JSX
contributes through the same push, and a final `return
<>{__jac_view_kids}</>;` is appended. The es-codegen wraps the result
in an arrow function that's invoked inline so the slot's expression
value is the accumulated JSX fragment.

`skip;` inside the slot is rewritten to the same fragment-of-kids
return — the slot early-exit guard ("show the empty state, stop
here"). Bare `return;` is flagged E2020 ("use `skip;`") and a
value-returning `return expr;` is flagged E2019; both still lower
into the fragment-return shape so the pass stays robust against
the diagnosed source.
"""
obj ViewLowerPass(UniPass) {
    """Per-pass counter used to name nested slot accumulators uniquely.

    Each `awaiting`-lowering synthesizes inner `JsxSlot`s whose bodies
    are also lowered into IIFEs. JavaScript hoists `let`-bound names
    by scope, so re-using `__jac_view_kids` inside nested IIFEs makes
    them reassign the *outer* slot's accumulator instead of declaring
    their own — clobbering the parent's children. A monotonic suffix
    gives every nested accumulator a distinct binding."""
    has _nested_acc_counter: int = 0;

    """Lower a JSX `{...}` slot body into an accumulator IIFE shape."""
    def exit_jsx_slot(nd: uni.JsxSlot) {
        raw_body: list = list(nd.body);
        # Diagnose body rule violations (re-targeted view-body-check).
        self._check_body(raw_body, False, "");
        # Lower the body in place.
        lowered = self._lower_body(raw_body, anchor=nd);
        nd.body = lowered;
        # Rebuild kid list: keep the `{` and `}` tokens, replace body
        # statements with their lowered counterparts.
        raw_ids: set = set();
        for rb in raw_body {
            raw_ids.add(id(rb));
        }
        new_kid: list = [];
        body_spliced = False;
        for k in nd.kid {
            if id(k) in raw_ids {
                continue;
            }
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
        nd.set_kids(new_kid);
    }

    # ----- view_body_check diagnostics -------------------------------------
    """Walk the raw template and emit view-body rule diagnostics.

    `in_loop` is True inside a template `for`/`while`; `loop_kw` names it.
    Nested `def` handlers are not descended into — their `return`s are their
    own."""
    def _check_body(stmts: list, in_loop: bool, loop_kw: str) {
        for s in stmts {
            if isinstance(s, uni.ReturnStmt) {
                # Any `return` in a slot body is forbidden: a slot body is
                # an inlined IIFE, so `return;` reads like a function-exit
                # but only exits the slot. `skip;` is the canonical
                # slot early-exit; `return expr;` makes no sense at all
                # since slots render template content.
                if s.expr is not None {
                    self.emit(E2019, node_override=s);
                } else {
                    self.emit(E2020, node_override=s);
                }
            } elif isinstance(s, uni.CtrlStmt) {
                # `skip;` is the slot early-exit (lowered by _lower_one to
                # `return <>{acc}</>;`) — always allowed, including inside
                # slot loops where it abandons remaining iterations *and*
                # later JSX. Only `break;` remains ambiguous in a slot
                # loop (exit-loop vs. exit-slot).
                if in_loop and s.ctrl.value == "break" {
                    self.emit(E2021, node_override=s, kw=s.ctrl.value, loop=loop_kw);
                }
            } elif isinstance(s, uni.ArchHas) {
                # `has`-fields declared inside a slot body would compile
                # to a conditional `useState` — a rules-of-hooks violation.
                # State belongs at the enclosing `def -> JsxElement` scope.
                self.emit(E2024, node_override=s);
            } elif isinstance(s, uni.WhileStmt) {
                if self._emits_keyless_jsx(s.body) {
                    self.emit(W2019, node_override=s);
                }
                self._check_body(s.body, True, "while");
                self._check_else(s.else_body, in_loop, loop_kw);
            } elif isinstance(s, uni.InForStmt) or isinstance(s, uni.IterForStmt) {
                # Keyless for-loop in a slot: until the auto-fragment
                # lowering (#6082 item 1) lands, an unkeyed loop child
                # contributes its JSX as flat siblings into the parent's
                # children list, and a re-render with a reordered iterable
                # loses iteration identity. W2021 names the fix at the
                # source site.
                if self._emits_keyless_jsx(s.body) {
                    self.emit(W2021, node_override=s);
                }
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
                if s.awaiting_body is not None {
                    # The awaiting body is rendered before any try-body work
                    # completes; loop-context flags carry through so an
                    # `awaiting` body inside a slot `for` still gets the
                    # same loop diagnostics.
                    self._check_body(s.awaiting_body.body, in_loop, loop_kw);
                }
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
                if s.awaiting_body is not None
                and self._emits_keyless_jsx(s.awaiting_body.body) {
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
    to `acc.append(<jsx>)`), then `return <>{acc}</>;`.

    `acc_name_str` names the accumulator local — the top-level slot uses
    `__jac_view_kids` (preserved for diagnostics that grep the emitted
    JS); nested slots synthesized by the `awaiting` lowering supply a
    unique suffixed name so each IIFE gets its own JS binding."""
    def _lower_body(
        stmts: list, anchor: uni.UniNode, acc_name_str: str = VIEW_ACC
    ) -> list {
        lowered = self._lower_stmt_list(stmts, None, anchor, acc_name_str);
        # acc = [];
        acc_name = self._synth_name(acc_name_str, anchor);
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
        frag = self._make_fragment(anchor, acc_name_str);
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
    `.kid` is patched so swapped statements stay reachable by tree walks.
    `acc_name_str` threads the accumulator's local name through the
    recursion so nested slots can use a distinct binding."""
    def _lower_stmt_list(
        stmts: list, owner: object, anchor: uni.UniNode, acc_name_str: str = VIEW_ACC
    ) -> list {
        new_stmts: list = [];
        for s in stmts {
            new_stmts.append(self._lower_one(s, anchor, acc_name_str));
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
    unchanged; nested `def` bodies are deliberately not descended into.
    `acc_name_str` threads the accumulator name through recursive lowerings."""
    def _lower_one(
        stmt: object, anchor: uni.UniNode, acc_name_str: str = VIEW_ACC
    ) -> object {
        s = stmt;
        if isinstance(s, uni.ExprStmt) {
            if isinstance(s.expr, uni.JsxElement) {
                return self._make_append(s.expr, anchor, acc_name_str);
            }
            return s;
        }
        if isinstance(s, uni.ReturnStmt) {
            # A bare `return;` was already flagged E2020 and a value-form
            # `return expr;` E2019; lowering them both into the fragment-
            # guard shape keeps the pass robust against the diagnosed
            # source (no spurious type errors downstream). New code should
            # use `skip;` (handled below).
            frag = self._make_fragment(anchor, acc_name_str);
            ret_uni = self._synth_tok("KW_RETURN", "return", anchor);
            s.expr = frag;
            s.set_kids([ret_uni, frag, self._synth_semi(anchor)]);
            return s;
        }
        if isinstance(s, uni.CtrlStmt) and s.ctrl.value == "skip" {
            # `skip;` is the slot early-exit: rewrite to
            # `return <>{acc}</>;` so the slot's IIFE returns the
            # accumulated fragment up to this point. `break;` and
            # `continue;` pass through to their normal JS lowering.
            frag = self._make_fragment(anchor, acc_name_str);
            ret_uni = self._synth_tok("KW_RETURN", "return", anchor);
            ret = uni.ReturnStmt(
                expr=frag, kid=[ret_uni, frag, self._synth_semi(anchor)]
            );
            return ret;
        }
        if isinstance(s, uni.IfStmt) {
            # IfStmt also matches ElseIf (a subclass).
            s.body = self._lower_stmt_list(s.body, s, anchor, acc_name_str);
            if s.else_body is not None {
                self._lower_one(s.else_body, anchor, acc_name_str);
            }
            return s;
        }
        if isinstance(s, uni.ElseStmt) {
            s.body = self._lower_stmt_list(s.body, s, anchor, acc_name_str);
            return s;
        }
        if isinstance(s, uni.WhileStmt)
        or isinstance(s, uni.InForStmt)
        or isinstance(s, uni.IterForStmt) {
            s.body = self._lower_stmt_list(s.body, s, anchor, acc_name_str);
            if s.else_body is not None {
                self._lower_one(s.else_body, anchor, acc_name_str);
            }
            return s;
        }
        if isinstance(s, uni.WithStmt) {
            s.body = self._lower_stmt_list(s.body, s, anchor, acc_name_str);
            return s;
        }
        if isinstance(s, uni.TryStmt) {
            # A `try` with an `awaiting` clause shifts the rendering model:
            # only one branch (fallback / resolved / failed) renders at a
            # time, instead of all branches contributing to the accumulator.
            # On the `cl` target the whole TryStmt is replaced by a single
            # `<JacAwaiting fallback={...}>{...}</JacAwaiting>` wrapper that
            # forwards to React's Suspense; on `sv`/`na` we warn (W2020)
            # and drop the awaiting body so the rest of the lowering treats
            # the construct as an ordinary try.
            if s.awaiting_body is not None {
                return self._lower_try_with_awaiting(s, anchor, acc_name_str);
            }
            s.body = self._lower_stmt_list(s.body, s, anchor, acc_name_str);
            for ex in s.excepts {
                self._lower_one(ex, anchor, acc_name_str);
            }
            if s.else_body is not None {
                self._lower_one(s.else_body, anchor, acc_name_str);
            }
            if s.finally_body is not None {
                self._lower_one(s.finally_body, anchor, acc_name_str);
            }
            return s;
        }
        if isinstance(s, uni.Except) or isinstance(s, uni.FinallyStmt) {
            s.body = self._lower_stmt_list(s.body, s, anchor, acc_name_str);
            return s;
        }
        if isinstance(s, uni.MatchStmt) {
            for cs in s.cases {
                self._lower_one(cs, anchor, acc_name_str);
            }
            return s;
        }
        if isinstance(s, uni.SwitchStmt) {
            for cs in s.cases {
                self._lower_one(cs, anchor, acc_name_str);
            }
            return s;
        }
        if isinstance(s, uni.MatchCase) or isinstance(s, uni.SwitchCase) {
            s.body = self._lower_stmt_list(s.body, s, anchor, acc_name_str);
            return s;
        }
        return s;
    }

    """Build `acc.append(<jsx>);` — append one template element in O(1)."""
    def _make_append(
        jsx: uni.Expr, anchor: uni.UniNode, acc_name_str: str = VIEW_ACC
    ) -> uni.ExprStmt {
        acc_ref = self._synth_name(acc_name_str, anchor);
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
    def _make_fragment(
        anchor: uni.UniNode, acc_name_str: str = VIEW_ACC
    ) -> uni.JsxElement {
        lb = self._synth_tok("LBRACE", "{", anchor);
        acc_ref = self._synth_name(acc_name_str, anchor);
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

    # ----- awaiting-clause lowering ----------------------------------------
    """Lower a `try { ... } awaiting { ... }` (and friends) inside a slot.

    On the `cl` target this becomes a single
    `acc.append(<JacAwaiting fallback={<>{lowered-awaiting}</>}>{lowered-try}</JacAwaiting>);`
    statement — the React Suspense + ErrorBoundary wrap that the
    `@jac/runtime`'s `JacAwaiting` component supplies, with the try body's
    JSX as children and the awaiting body's JSX as the fallback.

    On `sv`/`na` the wrapper has no analogue yet, so we emit W2020 and
    fall through to the ordinary try lowering (the `awaiting` body is
    silently dropped so it doesn't double-render through the accumulator).

    Diagnostics enforced here:
      * E2022 — `finally` is incompatible with `awaiting`; the finally body
        is stripped after the error to keep lowering well-formed.
      * W2020 — `awaiting` on a non-`cl` target."""
    def _lower_try_with_awaiting(
        s: uni.TryStmt, anchor: uni.UniNode, acc_name_str: str = VIEW_ACC
    ) -> uni.UniNode {
        if s.finally_body is not None {
            self.emit(E2022, node_override=s);
            s.finally_body = None;
        }
        if not s.in_client_context() {
            target = "na" if s.in_native_context() else "sv";
            self.emit(W2020, node_override=s, target=target);
            # Leave `awaiting_body` on the AST as a render no-op: downstream
            # codegen passes (pyast_gen_pass, na_ir_gen_pass) iterate
            # `body`/`excepts`/`else_body`/`finally_body` only, so the
            # awaiting clause's statements naturally don't reach the
            # generated runtime — they just remain attached for source-
            # level passes (the formatter round-trips them; the validation
            # pass treats `awaiting` as a satisfying clause for E0040).
            s.body = self._lower_stmt_list(s.body, s, anchor, acc_name_str);
            for ex in s.excepts {
                self._lower_one(ex, anchor, acc_name_str);
            }
            if s.else_body is not None {
                self._lower_one(s.else_body, anchor, acc_name_str);
            }
            return s;
        }
        try_stmts: list = list(s.body);
        awaiting_stmts: list = list(s.awaiting_body.body);
        jsx_awaiting = self._make_jac_awaiting(try_stmts, awaiting_stmts, anchor);
        return self._make_append(jsx_awaiting, anchor, acc_name_str);
    }

    """Synthesize `<JacAwaiting fallback={<>{...awaiting}</>}>{...try}</JacAwaiting>`.

    Both branch bodies are wrapped in synthetic `JsxSlot`s so the
    es-codegen turns them into inline IIFEs that return their
    accumulated JSX fragment. The `fallback` attribute additionally
    wraps the slot in a JSX fragment so the attribute value is a plain
    `Expression` (a slot is a `JsxChild`, not an `Expr`)."""
    def _make_jac_awaiting(
        try_stmts: list, awaiting_stmts: list, anchor: uni.UniNode
    ) -> uni.JsxElement {
        name_part = self._synth_name("JacAwaiting", anchor);
        el_name = uni.JsxElementName(parts=[name_part], kid=[name_part]);
        fallback_attr = self._make_attr_expr(
            "fallback", self._make_fragment_with_slot(awaiting_stmts, anchor), anchor
        );
        try_slot = self._make_synthetic_slot(try_stmts, anchor);
        open_lt = self._synth_tok(Tok.LT.value, "<", anchor);
        open_gt = self._synth_tok(Tok.GT.value, ">", anchor);
        close_open = self._synth_tok(Tok.LT.value, "<", anchor);
        slash_tok = self._synth_tok(Tok.DIV.value, "/", anchor);
        close_name = self._synth_name("JacAwaiting", anchor);
        close_gt = self._synth_tok(Tok.GT.value, ">", anchor);
        kid: list = [
            open_lt,
            el_name,
            fallback_attr,
            open_gt,
            try_slot,
            close_open,
            slash_tok,
            close_name,
            close_gt
        ];
        return uni.JsxElement(
            name=el_name,
            attributes=[fallback_attr],
            children=[try_slot],
            is_self_closing=False,
            is_fragment=False,
            kid=kid,
            dynamic_tag=None
        );
    }

    """Build a `JsxSlot` whose body is the lowered statement list.

    `_lower_body` produces the canonical slot-body shape (`acc = []; ...
    pushes ...; return <>{acc}</>;`) which the ES codegen wraps in an
    inline IIFE — so the slot's value is the rendered fragment.

    Each synthetic slot gets a uniquely-suffixed accumulator name so
    nested IIFEs don't share JS bindings with their parent slot
    (`__jac_view_kids_1`, `__jac_view_kids_2`, …)."""
    def _make_synthetic_slot(stmts: list, anchor: uni.UniNode) -> uni.JsxSlot {
        self._nested_acc_counter += 1;
        acc_name = f"{VIEW_ACC}_{self._nested_acc_counter}";
        self._check_body(stmts, False, "");
        lowered = self._lower_body(stmts, anchor=anchor, acc_name_str=acc_name);
        lb = self._synth_tok(Tok.LBRACE.value, "{", anchor);
        rb = self._synth_tok(Tok.RBRACE.value, "}", anchor);
        kid: list = [lb];
        kid.extend(lowered);
        kid.append(rb);
        return uni.JsxSlot(body=lowered, kid=kid);
    }

    """Wrap a synthetic `JsxSlot` in a `<>{...}</>` fragment so it can be
    used where a plain `Expression` is required (e.g. a JSX attribute
    value)."""
    def _make_fragment_with_slot(stmts: list, anchor: uni.UniNode) -> uni.JsxElement {
        slot = self._make_synthetic_slot(stmts, anchor);
        return uni.JsxElement(
            name=None,
            attributes=[],
            children=[slot],
            is_self_closing=False,
            is_fragment=True,
            kid=[
                self._synth_tok("JSX_FRAG_OPEN", "<>", anchor),
                slot,
                self._synth_tok("JSX_FRAG_CLOSE", "</>", anchor)
            ]
        );
    }

    """Build a `JsxNormalAttribute` of the form `name={value_expr}`."""
    def _make_attr_expr(
        attr_name: str, value_expr: uni.Expr, anchor: uni.UniNode
    ) -> uni.JsxNormalAttribute {
        name_tok = self._synth_tok(Tok.JSX_NAME.value, attr_name, anchor);
        eq_tok = self._synth_tok(Tok.EQ.value, "=", anchor);
        lb_tok = self._synth_tok(Tok.LBRACE.value, "{", anchor);
        rb_tok = self._synth_tok(Tok.RBRACE.value, "}", anchor);
        return uni.JsxNormalAttribute(
            name=name_tok,
            value=value_expr,
            kid=[name_tok, eq_tok, lb_tok, value_expr, rb_tok]
        );
    }
}
