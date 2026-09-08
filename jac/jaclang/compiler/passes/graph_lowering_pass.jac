import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.constant { EdgeDir, Tokens as Tok }
import from jaclang.compiler.frontend.diagnostics { E0084, E0085 }
import from jaclang.compiler.passes.uni_pass { UniPass }

walker GraphLoweringPass(UniPass) {
    has _serial: int = 0,
        _names: set[str] = set(),
        _builder_type: str = "",
        _ports_type: str = "",
        _capture: bool = True;

    def transform(ir_in: uni.Module) -> uni.Module {
        if not ir_in.get_all_sub_nodes(uni.GraphExpr) {
            return ir_in;
        }
        return UniPass.transform(self, ir_in);
    }

    def before_pass {
        self._names = {n.value for n in self.ir_in.get_all_sub_nodes(uni.Name)};
    }

    def runtime_import(at: uni.GraphExpr) -> uni.Import {
        self._builder_type = self.fresh("builder_type");
        self._ports_type = self.fresh("ports_type");
        path = [self.name(n, at) for n in ["jaclang", "runtime", "graph_fragment"]];
        module_path = uni.ModulePath(path=path, level=0, alias=None, kid=path);
        items: list[uni.ModuleItem] = [];
        for (original, alias) in [
            ("GraphBuilder", self._builder_type),
            ("GraphPorts", self._ports_type)
        ] {
            nm = self.name(original, at);
            al = self.name(alias, at);
            items.append(uni.ModuleItem(name=nm, alias=al, kid=[nm, al]));
        }
        return uni.Import(
            from_loc=module_path,
            items=items,
            is_absorb=False,
            kid=[module_path, *items]
        );
    }

    def fresh(label: str) -> str {
        while True {
            self._serial += 1;
            candidate = f"__jac_graph_{label}_{self._serial}";
            if candidate not in self._names {
                self._names.add(candidate);
                return candidate;
            }
        }
    }

    def name(value: str, at: uni.UniNode) -> uni.Name {
        return uni.Name(
            orig_src=at.loc.orig_src,
            name=Tok.NAME,
            value=value,
            line=at.loc.first_line,
            end_line=at.loc.first_line,
            col_start=at.loc.col_start,
            col_end=at.loc.col_start + len(value),
            pos_start=0,
            pos_end=0
        );
    }

    def attr(owner: str, member: str, at: uni.UniNode) -> uni.AtomTrailer {
        target = self.name(owner, at);
        right = self.name(member, at);
        return uni.AtomTrailer(
            target=target,
            right=right,
            is_attr=True,
            is_null_ok=False,
            kid=[target, right]
        );
    }

    def call(target: uni.Expr, args: list[uni.Expr]) -> uni.FuncCall {
        return uni.FuncCall(
            target=target, params=args, genai_call=None, kid=[target, *args]
        );
    }

    def assign(value: uni.Expr, body: list[uni.CodeBlockStmt], at: uni.UniNode) -> str {
        label = self.fresh("value");
        target = self.name(label, at);
        body.append(uni.Assignment(target=[target], value=value, kid=[target, value]));
        return label;
    }

    def parallel(
        values: list[uni.Expr],
        builder: str,
        body: list[uni.CodeBlockStmt],
        at: uni.UniNode
    ) -> str {
        parts: list[uni.Expr] = [];
        for value in values {
            ports = self.lower(value, builder, body);
            parts.append(self.name(ports, value));
        }
        items = uni.ListVal(
            values=parts,
            kid=[at.gen_token(Tok.LSQUARE), *parts, at.gen_token(Tok.RSQUARE)]
        );
        return self.assign(
            self.call(self.attr(builder, "parallel", at), [items]), body, at
        );
    }

    def lower(expr: uni.Expr, builder: str, body: list[uni.CodeBlockStmt]) -> str {
        if isinstance(expr, uni.CfgExpr) {
            return self.lower(expr.expr, builder, body);
        }
        if isinstance(expr, uni.AtomUnit) and isinstance(expr.value, uni.Expr) {
            return self.lower(expr.value, builder, body);
        }
        if isinstance(expr, uni.ListVal) {
            return self.parallel(list(expr.values), builder, body, expr);
        }
        if isinstance(expr, uni.IfElseExpr) {
            for branch in [expr.value, expr.else_value] {
                statements: list[uni.CodeBlockStmt] = [];
                ports = self.lower(branch, builder, statements);
                result = self.name(ports, branch);
                statements.append(uni.ReturnStmt(expr=result, kid=[result]));
                closure = uni.LambdaExpr(body=statements, kid=statements);
                invocation = self.call(closure, []);
                expr.replace_kid(
                    branch, uni.CfgExpr(expr=invocation, kid=[invocation])
                );
            }
            return self.assign(expr, body, expr);
        }
        if isinstance(expr, uni.ListCompr) and type(expr) is uni.ListCompr {
            statements: list[uni.CodeBlockStmt] = [];
            ports = self.lower(expr.out_expr, builder, statements);
            result = self.name(ports, expr.out_expr);
            statements.append(uni.ReturnStmt(expr=result, kid=[result]));
            closure = uni.LambdaExpr(body=statements, kid=statements);
            expr.replace_kid(expr.out_expr, self.call(closure, []));
            return self.assign(
                self.call(self.attr(builder, "parallel", expr), [expr]), body, expr
            );
        }
        if isinstance(expr, uni.BinaryExpr) and isinstance(expr.op, uni.ConnectOp) {
            if expr.op.edge_dir != EdgeDir.OUT {
                self.emit(E0084, node_override=expr.op);
            }
            left = self.lower(expr.left, builder, body);
            right = self.lower(expr.right, builder, body);
            src = self.fresh("source");
            tgt = self.fresh("target");
            lhs = self.name(src, expr.left);
            rhs = self.name(tgt, expr.right);
            op = expr.op;
            op.capture_edges = self._capture;
            conn = uni.BinaryExpr(left=lhs, op=op, right=rhs, kid=[lhs, op, rhs]);
            record: uni.Expr = self.call(
                self.attr(builder, "record_edges", expr), [conn]
            )
                if self._capture
                else conn;
            statement = uni.ExprStmt(expr=record, in_fstring=False, kid=[record]);
            target = self.name(tgt, expr.right);
            roots = self.attr(right, "roots", expr.right);
            inner = uni.InForStmt(
                target=target,
                collection=roots,
                body=[statement],
                kid=[target, roots, statement]
            );
            source = self.name(src, expr.left);
            tips = self.attr(left, "tips", expr.left);
            outer = uni.InForStmt(
                target=source, collection=tips, body=[inner], kid=[source, tips, inner]
            );
            body.append(outer);
            ports_call = self.call(
                self.name(self._ports_type, expr),
                [self.attr(left, "roots", expr), self.attr(right, "tips", expr)]
            );
            return self.assign(ports_call, body, expr);
        }
        return self.assign(
            self.call(self.attr(builder, "add", expr), [expr]), body, expr
        );
    }

    can exit_graph_expr with uni.GraphExpr exit {
        for nd in here.flatten() {
            if isinstance(nd, (uni.AwaitExpr, uni.YieldExpr)) {
                self.emit(E0085, node_override=nd);
            }
        }
        for generator in here.get_all_sub_nodes(uni.InnerCompr) {
            if generator.is_async {
                self.emit(E0085, node_override=generator);
            }
        }
        projection: uni.UniNode = here;
        while isinstance(projection.parent, uni.AtomUnit) {
            projection = projection.parent;
        }
        parent_expr = projection.parent;
        self._capture = not (
            isinstance(parent_expr, uni.AtomTrailer)
            and parent_expr.is_attr
            and parent_expr.target is projection
            and isinstance(parent_expr.right, uni.Name)
            and parent_expr.right.sym_name == "root"
        );
        body: list[uni.CodeBlockStmt] = [self.runtime_import(here)];
        args: list[uni.Expr] = [];
        if not self._capture {
            args.append(
                uni.Bool(
                    orig_src=here.loc.orig_src,
                    name=Tok.BOOL,
                    value="False",
                    line=here.loc.first_line,
                    end_line=here.loc.first_line,
                    col_start=here.loc.col_start,
                    col_end=here.loc.col_start + 5,
                    pos_start=0,
                    pos_end=0
                )
            );
        }
        builder = self.assign(
            self.call(self.name(self._builder_type, here), args), body, here
        );
        ports = self.lower(here.exprs[0], builder, body)
            if len(here.exprs) == 1
            else self.parallel(list(here.exprs), builder, body, here);
        result = self.call(
            self.attr(builder, "finish", here), [self.name(ports, here)]
        );
        ret = uni.ReturnStmt(expr=result, kid=[result]);
        body.append(ret);
        closure = uni.LambdaExpr(body=body, kid=body);
        invocation = self.call(closure, []);
        parent = here.parent;
        if parent is not None {
            parent.replace_kid(here, invocation);
        }
    }
}
