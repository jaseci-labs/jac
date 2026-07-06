impl OwnershipFacts.category_of(nd: object) -> Ownership {
    return self.value_category.get(nd.loc.pos_start, Ownership.BORROWED);
}

impl OwnershipFacts.is_owned(nd: object) -> bool {
    return self.category_of(nd) == Ownership.OWNED;
}

impl OwnershipFacts.is_last_use(nd: object) -> bool {
    return nd.loc.pos_start in self.last_uses;
}

impl OwnershipFacts.is_consumed(key: str, idx: int) -> bool {
    s = self.consumed_params.get(key, None);
    return s is not None and idx in s;
}

impl OwnershipFactsPass.transform(ir_in: uni.Module) -> uni.Module {
    self.facts = OwnershipFacts();
    try {
        self.analyze(ir_in);
        ir_in.gen.ownership_facts = self.facts;
    } except Exception {
        ir_in.gen.ownership_facts = OwnershipFacts();
    }
    return ir_in;
}

impl OwnershipFactsPass.analyze(mod: uni.Module) {
    for stmt in mod.body {
        if isinstance(stmt, uni.Archetype) and arch_is_ref(stmt) {
            self.ref_types[stmt.name.value] = True;
        }
    }
    for stmt in mod.body {
        if isinstance(stmt, uni.Archetype) {
            self.index_arch(stmt);
        } elif isinstance(stmt, uni.Ability) and stmt.name_ref is not None {
            sig = stmt.signature;
            self.func_returns[stmt.name_ref.value] = self.ret_name(
                sig.return_type if sig else None
            );
        }
    }
    for stmt in mod.body {
        if isinstance(stmt, uni.Ability) {
            self.analyze_ability(stmt, "");
        } elif isinstance(stmt, uni.Archetype) {
            for member in (stmt.body or []) {
                if isinstance(member, uni.Ability) {
                    self.analyze_ability(member, stmt.name.value);
                }
            }
        }
    }
}

impl OwnershipFactsPass.index_arch(arch: uni.Archetype) {
    name = arch.name.value;
    (fmap, rmap) = arch_type_maps(arch);
    self.field_types[name] = fmap;
    self.method_returns[name] = rmap;
}

impl OwnershipFactsPass.tag_name(type_tag: object) -> str {
    return type_tag_name(type_tag);
}

impl OwnershipFactsPass.ret_name(ret: object) -> str {
    return sig_ret_name(ret);
}

impl OwnershipFactsPass.analyze_ability(ab: uni.Ability, cls: str) {
    self.local_types = {};
    if cls {
        self.local_types["self"] = cls;
    }
    sig = ab.signature;
    if sig and sig.params {
        for p in sig.params {
            self.local_types[p.name.value] = self.tag_name(p.type_tag);
        }
    }
    body = list(ab.body or []);
    for st in body {
        self.categorize_stmt(st);
    }
    self.compute_consumed(ab, cls, body);
    if self.is_straight_line(body) {
        self.mark_last_uses(body);
    }
}

impl OwnershipFactsPass.compute_consumed(ab: uni.Ability, cls: str, body: list) {
    sig = ab.signature;
    if not (sig and sig.params) {
        return;
    }
    if not self.is_straight_line(body) {
        return;
    }
    key = self.callee_key(ab, cls);
    idx = 0;
    for p in sig.params {
        pname = p.name.value;
        if self.tag_name(p.type_tag) in self.ref_types {
            store = self.sole_field_store(body, pname);
            if store is not None and self.count_name(body, pname) == 1 {
                s = self.facts.consumed_params.get(key, None);
                if s is None {
                    s = set();
                    self.facts.consumed_params[key] = s;
                }
                s.add(idx);
                self.facts.value_category[store.loc.pos_start] = Ownership.OWNED;
            }
        }
        idx += 1;
    }
}

impl OwnershipFactsPass.callee_key(ab: uni.Ability, cls: str) -> str {
    nm = ab.name_ref.value if ab.name_ref is not None else "";
    if nm == "init" and cls {
        return cls;
    }
    if cls {
        return cls + "." + nm;
    }
    return nm;
}

impl OwnershipFactsPass.sole_field_store(body: list, pname: str) -> object {
    found = None;
    count = 0;
    for st in body {
        if isinstance(st, uni.Assignment) and st.value is not None {
            tgt = st.target[0];
            if isinstance(tgt, uni.AtomTrailer) and tgt.is_attr {
                v = st.value;
                if isinstance(v, uni.AtomUnit) {
                    v = v.value;
                }
                if isinstance(v, uni.Name) and v.value == pname {
                    count += 1;
                    found = st.value;
                }
            }
        }
    }
    if count == 1 {
        return found;
    }
    return None;
}

impl OwnershipFactsPass.count_name(body: list, pname: str) -> int {
    c = 0;
    for st in body {
        if isinstance(st, uni.Assignment) and st.value is not None {
            c += self.count_in_expr(st.value, pname);
        } elif isinstance(st, uni.ExprStmt) {
            c += self.count_in_expr(st.expr, pname);
        } elif isinstance(st, uni.ReturnStmt) and st.expr is not None {
            c += self.count_in_expr(st.expr, pname);
        }
    }
    return c;
}

