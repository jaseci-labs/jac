glob _INFER_PLAIN_NAMES: frozenset[str] = frozenset(
         {
             "int",
             "float",
             "bool",
             "str",
             "bytes",
             "bytearray",
             "None",
             "NoneType",
             "list",
             "dict",
             "set",
             "frozenset",
             "tuple",
             "range",
             "complex",
             "LiteralString"
         }
     ),
     _INFER_STDLIB_ROOTS: tuple[str, ...] = (
         "math",
         "os",
         "sys",
         "time",
         "random",
         "struct"
     ),
     _INFER_NUMERIC_NAMES: frozenset[str] = frozenset(
         {
             "i8",
             "i16",
             "i32",
             "i64",
             "u8",
             "u16",
             "u32",
             "u64",
             "f32",
             "f64",
             "isize",
             "usize",
             "byte"
         }
     ),
     _INFER_SHALLOW_BUILTINS: frozenset[str] = frozenset(
         {
             "len",
             "isinstance",
             "issubclass",
             "id",
             "type",
             "range",
             "enumerate",
             "zip",
             "reversed",
             "callable"
         }
     ),
     _INFER_PLAIN_BUILTINS: frozenset[str] = frozenset(
         {
             "int",
             "float",
             "str",
             "bool",
             "abs",
             "min",
             "max",
             "ord",
             "chr",
             "round",
             "divmod",
             "pow",
             "hex",
             "oct",
             "bin",
             "sum",
             "any",
             "all",
             "print",
             "repr",
             "format",
             "hash",
             "bytes",
             "bytearray",
             "list",
             "tuple",
             "dict",
             "set",
             "sorted"
         }
     );

impl OwnershipCheckPass._stamp_inferred_borrows -> None {
    """Infer the borrows of every function in the module.

    What each function may write is computed first, through the free functions
    it calls (a fixpoint), and only then is any local inferred.
    """;
    opts = self.prog?.options;
    if opts is not None and not opts.na_borrow_infer {
        return;
    }
    abilities = [
        ab
        for ab in self.module.get_all_sub_nodes(Ability)
        if ab.body is not None
    ];
    if not abilities {
        return;
    }
    nodes: dict[int, list[UniNode]] = {};
    for ab in abilities {
        nodes[id(ab)] = self._infer_nodes_of(ab);
    }

    direct: dict[int, set[str]] = {};
    calls: dict[int, list[Ability]] = {};
    for ab in abilities {
        callees: list[Ability] = [];
        direct[id(ab)] = self._infer_region_effects(nodes[id(ab)], callees);
        calls[id(ab)] = callees;
    }
    effects: dict[int, set[str]] = {k: set(v) for (k, v) in direct.items()};
    changed = True;
    while changed {
        changed = False;
        for ab in abilities {
            cur = effects[id(ab)];
            if "*" in cur {
                continue;
            }
            for callee in calls[id(ab)] {
                more = effects.get(id(callee));
                if more is None {
                    more = {"*"};
                }
                if not more.issubset(cur) {
                    cur |= more;
                    changed = True;
                }
            }
        }
    }
    for ab in abilities {
        if ab.is_async or self._infer_is_generator(nodes[id(ab)]) {
            continue;
        }
        self._infer_borrows_in(ab, nodes[id(ab)], effects);
    }
}

impl OwnershipCheckPass._infer_nodes_of(ab: Ability) -> list[UniNode] {
    """The nodes of `ab` that run in `ab` itself.

    That is the declaration's subtree and its impl bodies, as
    `element_sub_nodes` walks them, without the nodes of nested functions.
    """;
    out: list[UniNode] = [];
    seen: set[int] = set();
    pending: list[UniNode] = [ab];
    while pending {
        scope = pending.pop();
        for nd in scope.flatten() {
            if id(nd) in seen {
                continue;
            }
            seen.add(id(nd));
            if nd is not ab
                and not isinstance(nd, ImplDef)
                and nd.enclosing_decl(Ability) is ab {
                out.append(nd);
            }
        }
        pending.extend(scope.linked_impls());
    }
    return out;
}

