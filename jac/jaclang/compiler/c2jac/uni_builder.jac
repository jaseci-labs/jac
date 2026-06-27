"""Direct-IR path: pycparser C-AST → uni nodes for constructs with no Python-AST analog.

Covers P1d: C-for (→ IterForStmt) and enums (→ uni.Enum or glob GlobalVars).
Used by the driver's splice step after PyastBuildPass has built the base uni tree.
"""

import jaclang.jac0core.unitree as uni;
import from pycparser { c_ast }
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.compiler.c2jac.tags { Tier, Mechanism, Idiom, NodeTag, TagTable }
import from jaclang.compiler.c2jac.enum_prepass { EnumVerdicts }
import from jaclang.compiler.c2jac.c_common {
    C_BINOPS,
    C_AUGOPS,
    parse_c_int,
    parse_c_float,
    coord_of,
    classify_c_constant,
    c_char_ord,
    c_string_inner,
    expr_reeval_safe,
    has_loop_continue,
    switch_is_safe,
    section_terminates,
    is_simple_ref,
    cast_scalar_target,
    CLIT_INT,
    CLIT_FLOAT,
    CLIT_CHAR,
    CLIT_STRING
}

obj CUniBuilder {
    has src: uni.Source,
        tags: TagTable,
        enum_verdicts: EnumVerdicts,
        # Accumulates the names of C-for body constructs that could not be
        # faithfully lowered during the most recent loop build. A non-empty list
        # forces the enclosing loop to Tier-B so the Tier-B comments never claim
        # faithful coverage of a body it actually dropped. Reset at each loop entry.
        _loop_lossy: list[str] = [],
        # Set when a C-for/while loop had a real condition expression that could
        # not be lowered and was replaced by a bare `True`. Tracked separately
        # from _loop_lossy because the condition is built before that list is
        # reset, and its Tier-B reason is distinct from a dropped body construct.
        _cond_lossy: bool = False,
        # Set when the loop body being scanned contains a `continue` that binds
        # to *this* loop (not a nested loop — those are snapshot/restored around
        # the nested-loop recursion). Load-bearing for the while-desugar Tier-A
        # promotion: C `continue` jumps to the for-step, but the desugared
        # `body; step` runs `continue` *before* the step, so a loop-level
        # `continue` makes the desugar unfaithful — *but only when a step exists*.
        # With no step (e.g. `for (;;)` / `for (; cond; )`) there is nothing for
        # `continue` to skip, so it stays faithful; the Tier-A gate therefore
        # pairs this flag with step presence (see _for_as_while).
        _loop_has_continue: bool = False;

    def init(src: uni.Source, tags: TagTable, enum_verdicts: EnumVerdicts) {
        self.src = src;
        self.tags = tags;
        self.enum_verdicts = enum_verdicts;
        self._loop_lossy = [];
        self._cond_lossy = False;
        self._loop_has_continue = False;
    }

    # ------------------------------------------------------------------ #
    # Token factory                                                         #
    # ------------------------------------------------------------------ #
    def _tok(name: str, value: str, line: int, col: int) -> uni.Token {
        return uni.Token(
            orig_src=self.src,
            name=name,
            value=value,
            line=line,
            end_line=line,
            col_start=col,
            col_end=col + len(value),
            pos_start=0,
            pos_end=len(value),
        );
    }

    def _name_node(value: str, line: int, col: int) -> uni.Name {
        return uni.Name(
            orig_src=self.src,
            name="NAME",
            value=value,
            line=line,
            end_line=line,
            col_start=col,
            col_end=col + len(value),
            pos_start=0,
            pos_end=len(value),
        );
    }

    def _int_node(value: int, line: int, col: int) -> uni.Int {
        sv = str(value);
        return uni.Int(
            orig_src=self.src,
            name="INT",
            value=sv,
            line=line,
            end_line=line,
            col_start=col,
            col_end=col + len(sv),
            pos_start=0,
            pos_end=len(sv),
        );
    }

    def _string_node(value: str, line: int, col: int) -> uni.String {
        # `value` is the raw C string literal *including* its surrounding quotes
        # (e.g. `"hi"` / `"\n"`). DocIRGenPass.exit_string emits nd.value
        # verbatim, so the quotes and escapes must already be part of it — unlike
        # the Python-AST mapper, there is no later re-slice from the C source here.
        return uni.String(
            orig_src=self.src,
            name="STRING",
            value=value,
            line=line,
            end_line=line,
            col_start=col,
            col_end=col + len(value),
            pos_start=0,
            pos_end=len(value),
        );
    }

    def _coord(c_node: object) -> tuple[int, int] {
        # Direct-IR builder has no running line cursor; fall back to line 1.
        return coord_of(c_node, 1);
    }

    # ------------------------------------------------------------------ #
    # Main dispatch                                                         #
    # ------------------------------------------------------------------ #
    def build(c_node: object) -> list[uni.UniNode] {
        tp = type(c_node).__name__;
        if tp == "For" {
            return self._build_for(c_node);
        }
        if tp == "Enum" {
            return self._build_enum(c_node);
        }
        # Fallthrough — shouldn't happen; return empty.
        return [];
    }

    def _mark_tier_b(c_node: object, line: int, reason: str) {
        self.tags.tag(
            c_node,
            NodeTag(
                tier=Tier.TIER_B,
                mechanism=Mechanism.DIRECT_IR,
                idiom=Idiom.TIER_B,
                reason=reason,
                c_line=line,
                snippet=reason,
            )
        );
    }

    def _mark_tier_a(c_node: object, line: int, reason: str) {
        # Stamp a faithfully-lowered C-for as Tier-A with the C_FOR idiom. The
        # default_tier table already maps For → Tier-A, but the while-desugar
        # always overwrote that with _mark_tier_b; re-stamp Tier-A explicitly so
        # the verdict is queryable (TagTable.by_idiom) and the reason records
        # *why* the desugar is faithful rather than leaving a stale Tier-B tag.
        self._mark_tier_a_idiom(c_node, line, Idiom.C_FOR, reason);
    }

    def _mark_tier_a_idiom(c_node: object, line: int, idiom: Idiom, reason: str) {
        # Stamp a faithfully-lowered direct-IR construct Tier-A with a specific
        # idiom. A nested DoWhile/Switch is NOT on the boundary Tier-A allowlist
        # (the py-ast path's handler decides their verdict), so without this
        # re-stamp a clean nested do-while/switch would keep its default Tier-B
        # tag (empty reason) and show as a phantom best-effort site even though it
        # lowered exactly — the same hazard the EmptyStatement/Ternary allowlist
        # entries fix on the py-ast side.
        self.tags.tag(
            c_node,
            NodeTag(
                tier=Tier.TIER_A,
                mechanism=Mechanism.DIRECT_IR,
                idiom=idiom,
                reason=reason,
                c_line=line,
                snippet=reason,
            )
        );
    }

    # ------------------------------------------------------------------ #
    # C-for → IterForStmt                                                  #
    # ------------------------------------------------------------------ #
    def _build_for(nd: object) -> list[uni.UniNode] {
        (line, col) = self._coord(nd);
        # Reset the loss accumulator up front, BEFORE the init/cond/step builds,
        # so a representation-changing scalar cast in any clause (e.g.
        # `for (; i < (int)n; )`) counts toward the Tier-B verdict — not just one
        # in the body. (It used to reset after, wiping clause-level cast marks
        # and presenting a narrowed loop as faithful Tier-A.)
        self._loop_lossy = [];
        # Parse the init, cond, and step from the C-for node.
        init_nodes = self._for_init(getattr(nd, "init"), line, col);
        cond_expr = self._for_cond(nd.cond, line, col);
        step_assign = self._for_step(nd.next, line, col);
        body_stmts = self._for_body(nd.stmt, line, col);

        if init_nodes is None or cond_expr is None or step_assign is None {
            # Can't build IterForStmt — fall back to a faithful while-desugar
            # (preserves init/cond/body/step instead of dropping them). That path
            # rebuilds (and re-scans) the body itself, so the lossy list collected
            # above is discarded there.
            return self._for_as_while(nd, line, col);
        }
        if self._loop_lossy {
            # Body shape was lowered, but at least one statement could not be
            # represented faithfully (e.g. a nested loop, switch, call). Mark the
            # whole loop Tier-B so the report flags it rather than presenting a
            # silently-truncated body as faithful.
            self._mark_tier_b(
                nd,
                line,
                "C-for body contains constructs not faithfully lowered: " + ", ".join(
                    sorted(set(self._loop_lossy))
                ),
            );
        }
        return [
            uni.IterForStmt(
                kid=[init_nodes, cond_expr, step_assign, *body_stmts],
                iter=init_nodes,
                condition=cond_expr,
                count_by=step_assign,
                body=body_stmts,
                else_body=None,
                is_async=False,
            )
        ];
    }

    def _for_init(init_node: object, line: int, col: int) -> uni.Assignment | None {
        if init_node is None {
            # No init — emit i = 0 dummy.
            dummy = self._name_node("_c2jac_i", line, col);
            zero = self._int_node(0, line, col);
            return uni.Assignment(
                kid=[dummy, zero],
                target=[dummy],
                value=zero,
                type_tag=None,
                mutable=True,
                aug_op=None,
                is_enum_stmt=False
            );
        }

        # DeclList or Assignment?
        if isinstance(init_node, c_ast.DeclList) {
            # DeclList with one decl — multi-decl is handled upstream by _for_init_list.
            if len(init_node.decls) == 1 {
                return self._decl_to_assign(init_node.decls[0], line, col);
            }
            return None;
        }
        if isinstance(init_node, c_ast.Assignment) {
            return self._assign_to_uni_assign(init_node, line, col);
        }
        if isinstance(init_node, c_ast.Decl) {
            return self._decl_to_assign(init_node, line, col);
        }
        return None;
    }

    def _for_init_list(
        init_node: object, line: int, col: int
    ) -> list[uni.UniNode] | None {
        # The while-desugar can emit several statements before the loop, so a
        # multi-clause init lowers to one assignment per clause — unlike the
        # IterForStmt path, whose single `iter=` slot holds only one (which is
        # why _for_init returns None for these shapes and routes the loop here).
        # Two C forms reach this helper:
        #   • `for (int i = 0, j = 0; ...)` — a DeclList of initialized decls
        #   • `for (i = 0, j = 10; ...)`     — an ExprList (comma) of assignments
        # Each clause is lowered independently; if ANY clause can't be lowered
        # faithfully the whole init is abandoned (return None) so the caller
        # flags init-loss and keeps the loop out of Tier-A rather than emitting a
        # partial initializer that leaves some loop variable unset.
        if isinstance(init_node, c_ast.DeclList) {
            out: list[uni.UniNode] = [];
            for d in init_node.decls {
                a = self._decl_to_assign(d, line, col);
                if a is None {
                    return None;
                }
                out.append(a);
            }
            return out;
        }
        if isinstance(init_node, c_ast.ExprList) {
            # A comma init `for (i = 0, j = 10; ...)` evaluates each operand
            # left-to-right before the loop, so each lowers to its own pre-loop
            # statement. Beyond plain assignments, an operand may be an `i++`/`i--`
            # (→ augmented assignment) or a bare call `init_things()` (→ expression
            # statement) — all faithful as pre-loop statements. Any other operand
            # (or one whose sub-lowering fails) has no pre-loop analog, so bail to
            # keep the init from being partially emitted (loop vars left unset).
            out2: list[uni.UniNode] = [];
            for e in init_node.exprs {
                s2 = self._comma_init_stmt(e, line, col);
                if s2 is None {
                    return None;
                }
                out2.append(s2);
            }
            return out2;
        }
        single = self._for_init(init_node, line, col);
        if single is None {
            return None;
        }
        return [single];
    }

    def _comma_init_stmt(e: object, line: int, col: int) -> uni.UniNode | None {
        # One operand of a comma init `for (a = 0, b(), c++; ...)` as a pre-loop
        # statement. Assignment → assignment; `c++`/`c--` → augmented assignment
        # (via the step lowering); a bare call → an expression statement. Anything
        # else returns None so _for_init_list abandons the whole init rather than
        # emitting a partial one.
        if isinstance(e, c_ast.Assignment) {
            return self._assign_to_uni_assign(e, line, col);
        }
        if isinstance(e, c_ast.UnaryOp) and e.op in ("p++", "++", "p--", "--") {
            return self._step_as_stmt(e, line, col);
        }
        if isinstance(e, c_ast.FuncCall) {
            call = self._funccall_to_uni(e, line, col);
            if call is not None {
                return uni.ExprStmt(expr=call, in_fstring=False, kid=[call]);
            }
        }
        return None;
    }

    def _decl_to_assign(decl: object, line: int, col: int) -> uni.Assignment | None {
        decl_init = getattr(decl, "init");
        if decl.name is None or decl_init is None {
            return None;
        }
        (dline, dcol) = self._coord(decl);
        name_n = self._name_node(decl.name, dline, dcol);
        val = self._expr_to_uni(decl_init, dline, dcol);
        if val is None {
            return None;
        }
        return uni.Assignment(
            kid=[name_n, val],
            target=[name_n],
            value=val,
            type_tag=None,
            mutable=True,
            aug_op=None,
            is_enum_stmt=False
        );
    }

    def _assign_to_uni_assign(
        nd: object, line: int, col: int
    ) -> uni.Assignment | None {
        (aline, acol) = self._coord(nd);
        lhs = self._lvalue_to_uni(nd.lvalue, aline, acol);
        rhs = self._expr_to_uni(nd.rvalue, aline, acol);
        if lhs is None or rhs is None {
            return None;
        }
        aug = self._c_op_to_aug_tok(nd.op, aline, acol);
        if nd.op == "=" {
            return uni.Assignment(
                kid=[lhs, rhs],
                target=[lhs],
                value=rhs,
                type_tag=None,
                mutable=True,
                aug_op=None,
                is_enum_stmt=False
            );
        }
        if aug is None {
            return None;
        }
        return uni.Assignment(
            kid=[lhs, aug, rhs],
            target=[lhs],
            value=rhs,
            type_tag=None,
            mutable=True,
            aug_op=aug,
            is_enum_stmt=False
        );
    }

    def _for_cond(cond_node: object, line: int, col: int) -> uni.Expr | None {
        if cond_node is None {
            # Infinite loop (for(;;)) — fall back to WhileStmt via caller.
            return None;
        }
        # IterForStmt lowers to `while <condition>: { body; count_by }`, so the
        # condition is the FULL boolean expression (e.g. `i < n`), not just the
        # upper bound. Only canonical ascending comparisons map cleanly here;
        # anything else (descending, compound, calls) routes to the faithful
        # while-desugar via the caller's None check.
        if isinstance(cond_node, c_ast.BinaryOp)
        and cond_node.op in ("<", "<=", "!=") {
            return self._expr_to_uni(cond_node, line, col);
        }
        return None;
    }

    def _for_step(step_node: object, line: int, col: int) -> uni.Assignment | None {
        # IterForStmt appends count_by as the last statement of the desugared
        # while body, so it must be the FULL augmented assignment (e.g. `i += 1`),
        # not just the step magnitude. A plain `i = ...` step is not a valid `by`
        # clause (the parser only accepts augmented assignments there), so it
        # returns None and the caller routes the loop to the while-desugar.
        step = self._step_as_stmt(step_node, line, col);
        if isinstance(step, uni.Assignment) and step.aug_op is not None {
            return step;
        }
        return None;
    }

    def _c_stmt_to_uni(stmt: object, line: int, col: int) -> list[uni.UniNode] {
        if stmt is None {
            return [];
        }
        (sline, scol) = self._coord(stmt);

        if isinstance(stmt, c_ast.Compound) {
            items: list[uni.UniNode] = [];
            if stmt.block_items {
                for item in stmt.block_items {
                    items.extend(self._c_stmt_to_uni(item, sline, scol));
                }
            }
            return items;
        }

        if isinstance(stmt, c_ast.Continue) {
            # This `continue` binds to the loop currently being scanned (nested
            # loops snapshot/restore this flag around their recursion). Record it
            # so a while-desugar of that loop can't be promoted to Tier-A — the
            # desugared `continue` skips the step that C `continue` would run.
            self._loop_has_continue = True;
            cont_tok = self._tok(Tok.KW_CONTINUE, "continue", sline, scol);
            return [uni.CtrlStmt(kid=[cont_tok], ctrl=cont_tok)];
        }

        if isinstance(stmt, c_ast.Break) {
            brk_tok = self._tok(Tok.KW_BREAK, "break", sline, scol);
            return [uni.CtrlStmt(kid=[brk_tok], ctrl=brk_tok)];
        }

        if isinstance(stmt, c_ast.If) {
            cond = self._expr_to_uni(stmt.cond, sline, scol);
            if cond is None {
                self._loop_lossy.append("if condition");
                return [];
            }
            body_stmts = self._c_stmt_to_uni(stmt.iftrue, sline, scol);
            else_body = self._c_else_to_uni(getattr(stmt, "iffalse"), sline, scol);
            if_kid: list[uni.UniNode] = [cond, *body_stmts];
            if else_body is not None {
                if_kid.append(else_body);
            }
            return [
                uni.IfStmt(
                    kid=if_kid, condition=cond, body=body_stmts, else_body=else_body,
                )
            ];
        }

        if isinstance(stmt, c_ast.Return) {
            return self._return_to_uni(stmt, sline, scol);
        }

        if isinstance(stmt, c_ast.Assignment) {
            result_a = self._assign_to_uni_assign(stmt, sline, scol);
            if result_a is not None {
                return [result_a];
            }
            self._loop_lossy.append("assignment");
            return [];
        }

        if isinstance(stmt, c_ast.Decl) {
            result_d = self._decl_to_assign(stmt, sline, scol);
            if result_d is not None {
                return [result_d];
            }
            # Uninitialized or non-scalar local decl: no faithful Jac analog in
            # the direct-IR path (no type lowering here). Drop but flag, so the
            # loop demotes to Tier-B instead of silently losing the declaration.
            self._loop_lossy.append("uninitialized/complex local declaration");
            return [];
        }

        if isinstance(stmt, c_ast.FuncCall) {
            call = self._funccall_to_uni(stmt, sline, scol);
            if call is not None {
                return [uni.ExprStmt(expr=call, in_fstring=False, kid=[call])];
            }
            self._loop_lossy.append("function call");
            return [];
        }

        if isinstance(stmt, c_ast.While) {
            wcond = self._expr_to_uni(stmt.cond, sline, scol);
            if wcond is None {
                self._loop_lossy.append("while condition");
                return [];
            }
            # A `continue` inside this nested while binds to the *while*, not the
            # enclosing for. Snapshot/restore _loop_has_continue so it isn't
            # mis-attributed to the outer loop's continue-faithfulness verdict.
            saved_cont = self._loop_has_continue;
            wbody = self._c_stmt_to_uni(stmt.stmt, sline, scol);
            self._loop_has_continue = saved_cont;
            return [
                uni.WhileStmt(
                    kid=[wcond, *wbody], condition=wcond, body=wbody, else_body=None,
                )
            ];
        }

        if isinstance(stmt, c_ast.For) {
            # Recurse through the full for-builder so a nested loop gets the same
            # IterForStmt-or-while-desugar treatment (and its own Tier-B marking).
            # _build_for resets self._loop_lossy (and the nested loop's own body
            # scan drives _loop_has_continue), so snapshot and restore both outer
            # accumulators around the call to avoid cross-contaminating which loop
            # is flagged or whose `continue` is counted.
            saved = self._loop_lossy;
            saved_cont = self._loop_has_continue;
            inner = self._build_for(stmt);
            self._loop_lossy = saved;
            self._loop_has_continue = saved_cont;
            return inner;
        }

        if isinstance(stmt, c_ast.Cast) {
            # A bare `(int)i;` cast-expression statement: lower the inner expr
            # (the result is discarded, but a side-effecting operand must still
            # run). _expr_to_uni records the scalar-cast loss itself, so a clean
            # pointer cast stays Tier-A and a scalar cast demotes the loop.
            cast_expr = self._expr_to_uni(stmt, sline, scol);
            if cast_expr is not None {
                return [
                    uni.ExprStmt(expr=cast_expr, in_fstring=False, kid=[cast_expr])
                ];
            }
            self._loop_lossy.append("cast expression");
            return [];
        }

        if isinstance(stmt, c_ast.EmptyStatement) {
            # A stray `;` carries no semantics — drop it silently. Routing it
            # through the generic fallback below would flag a no-op as a Tier-B
            # body loss, demoting an otherwise-faithful loop over nothing.
            return [];
        }

        if isinstance(stmt, c_ast.UnaryOp) {
            # A bare `i++;` / `i--;` increment statement → augmented assignment
            # (the same lowering as a for-step). Other unary expression
            # statements (`!x;`, `~x;`, a simple `*p;`) lower as a discarded
            # expression statement; an unmappable form flags the loss so the
            # enclosing loop demotes rather than silently dropping it.
            if stmt.op in ("p++", "++", "p--", "--") {
                inc = self._step_as_stmt(stmt, sline, scol);
                if inc is not None {
                    return [inc];
                }
                self._loop_lossy.append("increment/decrement statement");
                return [];
            }
            ue = self._expr_to_uni(stmt, sline, scol);
            if ue is not None {
                return [uni.ExprStmt(expr=ue, in_fstring=False, kid=[ue])];
            }
            self._loop_lossy.append("unary expression statement");
            return [];
        }

        if isinstance(stmt, c_ast.DoWhile) {
            # A nested `do { body } while (cond);` desugars to the faithful
            # `while True { body; if not cond break }` (mirrors mapper.c_DoWhile).
            # _dowhile_to_uni flags the one hazard — a loop-level `continue` that
            # would skip the post-body condition test — so a clean nested
            # do-while stays Tier-A and a continue-bearing one demotes the loop.
            return self._dowhile_to_uni(stmt, sline, scol);
        }

        if isinstance(stmt, c_ast.Switch) {
            # A nested `switch` lowers to an if/elif/else chain (mirrors
            # mapper.c_Switch). _switch_to_uni flags the lossy shapes
            # (case fall-through between body-bearing sections, a side-effecting
            # selector re-evaluated per branch), so a clean nested switch stays
            # Tier-A and a lossy one demotes the enclosing loop.
            return self._switch_to_uni(stmt, sline, scol);
        }

        # Any other statement (goto, labels, ...) has no direct-IR lowering yet.
        # Record it so the enclosing loop is Tier-B.
        self._loop_lossy.append(type(stmt).__name__);
        return [];
    }

    def _c_else_to_uni(else_node: object, line: int, col: int) -> uni.UniNode | None {
        # Lower a C `else` arm. A bare `else if` reaches here as a nested c_ast.If;
        # mirror PyastBuildPass.proc_if by collapsing the single-If case into an
        # ElseIf chain, otherwise wrap the statements in an ElseStmt.
        if else_node is None {
            return None;
        }
        else_stmts = self._c_stmt_to_uni(else_node, line, col);
        if (
            isinstance(else_node, c_ast.If)
            and len(else_stmts) == 1
            and isinstance(else_stmts[0], uni.IfStmt)
        ) {
            inner = else_stmts[0];
            return uni.ElseIf(
                condition=inner.condition,
                body=inner.body,
                else_body=inner.else_body,
                kid=inner.kid,
            );
        }
        return uni.ElseStmt(body=else_stmts, kid=[*else_stmts]);
    }

    def _dowhile_to_uni(stmt: object, line: int, col: int) -> list[uni.UniNode] {
        # `do { body } while (cond);` has no Jac analog. Desugar to the faithful
        # `while True { body; if not cond { break } }` — body runs once before the
        # test, exactly like do-while (mirrors mapper.c_DoWhile). The one semantic
        # gap is a loop-level `continue`: in C it jumps to the post-body condition
        # test, but here it re-enters the loop top and skips the `if not cond`
        # guard, so the loop would spin without re-checking cond. Flag that case
        # (demoting the enclosing loop); the common continue-free do-while stays
        # faithful and keeps the loop Tier-A.
        cond = self._expr_to_uni(stmt.cond, line, col);
        if cond is None {
            self._loop_lossy.append("do-while condition");
            self._mark_tier_b(
                stmt,
                line,
                "do-while condition not faithfully lowered; the loop was dropped "
                "— verify",
            );
            return [];
        }
        # A `continue` inside this do-while binds to IT, not the enclosing for —
        # snapshot/restore the outer flag around the body scan so it isn't
        # mis-attributed to the for's continue-faithfulness verdict.
        saved_cont = self._loop_has_continue;
        body = self._c_stmt_to_uni(stmt.stmt, line, col);
        self._loop_has_continue = saved_cont;
        if has_loop_continue(stmt.stmt) {
            # Unfaithful: the desugared `continue` skips the post-body cond test.
            # Flag the do-while node precisely AND demote the enclosing loop (its
            # body now contains an unfaithfully-lowered construct).
            self._loop_lossy.append(
                "do-while with a loop-level continue (C runs the post-body "
                "condition test; the desugared continue skips it)"
            );
            self._mark_tier_b(
                stmt,
                line,
                "do-while desugared to `while True`/break; a loop-level `continue` "
                "skips the post-body condition test (C runs it) — verify",
            );
        } else {
            self._mark_tier_a_idiom(
                stmt,
                line,
                Idiom.DO_WHILE,
                "do-while desugared to `while True { body; if not cond break }` — "
                "faithful: body runs once before the test and no loop-level "
                "`continue` skips the post-body condition check",
            );
        }
        not_tok = self._tok(Tok.NOT, "not", line, col);
        not_cond = uni.UnaryExpr(kid=[not_tok, cond], operand=cond, op=not_tok);
        brk_tok = self._tok(Tok.KW_BREAK, "break", line, col);
        brk = uni.CtrlStmt(kid=[brk_tok], ctrl=brk_tok);
        guard = uni.IfStmt(
            kid=[not_cond, brk], condition=not_cond, body=[brk], else_body=None
        );
        full_body: list[uni.UniNode] = [*body, guard];
        true_c = uni.Bool(
            orig_src=self.src,
            name="BOOL",
            value="True",
            line=line,
            end_line=line,
            col_start=col,
            col_end=col + 4,
            pos_start=0,
            pos_end=4,
        );
        return [
            uni.WhileStmt(
                kid=[true_c, *full_body],
                condition=true_c,
                body=full_body,
                else_body=None,
            )
        ];
    }

    def _switch_to_uni(nd: object, line: int, col: int) -> list[uni.UniNode] {
        # C `switch` → nested if/elif/else (mirrors mapper.c_Switch). pycparser
        # nests each Case/Default as a block_item carrying its own statement list;
        # empty-statement cases (`case 1: case 2: ...`) fold their labels onto the
        # next body-bearing case, modelling `selector == 1 or selector == 2`. The
        # clean, common shape (every body-bearing case ends in break/return/
        # continue, pure selector) lowers exactly and keeps the loop Tier-A; only
        # the lossy shapes (case fall-through between body-bearing sections — which
        # if/elif cannot model — or a side-effecting selector re-evaluated per
        # branch) flag a loss and demote the enclosing loop.
        groups: list[tuple] = [];  # (list[c_value_node], list[c_stmt_node])
        pending: list[object] = [];
        default_stmts: list | None = None;
        items: list = [];
        if isinstance(nd.stmt, c_ast.Compound) and nd.stmt.block_items {
            items = nd.stmt.block_items;
        }
        for it in items {
            if isinstance(it, c_ast.Case) {
                pending.append(it.expr);
                if it.stmts {
                    groups.append((pending, it.stmts));
                    pending = [];
                }
            } elif isinstance(it, c_ast.Default) {
                # Empty `case` labels just before a `default` fall INTO it (an
                # empty case has no break), so they belong to the default
                # catch-all, not the next body-bearing case — drop them from
                # `pending` so their selector values don't leak onto a later
                # case's `==` test.
                pending = [];
                default_stmts = it.stmts or [];
            }
        }
        if not switch_is_safe(items, nd.cond) {
            # Lossy shape: flag the switch node precisely AND demote the enclosing
            # loop (its body now contains an unfaithfully-lowered construct).
            self._loop_lossy.append(
                "switch with case fall-through and/or a side-effecting selector "
                "re-evaluated per branch (if/elif models neither)"
            );
            self._mark_tier_b(
                nd,
                line,
                "switch lowered to an if/elif chain: case fall-through is not "
                "modelled and/or the selector has side effects but is re-evaluated "
                "per branch — verify (faithful when every case ends in break and "
                "the selector is pure)",
            );
        } else {
            self._mark_tier_a_idiom(
                nd,
                line,
                Idiom.SWITCH_CLEAN,
                "clean switch (no fall-through, pure selector) → exact if/elif chain",
            );
        }
        # Build each case's test + body; a sub-lowering that fails (an unmappable
        # selector / case value) demotes the whole loop rather than emitting a
        # partial chain that silently mismatches.
        built: list[tuple] = [];  # (test_expr, body_stmts)
        for grp in groups {
            (vals, stmts) = grp;
            test = self._switch_test_uni(nd.cond, vals, line, col);
            if test is None {
                self._loop_lossy.append("switch selector/case value");
                self._mark_tier_b(
                    nd,
                    line,
                    "switch selector/case value not faithfully lowered; the switch "
                    "was dropped — verify",
                );
                return [];
            }
            body = self._switch_branch_body_uni(stmts, line, col);
            built.append((test, body));
        }
        default_body: list[uni.UniNode] | None = None;
        if default_stmts is not None {
            default_body = self._switch_branch_body_uni(default_stmts, line, col);
        }
        return self._switch_chain(built, default_body, line, col);
    }

    def _switch_chain(
        built: list, default_body: list | None, line: int, col: int
    ) -> list[uni.UniNode] {
        # Fold (test, body) arms into an if/elif/else chain: the first arm is the
        # head IfStmt, each subsequent arm an ElseIf nested in the prior else, and
        # a `default` becomes the trailing ElseStmt. A switch with only a default
        # always runs it (emit its body bare); one with neither is a no-op.
        if not built {
            if default_body is not None {
                return default_body;
            }
            return [];
        }
        acc_else: uni.UniNode | None = None;
        if default_body is not None {
            acc_else = uni.ElseStmt(body=default_body, kid=[*default_body]);
        }
        head: uni.UniNode | None = None;
        idx = len(built) - 1;
        while idx >= 0 {
            (test, body) = built[idx];
            kid_nodes: list[uni.UniNode] = [test, *body];
            if acc_else is not None {
                kid_nodes.append(acc_else);
            }
            if idx == 0 {
                head = uni.IfStmt(
                    kid=kid_nodes, condition=test, body=body, else_body=acc_else
                );
            } else {
                acc_else = uni.ElseIf(
                    kid=kid_nodes, condition=test, body=body, else_body=acc_else
                );
            }
            idx -= 1;
        }
        return [head];
    }

    def _switch_test_uni(
        cond_cnode: object, vals: list, line: int, col: int
    ) -> uni.UniNode | None {
        # `selector == v1 [or selector == v2 ...]`. The selector is re-lowered per
        # comparison so no uni node is shared across the tree; an unmappable
        # selector or case value yields None so the caller flags the loss.
        cmps: list[uni.UniNode] = [];
        for v in vals {
            sel = self._expr_to_uni(cond_cnode, line, col);
            val = self._expr_to_uni(v, line, col);
            if sel is None or val is None {
                return None;
            }
            eq_tok = self._binop_tok("==", line, col);
            if eq_tok is None {
                return None;
            }
            cmps.append(
                uni.BinaryExpr(kid=[sel, eq_tok, val], left=sel, right=val, op=eq_tok)
            );
        }
        if not cmps {
            return None;
        }
        acc = cmps[0];
        i = 1;
        while i < len(cmps) {
            or_tok = self._binop_tok("||", line, col);
            if or_tok is None {
                return None;
            }
            acc = uni.BinaryExpr(
                kid=[acc, or_tok, cmps[i]], left=acc, right=cmps[i], op=or_tok
            );
            i += 1;
        }
        return acc;
    }

    def _switch_branch_body_uni(
        stmts: list | None, line: int, col: int
    ) -> list[uni.UniNode] {
        # Convert one case's direct statements, dropping the switch-terminating
        # `break` (a direct break only — a break inside a nested loop lives in
        # that loop's converted body). A braced case body `case N: { ... }`
        # arrives as a single Compound; unwrap it so its terminating break is
        # dropped exactly like an unbraced one. An empty result is fine — Jac
        # allows an empty `if { }` block, so a do-nothing case still gates its
        # selector match.
        items: list = stmts or [];
        if len(items) == 1 and isinstance(items[0], c_ast.Compound) {
            items = items[0].block_items or [];
        }
        out: list[uni.UniNode] = [];
        for s in items {
            if isinstance(s, c_ast.Break) {
                continue;
            }
            out.extend(self._c_stmt_to_uni(s, line, col));
        }
        return out;
    }

    def _return_to_uni(stmt: object, line: int, col: int) -> list[uni.UniNode] {
        expr_node = getattr(stmt, "expr");
        if expr_node is None {
            ret_tok = self._tok(Tok.KW_RETURN, "return", line, col);
            return [uni.ReturnStmt(expr=None, kid=[ret_tok])];
        }
        ret_expr = self._expr_to_uni(expr_node, line, col);
        if ret_expr is None {
            # Had a value we couldn't lower — emit a bare `return` and flag, so the
            # loop is Tier-B rather than silently changing the returned value.
            self._loop_lossy.append("return expression");
            ret_tok = self._tok(Tok.KW_RETURN, "return", line, col);
            return [uni.ReturnStmt(expr=None, kid=[ret_tok])];
        }
        return [uni.ReturnStmt(expr=ret_expr, kid=[ret_expr])];
    }

    def _for_body(stmt: object, line: int, col: int) -> list[uni.UniNode] {
        return self._c_stmt_to_uni(stmt, line, col);
    }

    def _for_as_while(nd: object, line: int, col: int) -> list[uni.UniNode] {
        # Fallback: can't build IterForStmt. Desugar to `init; while (cond) {
        # body; step }`. This is faithful (→ Tier-A) when the condition and body
        # lower cleanly and the body has no loop-level `continue` — the one place
        # C's step-then-retest diverges from `body; step` (§5.3). Any of those
        # losses demotes the loop to Tier-B; the verdict is decided below.
        result: list[uni.UniNode] = [];
        # Reset the loss accumulator up front (this path rebuilds and re-scans
        # the whole loop, so the list `_build_for` collected before falling back
        # here is discarded). Resetting BEFORE the init/cond builds — not after —
        # lets a scalar cast in those clauses accumulate toward the Tier-B
        # verdict alongside body-construct losses.
        self._loop_lossy = [];
        # init statement before the loop (skip the IterForStmt dummy for for(;;)).
        # NB: read the field via getattr — bare `nd.init` resolves to a bound
        # method on the c_ast node (Jac treats `.init` as the constructor slot),
        # which silently dropped the initializer (e.g. `i = n`) before this fix.
        init_node = getattr(nd, "init");
        # init_lossy: a real `for (init; ...)` initializer was present but couldn't
        # be lowered. The while-desugar emits init statements before the loop, so
        # _for_init_list handles the multi-clause forms a single IterForStmt slot
        # can't — `for (i = 0, j = 10; ...)` (comma) and `for (int i = 0, j = 0;
        # ...)` (multi-decl) each lower to one assignment per clause. It returns
        # None only when some clause can't be lowered faithfully; we'd otherwise
        # drop the init silently, leaving loop vars uninitialized — so record the
        # loss to keep the desugar out of Tier-A.
        init_lossy = False;
        if init_node is not None {
            init_stmts = self._for_init_list(init_node, line, col);
            if init_stmts is not None {
                result.extend(init_stmts);
            } else {
                init_lossy = True;
            }
        }
        self._cond_lossy = False;
        cond = self._while_cond(nd.cond, line, col);
        # Capture the condition-loss verdict into a local NOW, before building the
        # body. _cond_lossy is shared mutable builder state and a nested fallback
        # loop in the body re-runs _for_as_while, which resets it — so reading
        # self._cond_lossy after _for_body would report the inner loop's verdict,
        # silently dropping this loop's own condition-loss clause.
        cond_lossy = self._cond_lossy;
        self._loop_has_continue = False;
        body_stmts = self._for_body(nd.stmt, line, col);
        next_node = getattr(nd, "next");
        step_stmts = self._step_as_stmts(next_node, line, col);
        # step_lossy: a real `for (...; ...; step)` step was present but couldn't be
        # lowered (e.g. a bare function-call step like `tick()`, or a comma step
        # with an unmappable operand). _step_as_stmts returns None and the step
        # vanishes from the loop — the body no longer advances as written, so this
        # is unfaithful and must not reach Tier-A.
        step_lossy = next_node is not None and step_stmts is None;
        # A loop-level `continue` only makes the desugar unfaithful when a step
        # exists: C's `continue` jumps to the for-step then retests, but the
        # desugared `body; step` runs `continue` *before* the step, skipping it.
        # With no step (e.g. `for (;;)` / `for (; cond; )`) there is nothing for
        # `continue` to skip — it retests the condition in both C and the desugar
        # — so the loop stays faithful and can still reach Tier-A (§5.3).
        continue_unfaithful = self._loop_has_continue and next_node is not None;
        # The desugar `init; while cond { body; step }` is *faithful* only when
        # every clause survived lowering: the init emitted (loop vars initialized),
        # the condition lowered cleanly (cond is the real test, not a bare `True`),
        # every body construct lowered, the step emitted (the loop still advances),
        # and no loop-level `continue` skips a step (the one place C's
        # step-then-retest diverges from `body; step`). When all hold, promote to
        # Tier-A — e.g. a clean descending loop `for (i = n; i > 0; i--)` that
        # IterForStmt can't model, or a `for (;;)` with a `continue` (no step to
        # skip). A dropped init or step is just as unfaithful as a dropped body
        # statement, so both gate Tier-A here.
        if (
            not cond_lossy
            and not self._loop_lossy
            and not continue_unfaithful
            and not init_lossy
            and not step_lossy
        ) {
            self._mark_tier_a(
                nd,
                line,
                "C-for not expressible as IterForStmt (e.g. descending step); "
                "desugared to `init; while cond { body; step }` — faithful: every "
                "clause lowered exactly and no loop-level `continue` skips a step",
            );
        } else {
            reason = "C-for loop not expressible as IterForStmt; desugared to while";
            if init_lossy {
                reason += (
                    " | loop init not faithfully lowered: the `for (init; ...)` "
                    "initializer (e.g. a comma/multi-decl init) was dropped — loop "
                    "variables may be left uninitialized (verify)"
                );
            }
            if step_lossy {
                reason += (
                    " | loop step not faithfully lowered: the `for (...; ...; step)` "
                    "step (e.g. a bare function-call step) was dropped — the loop body "
                    "no longer advances/updates as written (verify)"
                );
            }
            if continue_unfaithful {
                reason += (
                    " (C `continue` runs the step, the desugared `continue` skips "
                    "it — verify)"
                );
            }
            if cond_lossy {
                reason += (
                    " | loop condition not faithfully lowered: real `for (...; cond; ...)` "
                    "test replaced by `while True` (the loop no longer terminates on the "
                    "original condition — verify)"
                );
            }
            if self._loop_lossy {
                reason += (
                    " | body constructs not faithfully lowered: " + ", ".join(
                        sorted(set(self._loop_lossy))
                    )
                );
            }
            self._mark_tier_b(nd, line, reason);
        }
        full_body: list[uni.UniNode] = [*body_stmts];
        if step_stmts is not None {
            full_body.extend(step_stmts);
        }
        result.append(
            uni.WhileStmt(
                kid=[cond, *full_body], condition=cond, body=full_body, else_body=None,
            )
        );
        return result;
    }

    def _while_cond(cond_node: object, line: int, col: int) -> uni.Expr {
        # Full condition expression for the while-desugar (not just the bound).
        if cond_node is not None {
            c = self._expr_to_uni(cond_node, line, col);
            if c is not None {
                return c;
            }
            # A real condition existed but couldn't be lowered — flag it so the
            # caller's Tier-B reason says so explicitly, rather than letting the
            # silent `True` fallback masquerade as faithful for(;;) semantics.
            self._cond_lossy = True;
        }
        # for(;;) or an unmappable condition → True (matches for(;;) semantics).
        return uni.Bool(
            orig_src=self.src,
            name="BOOL",
            value="True",
            line=line,
            end_line=line,
            col_start=col,
            col_end=col + 4,
            pos_start=0,
            pos_end=4,
        );
    }

    def _step_as_stmt(step_node: object, line: int, col: int) -> uni.UniNode | None {
        # The step as a full statement appended to the loop body (i++ → i += 1).
        if step_node is None {
            return None;
        }
        (sline, scol) = self._coord(step_node);
        if isinstance(step_node, c_ast.UnaryOp)
        and step_node.op in ("p++", "++", "p--", "--") {
            target = self._lvalue_to_uni(step_node.expr, sline, scol);
            if target is None {
                return None;
            }
            op_str = "+=" if step_node.op in ("p++", "++") else "-=";
            aug = self._c_op_to_aug_tok(op_str, sline, scol);
            one = self._int_node(1, sline, scol);
            return uni.Assignment(
                kid=[target, aug, one],
                target=[target],
                value=one,
                type_tag=None,
                mutable=True,
                aug_op=aug,
                is_enum_stmt=False
            );
        }
        if isinstance(step_node, c_ast.Assignment) {
            return self._assign_to_uni_assign(step_node, sline, scol);
        }
        if isinstance(step_node, c_ast.FuncCall) {
            # A bare call step `for (...; tick())`: append it as an expression
            # statement to the desugared body. Faithful — C runs the call after
            # each body pass, exactly where the desugar's `body; step` places it.
            # (The IterForStmt path rejects this via _for_step, whose count_by
            # must be an augmented assignment, so a call step always routes
            # through the while-desugar where a plain statement step is legal.)
            call = self._funccall_to_uni(step_node, sline, scol);
            if call is not None {
                return uni.ExprStmt(expr=call, in_fstring=False, kid=[call]);
            }
            return None;
        }
        return None;
    }

    def _step_as_stmts(
        step_node: object, line: int, col: int
    ) -> list[uni.UniNode] | None {
        # The for-step lowered to one-or-more statements appended after the body.
        # A comma step `for (...; ...; i++, j++)` is an ExprList: C evaluates every
        # operand left-to-right at the bottom of each iteration, exactly where the
        # desugar's appended steps run, so each operand becomes its own step
        # statement. (IterForStmt's single count_by slot can't hold a comma, so a
        # comma step always routes here via _for_step returning None.) A single
        # step defers to _step_as_stmt. Returns None — not [] — when a real step
        # was present but some operand couldn't be lowered, so the caller flags the
        # dropped step; a missing step (None node) returns [].
        if step_node is None {
            return [];
        }
        if isinstance(step_node, c_ast.ExprList) {
            out: list[uni.UniNode] = [];
            for e in step_node.exprs {
                s = self._step_as_stmt(e, line, col);
                if s is None {
                    return None;
                }
                out.append(s);
            }
            return out;
        }
        single = self._step_as_stmt(step_node, line, col);
        if single is None {
            return None;
        }
        return [single];
    }

    # ------------------------------------------------------------------ #
    # Enum → uni.Enum or GlobalVars                                         #
    # ------------------------------------------------------------------ #
    def _build_enum(nd: object) -> list[uni.UniNode] {
        verdict = self.enum_verdicts.verdicts.get(id(nd), "tier_b");
        name_map = self.enum_verdicts.name_map.get(id(nd), {});
        (line, col) = self._coord(nd);
        if verdict == Idiom.ENUM_AS_ENUM.value {
            return [self._enum_as_enum(nd, name_map, line, col)];
        }
        if verdict == Idiom.ENUM_AS_CONSTS.value {
            return self._enum_as_consts(name_map, line, col);
        }
        # TIER_B — emit nothing here; the mapper's placeholder already carries the surrogate.
        return [];
    }

    def _enum_as_enum(
        nd: object, name_map: dict[str, int], line: int, col: int
    ) -> uni.Enum {
        enum_name_str = nd.name or "_AnonEnum";
        enum_name = self._name_node(enum_name_str, line, col);
        members: list[uni.UniNode] = [];
        for (nm, val) in name_map.items() {
            m_name = self._name_node(nm, line, col);
            m_val = self._int_node(val, line, col);
            assign = uni.Assignment(
                kid=[m_name, m_val],
                target=[m_name],
                value=m_val,
                type_tag=None,
                mutable=False,
                aug_op=None,
                is_enum_stmt=True,
            );
            members.append(assign);
        }
        # Enum.body must be a list of EnumBlockStmt (Assignment) items, not a
        # wrapped EnumBlockStmt node — NormalizePass.enter_enum iterates nd.body.
        return uni.Enum(
            kid=[enum_name, *members],
            doc=None,
            is_async=False,
            body=members,
            access=None,
            decorators=None,
            name=enum_name,
            value_type=None,
            base_classes=None,
        );
    }

    def _enum_as_consts(
        name_map: dict[str, int], line: int, col: int
    ) -> list[uni.GlobalVars] {
        results: list[uni.GlobalVars] = [];
        for (nm, val) in name_map.items() {
            name_n = self._name_node(nm, line, col);
            val_n = self._int_node(val, line, col);
            assign = uni.Assignment(
                kid=[name_n, val_n],
                target=[name_n],
                value=val_n,
                type_tag=None,
                mutable=False,
                aug_op=None,
                is_enum_stmt=False,
            );
            gv = uni.GlobalVars(
                kid=[assign],
                access=None,
                doc=None,
                assignments=[assign],
                is_frozen=True,
            );
            results.append(gv);
        }
        return results;
    }

    # ------------------------------------------------------------------ #
    # Expression helpers                                                   #
    # ------------------------------------------------------------------ #
    def _expr_to_uni(nd: object, line: int, col: int) -> uni.UniNode | None {
        if nd is None {
            return None;
        }

        (nline, ncol) = self._coord(nd);
        if isinstance(nd, c_ast.Constant) {
            # classify_c_constant matches pycparser's widened C type ("unsigned
            # int", "long double", ...) on the family suffix — same source of
            # truth as mapper.c_Constant — so suffixed literals like `10U`/`1.5f`
            # that parse_c_int/float recover after stripping the suffix classify
            # correctly here too.
            family = classify_c_constant(nd.type);
            if family == CLIT_INT {
                iv = parse_c_int(nd.value);
                if iv is not None {
                    return self._int_node(iv, nline, ncol);
                }
            }
            if family == CLIT_FLOAT {
                fv = parse_c_float(nd.value);
                if fv is not None {
                    sv = str(fv);
                    return uni.Float(
                        orig_src=self.src,
                        name="FLOAT",
                        value=sv,
                        line=nline,
                        end_line=nline,
                        col_start=ncol,
                        col_end=ncol + len(sv),
                        pos_start=0,
                        pos_end=len(sv),
                    );
                }
            }
            if family == CLIT_CHAR {
                # A C char constant is an integer; lower `'z'` to its ordinal
                # (122) so a condition like `i < 'z'` stays faithful instead of
                # collapsing to `i < 0`.
                cv = c_char_ord(nd.value);
                if cv is not None {
                    return self._int_node(cv, nline, ncol);
                }
            }
            if family == CLIT_STRING {
                # A plain C string literal carries its double quotes and escapes
                # in nd.value; emit them verbatim as a Jac string (the direct-IR
                # path has no later source re-slice, unlike mapper.c_Constant). A
                # prefixed literal (L"…"/u8"…") makes c_string_inner return None,
                # so it falls through to the None path below and the loop is
                # honestly demoted to Tier-B.
                if c_string_inner(nd.value) is not None {
                    return self._string_node(nd.value, nline, ncol);
                }
            }
            # Unparseable / unsupported constant (multi-char literal, exotic
            # form): return None so the caller records the loss and the enclosing
            # loop demotes to Tier-B, rather than silently emitting a wrong-typed
            # `0` with no entry in the report (honest-reporting invariant).
            return None;
        }
        if isinstance(nd, c_ast.ID) {
            return self._name_node(nd.name, nline, ncol);
        }
        if isinstance(nd, c_ast.BinaryOp) {
            left = self._expr_to_uni(nd.left, nline, ncol);
            right = self._expr_to_uni(nd.right, nline, ncol);
            if left is None or right is None {
                return None;
            }
            op_tok = self._binop_tok(nd.op, nline, ncol);
            if op_tok is None {
                return None;
            }
            return uni.BinaryExpr(
                kid=[left, op_tok, right], left=left, right=right, op=op_tok
            );
        }
        if isinstance(nd, c_ast.UnaryOp) {
            # Unary `+x` is the identity on a numeric value — emit the operand.
            if nd.op == "+" {
                return self._expr_to_uni(nd.expr, nline, ncol);
            }
            unary_tok: dict[str, tuple[str, str]] = {
                "-": ("MINUS", "-"),
                "!": (Tok.NOT, "not"),
                "~": (Tok.BW_NOT, "~"),

            };
            entry = unary_tok.get(nd.op);
            if entry is not None {
                operand = self._expr_to_uni(nd.expr, nline, ncol);
                if operand is None {
                    return None;
                }
                (tok_name, tok_val) = entry;
                op_tok = self._tok(tok_name, tok_val, nline, ncol);
                return uni.UnaryExpr(kid=[op_tok, operand], operand=operand, op=op_tok);
            }
            if nd.op == "*" or nd.op == "&" {
                # PTR_REF identity (mirrors mapper.c_UnaryOp §7.4): dereferencing
                # or taking the address of a *simple* lvalue is a no-op in Jac, so
                # `*p`/`&x`/`*s.f`/`&a[i]` → the operand itself. This keeps
                # `*p += i` / `s += *p` in a for-body instead of returning None and
                # dropping the whole statement. Only ID / s.f / s->f / a[i] qualify;
                # a computed deref like `*(p + 1)` has a BinaryOp operand and falls
                # through to None (Tier-B), since the arithmetic can't be elided.
                if is_simple_ref(nd.expr) {
                    return self._expr_to_uni(nd.expr, nline, ncol);
                }
                return None;
            }
            # `sizeof`, `p++`/`p--`, and computed `*`/`&` have no faithful
            # direct-IR analog.
            return None;
        }
        if isinstance(nd, c_ast.TernaryOp) {
            # `cond ? a : b` → uni.IfElseExpr, the same shape
            # PyastBuildPass.proc_if_exp builds for Python's `a if cond else b`.
            # Each arm recurses through _expr_to_uni; an arm that can't lower
            # faithfully yields None so the caller demotes the enclosing
            # statement to Tier-B rather than dropping it silently.
            cond = self._expr_to_uni(nd.cond, nline, ncol);
            iftrue = self._expr_to_uni(nd.iftrue, nline, ncol);
            iffalse = self._expr_to_uni(nd.iffalse, nline, ncol);
            if cond is None or iftrue is None or iffalse is None {
                return None;
            }
            cond_cfg = uni.CfgExpr(expr=cond, kid=[cond]);
            val_cfg = uni.CfgExpr(expr=iftrue, kid=[iftrue]);
            else_cfg = uni.CfgExpr(expr=iffalse, kid=[iffalse]);
            return uni.IfElseExpr(
                value=val_cfg,
                condition=cond_cfg,
                else_value=else_cfg,
                kid=[val_cfg, cond_cfg, else_cfg],
            );
        }
        if isinstance(nd, c_ast.FuncCall) {
            return self._funccall_to_uni(nd, nline, ncol);
        }
        if isinstance(nd, c_ast.ArrayRef) {
            return self._arrayref_to_uni(nd, nline, ncol);
        }
        if isinstance(nd, c_ast.StructRef) {
            return self._structref_to_uni(nd, nline, ncol);
        }
        if isinstance(nd, c_ast.Cast) {
            # C cast — lower the inner expression; the cast itself has no Jac
            # analog. Mirror the top-level mapper.c_Cast (§5.3): a pointer /
            # struct / array cast doesn't change the emitted value, so it stays
            # at the optimistic Tier-A default; a scalar/numeric cast is
            # representation-changing ((int)f truncates, (char)x narrows) and we
            # drop the conversion, so record the loss to demote the enclosing
            # loop to Tier-B rather than presenting a narrowed value as faithful.
            inner = self._expr_to_uni(nd.expr, nline, ncol);
            if inner is None {
                return None;
            }
            target = cast_scalar_target(nd);
            if target is not None {
                self._loop_lossy.append(
                    f"scalar cast to `{target}` elided "
                    "(truncation/narrowing not applied)"
                );
            }
            return inner;
        }
        if isinstance(nd, c_ast.ExprList) {
            # Comma expression `(a, b, … , z)`: C evaluates every operand
            # left-to-right but yields only the last. Lowering just the final
            # operand is faithful exactly when the leading operands are
            # side-effect-free — then dropping their evaluation changes nothing
            # (mirrors mapper.c_ExprList). When a leading operand has a side
            # effect (call / assignment / ++/--) dropping it loses semantics, so
            # return None: the caller records the loss and demotes the enclosing
            # loop to Tier-B rather than silently emitting a partial result.
            if not nd.exprs {
                return None;
            }
            for e in nd.exprs[:-1] {
                if not expr_reeval_safe(e) {
                    return None;
                }
            }
            return self._expr_to_uni(nd.exprs[-1], nline, ncol);
        }
        if isinstance(nd, c_ast.InitList) {
            # Brace initializer `{a, b, c}` → a Jac list literal (mirrors
            # mapper.c_InitList). Faithful for a plain positional initializer:
            # array element / struct field order is preserved. A designated
            # initializer (`{.x = 1}` / `[2] = 3`) arrives as a NamedInitializer
            # operand whose target name has no positional analog here, so bail
            # (the caller flags the loss) rather than silently misplacing a value.
            # An operand that can't lower likewise bails.
            elts: list[uni.UniNode] = [];
            for e in nd.exprs {
                if isinstance(e, c_ast.NamedInitializer) {
                    return None;
                }
                ev = self._expr_to_uni(e, nline, ncol);
                if ev is None {
                    return None;
                }
                elts.append(ev);
            }
            return uni.ListVal(kid=[*elts], values=elts);
        }
        return None;
    }

    def _arrayref_to_uni(nd: object, line: int, col: int) -> uni.UniNode | None {
        # `arr[i]` → AtomTrailer(target=arr, right=IndexSlice[i]) — the same shape
        # PyastBuildPass.proc_subscript builds. Recurses through _expr_to_uni so a
        # nested subscript/field base (`m[i][j]`, `s.arr[i]`) lowers too; a base or
        # index that can't be lowered yields None so the caller flags the loss.
        arr = self._expr_to_uni(nd.name, line, col);
        idx = self._expr_to_uni(nd.subscript, line, col);
        if arr is None or idx is None {
            return None;
        }
        slice_item = uni.Slice(start=idx, stop=None, step=None, kid=[idx]);
        index_slice = uni.IndexSlice(
            slices=[slice_item], is_range=False, kid=[slice_item]
        );
        return uni.AtomTrailer(
            target=arr,
            right=index_slice,
            is_attr=False,
            is_null_ok=False,
            kid=[arr, index_slice],
        );
    }

    def _structref_to_uni(nd: object, line: int, col: int) -> uni.UniNode | None {
        # `s.field` and `s->field` both → AtomTrailer attribute access (mirrors
        # mapper.c_StructRef; the `->` deref is the PTR_REF identity). is_kwesc on a
        # field literally named `init` keeps it a field access, not a constructor.
        obj_expr = self._expr_to_uni(nd.name, line, col);
        if obj_expr is None {
            return None;
        }
        field = nd.field.name;
        (fline, fcol) = self._coord(nd.field);
        attr = uni.Name(
            orig_src=self.src,
            name=Tok.NAME,
            value=field,
            line=fline,
            end_line=fline,
            col_start=fcol,
            col_end=fcol + len(field),
            pos_start=0,
            pos_end=len(field),
            is_kwesc=(field == "init"),
        );
        return uni.AtomTrailer(
            target=obj_expr,
            right=attr,
            is_attr=True,
            is_null_ok=False,
            kid=[obj_expr, attr],
        );
    }

    def _funccall_to_uni(nd: object, line: int, col: int) -> uni.UniNode | None {
        target = self._expr_to_uni(nd.name, line, col);
        if target is None {
            return None;
        }
        params: list[uni.UniNode] = [];
        if nd.args {
            for e in nd.args.exprs {
                pe = self._expr_to_uni(e, line, col);
                if pe is None {
                    # An unmappable argument means we cannot emit a faithful call.
                    return None;
                }
                params.append(pe);
            }
        }
        kids = [target, *params] if params else [target];
        return uni.FuncCall(target=target, params=params, genai_call=None, kid=kids);
    }

    def _lvalue_to_uni(nd: object, line: int, col: int) -> uni.UniNode | None {
        if isinstance(nd, c_ast.ID) {
            (nline, ncol) = self._coord(nd);
            return self._name_node(nd.name, nline, ncol);
        }
        # `arr[i] = …`, `m[i][j] = …`, `s.f = …`, `p->f = …`: the subscript /
        # attribute trailer is the same Uni node whether it sits in lvalue or
        # rvalue position — its role as an assignment target comes from being
        # placed in `uni.Assignment.target`, not from any flag on the node — so
        # reuse the rvalue builders. Previously only a bare ID lowered here, so
        # every indexed or field assignment in a for-body was silently dropped.
        if isinstance(nd, c_ast.ArrayRef) {
            (nline, ncol) = self._coord(nd);
            return self._arrayref_to_uni(nd, nline, ncol);
        }
        if isinstance(nd, c_ast.StructRef) {
            (nline, ncol) = self._coord(nd);
            return self._structref_to_uni(nd, nline, ncol);
        }
        # `*p = …` / `*s.f = …`: dereferencing a *simple* pointer lvalue is the
        # PTR_REF identity (mirrors the rvalue side in _expr_to_uni), so the
        # target is just the operand. Keeps `*p += i` in a for-body instead of
        # dropping it. A computed deref (`*(p + 1) = …`) has a BinaryOp operand
        # and falls through to None (Tier-B).
        if isinstance(nd, c_ast.UnaryOp) and (nd.op == "*" or nd.op == "&") {
            if is_simple_ref(nd.expr) {
                (nline, ncol) = self._coord(nd.expr);
                return self._expr_to_uni(nd.expr, nline, ncol);
            }
        }
        # An otherwise computed lvalue has no faithful direct-IR analog yet;
        # return None so the caller records the loss (Tier-B).
        return None;
    }

    def _binop_tok(op: str, line: int, col: int) -> uni.Token | None {
        entry = C_BINOPS.get(op);
        if entry is None {
            return None;
        }
        (_, _, tok_name, tok_val) = entry;
        return self._tok(tok_name, tok_val, line, col);
    }

    def _c_op_to_aug_tok(op: str, line: int, col: int) -> uni.Token | None {
        entry = C_AUGOPS.get(op);
        if entry is None {
            return None;
        }
        (_, tok_name, tok_val) = entry;
        return self._tok(tok_name, tok_val, line, col);
    }
}
