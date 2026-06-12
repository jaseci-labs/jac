"""Foreign declaration model (One Owner Per Analysis, Phase 8).

The single owner of WHAT the user declared at the C boundary: struct
shapes collected from clib import blocks, and the C data layout computed
from them. No backend state and no LLVM types - scalar kinds are the
declared type names, layouts are (byte_offset, is_float, bit_width)
leaves ready for targets.abi.classify_struct. Callers supply the module
universe (entry module plus transitively imported native modules); the
backend knows its import graph, this module knows what the declarations
mean.
"""
import jaclang.jac0core.unitree as uni;

# Declared scalar type name -> (size, align, is_float, bits). `str` is a
# char* pointer at the C boundary; `float`/`int` are the Jac-default
# 64-bit forms.
glob FOREIGN_SCALARS: dict[str, tuple] = {
         "u8": (1, 1, False, 8),
         "i8": (1, 1, False, 8),
         "bool": (1, 1, False, 8),
         "u16": (2, 2, False, 16),
         "i16": (2, 2, False, 16),
         "u32": (4, 4, False, 32),
         "i32": (4, 4, False, 32),
         "u64": (8, 8, False, 64),
         "i64": (8, 8, False, 64),
         "int": (8, 8, False, 64),
         "f32": (4, 4, True, 32),
         "f64": (8, 8, True, 64),
         "float": (8, 8, True, 64),
         "str": (8, 8, False, 64),

     };

"""Collect clib struct declarations from the given modules: name ->
ordered list of (field_name, declared_type_name). Field types are the
declaration-surface names (the C boundary is declared, not inferred).

Duplicate names across modules are last-writer-wins: C symbol and struct
names are unique per link unit, so duplicate declarations of the same
name must describe the same C entity (the same contract a C compiler
applies to redeclarations) - the model does not arbitrate conflicting
redeclarations."""
def collect_foreign_structs(modules: list) -> dict {
    out: dict = {};
    for mod in modules {
        if mod is None {
            continue;
        }
        for imp in mod.get_all_sub_nodes(typ=uni.Import, brute_force=True) {
            if not imp.clib_decls {
                continue;
            }
            for decl in imp.clib_decls {
                if isinstance(decl, uni.Archetype) and decl.name is not None {
                    fields: list = [];
                    for var in decl.get_has_vars() {
                        tname: (str | None) = None;
                        if var.type_tag is not None and var.type_tag.tag is not None {
                            tag = var.type_tag.tag;
                            if isinstance(tag, uni.Name) {
                                tname = tag.value;
                            } elif tag?.value and isinstance(tag.value, str) {
                                tname = tag.value;
                            }
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

"""Declared type name of an annotation node, or None. The C boundary is
declared, not inferred: a foreign signature means exactly what its
annotation names say, so this reads the surface name only (no union
peeling, no symbol resolution)."""
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

"""Collect clib function declarations from the given modules: name ->
{"params": ordered (param_name, declared_type_name) pairs,
 "ret": declared return type name | None}. Like collect_foreign_structs,
this owns WHAT the user declared at the C boundary; backends own only
how those names materialize as LLVM types. The same last-writer-wins
duplicate-name contract applies: C function symbols are unique per link
unit, so redeclarations must agree."""
def collect_foreign_fns(modules: list) -> dict {
    out: dict = {};
    for mod in modules {
        if mod is None {
            continue;
        }
        for imp in mod.get_all_sub_nodes(typ=uni.Import, brute_force=True) {
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

"""C data layout of a declared foreign struct: returns
(size, align, scalars) where scalars are (byte_offset, is_float, bits)
leaves - nested struct fields are flattened recursively, offsets follow
C alignment rules, and total size is padded to the max alignment.
Unknown field type names lay out as 64-bit integers (pointer-sized)."""
def foreign_struct_layout(structs: dict, name: str) -> tuple {
    fields = structs.get(name, []);
    offset = 0;
    max_align = 1;
    scalars: list = [];
    for (fname, tname) in fields {
        if tname is not None and tname in structs {
            (sz, al, subs) = foreign_struct_layout(structs, tname);
        } elif tname is not None and tname in FOREIGN_SCALARS {
            (sz, al, isf, bits) = FOREIGN_SCALARS[tname];
            subs = [(0, isf, bits)];
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
