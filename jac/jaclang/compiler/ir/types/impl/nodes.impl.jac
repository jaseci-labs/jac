import from jaclang.compiler.ir.identity { RelationFamily }
impl ModuleType.symbol_table.getter -> (SymbolTable | None) {
    import from jaclang.compiler.ir.types.edges { DeclScopeOf }

    cached = self._cached_symbol_table;
    if cached is not None and cached.generation == self.relation_generation {
        return cached.value;
    }
    found = [self->:DeclScopeOf:->];
    val = found[0] if found else None;
    self._cached_symbol_table = RelationCache(self.relation_generation, val);
    return val;
}

impl ModuleType.symbol_table.setter(symbol_table: (SymbolTable | None)) -> None {
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }
    for proposed_target in ([] if symbol_table is None else [symbol_table]) {
        if not isinstance(proposed_target, UniScopeNode) {
            raise TypeError("DeclScopeOf requires a valid target");
        }
        self.check_connection(proposed_target, RelationFamily.TYPES);
    }

    self.changed_relations();
    import from jaclang.compiler.ir.types.edges { DeclScopeOf }

    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:DeclScopeOf:->];
    if symbol_table is not None {
        import from jaclang.compiler.ir.types.nodes { ClassDetailsShared, ModuleType }
        import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }
        if not isinstance(self, (ModuleType, ClassDetailsShared)) {
            raise TypeError("DeclScopeOf requires a valid source");
        }
        if not isinstance(symbol_table, UniScopeNode) {
            raise TypeError("DeclScopeOf requires a valid target");
        }
        self.prepare_connection(symbol_table, RelationFamily.TYPES);
        self +>:DeclScopeOf:+> symbol_table;
    }
    self._cached_symbol_table = RelationCache(self.relation_generation, symbol_table);
}

impl TypeVarType.bound.getter -> (TypeBase | None) {
    import from jaclang.compiler.ir.types.edges { BoundOf }

    cached = self._cached_bound;
    if cached is not None and cached.generation == self.relation_generation {
        return cached.value;
    }
    found = [self->:BoundOf:->];
    val = found[0] if found else None;
    self._cached_bound = RelationCache(self.relation_generation, val);
    return val;
}

impl TypeVarType.bound.setter(bound: (TypeBase | None)) -> None {
    import from jaclang.compiler.ir.types.nodes { TypeBase }
    for proposed_target in ([] if bound is None else [bound]) {
        if not isinstance(proposed_target, TypeBase) {
            raise TypeError("BoundOf requires a valid target");
        }
        self.check_connection(proposed_target, RelationFamily.TYPES);
    }

    self.changed_relations();
    import from jaclang.compiler.ir.types.edges { BoundOf }

    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:BoundOf:->];
    if bound is not None {
        import from jaclang.compiler.ir.types.nodes { TypeBase, TypeVarType }
        if not isinstance(self, TypeVarType) {
            raise TypeError("BoundOf requires a valid source");
        }
        if not isinstance(bound, TypeBase) {
            raise TypeError("BoundOf requires a valid target");
        }
        self.prepare_connection(bound, RelationFamily.TYPES);
        self +>:BoundOf:+> bound;
    }
    self._cached_bound = RelationCache(self.relation_generation, bound);
}

impl TypeVarType.constraints.getter -> list[TypeBase] {
    import from jaclang.compiler.ir.types.edges { ConstraintOf }

    cached = self._cached_constraints;
    if cached is not None and cached.generation == self.relation_generation {
        return cached.value;
    }
    val = [self->:ConstraintOf:->][?:TypeBase];
    self._cached_constraints = RelationCache(self.relation_generation, val);
    return val;
}

impl TypeVarType.constraints.setter(constraints: (list[TypeBase] | None)) -> None {
    import from jaclang.compiler.ir.types.nodes { TypeBase }
    for proposed_target in (constraints or []) {
        if not isinstance(proposed_target, TypeBase) {
            raise TypeError("ConstraintOf requires a valid target");
        }
        self.check_connection(proposed_target, RelationFamily.TYPES);
    }

