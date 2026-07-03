glob _MAX_QUAL_DEPTH: int = 8;

impl CMapper._conv_stmts(items: list) -> list[object] {
    out: list[object] = [];
    for item in items {
        n = self.conv_stmt(item);
        if isinstance(n, list) {
            out += n;
        } else {
            out.append(n);
        }
    }
    return out;
}

impl CMapper.c_FileAST(nd: object) -> object {
    body: list[object] = self._conv_stmts(nd.ext);
    if not body {
        body = [self._stamp_manual(ast3.Pass(), 1, 0)];
    }
    m = ast3.Module(body=body, type_ignores=[]);
    return m;
}

impl CMapper.c_Compound(nd: object) -> list[object] {
    return self._conv_stmts(nd.block_items or []);
}

impl CMapper.c_FuncDef(nd: object) -> object {
    self._list_bound = set();

    self._var_types = {};
    name = nd.decl.name;
    params: list[object] = [];
    vararg = None;
    pl = nd.decl.type.args;
    if pl is not None {
        for p in pl.params {
            if isinstance(p, c_ast.EllipsisParam) {
                vararg = ast3.arg(arg="args", annotation=None);
                self._stamp(vararg, p, text="...");
                if self._body_inspects_varargs(nd.body) {
                    self._mark_tier_b(
                        nd.decl,
                        "variadic `...` lowered to Jac `*args`: va_list/va_arg "
                        "semantics are not modelled — verify"
                    );
                }
                continue;
            }
            if p.name is None {
                continue;
            }
            ann = self._type_ann(p);
            arg_n = ast3.arg(arg=p.name, annotation=ann);
            self._stamp(arg_n, p, text=p.name);
            params.append(arg_n);

            self._record_scalar_type(p.name, p.type);
        }
    }
    args = ast3.arguments(
        posonlyargs=[],
        args=params,
        vararg=vararg,
        kwonlyargs=[],
        kw_defaults=[],
        kwarg=None,
        defaults=[],
    );

    self._func_depth += 1;

    prev_ret_is_ptr = self._ret_is_ptr;
    self._ret_is_ptr = isinstance(nd.decl.type.type, c_ast.PtrDecl);
    raw_body = self.c_Compound(nd.body);
    self._ret_is_ptr = prev_ret_is_ptr;
    self._func_depth -= 1;
    body: list[object] = raw_body or [self._stamp_manual(ast3.Pass(), 1, 0)];
    ret = self._ret_ann(nd.decl.type);
    fn = ast3.FunctionDef(
        name=name, args=args, body=body, decorator_list=[], returns=ret, type_params=[],
    );
    return self._stamp(fn, nd, text=name);
}

impl CMapper._body_inspects_varargs(nd: object) -> bool {
    if nd is None {
        return False;
    }
    if isinstance(nd, c_ast.IdentifierType) and "va_list" in (nd?.names or []) {
        return True;
    }
    if isinstance(nd, c_ast.FuncCall)
    and isinstance(nd.name, c_ast.ID)
    and nd.name.name in ("va_start", "va_arg", "va_end", "va_copy") {
        return True;
    }
    for (_, child) in nd.children() {
        if self._body_inspects_varargs(child) {
            return True;
        }
    }
    return False;
}

impl CMapper.c_Decl(nd: object) -> object {
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
    storage = nd.storage or [];
    quals = self._all_quals(nd);

    if "extern" in storage and getattr(nd, "init") is None {
        return [];
    }

    if "static" in storage and self._func_depth > 0 {
        self._mark_tier_b(nd, "function-local 'static' loses cross-call persistence");
    }

    if "volatile" in quals {
        self._mark_tier_b(
            nd, "'volatile' qualifier dropped (Jac cannot suppress read caching)"
        );
    }

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

    self._record_scalar_type(nd.name, inner);
    target = ast3.Name(id=nd.name, ctx=ast3.Store());
    self._stamp(target, nd, text=nd.name);
    nd_init = getattr(nd, "init");
    value = self.conv_expr(nd_init) if nd_init is not None else None;

    arr_elem = malloc_array_match(nd_init) if nd_init is not None else None;
    if arr_elem is not None {
        ann = self._list_ann_of(arr_elem);
        self._list_bound.add(nd.name);
    } else {
        ann = self._type_ann(nd);
        self._list_bound.discard(nd.name);
    }

