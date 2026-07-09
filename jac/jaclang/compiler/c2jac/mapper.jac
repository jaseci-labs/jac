import ast as ast3;
import from pycparser { c_ast }
import from jaclang.compiler.c2jac.tags { Tier, Mechanism, Idiom, NodeTag, TagTable }
import from jaclang.compiler.c2jac.boundary { default_tier, default_mechanism }
import from jaclang.compiler.c2jac.c_common {
    C_BINOPS,
    C_AUGOPS,
    parse_c_int,
    parse_c_float,
    coord_of
}

glob _SLOT_SENTINEL: str = "__c2jac_directir__",
     _UNSUPPORTED_STMT: str = "__c2jac_unsupported__",
     _UNSUPPORTED_EXPR: str = "__c2jac_unsupported_expr__",
     _C_BUILTIN_TYPES: set = {
         "int",
         "float",
         "double",
         "void",
         "long",
         "short",
         "unsigned",
         "signed",
         "bool",
         "size_t",

     },
     _C_PRIM_MAP: dict = {
         "int": "int",
         "float": "float",
         "double": "float",
         "char": "str",
         "void": "None",
         "long": "int",
         "short": "int",
         "unsigned": "int",
         "signed": "int",
         "bool": "bool",

     };

obj CMapper {
    has tags: TagTable,
        slot_map: dict[int, object],
        _next_slot: int,
        _lineno: int;

    def init(tags: TagTable) {
        self.tags = tags;
        self.slot_map = {};
        self._next_slot = 0;
        self._lineno = 1;
    }

    def _loc(c_node: object) -> tuple[int, int] {
        (line, col) = coord_of(c_node, self._lineno);
        self._lineno = line;
        return (line, col);
    }

    def _stamp(py_node: object, c_node: object, *, text: str = "") -> object {
        (line, col) = self._loc(c_node);
        py_node.lineno = line;
        py_node.col_offset = col;
        py_node.end_lineno = line;
        py_node.end_col_offset = col + max(len(text), 1);
        return py_node;
    }

    def _stamp_manual(
        py_node: object, line: int, col: int, *, text: str = ""
    ) -> object {
        py_node.lineno = line;
        py_node.col_offset = col;
        py_node.end_lineno = line;
        py_node.end_col_offset = col + max(len(text), 1);
        return py_node;
    }

    def _alloc_slot(c_node: object) -> int {
        sid = self._next_slot;
        self._next_slot += 1;
        self.slot_map[sid] = c_node;
        return sid;
    }

    def _surrogate_stmt(c_node: object) -> object {
        (line, col) = self._loc(c_node);
        reason = f"{type(c_node).__name__} @ L{line}";
        self.tags.tag(
            c_node,
            NodeTag(
                tier=Tier.TIER_B,
                mechanism=Mechanism.PY_AST,
                idiom=Idiom.TIER_B,
                reason=reason,
                c_line=line,
                snippet=reason
            )
        );
        name_n = self._stamp_manual(
            ast3.Name(id=_UNSUPPORTED_STMT, ctx=ast3.Load()),
            line,
            col,
            text=_UNSUPPORTED_STMT
        );
        reason_c = self._stamp_manual(
            ast3.Constant(value=reason), line, col, text=repr(reason)
        );
        call_n = self._stamp_manual(
            ast3.Call(func=name_n, args=[reason_c], keywords=[]), line, col
        );
        return self._stamp_manual(ast3.Expr(value=call_n), line, col);
    }

    def _surrogate_expr(c_node: object) -> object {
        (line, col) = self._loc(c_node);
        reason = f"{type(c_node).__name__} @ L{line}";
        self.tags.tag(
            c_node,
            NodeTag(
                tier=Tier.TIER_B,
                mechanism=Mechanism.PY_AST,
                idiom=Idiom.TIER_B,
                reason=reason,
                c_line=line,
                snippet=reason
            )
        );
        name_n = self._stamp_manual(
            ast3.Name(id=_UNSUPPORTED_EXPR, ctx=ast3.Load()),
            line,
            col,
            text=_UNSUPPORTED_EXPR
        );
        reason_c = self._stamp_manual(
            ast3.Constant(value=reason), line, col, text=repr(reason)
        );
        return self._stamp_manual(
            ast3.Call(func=name_n, args=[reason_c], keywords=[]), line, col
        );
    }

    def _mark_tier_b(c_node: object, reason: str) {
        (line, _) = self._loc(c_node);
        self.tags.tag(
            c_node,
            NodeTag(
                tier=Tier.TIER_B,
                mechanism=Mechanism.PY_AST,
                idiom=Idiom.TIER_B,
                reason=reason,
                c_line=line,
                snippet=reason
            )
        );
    }

    def _directir_placeholder(c_node: object) -> object {
        (line, col) = self._loc(c_node);
        sid = self._alloc_slot(c_node);
        name_n = self._stamp_manual(
            ast3.Name(id=_SLOT_SENTINEL, ctx=ast3.Load()),
            line,
            col,
            text=_SLOT_SENTINEL
        );
        sid_c = self._stamp_manual(ast3.Constant(value=sid), line, col, text=str(sid));
        call_n = self._stamp_manual(
            ast3.Call(func=name_n, args=[sid_c], keywords=[]), line, col
        );
        return self._stamp_manual(ast3.Expr(value=call_n), line, col);
    }

    def conv(c_node: object, *, stmt: bool = True) -> object {
        if stmt
        and isinstance(c_node, c_ast.UnaryOp)
        and c_node.op in ("p++", "++", "p--", "--") {
            inc = self._inc_dec_stmt(c_node);
            if inc is not None {
                return inc;
            }
        }
        meth = getattr(self, "c_" + type(c_node).__name__, None);
        if meth is None {
            if stmt {
                return self._surrogate_stmt(c_node);
            } else {
                return self._surrogate_expr(c_node);
            }
        }
        result = meth(c_node);

        if stmt and isinstance(result, ast3.expr) {
            line = getattr(result, "lineno", self._lineno);
            col = getattr(result, "col_offset", 0);
            return self._stamp_manual(ast3.Expr(value=result), line, col);
        }
        return result;
    }

    def _inc_dec_stmt(nd: object) -> object | None {
        target = self.conv_expr(nd.expr);
        if not (
            isinstance(target, ast3.Name)
            or isinstance(target, ast3.Attribute)
            or isinstance(target, ast3.Subscript)
        ) {
            return None;
        }
        self._to_store(target);
        op = ast3.Add() if nd.op in ("p++", "++") else ast3.Sub();
        (line, col) = self._loc(nd);
        one = self._stamp_manual(ast3.Constant(value=1), line, col, text="1");
        aug = ast3.AugAssign(target=target, op=op, value=one);
        return self._stamp_manual(aug, line, col, text=nd.op);
    }

    def conv_stmt(c_node: object) -> object {
        return self.conv(c_node, stmt=True);
    }

    def conv_expr(c_node: object) -> object {
        return self.conv(c_node, stmt=False);
    }

    def c_FileAST(nd: object) -> object {
        body: list[object] = [];
        for d in nd.ext {
            n = self.conv_stmt(d);
            if isinstance(n, list) {
                body += n;
            } else {
                body.append(n);
            }
        }
        if not body {
            body = [self._stamp_manual(ast3.Pass(), 1, 0)];
        }
        m = ast3.Module(body=body, type_ignores=[]);
        return m;
    }

    def c_Compound(nd: object) -> list[object] {
        stmts: list[object] = [];
        for item in (nd.block_items or []) {
            n = self.conv_stmt(item);
            if isinstance(n, list) {
                stmts += n;
            } else {
                stmts.append(n);
            }
        }
        return stmts;
    }

    def c_FuncDef(nd: object) -> object {
        name = nd.decl.name;
        params: list[object] = [];
        pl = nd.decl.type.args;
        if pl is not None {
            for p in pl.params {
                if p.name is None {
                    continue;
                }
                ann = self._type_ann(p);
                arg_n = ast3.arg(arg=p.name, annotation=ann);
                self._stamp(arg_n, p, text=p.name);
                params.append(arg_n);
            }
        }
        args = ast3.arguments(
            posonlyargs=[],
            args=params,
            vararg=None,
            kwonlyargs=[],
            kw_defaults=[],
            kwarg=None,
            defaults=[],
        );
        raw_body = self.c_Compound(nd.body);
        body: list[object] = raw_body or [self._stamp_manual(ast3.Pass(), 1, 0)];
        ret = self._ret_ann(nd.decl.type);
        fn = ast3.FunctionDef(
            name=name,
            args=args,
            body=body,
            decorator_list=[],
            returns=ret,
            type_params=[],
        );
        return self._stamp(fn, nd, text=name);
    }

    def c_Decl(nd: object) -> object {
        if nd.name is None {
            if isinstance(nd.type, c_ast.Struct) and nd.type.name is not None {
                return self.conv(nd.type);
            }

            if isinstance(nd.type, c_ast.Enum) {
                return self.conv(nd.type);
            }

            return self._surrogate_stmt(nd);
        }
        inner = nd.type;

        if isinstance(inner, c_ast.FuncDecl) {
            return [];
        }

        if isinstance(inner, c_ast.ArrayDecl) {
            return self._decl_array(nd);
        }

        if isinstance(inner, c_ast.TypeDecl) and isinstance(inner.type, c_ast.Struct) {
            return self._decl_struct_var(nd);
        }

        if isinstance(inner, c_ast.TypeDecl)
        and isinstance(inner.type, c_ast.Enum)
        and inner.type.values is not None {
            return self._directir_placeholder(inner.type);
        }
        target = ast3.Name(id=nd.name, ctx=ast3.Store());
        self._stamp(target, nd, text=nd.name);
        ann = self._type_ann(nd);
        nd_init = getattr(nd, "init");
        value = self.conv_expr(nd_init) if nd_init is not None else None;
        aa = ast3.AnnAssign(target=target, annotation=ann, value=value, simple=1);
        return self._stamp(aa, nd, text=nd.name);
    }

    def _decl_struct_var(nd: object) -> object {
        inner = nd.type;
        struct_name = inner.type.name or "object";
        target = ast3.Name(id=nd.name, ctx=ast3.Store());
        self._stamp(target, nd, text=nd.name);
        ann_n = ast3.Name(id=struct_name, ctx=ast3.Load());
        self._stamp(ann_n, nd, text=struct_name);
        nd_init = getattr(nd, "init");
        value = self.conv_expr(nd_init) if nd_init is not None else None;
        aa = ast3.AnnAssign(target=target, annotation=ann_n, value=value, simple=1);
        return self._stamp(aa, nd, text=nd.name);
    }

    def c_Assignment(nd: object) -> object {
        lhs = self.conv_expr(nd.lvalue);
        rhs = self.conv_expr(nd.rvalue);
        if nd.op == "=" {
            lhs_store = self._to_store(lhs);
            assign = ast3.Assign(targets=[lhs_store], value=rhs, type_comment=None);
            return self._stamp(assign, nd, text="=");
        }
        aug_entry = C_AUGOPS.get(nd.op);
        if aug_entry is not None {
            (ast_cls, _, _) = aug_entry;
            lhs_store = self._to_store(lhs);
            aug = ast3.AugAssign(
                target=lhs_store, op=getattr(ast3, ast_cls)(), value=rhs
            );
            return self._stamp(aug, nd, text=nd.op);
        }
        return self._surrogate_stmt(nd);
    }

    def _to_store(py_node: object) -> object {
        if isinstance(py_node, ast3.Name) {
            py_node.ctx = ast3.Store();
        } elif isinstance(py_node, ast3.Attribute) {
            py_node.ctx = ast3.Store();
        } elif isinstance(py_node, ast3.Subscript) {
            py_node.ctx = ast3.Store();
        }
        return py_node;
    }

    def c_BinaryOp(nd: object) -> object {
        entry = C_BINOPS.get(nd.op);
        if entry is None {
            return self._surrogate_expr(nd);
        }
        (kind, ast_cls, _, _) = entry;
        left = self.conv_expr(nd.left);
        right = self.conv_expr(nd.right);
        op_obj = getattr(ast3, ast_cls)();
        if kind == "arith" {
            expr_node = ast3.BinOp(left=left, op=op_obj, right=right);
        } elif kind == "compare" {
            expr_node = ast3.Compare(left=left, ops=[op_obj], comparators=[right]);
        } else {
            expr_node = ast3.BoolOp(op=op_obj, values=[left, right]);
        }
        return self._stamp(expr_node, nd, text=nd.op);
    }

    def c_If(nd: object) -> object {
        test = self.conv_expr(nd.cond);
        true_stmts = self._stmts_from(nd.iftrue);
        false_stmts: list[object] = [];
        if nd.iffalse is not None {
            false_stmts = self._stmts_from(nd.iffalse);
        }
        ifs = ast3.If(test=test, body=true_stmts, orelse=false_stmts);
        return self._stamp(ifs, nd, text="if");
    }

    def c_While(nd: object) -> object {
        test = self.conv_expr(nd.cond);
        body = self._stmts_from(nd.stmt);
        w = ast3.While(test=test, body=body, orelse=[]);
        return self._stamp(w, nd, text="while");
    }

    def _stmts_from(nd: object) -> list[object] {
        if isinstance(nd, c_ast.Compound) {
            return self.c_Compound(nd);
        }
        n = self.conv_stmt(nd);
        if isinstance(n, list) {
            return n or [self._stamp_manual(ast3.Pass(), 1, 0)];
        }
        return [n];
    }

    def c_Return(nd: object) -> object {
        val = self.conv_expr(nd.expr) if nd.expr is not None else None;
        r = ast3.Return(value=val);
        return self._stamp(r, nd, text="return");
    }

    def c_Break(nd: object) -> object {
        b = ast3.Break();
        return self._stamp(b, nd, text="break");
    }

    def c_Continue(nd: object) -> object {
        c = ast3.Continue();
        return self._stamp(c, nd, text="continue");
    }

    def c_FuncCall(nd: object) -> object {
        if isinstance(nd.name, c_ast.ID) and nd.name.name == "free" {
            return self._stamp_manual(ast3.Pass(), self._lineno, 0);
        }

        struct_name = self._malloc_struct_type(nd);
        if struct_name is not None {
            func_n = ast3.Name(id=struct_name, ctx=ast3.Load());
            self._stamp_manual(func_n, self._lineno, 0, text=struct_name);
            call = ast3.Call(func=func_n, args=[], keywords=[]);
            return self._stamp_manual(call, self._lineno, 0);
        }
        func = self.conv_expr(nd.name);
        args: list[object] = [];
        if nd.args {
            for e in nd.args.exprs {
                args.append(self.conv_expr(e));
            }
        }
        call = ast3.Call(func=func, args=args, keywords=[]);
        call_expr = self._stamp(call, nd, text="call");
        return call_expr;
    }

    def _malloc_struct_type(nd: object) -> str | None {
        if not isinstance(nd.name, c_ast.ID) or nd.name.name != "malloc" {
            return None;
        }
        if nd.args is None or len(nd.args.exprs) != 1 {
            return None;
        }
        arg = nd.args.exprs[0];
        if not isinstance(arg, c_ast.UnaryOp) or arg.op != "sizeof" {
            return None;
        }
        inner = arg.expr;
        if isinstance(inner, c_ast.Typename)
        and isinstance(inner.type, c_ast.TypeDecl) {
            return self._user_type_name(inner.type.type);
        }
        if isinstance(inner, c_ast.ID) {
            return inner.name;
        }
        return None;
    }

    def c_ID(nd: object) -> object {
        n = ast3.Name(id=nd.name, ctx=ast3.Load());
        return self._stamp(n, nd, text=nd.name);
    }

    def c_Constant(nd: object) -> object {
        if nd.type == "int" {
            iv = parse_c_int(nd.value);
            val: object = iv if iv is not None else repr(nd.value);
        } elif nd.type in ("double", "float") {
            fv = parse_c_float(nd.value);
            val = fv if fv is not None else repr(nd.value);
        } elif nd.type == "char" {
            raw = nd.value;
            if raw.startswith("'") and raw.endswith("'") {
                val = raw[1:-1];
            } else {
                val = raw;
            }
        } elif nd.type == "string" {
            raw = nd.value;
            if raw.startswith('"') and raw.endswith('"') {
                try {
                    val = bytes(raw[1:-1], "utf-8").decode("unicode_escape");
                } except Exception {
                    val = raw[1:-1];
                }
            } else {
                val = raw;
            }
        } else {
            val = repr(nd.value);
        }
        c = ast3.Constant(value=val);
        return self._stamp(c, nd, text=str(nd.value));
    }

    def c_UnaryOp(nd: object) -> object {
        unary_map: dict[str, object] = {
            "-": ast3.USub(),
            "+": ast3.UAdd(),
            "~": ast3.Invert(),
            "!": ast3.Not(),

        };
        if nd.op in unary_map {
            operand = self.conv_expr(nd.expr);
            u = ast3.UnaryOp(op=unary_map[nd.op], operand=operand);
            return self._stamp(u, nd, text=nd.op);
        }

        if nd.op in ("p++", "++", "p--", "--") {
            return self._surrogate_expr(nd);
        }
        if nd.op == "*" {
            return self._surrogate_expr(nd);
        }
        if nd.op == "&" {
            return self._surrogate_expr(nd);
        }
        if nd.op == "sizeof" {
            return self._surrogate_expr(nd);
        }
        return self._surrogate_expr(nd);
    }

    def c_Struct(nd: object) -> object {
        name = nd.name or "_AnonStruct";
        fields: list[object] = [];
        if nd.decls {
            for mem in nd.decls {
                ann_assign = self._struct_field(mem);
                if ann_assign is not None {
                    fields.append(ann_assign);
                }
            }
        }
        body: list[object] = fields or [self._stamp_manual(ast3.Pass(), 1, 0)];
        cls = ast3.ClassDef(
            name=name, bases=[], keywords=[], body=body, decorator_list=[]
        );
        return self._stamp(cls, nd, text=name);
    }

    def _struct_field(mem: object) -> object | None {
        if mem.name is None {
            return None;
        }
        target = ast3.Name(id=mem.name, ctx=ast3.Store());
        self._stamp(target, mem, text=mem.name);
        ann = self._type_ann(mem);
        aa = ast3.AnnAssign(target=target, annotation=ann, value=None, simple=1);
        return self._stamp(aa, mem, text=mem.name);
    }

    def c_Typedef(nd: object) -> object {
        inner = nd.type;
        if isinstance(inner, c_ast.TypeDecl) and isinstance(inner.type, c_ast.Struct) {
            s = inner.type;
            name = nd.name;
            fields: list[object] = [];
            if s.decls {
                for mem in s.decls {
                    aa = self._struct_field(mem);
                    if aa is not None {
                        fields.append(aa);
                    }
                }
            }
            body: list[object] = fields or [self._stamp_manual(ast3.Pass(), 1, 0)];
            cls = ast3.ClassDef(
                name=name, bases=[], keywords=[], body=body, decorator_list=[]
            );
            return self._stamp(cls, nd, text=name);
        }

        (line, col) = self._loc(nd);
        target = self._stamp_manual(
            ast3.Name(id=nd.name, ctx=ast3.Store()), line, col, text=nd.name
        );
        val_name = self._typename(nd.type);
        value = self._stamp_manual(
            ast3.Name(id=val_name, ctx=ast3.Load()), line, col, text=val_name
        );
        assign = ast3.Assign(targets=[target], value=value, type_comment=None);
        return self._stamp_manual(assign, line, col, text=nd.name);
    }

    def c_StructRef(nd: object) -> object {
        obj_expr = self.conv_expr(nd.name);
        field_name = nd.field.name;
        attr = ast3.Attribute(value=obj_expr, attr=field_name, ctx=ast3.Load());
        return self._stamp(attr, nd, text=field_name);
    }

    def c_ArrayDecl(nd: object) -> object {
        return self._surrogate_stmt(nd);
    }

    def _decl_array(nd: object) -> object {
        arr_decl = nd.type;
        elem_type = self._type_ann_from_type(arr_decl.type);
        list_ann = ast3.Subscript(
            value=ast3.Name(id="list", ctx=ast3.Load()),
            slice=elem_type,
            ctx=ast3.Load(),
        );
        self._stamp_manual(list_ann, self._lineno, 0, text="list");
        target = ast3.Name(id=nd.name, ctx=ast3.Store());
        self._stamp(target, nd, text=nd.name);
        value: object | None = None;
        nd_init = getattr(nd, "init");
        if nd_init is not None {
            value = self.conv_expr(nd_init);
        } elif arr_decl.dim is not None {
            dim_expr = self.conv_expr(arr_decl.dim);
            elem_default_name = self._typename(arr_decl.type);
            elem_call = ast3.Call(
                func=ast3.Name(id=elem_default_name, ctx=ast3.Load()),
                args=[],
                keywords=[],
            );
            self._stamp_manual(elem_call, self._lineno, 0);
            mult = ast3.BinOp(
                left=ast3.List(elts=[elem_call], ctx=ast3.Load()),
                op=ast3.Mult(),
                right=dim_expr
            );
            self._stamp_manual(mult, self._lineno, 0);
            value = mult;
        }
        aa = ast3.AnnAssign(target=target, annotation=list_ann, value=value, simple=1);
        return self._stamp(aa, nd, text=nd.name);
    }

    def c_InitList(nd: object) -> object {
        elts: list[object] = [];
        for expr in nd.exprs {
            elts.append(self.conv_expr(expr));
        }
        lst = ast3.List(elts=elts, ctx=ast3.Load());
        return self._stamp(lst, nd, text="[]");
    }

    def c_ArrayRef(nd: object) -> object {
        arr = self.conv_expr(nd.name);
        idx = self.conv_expr(nd.subscript);
        s = ast3.Subscript(value=arr, slice=idx, ctx=ast3.Load());
        return self._stamp(s, nd, text="[]");
    }

    def c_NamedInitializer(nd: object) -> object {
        field = ".".join([self._desig_name(d) for d in (nd.name or [])]);
        self._mark_tier_b(
            nd,
            f"designated initializer `.{field}=` — target field name dropped; "
            f"value emitted positionally, verify it lands on the intended member",
        );
        return self.conv_expr(nd.expr);
    }

    def _desig_name(d: object) -> str {
        return d.name if isinstance(d, c_ast.ID) else str(getattr(d, "value", "?"));
    }

    def c_ExprList(nd: object) -> object {
        if nd.exprs {
            if len(nd.exprs) > 1 {
                self._mark_tier_b(
                    nd,
                    f"comma expression — side effects of {len(nd.exprs) - 1} "
                    f"leading operand(s) dropped, only the final value emitted; verify",
                );
            }
            return self.conv_expr(nd.exprs[-1]);
        }
        return self._surrogate_expr(nd);
    }

    def c_Cast(nd: object) -> object {
        target = self._cast_scalar_target(nd);
        if target is not None {
            self._mark_tier_b(
                nd,
                f"cast to `{target}` elided — representation-changing conversion "
                f"(truncation/narrowing/discard) not applied; verify",
            );
        }
        return self.conv_expr(nd.expr);
    }

    def _cast_scalar_target(nd: object) -> str | None {
        to_type = nd?.to_type;
        if to_type is None {
            return None;
        }
        inner = to_type?.type;
        if isinstance(inner, c_ast.TypeDecl)
        and isinstance(inner.type, c_ast.IdentifierType) {
            names = inner.type.names;
            return names[-1] if names else None;
        }
        return None;
    }

    def c_For(nd: object) -> object {
        return self._directir_placeholder(nd);
    }

    def c_Enum(nd: object) -> object {
        return self._directir_placeholder(nd);
    }

    def c_Enumerator(nd: object) -> object {
        return self._surrogate_stmt(nd);
    }

    def c_EnumeratorList(nd: object) -> object {
        return self._surrogate_stmt(nd);
    }

    def _prim_typename(names: list) -> str {
        if not names {
            return "int";
        }
        return _C_PRIM_MAP.get(names[-1], "int");
    }

    def _user_type_name(t: object) -> str | None {
        if isinstance(t, c_ast.Struct) and t.name {
            return t.name;
        }
        names = t?.names;
        if names and names[-1] not in _C_BUILTIN_TYPES {
            return names[-1];
        }
        return None;
    }

    def _ptr_typename(ptr_decl: object) -> str {
        inner = ptr_decl.type;
        if isinstance(inner, c_ast.TypeDecl) {
            names = inner.type?.names or [];
            if "char" in names {
                return "str";
            }
            user = self._user_type_name(inner.type);
            if user is not None {
                return user;
            }
        }
        return "object";
    }

    def _typename(decl_type: object) -> str {
        t = decl_type;
        while not isinstance(t, c_ast.TypeDecl) {
            if isinstance(t, c_ast.ArrayDecl) {
                return "list";
            }
            if isinstance(t, c_ast.PtrDecl) {
                return self._ptr_typename(t);
            }
            if isinstance(t, c_ast.FuncDecl) {
                t = t.type;
                continue;
            }
            t = t?.type;
            if t is None {
                return "int";
            }
        }
        names = t.type?.names or ["int"];
        return self._prim_typename(names);
    }

    def _type_ann(decl: object) -> object {
        name = self._typename(decl.type);
        n = ast3.Name(id=name, ctx=ast3.Load());
        return self._stamp(n, decl, text=name);
    }

    def _type_ann_from_type(t: object) -> object {
        name = self._typename(t);
        (line, col) = (self._lineno, 0);
        n = ast3.Name(id=name, ctx=ast3.Load());
        return self._stamp_manual(n, line, col, text=name);
    }

    def _ret_ann(funcdecl: object) -> object {
        name = self._typename(funcdecl.type);
        n = ast3.Name(id=name, ctx=ast3.Load());
        n.lineno = 1;
        n.col_offset = 0;
        n.end_lineno = 1;
        n.end_col_offset = len(name);
        return n;
    }
}