impl OwnershipCheckPass._infer_is_generator(nds: list[UniNode]) -> bool {
    for nd in nds {
        if isinstance(nd, YieldExpr) {
            return True;
        }
    }
    return False;
}

impl OwnershipCheckPass._infer_plain_type(t: (TypeBase | None)) -> bool {
    if t is None {
        return False;
    }
    mangled = "";
    try {
        mangled = t.mangle();
    } except Exception {
        return False;
    }
    if not mangled {
        return False;
    }
    words = "".join(c if c.isalnum() or c == "_" else " " for c in mangled).split();
    for word in words {
        if word not in _INFER_PLAIN_NAMES and word not in _INFER_NUMERIC_NAMES {
            return False;
        }
    }
    return True;
}

impl OwnershipCheckPass._infer_expr_plain(e: object) -> bool {
    """Whether `e` is a plain value, so that using it runs no user code.

    A comparison or a boolean expression is a bool: its operands are checked
    where they appear.
    """;
    cur = e;
    while isinstance(cur, CfgExpr) {
        cur = cur.expr;
    }
    if isinstance(cur, Null) {
        return True;
    }
    if isinstance(cur, (CompareExpr, BoolExpr)) {
        return True;
    }
    return isinstance(cur, Expr) and self._infer_plain_type(cur.type);
}

impl OwnershipCheckPass._infer_region_effects(
    nds: list[UniNode], callees: list[Ability]
) -> set[str] {
    """What running these nodes may write: field names, "[]" for list elements
    and container contents, "*" for anything unknown. Free functions of this
    module that they call are collected in `callees` for the caller's
    fixpoint.

    A type annotation or another type expression is never evaluated, and
    storing a number or a bool releases nothing. Formatting a user object runs
    its `__str__` or `__format__`, a property read runs its getter, and the
    truthiness of a user object is its `__bool__` or `__len__` (an optional is
    tested for None the same way): all of these count as code the pass cannot
    see.
    """;
    out: set[str] = set();
    for nd in nds {
        if nd.find_parent_of_type(SubTag) is not None or self._infer_is_type_expr(nd) {
            continue;
        }
        if isinstance(
            nd, (WithStmt, AwaitExpr, YieldExpr, ConcurrentExpr, IterForStmt)
        ) {
            out.add("*");
        } elif isinstance(nd, Assignment) {
            if nd.aug_op is not None {
                aug_plain = self._infer_expr_plain(nd.value);
                for aug_tgt in nd.target {
                    if not self._infer_expr_plain(aug_tgt) {
                        aug_plain = False;
                    }
                }
                if not aug_plain {
                    out.add("*");
                }
            }
            for tgt in nd.target {
                if self._infer_scalar_slot(tgt) {
                    continue;
                }
                self._store_fields(tgt, out);
            }
        } elif isinstance(nd, DeleteStmt) {
            for tgt in nd.leaf_targets() {
                self._store_fields(tgt, out);
            }
        } elif isinstance(nd, FuncCall) {
            out |= self._infer_call_effects(nd, callees);
        } elif isinstance(nd, CompareExpr) {
            identity_only = True;
            for op in nd.ops {
                if op.value not in ("is", "is not") {
                    identity_only = False;
                }
            }
            if not identity_only {
                if not self._infer_expr_plain(nd.left) {
                    out.add("*");
                }
                for right in nd.rights {
                    if not self._infer_expr_plain(right) {
                        out.add("*");
                    }
                }
            }
        } elif isinstance(nd, BinaryExpr) {
            if not (
                self._infer_expr_plain(nd.left) and self._infer_expr_plain(nd.right)
            ) {
                out.add("*");
            }
        } elif isinstance(nd, BoolExpr) {
            for v in nd.values {
                if not self._infer_expr_plain(v) {
                    out.add("*");
                }
            }
        } elif isinstance(nd, UnaryExpr) {
            if not self._infer_expr_plain(nd.operand) {
                out.add("*");
            }
        } elif isinstance(nd, FormattedValue) {
            if not self._infer_expr_plain(nd.format_part) {
                out.add("*");
            }
        } elif isinstance(nd, AtomTrailer) {
            if nd.is_attr {
                decl = nd.right?.sym?.decl;
                owner = decl?.name_of;
                parent = nd.parent;
                called = isinstance(parent, FuncCall) and parent.target is nd;
                if isinstance(owner, Ability) and not called {
                    out.add("*");
                }
            } elif not self._infer_indexable(nd.target) {
                out.add("*");
            }
        } elif isinstance(nd, InForStmt) {
            if not self._infer_iterable(nd.collection) {
                out.add("*");
            }
        } elif isinstance(nd, (IfStmt, WhileStmt)) {
            cond: Expr = nd.condition;
            while isinstance(cond, CfgExpr) {
                cond = cond.expr;
            }
            if not self._infer_expr_plain(cond)
                and not isinstance(cond, (CompareExpr, BoolExpr)) {
                out.add("*");
            }
        }
    }
    return out;
}

