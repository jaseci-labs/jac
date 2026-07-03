impl CMapper.c_BinaryOp(nd: object) -> object {
    entry = C_BINOPS.get(nd.op);
    if entry is None {
        return self._surrogate_expr(nd);
    }
    (kind, ast_cls) = entry;
    left = self._binop_operand(nd.left, nd.right);
    right = self._binop_operand(nd.right, nd.left);
    op_obj = getattr(ast3, ast_cls)();
    if kind == BinKind.ARITH {
        expr_node = ast3.BinOp(left=left, op=op_obj, right=right);
    } elif kind == BinKind.COMPARE {
        expr_node = ast3.Compare(left=left, ops=[op_obj], comparators=[right]);
    } else {
        expr_node = ast3.BoolOp(op=op_obj, values=[left, right]);
    }
    return self._stamp(expr_node, nd, text=nd.op);
}

impl CMapper._binop_operand(operand: object, sibling: object) -> object {
    if isinstance(operand, c_ast.Constant)
    and classify_c_constant(operand.type) == CLIT_CHAR
    and self._expr_prim(sibling) in (JacPrim.INT, JacPrim.FLOAT, JacPrim.BOOL) {
        ov = c_char_ord(operand.value);
        if ov is not None {
            (line, col) = self._loc(operand);
            return self._stamp_manual(ast3.Constant(value=ov), line, col, text=str(ov));
        }
    }
    return self.conv_expr(operand);
}

impl CMapper._expr_prim(c_node: object) -> JacPrim | None {
    if isinstance(c_node, c_ast.Constant) {
        fam = classify_c_constant(c_node.type);
        if fam == CLIT_INT {
            return JacPrim.INT;
        }
        if fam == CLIT_FLOAT {
            return JacPrim.FLOAT;
        }

        return JacPrim.STR;
    }
    if isinstance(c_node, c_ast.ID) {
        return self._var_types.get(c_node.name);
    }
    return None;
}

impl CMapper._scalar_prim(type_node: object) -> JacPrim | None {
    if isinstance(type_node, c_ast.TypeDecl)
    and isinstance(type_node.type, c_ast.IdentifierType) {
        return jac_prim(type_node.type.names);
    }
    return None;
}

impl CMapper._record_scalar_type(name: str, type_node: object) {
    prim = self._scalar_prim(type_node);
    if prim is not None {
        self._var_types[name] = prim;
    } elif name in self._var_types {
        del self._var_types[name];
    }
}

impl CMapper.c_UnaryOp(nd: object) -> object {
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

    if nd.op in ("++", "--") {
        walrus = self._pre_incdec_walrus(nd);
        if walrus is not None {
            return walrus;
        }
        return self._surrogate_expr(nd);
    }
    if nd.op in ("p++", "p--") {
        return self._surrogate_expr(nd);
    }
    if nd.op == "*" {
        if is_simple_ref(nd.expr) {
            self._mark_tier_a(nd, Idiom.PTR_REF, "pointer dereference → Jac reference");
            return self.conv_expr(nd.expr);
        }
        return self._surrogate_expr(nd);
    }
    if nd.op == "&" {
        if is_simple_ref(nd.expr) {
            self._mark_tier_a(nd, Idiom.PTR_REF, "address-of → Jac reference");
            return self.conv_expr(nd.expr);
        }
        return self._surrogate_expr(nd);
    }
    if nd.op == "sizeof" {
        return self._surrogate_expr(nd);
    }
    return self._surrogate_expr(nd);
}

impl CMapper._pre_incdec_walrus(nd: object) -> object | None {
    if not isinstance(nd.expr, c_ast.ID) {
        return None;
    }
    if self._expr_prim(nd.expr) not in (JacPrim.INT, JacPrim.FLOAT) {
        return None;
    }
    name = nd.expr.name;
    (line, col) = self._loc(nd);
    target = self._stamp_manual(
        ast3.Name(id=name, ctx=ast3.Store()), line, col, text=name
    );
    load = self._stamp_manual(
        ast3.Name(id=name, ctx=ast3.Load()), line, col, text=name
    );
    one = self._stamp_manual(ast3.Constant(value=1), line, col, text="1");
    op_obj = ast3.Add() if nd.op == "++" else ast3.Sub();
    binop = self._stamp_manual(
        ast3.BinOp(left=load, op=op_obj, right=one), line, col, text=nd.op
    );
    walrus = ast3.NamedExpr(target=target, value=binop);
    self._stamp_manual(walrus, line, col, text=":=");
    self._mark_tier_a(
        nd,
        Idiom.PRE_INCDEC,
        "pre-inc/dec → Jac walrus `(x := x ± 1)` — faithful: the prefix value "
        "is the new value, exactly what `:=` yields",
    );
    return walrus;
}

