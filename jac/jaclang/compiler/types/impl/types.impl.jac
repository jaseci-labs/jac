impl ModuleType.symbol_table.getter -> (SymbolTable | None) {
    c = self._acc_cache;
    if (c is not None) and ("symbol_table" in c) {
        return c["symbol_table"];
    }
    found = [self->:DeclScopeOf:->];
    val = found[0] if found else None;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["symbol_table"] = val;
    return val;
}

impl ModuleType.symbol_table.setter(symbol_table: (SymbolTable | None)) -> None {
    del [edge self->:DeclScopeOf:->];
    if symbol_table is not None {
        self +>:DeclScopeOf:+> symbol_table;
    }
    c = self._acc_cache;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["symbol_table"] = symbol_table;
}

impl TypeVarType.bound.getter -> (TypeBase | None) {
    c = self._acc_cache;
    if (c is not None) and ("bound" in c) {
        return c["bound"];
    }
    found = [self->:BoundOf:->];
    val = found[0] if found else None;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["bound"] = val;
    return val;
}

impl TypeVarType.bound.setter(bound: (TypeBase | None)) -> None {
    del [edge self->:BoundOf:->];
    if bound is not None {
        self +>:BoundOf:+> bound;
    }
    c = self._acc_cache;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["bound"] = bound;
}

impl TypeVarType.constraints.getter -> list[TypeBase] {
    c = self._acc_cache;
    if (c is not None) and ("constraints" in c) {
        return c["constraints"];
    }
    val = [self->:ConstraintOf:->][?:TypeBase];
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["constraints"] = val;
    return val;
}

impl TypeVarType.constraints.setter(constraints: (list[TypeBase] | None)) -> None {
    del [edge self->:ConstraintOf:->];
    for t in (constraints or []) {
        self +>:ConstraintOf:+> t;
    }
    c = self._acc_cache;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["constraints"] = `list(constraints or []);
}

impl ClassDetailsShared.symbol_table.getter -> SymbolTable {
    c = self._acc_cache;
    if (c is not None) and ("symbol_table" in c) {
        return c["symbol_table"];
    }
    val = [self->:DeclScopeOf:->][0];
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["symbol_table"] = val;
    return val;
}

impl ClassDetailsShared.symbol_table.setter(symbol_table: SymbolTable) -> None {
    del [edge self->:DeclScopeOf:->];

    if symbol_table is not None {
        self +>:DeclScopeOf:+> symbol_table;
    }
    c = self._acc_cache;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["symbol_table"] = symbol_table;
}

impl ClassDetailsShared.mro.getter -> list[ClassType] {
    if self._mro_cache is None {
        self._mro_cache = [self->:MroOf:->];
    }
    return self._mro_cache;
}

impl ClassDetailsShared.mro.setter(mro: list[ClassType]) -> None {
    del [edge self->:MroOf:->];
    for t in (mro or []) {
        self +>:MroOf:+> t;
    }
    self._mro_cache = `list(mro or []);
}

impl ClassDetailsShared.type_params.getter -> list[TypeVarType] {
    c = self._acc_cache;
    if (c is not None) and ("type_params" in c) {
        return c["type_params"];
    }
    val = [self->:TypeParamOf:->][?:TypeVarType];
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["type_params"] = val;
    return val;
}

impl ClassDetailsShared.type_params.setter(
    type_params: (list[TypeVarType] | None)
) -> None {
    del [edge self->:TypeParamOf:->];
    for t in (type_params or []) {
        self +>:TypeParamOf:+> t;
    }
    c = self._acc_cache;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["type_params"] = `list(type_params or []);
}

impl ClassDetailsShared.base_classes.getter -> list[TypeBase] {
    c = self._acc_cache;
    if (c is not None) and ("base_classes" in c) {
        return c["base_classes"];
    }
    val = [self->:BaseOf:->][?:TypeBase];
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["base_classes"] = val;
    return val;
}

impl ClassDetailsShared.base_classes.setter(
    base_classes: (list[TypeBase] | None)
) -> None {
    del [edge self->:BaseOf:->];
    for t in (base_classes or []) {
        self +>:BaseOf:+> t;
    }
    c = self._acc_cache;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["base_classes"] = `list(base_classes or []);
}

impl ClassDetailsShared.enum_value_type.getter -> (TypeBase | None) {
    c = self._acc_cache;
    if (c is not None) and ("enum_value_type" in c) {
        return c["enum_value_type"];
    }
    found = [self->:ValueTypeOf:->];
    val = found[0] if found else None;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["enum_value_type"] = val;
    return val;
}

