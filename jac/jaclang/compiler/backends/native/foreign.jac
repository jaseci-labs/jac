import jaclang.compiler.ir.schema as uni;
import from jaclang.compiler.analysis.types.type_registry { JAC_TYPE_REGISTRY }

def collect_foreign_structs(modules: list) -> dict {
    out: dict = {};
    for mod in modules {
        if mod is None {
            continue;
        }
        for imp in mod.get_all_sub_nodes(typ=uni.Import) {
            if not imp.clib_decls {
                continue;
            }
            for decl in imp.clib_decls {
                if isinstance(decl, uni.Archetype) and decl.name is not None {
                    fields: list = [];
                    for var in decl.get_has_vars() {
                        tname: (str | None) = None;
                        if var.type_tag is not None and var.type_tag.tag is not None {
                            tname = declared_type_name(var.type_tag.tag);
                        }
                        fields.append((var.sym_name, tname));
                    }
                    out[decl.name.value] = fields;
                }
            }
        }
    }
    return out;
}

def declared_type_name(type_expr: (uni.UniNode | None)) -> (str | None) {
    if type_expr is None {
        return None;
    }
    if isinstance(type_expr, uni.Name) {
        return type_expr.value;
    }
    val = type_expr?.value;
    if isinstance(val, str) {
        return val;
    }
    return None;
}

def collect_foreign_fns(modules: list) -> dict {
    out: dict = {};
    for mod in modules {
        if mod is None {
            continue;
        }
        for imp in mod.get_all_sub_nodes(typ=uni.Import) {
            if not imp.clib_decls {
                continue;
            }
            for decl in imp.clib_decls {
                if not isinstance(decl, uni.Ability) {
                    continue;
                }
                if decl.signature is None
                    or not isinstance(decl.signature, uni.FuncSignature) {
                    continue;
                }
                fname = decl.name_ref.sym_name if decl.name_ref else None;
                if fname is None {
                    continue;
                }
                params: list = [];
                for p in decl.signature.get_parameters() {
                    if p.is_vararg or p.is_kwargs {
                        continue;
                    }
                    ptn = declared_type_name(p.type_tag.tag)
                        if (p.type_tag and p.type_tag.tag)
                        else None;
                    params.append((p.name.value if p.name else None, ptn));
                }
                out[fname] = {
                    "params": params,
                    "ret": declared_type_name(decl.signature.return_type)
                };
            }
        }
    }
    return out;
}

def foreign_struct_layout(
    structs: dict, name: str
) -> tuple[int, int, list[tuple[int, bool, int]]] {
    fields = structs.get(name, []);
    offset = 0;
    max_align = 1;
    scalars: list[tuple[int, bool, int]] = [];
    for (fname, tname) in fields {
        if isinstance(tname, str) and tname in structs {
            (sz, al, subs) = foreign_struct_layout(structs, tname);
        } elif isinstance(tname, str)
            and (scalar := JAC_TYPE_REGISTRY.get(tname)) is not None
            and scalar.width > 0 {
            (sz, al) = (scalar.size_bytes(), scalar.align());
            subs = [(0, scalar.is_float, max(8, scalar.width))];
        } else {
            (sz, al, subs) = (8, 8, [(0, False, 64)]);
        }
        if al > 0 and (offset % al) != 0 {
            offset += al - (offset % al);
        }
        for (so, isf2, b) in subs {
            scalars.append((offset + so, isf2, b));
        }
        offset += sz;
        if al > max_align {
            max_align = al;
        }
    }
    size = offset;
    if max_align > 0 and (size % max_align) != 0 {
        size += max_align - (size % max_align);
    }
    return (size, max_align, scalars);
}