    self.changed_relations();
    import from jaclang.compiler.ir.types.edges { ConstraintOf }

    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:ConstraintOf:->];
    for t in (constraints or []) {
        import from jaclang.compiler.ir.types.nodes { TypeBase, TypeVarType }
        if not isinstance(self, TypeVarType) {
            raise TypeError("ConstraintOf requires a valid source");
        }
        if not isinstance(t, TypeBase) {
            raise TypeError("ConstraintOf requires a valid target");
        }
        self.prepare_connection(t, RelationFamily.TYPES);
        self +>:ConstraintOf:+> t;
    }
    self._cached_constraints = RelationCache(
        self.relation_generation, `list(constraints or [])
    );
}

impl ClassDetailsShared.symbol_table.getter -> SymbolTable {
    import from jaclang.compiler.ir.types.edges { DeclScopeOf }

    cached = self._cached_symbol_table;
    if cached is not None and cached.generation == self.relation_generation {
        return cached.value;
    }
    val = [self->:DeclScopeOf:->][0];
    self._cached_symbol_table = RelationCache(self.relation_generation, val);
    return val;
}

impl ClassDetailsShared.symbol_table.setter(symbol_table: SymbolTable) -> None {
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }
    import from jaclang.compiler.ir.types.edges { DeclScopeOf }
    if not isinstance(symbol_table, UniScopeNode) {
        raise TypeError("DeclScopeOf requires a valid target");
    }
    self.check_connection(symbol_table, RelationFamily.TYPES);
    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:DeclScopeOf:->];
    self +>:DeclScopeOf:+> symbol_table;
    self._cached_symbol_table = RelationCache(self.relation_generation, symbol_table);
}

impl ClassDetailsShared.mro.getter -> list[ClassType] {
    import from jaclang.compiler.ir.types.edges { MroOf }

    if self._mro_cache is None or self._mro_generation != self.relation_generation {
        self._mro_cache = [self->:MroOf:->];
        self._mro_generation = self.relation_generation;
    }
    return self._mro_cache;
}

impl ClassDetailsShared.mro.setter(mro: list[ClassType]) -> None {
    import from jaclang.compiler.ir.types.nodes { ClassType }
    for proposed_target in (mro or []) {
        if not isinstance(proposed_target, ClassType) {
            raise TypeError("MroOf requires a valid target");
        }
        self.check_connection(proposed_target, RelationFamily.TYPES);
    }

    self.changed_relations();
    import from jaclang.compiler.ir.types.edges { MroOf }

    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:MroOf:->];
    for t in (mro or []) {
        import from jaclang.compiler.ir.types.nodes { ClassDetailsShared, ClassType }
        if not isinstance(self, ClassDetailsShared) {
            raise TypeError("MroOf requires a valid source");
        }
        if not isinstance(t, ClassType) {
            raise TypeError("MroOf requires a valid target");
        }
        self.prepare_connection(t, RelationFamily.TYPES);
        self +>:MroOf:+> t;
    }
    self._mro_cache = `list(mro or []);
    self._mro_generation = self.relation_generation;
}

impl ClassDetailsShared.type_params.getter -> list[TypeVarType] {
    import from jaclang.compiler.ir.types.edges { TypeParamOf }

    cached = self._cached_type_params;
    if cached is not None and cached.generation == self.relation_generation {
        return cached.value;
    }
    val = [self->:TypeParamOf:->][?:TypeVarType];
    self._cached_type_params = RelationCache(self.relation_generation, val);
    return val;
}

impl ClassDetailsShared.type_params.setter(
    type_params: (list[TypeVarType] | None)
) -> None {
    import from jaclang.compiler.ir.types.nodes { TypeVarType }
    for proposed_target in (type_params or []) {
        if not isinstance(proposed_target, TypeVarType) {
            raise TypeError("TypeParamOf requires a valid target");
        }
        self.check_connection(proposed_target, RelationFamily.TYPES);
    }

    self.changed_relations();
    import from jaclang.compiler.ir.types.edges { TypeParamOf }

    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:TypeParamOf:->];
    for t in (type_params or []) {
        import from jaclang.compiler.ir.types.nodes {
            ClassDetailsShared,
            FunctionType,
            TypeVarType
        }
        if not isinstance(self, (ClassDetailsShared, FunctionType)) {
            raise TypeError("TypeParamOf requires a valid source");
        }
        if not isinstance(t, TypeVarType) {
            raise TypeError("TypeParamOf requires a valid target");
        }
        self.prepare_connection(t, RelationFamily.TYPES);
        self +>:TypeParamOf:+> t;
    }
    self._cached_type_params = RelationCache(
        self.relation_generation, `list(type_params or [])
    );
}

impl ClassDetailsShared.base_classes.getter -> list[TypeBase] {
    import from jaclang.compiler.ir.types.edges { BaseOf }

    cached = self._cached_base_classes;
    if cached is not None and cached.generation == self.relation_generation {
        return cached.value;
    }
    val = [self->:BaseOf:->][?:TypeBase];
    self._cached_base_classes = RelationCache(self.relation_generation, val);
    return val;
}

impl ClassDetailsShared.base_classes.setter(
    base_classes: (list[TypeBase] | None)
) -> None {
    import from jaclang.compiler.ir.types.nodes { TypeBase }
    for proposed_target in (base_classes or []) {
        if not isinstance(proposed_target, TypeBase) {
            raise TypeError("BaseOf requires a valid target");
        }
        self.check_connection(proposed_target, RelationFamily.TYPES);
    }

    self.changed_relations();
    import from jaclang.compiler.ir.types.edges { BaseOf }

    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:BaseOf:->];
    for t in (base_classes or []) {
        import from jaclang.compiler.ir.types.nodes { ClassDetailsShared, TypeBase }
        if not isinstance(self, ClassDetailsShared) {
            raise TypeError("BaseOf requires a valid source");
        }
        if not isinstance(t, TypeBase) {
            raise TypeError("BaseOf requires a valid target");
        }
        self.prepare_connection(t, RelationFamily.TYPES);
        self +>:BaseOf:+> t;
    }
    self._cached_base_classes = RelationCache(
        self.relation_generation, `list(base_classes or [])
    );
}

