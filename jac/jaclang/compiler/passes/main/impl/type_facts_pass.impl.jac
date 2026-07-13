impl TypeFacts.type_of(e: object, local_types: dict[str, str]) -> str {
    return infer_type(
        e,
        local_types,
        self.ref_types,
        self.func_returns,
        self.method_returns,
        self.field_types
    );
}

impl TypeFacts.is_ref(name: str) -> bool {
    return name in self.ref_types;
}

impl TypeFactsPass.transform(ir_in: uni.Module) -> uni.Module {
    self.facts = TypeFacts();
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
            self.facts.func_returns[stmt.name_ref.sym_name] = self.ret_name(
                sig.return_type if isinstance(sig, uni.FuncSignature) else None
            );
        }
    }
}

impl TypeFactsPass.index_arch(arch: uni.Archetype) {
    name = arch.name.value;
    (fmap, rmap) = arch_type_maps(arch);
    self.facts.field_types[name] = fmap;
    self.facts.method_returns[name] = rmap;
}

impl TypeFactsPass.ret_name(ret: uni.Expr | None) -> str {
    return ret_type_name(ret);
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

impl ScopeTypes.for_ability(sig: object, self_type: str) -> dict[str, str] {
    out: dict[str, str] = {};
    if self_type {
        out["self"] = self_type;
    }
    if isinstance(sig, uni.FuncSignature) and sig.params {
        for p in sig.params {
            out[p.name.value] = type_tag_name(p.type_tag);
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

impl arch_type_maps(arch: uni.Archetype) -> tuple[dict[str, str], dict[str, str]] {
    fmap: dict[str, str] = {};
    rmap: dict[str, str] = {};
    for member in (arch.body or []) {
        if isinstance(member, uni.ArchHas) {
            for hv in member.vars {
                fmap[hv.name.value] = type_tag_name(hv.type_tag);
            }
        } elif isinstance(member, uni.Ability) and member.name_ref is not None {
            sig = member.signature;
            rmap[member.name_ref.sym_name] = ret_type_name(
                sig.return_type if isinstance(sig, uni.FuncSignature) else None
            );
        }
    }
    return (fmap, rmap);
}

impl _attr_name(nd: object) -> str {
    if isinstance(nd, uni.Name) {
        return nd.value;
    }
    return "";
}

impl infer_type(
    e: object,
    local_types: dict[str, str],
    ref_types: object,
    func_returns: dict[str, str],
    method_returns: dict[str, dict[str, str]],
    field_types: dict[str, dict[str, str]]
) -> str {
    if isinstance(e, uni.AtomUnit) {
        return infer_type(
            e.value, local_types, ref_types, func_returns, method_returns, field_types
        );
    }
    if isinstance(e, (uni.String, uni.MultiString)) {
        return "str";
    }
    if isinstance(e, uni.Bool) {
        return "bool";
    }
    if isinstance(e, uni.Int) {
        return "int";
    }
    if isinstance(e, uni.Float) {
        return "float";
    }
    if isinstance(e, uni.Name) {
        return local_types.get(e.value, "");
    }
    if isinstance(e, uni.BinaryExpr) {
        lt = infer_type(
            e.left, local_types, ref_types, func_returns, method_returns, field_types
        );
        rt = infer_type(
            e.right, local_types, ref_types, func_returns, method_returns, field_types
        );
        if isinstance(e.op, uni.Token)
        and e.op.value == "+"
        and (lt == "str" or rt == "str") {
            return "str";
        }
        if lt == "float" or rt == "float" {
            return "float";
        }
        if lt == "int" or rt == "int" {
            return "int";
        }
        return "";
    }
    if isinstance(e, uni.CompareExpr) {
        return "bool";
    }
    if isinstance(e, uni.FuncCall) {
        tgt = e.target;
        # Ref arches live in `ref_types`; value arches (`@__jac_value__`) do
        # not, but both are indexed in `field_types` so a `Type(...)` call
        # still types as `Type` for jac2c POD compound literals.
        if isinstance(tgt, uni.Name) and (
            tgt.value in ref_types or tgt.value in field_types
        ) {
            return tgt.value;
        }
        if isinstance(tgt, uni.Name) and tgt.value in func_returns {
            return func_returns[tgt.value];
        }
        if isinstance(tgt, uni.AtomTrailer) and tgt.is_attr {
            recv = infer_type(
                tgt.target,
                local_types,
                ref_types,
                func_returns,
                method_returns,
                field_types
            );
            m = _attr_name(tgt.right);
            if recv in method_returns and m in method_returns[recv] {
                return method_returns[recv][m];
            }
        }
        return "";
    }
    if isinstance(e, uni.AtomTrailer) and e.is_attr {
        recv = infer_type(
            e.target, local_types, ref_types, func_returns, method_returns, field_types
        );
        f = _attr_name(e.right);
        if recv in field_types and f in field_types[recv] {
            return field_types[recv][f];
        }
    }
    return "";
}

impl get_shared_type_facts(
    modules: list[uni.Module], prog: JacProgram | None = None
) -> TypeFacts {
    merged = TypeFacts();
    merged.ok = True;
    for m in modules {
        f = get_type_facts(m, prog);
        if not f.ok {
            merged.ok = False;
        }
        for (k, rv) in f.ref_types.items() {
            if k not in merged.ref_types {
                merged.ref_types[k] = rv;
            }
        }
        for (k, fv) in f.func_returns.items() {
            if k not in merged.func_returns {
                merged.func_returns[k] = fv;
            }
        }
        for (k, mv) in f.method_returns.items() {
            if k not in merged.method_returns {
                merged.method_returns[k] = dict(mv);
            }
        }
        for (k, tv) in f.field_types.items() {
            if k not in merged.field_types {
                merged.field_types[k] = dict(tv);
            }
        }
    }
    return merged;
}