impl OwnershipCheckPass._infer_indexable(target: object) -> bool {
    """Whether indexing `target` runs no user code (a builtin container).""";
    if not isinstance(target, Expr) {
        return False;
    }
    mangled = "";
    try {
        mangled = target.type.mangle() if target.type is not None else "";
    } except Exception {
        return False;
    }
    head = mangled.split("[")[0];
    return head in ("list", "dict", "tuple", "str", "bytes", "bytearray");
}

impl OwnershipCheckPass._infer_iterable(coll: object) -> bool {
    if isinstance(coll, FuncCall)
        and isinstance(coll.target, Name)
        and coll.target.sym_name in ("range", "enumerate", "zip", "reversed") {
        return True;
    }
    if not isinstance(coll, Expr) or coll.type is None {
        return False;
    }
    mangled = "";
    try {
        mangled = coll.type.mangle();
    } except Exception {
        return False;
    }
    return mangled.split("[")[0]
        in ("list", "dict", "set", "frozenset", "tuple", "str", "bytes", "range");
}

impl OwnershipCheckPass._infer_call_effects(
    call: FuncCall, callees: list[Ability]
) -> set[str] {
    """What a call may write, for the caller's fixpoint.

    A builtin does not resolve to a declaration, so known builtins are
    recognised by name: methods of builtin containers and strings, builtin
    exceptions (their constructor only stores its arguments), and the shallow
    builtins such as `len`, which look at a container itself and not at what
    it holds (only a user object argument can run its own `__len__` and the
    like). Any other library call may compare, hash or format what it is
    given, which runs a user object's dunder methods, so it is trusted with
    plain values only. A method call can do anything, since an override in a
    subclass, here or in another module, can.
    """;
    callee = self._callee_ability(call);
    if callee is None {
        bname = call.target.sym_name if isinstance(call.target, Name) else "";
        bargs: list[Expr] = [];
        for p in (call.params or []) {
            pv = p.value if isinstance(p, KWPair) else p;
            if isinstance(pv, Expr) {
                bargs.append(pv);
            }
        }
        if isinstance(call.target, AtomTrailer)
            and call.target.is_attr
            and isinstance(call.target.right, Name)
            and self._infer_builtin_outer(call.target.target) {
            mname = call.target.right.sym_name;
            if mname in _MUTATING_CONTAINER_METHODS {
                return self._infer_mutator_effects(mname, call, bargs);
            }
            if all(self._infer_expr_plain(a) for a in bargs) {
                return set();
            }
            return {"*"};
        }
        if (bname.endswith("Error") or bname.endswith("Exception"))
            and all(self._infer_expr_plain(a) for a in bargs) {
            return set();
        }
        if bname in _INFER_SHALLOW_BUILTINS {
            if all(
                self._infer_expr_plain(a) or self._infer_builtin_outer(a) for a in bargs
            ) {
                return set();
            }
        } elif bname in _INFER_PLAIN_BUILTINS {
            if all(self._infer_expr_plain(a) for a in bargs) {
                return set();
            }
        }
        return {"*"};
    }
    args: list[Expr] = [];
    for p in (call.params or []) {
        if isinstance(p, KWPair) {
            if isinstance(p.value, Expr) {
                args.append(p.value);
            }
        } elif isinstance(p, Expr) {
            args.append(p);
        }
    }
    if self._is_builtin_mutator(callee) {
        mname = callee.name_ref.sym_name if callee.name_ref is not None else "";
        return self._infer_mutator_effects(mname, call, args);
    }
    path = str(callee.loc.mod_path);
    arch = callee.find_parent_of_type(Archetype);
    if path.endswith(".pyi") {
        name = callee.name_ref.sym_name if callee.name_ref is not None else "";
        if name in ("setattr", "delattr") {
            return {"*"};
        }
        for a in args {
            if isinstance(a.type, FunctionType) or isinstance(a, LambdaExpr) {
                return {"*"};
            }
        }
        if arch is None and name in _INFER_SHALLOW_BUILTINS {
            return set()
                if all(
                    self._infer_expr_plain(a) or self._infer_builtin_outer(a)
                    for a in args
                )
                else set(["*"]);
        }

        return set() if all(self._infer_expr_plain(a) for a in args) else set(["*"]);
    }
    if arch is not None {
        return {"*"};
    }
    if callee.loc.mod_path != self.module.loc.mod_path {
        base_nm = "";
        tgt = call.target;
        while isinstance(tgt, AtomTrailer) {
            tgt = tgt.target;
        }
        if isinstance(tgt, Name) {
            base_nm = tgt.sym_name;
        }
        if (base_nm in _INFER_STDLIB_ROOTS or "na_stdlib" in path)
            and all(self._infer_expr_plain(a) for a in args) {
            return set();
        }
        return {"*"};
    }
    callees.append(callee);
    return set();
}

