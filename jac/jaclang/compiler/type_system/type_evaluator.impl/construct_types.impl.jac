impl TypeEvaluator._get_type_of_root(node_: uni.SpecialVarRef) -> TypeBase {
    if self.prefetch and self.prefetch.root_class {
        node_.sym = self.prefetch.root_class.get_class_symbol();
        node_.type = self.prefetch.root_class.clone_as_instance();
        return node_.type;
    }
    return types.UnknownType();
}

impl TypeEvaluator._get_type_of_self(node_: uni.SpecialVarRef) -> TypeBase {
    if method := self._get_enclosing_method(node_) {
        cls = method.method_owner;

        if isinstance(cls, uni.Archetype) {
            node_.sym = type_utils.lookup_symtab(
                method, node_.value, self.builtins_module
            );
            node_.type = self.get_type_of_class(cls).clone_as_instance();
            return node_.type;
        }

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

impl TypeEvaluator._get_type_of_super(node_: uni.SpecialVarRef) -> TypeBase {
    if method := self._get_enclosing_method(node_) {
        cls = method.method_owner;
        if isinstance(cls, uni.Archetype) {
            current_class_type = self.get_type_of_class(cls);

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

impl TypeEvaluator._get_type_of_lhs_assignment(expr: uni.Name) -> TypeBase | None {
    import from jaclang.compiler.symbol_utils { find_destructure_index_path }

    if expr.sym is not None and expr.sym.decl is expr {
        return None;
    }

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

    if assignment.aug_op is not None {
        return None;
    }

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

    if lhs_root is expr {
        return self.get_type_of_expression(assignment.value);
    }

    path = find_destructure_index_path(lhs_root, expr.value);
    if path is None or len(path) == 0 {
        return None;
    }
    return self._extract_tuple_element_type_path(
        self.get_type_of_expression(assignment.value), path
    );
}

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

impl TypeEvaluator._get_iterable_element_type(
    iterable_type: TypeBase, node_for_error: uni.Expr | None = None
) -> TypeBase | None {
    iter_type = self.get_type_of_magic_method_call(
        iterable_type, "__iter__", [], node_for_error
    );
    if not isinstance(iter_type, types.ClassType) {
        return None;
    }
    next_type = self.get_type_of_magic_method_call(
        iter_type, "__next__", [], node_for_error
    );
    if next_type and not isinstance(next_type, types.UnknownType) {
        return self._convert_to_instance(next_type);
    }
    if iter_type.private
    and iter_type.private.type_args
    and len(iter_type.private.type_args) == 1 {
        elem_type = iter_type.private.type_args[0];

        if isinstance(elem_type, types.TypeVarType)
        and isinstance(iterable_type, types.ClassType)
        and iterable_type.private.type_args {
            specialized = iter_type.specialize_generics(
                iterable_type.private.type_args
            );
            if len(specialized.private.type_args) == 1 {
                elem_type = specialized.private.type_args[0];
            }
        }
        return self._convert_to_instance(elem_type);
    }
    return None;
}

impl TypeEvaluator._native_iter_next_result(expr: uni.FuncCall) -> TypeBase | None {
    if not (
        isinstance(expr.target, uni.Name)
        and expr.target.value in ("iter", "next")
        and len(expr.params or []) == 1
    ) {
        return None;
    }
    sym = expr.target.sym;
    if sym is None or sym.parent_tab is not self.na_builtins_module {
        return None;
    }
    arg = expr.params[0];

    if isinstance(arg, uni.KWPair) {
        return None;
    }
    arg_expr = arg;
    arg_type = self.get_type_of_expression(arg_expr);
    if isinstance(arg_type, types.UnknownType) {
        return None;
    }
    elem = self._get_iterable_element_type(arg_type, arg_expr);
    if elem is None {
        return None;
    }
    if expr.target.value == "next" {
        return elem;
    }
    iter_cls = self._get_type_from_module(self.na_builtins_module, "Iterator");
    if not isinstance(iter_cls, types.ClassType) {
        return None;
    }
    return self._convert_to_instance(iter_cls.specialize_generics([elem]));
}

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

impl TypeEvaluator.get_type_of_float(nd: uni.Float) -> TypeBase {
    assert self.prefetch.float_class is not None;
    return self.prefetch.float_class;
}

impl TypeEvaluator.get_type_of_int(nd: uni.Int) -> TypeBase {
    assert self.prefetch.int_class is not None;
    return self.prefetch.int_class;
}

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
            is_async=node_.is_async,
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

    def _get_param_category(param: uni.ParamVar) -> types.ParameterCategory {
        if param.is_vararg {
            return types.ParameterCategory.ArgsList;
        }
        if param.is_kwargs {
            return types.ParameterCategory.KwargsDict;
        }
        return types.ParameterCategory.Positional;
    }

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
        param_type: TypeBase | None = None;

        if param.type_tag {
            param_type_cls = self.get_type_of_expression(param.type_tag.tag);
            param_type = self._convert_to_instance(param_type_cls);
        }

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
        is_async=node_.is_async,
    );
    func_type = self._apply_function_decorators(node_, func_type);
    node_.name_spec.type = func_type;
    return func_type;
}

impl TypeEvaluator._apply_function_decorators(
    node_: uni.Ability, func_type: types.FunctionType
) -> types.FunctionType {
    import from jaclang.compiler.type_system.type_utils { apply_solved_type_vars }
    if not node_.decorators {
        return func_type;
    }
    for decorator in node_.decorators {
        decorator_type = self.get_type_of_expression(decorator);
        if not isinstance(decorator_type, types.FunctionType) {
            continue;
        }
        params = decorator_type.parameters or [];

        if len(params) != 1
        or not isinstance(params[0].param_type, types.FunctionType)
        or not isinstance(decorator_type.return_type, types.FunctionType) {
            continue;
        }
        bindings: dict[str, TypeBase] = {};
        self.assign_type_to_type_var(params[0].param_type, func_type, bindings);
        decorated = apply_solved_type_vars(decorator_type.return_type, bindings);
        if isinstance(decorated, types.FunctionType) {
            func_type = decorated;
        }
    }
    return func_type;
}

impl TypeEvaluator.get_type_of_class(node_: uni.Archetype) -> types.ClassType {
    if node_.name_spec.type is not None {
        return cast(types.ClassType, node_.name_spec.type);
    }

    type_params = self._extract_type_params(node_);
    base_classes: list[TypeBase] = [];
    for base_class in node_.base_classes or [] {
        base_class_type = self.get_type_of_expression(base_class);
        base_classes.append(base_class_type);
    }

    parent_module = node_.find_parent_of_type(uni.Module);
    mod_flags = type_utils.compute_module_source_flags(
        parent_module.loc.mod_path if parent_module and parent_module.loc else ""
    );
    is_builtin_class = mod_flags.is_builtin_stub;
    is_from_stdlib_stub = mod_flags.is_stdlib_stub;

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

    if not base_classes and self.prefetch and self.prefetch.object_class {
        is_object_class = is_builtin_class and node_.name_spec.sym_name == "object";
        if not is_object_class {
            base_classes.append(self.prefetch.object_class);
        }
    }

    is_data_class = node_.sym_category != SymbolType.TYPE;

    is_enum_class = any(
        isinstance(base, types.ClassType) and base.shared.is_enum_class
        for base in base_classes
    );

    is_namedtuple = any(
        isinstance(base, types.ClassType)
        and base.shared.is_builtin_class
        and base.shared.class_name == "NamedTuple" for base in base_classes
    );

    is_typeddict = any(
        isinstance(base, types.ClassType) and base.shared.is_typeddict
        for base in base_classes
    )
    or self._has_typeddict_special_form_base(node_);
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
            is_typeddict=is_typeddict,
            is_enum_class=is_enum_class,
            enum_value_type=enum_value_type,
            enum_members=enum_members,
        ),
        flags=types.TypeFlags.Instantiable,
    );

    type_utils.compute_mro_linearization(cls_type);

    if is_typeddict {
        cls_type.shared.typeddict_fields = self._build_typeddict_fields(cls_type);
    }

    node_.name_spec.type = cls_type;
    return cls_type;
}

impl TypeEvaluator.get_type_of_enum(node_: uni.Enum) -> types.ClassType {
    if node_.name_spec.type is not None {
        return cast(types.ClassType, node_.name_spec.type);
    }

    base_classes: list[types.TypeBase] = [];

    if node_.value_type {
        base_classes.append(self.get_type_of_expression(node_.value_type));
    }
    for base_class in node_.base_classes or [] {
        base_class_type = self.get_type_of_expression(base_class);
        base_classes.append(base_class_type);
    }

    if not node_.base_classes and self.prefetch and self.prefetch.enum_class {
        base_classes.append(self.prefetch.enum_class);
    }

    enum_value_type = enum_utils.get_special_enum_value_type_from_bases(
        base_classes, self.prefetch
    );

    enum_members = enum_utils.build_enum_members(node_, self, enum_value_type);

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

    node_.name_spec.type = cls_type;
    return cls_type;
}

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
