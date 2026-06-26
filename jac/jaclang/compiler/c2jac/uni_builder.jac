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
    coord_of
}

obj CUniBuilder {
    has src: uni.Source,
        tags: TagTable,
        enum_verdicts: EnumVerdicts,
        # Accumulates the names of C-for body constructs that could not be
        # faithfully lowered during the most recent loop build. A non-empty list
        # forces the enclosing loop to Tier-B so the Tier-B comments never claim
        # faithful coverage of a body it actually dropped. Reset at each loop entry.
        _loop_lossy: list[str] = [];

    def init(src: uni.Source, tags: TagTable, enum_verdicts: EnumVerdicts) {
        self.src = src;
        self.tags = tags;
        self.enum_verdicts = enum_verdicts;
        self._loop_lossy = [];
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

    def _c_char_ord(raw: str) -> int | None {
        # C char constant ("'z'", "'\n'", "'\0'") → its integer value. Decodes
        # the common escape sequences via unicode_escape; returns None for
        # multi-character or otherwise non-single-char constants so the caller
        # can flag the loss instead of guessing.
        if not (raw.startswith("'") and raw.endswith("'")) or len(raw) < 3 {
            return None;
        }
        inner = raw[1:-1];
        try {
            decoded = bytes(inner, "utf-8").decode("unicode_escape");
        } except Exception {
            return None;
        }
        if len(decoded) != 1 {
            return None;
        }
        return ord(decoded);
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

    # ------------------------------------------------------------------ #
    # C-for → IterForStmt                                                  #
    # ------------------------------------------------------------------ #
    def _build_for(nd: object) -> list[uni.UniNode] {
        (line, col) = self._coord(nd);
        # Parse the init, cond, and step from the C-for node.
        init_nodes = self._for_init(getattr(nd, "init"), line, col);
        cond_expr = self._for_cond(nd.cond, line, col);
        step_assign = self._for_step(nd.next, line, col);
        self._loop_lossy = [];
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
            # Multiple init decls — only handle single for now.
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
            wbody = self._c_stmt_to_uni(stmt.stmt, sline, scol);
            return [
                uni.WhileStmt(
                    kid=[wcond, *wbody], condition=wcond, body=wbody, else_body=None,
                )
            ];
        }

        if isinstance(stmt, c_ast.For) {
            # Recurse through the full for-builder so a nested loop gets the same
            # IterForStmt-or-while-desugar treatment (and its own Tier-B marking).
            # _build_for resets self._loop_lossy, so snapshot and restore the
            # outer accumulator around the call to avoid cross-contaminating which
            # loop is flagged.
            saved = self._loop_lossy;
            inner = self._build_for(stmt);
            self._loop_lossy = saved;
            return inner;
        }

        # Any other statement (switch, goto, do-while, ...) has no direct-IR
        # lowering yet. Record it so the enclosing loop is Tier-B.
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
        # body; step }` — faithful except that C `continue` jumps to the step
        # whereas here it skips it, so the loop is marked Tier-B (§5.3).
        result: list[uni.UniNode] = [];
        # init statement before the loop (skip the IterForStmt dummy for for(;;)).
        # NB: read the field via getattr — bare `nd.init` resolves to a bound
        # method on the c_ast node (Jac treats `.init` as the constructor slot),
        # which silently dropped the initializer (e.g. `i = n`) before this fix.
        init_node = getattr(nd, "init");
        if init_node is not None {
            init_stmt = self._for_init(init_node, line, col);
            if init_stmt is not None {
                result.append(init_stmt);
            }
        }
        cond = self._while_cond(nd.cond, line, col);
        self._loop_lossy = [];
        body_stmts = self._for_body(nd.stmt, line, col);
        step_stmt = self._step_as_stmt(nd.next, line, col);
        reason = (
            "C-for loop not expressible as IterForStmt; desugared to while "
            "(C `continue` runs the step, the desugared `continue` skips it — verify)"
        );
        if self._loop_lossy {
            reason += (
                " | body constructs not faithfully lowered: " + ", ".join(
                    sorted(set(self._loop_lossy))
                )
            );
        }
        self._mark_tier_b(nd, line, reason);
        full_body: list[uni.UniNode] = [*body_stmts];
        if step_stmt is not None {
            full_body.append(step_stmt);
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
        return None;
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
            # pycparser reports the widened C type ("unsigned int", "long double",
            # ...), so match on the family suffix — same as mapper.c_Constant — to
            # cover suffixed literals like `10U`/`1.5f` that parse_c_int/float
            # recover after stripping the suffix.
            if nd.type.endswith("int") {
                iv = parse_c_int(nd.value);
                if iv is not None {
                    return self._int_node(iv, nline, ncol);
                }
            }
            if nd.type.endswith("double") or nd.type.endswith("float") {
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
            if nd.type == "char" {
                # A C char constant is an integer; lower `'z'` to its ordinal
                # (122) so a condition like `i < 'z'` stays faithful instead of
                # collapsing to `i < 0`.
                cv = self._c_char_ord(nd.value);
                if cv is not None {
                    return self._int_node(cv, nline, ncol);
                }
            }
            if nd.type == "string" {
                # A plain C string literal carries its double quotes and escapes
                # in nd.value; emit them verbatim as a Jac string (same family as
                # mapper.c_Constant's "string" branch). A prefixed literal
                # (L"…"/u8"…") doesn't start with `"`, so it falls through to the
                # None path below and the loop is honestly demoted to Tier-B.
                raw = nd.value;
                if raw.startswith('"') and raw.endswith('"') and len(raw) >= 2 {
                    return self._string_node(raw, nline, ncol);
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
            # `*p`, `&p`, `sizeof`, `p++`/`p--` have no faithful direct-IR analog.
            return None;
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
        # attribute trailer is the same node in lvalue and rvalue position (its
        # Store-vs-Load context is resolved downstream), so reuse the rvalue
        # builders. Previously only a bare ID lowered here, so every indexed or
        # field assignment in a for-body was silently dropped.
        if isinstance(nd, c_ast.ArrayRef) {
            (nline, ncol) = self._coord(nd);
            return self._arrayref_to_uni(nd, nline, ncol);
        }
        if isinstance(nd, c_ast.StructRef) {
            (nline, ncol) = self._coord(nd);
            return self._structref_to_uni(nd, nline, ncol);
        }
        # A `*p = …` deref or otherwise computed lvalue has no faithful direct-IR
        # analog yet; return None so the caller records the loss (Tier-B).
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