impl ClassDetailsShared.enum_value_type.getter -> (TypeBase | None) {
    import from jaclang.compiler.ir.types.edges { ValueTypeOf }

    cached = self._cached_enum_value_type;
    if cached is not None and cached.generation == self.relation_generation {
        return cached.value;
    }
    found = [self->:ValueTypeOf:->];
    val = found[0] if found else None;
    self._cached_enum_value_type = RelationCache(self.relation_generation, val);
    return val;
}

impl ClassDetailsShared.enum_value_type.setter(
    enum_value_type: (TypeBase | None)
) -> None {
    import from jaclang.compiler.ir.types.nodes { TypeBase }
    for proposed_target in ([] if enum_value_type is None else [enum_value_type]) {
        if not isinstance(proposed_target, TypeBase) {
            raise TypeError("ValueTypeOf requires a valid target");
        }
        self.check_connection(proposed_target, RelationFamily.TYPES);
    }

    self.changed_relations();
    import from jaclang.compiler.ir.types.edges { ValueTypeOf }

    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:ValueTypeOf:->];
    if enum_value_type is not None {
        import from jaclang.compiler.ir.types.nodes {
            ClassDetailsShared,
            EnumMemberInfo,
            TypeBase
        }
        if not isinstance(self, (ClassDetailsShared, EnumMemberInfo)) {
            raise TypeError("ValueTypeOf requires a valid source");
        }
        if not isinstance(enum_value_type, TypeBase) {
            raise TypeError("ValueTypeOf requires a valid target");
        }
        self.prepare_connection(enum_value_type, RelationFamily.TYPES);
        self +>:ValueTypeOf:+> enum_value_type;
    }
    self._cached_enum_value_type = RelationCache(
        self.relation_generation, enum_value_type
    );
}

impl ClassDetailsShared.typeddict_fields.getter -> dict[str, TypeBase] {
    import from jaclang.compiler.ir.types.edges { TypeMemberOf }

    d: dict[str, TypeBase] = {};
    for ea in [edge self->:TypeMemberOf:->] {
        d[ea.name] = getattr(ea, "__jac__").target.archetype;
    }
    return d;
}

impl ClassDetailsShared.typeddict_fields.setter(
    typeddict_fields: (dict[str, TypeBase] | None)
) -> None {
    import from jaclang.compiler.ir.types.nodes { TypeBase }
    for proposed_target in (typeddict_fields or {}).values() {
        if not isinstance(proposed_target, TypeBase) {
            raise TypeError("TypeMemberOf requires a valid target");
        }
        self.check_connection(proposed_target, RelationFamily.TYPES);
    }

    self.changed_relations();
    import from jaclang.compiler.ir.types.edges { TypeMemberOf }

    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:TypeMemberOf:->];
    for (k, v) in (typeddict_fields or {}).items() {
        import from jaclang.compiler.ir.types.nodes { ClassDetailsShared, TypeBase }
        if not isinstance(self, ClassDetailsShared) {
            raise TypeError("TypeMemberOf requires a valid source");
        }
        if not isinstance(v, TypeBase) {
            raise TypeError("TypeMemberOf requires a valid target");
        }
        self.prepare_connection(v, RelationFamily.TYPES);
        self +>:TypeMemberOf(name=k):+> v;
    }
}

impl ClassDetailsShared.enum_members.getter -> dict[str, EnumMemberInfo] {
    import from jaclang.compiler.ir.types.edges { EnumMemberOf }

    d: dict[str, EnumMemberInfo] = {};
    for ea in [edge self->:EnumMemberOf:->] {
        d[ea.name] = getattr(ea, "__jac__").target.archetype;
    }
    return d;
}

