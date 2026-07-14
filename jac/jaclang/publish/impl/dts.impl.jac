import from jaclang.jac0core.unitree { Module, Ability, Archetype, GlobalVars }
import from jaclang.publish.jsdoc { jac_type_to_ts }

def _param_type_str(param: any) -> str {
    tag = param?.type_tag;
    if tag is None {
        return "any";
    }
    inner = tag?.tag;
    if inner is None or not hasattr(inner, "unparse") {
        return "any";
    }
    try {
        return jac_type_to_ts(inner.unparse());
    } except Exception {
        return "any";
    }
}

def _fn_decl(ability: Ability) -> str {
    name = ability?.sym_name;
    if not name {
        return "";
    }
    sig = ability?.signature;
    parts: list[str] = [];
    params = sig?.params if sig else None;
    if params {
        for p in params {
            pname = p?.sym_name;
            if not pname {
                continue;
            }
            ptype = _param_type_str(p);
            optional = "?" if p?.value is not None else "";
            parts.append(f"{pname}{optional}: {ptype}");
        }
    }
    ret = "void";
    rt = sig?.return_type if sig else None;
    if rt is not None and hasattr(rt, "unparse") {
        try {
            rt_str = rt.unparse();
        } except Exception {
            rt_str = "";
        }
        if rt_str {
            ret = jac_type_to_ts(rt_str, is_return=True);
        }
    }
    return f"export declare function {name}({', '.join(parts)}): {ret};";
}

def _class_decl(arch: Archetype) -> str {
    name = arch?.sym_name;
    if not name {
        return "";
    }
    lines: list[str] = [f"export declare class {name} {{"];
    body = arch?.body or [];
    for member in body {
        if type(member).__name__ != "ArchHas" {
            continue;
        }
        for v in member?.vars or [] {
            fname = v?.sym_name;
            if not fname {
                continue;
            }
            lines.append(f"  {fname}: {_param_type_str(v)};");
        }
    }
    lines.append("}");
    return "\n".join(lines);
}

def _global_decl(assign: any, wanted: any) -> str {
    targets = assign?.target or [];
    if not targets {
        return "";
    }
    gname = targets[0]?.value;
    if not gname or gname not in wanted {
        return "";
    }
    gtype = "any";
    tag = assign?.type_tag;
    inner = tag?.tag if tag is not None else None;
    if inner is not None and hasattr(inner, "unparse") {
        try {
            gtype = jac_type_to_ts(inner.unparse());
        } except Exception {
            gtype = "any";
        }
    }
    return f"export declare const {gname}: {gtype};";
}

impl dts_for_module(mod: Module) -> str {
    manifest = mod.gen.client_manifest if (mod and mod.gen) else None;
    exports: set = set(manifest.exports) if manifest else set();
    globals_set: set = set(manifest.globals) if manifest else set();
    if not exports and not globals_set {
        return "";
    }

    blocks: list[str] = [];
    for nd in mod.body {
        if isinstance(nd, Ability) {
            if nd?.sym_name in exports {
                decl = _fn_decl(nd);
                if decl {
                    blocks.append(decl);
                }
            }
        } elif isinstance(nd, Archetype) {
            if nd?.sym_name in exports {
                decl = _class_decl(nd);
                if decl {
                    blocks.append(decl);
                }
            }
        } elif isinstance(nd, GlobalVars) {
            for assign in nd?.assignments or [] {
                decl = _global_decl(assign, globals_set);
                if decl {
                    blocks.append(decl);
                }
            }
        }
    }

    if not blocks {
        return "";
    }
    return "\n".join(blocks) + "\n";
}