impl OwnershipCheckPass._infer_path(expr: object) -> (tuple[Name, set[str]] | None) {
    """The root name and the fields along `expr` when it is a place: a name,
    or `.field` and `list[index]` steps from one. None for anything else.""";
    fields: set[str] = set();
    cur = expr;
    while isinstance(cur, AtomTrailer) {
        if cur.is_null_ok {
            return None;
        }
        if cur.is_attr {
            if not isinstance(cur.right, Name) {
                return None;
            }
            fields.add(cur.right.sym_name);
        } else {
            if not isinstance(cur.right, IndexSlice) or cur.right.is_range {
                return None;
            }
            _tt = "";
            try {
                _tt = cur.target.type.mangle() if cur.target.type is not None else "";
            } except Exception {
                return None;
            }
            if not _tt.startswith("list[") {
                return None;
            }
            fields.add("[]");
        }
        cur = cur.target;
    }
    if not isinstance(cur, Name) or cur.sym is None {
        return None;
    }
    return (cur, fields);
}

impl OwnershipCheckPass._infer_borrows_in(
    ab: Ability, nds: list[UniNode], effects: dict[int, set[str]]
) -> int {
    """Stamp the binds of the locals of `ab` that can be borrows; the count.

    It first collects every way a local is bound in `ab`, the locals copied
    whole into another local (the copy at a local's last use takes its
    reference through move lowering, so such a local may stop holding its
    object before the function ends and is never a stable root), and the names
    nested functions and lambdas capture. Candidates are the locals whose
    every bind is None or a place. A candidate holds while its roots hold: the
    fixpoint drops the ones whose root is neither a parameter, `self`, a
    stable owner nor a surviving candidate, and the ones whose path, with its
    roots' paths, the function may write.
    """;
    fn_writes = effects.get(id(ab), {"*"});

    simple: dict[SymId, list[Assignment]] = {};
    other_binds: dict[SymId, int] = {};
    names: dict[SymId, Name] = {};

    copied: set[SymId] = set();
    for nd in nds {
        if isinstance(nd, Assignment) {
            if isinstance(nd.value, Name) and nd.value.sym is not None {
                copied.add(self._name_sym_id(nd.value));
            }
            single = len(nd.target) == 1 and nd.aug_op is None;
            for tgt in nd.target {
                for nm in self._infer_bound_names(tgt) {
                    sid = self._name_sym_id(nm);
                    names[sid] = nm;
                    if single and tgt is nm {
                        simple.setdefault(sid, []).append(nd);
                    } else {
                        other_binds[sid] = other_binds.get(sid, 0) + 1;
                    }
                }
            }
        } elif isinstance(nd, DeleteStmt) {
            for tgt in nd.leaf_targets() {
                if isinstance(tgt, Name) and tgt.sym is not None {
                    sid = self._name_sym_id(tgt);
                    other_binds[sid] = other_binds.get(sid, 0) + 1;
                }
            }
        } elif isinstance(nd, InForStmt) {
            for nm in self._infer_bound_names(nd.target) {
                sid = self._name_sym_id(nm);
                names[sid] = nm;
                other_binds[sid] = other_binds.get(sid, 0) + 1;
            }
        } else {
            bound: object = None;
            if isinstance(nd, Except) {
                bound = nd.name;
            } elif isinstance(nd, (MatchAs, MatchStar)) {
                bound = nd.name;
            } elif isinstance(nd, ExprAsItem) {
                bound = nd.alias;
            }
            for nm in self._infer_bound_names(bound) {
                other_binds[self._name_sym_id(nm)] = 99;
            }
        }
    }

    captured: set[SymId] = set();
    for lam in ab.element_sub_nodes(LambdaExpr) {
        for nm in lam.get_all_sub_nodes(Name) {
            lam_sid = self._sym_id(nm);
            if lam_sid is not None {
                captured.add(lam_sid);
            }
        }
    }
    for inner in ab.element_sub_nodes(Ability) {
        if inner is ab {
            continue;
        }
        for nm in inner.element_sub_nodes(Name) {
            inner_sid = self._sym_id(nm);
            if inner_sid is not None {
                captured.add(inner_sid);
            }
        }
    }

    cand: dict[SymId, tuple[list[Assignment], list[tuple[Name, set[str]]]]] = {};
    for (sid, binds) in simple.items() {
        nm = names[sid];
        if not self._infer_is_local(nm) or other_binds.get(sid, 0) or sid in captured {
            continue;
        }
        paths: list[tuple[Name, set[str]]] = [];
        ok = True;
        for nd in binds {
            if isinstance(nd.value, Null) {
                continue;
            }
            p = self._infer_path(nd.value);
            if p is None {
                ok = False;
                break;
            }
            paths.append(p);
        }
        if ok and paths {
            cand[sid] = (binds, paths);
        }
    }

    fields_of: dict[SymId, set[str]] = {};
    for (sid, cand_entry) in cand.items() {
        f: set[str] = set();
        for (_root, pf) in cand_entry[1] {
            f |= pf;
        }
        fields_of[sid] = f;
    }
    alive = set(cand.keys());
    changed = True;
    while changed {
        changed = False;
        for sid in list(alive) {
            (binds, paths) = cand[sid];
            drop = "*" in fn_writes;
            for (base_nm, _pf) in paths {
                rsid = self._name_sym_id(base_nm);
                if base_nm.sym_name == "self" {
                    continue;
                }
                base_sym = base_nm.sym;
                if base_sym is None {
                    drop = True;
                    continue;
                }
                if base_sym.storage == SymbolStorage.PARAM {
                    if other_binds.get(rsid, 0) or simple.get(rsid) {
                        drop = True;
                    }
                    continue;
                }
                if rsid == sid {
                    continue;
                }
                if rsid in alive {
                    if not fields_of[rsid].issubset(fields_of[sid]) {
                        fields_of[sid] |= fields_of[rsid];
                        changed = True;
                    }
                    continue;
                }
                if not (
                    self._infer_is_local(base_nm)
                    and self._infer_owner_stable(ab, rsid, other_binds, simple)
                    and rsid not in copied
                    and rsid not in captured
                ) {
                    drop = True;
                }
            }
            if not drop and fields_of[sid] & fn_writes {
                drop = True;
            }
            if drop {
                alive.discard(sid);
                changed = True;
            }
        }
    }
    count = 0;
    for sid in alive {
        for nd in cand[sid][0] {
            self.module.managed_borrow_binds.add(id(nd));
            count += 1;
        }
    }
    count += self._infer_loop_borrows(ab, nds, other_binds, simple, captured, effects);
    return count;
}