impl ClassDetailsShared.enum_members.setter(
    enum_members: (dict[str, EnumMemberInfo] | None)
) -> None {
    import from jaclang.compiler.ir.types.nodes { EnumMemberInfo }
    for proposed_target in (enum_members or {}).values() {
        if not isinstance(proposed_target, EnumMemberInfo) {
            raise TypeError("EnumMemberOf requires a valid target");
        }
        self.check_connection(proposed_target, RelationFamily.TYPES);
    }

    self.changed_relations();
    import from jaclang.compiler.ir.types.edges { EnumMemberOf }

    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:EnumMemberOf:->];
    for (k, v) in (enum_members or {}).items() {
        import from jaclang.compiler.ir.types.nodes {
            ClassDetailsShared,
            EnumMemberInfo
        }
        if not isinstance(self, ClassDetailsShared) {
            raise TypeError("EnumMemberOf requires a valid source");
        }
        if not isinstance(v, EnumMemberInfo) {
            raise TypeError("EnumMemberOf requires a valid target");
        }
        self.prepare_connection(v, RelationFamily.TYPES);
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
    declaration_identity: (tuple[str, int, int, str] | None) = None,
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
    self.declaration_identity = declaration_identity;
    self._identity_key = None;
    self._identity_generation = -1;
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
    import from jaclang.compiler.ir.types.edges { TypeArgOf }

    if self._targs_cache is None
        or self._targs_generation != self.relation_generation {
        self._targs_cache = [self->:TypeArgOf:->][?:TypeBase];
        self._targs_generation = self.relation_generation;
    }
    return self._targs_cache;
}

impl ClassDetailsPrivate.type_args.setter(type_args: (list[TypeBase] | None)) -> None {
    import from jaclang.compiler.ir.types.nodes { TypeBase }
    for proposed_target in (type_args or []) {
        if not isinstance(proposed_target, TypeBase) {
            raise TypeError("TypeArgOf requires a valid target");
        }
        self.check_connection(proposed_target, RelationFamily.TYPES);
    }

