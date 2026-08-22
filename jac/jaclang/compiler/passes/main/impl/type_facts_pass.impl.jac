impl TypeFacts.type_of(
    e: object, local_types: dict[str, str], scope: dict[str, str] = {}
) -> str {
    if self.prog is not None and isinstance(e, uni.Expr) {
        resolved = self.type_of_via_checker(e);
        if resolved {
            return resolved;
        }
    }
    if isinstance(e, uni.AtomUnit) {
        return self.type_of(e.value, local_types, scope);
    }
    if isinstance(e, uni.Name) {
        t = local_types.get(e.value, "");
        return scope.get(t, t);
    }
    return "";
}

impl TypeFacts.type_of_via_checker(e: uni.Expr) -> str {
    if self.prog is None {
        return "";
    }
    ty = e.type;
    if ty is None {
        try {
            te = self.prog.get_type_evaluator();
            if te {
                ty = te.get_type_of_expression(e);
            }
        } except Exception {
            return "";
        }
    }
    if ty is None {
        return "";
    }
    return self.typebase_to_typename(ty);
}

impl TypeFacts.typebase_to_typename(ty: TypeBase | None) -> str {
    import from jaclang.compiler.type_system.type_utils { primitive_type_name_of }
    import from jaclang.compiler.type_system.types { ClassType }
    if ty is None {
        return "";
    }

    prim = primitive_type_name_of(ty);
    if prim {
        return prim;
    }

    if isinstance(ty, ClassType) {
        arch = ty.shared.symbol_table;
        if isinstance(arch, uni.Archetype) {
            if self.type_ids is not None {
                if self.type_ids.has_arch(arch) {
                    return self.type_ids.tid_of_arch(arch);
                }
            } else {
                return arch.name.value;
            }
        }
    }
    return "";
}

impl TypeFacts.is_ref(name: str) -> bool {
    return name in self.ref_types;
}

impl TypeFactsPass.transform(ir_in: uni.Module) -> uni.Module {
    self.facts = TypeFacts();
    self.facts.prog = self.prog;
    try {
        self.index_module(ir_in);
        self.facts.ok = True;
        ir_in.gen.type_facts = self.facts;
    } except Exception {
        ir_in.gen.type_facts = TypeFacts();
    }
    return ir_in;
}

impl TypeFactsPass.index_module(mod: uni.Module) {
    for stmt in mod.body {
        if isinstance(stmt, uni.Archetype) and is_ref_arch(stmt) {
            self.facts.ref_types[stmt.name.value] = True;
        }
    }
    for stmt in mod.body {
        if isinstance(stmt, uni.Archetype) {
            self.index_arch(stmt);
        } elif isinstance(stmt, uni.Ability) and stmt.name_ref is not None {
            sig = stmt.signature;
            ret = sig.return_type if isinstance(sig, uni.FuncSignature) else None;
            self.facts.func_returns[stmt.name_ref.sym_name] = self.resolve_ann_token(
                ret, self.ret_name(ret)
            );
        }
    }
}

impl TypeFactsPass.index_arch(arch: uni.Archetype) {
    name = arch.name.value;
    fmap: dict[str, str] = {};
    rmap: dict[str, str] = {};
    for member in (arch.body or []) {
        if isinstance(member, uni.ArchHas) {
            for hv in member.vars {
                ann = hv.type_tag.tag if hv.type_tag is not None else None;
                fmap[hv.name.value] = self.resolve_ann_token(
                    ann, type_tag_name(hv.type_tag)
                );
            }
        } elif isinstance(member, uni.Ability) and member.name_ref is not None {
            sig = member.signature;
            ret = sig.return_type if isinstance(sig, uni.FuncSignature) else None;
            rmap[member.name_ref.sym_name] = self.resolve_ann_token(
                ret, ret_type_name(ret)
            );
        }
    }
    self.facts.field_types[name] = fmap;
    self.facts.method_returns[name] = rmap;
}

impl TypeFactsPass.ret_name(ret: uni.Expr | None) -> str {
    return ret_type_name(ret);
}

impl TypeFactsPass.resolve_ann_token(ann: uni.Expr | None, syntactic: str) -> str {
    if ann is None or self.prog is None {
        return syntactic;
    }
    tok = "";
    try {
        te = self.prog.get_type_evaluator();
        if te {
            ty = te.get_type_of_expression(ann);
            tok = self.facts.typebase_to_typename(ty);
        }
    } except Exception {
        tok = "";
    }
    if tok {
        return tok;
    }
    return syntactic;
}

impl get_type_facts(module: uni.Module, prog: JacProgram | None = None) -> TypeFacts {
    cached = module.gen.type_facts;
    if isinstance(cached, TypeFacts) {
        return cached;
    }
    if prog is not None {
        TypeFactsPass(ir_in=module, prog=prog);
        result = module.gen.type_facts;
        if isinstance(result, TypeFacts) {
            return result;
        }
        return TypeFacts();
    }
    raise ValueError(
        "get_type_facts: prog is None and this module has no cached facts; "
        "pass a JacProgram to build facts, or call after facts were computed"
    );
}

impl ScopeTypes.for_ability(
    sig: object, self_type: str, scope: dict[str, str] = {}
) -> dict[str, str] {
    out: dict[str, str] = {};
    if self_type {
        out["self"] = self_type;
    }
    if isinstance(sig, uni.FuncSignature) and sig.params {
        for p in sig.params {
            pty = type_tag_name(p.type_tag);
            out[p.name.value] = scope.get(pty, pty);
        }
    }
    return out;
}

