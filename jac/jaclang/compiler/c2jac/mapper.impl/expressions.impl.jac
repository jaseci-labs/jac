"""Value-producing expression handlers (binary / unary ops, identifiers,
constants, struct & array refs, initializer lists, casts) and the
malloc/realloc pointer-idiom recognizers behind c_FuncCall (§7)."""

impl CMapper.c_BinaryOp(nd: object) -> object {
    entry = C_BINOPS.get(nd.op);
    if entry is None {
        return self._surrogate_expr(nd);
    }
    (kind, ast_cls) = entry;
    left = self._binop_operand(nd.left, nd.right);
    right = self._binop_operand(nd.right, nd.left);
    op_obj = getattr(ast3, ast_cls)();
    if kind == "arith" {
        expr_node = ast3.BinOp(left=left, op=op_obj, right=right);
    } elif kind == "compare" {
        expr_node = ast3.Compare(left=left, ops=[op_obj], comparators=[right]);
    } else {
        # bool — && / ||
        expr_node = ast3.BoolOp(op=op_obj, values=[left, right]);
    }
    return self._stamp(expr_node, nd, text=nd.op);
}

impl CMapper._binop_operand(operand: object, sibling: object) -> object {
    # A C character constant is an integer. Under c2jac's char→str model it
    # normally renders as the one-char string `'a'` so a char-to-char comparison
    # (`c == 'a'`, where the char variable `c` is itself a str) stays faithful.
    # But when the char literal is combined with a NUMERIC operand — `i < 'z'`,
    # `total + 'a'`, where the sibling resolves to int/float — the str form is a
    # type-mismatched comparison/arithmetic in Jac (int vs str). Emit the char's
    # integer ordinal instead (`i < 122`), matching C's value semantics. The
    # sibling type is resolved from the running scalar-var map; when it is
    # unknown (or itself char/str) the readable str form is kept.
    if isinstance(operand, c_ast.Constant)
    and classify_c_constant(operand.type) == CLIT_CHAR
    and self._expr_prim(sibling) in ("int", "float", "bool") {
        ov = c_char_ord(operand.value);
        if ov is not None {
            (line, col) = self._loc(operand);
            return self._stamp_manual(ast3.Constant(value=ov), line, col, text=str(ov));
        }
    }
    return self.conv_expr(operand);
}

impl CMapper._expr_prim(c_node: object) -> str | None {
    # Best-effort Jac-primitive of an expression operand, for char-literal
    # promotion. Resolves literals by family and identifiers via the scalar-var
    # map; anything else (calls, refs, nested exprs) is unknown → None.
    if isinstance(c_node, c_ast.Constant) {
        fam = classify_c_constant(c_node.type);
        if fam == CLIT_INT {
            return "int";
        }
        if fam == CLIT_FLOAT {
            return "float";
        }
        # char / string literals are text under the char→str model.
        return "str";
    }
    if isinstance(c_node, c_ast.ID) {
        return self._var_types.get(c_node.name);
    }
    return None;
}

impl CMapper._scalar_prim(type_node: object) -> str | None {
    # The Jac primitive of a plain scalar declarator (TypeDecl → IdentifierType),
    # or None for pointers/arrays/structs/functions — which are not scalars we
    # track for char-literal promotion.
    if isinstance(type_node, c_ast.TypeDecl)
    and isinstance(type_node.type, c_ast.IdentifierType) {
        return jac_prim(type_node.type.names);
    }
    return None;
}

