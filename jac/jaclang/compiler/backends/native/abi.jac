import from jaclang.compiler.backends.native.llvm { ir }

"""Deferred composite storage, resolved after its component types are complete."""
obj CompositeStorage {
    has storage: ir.IdentifiedStructType,
        components: list[ir.Type],
        kind: str,
        alignment: int = 0;
}

"""A concrete storage layout measured by the selected LLVM target."""
obj StorageLayout {
    has size: int,
        alignment: int,
        field_offsets: list[int] = [];
}

"""Whether LLVM can size this storage without following pointer pointees."""
def is_sized_storage(typ: ir.Type, ancestors: set[int] | None = None) -> bool {
    if isinstance(typ, (ir.IntType, ir.HalfType, ir.FloatType, ir.DoubleType, ir.PointerType)) { return True; }
    path = ancestors or set();
    if id(typ) in path { return False; }
    path = path | {id(typ)};
    if isinstance(typ, (ir.ArrayType, ir.VectorType)) {
        return isinstance(typ.element, ir.Type) and is_sized_storage(typ.element, path);
    }
    if isinstance(typ, (ir.LiteralStructType, ir.IdentifiedStructType)) {
        if typ.elements is None { return False; }
        return all(isinstance(field, ir.Type) and is_sized_storage(field, path) for field in typ.elements);
    }
    return False;
}

"""Measure complete storage types without duplicating target size/alignment rules."""
def storage_layouts(module: ir.Module, types: dict[str, ir.Type]) -> dict[str, StorageLayout] {
    import from jaclang.compiler.backends.native.llvm { binding }
    if not module.data_layout { raise ValueError("Storage layout requires an explicit target data layout"); }
    if not types { return {}; }
    probe = ir.Module(name="storage_layout", context=module.context);
    probe.data_layout = module.data_layout;
    probe.triple = module.triple;
    for (name, typ) in types.items() {
        if not is_sized_storage(typ) { raise ValueError("Storage type is incomplete or unsized: " + name); }
        ir.GlobalVariable(probe, typ, name=name);
    }
    layouts: dict[str, StorageLayout] = {};
    with binding.parse_assembly(str(probe)) as bound, binding.create_target_data(str(module.data_layout)) as target_data {
        for value in bound.global_variables {
            (size, alignment) = target_data.get_global_storage_layout(value);
            typ = types[value.name];
            offsets: list[int] = [];
            if isinstance(typ, (ir.LiteralStructType, ir.IdentifiedStructType)) {
                assert typ.elements is not None;
                (offsets, _) = target_data.get_global_struct_layout(value, len(typ.elements));
            }
            layouts[value.name] = StorageLayout(size, alignment, offsets);
        }
    }
    return layouts;
}

"""Construct untagged overlapping storage with the alternatives' target alignment."""
def overlapping_storage(module: ir.Module, alternatives: list[ir.Type]) -> ir.LiteralStructType {
    if not alternatives { raise ValueError("Overlapping storage requires at least one alternative"); }
    layouts = storage_layouts(module, {str(i): typ for (i, typ) in enumerate(alternatives)});
    capacity = max(layout.size for layout in layouts.values());
    # Zero-length fields impose the alternatives' ABI alignments without taking
    # space. The enclosing LLVM struct supplies the final alignment padding.
    fields: list[ir.Type] = [ir.ArrayType(typ, 0) for typ in alternatives];
    fields.append(ir.ArrayType(ir.IntType(8), capacity));
    return ir.LiteralStructType(fields);
}

"""Build aligned storage and verify the alignment against the target data layout."""
def aligned_storage(module: ir.Module, element: ir.Type, alignment: int) -> ir.LiteralStructType {
    if alignment <= 0 or (alignment & (alignment - 1)) != 0 or alignment > (1 << 29) {
        raise ValueError("Unsupported storage alignment");
    }
    marker = ir.VectorType(ir.IntType(8), alignment);
    layout = ir.LiteralStructType([element, ir.ArrayType(marker, 0)]);
    measured = storage_layouts(module, {"element": element, "aligned": layout});
    if measured["aligned"].alignment < alignment or measured["aligned"].field_offsets[0] != 0 {
        raise ValueError("Target cannot represent the requested storage alignment");
    }
    return layout;
}