impl CMapper.c_ID(nd: object) -> object {
    n = ast3.Name(id=nd.name, ctx=ast3.Load());
    return self._stamp(n, nd, text=nd.name);
}

impl CMapper.c_Constant(nd: object) -> object {
    txt: str = str(nd.value);

    family = classify_c_constant(nd.type);
    if family == CLIT_INT {
        iv = parse_c_int(nd.value);
        if iv is not None {
            val: object = iv;
            txt = str(iv);
        } else {
            self._mark_tier_b(
                nd,
                "integer literal `" + str(nd.value) + "` could not be parsed; "
                "emitted as a string placeholder — verify",
            );
            val = repr(nd.value);
        }
    } elif family == CLIT_FLOAT {
        fv = parse_c_float(nd.value);
        if fv is not None {
            val = fv;
            txt = str(fv);
        } else {
            self._mark_tier_b(
                nd,
                "float literal `" + str(nd.value) + "` could not be parsed; "
                "emitted as a string placeholder — verify",
            );
            val = repr(nd.value);
        }
    } elif family == CLIT_CHAR {
        val = c_char_text(nd.value);
    } elif family == CLIT_STRING {
        inner = c_string_inner(nd.value);
        if inner is not None {
            if inner.isascii() {
                try {
                    val = bytes(inner, "utf-8").decode("unicode_escape");
                } except Exception {
                    val = inner;
                }
            } else {
                val = inner;
            }
        } else {
            val = nd.value;
        }
    } else {
        self._mark_tier_b(
            nd,
            "constant of unrecognized type `" + str(nd.type) + "` emitted as a "
            "string placeholder — verify",
        );
        val = repr(nd.value);
    }
    c = ast3.Constant(value=val);
    stamped = self._stamp(c, nd, text=txt);
    if nd.type == "string" {
        (sline, scol) = self._loc(nd);
        stamped.end_col_offset = scol + len(str(nd.value).encode("utf-8"));
    }
    return stamped;
}

impl CMapper.c_StructRef(nd: object) -> object {
    obj_expr = self.conv_expr(nd.name);
    field_name = nd.field.name;
    attr = ast3.Attribute(value=obj_expr, attr=field_name, ctx=ast3.Load());
    return self._stamp(attr, nd, text=field_name);
}

impl CMapper.c_ArrayRef(nd: object) -> object {
    arr = self.conv_expr(nd.name);
    idx = self.conv_expr(nd.subscript);
    s = ast3.Subscript(value=arr, slice=idx, ctx=ast3.Load());
    return self._stamp(s, nd, text="[]");
}

impl CMapper.c_InitList(nd: object) -> object {
    elts: list[object] = [];
    for expr in nd.exprs {
        elts.append(self.conv_expr(expr));
    }
    lst = ast3.List(elts=elts, ctx=ast3.Load());
    return self._stamp(lst, nd, text="[]");
}

impl CMapper.c_NamedInitializer(nd: object) -> object {
    field = ".".join([self._desig_name(d) for d in (nd.name or [])]);
    self._mark_tier_b(
        nd,
        f"designated initializer `.{field}=` — target field name dropped; "
        f"value emitted positionally, verify it lands on the intended member",
    );
    return self.conv_expr(nd.expr);
}

impl CMapper._desig_name(d: object) -> str {
    return d.name if isinstance(d, c_ast.ID) else str(getattr(d, "value", "?"));
}

impl CMapper.c_ExprList(nd: object) -> object {
    if nd.exprs {
        impure = [
            e
            for e in nd.exprs[:-1]
            if not expr_reeval_safe(e)
        ];
        if impure {
            self._mark_tier_b(
                nd,
                f"comma expression — side effects of {len(impure)} leading "
                f"operand(s) dropped, only the final value emitted; verify",
            );
        }
        return self.conv_expr(nd.exprs[-1]);
    }
    return self._surrogate_expr(nd);
}

