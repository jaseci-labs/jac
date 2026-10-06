import from jaclang.compiler.frontend.constant { OwnershipKind }

impl NativeLowering._nogc_owned_param(p: uni.ParamVar) -> bool {
    if not self._nogc_owned_world() or p.type_tag is None {
        return False;
    }
    return p.type_tag.ownership == OwnershipKind.OWN;
}

impl NativeLowering._normalize_type_key(key: str) -> str {
    if " | " in key or ("|" in key and "type[" in key) {
        sep = " | " if " | " in key else "|";
        for part in key.split(sep) {
            _p = part.strip();
            if _p.startswith("type[") and _p.endswith("]") {
                _p = _p[5:-1];
            }
            if _p not in ("None", "NoneType") {
                return _p;
            }
        }
    }
    if key.startswith("type[") and key.endswith("]") {
        key = key[5:-1];
    }
    return key;
}

impl NativeLowering._elem_keys_of_annotation(
    ann: (uni.UniNode | None)
) -> (list[str | None] | None) {
    if ann is None {
        return None;
    }

    if isinstance(ann, uni.AtomUnit) {
        return self._elem_keys_of_annotation(ann.value);
    }
    if (isinstance(ann, uni.BinaryExpr) and getattr(ann.op, 'value', '') == "|") {
        return (
            self._elem_keys_of_annotation(ann.left)
            or self._elem_keys_of_annotation(ann.right)
        );
    }
    elems: list[uni.UniNode] = [];
    if isinstance(ann, uni.TupleVal) {
        elems = list(ann.values or []);
    } elif isinstance(ann, uni.AtomTrailer) and isinstance(ann.right, uni.IndexSlice) {
        for s in ann.right.slices {
            inner = s.start if s.start is not None else s;
            if isinstance(inner, uni.TupleVal) {
                elems.extend(list(inner.values or []));
            } else {
                elems.append(inner);
            }
        }
    }
    if not elems {
        return None;
    }
    keys: list[str | None] = [];
    for e in elems {
        while (isinstance(e, uni.BinaryExpr) and getattr(e.op, 'value', '') == "|") {
            e = e.left;
        }
        _ek: (str | None) = None;
        _etb = e?.type if isinstance(e, uni.Expr) else None;
        if _etb is not None {
            try {
                mangled = self._mangled_of(_etb);
                if mangled is not None {
                    _ek = self._normalize_type_key(mangled);
                }
            } except Exception {}
        }
        keys.append(_ek);
    }
    return keys;
}

impl NativeLowering._record_ret_facts(
    name: str, sig: uni.FuncSignature, imported: (NativeFuncLayout | None) = None
) -> None {
    _rt = sig.return_type;
    if _rt is None {
        return;
    }
    if isinstance(_rt, uni.BinaryExpr) and getattr(_rt.op, 'value', '') == "|" {
        _rt = _rt.left;
    }
    _rtb = _rt?.type;
    if _rtb is not None {
        try {
            mangled = self._mangled_of(_rtb);
            if mangled is not None {
                self.func_ret_type_key[name] = self._normalize_type_key(mangled);
            }
        } except Exception {}
    }
    if imported is not None and imported.ret_enum_type {
        self.func_ret_type_key.setdefault(name, imported.ret_enum_type);
    }
    keys = imported.ret_elem_keys
        if imported is not None
        else self._elem_keys_of_annotation(_rt);
    if keys {
        self.func_ret_elem_keys[name] = keys;
    }
}

impl NativeLowering._ability_is_generator(nd: uni.Ability) -> bool {
    """Whether the ability's own body yields -- inline, or in its impl annex.""";
    owner: uni.UniNode = nd.body if isinstance(nd.body, uni.ImplDef) else nd;
    for y in owner.get_all_sub_nodes(typ=uni.YieldExpr) {
        _cur = y.parent;
        while _cur is not None
            and _cur is not owner
            and not isinstance(_cur, (uni.Ability, uni.ImplDef, uni.LambdaExpr)) {
            _cur = _cur.parent;
        }
        if _cur is owner {
            return True;
        }
    }
    return False;
}
