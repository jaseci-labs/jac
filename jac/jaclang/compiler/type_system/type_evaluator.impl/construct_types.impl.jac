"""Return the effective type of self."""
impl TypeEvaluator._get_type_of_self(node_: uni.SpecialVarRef) -> TypeBase {
    if method := self._get_enclosing_method(node_) {
        cls = method.method_owner;
        # self inside class method → instance of that class
        if isinstance(cls, uni.Archetype) {
            node_.sym = type_utils.lookup_symtab(
                method, node_.value, self.builtins_module
            );
            node_.type = self.get_type_of_class(cls).clone_as_instance();
            return node_.type;
        }
        # self inside enum method → instance of that enum
        if isinstance(cls, uni.Enum) {
            node_.sym = type_utils.lookup_symtab(
                method, node_.value, self.builtins_module
            );
            node_.type = self.get_type_of_enum(cls).clone_as_instance();
            return node_.type;
        }
    }
    return types.UnknownType();
}

"""Return the effective type of super (first parent class in MRO)."""
impl TypeEvaluator._get_type_of_super(node_: uni.SpecialVarRef) -> TypeBase {
    if method := self._get_enclosing_method(node_) {
        cls = method.method_owner;
        if isinstance(cls, uni.Archetype) {
            current_class_type = self.get_type_of_class(cls);
            # MRO[0] is current class, MRO[1] is first parent
            if len(current_class_type.shared.mro) > 1 {
                parent_class_type = current_class_type.shared.mro[1];
                node_.sym = type_utils.lookup_symtab(
                    method, node_.value, self.builtins_module
                );
                node_.type = parent_class_type.clone_as_instance();
                return node_.type;
            }
        }
    }
    return types.UnknownType();
}

"""Type an LHS Name receives from its enclosing assignment, or None.

Flat `x = e` returns the type of `e`. Destructure `(x, _) = e` (and
nested) descends the RHS tuple's `type_args` by positional path.

None is returned — callers keep the declared type — for the declaration
site itself (its cached `.type` doubles as the declared-type lookup for
`_get_type_of_symbol`), augmented assignments, member assignments,
starred slots, and RHS shapes that aren't a concrete positional tuple.
"""
impl TypeEvaluator._get_type_of_lhs_assignment(expr: uni.Name) -> TypeBase | None {
    import from jaclang.compiler.symbol_utils { find_destructure_index_path }
    # Declaration site: leave the cached declared type intact.
    if expr.sym is not None and expr.sym.decl is expr {
        return None;
    }
    # Peel destructure / paren wrappers to find the enclosing Assignment.
    parent = expr.parent;
    lhs_root: uni.UniNode = expr;
    while isinstance(parent, (uni.TupleVal, uni.ListVal, uni.AtomUnit)) {
        lhs_root = parent;
        parent = parent.parent;
    }
    if not isinstance(parent, uni.Assignment) or parent.value is None {
        return None;
    }
    assignment = parent;
    # `x += e` evaluates to `x <op> e` — defer to the declared type.
    if assignment.aug_op is not None {
        return None;
    }
    # Identity check — a TupleVal can appear on both sides, `in` uses equality.
    target_hit = False;
    for t in assignment.target {
        if t is lhs_root {
            target_hit = True;
            break;
        }
    }
    if not target_hit {
        return None;
    }
    # Flat: the Name is the target.
    if lhs_root is expr {
        return self.get_type_of_expression(assignment.value);
    }
    # Destructure: descend `type_args` by positional path.
    path = find_destructure_index_path(lhs_root, expr.value);
    if path is None or len(path) == 0 {
        return None;
    }
    return self._extract_tuple_element_type_path(
        self.get_type_of_expression(assignment.value), path
    );
}

"""Extract the element type at `idx` from a concrete tuple-like class.

Handles regular `tuple[T1, T2, ...]` via `private.type_args` and
NamedTuple via `is_namedtuple()` + `get_has_vars()`. Returns the
element as an instance, or None when `tuple_type` isn't a concrete
tuple with a valid slot at `idx`.
"""
impl TypeEvaluator._extract_tuple_element_type(
    tuple_type: TypeBase, idx: int
) -> TypeBase | None {
    if not isinstance(tuple_type, types.ClassType) or idx < 0 {
        return None;
    }
    cls: types.ClassType = tuple_type;
    if cls.is_namedtuple() {
        has_vars = cls.shared.symbol_table.get_has_vars();
        if idx >= len(has_vars) {
            return None;
        }
        field = has_vars[idx];
        if field.type_tag is None {
            return None;
        }
        return self._convert_to_instance(
            self.get_type_of_expression(field.type_tag.tag)
        );
    }
    if cls.private.type_args and idx < len(cls.private.type_args) {
        return self._convert_to_instance(cls.private.type_args[idx]);
    }
    return None;
}

