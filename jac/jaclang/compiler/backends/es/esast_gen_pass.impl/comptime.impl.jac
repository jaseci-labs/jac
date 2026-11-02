impl EsastGenPass._ct_es_expr(
    cv: (CtValue | None), jac_node: uni.UniNode
) -> (es.Expression | None) {
    if cv is None or cv.is_deferred {
        return None;
    }
    built = self._ct_es_value(cv);
    if built is None {
        return None;
    }
    return self.sync_loc(built, jac_node=jac_node);
}

impl EsastGenPass._ct_es_value(v: CtValue) -> (es.Expression | None) {
    if isinstance(v, CtNone) {
        return es.Literal(value=None);
    }
    if isinstance(v, (CtBool, CtFloat, CtStr)) {
        return es.Literal(value=v.value);
    }
    if isinstance(v, CtInt) {
        return es.Literal(value=int_host(v));
    }
    if isinstance(v, (CtList, CtTuple, CtSet)) {
        elements: list[(es.Expression | es.SpreadElement | None)] = [];
        for item in v.items {
            built = self._ct_es_value(item);
            if built is None {
                return None;
            }
            elements.append(built);
        }
        return es.ArrayExpression(elements=elements);
    }
    if isinstance(v, CtDict) {
        props: list[(es.Property | es.SpreadElement)] = [];
        for (i, k) in enumerate(v.keys) {
            if not isinstance(k, CtStr) {
                return None;
            }
            built = self._ct_es_value(v.vals[i]);
            if built is None {
                return None;
            }
            props.append(es.Property(key=es.Literal(value=k.value), value=built));
        }
        return es.ObjectExpression(properties=props);
    }
    return None;
}

impl EsastGenPass._comptime_only_names -> set[str] {
    cached = self._ct_only_names;
    if cached is not None {
        return cached;
    }
    names: set[str] = set();
    for imp in self.module.get_all_sub_nodes(uni.Import) {
        if not imp.is_comptime {
            continue;
        }
        for item in imp.items {
            bound: (uni.Name | None) = item.alias;
            if (
                bound is None
                and isinstance(item, uni.ModuleItem)
                and isinstance(item.name, uni.Name)
            ) {
                bound = item.name;
            }
            if bound is None and isinstance(item, uni.ModulePath) and item.path {
                last = item.path[-1];
                bound = last if isinstance(last, uni.Name) else None;
            }
            if bound is not None {
                names.add(bound.sym_name);
            }
        }
    }
    for ab in self.module.get_all_sub_nodes(uni.Ability) {
        if ab.is_comptime and ab.name_ref is not None {
            names.add(ab.name_ref.sym_name);
        }
    }
    self._ct_only_names = names;
    return names;
}

impl EsastGenPass._ct_only_name(nd: uni.Name) -> bool {
    if nd.sym_name in self._comptime_only_names() {
        return True;
    }
    sym = nd.sym;
    if sym is None {
        return False;
    }
    decl = sym.decl;
    imp = decl.find_parent_of_type(uni.Import) if isinstance(decl, uni.Name) else None;
    if imp is not None and imp.is_comptime {
        return True;
    }
    owner = decl.name_of;
    return isinstance(owner, uni.Ability) and owner.is_comptime;
}

impl EsastGenPass._is_ct_type_param(nd: uni.Name) -> bool {
    sym = nd.sym;
    if sym is None {
        return False;
    }
    owner = sym.decl.name_of;
    return isinstance(owner, uni.TypeParam) and owner.is_comptime;
}

impl EsastGenPass._ct_ctor_slots(
    nd: uni.UniNode
) -> (list[tuple[str, uni.Expr]] | None) {
    if not isinstance(nd, uni.AtomTrailer) or nd.is_attr {
        return None;
    }
    if not isinstance(nd.right, uni.IndexSlice) or nd.right.is_range {
        return None;
    }
    t = nd.target.type;
    if not isinstance(t, ClassType) {
        return None;
    }
    shared = t.shared;
    if not shared.ct_params {
        return None;
    }
    arch = shared.symbol_table;
    if not isinstance(arch, uni.Archetype) {
        return None;
    }
    s0 = nd.right.slices[0] if nd.right.slices else None;
    head = s0.start if s0 is not None else None;
    vals: list[uni.Expr | uni.KWPair] = list(head.values)
        if isinstance(head, uni.TupleVal)
        else ([head] if head else []);
    out: list[tuple[str, uni.Expr]] = [];
    for (i, tp) in enumerate(arch.type_params or []) {
        if tp.is_comptime and i < len(vals) {
            value = vals[i];
            if not isinstance(value, uni.Expr) {
                return None;
            }
            out.append((tp.name.value, value));
        }
    }
    return out;
}

impl EsastGenPass._trailer_reaches_ct_class(nd: uni.AtomTrailer) -> bool {
    cur: any = nd.target;
    while isinstance(cur, uni.AtomTrailer) {
        if self._ct_ctor_slots(cur) is not None {
            return True;
        }
        cur = cur.target;
    }
    return False;
}
