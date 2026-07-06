import jaclang.jac0core.unitree as uni;

def is_ref_arch(arch: uni.Archetype) -> bool {
    for member in (arch.body or []) {
        if isinstance(member, uni.Ability) {
            return True;
        }
    }
    return arch.base_classes is not None and len(arch.base_classes) > 0;
}

def type_tag_name(type_tag: object) -> str {
    if type_tag is None {
        return "";
    }
    tag = type_tag.tag;
    if isinstance(tag, uni.Name) {
        return tag.value;
    }
    return tag.unparse();
}

def ret_type_name(ret: object) -> str {
    if ret is None {
        return "";
    }
    if isinstance(ret, uni.Name) {
        return ret.value;
    }
    return ret.unparse();
}

def arch_type_maps(arch: uni.Archetype) -> tuple[dict[str, str], dict[str, str]] {
    fmap: dict[str, str] = {};
    rmap: dict[str, str] = {};
    for member in (arch.body or []) {
        if isinstance(member, uni.ArchHas) {
            for hv in member.vars {
                fmap[hv.name.value] = type_tag_name(hv.type_tag);
            }
        } elif isinstance(member, uni.Ability) and member.name_ref is not None {
            sig = member.signature;
            rmap[member.name_ref.value] = ret_type_name(
                sig.return_type if sig else None
            );
        }
    }
    return (fmap, rmap);
}

def _attr_name(nd: object) -> str {
    if isinstance(nd, uni.Name) {
        return nd.value;
    }
    return "";
}

def infer_type(
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
        if e.op.value == "+" and (lt == "str" or rt == "str") {
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
        if isinstance(tgt, uni.Name) and tgt.value in ref_types {
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