"""Walk `tuple_type` through a positional index path and return the
element type at the leaf, or None if any step fails."""
impl TypeEvaluator._extract_tuple_element_type_path(
    tuple_type: TypeBase, path: list[int]
) -> TypeBase | None {
    cursor: TypeBase | None = tuple_type;
    for idx in path {
        if cursor is None {
            return None;
        }
        cursor = self._extract_tuple_element_type(cursor, idx);
    }
    return cursor;
}

"""Return the effective type of the float."""
impl TypeEvaluator.get_type_of_float(nd: uni.Float) -> TypeBase {
    assert self.prefetch.float_class is not None;
    return self.prefetch.float_class;
}

"""Return the effective type of the int."""
impl TypeEvaluator.get_type_of_int(nd: uni.Int) -> TypeBase {
    assert self.prefetch.int_class is not None;
    return self.prefetch.int_class;
}

"""Return the effective type of the string."""
impl TypeEvaluator.get_type_of_string(nd: uni.String | uni.MultiString) -> TypeBase {
    # FIXME: Strings are a type of LiteralString type:
    # "foo" is not `str` but Literal["foo"], however for now we'll
    # not considering that and make it work and will implement that
    # later.
    #
    # see: getTypeOfString() in pyright (it requires parsing the sub
    # file of the typing module).
    assert self.prefetch.str_class is not None;
    return self.prefetch.str_class;
}

"""Return the effective type of an ability."""
impl TypeEvaluator.get_type_of_ability(node_: uni.Ability) -> TypeBase {
    if node_.name_spec.type is not None {
        return node_.name_spec.type;
    }
    func_type_params: list[types.TypeVarType] | None = None;
    if node_.type_params {
        func_type_params = [
            types.TypeVarType(
                name=tp.sym_name,
                bound=self._convert_to_instance(self.get_type_of_expression(tp.bound))
                    if tp.bound
                    else None
            ) for tp in node_.type_params
        ];
    }
    if not isinstance(node_.signature, uni.FuncSignature) {
        flags = types.FunctionTypeFlags.Null;
        if node_.is_static {
            flags = flags | types.FunctionTypeFlags.StaticMethod;
        }
        func_type = types.FunctionType(
            func_name=node_.name_spec.sym_name,
            return_type=self.get_none_type(),
            parameters=None,
            function_flags=flags,
            type_params=func_type_params,
        );
        node_.name_spec.type = func_type;
        return node_.name_spec.type;
    }
    return_type: TypeBase = self.get_none_type();
    if isinstance(node_.signature.return_type, uni.Expr) {
        return_type = self._convert_to_instance(
            self.get_type_of_expression(node_.signature.return_type)
        );
    }
    # Define helper function for parameter conversion.
    def _get_param_category(param: uni.ParamVar) -> types.ParameterCategory {
        if param.is_vararg {
            return types.ParameterCategory.ArgsList;
        }
        if param.is_kwargs {
            return types.ParameterCategory.KwargsDict;
        }
        return types.ParameterCategory.Positional;
    }
    # Define helper function for parameter kind conversion.
    def _convert_param_kind(kind: uni.ParamKind) -> types.ParamKind {
        match kind {
            case uni.ParamKind.POSONLY:
                return types.ParamKind.POSONLY;

            case uni.ParamKind.NORMAL:
                return types.ParamKind.NORMAL;

            case uni.ParamKind.VARARG:
                return types.ParamKind.VARARG;

            case uni.ParamKind.KWONLY:
                return types.ParamKind.KWONLY;

            case uni.ParamKind.KWARG:
                return types.ParamKind.KWARG;
                return types.ParamKind.NORMAL;

        }
    }
    parameters: list[types.Parameter] = [];
    for (idx, param) in enumerate(node_.signature.get_parameters()) {
        # TODO: Set parameter category for *args, and **kwargs
        param_type: TypeBase | None = None;

        if param.type_tag {
            param_type_cls = self.get_type_of_expression(param.type_tag.tag);
            param_type = self._convert_to_instance(param_type_cls);
        }

        # For Python stub methods, check if first parameter is named 'self' or 'cls'
        # In addition to the Jac-specific checks
        # Note: For static methods, 'self' is just a regular parameter, not special
        is_self_param = (
            idx == 0
            and (
                self._is_expr_self(param.name)
                or (
                    isinstance(param.name, uni.Name)
                    and param.name.value == "self"
                    and node_.signature
                    and not node_.signature.is_static
                )
            )
        );
        is_cls_param = (
            idx == 0
            and (
                self._is_ability_classmethod(node_)
                or (
                    isinstance(param.name, uni.Name)
                    and param.name.value == "cls"
                    and node_.name_spec.sym_name == "__new__"
                )
            )
        );
        parameters.append(
            types.Parameter(
                name=param.name.value,
                category=_get_param_category(param),
                param_type=param_type,
                default_value=param.value,
                is_self=is_self_param,
                is_cls=is_cls_param,
                param_kind=_convert_param_kind(param.param_kind),
            )
        );
    }
    # Set function flags for static/class methods
    flags = types.FunctionTypeFlags.Null;
    if node_.is_static {
        flags = flags | types.FunctionTypeFlags.StaticMethod;
    }
    if self._is_ability_classmethod(node_) {
        flags = flags | types.FunctionTypeFlags.ClassMethod;
    }
    func_type = types.FunctionType(
        func_name=node_.name_spec.sym_name,
        return_type=return_type,
        parameters=parameters,
        function_flags=flags,
        type_params=func_type_params,
    );
    node_.name_spec.type = func_type;
    return func_type;
}