impl ClassDetailsShared.enum_value_type.setter(
    enum_value_type: (TypeBase | None)
) -> None {
    del [edge self->:ValueTypeOf:->];
    if enum_value_type is not None {
        self +>:ValueTypeOf:+> enum_value_type;
    }
    c = self._acc_cache;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["enum_value_type"] = enum_value_type;
}

impl ClassDetailsShared.typeddict_fields.getter -> dict[str, TypeBase] {
    d: dict[str, TypeBase] = {};
    for ea in [edge self->:TypeMemberOf:->] {
        d[ea.name] = getattr(ea, "__jac__").target.archetype;
    }
    return d;
}

impl ClassDetailsShared.typeddict_fields.setter(
    typeddict_fields: (dict[str, TypeBase] | None)
) -> None {
    del [edge self->:TypeMemberOf:->];
    for (k, v) in (typeddict_fields or {}).items() {
        self +>:TypeMemberOf(name=k):+> v;
    }
}

impl ClassDetailsShared.enum_members.getter -> dict[str, EnumMemberInfo] {
    d: dict[str, EnumMemberInfo] = {};
    for ea in [edge self->:EnumMemberOf:->] {
        d[ea.name] = getattr(ea, "__jac__").target.archetype;
    }
    return d;
}

impl ClassDetailsShared.enum_members.setter(
    enum_members: (dict[str, EnumMemberInfo] | None)
) -> None {
    del [edge self->:EnumMemberOf:->];
    for (k, v) in (enum_members or {}).items() {
        self +>:EnumMemberOf(name=k):+> v;
    }
}

impl ClassDetailsShared.init(
    *,
    class_name: str,
    symbol_table: SymbolTable,
    mro: (list[ClassType] | None) = None,
    type_params: (list[TypeVarType] | None) = None,
    base_classes: (list[TypeBase] | None) = None,
    is_builtin_class: bool = False,
    is_from_stdlib_stub: bool = False,
    is_data_class: bool = False,
    is_namedtuple: bool = False,
    is_typeddict: bool = False,
    typeddict_fields: (dict[str, TypeBase] | None) = None,
    is_root_class: bool = False,
    is_enum_class: bool = False,
    enum_value_type: (TypeBase | None) = None,
    enum_members: (dict[str, EnumMemberInfo] | None) = None,
    _identity_key: (tuple[str, int, int, str] | None) = None,
    _derived_special_types: (dict[str, ClassType] | None) = None,
    ct_params: (list[str] | None) = None
) -> None {
    self.class_name = class_name;
    self.is_builtin_class = is_builtin_class;
    self.is_from_stdlib_stub = is_from_stdlib_stub;
    self.is_data_class = is_data_class;
    self.is_namedtuple = is_namedtuple;
    self.is_typeddict = is_typeddict;
    self.is_root_class = is_root_class;
    self.is_enum_class = is_enum_class;
    self._identity_key = _identity_key;
    self._derived_special_types = _derived_special_types;
    self.ct_params = ct_params;
    self.symbol_table = symbol_table;
    self.mro = [];
    self.type_params = type_params;
    self.base_classes = base_classes;
    self.typeddict_fields = typeddict_fields;
    self.enum_value_type = enum_value_type;
    self.enum_members = enum_members;
}

impl ClassDetailsPrivate.init(
    *,
    type_args: (list[TypeBase] | None) = None,
    ct_args: (dict[str, any] | None) = None,
    alias_name: (str | None) = None,
    literal_value: (str | int | bool | None) = None,
    distinct_key: (str | None) = None
) -> None {
    self.ct_args = ct_args;
    self.alias_name = alias_name;
    self.literal_value = literal_value;
    self.distinct_key = distinct_key;
    self.type_args = type_args;
}

impl ClassDetailsPrivate.type_args.getter -> list[TypeBase] {
    if self._targs_cache is None {
        self._targs_cache = [self->:TypeArgOf:->][?:TypeBase];
    }
    return self._targs_cache;
}