impl OwnershipCheckPass._infer_bound_names(tgt: object) -> list[Name] {
    if isinstance(tgt, Name) {
        return [tgt] if tgt.sym is not None else [];
    }
    out: list[Name] = [];
    if isinstance(tgt, TupleVal) {
        for tv in tgt.values {
            out.extend(self._infer_bound_names(tv));
        }
    } elif isinstance(tgt, ListVal) {
        for lv in tgt.values {
            out.extend(self._infer_bound_names(lv));
        }
    }
    return out;
}

impl OwnershipCheckPass._infer_loop_borrows(
    ab: Ability,
    nds: list[UniNode],
    other_binds: dict[SymId, int],
    simple: dict[SymId, list[Assignment]],
    captured: set[SymId],
    effects: dict[int, set[str]]
) -> int {
    """`for x in <list>`: x borrows each element while the body runs, if the
    body cannot change the list and x is not used outside the loop.

    Every use of x must be inside the body, and the collection's root must not
    be rebound elsewhere in the function, unless it is a local bound once
    outside this loop.
    """;
    count = 0;
    for st in nds {
        if not isinstance(st, InForStmt) or not isinstance(st.target, Name) {
            continue;
        }
        tgt = st.target;
        if tgt.sym is None or tgt.sym.storage != SymbolStorage.LOCAL {
            continue;
        }
        sid = self._name_sym_id(tgt);
        if other_binds.get(sid, 0) != 1 or simple.get(sid) or sid in captured {
            continue;
        }
        coll_type = "";
        try {
            coll_type = st.collection.type.mangle()
                if st.collection.type is not None
                else "";
        } except Exception {
            continue;
        }
        if not coll_type.startswith("list[") {
            continue;
        }

        inside = True;
        for nm in self.name_uses_by_sym.get(sid, []) {
            if nm is tgt {
                continue;
            }
            cur = nm.parent;
            hit = False;
            while cur is not None {
                if cur is st {
                    hit = True;
                    break;
                }
                cur = cur.parent;
            }
            if not hit or self._infer_in_else(nm, st) {
                inside = False;
                break;
            }
        }
        if not inside {
            continue;
        }
        body_nodes: list[UniNode] = [];
        for stmt in (st.body or []) {
            body_nodes.extend(stmt.flatten());
        }
        callees: list[Ability] = [];
        writes = self._infer_region_effects(body_nodes, callees);
        for callee in callees {
            writes |= effects.get(id(callee), {"*"});
        }
        path = self._infer_path(st.collection);
        coll_fields: set[str] = path[1] if path is not None else set();
        if "*" in writes or "[]" in writes or coll_fields & writes {
            continue;
        }
        if path is not None {
            base_nm = path[0];
            rsid = self._name_sym_id(base_nm);
            if base_nm.sym_name != "self"
                and (other_binds.get(rsid, 0) or simple.get(rsid)) {
                if not (
                    self._infer_is_local(base_nm)
                    and len(simple.get(rsid, [])) == 1
                    and not other_binds.get(rsid, 0)
                ) {
                    continue;
                }
                if self._infer_contains(st, simple[rsid][0]) {
                    continue;
                }
            }
        }
        self.module.managed_borrow_binds.add(id(st));
        count += 1;
    }
    return count;
}

