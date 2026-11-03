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
    found = err.refusal;
    if found is not None {
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
    if isinstance(t, NeverType) {
        return mir_none();
    }
    if isinstance(t, TypeVarType) {
        bound = env.get(t.name) if env is not None else None;
        if bound is None and t.is_class_type_param and not t.is_self {
            return mir_any();
        }
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
    if isinstance(t, EnumMemberType) and t.enum_class is not None {
        return mir_class_type(t.enum_class.clone_as_instance(), position, site, env);
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
    if isinstance(t, FunctionType)
        and any(lenient_c_slot(p.param_type) for p in t.parameters) {
        params = [
            mir_c_ptr(mir_int(8, False))
                if lenient_c_slot(p.param_type)
                else mir_type_of(p.param_type, MirPosition.C_FIELD, site, env)
            for p in t.parameters
        ];
        ret = mir_c_ptr(mir_int(8, False))
            if lenient_c_slot(t.return_type)
            else mir_type_of(t.return_type, MirPosition.C_FIELD, site, env);
        return mir_c_fn(params, ret);
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
        if not (
            isinstance(member, ClassType)
            and member.shared.class_name in ("NoneType", "None")
        )
    ];
    has_none = len(members) < len(t.types);
    if any(
        isinstance(member, AnyType)
            or (isinstance(member, ClassType) and member.shared.class_name == "object")
        for member in members
    ) {
        return mir_any();
    }
    lowered = [mir_type_of(member, position, site, env) for member in members];
    if not lowered {
        return mir_none();
    }
    shared = lowered[0];
    if all(
        member.kind == MirKind.INT
            and member.width == shared.width
            and member.signed == shared.signed for member in lowered
    ) {
        merged = mir_int(
            shared.width, shared.signed, all(member.is_sized() for member in lowered)
        );
        return mir_opt(merged) if has_none else merged;
    }
    if all(member is shared for member in lowered) {
        return mir_opt(shared) if has_none and shared.kind != MirKind.ANY else shared;
    }
    addresses = [
        member
        for member in lowered
        if member.kind == MirKind.C_PTR
    ];
    if addresses
        and all(member.kind in (MirKind.C_PTR, MirKind.BOOL) for member in lowered) {
        word = addresses[0]
            if all(member is addresses[0] for member in addresses)
            else mir_c_ptr(mir_int(8, False));
        return word;
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
    if t.is_builtin("type") {
        return mir_class_value_type(t, env);
    }
    kind = c_builtin_kind(t);
    if kind == "ptr" {
        return mir_c_ptr(mir_c_elem(c_type_arg(t), site));
    }
    if kind == "PtrView" {
        return mir_c_view(mir_c_elem(c_type_arg(t), site));
    }
    if kind == "VaList" {
        return mir_c_ptr(mir_int(8, False));
    }
    if kind == "Pinned" {
        return mir_c_pin(mir_c_elem(c_type_arg(t), site));
    }
    if t.is_builtin("Task") {
        return mir_ref();
    }
    arch = foreign_struct_of_type(t);
    if arch is not None {
        return mir_c_struct(arch.name.value);
    }
    name = t.shared.class_name;
    scope = t.shared.symbol_table;
    if isinstance(scope, uni.Archetype) and not stub_archetype(scope) {
        if host_only_archetype(scope) {
            return mir_any();
        }
        native = class_type_native_name(t);
        if native and t.is_instantiable() and not t.is_instance() {
            return mir_class("*");
        }
        if native {
            return mir_obj(native);
        }
    }
    if name in ("NoneType", "None") {
        return mir_none();
    }
    if name in ("SupportsIndex", "SupportsInt") and stub_scope(scope) {
        return mir_int();
    }
    if name == "SupportsFloat" and stub_scope(scope) {
        return mir_float();
    }
    if name == "Buffer" and stub_scope(scope) {
        return mir_bytes();
    }
    if name == "Region"
        and not (isinstance(scope, uni.Archetype) and not stub_archetype(scope)) {
        return mir_region();
    }
    if name in ("Node", "Edge", "Walker") and stub_scope(scope) and t.is_instance() {
        return mir_any();
    }
    if name == "object" or (name == "Any" and stub_scope(scope)) {
        return mir_any();
    }
    if name == "range" {
        return mir_range();
    }
    if name in FILE_TYPE_NAMES {
        return mir_file(FILE_TYPE_NAMES[name]);
    }
    if name == "enumerate" {
        args = t.private.type_args if t.private else None;
        if not args {
            raise MirRefused(
                mir_refusal("type", "enumerate without an element type", site)
            );
        }
        return mir_iter(
            mir_tuple([mir_int(), mir_type_of(args[0], MirPosition.VALUE, site, env)])
        );
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
        if members is not None and len(members) == 0 and t.is_instance() {
            return mir_tuple([]);
        }
        if not members {
            raise MirRefused(mir_refusal("type", "tuple without member types", site));
        }
        if len(members) == 2 and isinstance(members[1], UnknownType) {
            return mir_list(mir_type_of(members[0], MirPosition.ELEMENT, site, env));
        }
        return mir_tuple(
            [mir_type_of(member, MirPosition.VALUE, site, env) for member in members]
        );
    }
    if name in ("dict_keys", "dict_values", "dict_items") {
        args = t.private.type_args if t.private else None;
        if not args or len(args) != 2 {
            raise MirRefused(
                mir_refusal("type", f"{name} without element types", site)
            );
        }
        if name == "dict_items" {
            return mir_list(
                mir_tuple(
                    [
                        mir_type_of(args[0], MirPosition.VALUE, site, env),
                        mir_type_of(args[1], MirPosition.VALUE, site, env)
                    ]
                )
            );
        }
        return mir_list(
            mir_type_of(
                args[0] if name == "dict_keys" else args[1],
                MirPosition.ELEMENT,
                site,
                env
            )
        );
    }
    if name in LIST_CLASSES or name in SET_CLASSES or name == "dict" {
        args = t.private.type_args if t.private else None;
        if not args {
            if name == "dict" {
                return mir_dict(mir_any(), mir_any());
            }
            return mir_list(mir_any()) if name in LIST_CLASSES else mir_set(mir_any());
        }
        element_types = [
            mir_type_of(arg, MirPosition.ELEMENT, site, env) for arg in args
        ];
        if name in LIST_CLASSES {
            return mir_list(element_types[0]);
        }
        if name in SET_CLASSES {
            return mir_set(element_types[0]);
        }
        return mir_dict(element_types[0], element_types[1]);
    }
    if name in ("str", "LiteralString") {
        if position in (MirPosition.VALUE, MirPosition.SIGNATURE) {
            return mir_str();
        }
        return mir_str_ref();
    }
    if name == "bytes" {
        return mir_bytes();
    }
    if JAC_TYPE_REGISTRY.is_exception(name) and t.is_instance() {
        if position in (MirPosition.VALUE, MirPosition.SIGNATURE) {
            return mir_str();
        }
        return mir_str_ref();
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

impl stub_archetype(scope: uni.Archetype) -> bool {
    return scope.loc is not None and scope.loc.mod_path.endswith(".pyi");
}

impl stub_scope(scope: (uni.UniScopeNode | None)) -> bool {
    return scope is not None
        and scope.loc is not None
        and scope.loc.mod_path.endswith(".pyi");
}

impl mir_class_value_type(
    t: ClassType, env: (dict[str, TypeBase] | None) = None
) -> MirType {
    return mir_class("*");
}

impl lenient_c_slot(t: (TypeBase | None)) -> bool {
    return isinstance(t, AnyType) and t.is_foreign and not t.foreign_scalar;
}

impl host_only_archetype(arch: uni.Archetype) -> bool {
    if not native_unit_compile_active() {
        return False;
    }
    owner = arch.find_parent_of_type(uni.Module);
    if owner is None or not owner.loc.mod_path.endswith(".jac") {
        return False;
    }
    return host_only_path(owner.loc.mod_path);
}

impl host_only_path(path: str) -> bool {
    if not native_unit_compile_active() or not path.endswith(".jac") {
        return False;
    }
    known = _HOST_ONLY_UNITS.get(path);
    if known is None {
        known = not native_unit(path, True);
        _HOST_ONLY_UNITS[path] = known;
    }
    return known;
}