    self.changed_relations();
    import from jaclang.compiler.ir.types.edges { TypeArgOf }

    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:TypeArgOf:->];
    for t in (type_args or []) {
        import from jaclang.compiler.ir.types.nodes { ClassDetailsPrivate, TypeBase }
        if not isinstance(self, ClassDetailsPrivate) {
            raise TypeError("TypeArgOf requires a valid source");
        }
        if not isinstance(t, TypeBase) {
            raise TypeError("TypeArgOf requires a valid target");
        }
        self.prepare_connection(t, RelationFamily.TYPES);
        self +>:TypeArgOf:+> t;
    }
    self._targs_cache = `list(type_args or []);
    self._targs_generation = self.relation_generation;
}

impl ClassType._shared.getter -> (ClassDetailsShared | None) {
    import from jaclang.compiler.ir.types.edges { SharedOf }

    cached = self._cached__shared;
    if cached is not None and cached.generation == self.relation_generation {
        return cached.value;
    }
    found = [self->:SharedOf:->];
    val = found[0] if found else None;
    self._cached__shared = RelationCache(self.relation_generation, val);
    return val;
}

impl ClassType._shared.setter(_shared: (ClassDetailsShared | None)) -> None {
    import from jaclang.compiler.ir.types.nodes { ClassDetailsShared }
    for proposed_target in ([] if _shared is None else [_shared]) {
        if not isinstance(proposed_target, ClassDetailsShared) {
            raise TypeError("SharedOf requires a valid target");
        }
        self.check_connection(proposed_target, RelationFamily.TYPES);
    }

    self.changed_relations();
    import from jaclang.compiler.ir.types.edges { SharedOf }

    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:SharedOf:->];
    if _shared is not None {
        import from jaclang.compiler.ir.types.nodes { ClassDetailsShared, ClassType }
        if not isinstance(self, ClassType) {
            raise TypeError("SharedOf requires a valid source");
        }
        if not isinstance(_shared, ClassDetailsShared) {
            raise TypeError("SharedOf requires a valid target");
        }
        self.prepare_connection(_shared, RelationFamily.TYPES);
        self +>:SharedOf:+> _shared;
    }
    self._cached__shared = RelationCache(self.relation_generation, _shared);
}

impl ClassType.private.getter -> ClassDetailsPrivate {
    import from jaclang.compiler.ir.types.edges { PrivOf }

    cached = self._cached_private;
    if cached is not None and cached.generation == self.relation_generation {
        return cached.value;
    }
    val = [self->:PrivOf:->][0];
    self._cached_private = RelationCache(self.relation_generation, val);
    return val;
}

impl ClassType.private.setter(private: ClassDetailsPrivate) -> None {
    import from jaclang.compiler.ir.types.nodes { ClassDetailsPrivate }
    for proposed_target in [private] {
        if not isinstance(proposed_target, ClassDetailsPrivate) {
            raise TypeError("PrivOf requires a valid target");
        }
        self.check_connection(proposed_target, RelationFamily.TYPES);
    }

    self.changed_relations();
    import from jaclang.compiler.ir.types.edges { PrivOf }

    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:PrivOf:->];
    import from jaclang.compiler.ir.types.nodes { ClassDetailsPrivate, ClassType }
    if not isinstance(self, ClassType) {
        raise TypeError("PrivOf requires a valid source");
    }
    if not isinstance(private, ClassDetailsPrivate) {
        raise TypeError("PrivOf requires a valid target");
    }
    self.prepare_connection(private, RelationFamily.TYPES);
    self +>:PrivOf:+> private;
    self._cached_private = RelationCache(self.relation_generation, private);
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
    import from jaclang.compiler.ir.types.edges { ParamTypeOf }

    cached = self._cached_param_type;
    if cached is not None and cached.generation == self.relation_generation {
        return cached.value;
    }
    found = [self->:ParamTypeOf:->];
    val = found[0] if found else None;
    self._cached_param_type = RelationCache(self.relation_generation, val);
    return val;
}

impl Parameter.param_type.setter(param_type: (TypeBase | None)) -> None {
    import from jaclang.compiler.ir.types.nodes { TypeBase }
    for proposed_target in ([] if param_type is None else [param_type]) {
        if not isinstance(proposed_target, TypeBase) {
            raise TypeError("ParamTypeOf requires a valid target");
        }
        self.check_connection(proposed_target, RelationFamily.TYPES);
    }

    self.changed_relations();
    import from jaclang.compiler.ir.types.edges { ParamTypeOf }

    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:ParamTypeOf:->];
    if param_type is not None {
        import from jaclang.compiler.ir.types.nodes { Parameter, TypeBase }
        if not isinstance(self, Parameter) {
            raise TypeError("ParamTypeOf requires a valid source");
        }
        if not isinstance(param_type, TypeBase) {
            raise TypeError("ParamTypeOf requires a valid target");
        }
        self.prepare_connection(param_type, RelationFamily.TYPES);
        self +>:ParamTypeOf:+> param_type;
    }
    self._cached_param_type = RelationCache(self.relation_generation, param_type);
}

impl Parameter.default_value.getter -> (Expr | None) {
    import from jaclang.compiler.ir.types.edges { ParamDefaultOf }

    cached = self._cached_default_value;
    if cached is not None and cached.generation == self.relation_generation {
        return cached.value;
    }
    found = [self->:ParamDefaultOf:->];
    val = found[0] if found else None;
    self._cached_default_value = RelationCache(self.relation_generation, val);
    return val;
}

impl Parameter.default_value.setter(default_value: (Expr | None)) -> None {
    import from jaclang.compiler.ir.types.syntax { Expr }
    for proposed_target in ([] if default_value is None else [default_value]) {
        if not isinstance(proposed_target, Expr) {
            raise TypeError("ParamDefaultOf requires a valid target");
        }
        self.check_connection(proposed_target, RelationFamily.TYPES);
    }

    self.changed_relations();
    import from jaclang.compiler.ir.types.edges { ParamDefaultOf }

    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:ParamDefaultOf:->];
    if default_value is not None {
        import from jaclang.compiler.ir.types.nodes { Parameter }
        import from jaclang.compiler.ir.types.syntax { Expr }
        if not isinstance(self, Parameter) {
            raise TypeError("ParamDefaultOf requires a valid source");
        }
        if not isinstance(default_value, Expr) {
            raise TypeError("ParamDefaultOf requires a valid target");
        }
        self.prepare_connection(default_value, RelationFamily.TYPES);
        self +>:ParamDefaultOf:+> default_value;
    }
    self._cached_default_value = RelationCache(self.relation_generation, default_value);
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
    import from jaclang.compiler.ir.types.edges { ReturnsOf }

    cached = self._cached_return_type;
    if cached is not None and cached.generation == self.relation_generation {
        return cached.value;
    }
    found = [self->:ReturnsOf:->];
    val = found[0] if found else None;
    self._cached_return_type = RelationCache(self.relation_generation, val);
    return val;
}

impl FunctionType.return_type.setter(return_type: (TypeBase | None)) -> None {
    import from jaclang.compiler.ir.types.nodes { TypeBase }
    for proposed_target in ([] if return_type is None else [return_type]) {
        if not isinstance(proposed_target, TypeBase) {
            raise TypeError("ReturnsOf requires a valid target");
        }
        self.check_connection(proposed_target, RelationFamily.TYPES);
    }

    self.changed_relations();
    import from jaclang.compiler.ir.types.edges { ReturnsOf }

    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:ReturnsOf:->];
    if return_type is not None {
        import from jaclang.compiler.ir.types.nodes { FunctionType, TypeBase }
        if not isinstance(self, FunctionType) {
            raise TypeError("ReturnsOf requires a valid source");
        }
        if not isinstance(return_type, TypeBase) {
            raise TypeError("ReturnsOf requires a valid target");
        }
        self.prepare_connection(return_type, RelationFamily.TYPES);
        self +>:ReturnsOf:+> return_type;
    }
    self._cached_return_type = RelationCache(self.relation_generation, return_type);
}

impl FunctionType.parameters.getter -> list[Parameter] {
    import from jaclang.compiler.ir.types.edges { ParamOf }

    if self._params_cache is None
        or self._params_generation != self.relation_generation {
        self._params_cache = [self->:ParamOf:->];
        self._params_generation = self.relation_generation;
    }
    return self._params_cache;
}

impl FunctionType.parameters.setter(parameters: (list[Parameter] | None)) -> None {
    import from jaclang.compiler.ir.types.nodes { Parameter }
    for proposed_target in (parameters or []) {
        if not isinstance(proposed_target, Parameter) {
            raise TypeError("ParamOf requires a valid target");
        }
        self.check_connection(proposed_target, RelationFamily.TYPES);
    }

    self.changed_relations();
    import from jaclang.compiler.ir.types.edges { ParamOf }

    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:ParamOf:->];
    for t in (parameters or []) {
        import from jaclang.compiler.ir.types.nodes { FunctionType, Parameter }
        if not isinstance(self, FunctionType) {
            raise TypeError("ParamOf requires a valid source");
        }
        if not isinstance(t, Parameter) {
            raise TypeError("ParamOf requires a valid target");
        }
        self.prepare_connection(t, RelationFamily.TYPES);
        self +>:ParamOf:+> t;
    }
    self._params_cache = `list(parameters or []);
    self._params_generation = self.relation_generation;
}