def struct_layouts(module: ir.Module) -> dict[str, tuple[list[int], int]] {
    types: dict[str, ir.Type] = {name: typ for (name, typ) in module.context.identified_types.items()
        if not typ.is_opaque};
    layouts = storage_layouts(module, types);
    return {name: (layout.field_offsets, layout.size) for (name, layout) in layouts.items()};
}


def scalar_layout(
    llt: (ir.Type | None)
) -> tuple[int, int, list[tuple[int, bool, int]]] {
    if isinstance(llt, ir.DoubleType) {
        return (8, 8, [(0, True, 64)]);
    }
    if isinstance(llt, ir.FloatType) {
        return (4, 4, [(0, True, 32)]);
    }
    if isinstance(llt, ir.IntType) {
        w = llt.width;
        nbytes = w // 8;
        if nbytes < 1 {
            nbytes = 1;
        }
        return (nbytes, nbytes, [(0, False, w)]);
    }
    if isinstance(llt, ir.PointerType) {
        return (8, 8, [(0, False, 64)]);
    }

    return (8, 8, [(0, False, 64)]);
}

def classify_struct_sysv(
    size: int, align: int, scalars: list[tuple[int, bool, int]]
) -> dict[str, any] {
    if size == 0 {
        return {
            "size": 0,
            "align": 1,
            "memory": False,
            "coerce": [],
            "byval": True,
            "safe": False
        };
    }

    if size > 16 {
        return {
            "size": size,
            "align": align,
            "memory": True,
            "coerce": [],
            "byval": True,
            "safe": False
        };
    }
    num_eb = (size + 7) // 8;
    eb_cls: list[str] = [];
    eb_dbl: list[bool] = [];
    eb_nfloat: list[int] = [];
    for _e in range(num_eb) {
        eb_cls.append("NONE");
        eb_dbl.append(False);
        eb_nfloat.append(0);
    }
    for (off, is_sse, bits) in scalars {
        eb = off // 8;
        if eb >= num_eb {
            continue;
        }
        cur = eb_cls[eb];
        cls = "SSE" if is_sse else "INT";
        if cur == "NONE" {
            eb_cls[eb] = cls;
        } elif cur == "INT" or cls == "INT" {
            eb_cls[eb] = "INT";
        } else {
            eb_cls[eb] = "SSE";
        }
        if is_sse {
            eb_nfloat[eb] += 1;
            if bits == 64 {
                eb_dbl[eb] = True;
            }
        }
    }
    coerce: list[ir.Type] = [];
    for eb in range(num_eb) {
        used = size - (eb * 8);
        if used > 8 {
            used = 8;
        }
        if eb_cls[eb] == "SSE" {
            if eb_dbl[eb] {
                coerce.append(ir.DoubleType());
            } elif eb_nfloat[eb] >= 2 {
                coerce.append(ir.VectorType(ir.FloatType(), 2));
            } else {
                coerce.append(ir.FloatType());
            }
        } else {
            if used <= 1 {
                coerce.append(ir.IntType(8));
            } elif used <= 2 {
                coerce.append(ir.IntType(16));
            } elif used <= 4 {
                coerce.append(ir.IntType(32));
            } else {
                coerce.append(ir.IntType(64));
            }
        }
    }
    return {
        "size": size,
        "align": align,
        "memory": False,
        "coerce": coerce,
        "byval": True,
        "safe": False
    };
}