impl CMapper.c_Cast(nd: object) -> object {
    target = cast_scalar_target(nd);
    if target is not None {
        self._mark_tier_b(
            nd,
            f"cast to `{target}` elided — representation-changing conversion "
            f"(truncation/narrowing/discard) not applied; verify",
        );
    }
    return self.conv_expr(nd.expr);
}

impl CMapper.c_FuncCall(nd: object) -> object {
    if isinstance(nd.name, c_ast.ID) and nd.name.name == "free" {
        self._mark_tier_a(nd, Idiom.FREE_ELIDE, "free() elided — Jac GC reclaims");
        return self._stamp_manual(ast3.Pass(), self._lineno, 0);
    }

    if isinstance(nd.name, c_ast.ID) and nd.name.name == "realloc" {
        re = self._realloc_elide(nd);
        if re is not None {
            return re;
        }
    }

    arr = self._malloc_array(nd);
    if arr is not None {
        self._mark_tier_a(nd, Idiom.LIST_OF_OBJECTS, "malloc(n*sizeof(T)) → list[T]");
        return arr;
    }

    struct_name = malloc_struct_type(nd);
    if struct_name is not None {
        self._mark_tier_a(
            nd, Idiom.OBJECT_CREATE, "malloc(sizeof(T)) → T() constructor"
        );
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

impl CMapper._realloc_elide(nd: object) -> object | None {
    ptr = realloc_ptr_arg(nd);
    if ptr is None {
        return None;
    }
    py_ptr = self.conv_expr(ptr);
    if isinstance(ptr, c_ast.ID) and ptr.name in self._list_bound {
        self._mark_tier_a(
            nd,
            Idiom.REALLOC_ELIDE,
            "realloc on list-bound pointer elided — Jac list grows under GC",
        );
    } else {
        self._mark_tier_b_idiom(
            nd,
            Idiom.REALLOC_ELIDE,
            "realloc elided to its pointer arg, but the pointer is not proven "
            "list-bound; if it backed a raw buffer the resize is lost — verify",
        );
    }
    return py_ptr;
}

impl CMapper._elem_default(tname: str) -> object {
    if tname in C_PRIM_MAP {
        jac = C_PRIM_MAP.get(tname, JacPrim.INT);
        val = jac_prim_zero(jac).value;
        return self._stamp_manual(ast3.Constant(value=val), self._lineno, 0);
    }
    fn = ast3.Name(id=tname, ctx=ast3.Load());
    self._stamp_manual(fn, self._lineno, 0, text=tname);
    call = ast3.Call(func=fn, args=[], keywords=[]);
    return self._stamp_manual(call, self._lineno, 0);
}

impl CMapper._product_expr(factors: list) -> object {
    exprs = [self.conv_expr(f) for f in factors];
    acc = exprs[0];
    i = 1;
    while i < len(exprs) {
        acc = ast3.BinOp(left=acc, op=ast3.Mult(), right=exprs[i]);
        self._stamp_manual(acc, self._lineno, 0, text="*");
        i += 1;
    }
    return acc;
}

impl CMapper._malloc_array(nd: object) -> object | None {
    tname = malloc_array_match(nd);
    if tname is None {
        return None;
    }
    default = self._elem_default(tname);
    factors: list = [];
    flatten_mult(nd.args.exprs[0], factors);
    others = [
        f
        for f in factors
        if sizeof_type(f) is None
    ];
    count = self._product_expr(others);
    range_fn = self._stamp_manual(
        ast3.Name(id="range", ctx=ast3.Load()), self._lineno, 0, text="range"
    );
    range_call = self._stamp_manual(
        ast3.Call(func=range_fn, args=[count], keywords=[]), self._lineno, 0
    );
    tgt = self._stamp_manual(
        ast3.Name(id="_", ctx=ast3.Store()), self._lineno, 0, text="_"
    );
    comp = ast3.comprehension(target=tgt, iter=range_call, ifs=[], is_async=0);
    lc = ast3.ListComp(elt=default, generators=[comp]);
    return self._stamp_manual(lc, self._lineno, 0, text="[]");
}