impl is_ref_arch(arch: uni.Archetype) -> bool {
    for dec in (arch.decorators or []) {
        if isinstance(dec, uni.Name) and dec.value == VALUE_ARCH_DECORATOR {
            return False;
        }
    }
    return True;
}

impl type_tag_name(type_tag: uni.SubTag[uni.Expr] | None) -> str {
    if type_tag is None {
        return "";
    }
    tag = type_tag.tag;
    if isinstance(tag, uni.Name) {
        return tag.value;
    }
    return tag.unparse();
}

impl ret_type_name(ret: uni.Expr | None) -> str {
    if ret is None {
        return "";
    }
    if isinstance(ret, uni.Name) {
        return ret.value;
    }
    return ret.unparse();
}

impl get_shared_type_facts(
    modules: list[uni.Module], prog: JacProgram | None = None
) -> TypeFacts {
    merged = TypeFacts();
    merged.ok = True;
    merged.prog = prog;
    idx = build_type_id_index(modules);
    merged.type_ids = idx;
    for m in modules {
        f = get_type_facts(m, prog);
        if not f.ok {
            merged.ok = False;
        }
        mp = m.loc.mod_path if m.loc else "";
        scope = idx.scope_for(m);

        for (k, rv) in f.ref_types.items() {
            merged.ref_types[idx.tid_for(mp, k)] = rv;
        }
        for (k, fv) in f.func_returns.items() {
            if k not in merged.func_returns {
                merged.func_returns[k] = scope.get(fv, fv);
            }
        }
        for (k, mv) in f.method_returns.items() {
            inner: dict[str, str] = {};
            for (mn, rt) in mv.items() {
                inner[mn] = scope.get(rt, rt);
            }
            merged.method_returns[idx.tid_for(mp, k)] = inner;
        }
        for (k, tv) in f.field_types.items() {
            fmap: dict[str, str] = {};
            for (fn, ft) in tv.items() {
                fmap[fn] = scope.get(ft, ft);
            }
            merged.field_types[idx.tid_for(mp, k)] = fmap;
        }
    }
    return merged;
}

impl module_stem(mod_path: str) -> str {
    import os;
    base = os.path.basename(mod_path or "");
    for ext in [".na.jac", ".jac", ".c", ".h"] {
        if base.endswith(ext) {
            return base[:-len(ext)];
        }
    }
    return base;
}

impl sanitize_c_ident(s: str) -> str {
    import re;
    out = re.sub(r'[^A-Za-z0-9_]', '_', s or "");
    if out and out[0].isdigit() {
        out = "_" + out;
    }
    return out or "m";
}

impl TypeIdIndex.key(mod_path: str, name: str) -> str {
    return (mod_path or "") + "\x00" + name;
}

impl TypeIdIndex.tid_for(mod_path: str, name: str) -> str {
    return self.tids.get(self.key(mod_path, name), name);
}

impl TypeIdIndex.tid_of_arch(arch: uni.Archetype) -> str {
    mp = arch.loc.mod_path if arch.loc else "";
    return self.tid_for(mp, arch.name.value);
}

impl TypeIdIndex.has_arch(arch: uni.Archetype) -> bool {
    mp = arch.loc.mod_path if arch.loc else "";
    return self.key(mp, arch.name.value) in self.tids;
}

impl TypeIdIndex.scope_for(mod: uni.Module) -> dict[str, str] {
    scope: dict[str, str] = {};
    for stmt in (mod.body or []) {
        if isinstance(stmt, uni.Archetype) {
            scope[stmt.name.value] = self.tid_of_arch(stmt);
        } elif isinstance(stmt, uni.Import) {
            for item in stmt.items {
                if not isinstance(item, uni.ModuleItem) {
                    continue;
                }
                try {
                    tgt = item.from_mod_path.resolve_relative_path();
                } except Exception {
                    continue;
                }
                if not tgt {
                    continue;
                }
                local = item.alias.value if item.alias is not None else item.name.value;
                scope[local] = self.tid_for(tgt, item.name.value);
            }
        }
    }
    return scope;
}

impl build_type_id_index(modules: list[uni.Module]) -> TypeIdIndex {
    idx = TypeIdIndex();
    defs: list[tuple[str, str]] = [];
    name_mods: dict[str, set[str]] = {};
    for m in modules {
        for stmt in (m.body or []) {
            if isinstance(stmt, uni.Archetype) {
                mp = stmt.loc.mod_path if stmt.loc else "";
                nm = stmt.name.value;
                defs.append((mp, nm));
                if nm not in name_mods {
                    name_mods[nm] = set();
                }
                name_mods[nm].add(mp);
            }
        }
    }
    used: set[str] = set();

    # Namespace EVERY archetype struct name unconditionally as `module__Name`
    # so separately-built TUs never emit a bare `struct Token` that would clash
    # when fused/linked. The `_N` suffix still disambiguates genuine collisions.
    colliders: list[tuple[str, str]] = [];
    placed: set[str] = set();
    for (mp, nm) in defs {
        k = idx.key(mp, nm);
        if k in placed {
            continue;
        }
        placed.add(k);
        colliders.append((mp, nm));
    }
    colliders.sort(key=lambda (pair) { pair[1] + "\x00" + pair[0]; });
    for (mp, nm) in colliders {
        base = sanitize_c_ident(module_stem(mp)) + "__" + nm;
        cand = base;
        n = 1;
        while cand in used {
            cand = base + "_" + str(n);
            n += 1;
        }
        used.add(cand);
        idx.tids[idx.key(mp, nm)] = cand;
    }
    return idx;
}