impl OwnershipCheckPass._infer_in_else(nm: UniNode, st: InForStmt) -> bool {
    els = st.else_body;
    if els is None {
        return False;
    }
    cur = nm.parent;
    while cur is not None and cur is not st {
        if cur is els {
            return True;
        }
        cur = cur.parent;
    }
    return False;
}

impl OwnershipCheckPass._infer_contains(outer: UniNode, inner: UniNode) -> bool {
    cur = inner.parent;
    while cur is not None {
        if cur is outer {
            return True;
        }
        cur = cur.parent;
    }
    return False;
}

impl OwnershipCheckPass._infer_is_local(nm: Name) -> bool {
    return nm.sym is not None and nm.sym.storage == SymbolStorage.LOCAL;
}

impl OwnershipCheckPass._infer_owner_stable(
    ab: Ability,
    sid: SymId,
    other_binds: dict[SymId, int],
    simple: dict[SymId, list[Assignment]]
) -> bool {
    """A local base_nm that owns what it names: bound once, outside any loop.""";
    if other_binds.get(sid, 0) {
        return False;
    }
    binds = simple.get(sid, []);
    if len(binds) != 1 {
        return False;
    }
    cur = binds[0].parent;
    while cur is not None and cur is not ab {
        if isinstance(cur, (WhileStmt, InForStmt, IterForStmt)) {
            return False;
        }
        cur = cur.parent;
    }
    return True;
}