impl OwnershipFactsPass.count_in_expr(e: object, pname: str) -> int {
    if isinstance(e, uni.AtomUnit) {
        return self.count_in_expr(e.value, pname);
    }
    if isinstance(e, uni.Name) {
        return 1 if e.value == pname else 0;
    }
    if isinstance(e, uni.FuncCall) {
        c = self.count_in_expr(e.target, pname);
        for p in (e.params or []) {
            if isinstance(p, uni.Expr) {
                c += self.count_in_expr(p, pname);
            }
        }
        return c;
    }
    if isinstance(e, uni.BinaryExpr) {
        return self.count_in_expr(e.left, pname) + self.count_in_expr(e.right, pname);
    }
    if isinstance(e, uni.CompareExpr) {
        c = self.count_in_expr(e.left, pname);
        for r in e.rights {
            c += self.count_in_expr(r, pname);
        }
        return c;
    }
    if isinstance(e, uni.AtomTrailer) {
        c = self.count_in_expr(e.target, pname);
        if not e.is_attr {
            c += self.count_in_expr(e.right, pname);
        }
        return c;
    }
    if isinstance(e, uni.UnaryExpr) {
        return self.count_in_expr(e.operand, pname);
    }
    return 0;
}

impl OwnershipFactsPass.is_straight_line(body: list) -> bool {
    for st in body {
        if not isinstance(st, (uni.Assignment, uni.ExprStmt, uni.ReturnStmt)) {
            return False;
        }
    }
    return True;
}

impl OwnershipFactsPass.categorize_stmt(st: object) {
    if isinstance(st, uni.Assignment) {
        if st.value is not None {
            self.categorize(st.value);
            self.note_local_type(st);
        }
    } elif isinstance(st, uni.ExprStmt) {
        self.categorize(st.expr);
    } elif isinstance(st, uni.ReturnStmt) {
        if st.expr is not None {
            self.categorize(st.expr);
        }
    }
}

impl OwnershipFactsPass.note_local_type(a: uni.Assignment) {
    tgt = a.target[0];
    if not isinstance(tgt, uni.Name) {
        return;
    }
    if a.type_tag is not None {
        self.local_types[tgt.value] = self.tag_name(a.type_tag);
    } else {
        self.local_types[tgt.value] = self.type_of(a.value);
    }
}

impl OwnershipFactsPass.categorize(e: object) {
    if not isinstance(e, uni.Expr) {
        return;
    }

    if isinstance(e, uni.AtomUnit) {
        self.categorize(e.value);

        self.facts.value_category[e.loc.pos_start] = self.facts.category_of(e.value);
        return;
    }
    if isinstance(e, uni.FuncCall) {
        for p in (e.params or []) {
            if isinstance(p, uni.Expr) {
                self.categorize(p);
            }
        }
    } elif isinstance(e, uni.BinaryExpr) {
        self.categorize(e.left);
        self.categorize(e.right);
    } elif isinstance(e, uni.AtomTrailer) {
        self.categorize(e.target);
    }
    self.facts.value_category[e.loc.pos_start] = self.ownership_of(e);
}

impl OwnershipFactsPass.ownership_of(e: uni.Expr) -> Ownership {
    base = result_ownership(e);

    if base == Ownership.UNKNOWN and self.is_str_concat(e) {
        return Ownership.OWNED;
    }
    return base;
}

impl OwnershipFactsPass.is_str_concat(e: uni.Expr) -> bool {
    return isinstance(e, uni.BinaryExpr)
    and e.op.value == "+"
    and (self.type_of(e.left) == "str" or self.type_of(e.right) == "str");
}

impl OwnershipFactsPass.type_of(e: object) -> str {
    return infer_type(
        e,
        self.local_types,
        self.ref_types,
        self.func_returns,
        self.method_returns,
        self.field_types
    );
}

impl OwnershipFactsPass.mark_last_uses(body: list) {
    last_read: dict[str, object] = {};
    for st in body {
        self.collect_reads(st, last_read);
    }
    for (nm, node) in last_read.items() {
        self.facts.last_uses[node.loc.pos_start] = True;
    }
}

impl OwnershipFactsPass.collect_reads(e: object, last_read: dict) {
    if isinstance(e, uni.Assignment) {
        if e.value is not None {
            self.collect_reads(e.value, last_read);
        }
        return;
    }
    if isinstance(e, uni.ExprStmt) {
        self.collect_reads(e.expr, last_read);
        return;
    }
    if isinstance(e, uni.ReturnStmt) {
        if e.expr is not None {
            self.collect_reads(e.expr, last_read);
        }
        return;
    }
    if isinstance(e, uni.AtomUnit) {
        self.collect_reads(e.value, last_read);
        return;
    }
    if isinstance(e, uni.Name) {
        if e.value in self.local_types and e.value != "self" {
            last_read[e.value] = e;
        }
        return;
    }
    if isinstance(e, uni.FuncCall) {
        self.collect_reads(e.target, last_read);
        for p in (e.params or []) {
            if isinstance(p, uni.Expr) {
                self.collect_reads(p, last_read);
            }
        }
        return;
    }
    if isinstance(e, uni.BinaryExpr) {
        self.collect_reads(e.left, last_read);
        self.collect_reads(e.right, last_read);
        return;
    }
    if isinstance(e, uni.AtomTrailer) {
        self.collect_reads(e.target, last_read);
        return;
    }
}

impl get_ownership_facts(module: uni.Module, prog: any = None) -> OwnershipFacts {
    facts = module.gen.ownership_facts;
    if facts is not None {
        return facts;
    }
    OwnershipFactsPass(ir_in=module, prog=prog);
    return module.gen.ownership_facts or OwnershipFacts();
}