impl FunctionType.type_params.getter -> list[TypeVarType] {
    import from jaclang.compiler.ir.types.edges { TypeParamOf }

    cached = self._cached_type_params;
    if cached is not None and cached.generation == self.relation_generation {
        return cached.value;
    }
    val = [self->:TypeParamOf:->][?:TypeVarType];
    self._cached_type_params = RelationCache(self.relation_generation, val);
    return val;
}

impl FunctionType.type_params.setter(type_params: (list[TypeVarType] | None)) -> None {
    import from jaclang.compiler.ir.types.nodes { TypeVarType }
    for proposed_target in (type_params or []) {
        if not isinstance(proposed_target, TypeVarType) {
            raise TypeError("TypeParamOf requires a valid target");
        }
        self.check_connection(proposed_target, RelationFamily.TYPES);
    }

    self.changed_relations();
    import from jaclang.compiler.ir.types.edges { TypeParamOf }

    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:TypeParamOf:->];
    for t in (type_params or []) {
        import from jaclang.compiler.ir.types.nodes {
            ClassDetailsShared,
            FunctionType,
            TypeVarType
        }
        if not isinstance(self, (ClassDetailsShared, FunctionType)) {
            raise TypeError("TypeParamOf requires a valid source");
        }
        if not isinstance(t, TypeVarType) {
            raise TypeError("TypeParamOf requires a valid target");
        }
        self.prepare_connection(t, RelationFamily.TYPES);
        self +>:TypeParamOf:+> t;
    }
    self._cached_type_params = RelationCache(
        self.relation_generation, `list(type_params or [])
    );
}

impl FunctionType.type_guard.getter -> (TypeBase | None) {
    import from jaclang.compiler.ir.types.edges { GuardOf }

    cached = self._cached_type_guard;
    if cached is not None and cached.generation == self.relation_generation {
        return cached.value;
    }
    found = [self->:GuardOf:->];
    val = found[0] if found else None;
    self._cached_type_guard = RelationCache(self.relation_generation, val);
    return val;
}

impl FunctionType.type_guard.setter(type_guard: (TypeBase | None)) -> None {
    import from jaclang.compiler.ir.types.nodes { TypeBase }
    for proposed_target in ([] if type_guard is None else [type_guard]) {
        if not isinstance(proposed_target, TypeBase) {
            raise TypeError("GuardOf requires a valid target");
        }
        self.check_connection(proposed_target, RelationFamily.TYPES);
    }

    self.changed_relations();
    import from jaclang.compiler.ir.types.edges { GuardOf }

    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:GuardOf:->];
    if type_guard is not None {
        import from jaclang.compiler.ir.types.nodes { FunctionType, TypeBase }
        if not isinstance(self, FunctionType) {
            raise TypeError("GuardOf requires a valid source");
        }
        if not isinstance(type_guard, TypeBase) {
            raise TypeError("GuardOf requires a valid target");
        }
        self.prepare_connection(type_guard, RelationFamily.TYPES);
        self +>:GuardOf:+> type_guard;
    }
    self._cached_type_guard = RelationCache(self.relation_generation, type_guard);
}

impl OverloadedType.overloads.getter -> list[FunctionType] {
    import from jaclang.compiler.ir.types.edges { OverloadOf }

    cached = self._cached_overloads;
    if cached is not None and cached.generation == self.relation_generation {
        return cached.value;
    }
    val = [self->:OverloadOf:->][?:FunctionType];
    self._cached_overloads = RelationCache(self.relation_generation, val);
    return val;
}

impl OverloadedType.overloads.setter(overloads: (list[FunctionType] | None)) -> None {
    import from jaclang.compiler.ir.types.nodes { FunctionType }
    for proposed_target in (overloads or []) {
        if not isinstance(proposed_target, FunctionType) {
            raise TypeError("OverloadOf requires a valid target");
        }
        self.check_connection(proposed_target, RelationFamily.TYPES);
    }

    self.changed_relations();
    import from jaclang.compiler.ir.types.edges { OverloadOf }

    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:OverloadOf:->];
    for t in (overloads or []) {
        import from jaclang.compiler.ir.types.nodes { FunctionType, OverloadedType }
        if not isinstance(self, OverloadedType) {
            raise TypeError("OverloadOf requires a valid source");
        }
        if not isinstance(t, FunctionType) {
            raise TypeError("OverloadOf requires a valid target");
        }
        self.prepare_connection(t, RelationFamily.TYPES);
        self +>:OverloadOf:+> t;
    }
    self._cached_overloads = RelationCache(
        self.relation_generation, `list(overloads or [])
    );
}