impl OwnershipCheckPass._infer_builtin_outer(e: object) -> bool {
    """Whether `e` is a builtin container (its elements may be anything).""";
    if not isinstance(e, Expr) or e.type is None {
        return False;
    }
    mangled = "";
    try {
        mangled = e.type.mangle();
    } except Exception {
        return False;
    }
    return mangled.split("[")[0]
        in ("list", "dict", "set", "frozenset", "tuple", "str", "bytes", "bytearray");
}

impl OwnershipCheckPass._infer_scalar_slot(tgt: object) -> bool {
    """Whether `tgt` is a field or element whose value is a number or a bool.""";
    if not isinstance(tgt, AtomTrailer) or tgt.type is None {
        return False;
    }
    mangled = "";
    try {
        mangled = tgt.type.mangle();
    } except Exception {
        return False;
    }
    return mangled in ("int", "float", "bool", "complex")
        or mangled in _INFER_NUMERIC_NAMES;
}

impl OwnershipCheckPass._infer_is_type_expr(nd: object) -> bool {
    """Whether `nd` denotes a type (`list[list[float]]` in a return annotation).""";
    if not isinstance(nd, Expr) or nd.type is None {
        return False;
    }
    tex = "";
    try {
        tex = nd.type.mangle();
    } except Exception {
        return False;
    }
    return tex.startswith("type[");
}

impl OwnershipCheckPass._infer_mutator_effects(
    mname: str, call: FuncCall, args: list[Expr]
) -> set[str] {
    """A container method's effect on borrows of its elements. Only removing
    or overwriting an element releases it; adding or reordering releases
    nothing (a borrow names the element, not its slot), unless the method
    runs user code: hashing or ordering user objects, iterating a user
    iterable.""";
    recv = call.target.target if isinstance(call.target, AtomTrailer) else None;
    if mname in ("clear", "popitem") or (mname == "pop" and not args) {
        return {"[]"};
    }
    if mname in ("pop", "remove", "discard", "update") {
        if recv is not None
            and self._infer_expr_plain(recv)
            and all(self._infer_expr_plain(a) for a in args) {
            return {"[]"};
        }
        return {"*"};
    }
    if mname in ("append", "insert", "reverse") {
        return set();
    }
    if mname == "extend" {
        return set()
            if all(
                self._infer_builtin_outer(a) or self._infer_expr_plain(a) for a in args
            )
            else set(["*"]);
    }
    if mname in ("add", "setdefault") {
        return set() if all(self._infer_expr_plain(a) for a in args) else set(["*"]);
    }
    if mname == "sort" {
        return set()
            if (recv is not None and self._infer_expr_plain(recv) and not args)
            else set(["*"]);
    }
    return {"[]"};
}
