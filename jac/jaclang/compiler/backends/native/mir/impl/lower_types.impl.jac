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
    return mir_int(shape.width, shape.signed);
}

impl mir_class_type(
    t: ClassType, position: MirPosition, site: (uni.UniNode | None) = None
) -> MirType {
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
        return mir_int(shape.width, shape.signed);
    }
    if name == "str" {
        return mir_str() if position == MirPosition.VALUE else mir_str_ref();
    }
    raise MirRefused(mir_refusal("type", name, site));
}
