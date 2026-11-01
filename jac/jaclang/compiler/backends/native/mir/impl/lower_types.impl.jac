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
    t: (TypeBase | None),
    position: MirPosition,
    site: (uni.UniNode | None) = None,
    env: (dict[str, TypeBase] | None) = None
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
    if isinstance(t, TypeVarType) {
        bound = env.get(t.name) if env is not None else None;
        if bound is None {
            raise MirRefused(
                mir_refusal(
                    "type",
                    f"type variable {t.name}",
                    site,
                    "A generic value is native only inside an instantiation, where its call solved every type argument."
                )
            );
        }
        return mir_type_of(bound, position, site, env);
    }
    if isinstance(t, ClassType) {
        return mir_class_type(t, position, site, env);
    }
    if isinstance(t, UnionType) {
        return mir_union_type(t, position, site, env);
    }
    if isinstance(t, AnyType) and t.is_foreign and t.foreign_scalar {
        return mir_class_type_named(t.foreign_scalar, site);
    }
    if isinstance(t, AnyType) and not t.is_foreign {
        return mir_any();
    }
    if isinstance(t, FunctionType) and position == MirPosition.C_FIELD {
        params = [
            mir_type_of(p.param_type, MirPosition.C_FIELD, site, env)
            for p in t.parameters
        ];
        return mir_c_fn(
            params, mir_type_of(t.return_type, MirPosition.C_FIELD, site, env)
        );
    }
    if isinstance(t, FunctionType) {
        params = [
            mir_type_of(p.param_type, MirPosition.VALUE, site, env)
            for p in t.parameters
        ];
        return mir_fn(
            params, mir_type_of(t.return_type, MirPosition.SIGNATURE, site, env)
        );
    }
    raise MirRefused(mir_refusal("type", str(t), site));
}

impl mir_union_type(
    t: UnionType,
    position: MirPosition,
    site: (uni.UniNode | None) = None,
    env: (dict[str, TypeBase] | None) = None
) -> MirType {
    members = [
        member
        for member in t.types
        if not (isinstance(member, ClassType) and member.shared.class_name in ("NoneType", "None"))
    ];
    has_none = len(members) < len(t.types);
    lowered = [mir_type_of(member, position, site, env) for member in members];
    if not lowered {
        return mir_none();
    }
    shared = lowered[0];
    if all(member is shared for member in lowered) {
        return mir_opt(shared) if has_none and shared.kind != MirKind.ANY else shared;
    }
    for member in lowered {
        if member.kind not in ANY_BOXABLE {
            raise MirRefused(
                mir_refusal(
                    "type",
                    str(t),
                    site,
                    f"A union whose members share no representation is boxed as `any`, and a {member.render()} has no `any` box."
                )
            );
        }
    }
    return mir_any();
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
    t: ClassType,
    position: MirPosition,
    site: (uni.UniNode | None) = None,
    env: (dict[str, TypeBase] | None) = None
) -> MirType {
    if is_enum_class_type(t) {
        name = class_type_native_name(t) or t.shared.class_name;
        if t.is_instantiable() and not t.is_instance() {
            return mir_class(name);
        }
        return mir_enum(name, mir_int());
    }
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
    if name == "object" {
        return mir_any();
    }
    if name == "range" {
        return mir_range();
    }
    if name in ITERATOR_CLASSES {
        args = t.private.type_args if t.private else None;
        if not args {
            raise MirRefused(
                mir_refusal(
                    "type",
                    f"{name} without an element type",
                    site,
                    "Native iterators need their element type; annotate it, e.g. `Iterator[int]`."
                )
            );
        }
        return mir_iter(mir_type_of(args[0], MirPosition.ELEMENT, site, env));
    }
    if name == "Iterable" {
        raise MirRefused(
            mir_refusal(
                "type",
                "Iterable",
                site,
                "An Iterable may be iterated more than once, which no single native form keeps; annotate a concrete container or `Iterator[T]`."
            )
        );
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
        return mir_tuple(
            [mir_type_of(member, MirPosition.VALUE, site, env) for member in members]
        );
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
        members = [mir_type_of(arg, MirPosition.ELEMENT, site, env) for arg in args];
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