    if value is None and (self._func_depth == 0 or "static" in storage) {
        value = self._zero_default(inner);
    }
    aa = ast3.AnnAssign(target=target, annotation=ann, value=value, simple=1);
    return self._stamp(aa, nd, text=nd.name);
}

impl CMapper._all_quals(nd: object) -> set {
    quals: set = set(nd?.quals or []);
    t = nd?.type;
    for _ in range(_MAX_QUAL_DEPTH) {
        if t is None {
            break;
        }
        quals |= set(t?.quals or []);
        t = t?.type;
    }
    return quals;
}

impl CMapper._decl_struct_var(nd: object) -> object {
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

impl CMapper._zero_default(inner: object) -> object {
    (line, col) = (self._lineno, 0);
    if isinstance(inner, c_ast.PtrDecl) {
        return self._stamp_manual(ast3.Constant(value=None), line, col, text="None");
    }
    names: list = [];
    if isinstance(inner, c_ast.TypeDecl) {
        names = inner.type?.names or [];
    }
    jac = jac_prim(names);
    if jac == JacPrim.STR {
        val: object = "";
        t: str = '""';
    } else {
        pz = jac_prim_zero(jac);
        val = pz.value;
        t = pz.text;
    }
    return self._stamp_manual(ast3.Constant(value=val), line, col, text=t);
}

impl CMapper.c_Assignment(nd: object) -> object {
    if nd.op == "=" and isinstance(nd.rvalue, c_ast.Assignment) {
        inner = self.conv_stmt(nd.rvalue);
        inner_stmts: list[object] = [inner] if not isinstance(inner, list) else inner;
        (line, col) = self._loc(nd);
        lhs = self.conv_expr(nd.lvalue);
        lhs_store = self._to_store(lhs);
        leaf = nd.rvalue;
        while isinstance(leaf.rvalue, c_ast.Assignment) {
            leaf = leaf.rvalue;
        }
        final_rhs = self.conv_expr(leaf.rvalue);
        outer = ast3.Assign(targets=[lhs_store], value=final_rhs, type_comment=None);
        outer_stmt = self._stamp(outer, nd, text="=");
        return inner_stmts + [outer_stmt];
    }

    lhs = self.conv_expr(nd.lvalue);

    rhs = self.conv_expr(nd.rvalue);

    if nd.op == "=" and isinstance(nd.lvalue, c_ast.ID) {
        if malloc_array_match(nd.rvalue) is not None
        or realloc_of_list_bound(nd.rvalue, self._list_bound) {
            self._list_bound.add(nd.lvalue.name);
        } else {
            self._list_bound.discard(nd.lvalue.name);
        }
    }
    if nd.op == "=" {
        lhs_store = self._to_store(lhs);
        assign = ast3.Assign(targets=[lhs_store], value=rhs, type_comment=None);
        return self._stamp(assign, nd, text="=");
    }
    aug_entry = C_AUGOPS.get(nd.op);
    if aug_entry is not None {
        ast_cls = aug_entry;
        lhs_store = self._to_store(lhs);
        aug = ast3.AugAssign(target=lhs_store, op=getattr(ast3, ast_cls)(), value=rhs);
        return self._stamp(aug, nd, text=nd.op);
    }
    return self._surrogate_stmt(nd);
}

impl CMapper._struct_classdef(snode: object, name: str, origin: object) -> object {
    fields: list[object] = [];
    if snode.decls {
        for mem in snode.decls {
            aa = self._struct_field(mem);
            if aa is not None {
                fields.append(aa);
            }
        }
    }
    body: list[object] = fields or [self._stamp_manual(ast3.Pass(), 1, 0)];
    cls = ast3.ClassDef(name=name, bases=[], keywords=[], body=body, decorator_list=[]);
    return self._stamp(cls, origin, text=name);
}

impl CMapper.c_Struct(nd: object) -> object {
    return self._struct_classdef(nd, nd.name or "_AnonStruct", nd);
}

impl CMapper._struct_field(mem: object) -> object | None {
    if mem.name is None {
        return None;
    }
    target = ast3.Name(id=mem.name, ctx=ast3.Store());
    self._stamp(target, mem, text=mem.name);
    ann = self._type_ann(mem);
    aa = ast3.AnnAssign(target=target, annotation=ann, value=None, simple=1);
    return self._stamp(aa, mem, text=mem.name);
}

impl CMapper.c_Typedef(nd: object) -> object {
    inner = nd.type;
    if isinstance(inner, c_ast.TypeDecl) and isinstance(inner.type, c_ast.Struct) {
        return self._struct_classdef(inner.type, nd.name, nd);
    }