def classify_struct_aapcs(
    size: int, align: int, scalars: list[tuple[int, bool, int]]
) -> dict[str, any] {
    if size == 0 {
        return {
            "size": 0,
            "align": 1,
            "memory": False,
            "coerce": [],
            "byval": False,
            "safe": True
        };
    }

    is_hfa = len(scalars) >= 1 and len(scalars) <= 4;
    hfa_bits = scalars[0][2] if scalars else 0;
    for (_off, _is_sse, _bits) in scalars {
        if not _is_sse or _bits != hfa_bits {
            is_hfa = False;
        }
    }
    if is_hfa {
        elem = ir.DoubleType() if hfa_bits == 64 else ir.FloatType();
        return {
            "size": size,
            "align": align,
            "memory": False,
            "coerce": [ir.ArrayType(elem, len(scalars))],
            "byval": False,
            "safe": True
        };
    }

    if size > 16 {
        return {
            "size": size,
            "align": align,
            "memory": True,
            "coerce": [],
            "byval": False,
            "safe": True
        };
    }

    if size <= 8 {
        coerce: list[ir.Type] = [ir.IntType(64)];
    } else {
        coerce: list[ir.Type] = [ir.ArrayType(ir.IntType(64), 2)];
    }
    return {
        "size": size,
        "align": align,
        "memory": False,
        "coerce": coerce,
        "byval": False,
        "safe": True
    };
}

def classify_struct(
    size: int, align: int, scalars: list[tuple[int, bool, int]], triple: str
) -> dict[str, any] {
    if "aarch64" in triple or "arm64" in triple {
        return classify_struct_aapcs(size, align, scalars);
    }
    return classify_struct_sysv(size, align, scalars);
}

def classify_foreign_fn(
    structs: dict[str, list[tuple[str, str | None]]],
    params: list[tuple[(str | None), (str | None)]],
    ret_tname: (str | None),
    triple: str
) -> (dict[str, any] | None) {
    import from jaclang.compiler.backends.native.foreign { foreign_struct_layout }
    has_struct = ret_tname is not None and ret_tname in structs;
    for (_pn, _tn) in params {
        if _tn is not None and _tn in structs {
            has_struct = True;
        }
    }
    if not has_struct {
        return None;
    }
    sig: list[tuple[str, str | int | ir.Type]] = [];
    param_plan: list[dict[str, any]] = [];
    for (i, (pname, tname)) in enumerate(params) {
        pn = pname or f"arg{i}";
        if tname is not None and tname in structs {
            (sz, al, leaves) = foreign_struct_layout(structs, tname);
            cls = classify_struct(sz, al, leaves, triple);
            if cls["memory"] {
                param_plan.append(
                    {
                        "kind": "struct_mem",
                        "sname": tname,
                        "pname": pn,
                        "align": cls["align"],
                        "byval": cls["byval"],
                        "argpos": len(sig)
                    }
                );
                sig.append(("structptr", tname));
            } else {
                start = len(sig);
                for ct in cls["coerce"] {
                    sig.append(("coerce", ct));
                }
                param_plan.append(
                    {
                        "kind": "struct_reg",
                        "sname": tname,
                        "pname": pn,
                        "coerce": cls["coerce"],
                        "safe": cls["safe"],
                        "argpos": start
                    }
                );
            }
        } else {
            param_plan.append(
                {"kind": "scalar", "tname": tname, "pname": pn, "argpos": len(sig)}
            );
            sig.append(("scalar", i));
        }
    }
    sret = False;
    sig_ret: tuple[str] | tuple[str, list[ir.Type]] = ("scalar", );
    ret_plan: dict[str, any] = {"kind": "scalar"};
    if ret_tname is not None and ret_tname in structs {
        (rsz, ral, rleaves) = foreign_struct_layout(structs, ret_tname);
        rcls = classify_struct(rsz, ral, rleaves, triple);
        if rcls["memory"] {
            sret = True;
            sig_ret = ("void", );
            sig = [("sretptr", ret_tname)] + sig;
            for pp in param_plan {
                pp["argpos"] += 1;
            }
            ret_plan = {"kind": "sret", "sname": ret_tname, "align": rcls["align"]};
        } else {
            sig_ret = ("coerce", rcls["coerce"]);
            ret_plan = {
                "kind": "struct_reg",
                "sname": ret_tname,
                "coerce": rcls["coerce"],
                "safe": rcls["safe"]
            };
        }
    }
    return {
        "params": param_plan,
        "ret": ret_plan,
        "sret": sret,
        "sig": sig,
        "sig_ret": sig_ret
    };
}