"""Return the effective type of the class."""
impl TypeEvaluator.get_type_of_class(node_: uni.Archetype) -> types.ClassType {
    # Is this type already cached?
    if node_.name_spec.type is not None {
        return cast(types.ClassType, node_.name_spec.type);
    }
    # Gather type parameters.
    type_params = self._extract_type_params(node_);
    base_classes: list[TypeBase] = [];
    for base_class in node_.base_classes or [] {
        base_class_type = self.get_type_of_expression(base_class);
        base_classes.append(base_class_type);
    }
    # Compute module flags using centralized helper (like Pyright's SourceFileInfo)
    parent_module = node_.find_parent_of_type(uni.Module);
    mod_flags = type_utils.compute_module_source_flags(
        parent_module.loc.mod_path if parent_module and parent_module.loc else ""
    );
    is_builtin_class = mod_flags.is_builtin_stub;
    is_from_stdlib_stub = mod_flags.is_stdlib_stub;
    # Add implicit base classes for Jac archetype keywords.
    # walker Foo {} → base_classes = [Walker]  (so .reports etc. are visible)
    # node Foo {}   → base_classes = [Node]
    if not base_classes and self.prefetch {
        if (
            node_.sym_category == SymbolType.WALKER_ARCH
            and self.prefetch.walker_class
            and not (is_builtin_class and node_.name_spec.sym_name == "Walker")
        ) {
            base_classes.append(self.prefetch.walker_class);
        } elif (
            node_.sym_category == SymbolType.NODE_ARCH
            and self.prefetch.node_class
            and not (is_builtin_class and node_.name_spec.sym_name == "Node")
        ) {
            base_classes.append(self.prefetch.node_class);
        }
    }
    # Add object as implicit base class (Every class inherits from object)
    if not base_classes and self.prefetch and self.prefetch.object_class {
        is_object_class = is_builtin_class and node_.name_spec.sym_name == "object";
        if not is_object_class {
            base_classes.append(self.prefetch.object_class);
        }
    }
    # NOTE: obj, walker, node, edge are dataclass with symbol type as such but
    # other classes are with symbol type TYPE.
    # TODO: We need to handle @dataclass decorator as well.
    is_data_class = node_.sym_category != SymbolType.TYPE;
    # Detect class-based enums: is_enum_class propagates from prefetched Enum.
    is_enum_class = any(
        isinstance(base, types.ClassType) and base.shared.is_enum_class
        for base in base_classes
    );
    # Detect NamedTuple subclasses: class X(NamedTuple) { ... }
    # Check both the name AND that it's a builtin class (from typing module)
    # to avoid false positives from user-defined classes named "NamedTuple"
    is_namedtuple = any(
        isinstance(base, types.ClassType)
        and base.shared.is_builtin_class
        and base.shared.class_name == "NamedTuple" for base in base_classes
    );
    enum_members: dict[str, types.EnumMemberInfo] | None = None;
    enum_value_type: types.TypeBase | None = None;
    if is_enum_class {
        enum_value_type = enum_utils.get_special_enum_value_type_from_bases(
            base_classes, self.prefetch
        );
        enum_members = enum_utils.build_enum_members(node_, self, enum_value_type);
    }
    cls_type = types.ClassType(
        _shared=types.ClassType.ClassDetailsShared(
            class_name=node_.name_spec.sym_name,
            symbol_table=node_,
            type_params=type_params,
            base_classes=base_classes,
            is_builtin_class=is_builtin_class,
            is_from_stdlib_stub=is_from_stdlib_stub,
            is_data_class=is_data_class,
            is_namedtuple=is_namedtuple,
            is_enum_class=is_enum_class,
            enum_value_type=enum_value_type,
            enum_members=enum_members,
        ),
        flags=types.TypeFlags.Instantiable,
    );
    # Compute the MRO for the class.
    type_utils.compute_mro_linearization(cls_type);
    # Cache the type, pyright is doing invalidateTypeCacheIfCanceled()
    # we're not doing that any time sooner.
    node_.name_spec.type = cls_type;
    return cls_type;
}