impl ClassDetailsPrivate.type_args.setter(type_args: (list[TypeBase] | None)) -> None {
    del [edge self->:TypeArgOf:->];
    for t in (type_args or []) {
        self +>:TypeArgOf:+> t;
    }
    self._targs_cache = `list(type_args or []);
}

impl ClassType._shared.getter -> (ClassDetailsShared | None) {
    c = self._acc_cache;
    if (c is not None) and ("_shared" in c) {
        return c["_shared"];
    }
    found = [self->:SharedOf:->];
    val = found[0] if found else None;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["_shared"] = val;
    return val;
}

impl ClassType._shared.setter(_shared: (ClassDetailsShared | None)) -> None {
    del [edge self->:SharedOf:->];
    if _shared is not None {
        self +>:SharedOf:+> _shared;
    }
    c = self._acc_cache;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["_shared"] = _shared;
}

impl ClassType.private.getter -> ClassDetailsPrivate {
    c = self._acc_cache;
    if (c is not None) and ("private" in c) {
        return c["private"];
    }
    val = [self->:PrivOf:->][0];
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["private"] = val;
    return val;
}

impl ClassType.private.setter(private: ClassDetailsPrivate) -> None {
    del [edge self->:PrivOf:->];
    self +>:PrivOf:+> private;
    c = self._acc_cache;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["private"] = private;
}

impl ClassType.init(
    *,
    _shared: (ClassDetailsShared | None) = None,
    private: (ClassDetailsPrivate | None) = None,
    flags: TypeFlags = TypeFlags.Null
) -> None {
    self.flags = flags;
    self._shared = _shared;
    self.private = private or ClassDetailsPrivate();
}

impl ModuleType.init(
    *,
    mod_name: str = "",
    file_uri: Path = Path(""),
    symbol_table: (SymbolTable | None) = None,
    is_external: bool = False,
    flags: TypeFlags = TypeFlags.Null
) -> None {
    self.mod_name = mod_name;
    self.file_uri = file_uri;
    self.is_external = is_external;
    self.flags = flags;
    self.symbol_table = symbol_table;
}

impl TypeVarType.init(
    *,
    name: str = "",
    is_covariant: bool = False,
    is_contravariant: bool = False,
    is_self: bool = False,
    is_param_spec: bool = False,
    is_class_type_param: bool = False,
    bound: (TypeBase | None) = None,
    constraints: (list[TypeBase] | None) = None,
    flags: TypeFlags = TypeFlags.Null
) -> None {
    self.name = name;
    self.is_covariant = is_covariant;
    self.is_contravariant = is_contravariant;
    self.is_self = is_self;
    self.is_param_spec = is_param_spec;
    self.is_class_type_param = is_class_type_param;
    self.flags = flags;
    self.bound = bound;
    self.constraints = constraints;
}

impl Parameter.init(
    *,
    name: str,
    category: (ParameterCategory | None),
    param_type: (TypeBase | None),
    default_value: (Expr | None) = None,
    is_self: bool = False,
    is_cls: bool = False,
    param_kind: ParamKind = ParamKind.NORMAL,
    has_default: bool = False,
    is_comptime: bool = False
) -> None {
    self.name = name;
    self.category = category;
    self.is_self = is_self;
    self.is_cls = is_cls;
    self.param_kind = param_kind;
    self.has_default = has_default;
    self.is_comptime = is_comptime;
    self.param_type = param_type;
    self.default_value = default_value;
}

impl Parameter.param_type.getter -> (TypeBase | None) {
    c = self._acc_cache;
    if (c is not None) and ("param_type" in c) {
        return c["param_type"];
    }
    found = [self->:ParamTypeOf:->];
    val = found[0] if found else None;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["param_type"] = val;
    return val;
}

impl Parameter.param_type.setter(param_type: (TypeBase | None)) -> None {
    del [edge self->:ParamTypeOf:->];
    if param_type is not None {
        self +>:ParamTypeOf:+> param_type;
    }
    c = self._acc_cache;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["param_type"] = param_type;
}

impl Parameter.default_value.getter -> (Expr | None) {
    c = self._acc_cache;
    if (c is not None) and ("default_value" in c) {
        return c["default_value"];
    }
    found = [self->:ParamDefaultOf:->];
    val = found[0] if found else None;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["default_value"] = val;
    return val;
}

impl Parameter.default_value.setter(default_value: (Expr | None)) -> None {
    del [edge self->:ParamDefaultOf:->];
    if default_value is not None {
        self +>:ParamDefaultOf:+> default_value;
    }
    c = self._acc_cache;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["default_value"] = default_value;
}

impl FunctionType.init(
    *,
    func_name: str = "",
    return_type: (TypeBase | None) = None,
    parameters: (list[Parameter] | None) = None,
    function_flags: int = 0,
    type_params: (list[TypeVarType] | None) = None,
    is_async: bool = False,
    type_guard: (TypeBase | None) = None,
    type_guard_is_strict: bool = False,
    flags: TypeFlags = TypeFlags.Null
) -> None {
    self.func_name = func_name;
    self.function_flags = function_flags;
    self.is_async = is_async;
    self.type_guard_is_strict = type_guard_is_strict;
    self.flags = flags;
    self.return_type = return_type;
    self.parameters = parameters or [];
    self.type_params = type_params;
    self.type_guard = type_guard;
}

impl FunctionType.return_type.getter -> (TypeBase | None) {
    c = self._acc_cache;
    if (c is not None) and ("return_type" in c) {
        return c["return_type"];
    }
    found = [self->:ReturnsOf:->];
    val = found[0] if found else None;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["return_type"] = val;
    return val;
}

impl FunctionType.return_type.setter(return_type: (TypeBase | None)) -> None {
    del [edge self->:ReturnsOf:->];
    if return_type is not None {
        self +>:ReturnsOf:+> return_type;
    }
    c = self._acc_cache;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["return_type"] = return_type;
}

impl FunctionType.parameters.getter -> list[Parameter] {
    if self._params_cache is None {
        self._params_cache = [self->:ParamOf:->];
    }
    return self._params_cache;
}

impl FunctionType.parameters.setter(parameters: (list[Parameter] | None)) -> None {
    del [edge self->:ParamOf:->];
    for t in (parameters or []) {
        self +>:ParamOf:+> t;
    }
    self._params_cache = `list(parameters or []);
}