impl CMapper._record_scalar_type(name: str, type_node: object) {
    # Remember a scalar variable's Jac primitive so a later binary op can decide
    # whether a char-literal sibling should promote to its ordinal. A non-scalar
    # (re)declaration of the same name clears any stale entry.
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
    # p++, p--, *p, &p, sizeof — contextual; treat as surrogate or elide.
    if nd.op in ("p++", "++", "p--", "--") {
        # Increment/decrement: emit as augassign in statement context,
        # but here we're in expr context — emit as surrogate.
        return self._surrogate_expr(nd);
    }
    if nd.op == "*" {
        # PTR_REF (§7.4): dereferencing a plain pointer-as-reference is
        # identity in Jac — `*p`/`(*p).f` → `p`/`p.f`. Only when the operand
        # is a simple lvalue (no pointer arithmetic); `*(p+1)` stays Tier-B.
        if is_simple_ref(nd.expr) {
            self._mark_tier_a(nd, Idiom.PTR_REF, "pointer dereference → Jac reference");
            return self.conv_expr(nd.expr);
        }
        return self._surrogate_expr(nd);
    }
    if nd.op == "&" {
        # PTR_REF (§7.4): address-of a simple lvalue → pass the object by
        # reference, i.e. identity. `&(p+1)`/computed addresses stay Tier-B.
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

impl CMapper.c_ID(nd: object) -> object {
    n = ast3.Name(id=nd.name, ctx=ast3.Load());
    return self._stamp(n, nd, text=nd.name);
}

impl CMapper.c_Constant(nd: object) -> object {
    # Default the rendered text to the raw C literal; numeric branches
    # override it with the parsed value so a stripped suffix (`10L`→`10`)
    # doesn't leak verbatim into the emitted Jac.
    txt: str = str(nd.value);
    # classify_c_constant matches pycparser's widened C type (`10L` is
    # "long int", `5U` is "unsigned int", `1.0L` is "long double") on the
    # family suffix so every integer / floating constant is normalized —
    # shared source of truth with uni_builder._expr_to_uni.
    family = classify_c_constant(nd.type);
    if family == CLIT_INT {
        iv = parse_c_int(nd.value);
        if iv is not None {
            val: object = iv;
            txt = str(iv);
        } else {
            # Unparseable even after suffix-stripping: a string placeholder
            # is the wrong type, so flag it rather than pass it off as exact.
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
        # char literal: 'a' → single char string.
        val = c_char_text(nd.value);
    } elif family == CLIT_STRING {
        inner = c_string_inner(nd.value);
        if inner is not None {
            if inner.isascii() {
                # unicode_escape resolves the common ASCII escapes (\n, \t, …)
                # for the AST value; the emitted Jac is re-sliced verbatim from
                # the C source, so escape/quote style is preserved either way.
                try {
                    val = bytes(inner, "utf-8").decode("unicode_escape");
                } except Exception {
                    val = inner;
                }
            } else {
                # Non-ASCII: unicode_escape would re-decode UTF-8 multibyte
                # sequences (e.g. `\xc3\xa9` → `é`) as Latin-1 pairs and corrupt
                # the text, so keep the real characters for the AST value. The
                # emitted Jac still comes from the verbatim source slice below.
                val = inner;
            }
        } else {
            # Not a bare double-quoted literal (prefixed L"…"/u8"… or
            # malformed): keep the raw spelling as the AST value.
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
        # PyastBuildPass re-slices a string Constant verbatim from orig_src
        # (the C source) using BYTE offsets, but _stamp derives end_col from the
        # character count. For a multibyte (non-ASCII) literal the two diverge
        # and the closing quote is sliced off; pin the byte length so the quote
        # survives and the literal round-trips faithfully.
        (sline, scol) = self._loc(nd);
        stamped.end_col_offset = scol + len(str(nd.value).encode("utf-8"));
    }
    return stamped;
}

impl CMapper.c_StructRef(nd: object) -> object {
    # s.field or s->field.
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
    # {.field = val} designated initializer → emit value, but the field name
    # (which determines WHICH struct member receives it) is dropped. That's
    # lossy whenever initializers aren't in declaration order, so flag it.
    field = ".".join([self._desig_name(d) for d in (nd.name or [])]);
    self._mark_tier_b(
        nd,
        f"designated initializer `.{field}=` — target field name dropped; "
        f"value emitted positionally, verify it lands on the intended member",
    );
    return self.conv_expr(nd.expr);
}

impl CMapper._desig_name(d: object) -> str {
    # A designator is an ID (field) or a Constant (array index).
    return d.name if isinstance(d, c_ast.ID) else str(getattr(d, "value", "?"));
}

impl CMapper.c_ExprList(nd: object) -> object {
    # Comma-expression: emit last element (common C idiom, conservative).
    # The C comma evaluates every operand left-to-right but yields only the
    # last, so we drop the leading operands. That's faithful when they're
    # side-effect-free (pure constants / IDs / reads): their evaluation has no
    # observable effect, so dropping them changes nothing and the result stays
    # Tier-A. Only when a leading operand has a side effect (call, assignment,
    # ++/--) does dropping it lose semantics — flag those Tier-B.
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
    # C cast — emit inner expression (lossy but better than surrogate for
    # simple cases). A cast to a scalar/numeric type is representation-
    # changing ((int)f truncates, (char)x narrows, (void)e discards); we drop
    # it, so flag those (§5.3 Tier-B). Pointer/struct casts don't change the
    # emitted value, so they stay at the optimistic Tier-A default.
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
    # FREE_ELIDE: free(p) → Pass (GC handles it; §7.3)
    if isinstance(nd.name, c_ast.ID) and nd.name.name == "free" {
        self._mark_tier_a(nd, Idiom.FREE_ELIDE, "free() elided — Jac GC reclaims");
        return self._stamp_manual(ast3.Pass(), self._lineno, 0);
    }
    # REALLOC_ELIDE: realloc(p, n) → p (§7.5). A Jac list grows under GC, so
    # the resize is a no-op that yields the same binding.
    if isinstance(nd.name, c_ast.ID) and nd.name.name == "realloc" {
        re = self._realloc_elide(nd);
        if re is not None {
            return re;
        }
    }
    # LIST_OF_OBJECTS: malloc(n*sizeof(T)) → [T() for _ in range(n)] (§7.2)
    arr = self._malloc_array(nd);
    if arr is not None {
        self._mark_tier_a(nd, Idiom.LIST_OF_OBJECTS, "malloc(n*sizeof(T)) → list[T]");
        return arr;
    }
    # OBJECT_CREATE: malloc(sizeof(T)) → T() constructor (§7.1)
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
    # realloc(p, n) → p. Tier-A when p is provably list-bound in this function
    # (the list grows under GC, so the resize is moot, §7.5/§9.5); otherwise
    # still elided to p but flagged Tier-B — a raw-buffer resize would be lost.
    if nd.args is None or len(nd.args.exprs) < 1 {
        return None;
    }
    ptr = nd.args.exprs[0];
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
    # Default-element Jac node for a list-of-objects of C type tname.
    if tname in C_PRIM_MAP {
        jac = C_PRIM_MAP.get(tname, "int");
        (val, _text) = jac_prim_zero(jac);
        return self._stamp_manual(ast3.Constant(value=val), self._lineno, 0);
    }
    fn = ast3.Name(id=tname, ctx=ast3.Load());
    self._stamp_manual(fn, self._lineno, 0, text=tname);
    call = ast3.Call(func=fn, args=[], keywords=[]);
    return self._stamp_manual(call, self._lineno, 0);
}

impl CMapper._product_expr(factors: list) -> object {
    # Fold converted factors into a left-leaning `*` BinOp (the element count).
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
    # `malloc(n*sizeof(T))` → `[T() for _ in range(n)]` (§7.2). Distinct
    # elements (comprehension, not `[x]*n`) so mutable objects don't alias.
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
