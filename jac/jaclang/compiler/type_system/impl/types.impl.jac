"""Initialize obviously."""

impl UnionType.init(self: UnionType, types: list[TypeBase]) -> None {
    super.init();
    # Flatten nested union types
    flattened_types: list[TypeBase] = [];
    for ty in types {
        if isinstance(ty, UnionType) {
            flattened_types.extend(ty.types);
        } else {
            flattened_types.append(ty);
        }
    }
    self.types = flattened_types;
}

"""Return the index of the given type variable in the class type."""
impl FunctionType._index_of_type_param(
    self: FunctionType, class_type: ClassType, type_var: TypeVarType
) -> int {
    for (idx, type_param) in enumerate(class_type.shared.type_params) {
        if (type_param is type_var) {
            return idx;
        }
    }
    return -1;
}

"""Specialize the function type based on the given class type."""
impl FunctionType.specialize(self: FunctionType, class_type: ClassType) -> FunctionType {
    clone = FunctionType(
        func_name=self.func_name,
        return_type=self.return_type,
        parameters=[
            Parameter(
                name=param.name,
                category=param.category,
                param_type=param.param_type,
                default_value=param.default_value,
                is_self=param.is_self,
                is_cls=param.is_cls,
                param_kind=param.param_kind
            ) for param in self.parameters
        ]
    );
    for param in clone.parameters {
        if (not param.param_type or not isinstance(param.param_type, TypeVarType)) {
            continue;
        }
        idx = self._index_of_type_param(class_type, param.param_type);
        if ((idx != -1) and (idx < len(class_type.private.type_args))) {
            ty = class_type.private.type_args[idx];
            ty = ty.clone_as_instance() if isinstance(ty, ClassType) else ty;
            param.param_type = ty;
        }
    }
    if (clone.return_type and isinstance(clone.return_type, TypeVarType)) {
        idx = self._index_of_type_param(class_type, clone.return_type);
        if ((idx != -1) and (idx < len(class_type.private.type_args))) {
            ty = class_type.private.type_args[idx];
            ty = ty.clone_as_instance() if isinstance(ty, ClassType) else ty;
            clone.return_type = ty;
        }
    }
    return clone;
}

"""Initialize obviously."""
impl FunctionType.init(
    self: FunctionType,
    func_name: str,
    return_type: (TypeBase | None) = None,
    parameters: (list[Parameter] | None) = None,
    flags: TypeFlags = TypeFlags.Null
) -> None {
    super.init(flags=flags);
    self.func_name = func_name;
    self.return_type = return_type;
    self.parameters = parameters or [];
}

impl OverloadedType.init(self: OverloadedType, overloads: list[FunctionType]) -> None {
    super.init();
    self.overloads = overloads;
}

"""Initialize obviously."""
impl Parameter.init(
    self: Parameter,
    name: str,
    category: ParameterCategory,
    param_type: (TypeBase | None),
    default_value: (Expr | None) = None,
    is_self: bool = False,
    is_cls: bool = False,
    param_kind: ParamKind = ParamKind.NORMAL
) -> None {
    super.init();
    self.name = name;
    self.category = category;
    self.default_value = default_value;
    self.param_type = param_type;
    self.is_self = is_self;
    self.is_cls = is_cls;
    self.param_kind: ParamKind = param_kind;
}

"""Return true if this class is the built-in Node type."""
impl ClassType.is_node_type(self: ClassType) -> bool {
    import jaclang.pycore.unitree as uni;
    import from jaclang.pycore.constant { SymbolType }
    if self.shared.is_root_class {
        return True;
    }
    arch = self.shared.symbol_table;
    assert isinstance(arch, uni.Archetype);
    return (arch.sym_category == SymbolType.NODE_ARCH);
}

"""Return true if this class is the built-in Edge type."""
impl ClassType.is_edge_type(self: ClassType) -> bool {
    import jaclang.pycore.unitree as uni;
    import from jaclang.pycore.constant { SymbolType }
    arch = self.shared.symbol_table;
    assert isinstance(arch, uni.Archetype);
    return (arch.sym_category == SymbolType.EDGE_ARCH);
}

"""Return true if this class is a data class."""
impl ClassType.is_data_class(self: ClassType) -> bool {
    return self.shared.is_data_class;
}

"""
        Return true if this class is a builtin class.

        If class_name is provided, also check if the class name matches.
"""
impl ClassType.is_builtin(self: ClassType, class_name: (str | None) = None) -> bool {
    if not self.shared.is_builtin_class {
        return False;
    }
    if (class_name is not None) {
        return (self.shared.class_name == class_name);
    }
    return True;
}

"""Lookup a member in the class type."""
impl ClassType.lookup_member_symbol(
    self: ClassType, member: str, r_overloaded: list | None = None
) -> (Symbol | None) {
    for cls in self.shared.mro {
        members = cls.shared.symbol_table.names_in_scope;
        overloads = cls.shared.symbol_table.names_in_scope_overload;
        if (member in members) {
            if r_overloaded is not None and (member in overloads) {
                r_overloaded.extend(overloads[member]);
            }
            return members[member];
        }
    }
    return None;
}