impl FunctionType.type_params.getter -> list[TypeVarType] {
    c = self._acc_cache;
    if (c is not None) and ("type_params" in c) {
        return c["type_params"];
    }
    val = [self->:TypeParamOf:->][?:TypeVarType];
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["type_params"] = val;
    return val;
}

impl FunctionType.type_params.setter(type_params: (list[TypeVarType] | None)) -> None {
    del [edge self->:TypeParamOf:->];
    for t in (type_params or []) {
        self +>:TypeParamOf:+> t;
    }
    c = self._acc_cache;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["type_params"] = `list(type_params or []);
}

impl FunctionType.type_guard.getter -> (TypeBase | None) {
    c = self._acc_cache;
    if (c is not None) and ("type_guard" in c) {
        return c["type_guard"];
    }
    found = [self->:GuardOf:->];
    val = found[0] if found else None;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["type_guard"] = val;
    return val;
}

impl FunctionType.type_guard.setter(type_guard: (TypeBase | None)) -> None {
    del [edge self->:GuardOf:->];
    if type_guard is not None {
        self +>:GuardOf:+> type_guard;
    }
    c = self._acc_cache;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["type_guard"] = type_guard;
}

impl OverloadedType.overloads.getter -> list[FunctionType] {
    c = self._acc_cache;
    if (c is not None) and ("overloads" in c) {
        return c["overloads"];
    }
    val = [self->:OverloadOf:->][?:FunctionType];
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["overloads"] = val;
    return val;
}

impl OverloadedType.overloads.setter(overloads: (list[FunctionType] | None)) -> None {
    del [edge self->:OverloadOf:->];
    for t in (overloads or []) {
        self +>:OverloadOf:+> t;
    }
    c = self._acc_cache;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["overloads"] = `list(overloads or []);
}

impl OverloadedType.init(
    *, overloads: (list[FunctionType] | None) = None, flags: TypeFlags = TypeFlags.Null
) -> None {
    self.flags = flags;
    self.overloads = overloads;
}

impl UnionType.types.getter -> list[TypeBase] {
    c = self._acc_cache;
    if (c is not None) and ("types" in c) {
        return c["types"];
    }
    val = [self->:UnionMemberOf:->][?:TypeBase];
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["types"] = val;
    return val;
}

