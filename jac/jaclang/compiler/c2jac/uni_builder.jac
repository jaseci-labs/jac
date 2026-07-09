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
        _loop_lossy: list[str] = [];

    def init(src: uni.Source, tags: TagTable, enum_verdicts: EnumVerdicts) {
        self.src = src;
        self.tags = tags;
        self.enum_verdicts = enum_verdicts;
        self._loop_lossy = [];
    }

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

    def _coord(c_node: object) -> tuple[int, int] {
        return coord_of(c_node, 1);
    }

    def build(c_node: object) -> list[uni.UniNode] {
        tp = type(c_node).__name__;
        if tp == "For" {
            return self._build_for(c_node);
        }
        if tp == "Enum" {
            return self._build_enum(c_node);
        }

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

    def _build_for(nd: object) -> list[uni.UniNode] {
        (line, col) = self._coord(nd);

        init_nodes = self._for_init(getattr(nd, "init"), line, col);
        cond_expr = self._for_cond(nd.cond, line, col);
        step_assign = self._for_step(nd.next, line, col);
        self._loop_lossy = [];
        body_stmts = self._for_body(nd.stmt, line, col);

        if init_nodes is None or cond_expr is None or step_assign is None {
            return self._for_as_while(nd, line, col);
        }
        if self._loop_lossy {
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

        if isinstance(init_node, c_ast.DeclList) {
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
            return None;
        }

        if isinstance(cond_node, c_ast.BinaryOp)
        and cond_node.op in ("<", "<=", "!=") {
            return self._expr_to_uni(cond_node, line, col);
        }
        return None;
    }

    def _for_step(step_node: object, line: int, col: int) -> uni.Assignment | None {
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

            self._loop_lossy.append("uninitialized/complex local declaration");
            return [];
        }

        self._loop_lossy.append(type(stmt).__name__);
        return [];
    }

    def _c_else_to_uni(else_node: object, line: int, col: int) -> uni.UniNode | None {
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
        result: list[uni.UniNode] = [];

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
        if cond_node is not None {
            c = self._expr_to_uni(cond_node, line, col);
            if c is not None {
                return c;
            }
        }

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

    def _expr_to_uni(nd: object, line: int, col: int) -> uni.UniNode | None {
        if nd is None {
            return None;
        }

        (nline, ncol) = self._coord(nd);
        if isinstance(nd, c_ast.Constant) {
            if nd.type == "int" {
                iv = parse_c_int(nd.value);
                if iv is not None {
                    return self._int_node(iv, nline, ncol);
                }
            }
            if nd.type in ("double", "float") {
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

            return self._int_node(0, nline, ncol);
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
            if nd.op == "-" {
                operand = self._expr_to_uni(nd.expr, nline, ncol);
                if operand is None {
                    return None;
                }
                op_tok = self._tok("MINUS", "-", nline, ncol);
                return uni.UnaryExpr(kid=[op_tok, operand], operand=operand, op=op_tok);
            }
        }
        return None;
    }

    def _lvalue_to_uni(nd: object, line: int, col: int) -> uni.UniNode | None {
        if isinstance(nd, c_ast.ID) {
            (nline, ncol) = self._coord(nd);
            return self._name_node(nd.name, nline, ncol);
        }
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