    (line, col) = self._loc(nd);
    target = self._stamp_manual(
        ast3.Name(id=nd.name, ctx=ast3.Store()), line, col, text=nd.name
    );
    val_name = typename(nd.type);
    value = self._stamp_manual(
        ast3.Name(id=val_name, ctx=ast3.Load()), line, col, text=val_name
    );
    assign = ast3.Assign(targets=[target], value=value, type_comment=None);
    return self._stamp_manual(assign, line, col, text=nd.name);
}

impl CMapper._decl_array(nd: object) -> object {
    arr_decl = nd.type;

    elem_name = elem_typename(arr_decl.type);
    elem_type = self._stamp_manual(
        ast3.Name(id=elem_name, ctx=ast3.Load()), self._lineno, 0, text=elem_name
    );
    list_ann = ast3.Subscript(
        value=ast3.Name(id="list", ctx=ast3.Load()), slice=elem_type, ctx=ast3.Load(),
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
        elem_default_name = elem_name;
        elem_node = self._elem_default(elem_default_name);
        if elem_default_name in C_PRIM_MAP {
            mult = ast3.BinOp(
                left=ast3.List(elts=[elem_node], ctx=ast3.Load()),
                op=ast3.Mult(),
                right=dim_expr
            );
            self._stamp_manual(mult, self._lineno, 0);
            value = mult;
        } else {
            range_fn = self._stamp_manual(
                ast3.Name(id="range", ctx=ast3.Load()), self._lineno, 0, text="range"
            );
            range_call = self._stamp_manual(
                ast3.Call(func=range_fn, args=[dim_expr], keywords=[]), self._lineno, 0
            );
            tgt = self._stamp_manual(
                ast3.Name(id="_", ctx=ast3.Store()), self._lineno, 0, text="_"
            );
            gen = ast3.comprehension(target=tgt, iter=range_call, ifs=[], is_async=0);
            lc = ast3.ListComp(elt=elem_node, generators=[gen]);
            value = self._stamp_manual(lc, self._lineno, 0, text="[]");
        }
    }
    aa = ast3.AnnAssign(target=target, annotation=list_ann, value=value, simple=1);
    return self._stamp(aa, nd, text=nd.name);
}

impl CMapper.c_ArrayDecl(nd: object) -> object {
    return self._surrogate_stmt(nd);
}

impl CMapper.c_Enum(nd: object) -> object {
    return self._directir_placeholder(nd);
}

impl CMapper._type_ann(decl: object) -> object {
    name = elem_typename(decl.type);
    n = ast3.Name(id=name, ctx=ast3.Load());
    return self._stamp(n, decl, text=name);
}

impl CMapper._type_ann_from_type(t: object) -> object {
    name = typename(t);
    (line, col) = (self._lineno, 0);
    n = ast3.Name(id=name, ctx=ast3.Load());
    return self._stamp_manual(n, line, col, text=name);
}

impl CMapper._ret_ann(funcdecl: object) -> object {
    name = elem_typename(funcdecl.type);
    n = ast3.Name(id=name, ctx=ast3.Load());
    n.lineno = 1;
    n.col_offset = 0;
    n.end_lineno = 1;
    n.end_col_offset = len(name);
    return n;
}

impl CMapper._list_ann_of(tname: str) -> object {
    raw = C_PRIM_MAP.get(tname);
    jac: str = raw.value if raw is not None else tname;
    elem = self._stamp_manual(
        ast3.Name(id=jac, ctx=ast3.Load()), self._lineno, 0, text=jac
    );
    lst = self._stamp_manual(
        ast3.Name(id="list", ctx=ast3.Load()), self._lineno, 0, text="list"
    );
    sub = ast3.Subscript(value=lst, slice=elem, ctx=ast3.Load());
    return self._stamp_manual(sub, self._lineno, 0, text="list");
}
