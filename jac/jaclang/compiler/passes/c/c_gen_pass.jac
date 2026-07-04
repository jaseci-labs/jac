import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.transform { Transform }

glob C_PRIM_TYPES: dict[str, str] = {
         "int": "int",
         "float": "double",
         "bool": "int",
         "str": "const char*",
         "None": "void",
         "": "void"
     },
     C_OP_MAP: dict[str, str] = {"and": "&&", "or": "||", "not": "!"};

obj CGenPass(Transform[uni.Module, uni.Module]) {
    def transform(ir_in: uni.Module) -> uni.Module {
        try {
            self.gen_module(ir_in);
        } except Exception as e {
            ir_in.gen.c_src = f"/* jac2c: C emission failed: {e} */\n";
        }
        return ir_in;
    }

    def gen_module(mod: uni.Module) {
        structs: list[str] = [];
        protos: list[str] = [];
        funcs: list[str] = [];
        for stmt in mod.body {
            if isinstance(stmt, uni.Archetype) {
                structs.append(self.gen_struct(stmt));
            } elif isinstance(stmt, uni.Ability) {
                protos.append(self.func_head(stmt) + ";");
                funcs.append(self.gen_func(stmt));
            }
        }
        parts: list[str] = ["/* Generated from Jac by `jac jac2c`. */"];
        parts.extend(
            [
                s
                for s in structs
                if s
            ]
        );
        parts.extend(
            [
                p
                for p in protos
                if p
            ]
        );
        parts.extend(
            [
                f
                for f in funcs
                if f
            ]
        );
        mod.gen.c_src = "\n\n".join(parts) + "\n";
    }

    def c_type(jac_ty: str) -> str {
        if jac_ty in C_PRIM_TYPES {
            return C_PRIM_TYPES[jac_ty];
        }
        return f"struct {jac_ty}";
    }

    def type_name(type_tag: object) -> str {
        if type_tag is None {
            return "";
        }
        tag = type_tag.tag;
        if isinstance(tag, uni.Name) {
            return tag.value;
        }
        return tag.unparse();
    }

    def ret_type_name(ret: object) -> str {
        if ret is None {
            return "";
        }
        if isinstance(ret, uni.Name) {
            return ret.value;
        }
        return ret.unparse();
    }

    def gen_struct(arch: uni.Archetype) -> str {
        name = arch.name.value;
        lines: list[str] = [f"struct {name} " + "{"];
        for member in (arch.body or []) {
            if isinstance(member, uni.ArchHas) {
                for hv in member.vars {
                    cty = self.c_type(self.type_name(hv.type_tag));
                    lines.append(f"    {cty} {hv.name.value};");
                }
            }
        }
        lines.append("};");
        return "\n".join(lines);
    }

    def func_head(ab: uni.Ability) -> str {
        name = ab.name_ref.value;
        sig = ab.signature;
        ret = self.c_type(self.ret_type_name(sig.return_type if sig else None));
        params: list[str] = [];
        if sig and sig.params {
            for p in sig.params {
                pty = self.c_type(self.type_name(p.type_tag));
                params.append(f"{pty} {p.name.value}");
            }
        }
        ptxt = ", ".join(params) if params else "void";
        return f"{ret} {name}({ptxt})";
    }

    def gen_func(ab: uni.Ability) -> str {
        body = self.gen_block(ab.body, 1);
        return self.func_head(ab) + " {\n" + body + "\n}";
    }

    def gen_block(stmts: object, ind: int) -> str {
        out: list[str] = [];
        for st in (stmts or []) {
            rendered = self.gen_stmt(st, ind);
            if rendered {
                out.append(rendered);
            }
        }
        return "\n".join(out);
    }

    def gen_stmt(st: object, ind: int) -> str {
        pad = "    " * ind;
        if isinstance(st, uni.ReturnStmt) {
            if st.expr is not None {
                return pad + "return " + self.gen_expr(st.expr) + ";";
            }
            return pad + "return;";
        }
        if isinstance(st, uni.Assignment) {
            return pad + self.gen_assign(st) + ";";
        }
        if isinstance(st, uni.IfStmt) {
            return self.gen_if(st, ind);
        }
        if isinstance(st, uni.WhileStmt) {
            head = pad + "while (" + self.gen_expr(st.condition) + ") {\n";
            return head + self.gen_block(st.body, ind + 1) + "\n" + pad + "}";
        }
        if isinstance(st, uni.IterForStmt) {
            return self.gen_for(st, ind);
        }
        if isinstance(st, uni.ExprStmt) {
            return pad + self.gen_expr(st.expr) + ";";
        }
        return pad + f"/* jac2c: unsupported statement {type(st).__name__} */";
    }

    def gen_for(st: uni.IterForStmt, ind: int) -> str {
        pad = "    " * ind;
        init = self.gen_assign(st.iter);
        if st.iter.type_tag is None {
            init = "int " + init;
        }
        step = self.gen_assign(st.count_by);
        cond = self.gen_expr(st.condition);
        head = pad + f"for ({init}; {cond}; {step}) " + "{\n";
        return head + self.gen_block(st.body, ind + 1) + "\n" + pad + "}";
    }

    def gen_if(st: uni.IfStmt, ind: int) -> str {
        pad = "    " * ind;
        head = pad + "if (" + self.gen_expr(st.condition) + ") {\n";
        s = head + self.gen_block(st.body, ind + 1) + "\n" + pad + "}";
        eb = st.else_body;
        if eb is None {
            return s;
        }
        if isinstance(eb, uni.ElseIf) {
            return s + " else " + self.gen_if(eb, ind).strip();
        }
        if isinstance(eb, uni.ElseStmt) {
            inner = self.gen_block(eb.body, ind + 1);
            return s + " else {\n" + inner + "\n" + pad + "}";
        }
        return s;
    }

    def gen_assign(a: uni.Assignment) -> str {
        tgt = self.gen_expr(a.target[0]);
        if a.type_tag is not None {
            cty = self.c_type(self.type_name(a.type_tag));
            if a.value is not None {
                return f"{cty} {tgt} = " + self.gen_expr(a.value);
            }
            return f"{cty} {tgt}";
        }
        if a.aug_op is not None {
            return f"{tgt} {a.aug_op.value} " + self.gen_expr(a.value);
        }
        return f"{tgt} = " + self.gen_expr(a.value);
    }

    def c_op(op_val: str) -> str {
        if op_val in C_OP_MAP {
            return C_OP_MAP[op_val];
        }
        return op_val;
    }

    def gen_expr(e: object) -> str {
        if isinstance(e, uni.AtomUnit) {
            return self.gen_expr(e.value);
        }
        if isinstance(e, uni.Bool) {
            return "1" if e.value == "True" else "0";
        }
        if isinstance(e, uni.Name) {
            return e.value;
        }
        if isinstance(e, (uni.Int, uni.Float)) {
            return e.value;
        }
        if isinstance(e, uni.String) {
            return e.value;
        }
        if isinstance(e, uni.BinaryExpr) {
            op = self.c_op(e.op.value);
            return "(" + self.gen_expr(e.left) + f" {op} " + self.gen_expr(e.right) + ")";
        }
        if isinstance(e, uni.CompareExpr) {
            clauses: list[str] = [];
            prev = e.left;
            for (op, right) in zip(e.ops, e.rights) {
                cop = self.c_op(op.value);
                clauses.append(
                    "(" + self.gen_expr(prev) + f" {cop} " + self.gen_expr(right) + ")"
                );
                prev = right;
            }
            if len(clauses) == 1 {
                return clauses[0];
            }
            return "(" + " && ".join(clauses) + ")";
        }
        if isinstance(e, uni.UnaryExpr) {
            return self.c_op(e.op.value) + self.gen_expr(e.operand);
        }
        if isinstance(e, uni.AtomTrailer) {
            if e.is_attr {
                return self.gen_expr(e.target) + "." + self.attr_name(e.right);
            }
            return self.gen_expr(e.target) + "[" + self.gen_expr(e.right) + "]";
        }
        if isinstance(e, uni.FuncCall) {
            args: list[str] = [];
            for p in (e.params or []) {
                if isinstance(p, uni.Expr) {
                    args.append(self.gen_expr(p));
                }
            }
            return self.gen_expr(e.target) + "(" + ", ".join(args) + ")";
        }
        return f"/* jac2c: unsupported expr {type(e).__name__} */";
    }

    def attr_name(nd: object) -> str {
        if isinstance(nd, uni.Name) {
            return nd.value;
        }
        return self.gen_expr(nd);
    }
}
