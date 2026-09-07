impl TypeEvaluator._get_type_of_root(node_: SpecialVarRef) -> TypeBase {
    if self.prefetch and self.prefetch.root_class {
        node_.sym = self.prefetch.root_class.get_class_symbol();
        node_.type = self.prefetch.root_class.clone_as_instance();
        return node_.type;
    }
    return UnknownType();
}

impl TypeEvaluator._get_type_of_self(node_: Name) -> TypeBase {
    if method := self._get_enclosing_method(node_) {
        cls = method.method_owner;

        if isinstance(cls, Archetype) {
            node_.sym = lookup_symtab(method, node_.value, self.builtins_module);
            node_.type = self.get_type_of_class(cls).clone_as_instance();
            return node_.type;
        }

        if isinstance(cls, Enum) {
            node_.sym = lookup_symtab(method, node_.value, self.builtins_module);
            node_.type = self.get_type_of_enum(cls).clone_as_instance();
            return node_.type;
        }
    }
    return UnknownType();
}

impl TypeEvaluator._get_type_of_super(node_: Name) -> TypeBase {
    if method := self._get_enclosing_method(node_) {
        cls = method.method_owner;
        if isinstance(cls, Archetype) {
            current_class_type = self.get_type_of_class(cls);

            rest = current_class_type.shared.mro[1:];
            if rest {
                node_.sym = lookup_symtab(method, node_.value, self.builtins_module);
                node_.type = self._super_owner_for(node_, rest).clone_as_instance();
                return node_.type;
            }
        }
    }
    return UnknownType();
}

impl TypeEvaluator._get_type_of_lhs_assignment(expr: Name) -> TypeBase | None {
    import from jaclang.compiler.symbol_utils { find_destructure_index_path }

    if expr.sym is not None and expr.sym.decl is expr {
        return None;
    }

    parent = expr.parent;
    lhs_root: UniNode = expr;
    while isinstance(parent, (TupleVal, ListVal, AtomUnit)) {
        lhs_root = parent;
        parent = parent.parent;
    }
    if not isinstance(parent, Assignment) or not isinstance(parent.value, Expr) {
        return None;
    }
    assignment = parent;
    value = parent.value;

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
        return self.get_type_of_expression(value);
    }

    path = find_destructure_index_path(lhs_root, expr.value);
    if path is None or len(path) == 0 {
        return None;
    }
    return self._extract_tuple_element_type_path(
        self.get_type_of_expression(value), path
    );
}

