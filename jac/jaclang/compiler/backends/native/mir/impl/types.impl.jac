impl MirType.is_scalar -> bool {
    return self.kind
        in (MirKind.BOOL, MirKind.INT, MirKind.FLOAT, MirKind.NONE, MirKind.C_PTR);
}

impl MirType.is_numeric -> bool {
    return self.kind in (MirKind.BOOL, MirKind.INT, MirKind.FLOAT);
}

impl MirType.is_ref -> bool {
    return self.kind
        in (
            MirKind.STR_REF,
            MirKind.BYTES,
            MirKind.BYTEARRAY,
            MirKind.OPT_REF,
            MirKind.LIST,
            MirKind.LIST_AOS,
            MirKind.DICT,
            MirKind.SET,
            MirKind.OBJ,
            MirKind.FN,
            MirKind.ITER,
            MirKind.RANGE,
            MirKind.COMPLEX
        );
}

impl MirType.is_sized -> bool {
    return self.kind == MirKind.INT and self.name == "sized";
}

impl MirType.payload -> MirType {
    if not self.args {
        raise ValueError(f"MIR type {self.render()} has no payload");
    }
    return self.args[0];
}

impl MirType.render -> str {
    if self.kind == MirKind.INT {
        if not self.is_sized() {
            return "int";
        }
        return f"{'i' if self.signed else 'u'}{self.width}";
    }
    if self.kind == MirKind.FLOAT {
        return f"f{self.width}";
    }
    inner = ", ".join(arg.render() for arg in self.args);
    label = self.kind.value;
    if self.name {
        label = f"{label} {self.name}";
    }
    return f"{label}<{inner}>" if self.args else label;
}

impl mir_type(
    kind: MirKind,
    width: int = 0,
    signed: bool = False,
    name: str = "",
    args: (list[MirType] | None) = None
) -> MirType {
    members: list[MirType] = list(args) if args is not None else [];
    key = f"{kind.value}|{width}|{int(signed)}|{name}|"
        + ",".join(arg.key for arg in members);
    found = _MIR_TYPES.get(key);
    if found is not None {
        return found;
    }
    made = MirType(
        kind=kind, width=width, signed=signed, name=name, args=members, key=key
    );
    _MIR_TYPES[key] = made;
    return made;
}

impl mir_void -> MirType {
    return mir_type(MirKind.VOID);
}

impl mir_none -> MirType {
    return mir_type(MirKind.NONE);
}

impl mir_bool -> MirType {
    return mir_type(MirKind.BOOL, width=1);
}

impl mir_int(width: int = 64, signed: bool = True, sized: bool = False) -> MirType {
    sized = sized or width != 64 or not signed;
    return mir_type(
        MirKind.INT, width=width, signed=signed, name="sized" if sized else ""
    );
}

impl mir_float(width: int = 64) -> MirType {
    return mir_type(MirKind.FLOAT, width=width, signed=True);
}

impl mir_str -> MirType {
    return mir_type(MirKind.STR);
}

impl mir_str_ref -> MirType {
    return mir_type(MirKind.STR_REF);
}

impl mir_bytes -> MirType {
    return mir_type(MirKind.BYTES);
}

impl mir_bytearray -> MirType {
    return mir_type(MirKind.BYTEARRAY);
}

impl mir_opt(payload: MirType) -> MirType {
    return mir_type(MirKind.OPT, args=[payload]);
}

impl mir_opt_ref(payload: MirType) -> MirType {
    return mir_type(MirKind.OPT_REF, args=[payload]);
}

impl mir_any -> MirType {
    return mir_type(MirKind.ANY);
}

impl mir_list(elem: MirType) -> MirType {
    return mir_type(MirKind.LIST, args=[elem]);
}

impl mir_list_aos(elem: MirType) -> MirType {
    return mir_type(MirKind.LIST_AOS, args=[elem]);
}

impl mir_dict(key: MirType, value: MirType) -> MirType {
    return mir_type(MirKind.DICT, args=[key, value]);
}

impl mir_set(elem: MirType) -> MirType {
    return mir_type(MirKind.SET, args=[elem]);
}

impl mir_tuple(elems: list[MirType]) -> MirType {
    return mir_type(MirKind.TUPLE, args=elems);
}

impl mir_obj(name: str) -> MirType {
    return mir_type(MirKind.OBJ, name=name);
}

impl mir_osp(kind: str) -> MirType {
    return mir_type(MirKind.OSP, name=kind);
}

impl mir_enum(name: str, underlying: MirType) -> MirType {
    return mir_type(MirKind.ENUM, name=name, args=[underlying]);
}

impl mir_fn(params: list[MirType], ret: MirType) -> MirType {
    return mir_type(MirKind.FN, args=[ret] + params);
}

impl mir_iter(elem: MirType) -> MirType {
    return mir_type(MirKind.ITER, args=[elem]);
}

impl mir_range -> MirType {
    return mir_type(MirKind.RANGE);
}

impl mir_complex -> MirType {
    return mir_type(MirKind.COMPLEX);
}

impl mir_slice -> MirType {
    return mir_type(MirKind.SLICE);
}

impl mir_region -> MirType {
    return mir_type(MirKind.REGION);
}

impl mir_class(name: str) -> MirType {
    return mir_type(MirKind.CLASS, name=name);
}

impl mir_typevar(name: str) -> MirType {
    return mir_type(MirKind.TYPEVAR, name=name);
}

impl mir_c_ptr(elem: MirType) -> MirType {
    return mir_type(MirKind.C_PTR, args=[elem]);
}

impl mir_c_struct(name: str) -> MirType {
    return mir_type(MirKind.C_STRUCT, name=name);
}

impl mir_c_view(elem: MirType) -> MirType {
    return mir_type(MirKind.C_VIEW, args=[elem]);
}

impl mir_c_fn(params: list[MirType], ret: MirType) -> MirType {
    return mir_type(MirKind.C_FN, args=[ret] + params);
}
