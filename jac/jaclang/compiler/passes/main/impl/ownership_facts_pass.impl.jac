impl OwnershipFacts.category_of(nd: uni.UniNode) -> Ownership {
    if not isinstance(nd, uni.UniNode) {
        return Ownership.BORROWED;
    }
    return self.value_category.get(nd.loc.pos_start, Ownership.BORROWED);
}

impl OwnershipFacts.is_owned(nd: uni.UniNode) -> bool {
    return self.category_of(nd) == Ownership.OWNED;
}

impl OwnershipFacts.is_last_use(nd: uni.UniNode) -> bool {
    if not isinstance(nd, uni.UniNode) {
        return False;
    }
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
    self.tf = get_type_facts(mod, self.prog);
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

impl OwnershipFactsPass.tag_name(type_tag: uni.SubTag[uni.Expr] | None) -> str {
    return type_tag_name(type_tag);
}

impl OwnershipFactsPass.analyze_ability(ab: uni.Ability, cls: str) {
    self.local_types = ScopeTypes.for_ability(ab.signature, cls);
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
    if not (isinstance(sig, uni.FuncSignature) and sig.params) {
        return;
    }
    if not self.is_straight_line(body) {
        return;
    }
    key = self.callee_key(ab, cls);
    idx = 0;
    for p in sig.params {
        pname = p.name.value;
        if self.tag_name(p.type_tag) in self.tf.ref_types {
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
    nm = ab.name_ref.sym_name if ab.name_ref is not None else "";
    if nm == "init" and cls {
        return cls;
    }
    if cls {
        return cls + "." + nm;
    }
    return nm;
}

impl OwnershipFactsPass.sole_field_store(body: list, pname: str) -> uni.UniNode | None {
    found = None;
    count = 0;
    for st in body {
        if isinstance(st, uni.Assignment) and st.value is not None {
            tgt = st.target[0];
            if isinstance(tgt, uni.AtomTrailer) and tgt.is_attr {
                v = st.value;
                target_v: object = v;
                if isinstance(v, uni.AtomUnit) {
                    target_v = v.value;
                }
                if isinstance(target_v, uni.Name) and target_v.value == pname {
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
    and isinstance(e.op, uni.Token)
    and e.op.value == "+"
    and (self.type_of(e.left) == "str" or self.type_of(e.right) == "str");
}

impl OwnershipFactsPass.type_of(e: object) -> str {
    return self.tf.type_of(e, self.local_types);
}

impl OwnershipFactsPass.mark_last_uses(body: list) {
    last_read: dict[str, uni.UniNode] = {};
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

impl get_ownership_facts(
    module: uni.Module, prog: JacProgram | None = None
) -> OwnershipFacts {
    cached: OwnershipFacts | None = module.gen.ownership_facts;
    if cached is not None {
        return cached;
    }
    if prog is not None {
        OwnershipFactsPass(ir_in=module, prog=prog);
        result: OwnershipFacts | None = module.gen.ownership_facts;
        return result or OwnershipFacts();
    }
    return OwnershipFacts();
}