impl TypeEvaluator._extract_tuple_element_type(
    tuple_type: TypeBase, idx: int
) -> TypeBase | None {
    if idx < 0 {
        return None;
    }
    if tuple_type.is_any_instance() {
        return tuple_type;
    }

    if isinstance(tuple_type, AnyType) {
        return AnyType(is_foreign=tuple_type.is_foreign);
    }
    if isinstance(tuple_type, UnknownType) {
        return UnknownType(
            is_diagnosed=tuple_type.is_diagnosed, is_incomplete=tuple_type.is_incomplete
        );
    }
    if isinstance(tuple_type, UnionType) {
        elements: list[TypeBase] = [];
        for member in tuple_type.types {
            element = self._extract_tuple_element_type(member, idx);
            if element is None {
                return None;
            }
            self._collect_unique_types(element, elements);
        }
        if not elements {
            return None;
        }
        return elements[0] if len(elements) == 1 else UnionType(types=elements);
    }
    if not isinstance(tuple_type, ClassType) {
        return None;
    }
    cls: ClassType = tuple_type;
    if cls.is_namedtuple() {
        scope = cls.shared.symbol_table;
        if not isinstance(scope, Archetype) {
            return None;
        }
        has_vars = scope.get_has_vars();
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
    if (
        cls.is_builtin("tuple")
        and cls.private.type_args
        and self._tuple_has_variadic_arg(cls)
    ) {
        return self._convert_to_instance(cls.private.type_args[0]);
    }
    if cls.private.type_args and idx < len(cls.private.type_args) {
        return self._convert_to_instance(cls.private.type_args[idx]);
    }
    return None;
}

impl TypeEvaluator._tuple_has_variadic_arg(cls: ClassType) -> bool {
    for ta in cls.private.type_args or [] {
        if isinstance(ta, UnknownType) {
            return True;
        }
    }
    return False;
}

impl TypeEvaluator._tuple_literal_index_type(
    base_type: TypeBase, subscript_arg: Expr
) -> TypeBase | None {
    if not isinstance(base_type, ClassType) or not base_type.is_class_instance() {
        return None;
    }
    cls: ClassType = base_type;
    if not (
        cls.is_builtin("tuple")
        and cls.private.type_args
        and not self._tuple_has_variadic_arg(cls)
    ) {
        return None;
    }

    idx_val: int | None = None;
    if isinstance(subscript_arg, Int) {
        idx_val = subscript_arg.lit_value;
    } elif (
        isinstance(subscript_arg, UnaryExpr)
        and isinstance(subscript_arg.op, Token)
        and subscript_arg.op.name == Tok.MINUS
        and isinstance(subscript_arg.operand, Int)
    ) {
        idx_val = -subscript_arg.operand.lit_value;
    }
    if idx_val is None {
        return None;
    }

    length = len(cls.private.type_args);
    real_idx = idx_val if idx_val >= 0 else length + idx_val;
    if real_idx < 0 or real_idx >= length {
        return None;
    }
    return self._extract_tuple_element_type(cls, real_idx);
}

impl TypeEvaluator._get_iterable_element_type(
    iterable_type: TypeBase, node_for_error: UniNode | None = None
) -> TypeBase | None {
    if iterable_type.is_any_instance() {
        return iterable_type;
    }
    if isinstance(iterable_type, AnyType) {
        return AnyType(is_foreign=iterable_type.is_foreign);
    }

    if isinstance(iterable_type, UnknownType) {
        return UnknownType(
            is_diagnosed=iterable_type.is_diagnosed,
            is_incomplete=iterable_type.is_incomplete
        );
    }
    if isinstance(iterable_type, ClassType) {
        members: list[TypeBase] = [];
        if iterable_type.is_namedtuple() {
            scope = iterable_type.shared.symbol_table;
            if isinstance(scope, Archetype) {
                for field in scope.get_has_vars() {
                    if field.type_tag is not None {
                        members.append(
                            self._convert_to_instance(
                                self.get_type_of_expression(field.type_tag.tag)
                            )
                        );
                    }
                }
            }
        } elif iterable_type.is_builtin("tuple") {
            if iterable_type.private.type_args
                and self._tuple_has_variadic_arg(iterable_type) {
                return self._extract_tuple_element_type(iterable_type, 0);
            }
            members = [
                self._convert_to_instance(arg)
                for arg in iterable_type.private.type_args
            ];
        }
        if members {
            return members[0] if len(members) == 1 else UnionType(types=members);
        }
    }
    iter_type = self.get_type_of_magic_method_call(
        iterable_type, "__iter__", [], node_for_error
    );
    if not isinstance(iter_type, ClassType) {
        return None;
    }
    next_type = self.get_type_of_magic_method_call(
        iter_type, "__next__", [], node_for_error
    );
    if next_type and not isinstance(next_type, UnknownType) {
        return self._convert_to_instance(next_type);
    }
    if iter_type.private
        and iter_type.private.type_args
        and len(iter_type.private.type_args) == 1 {
        elem_type = iter_type.private.type_args[0];

        if isinstance(elem_type, TypeVarType)
            and isinstance(iterable_type, ClassType)
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

impl TypeEvaluator._native_iter_next_result(expr: FuncCall) -> TypeBase | None {
    if not (
        isinstance(expr.target, Name)
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

    if isinstance(arg, KWPair) {
        return None;
    }
    arg_expr = arg;
    arg_type = self.get_type_of_expression(arg_expr);
    if isinstance(arg_type, UnknownType) {
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
    if not isinstance(iter_cls, ClassType) {
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

impl TypeEvaluator.get_type_of_float(nd: Float) -> TypeBase {
    assert self.prefetch.float_class is not None;
    return self.prefetch.float_class;
}

impl TypeEvaluator.get_type_of_int(nd: Int) -> TypeBase {
    assert self.prefetch.int_class is not None;
    return self.prefetch.int_class;
}

impl TypeEvaluator.get_type_of_ability(node_: Ability) -> TypeBase {
    if node_.name_spec.type is not None {
        return node_.name_spec.type;
    }
    func_type_params: list[TypeVarType] | None = None;
    if node_.type_params {
        func_type_params = [
            TypeVarType(
                name=tp.sym_name,
                bound=self._convert_to_instance(self.get_type_of_expression(tp.bound))
                    if tp.bound
                    else None
            ) for tp in node_.type_params
        ];
    }
    if not isinstance(node_.signature, FuncSignature) {
        flags = FunctionTypeFlags.Null;
        if node_.is_static {
            flags = flags | FunctionTypeFlags.StaticMethod;
        }
        func_type = FunctionType(
            func_name=node_.name_spec.sym_name,
            return_type=self.get_none_type(),
            parameters=[],
            function_flags=flags,
            type_params=func_type_params,
            is_async=node_.is_async,
        );
        node_.name_spec.type = func_type;
        return node_.name_spec.type;
    }
    return_type: TypeBase = self.get_none_type();
    if isinstance(node_.signature.return_type, Expr) {
        return_type = self._convert_to_instance(
            self.get_type_of_expression(node_.signature.return_type)
        );
    }

    def _get_param_category(param: ParamVar) -> ParameterCategory {
        if param.is_vararg {
            return ParameterCategory.ArgsList;
        }
        if param.is_kwargs {
            return ParameterCategory.KwargsDict;
        }
        return ParameterCategory.Positional;
    }

    def _convert_param_kind(kind: UniParamKind) -> ParamKind {
        match kind {
            case UniParamKind.POSONLY:
                return ParamKind.POSONLY;

            case UniParamKind.NORMAL:
                return ParamKind.NORMAL;

            case UniParamKind.VARARG:
                return ParamKind.VARARG;

            case UniParamKind.KWONLY:
                return ParamKind.KWONLY;

            case UniParamKind.KWARG:
                return ParamKind.KWARG;

        }
    }

    if node_.find_parent_of_type(Import) is not None {
        extern_params: list[Parameter] = [];
        ret_type: TypeBase = AnyType(is_foreign=True);
        if isinstance(node_.signature, FuncSignature) {
            for extern_param in node_.signature.get_parameters() {
                extern_params.append(
                    Parameter(
                        name=extern_param.name.value,
                        category=_get_param_category(extern_param),
                        param_type=self._extern_scalar_type(
                            extern_param.type_tag.tag if extern_param.type_tag else None
                        ),
                        default_value=extern_param.value,
                        param_kind=_convert_param_kind(extern_param.param_kind),
                    )
                );
            }
            ret_type = self._extern_scalar_type(node_.signature.return_type);
        }
        extern_fn = FunctionType(
            func_name=node_.name_spec.sym_name,
            return_type=ret_type,
            parameters=extern_params,
        );
        node_.name_spec.type = extern_fn;
        return extern_fn;
    }
    parameters: list[Parameter] = [];
    for (idx, param) in enumerate(node_.signature.get_parameters()) {
        param_type: TypeBase | None = None;

        if param.type_tag {
            param_type_cls = self.get_type_of_expression(param.type_tag.tag);
            param_type = self._convert_to_instance(param_type_cls);
        }

        is_cls_param = (
            idx == 0
            and (
                self._is_ability_classmethod(node_)
                or (
                    isinstance(param.name, Name)
                    and param.name.value == "cls"
                    and node_.name_spec.sym_name == "__new__"
                )
            )
        );

        is_self_param = (
            idx == 0
            and not is_cls_param
            and (
                self._is_expr_self(param.name)
                or (
                    isinstance(param.name, Name)
                    and param.name.value == "self"
                    and node_.signature is not None
                    and not node_.signature.is_static
                )
                or (
                    node_.is_method
                    and node_.signature is not None
                    and node_.signature.is_in_py_class
                    and param.param_kind in (UniParamKind.POSONLY, UniParamKind.NORMAL)
                    and node_.name_spec.sym_name
                        not in ("__new__", "__init_subclass__", "__class_getitem__")
                    and not self._is_ability_staticmethod(node_)
                )
            )
        );
        parameters.append(
            Parameter(
                name=param.name.value,
                category=_get_param_category(param),
                param_type=param_type,
                default_value=param.value,
                is_self=is_self_param,
                is_cls=is_cls_param,
                param_kind=_convert_param_kind(param.param_kind),
                is_comptime=param.is_comptime,
            )
        );
    }

    flags = FunctionTypeFlags.Null;
    if self._is_ability_staticmethod(node_) {
        flags = flags | FunctionTypeFlags.StaticMethod;
    }
    if self._is_ability_classmethod(node_) {
        flags = flags | FunctionTypeFlags.ClassMethod;
    }
    guarded_type: TypeBase | None = None;
    guard_is_strict = False;
    guard_form = self._type_guard_form_of(return_type);
    if guard_form is not None {
        assert isinstance(return_type, ClassType);
        guard_args = return_type.private.type_args or [];
        if guard_args {
            guarded_type = guard_args[0];
            guard_is_strict = guard_form == "TypeIs";
        }
        return_type = self._unwrap_type_guard_return(return_type);
    }
    func_type = FunctionType(
        func_name=node_.name_spec.sym_name,
        return_type=return_type,
        parameters=parameters,
        function_flags=flags,
        type_params=func_type_params,
        is_async=node_.is_async,
        type_guard=guarded_type,
        type_guard_is_strict=guard_is_strict,
    );
    func_type = self._apply_function_decorators(node_, func_type);
    node_.name_spec.type = func_type;
    return func_type;
}

impl TypeEvaluator._apply_function_decorators(
    node_: Ability, func_type: FunctionType
) -> FunctionType {
    import from jaclang.compiler.types.type_utils { apply_solved_type_vars }
    if not node_.decorators {
        return func_type;
    }
    for decorator in node_.decorators {
        decorator_type = self.get_type_of_expression(decorator);
        if not isinstance(decorator_type, FunctionType) {
            continue;
        }
        params = decorator_type.parameters or [];

        if len(params) != 1
            or not isinstance(params[0].param_type, FunctionType)
            or not isinstance(decorator_type.return_type, FunctionType) {
            continue;
        }
        bindings: dict[str, TypeBase] = {};
        self.assign_type_to_type_var(params[0].param_type, func_type, bindings);
        decorated = apply_solved_type_vars(decorator_type.return_type, bindings);
        if isinstance(decorated, FunctionType) {
            func_type = decorated;
        }
    }
    return func_type;
}

impl TypeEvaluator.get_type_of_class(node_: Archetype) -> ClassType {
    if node_.name_spec.type is not None {
        return cast(ClassType, node_.name_spec.type);
    }

    type_params = self._extract_type_params(node_);
    base_classes: list[TypeBase] = [];
    for base_class in node_.base_classes or [] {
        base_class_type = self.get_type_of_expression(base_class);
        base_classes.append(base_class_type);
    }

    parent_module = node_.find_parent_of_type(Module);
    mod_flags = compute_module_source_flags(
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
        isinstance(base, ClassType)
            and (
                base.shared.is_enum_class
                or (
                    self.prefetch.enum_class is not None
                    and any(
                        ancestor.shared.same_class(self.prefetch.enum_class.shared)
                        for ancestor in base.shared.mro
                    )
                )
            ) for base in base_classes
    );

    is_namedtuple = any(
        isinstance(base, ClassType)
            and base.shared.is_builtin_class
            and base.shared.class_name == "NamedTuple" for base in base_classes
    );

    is_typeddict = any(
        isinstance(base, ClassType) and base.shared.is_typeddict
        for base in base_classes
    )
        or self._has_typeddict_special_form_base(node_);
    enum_members: dict[str, EnumMemberInfo] | None = None;
    enum_value_type: TypeBase | None = None;
    if is_enum_class {
        enum_value_type = get_special_enum_value_type_from_bases(
            base_classes, self.prefetch
        );
        enum_members = build_enum_members(node_, self, enum_value_type);
    }
    cls_type = ClassType(
        _shared=self._intern_shared(
            ClassDetailsShared(
                class_name=node_.name_spec.sym_name,
                symbol_table=node_,
                type_params=type_params,
                ct_params=self._extract_ct_params(node_),
                base_classes=base_classes,
                is_builtin_class=is_builtin_class,
                is_from_stdlib_stub=is_from_stdlib_stub,
                is_data_class=is_data_class,
                is_namedtuple=is_namedtuple,
                is_typeddict=is_typeddict,
                is_enum_class=is_enum_class,
                enum_value_type=enum_value_type,
                enum_members=enum_members,
            )
        ),
        flags=TypeFlags.Instantiable,
    );

    compute_mro_linearization(cls_type);

    if is_typeddict {
        cls_type.shared.typeddict_fields = self._build_typeddict_fields(cls_type);
    }

    node_.name_spec.type = cls_type;
    return cls_type;
}

impl TypeEvaluator.get_type_of_enum(node_: Enum) -> ClassType {
    if node_.name_spec.type is not None {
        return cast(ClassType, node_.name_spec.type);
    }

    base_classes: list[TypeBase] = [];

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

    enum_value_type = get_special_enum_value_type_from_bases(
        base_classes, self.prefetch
    );

    enum_members = build_enum_members(node_, self, enum_value_type);

    parent_module = node_.find_parent_of_type(Module);
    mod_flags = compute_module_source_flags(
        parent_module.loc.mod_path if parent_module and parent_module.loc else ""
    );
    cls_type = ClassType(
        _shared=self._intern_shared(
            ClassDetailsShared(
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
            )
        ),
        flags=TypeFlags.Instantiable,
    );
    compute_mro_linearization(cls_type);

    node_.name_spec.type = cls_type;
    return cls_type;
}

impl TypeEvaluator._get_type_from_module(module: Module, name: str) -> TypeBase {
    if (symbol := lookup_symtab(module, name, self.builtins_module)) is not None {
        return self.get_type_of_symbol(symbol);
    }
    return UnknownType();
}

impl TypeEvaluator.get_none_type -> TypeBase {
    if self.prefetch and self.prefetch.none_type_class {
        return self.prefetch.none_type_class;
    }
    return UnknownType();
}


impl TypeEvaluator._super_owner_for(node_: Name, rest: list[ClassType]) -> ClassType {
    import from jaclang.compiler.types.type_utils { collect_member_syms }
    parent = node_.parent;
    member_name: str | None = None;
    if isinstance(parent, AtomTrailer) and isinstance(parent.right, Name) {
        member_name = parent.right.value;
    }
    if member_name is None {
        return rest[0];
    }
    lookup_names = [member_name];
    if member_name == "init" {
        lookup_names.append("__init__");
    }
    for candidate in rest {
        for nm in lookup_names {
            if collect_member_syms(candidate.shared.symbol_table, nm) {
                return candidate;
            }
        }
        if (
            member_name in ('init', '__init__')
            and candidate.is_data_class()
            and self._scope_has_fields(candidate.shared.symbol_table)
        ) {
            return candidate;
        }
    }
    return rest[0];
}

impl TypeEvaluator._extern_scalar_type(type_expr: Expr | None) -> TypeBase {
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    if isinstance(type_expr, Name) {
        name = type_expr.sym_name;
        if JAC_TYPE_REGISTRY.is_sized(name) {
            declared = self.get_type_of_expression(type_expr);
            if isinstance(declared, ClassType) {
                return self._convert_to_instance(declared);
            }
        }
        if JAC_TYPE_REGISTRY.is_numeric(name) {
            return AnyType(is_foreign=True, foreign_scalar=name);
        }
    }
    return AnyType(is_foreign=True);
}

impl TypeEvaluator._check_extern_ctor_args(expr: FuncCall, arch: Archetype) -> None {
    fields = arch.get_has_vars();
    by_name: dict[str, HasVar] = {};
    for hv in fields {
        by_name[hv.name.sym_name] = hv;
    }
    pos = 0;
    for param in expr.params {
        field: HasVar | None = None;
        arg: Expr;
        if isinstance(param, KWPair) {
            if param.key is None {
                continue;
            }
            field = by_name.get(param.key.sym_name);
            arg = param.value;
        } else {
            arg = param;
            field = fields[pos] if pos < len(fields) else None;
            pos += 1;
        }
        if field is None {
            continue;
        }
        dest = self._extern_field_type(field);
        if isinstance(dest, AnyType) and dest.foreign_scalar is None {
            continue;
        }
        src = self.get_type_of_expression(arg);
        verdict = self.assign_expr(arg, src, dest, strict=self._is_strict_site(arg));
        if not verdict.ok and not verdict.diagnosed {
            self.emit_diag(
                E1053,
                arg,
                actual=str(src),
                name=field.name.sym_name,
                expected=str(dest)
            );
        }
    }
}

impl TypeEvaluator._extern_member_type(arch: Archetype, name: str) -> TypeBase {
    for hv in arch.get_has_vars() {
        if hv.name.sym_name == name {
            return self._extern_field_type(hv);
        }
    }
    return AnyType(is_foreign=True);
}

impl TypeEvaluator._extern_field_type(field: HasVar) -> TypeBase {
    import from jaclang.compiler.types.types { create_callable_type }
    import from jaclang.compiler.types.fixed_width { numeric_name_of }
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    annotation = field.type_tag;
    if annotation is None {
        return AnyType(is_foreign=True);
    }
    tag = annotation.tag;
    declared = self.get_type_of_expression(tag);
    if isinstance(declared, FunctionType) {
        param_types: list[TypeBase] = [];
        typed = False;
        for p in declared.parameters or [] {
            parameter_type = p.param_type;
            pn = numeric_name_of(parameter_type);
            if parameter_type is not None
                and pn is not None
                and JAC_TYPE_REGISTRY.is_sized(pn) {
                param_types.append(parameter_type);
                typed = True;
            } else {
                param_types.append(AnyType(is_foreign=True, foreign_scalar=pn));
            }
        }
        return_type = declared.return_type;
        rn = numeric_name_of(return_type);
        ret_type: TypeBase = AnyType(is_foreign=True, foreign_scalar=rn);
        if return_type is not None
            and rn is not None
            and JAC_TYPE_REGISTRY.is_sized(rn) {
            ret_type = return_type;
            typed = True;
        }
        if typed {
            return create_callable_type(param_types, ret_type, is_gradual=False);
        }
        return AnyType(is_foreign=True);
    }
    return self._extern_scalar_type(tag);
}

impl TypeEvaluator._get_class_from_module(
    module: Module | None, name: str
) -> ClassType | None {
    if module is None {
        return None;
    }
    resolved = self._get_type_from_module(module, name);
    return resolved if isinstance(resolved, ClassType) else None;
}