"""Return the symbol representing the class."""
impl ClassType.get_class_symbol(self: ClassType) -> Symbol {
    return self.shared.symbol_table.name.sym;
}

"""Return a new class type specialized with the given type arguments."""
impl ClassType.specialize_generics(
    self: ClassType, type_args: list[TypeBase]
) -> ClassType {
    new_private = ClassType.ClassDetailsPrivate(type_args=type_args);
    return ClassType(self.shared, private=new_private, flags=self.flags);
}

impl ClassType.clone_as_class(self: ClassType) -> ClassType {
    if not self.is_instance() {
        return self;
    }
    private = ClassType.ClassDetailsPrivate(type_args=self.private.type_args[:]);
    new_flag = self.flags;
    new_flag = TypeFlags((new_flag & ~TypeFlags.Instance));
    new_flags = TypeFlags((new_flag | TypeFlags.Instantiable));
    new_class = ClassType(self.shared, private=private, flags=new_flags);
    return new_class;
}

"""Clone this class type as an instance type."""
impl ClassType.clone_as_instance(self: ClassType) -> ClassType {
    if self.is_instance() {
        return self;
    }
    private = ClassType.ClassDetailsPrivate(type_args=self.private.type_args[:]);
    new_instance = ClassType(self.shared, private=private, flags=self.flags);
    new_flag = self.flags;
    new_flag = TypeFlags((new_flag & ~TypeFlags.Instantiable));
    new_flags = TypeFlags((new_flag | TypeFlags.Instance));
    new_instance.flags = new_flags;
    return new_instance;
}

"""Return a string representation of the class type."""
impl ClassType.__str__(self: ClassType) -> str {
    return f"<class {self.shared.class_name}>";
}

"""Initialize the class type."""
impl ClassType.init(
    self: ClassType,
    shared: ClassType.ClassDetailsShared,
    private: (ClassType.ClassDetailsPrivate | None) = None,
    flags: TypeFlags = TypeFlags.Null
) -> None {
    super.init(flags=flags);
    self.shared = shared;
    self.private = private or ClassType.ClassDetailsPrivate();
}

"""Initialize obviously."""
impl ClassType.ClassDetailsPrivate.init(
    self: ClassType.ClassDetailsPrivate, type_args: (list[TypeBase] | None) = None
) -> None {
    self.type_args = type_args or [];
}

"""Initialize obviously."""
impl ClassType.ClassDetailsShared.init(
    self: ClassType.ClassDetailsShared,
    class_name: str,
    symbol_table: SymbolTable,
    *,
    type_params: (list[TypeVarType] | None) = None,
    base_classes: (list[TypeBase] | None) = None,
    is_builtin_class: bool = False,
    is_data_class: bool = False,
    is_root_class: bool = False
) -> None {
    self.class_name = class_name;
    self.symbol_table = symbol_table;
    self.type_params = type_params or [];
    self.base_classes = base_classes or [];
    self.mro: list[ClassType] = [];
    self.is_builtin_class = is_builtin_class;
    self.is_data_class = is_data_class;
    self.is_root_class = is_root_class;
}

"""Initialize obviously."""
impl TypeVarType.init(self: TypeVarType) -> None {
    super.init();
}

"""Initialize the class."""
impl ModuleType.init(
    self: ModuleType, mod_name: str, file_uri: Path, symbol_table: SymbolTable
) -> None {
    super.init();
    self.mod_name = mod_name;
    self.file_uri = file_uri;
    self.symbol_table = symbol_table;
}

"""Return whether the class is an instance."""
impl TypeBase.is_class_instance(self: TypeBase) -> bool {
    return ((self.category == TypeCategory.Class) and self.is_instance());
}

"""Return whether the class can be instantiated."""
impl TypeBase.is_instantiable_class(self: TypeBase) -> bool {
    return ((self.category == TypeCategory.Class) and self.is_instantiable());
}

"""Return whether the type is an instance."""
impl TypeBase.is_instance(self: TypeBase) -> bool {
    return bool((self.flags & TypeFlags.Instance));
}

"""Return whether the type is instantiable."""
impl TypeBase.is_instantiable(self: TypeBase) -> bool {
    return bool((self.flags & TypeFlags.Instantiable));
}

"""Return an instance of an unknown type."""
impl TypeBase.unknown -> UnknownType {
    return UnknownType();
}

"""Returns the category of the type."""
impl TypeBase.category(self: TypeBase) -> TypeCategory {
    return self.CATEGORY;
}

"""Initialize obviously."""
impl TypeBase.init(self: TypeBase, flags: TypeFlags = TypeFlags.Null) -> None {
    self.flags: TypeFlags = flags;
}
