impl mir_refusal(
    kind: str,
    name: str,
    site: (uni.UniNode | None) = None,
    help: (str | None) = None,
    code: str = "E5092"
) -> NativeRefusal {
    return NativeRefusal(kind=kind, name=name, site=site, help=help, code=code);
}

impl refusal_of(err: MirRefused) -> NativeRefusal {
    found = err.args[0] if err.args else None;
    if isinstance(found, NativeRefusal) {
        return found;
    }
    return mir_refusal("construct", str(err));
}

impl mir_type_of(
    t: (TypeBase | None), position: MirPosition, site: (uni.UniNode | None) = None
) -> MirType {
    if t is None {
        raise MirRefused(
            mir_refusal(
                "value",
                "untyped",
                site,
                "The type checker recorded no type for this value; native code needs every value typed."
            )
        );
    }
    if isinstance(t, ClassType) {
        return mir_class_type(t, position, site);
    }
    if isinstance(t, UnionType) {
        members = [
            member
            for member in t.types
            if not (isinstance(member, ClassType) and member.shared.class_name in ("NoneType", "None"))
        ];
        if len(members) == 1 and len(members) < len(t.types) {
            return mir_opt(mir_type_of(members[0], position, site));
        }
        raise MirRefused(
            mir_refusal(
                "type",
                str(t),
                site,
                "Native code holds an optional (T | None) union so far; other unions need a shared representation."
            )
        );
    }
    if isinstance(t, AnyType) and t.is_foreign and t.foreign_scalar {
        return mir_class_type_named(t.foreign_scalar, site);
    }
    if isinstance(t, FunctionType) and position == MirPosition.C_FIELD {
        params = [
            mir_type_of(p.param_type, MirPosition.C_FIELD, site) for p in t.parameters
        ];
        return mir_c_fn(params, mir_type_of(t.return_type, MirPosition.C_FIELD, site));
    }
    if isinstance(t, FunctionType) {
        params = [
            mir_type_of(p.param_type, MirPosition.VALUE, site) for p in t.parameters
        ];
        return mir_fn(params, mir_type_of(t.return_type, MirPosition.SIGNATURE, site));
    }
    raise MirRefused(mir_refusal("type", str(t), site));
}

impl mir_class_type_named(name: str, site: (uni.UniNode | None) = None) -> MirType {
    if name == "bool" {
        return mir_bool();
    }
    shape = shape_of(name);
    if shape is None {
        raise MirRefused(mir_refusal("conversion", name, site));
    }
    if shape.is_float {
        return mir_float(shape.width);
    }
    return mir_int(shape.width, shape.signed, shape.sized);
}

impl mir_class_type(
    t: ClassType, position: MirPosition, site: (uni.UniNode | None) = None
) -> MirType {
    kind = c_builtin_kind(t);
    if kind == "ptr" {
        return mir_c_ptr(mir_c_elem(c_type_arg(t), site));
    }
    if kind == "PtrView" {
        return mir_c_view(mir_c_elem(c_type_arg(t), site));
    }
    arch = foreign_struct_of_type(t);
    if arch is not None {
        return mir_c_struct(arch.name.value);
    }
    if isinstance(t.shared.symbol_table, uni.Archetype) {
        native = class_type_native_name(t);
        if native {
            return mir_obj(native);
        }
    }
    name = t.shared.class_name;
    if name in ("NoneType", "None") {
        return mir_none();
    }
    if name == "bool" {
        return mir_bool();
    }
    shape = shape_of(name);
    if shape is not None {
        if shape.is_float {
            return mir_float(shape.width);
        }
        return mir_int(shape.width, shape.signed, shape.sized);
    }
    if name == "tuple" {
        members = t.private.type_args if t.private else None;
        if not members {
            raise MirRefused(mir_refusal("type", "tuple without member types", site));
        }
        return mir_tuple([mir_type_of(member, MirPosition.VALUE, site) for member in members]);
    }
    if name in ("list", "dict", "set") {
        args = t.private.type_args if t.private else None;
        if not args {
            raise MirRefused(
                mir_refusal(
                    "type",
                    f"{name} without element types",
                    site,
                    "Native containers need their element types; annotate the value."
                )
            );
        }
        members = [mir_type_of(arg, MirPosition.ELEMENT, site) for arg in args];
        if name == "list" {
            return mir_list(members[0]);
        }
        if name == "set" {
            return mir_set(members[0]);
        }
        return mir_dict(members[0], members[1]);
    }
    if name == "str" {
        if position in (MirPosition.VALUE, MirPosition.SIGNATURE) {
            return mir_str();
        }
        return mir_str_ref();
    }
    if name == "bytes" {
        return mir_bytes();
    }
    if name == "bytearray" {
        return mir_bytearray();
    }
    raise MirRefused(mir_refusal("type", name, site));
}

impl mir_c_elem(t: (TypeBase | None), site: (uni.UniNode | None) = None) -> MirType {
    if t is None {
        return mir_int(8, False);
    }
    if isinstance(t, ClassType) and t.shared.class_name in ("object", "NoneType") {
        return mir_int(8, False);
    }
    return mir_type_of(t, MirPosition.C_FIELD, site);
}

impl mir_spec_type(spec: str) -> MirType {
    if spec == "none" {
        return mir_none();
    }
    if spec == "f64" {
        return mir_float(64);
    }
    if spec.startswith("i") and spec[1:].isdigit() {
        return mir_int(int(spec[1:]), True, True);
    }
    raise MirRefused(mir_refusal("intrinsic operand", spec));
}