"""Build the type for an enum class."""
impl TypeEvaluator.get_type_of_enum(node_: uni.Enum) -> types.ClassType {
    # Return cached type if available
    if node_.name_spec.type is not None {
        return cast(types.ClassType, node_.name_spec.type);
    }
    # Collect base classes (Example: enum Color(IntEnum) → base_classes = [IntEnum])
    base_classes: list[types.TypeBase] = [];
    for base_class in node_.base_classes or [] {
        base_class_type = self.get_type_of_expression(base_class);
        base_classes.append(base_class_type);
    }
    # No base specified, Then add Enum as implicit base (Example: enum Color { RED=1 } → base_classes = [Enum])
    if not base_classes and self.prefetch and self.prefetch.enum_class {
        base_classes.append(self.prefetch.enum_class);
    }
    # Get required value type for special enums (IntEnum → int, StrEnum → str, IntFlag → int)
    enum_value_type = enum_utils.get_special_enum_value_type_from_bases(
        base_classes, self.prefetch
    );
    # Build member dictionary (RED=1, GREEN=2, etc.) with validation
    enum_members = enum_utils.build_enum_members(node_, self, enum_value_type);
    # Compute module flags using centralized helper (like Pyright's SourceFileInfo)
    parent_module = node_.find_parent_of_type(uni.Module);
    mod_flags = type_utils.compute_module_source_flags(
        parent_module.loc.mod_path if parent_module and parent_module.loc else ""
    );
    cls_type = types.ClassType(
        _shared=types.ClassType.ClassDetailsShared(
            class_name=node_.name_spec.sym_name,
            symbol_table=node_,
            type_params=None,
            base_classes=base_classes,
            is_builtin_class=mod_flags.is_builtin_stub,
            is_from_stdlib_stub=mod_flags.is_stdlib_stub,
            is_data_class=False,
            is_enum_class=True,
            enum_value_type=enum_value_type,
            enum_members=enum_members,
        ),
        flags=types.TypeFlags.Instantiable,
    );
    type_utils.compute_mro_linearization(cls_type);
    # Store in node for reuse
    node_.name_spec.type = cls_type;
    return cls_type;
}

"""Return the built-in type with the given name."""
impl TypeEvaluator._get_type_from_module(module: uni.Module, name: str) -> TypeBase {
    if (
        symbol := type_utils.lookup_symtab(module, name, self.builtins_module)
    ) is not None {
        return self.get_type_of_symbol(symbol);
    }
    return types.UnknownType();
}

impl TypeEvaluator.get_none_type -> TypeBase {
    if self.prefetch and self.prefetch.none_type_class {
        return self.prefetch.none_type_class;
    }
    return types.UnknownType();
}
