"""Declaration / binding handlers — anything that introduces a name or
a type: file & compound scopes, functions, variable & array decls,
assignments, structs, typedefs, enums, plus the C-type annotation helpers."""

impl CMapper.c_FileAST(nd: object) -> object {
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

impl CMapper.c_Compound(nd: object) -> list[object] {
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

impl CMapper.c_FuncDef(nd: object) -> object {
    # Reset list-bound tracking per function — a name proven list-bound in one
    # function must not license a Tier-A realloc-elide on a same-named param in
    # another (§7.5).
    self._list_bound = set();
    # Reset scalar-var type tracking per function (used for char-literal
    # promotion in binary ops) — a name's type in one function must not leak
    # into another.
    self._var_types = {};
    name = nd.decl.name;
    params: list[object] = [];
    vararg = None;
    pl = nd.decl.type.args;
    if pl is not None {
        for p in pl.params {
            if isinstance(p, c_ast.EllipsisParam) {
                # Variadic `...` (§roadmap #9): always map the *declaration* to a
                # Jac `*args` so the signature stays callable. Lowering `...` to
                # `*args` is fully faithful when the body ignores the extra args —
                # they are harmlessly accepted — so that case stays Tier-A. Only a
                # body that actually reaches into the varargs (a `va_list` object
                # or a `va_start`/`va_arg`/`va_end` call), which Jac cannot model,
                # keeps the function Tier-B.
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
            # Track the param's scalar type for char-literal promotion (§ binop).
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
    # Mark function-local scope so c_Decl can classify function-local
    # `static` (whose cross-call persistence Jac cannot express) distinctly
    # from a file-scope static (a plain module var).
    self._func_depth += 1;
    # Track pointer-typed returns so c_Return lowers a bare `0` / NULL to Jac
    # `None` rather than the integer literal 0 (expression lowering itself has
    # no pointer context). The return declarator is nd.decl.type.type — a
    # PtrDecl for `T *f(...)`.
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
    # True iff a function body reaches into its variadic args — i.e. declares a
    # `va_list` or calls `va_start`/`va_arg`/`va_end`/`va_copy`. Those are the
    # only forms `*args` cannot model; a body that merely ignores the extra args
    # is lowered faithfully (Tier-A). Walks the pycparser subtree generically via
    # `.children()` (each child yields a (name, node) tuple) and keys off the two
    # real node shapes: a `va_list` IdentifierType and a va-machinery FuncCall.
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
    # Typedef handled by c_Typedef; struct decl handled there too.
    # Here we handle: local/global variable decl with optional init.
    if nd.name is None {
        # Bare struct definition (struct Node { ... };) → route to c_Struct.
        if isinstance(nd.type, c_ast.Struct) and nd.type.name is not None {
            return self.conv(nd.type);
        }
        # Bare enum definition (enum Color { ... };) → route to c_Enum
        # so the direct-IR path can emit uni.Enum or GlobalVars.
        if isinstance(nd.type, c_ast.Enum) {
            return self.conv(nd.type);
        }
        # Anonymous struct or function pointer type decl — surrogate.
        return self._surrogate_stmt(nd);
    }
    inner = nd.type;
    storage = nd.storage or [];
    quals = self._all_quals(nd);
    # --- storage class (#5) ---
    # `extern` names a definition in another TU; with no initializer it is a
    # pure declaration → no-op in Jac (like a function prototype). `extern`
    # WITH an initializer is itself the definition, so fall through and emit.
    # NB: read the initializer via 2-arg `getattr(nd, "init")`, never
    # `nd.init` — Jac maps the bare `.init` attribute to the object's
    # constructor (def init → __init__), so `nd.init` returns a bound method,
    # not pycparser's field. (A 3-arg getattr-with-None is also unsafe: it is
    # rewritten by jac-format into `nd?.init`, which hits the same trap.)
    if "extern" in storage and getattr(nd, "init") is None {
        return [];
    }
    # Function-local `static` keeps its value across calls; a Jac local
    # cannot. Emit a best-effort local (re-initialized each call) and flag
    # the lost persistence. File-scope `static` is just a module var — no
    # loss, so only the function-local variant is demoted.
    if "static" in storage and self._func_depth > 0 {
        self._mark_tier_b(nd, "function-local 'static' loses cross-call persistence");
    }
    # --- qualifiers (#6) ---
    # `const`, `register`, and `restrict` are benign, idiomatic drops → stay
    # Tier-A. `const`/`register` preserve value semantics (the immutability /
    # storage hint is only advisory); `restrict` is an aliasing/optimization
    # contract for the C optimizer, not a runtime operation the lowered code
    # must perform, so dropping it is faithful for defined executions. Only
    # `volatile` carries real semantics Jac cannot express (it must suppress
    # read caching), so emit it faithfully but flag the loss rather than
    # dropping it silently.
    if "volatile" in quals {
        self._mark_tier_b(
            nd, "'volatile' qualifier dropped (Jac cannot suppress read caching)"
        );
    }
    # Function forward declaration (prototype) — no-op in Jac.
    if isinstance(inner, c_ast.FuncDecl) {
        return [];
    }
    # Array decl.
    if isinstance(inner, c_ast.ArrayDecl) {
        return self._decl_array(nd);
    }
    # Struct decl without typedef — emit ClassDef (P1b).
    if isinstance(inner, c_ast.TypeDecl) and isinstance(inner.type, c_ast.Struct) {
        return self._decl_struct_var(nd);
    }
    # Enum variable decl (enum { ... } varname) — emit constants via DIRECT_IR, skip the var.
    if isinstance(inner, c_ast.TypeDecl)
    and isinstance(inner.type, c_ast.Enum)
    and inner.type.values is not None {
        return self._directir_placeholder(inner.type);
    }
    # Record this scalar's type so a later binary op can decide whether a
    # char-literal sibling should promote to its ordinal (e.g. `i < 'z'`).
    self._record_scalar_type(nd.name, inner);
    target = ast3.Name(id=nd.name, ctx=ast3.Store());
    self._stamp(target, nd, text=nd.name);
    nd_init = getattr(nd, "init");
    value = self.conv_expr(nd_init) if nd_init is not None else None;
    # LIST_OF_OBJECTS (§7.2): `T *arr = malloc(n*sizeof(T))` is a list, not a
    # bare T — annotate `list[T]` (not the pointer's `T`) and record the name
    # as list-bound so a later realloc on it elides cleanly (§7.5).
    arr_elem = malloc_array_match(nd_init) if nd_init is not None else None;
    if arr_elem is not None {
        ann = self._list_ann_of(arr_elem);
        self._list_bound.add(nd.name);
    } else {
        ann = self._type_ann(nd);
        # A fresh non-list (re)declaration of this name clears any stale
        # list-bound state from an outer-scope binding of the same name.
        self._list_bound.discard(nd.name);
    }
    # Static storage duration (#2): an uninitialized file-scope var or a
    # function-local `static` is zero-initialized in C. Synthesize that zero
    # so the guarantee survives; automatic locals (no static, in a function)
    # stay annotation-only, matching C's indeterminate value.
    if value is None and (self._func_depth == 0 or "static" in storage) {
        value = self._zero_default(inner);
    }
    aa = ast3.AnnAssign(target=target, annotation=ann, value=value, simple=1);
    return self._stamp(aa, nd, text=nd.name);
}

impl CMapper._all_quals(nd: object) -> set {
    # Collect type qualifiers from a Decl and the whole nested type chain.
    # `const`/`volatile` may sit on the Decl or the pointed-to TypeDecl;
    # `restrict` lives on the PtrDecl, not the Decl — so reading nd.quals
    # alone would miss the common `int * restrict p`. The chain is short
    # (pointer/array/typedecl nesting), so a bounded walk suffices.
    quals: set = set(nd?.quals or []);
    t = nd?.type;
    for _ in range(8) {
        if t is None {
            break;
        }
        quals |= set(t?.quals or []);
        t = t?.type;
    }
    return quals;
}

impl CMapper._decl_struct_var(nd: object) -> object {
    # Variable whose type is a struct — just AnnAssign with struct name.
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
    # Zero-initializer for an uninitialized *static-storage-duration* decl
    # (file-scope, or function-local `static`). C guarantees such objects
    # start at zero — NULL for pointers, 0/0.0/false for scalars — so a bare
    # `n: int` annotation would silently drop that guarantee (vs an automatic
    # local, whose value is genuinely indeterminate and stays annotation-only).
    (line, col) = (self._lineno, 0);
    if isinstance(inner, c_ast.PtrDecl) {
        return self._stamp_manual(ast3.Constant(value=None), line, col, text="None");
    }
    names: list = [];
    if isinstance(inner, c_ast.TypeDecl) {
        names = inner.type?.names or [];
    }
    jac = jac_prim(names);
    if jac == "str" {
        # A zero `char` is the NUL byte; modelled as "" (empty string) rather
        # than embedding a literal NUL into the generated Jac source.
        (val, t) = ("", '""');
    } else {
        (val, t) = jac_prim_zero(jac);
    }
    return self._stamp_manual(ast3.Constant(value=val), line, col, text=t);
}

impl CMapper.c_Assignment(nd: object) -> object {
    lhs = self.conv_expr(nd.lvalue);
    # Convert the rvalue BEFORE updating list-bound state so a `realloc` inside
    # it (via _realloc_elide) sees the pointer's pre-assignment binding.
    rhs = self.conv_expr(nd.rvalue);
    # Track list-boundness across reassignment (§7.5) by last-write-wins.
    # `arr = malloc(n*sizeof(T))` marks `arr` list-bound; `arr = realloc(arr,…)`
    # on an already-bound pointer preserves it (same logical buffer); ANY other
    # plain `arr = …` invalidates it. Without the invalidation the set is
    # monotonic, so `arr = malloc(); arr = raw; realloc(arr, n)` would falsely
    # stamp the trailing realloc Tier-A. (Branch-conditional rebinds still need
    # real dataflow tracking — see §9.5; this keeps straight-line flow sound.)
    if nd.op == "=" and isinstance(nd.lvalue, c_ast.ID) {
        if malloc_array_match(nd.rvalue) is not None
        or realloc_of_list_bound(nd.rvalue, self._list_bound) {
            self._list_bound.add(nd.lvalue.name);
        } else {
            self._list_bound.discard(nd.lvalue.name);
        }
    }
    if nd.op == "=" {
        # Convert lhs context to Store.
        lhs_store = self._to_store(lhs);
        assign = ast3.Assign(targets=[lhs_store], value=rhs, type_comment=None);
        return self._stamp(assign, nd, text="=");
    }
    aug_entry = C_AUGOPS.get(nd.op);
    if aug_entry is not None {
        (ast_cls, _, _) = aug_entry;
        lhs_store = self._to_store(lhs);
        aug = ast3.AugAssign(target=lhs_store, op=getattr(ast3, ast_cls)(), value=rhs);
        return self._stamp(aug, nd, text=nd.op);
    }
    return self._surrogate_stmt(nd);
}

impl CMapper.c_Struct(nd: object) -> object {
    # Bare struct definition (not through Typedef) encountered as top-level decl.
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
    cls = ast3.ClassDef(name=name, bases=[], keywords=[], body=body, decorator_list=[]);
    return self._stamp(cls, nd, text=name);
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
    # typedef struct { ... } TypeName  →  ClassDef named TypeName.
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
    # Scalar typedef → alias assignment.
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
    # nd is c_ast.Decl whose .type is ArrayDecl.
    arr_decl = nd.type;
    # Resolve the element type once: `elem_typename` keeps struct/union/typedef
    # elements as their real name (e.g. `S`) so both the `list[S]` annotation and
    # the `S()` default below name the actual type instead of collapsing to int.
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
            # Immutable scalar defaults can't alias → `[0] * n` is fine.
            mult = ast3.BinOp(
                left=ast3.List(elts=[elem_node], ctx=ast3.Load()),
                op=ast3.Mult(),
                right=dim_expr
            );
            self._stamp_manual(mult, self._lineno, 0);
            value = mult;
        } else {
            # Object elements (struct/union) must be distinct instances, else
            # `a[0]` and `a[1]` would share one object (a[1].x = 2 clobbers
            # a[0].x). Emit `[T() for _ in range(n)]`, mirroring _malloc_array.
            range_fn = self._stamp_manual(
                ast3.Name(id="range", ctx=ast3.Load()), self._lineno, 0, text="range"
            );
            range_call = self._stamp_manual(
                ast3.Call(func=range_fn, args=[dim_expr], keywords=[]), self._lineno, 0
            );
            tgt = self._stamp_manual(
                ast3.Name(id="_", ctx=ast3.Store()), self._lineno, 0, text="_"
            );
            gen = ast3.comprehension(
                target=tgt, iter=range_call, ifs=[], is_async=0
            );
            lc = ast3.ListComp(elt=elem_node, generators=[gen]);
            value = self._stamp_manual(lc, self._lineno, 0, text="[]");
        }
    }
    aa = ast3.AnnAssign(target=target, annotation=list_ann, value=value, simple=1);
    return self._stamp(aa, nd, text=nd.name);
}

impl CMapper.c_ArrayDecl(nd: object) -> object {
    # Top-level handler only called if the parent Decl routes here directly.
    # Most ArrayDecl nodes are handled via c_Decl → _decl_array.
    return self._surrogate_stmt(nd);
}

impl CMapper.c_Enum(nd: object) -> object {
    return self._directir_placeholder(nd);
}

impl CMapper.c_Enumerator(nd: object) -> object {
    # Usually encountered inside Enum, not top-level; emit surrogate.
    return self._surrogate_stmt(nd);
}

impl CMapper.c_EnumeratorList(nd: object) -> object {
    return self._surrogate_stmt(nd);
}

impl CMapper._type_ann(decl: object) -> object {
    # Works on a Decl node.
    name = typename(decl.type);
    n = ast3.Name(id=name, ctx=ast3.Load());
    return self._stamp(n, decl, text=name);
}

impl CMapper._type_ann_from_type(t: object) -> object {
    # Works on a raw type node (TypeDecl, PtrDecl, etc.).
    name = typename(t);
    (line, col) = (self._lineno, 0);
    n = ast3.Name(id=name, ctx=ast3.Load());
    return self._stamp_manual(n, line, col, text=name);
}

impl CMapper._ret_ann(funcdecl: object) -> object {
    name = typename(funcdecl.type);
    n = ast3.Name(id=name, ctx=ast3.Load());
    n.lineno = 1;
    n.col_offset = 0;
    n.end_lineno = 1;
    n.end_col_offset = len(name);
    return n;
}

impl CMapper._list_ann_of(tname: str) -> object {
    # Build a `list[T]` annotation node for a C element type tname.
    jac = C_PRIM_MAP.get(tname, tname);
    elem = self._stamp_manual(
        ast3.Name(id=jac, ctx=ast3.Load()), self._lineno, 0, text=jac
    );
    lst = self._stamp_manual(
        ast3.Name(id="list", ctx=ast3.Load()), self._lineno, 0, text="list"
    );
    sub = ast3.Subscript(value=lst, slice=elem, ctx=ast3.Load());
    return self._stamp_manual(sub, self._lineno, 0, text="list");
}