impl UnionType.types.setter(types: (list[TypeBase] | None)) -> None {
    del [edge self->:UnionMemberOf:->];
    for t in (types or []) {
        self +>:UnionMemberOf:+> t;
    }
    c = self._acc_cache;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["types"] = `list(types or []);
}

impl UnionType.init(
    *, types: (list[TypeBase] | None) = None, flags: TypeFlags = TypeFlags.Null
) -> None {
    self.flags = flags;
    flattened: list[TypeBase] = [];
    for ty in (types or []) {
        if isinstance(ty, UnionType) {
            flattened.extend(ty.types or []);
        } else {
            flattened.append(ty);
        }
    }
    self.types = flattened;
}

impl EnumMemberInfo.value_type.getter -> (TypeBase | None) {
    c = self._acc_cache;
    if (c is not None) and ("value_type" in c) {
        return c["value_type"];
    }
    found = [self->:ValueTypeOf:->];
    val = found[0] if found else None;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["value_type"] = val;
    return val;
}

impl EnumMemberInfo.value_type.setter(value_type: (TypeBase | None)) -> None {
    del [edge self->:ValueTypeOf:->];
    if value_type is not None {
        self +>:ValueTypeOf:+> value_type;
    }
    c = self._acc_cache;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["value_type"] = value_type;
}

impl EnumMemberInfo.init(
    *,
    member_name: str,
    value_type: (TypeBase | None) = None,
    literal_value: (int | str | None) = None
) -> None {
    self.member_name = member_name;
    self.literal_value = literal_value;
    self.value_type = value_type;
}

impl EnumMemberType.enum_class.getter -> (ClassType | None) {
    c = self._acc_cache;
    if (c is not None) and ("enum_class" in c) {
        return c["enum_class"];
    }
    found = [self->:EnumClassOf:->];
    val = found[0] if found else None;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["enum_class"] = val;
    return val;
}

impl EnumMemberType.enum_class.setter(enum_class: (ClassType | None)) -> None {
    del [edge self->:EnumClassOf:->];
    if enum_class is not None {
        self +>:EnumClassOf:+> enum_class;
    }
    c = self._acc_cache;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["enum_class"] = enum_class;
}

impl EnumMemberType.member_info.getter -> (EnumMemberInfo | None) {
    c = self._acc_cache;
    if (c is not None) and ("member_info" in c) {
        return c["member_info"];
    }
    found = [self->:MemberInfoOf:->];
    val = found[0] if found else None;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["member_info"] = val;
    return val;
}

impl EnumMemberType.member_info.setter(member_info: (EnumMemberInfo | None)) -> None {
    del [edge self->:MemberInfoOf:->];
    if member_info is not None {
        self +>:MemberInfoOf:+> member_info;
    }
    c = self._acc_cache;
    if c is None {
        c = {};
        self._acc_cache = c;
    }
    c["member_info"] = member_info;
}

impl EnumMemberType.init(
    *,
    enum_class: (ClassType | None) = None,
    member_info: (EnumMemberInfo | None) = None,
    flags: TypeFlags = TypeFlags.Null
) -> None {
    self.flags = flags;
    self.enum_class = enum_class;
    self.member_info = member_info;
}

impl UnionType.__str__ -> str {
    if not self.types or len(self.types) == 0 {
        return "<Union>";
    }
    return " | ".join(str(ty) for ty in self.types);
}

impl UnknownType.__str__ -> str {
    return "<Unknown>";
}

impl NeverType.__str__ -> str {
    return "<Never>";
}

impl AnyType.__str__ -> str {
    return "<any>";
}

impl ModuleType.__str__ -> str {
    if self.mod_name {
        return f"<module {self.mod_name}>";
    }
    if self.file_uri and str(self.file_uri) != "." {
        return f"<module {self.file_uri}>";
    }
    return "<module>";
}

impl TypeVarType.__str__ -> str {
    if self.name {
        return self.name;
    }
    return "<TypeVar>";
}

impl Parameter.clone -> Parameter {
    return Parameter(
        name=self.name,
        category=self.category,
        param_type=self.param_type,
        default_value=self.default_value,
        is_self=self.is_self,
        is_cls=self.is_cls,
        param_kind=self.param_kind,
        has_default=self.has_default,
        is_comptime=self.is_comptime
    );
}

impl Parameter.is_optional.getter -> bool {
    return self.default_value is not None or self.has_default;
}

impl FunctionType.specialize(class_type: ClassType) -> FunctionType {
    import from jaclang.compiler.types.type_utils {
        apply_solved_type_vars,
        build_type_var_solution
    }

    solution = build_type_var_solution(class_type);

    clone = FunctionType(
        func_name=self.func_name,
        return_type=self.return_type,
        parameters=[param.clone() for param in self.parameters],
        type_params=self.type_params,
        is_async=self.is_async,
        type_guard=self.type_guard,
        type_guard_is_strict=self.type_guard_is_strict,
    );

    for param in clone.parameters {
        if param.param_type {
            param.param_type = apply_solved_type_vars(
                param.param_type, solution, class_type
            );
        }
    }

    if clone.return_type {
        clone.return_type = apply_solved_type_vars(
            clone.return_type, solution, class_type
        );
    }

    return clone;
}

impl FunctionType.specialize_func_type_vars(
    solution: dict[(str, TypeBase)]
) -> FunctionType {
    import from jaclang.compiler.types.type_utils { apply_solved_type_vars }

    clone = FunctionType(
        func_name=self.func_name,
        return_type=self.return_type,
        parameters=[param.clone() for param in self.parameters],
        function_flags=self.function_flags,
        type_params=self.type_params,
        is_async=self.is_async,
        type_guard=self.type_guard,
        type_guard_is_strict=self.type_guard_is_strict,
    );

    for param in clone.parameters {
        if param.param_type {
            param.param_type = apply_solved_type_vars(param.param_type, solution);
        }
    }

    if clone.return_type {
        clone.return_type = apply_solved_type_vars(clone.return_type, solution);
    }

    return clone;
}

impl FunctionType.__str__ -> str {
    if self.is_from_callable_annotation() {
        if self.is_gradual_callable_form() {
            return_type_str = str(self.return_type) if self.return_type else "Unknown";
            return f"Callable[..., {return_type_str}]";
        }

        param_type_strs: list[str] = [];
        for param in self.parameters or [] {
            if param.param_type {
                param_type_strs.append(str(param.param_type));
            } else {
                param_type_strs.append("Unknown");
            }
        }
        params_str = ", ".join(param_type_strs);
        return_type_str = str(self.return_type) if self.return_type else "Unknown";
        return f"Callable[[{params_str}], {return_type_str}]";
    }

    param_strs: list[str] = [];
    for param in self.parameters or [] {
        param_str = param.name;
        if param.param_type {
            param_str = f"{param_str}: {param.param_type}";
        }
        if param.is_optional {
            param_str = f"{param_str} = ...";
        }
        param_strs.append(param_str);
    }
    params_str = ", ".join(param_strs);
    func_name = self.func_name or "<anonymous>";
    return_type_str = f" -> {self.return_type}" if self.return_type else "";
    return f"<function {func_name}({params_str}){return_type_str}>";
}

impl OverloadedType.__str__ -> str {
    count = len(self.overloads) if self.overloads else 0;
    return f"<overload {count} overloads>";
}

def _class_scope_category(scope: any) -> any {
    import from jaclang.compiler.frontend.unitree { Archetype }
    if isinstance(scope, Archetype) {
        return scope.sym_category;
    }
    import from jaclang.compiler.types.stubcat.reader { CatScope }
    if isinstance(scope, CatScope) and scope.cat_owner_sym is not None {
        return scope.cat_owner_sym.sym_type;
    }
    return None;
}

impl ClassType.is_node_type -> bool {
    import from jaclang.compiler.frontend.constant { SymbolType }
    if self.shared.is_root_class {
        return True;
    }
    return _class_scope_category(self.shared.symbol_table) == SymbolType.NODE_ARCH;
}

impl ClassType.is_edge_type -> bool {
    import from jaclang.compiler.frontend.constant { SymbolType }
    return _class_scope_category(self.shared.symbol_table) == SymbolType.EDGE_ARCH;
}

impl ClassType.is_walker_type -> bool {
    import from jaclang.compiler.frontend.constant { SymbolType }
    return _class_scope_category(self.shared.symbol_table) == SymbolType.WALKER_ARCH;
}

impl ClassType.is_data_class -> bool {
    return self.shared.is_data_class;
}

impl ClassType.is_namedtuple -> bool {
    return self.shared.is_namedtuple;
}

impl ClassType.is_typeddict -> bool {
    return self.shared.is_typeddict;
}

impl ClassType.is_enum_class -> bool {
    return self.shared.is_enum_class;
}

impl ClassType.is_builtin(class_name: (str | list[str] | None) = None) -> bool {
    if not self.shared.is_builtin_class {
        return False;
    }
    if class_name is None {
        return True;
    }
    if isinstance(class_name, str) {
        return self.shared.class_name == class_name;
    }
    return self.shared.class_name in class_name;
}

impl ClassType.lookup_member_symbol(
    member: str, r_overloaded: list | None = None
) -> (Symbol | None) {
    import from jaclang.compiler.frontend.unitree {
        Ability,
        Archetype,
        Assignment,
        AtomTrailer,
        FuncSignature,
        ParamVar
    }
    import from jaclang.compiler.types.type_utils { collect_member_syms }
    for cls in self.shared.mro {
        all_syms = collect_member_syms(cls.shared.symbol_table, member);
        if all_syms {
            if r_overloaded is not None and len(all_syms) > 1 {
                r_overloaded.extend(all_syms[1:]);
            }
            return all_syms[0];
        }
    }

    for cls in self.shared.mro {
        arch = cls.shared.symbol_table;
        if not isinstance(arch, Archetype) {
            continue;
        }
        is_class = arch.arch_type.name == 'KW_CLASS';

        for method_name in ('init', '__post_init__') {
            method_sym = arch.lookup(method_name, deep=False);
            if not method_sym or not isinstance(method_sym.decl.name_of, Ability) {
                continue;
            }
            method_ability = method_sym.decl.name_of;

            if (
                isinstance(method_ability.signature, FuncSignature)
                and method_ability.signature.params
            ) {
                for param in method_ability.signature.params {
                    if not isinstance(param, ParamVar) {
                        continue;
                    }
                    if param.name.value == member and param.name.value != 'self' {
                        arch.def_insert(param.name, access_spec=arch);
                        return arch.lookup(member, deep=False);
                    }
                }
            }

            for trailer in method_ability.get_all_sub_nodes(AtomTrailer) {
                if not (trailer.parent and isinstance(trailer.parent, Assignment)) {
                    continue;
                }
                if trailer != trailer.parent.target[0] {
                    continue;
                }

                if not is_class and trailer.parent.type_tag is None {
                    continue;
                }
                chain = trailer.as_attr_list;
                if (
                    len(chain) >= 2
                    and chain[0].sym_name == 'self'
                    and chain[1].sym_name == member
                ) {
                    arch.def_insert(chain[1], access_spec=arch);
                    return arch.lookup(member, deep=False);
                }
            }
        }
    }
    return None;
}

impl ClassType.get_class_symbol -> (Symbol | None) {
    import from jaclang.compiler.frontend.unitree { Archetype }
    symbol_table = self.shared.symbol_table;
    if isinstance(symbol_table, Archetype) {
        return symbol_table.name.sym;
    }
    import from jaclang.compiler.types.stubcat.reader { CatScope }
    if isinstance(symbol_table, CatScope) {
        return symbol_table.cat_owner_sym;
    }
    return None;
}

impl ClassType.specialize_generics(type_args: list[TypeBase]) -> ClassType {
    new_private = ClassDetailsPrivate(
        type_args=type_args,
        ct_args=self.private.ct_args,
        alias_name=self.private.alias_name,
        literal_value=self.private.literal_value,
        distinct_key=self.private.distinct_key
    );
    return ClassType(_shared=self.shared, private=new_private, flags=self.flags);
}

impl ClassType.clone_as_class -> ClassType {
    if not self.is_instance() {
        return self;
    }
    private = ClassDetailsPrivate(
        type_args=self.private.type_args[:],
        ct_args=self.private.ct_args,
        alias_name=self.private.alias_name,
        literal_value=self.private.literal_value,
        distinct_key=self.private.distinct_key
    );
    new_flag = self.flags;
    new_flag = TypeFlags((new_flag & ~TypeFlags.Instance));
    new_flags = TypeFlags((new_flag | TypeFlags.Instantiable));
    new_class = ClassType(_shared=self.shared, private=private, flags=new_flags);
    return new_class;
}

impl ClassType.clone_as_instance -> ClassType {
    if self.is_instance() {
        return self;
    }
    private = ClassDetailsPrivate(
        type_args=self.private.type_args[:],
        ct_args=self.private.ct_args,
        alias_name=self.private.alias_name,
        literal_value=self.private.literal_value,
        distinct_key=self.private.distinct_key
    );
    new_instance = ClassType(_shared=self.shared, private=private, flags=self.flags);
    new_flag = self.flags;
    new_flag = TypeFlags((new_flag & ~TypeFlags.Instantiable));
    new_flags = TypeFlags((new_flag | TypeFlags.Instance));
    new_instance.flags = new_flags;
    return new_instance;
}

impl ClassType.is_special_form(name: str | None = None) -> bool {
    if self.private.alias_name is None {
        return False;
    }
    if name is None {
        return True;
    }
    return self.private.alias_name == name;
}

impl ClassType.clone_with_literal(value: (str | int | bool | None)) -> ClassType {
    new_private = ClassDetailsPrivate(
        type_args=self.private.type_args[:], alias_name=None, literal_value=value
    );
    return ClassType(_shared=self.shared, private=new_private, flags=self.flags);
}

impl ClassType.is_literal_type -> bool {
    return self.private.literal_value is not None;
}

impl ClassType.get_literal_value -> (str | int | bool | None) {
    return self.private.literal_value;
}

impl ClassType.__str__ -> str {
    if self.private.distinct_key is not None {
        return self.private.distinct_key.split("::")[-1];
    }
    if self.private.literal_value is not None {
        lit_val = self.private.literal_value;
        if isinstance(lit_val, str) {
            return f"Literal[\"{lit_val}\"]";
        }
        return f"Literal[{lit_val}]";
    }

    class_name = self._shared.class_name if self._shared is not None else "<unbound>";

    if self.private.type_args {
        args_str = ", ".join(str(arg) for arg in self.private.type_args);
        return f"{class_name}[{args_str}]";
    }
    return f"{class_name}";
}

impl ClassType.shared.getter -> ClassDetailsShared {
    assert self._shared is not None , "ClassType.shared accessed before construction (detached property ClassType?)";
    return self._shared;
}

impl ClassDetailsShared.canonical_key -> (tuple[str, int, int, str] | None) {
    if self._identity_key is not None {
        return self._identity_key;
    }
    decl = self.symbol_table;
    if decl is None or decl.loc is None {
        return None;
    }
    import os;
    mod_path = decl.loc.mod_path;
    canon_path = os.path.realpath(mod_path) if mod_path else "";
    self._identity_key = (
        canon_path,
        decl.loc.first_line,
        decl.loc.col_start,
        self.class_name
    );
    return self._identity_key;
}

impl ClassDetailsShared.same_class(other: ClassDetailsShared) -> bool {
    if self is other {
        return True;
    }
    key = self.canonical_key();
    if key is None {
        return False;
    }
    other_key = other.canonical_key();
    if key == other_key {
        return True;
    }

    if other_key is None or self.class_name != other.class_name {
        return False;
    }
    import from jaclang.compiler.frontend.codeinfo { bundled_stdlib_module_of }
    mod_name = bundled_stdlib_module_of(key[0]);
    return mod_name is not None and mod_name == bundled_stdlib_module_of(other_key[0]);
}

impl TypeBase.is_class_instance -> bool {
    return ((self.category == TypeCategory.Class) and self.is_instance());
}

impl TypeBase.is_instantiable_class -> bool {
    return ((self.category == TypeCategory.Class) and self.is_instantiable());
}

impl TypeBase.is_instance -> bool {
    return bool((self.flags & TypeFlags.Instance));
}

impl TypeBase.is_instantiable -> bool {
    return bool((self.flags & TypeFlags.Instantiable));
}

impl TypeBase.category.getter -> TypeCategory {
    return self.CATEGORY;
}

impl TypeBase.mangle -> str {
    if isinstance(self, ClassType) {
        base = self._shared.class_name if self._shared is not None else "<unbound>";
        if self.private.type_args {
            args = ",".join(arg.mangle() for arg in self.private.type_args);
            base = f"{base}[{args}]";
        }
        if self.is_instantiable() and not self.is_instance() {
            return f"type[{base}]";
        }
        return base;
    }
    if isinstance(self, UnionType) {
        members = sorted(set(ty.mangle() for ty in (self.types or [])));
        return "|".join(members) if members else "<union>";
    }
    if isinstance(self, FunctionType) {
        params = ",".join(
            (p.param_type.mangle() if p.param_type is not None else "any")
            for p in (self.parameters or [])
        );
        ret = self.return_type.mangle() if self.return_type is not None else "any";
        return f"fn({params})->{ret}";
    }
    if isinstance(self, OverloadedType) {
        return "&".join(ov.mangle() for ov in (self.overloads or []));
    }
    if isinstance(self, EnumMemberType) {
        enum_key = self.enum_class.mangle()
            if self.enum_class is not None
            else "<enum>";
        member = self.member_info.member_name
            if self.member_info is not None
            else "<member>";
        return f"{enum_key}.{member}";
    }
    if isinstance(self, ModuleType) {
        return f"module[{self.mod_name}]" if self.mod_name else "module[?]";
    }
    if isinstance(self, TypeVarType) {
        return f"~{self.name}" if self.name else "~T";
    }
    if isinstance(self, AnyType) {
        return "any";
    }
    if isinstance(self, NeverType) {
        return "never";
    }
    if isinstance(self, UnknownType) {
        return "<unknown>";
    }
    return "<unbound>";
}

impl TypeBase.is_any_instance -> bool {
    if self.category == TypeCategory.Any {
        return True;
    }
    if isinstance(self, ClassType) {
        return self.is_builtin("Any");
    }
    return False;
}

impl TypeBase.is_any_type -> bool {
    if self.category in (TypeCategory.Any, TypeCategory.TypeVar) {
        return True;
    }

    if isinstance(self, ClassType) {
        return self.is_builtin("object");
    }
    return False;
}

impl EnumMemberType.__str__ -> str {
    enum_class = self.enum_class;
    member_info = self.member_info;
    class_name = enum_class.shared.class_name if enum_class is not None else "Unknown";
    member_name = member_info.member_name if member_info is not None else "Unknown";
    return f"<{class_name}.{member_name}>";
}

impl EnumMemberType.get_value_type -> TypeBase {
    enum_class = self.enum_class;
    member_info = self.member_info;
    return (member_info.value_type if member_info is not None else None)
        or (enum_class.shared.enum_value_type if enum_class is not None else None)
        or UnknownType();
}

impl FunctionType.is_gradual_callable_form -> bool {
    return bool(self.function_flags & FunctionTypeFlags.GradualCallableForm);
}

impl FunctionType.is_from_callable_annotation -> bool {
    return self.func_name == "";
}