impl OverloadedType.init(
    *, overloads: (list[FunctionType] | None) = None, flags: TypeFlags = TypeFlags.Null
) -> None {
    self.flags = flags;
    self.overloads = overloads;
}

impl UnionType.types.getter -> list[TypeBase] {
    import from jaclang.compiler.ir.types.edges { UnionMemberOf }

    cached = self._cached_types;
    if cached is not None and cached.generation == self.relation_generation {
        return cached.value;
    }
    val = [self->:UnionMemberOf:->][?:TypeBase];
    self._cached_types = RelationCache(self.relation_generation, val);
    return val;
}

impl UnionType.types.setter(types: (list[TypeBase] | None)) -> None {
    import from jaclang.compiler.ir.types.nodes { TypeBase }
    for proposed_target in (types or []) {
        if not isinstance(proposed_target, TypeBase) {
            raise TypeError("UnionMemberOf requires a valid target");
        }
        self.check_connection(proposed_target, RelationFamily.TYPES);
    }

    self.changed_relations();
    import from jaclang.compiler.ir.types.edges { UnionMemberOf }

    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:UnionMemberOf:->];
    for t in (types or []) {
        import from jaclang.compiler.ir.types.nodes { TypeBase, UnionType }
        if not isinstance(self, UnionType) {
            raise TypeError("UnionMemberOf requires a valid source");
        }
        if not isinstance(t, TypeBase) {
            raise TypeError("UnionMemberOf requires a valid target");
        }
        self.prepare_connection(t, RelationFamily.TYPES);
        self +>:UnionMemberOf:+> t;
    }
    self._cached_types = RelationCache(self.relation_generation, `list(types or []));
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
    import from jaclang.compiler.ir.types.edges { ValueTypeOf }

    cached = self._cached_value_type;
    if cached is not None and cached.generation == self.relation_generation {
        return cached.value;
    }
    found = [self->:ValueTypeOf:->];
    val = found[0] if found else None;
    self._cached_value_type = RelationCache(self.relation_generation, val);
    return val;
}

impl EnumMemberInfo.value_type.setter(value_type: (TypeBase | None)) -> None {
    import from jaclang.compiler.ir.types.nodes { TypeBase }
    for proposed_target in ([] if value_type is None else [value_type]) {
        if not isinstance(proposed_target, TypeBase) {
            raise TypeError("ValueTypeOf requires a valid target");
        }
        self.check_connection(proposed_target, RelationFamily.TYPES);
    }

    self.changed_relations();
    import from jaclang.compiler.ir.types.edges { ValueTypeOf }

    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:ValueTypeOf:->];
    if value_type is not None {
        import from jaclang.compiler.ir.types.nodes {
            ClassDetailsShared,
            EnumMemberInfo,
            TypeBase
        }
        if not isinstance(self, (ClassDetailsShared, EnumMemberInfo)) {
            raise TypeError("ValueTypeOf requires a valid source");
        }
        if not isinstance(value_type, TypeBase) {
            raise TypeError("ValueTypeOf requires a valid target");
        }
        self.prepare_connection(value_type, RelationFamily.TYPES);
        self +>:ValueTypeOf:+> value_type;
    }
    self._cached_value_type = RelationCache(self.relation_generation, value_type);
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
    import from jaclang.compiler.ir.types.edges { EnumClassOf }

    cached = self._cached_enum_class;
    if cached is not None and cached.generation == self.relation_generation {
        return cached.value;
    }
    found = [self->:EnumClassOf:->];
    val = found[0] if found else None;
    self._cached_enum_class = RelationCache(self.relation_generation, val);
    return val;
}

impl EnumMemberType.enum_class.setter(enum_class: (ClassType | None)) -> None {
    import from jaclang.compiler.ir.types.nodes { ClassType }
    for proposed_target in ([] if enum_class is None else [enum_class]) {
        if not isinstance(proposed_target, ClassType) {
            raise TypeError("EnumClassOf requires a valid target");
        }
        self.check_connection(proposed_target, RelationFamily.TYPES);
    }

    self.changed_relations();
    import from jaclang.compiler.ir.types.edges { EnumClassOf }

    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:EnumClassOf:->];
    if enum_class is not None {
        import from jaclang.compiler.ir.types.nodes { ClassType, EnumMemberType }
        if not isinstance(self, EnumMemberType) {
            raise TypeError("EnumClassOf requires a valid source");
        }
        if not isinstance(enum_class, ClassType) {
            raise TypeError("EnumClassOf requires a valid target");
        }
        self.prepare_connection(enum_class, RelationFamily.TYPES);
        self +>:EnumClassOf:+> enum_class;
    }
    self._cached_enum_class = RelationCache(self.relation_generation, enum_class);
}

impl EnumMemberType.member_info.getter -> (EnumMemberInfo | None) {
    import from jaclang.compiler.ir.types.edges { MemberInfoOf }

    cached = self._cached_member_info;
    if cached is not None and cached.generation == self.relation_generation {
        return cached.value;
    }
    found = [self->:MemberInfoOf:->];
    val = found[0] if found else None;
    self._cached_member_info = RelationCache(self.relation_generation, val);
    return val;
}

impl EnumMemberType.member_info.setter(member_info: (EnumMemberInfo | None)) -> None {
    import from jaclang.compiler.ir.types.nodes { EnumMemberInfo }
    for proposed_target in ([] if member_info is None else [member_info]) {
        if not isinstance(proposed_target, EnumMemberInfo) {
            raise TypeError("MemberInfoOf requires a valid target");
        }
        self.check_connection(proposed_target, RelationFamily.TYPES);
    }

    self.changed_relations();
    import from jaclang.compiler.ir.types.edges { MemberInfoOf }

    self.changed_relations(RelationFamily.TYPES);
    del [edge self->:MemberInfoOf:->];
    if member_info is not None {
        import from jaclang.compiler.ir.types.nodes { EnumMemberInfo, EnumMemberType }
        if not isinstance(self, EnumMemberType) {
            raise TypeError("MemberInfoOf requires a valid source");
        }
        if not isinstance(member_info, EnumMemberInfo) {
            raise TypeError("MemberInfoOf requires a valid target");
        }
        self.prepare_connection(member_info, RelationFamily.TYPES);
        self +>:MemberInfoOf:+> member_info;
    }
    self._cached_member_info = RelationCache(self.relation_generation, member_info);
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

impl FunctionType.clone -> FunctionType {
    return FunctionType(
        func_name=self.func_name,
        return_type=self.return_type,
        parameters=[param.clone() for param in self.parameters],
        function_flags=self.function_flags,
        type_params=self.type_params,
        is_async=self.is_async,
        type_guard=self.type_guard,
        type_guard_is_strict=self.type_guard_is_strict,
        flags=self.flags,
    );
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

impl _class_scope_category(scope: SymbolTable | None) -> SymbolType | None {
    import from jaclang.compiler.ir.enums { SymbolType }
    import from jaclang.compiler.ir.syntax.nodes { Archetype }
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }
    if isinstance(scope, Archetype) {
        return scope.sym_category;
    }
    if isinstance(scope, UniScopeNode) and scope.declaration_symbol is not None {
        return scope.declaration_symbol.sym_type;
    }
    return None;
}

impl ClassType.is_node_type -> bool {
    import from jaclang.compiler.ir.enums { SymbolType }
    if self.shared.is_root_class or self.is_builtin("Node") {
        return True;
    }
    return _class_scope_category(self.shared.symbol_table) == SymbolType.NODE_ARCH;
}

impl ClassType.is_edge_type -> bool {
    import from jaclang.compiler.ir.enums { SymbolType }
    if self.is_builtin("Edge") {
        return True;
    }
    return _class_scope_category(self.shared.symbol_table) == SymbolType.EDGE_ARCH;
}

impl ClassType.is_walker_type -> bool {
    import from jaclang.compiler.ir.enums { SymbolType }
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

impl ClassType.get_class_symbol -> (Symbol | None) {
    import from jaclang.compiler.ir.syntax.nodes { Archetype }
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }
    symbol_table = self.shared.symbol_table;
    if isinstance(symbol_table, Archetype) {
        return symbol_table.name.sym;
    }
    if isinstance(symbol_table, UniScopeNode) {
        return symbol_table.declaration_symbol;
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
    if self.declaration_identity is not None {
        return self.declaration_identity;
    }
    if self._identity_key is not None
        and self._identity_generation == self.relation_generation {
        return self._identity_key;
    }
    decl = self.symbol_table;
    if decl is None or decl.loc is None {
        return None;
    }
    import os;
    mod_path = decl.loc.mod_path;
    canon_path = os.path.realpath(mod_path) if mod_path else "";
    self._identity_generation = self.relation_generation;
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
    import from jaclang.compiler.ir.identity { bundled_stdlib_module_of }
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
