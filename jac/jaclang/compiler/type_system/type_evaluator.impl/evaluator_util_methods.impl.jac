impl TypeEvaluator._try_resolve_forward_ref(expr: String) -> TypeBase | None {
    name = expr.lit_value;
    if not isinstance(name, str) or not name {
        return None;
    }
    scope = expr.find_parent_of_type(UniScopeNode);
    if not scope {
        return None;
    }
    symbol = lookup_symtab(scope, name, self.builtins_module);
    if not symbol {
        return None;
    }
    symbol = self.resolve_imported_symbols(symbol);
    if not symbol.decl or not symbol.decl.name_of {
        return None;
    }

    resolved = self.get_type_of_symbol(symbol);
    if isinstance(resolved, UnknownType) {
        return None;
    }
    return resolved;
}

impl TypeEvaluator._type_from_union_annotation_arg(val: Expr) -> TypeBase {
    string_expr: String | None = None;
    if isinstance(val, MultiString) and val.strings {
        if (
            len(val.strings) == 1
            and isinstance(val.strings[0], String)
            and isinstance(val.strings[0].lit_value, str)
        ) {
            string_expr = val.strings[0];
        }
    } elif isinstance(val, String) and isinstance(val.lit_value, str) {
        string_expr = val;
    }
    if string_expr is not None {
        fwd = self._try_resolve_forward_ref(string_expr);
        if fwd is not None {
            return self._convert_to_instance(fwd);
        }
    }
    return self._convert_to_instance(self.get_type_of_expression(val));
}

impl TypeEvaluator._build_field_params(
    class_type: ClassType, skip_deferred: bool = True
) -> dict[str, Parameter] {
    import from jaclang.jac0core.codeinfo { NATIVE_ERASED_RIM_BASES }
    param_map: dict[str, Parameter] = {};
    _erase_rim = self._in_native_context();
    for cls in class_type.shared.mro[::-1] {
        if _erase_rim and cls.shared.class_name in NATIVE_ERASED_RIM_BASES {
            continue;
        }
        for has_var in cls.shared.symbol_table.get_has_vars() {
            if skip_deferred and has_var.defer {
                continue;
            }

            if has_var.accessors {
                continue;
            }
            param_type: TypeBase | None = None;
            if has_var.type_tag {
                var_type_expr = has_var.type_tag.tag;
                type_cls = self.get_type_of_expression(var_type_expr);
                param_type = self._convert_to_instance(type_cls);
            }
            param_map[has_var.name.value] = Parameter(
                name=has_var.name.value,
                category=ParameterCategory.Positional,
                param_type=param_type,
                default_value=has_var.value,
                is_self=False,
                param_kind=ParamKind.NORMAL,
            );
        }
    }
    return param_map;
}

impl TypeEvaluator._literal_type_from_expr(val: Expr) -> TypeBase | None {
    if not self.prefetch {
        return None;
    }

    if isinstance(val, Null) and self.prefetch.none_type_class {
        return self._convert_to_instance(self.prefetch.none_type_class);
    }
    base: ClassType | None = None;
    value: str | int | bool | None = None;

    if isinstance(val, Bool) {
        base = self.prefetch.bool_class;
        value = val.lit_value;
    } elif isinstance(val, Int) {
        base = self.prefetch.int_class;
        value = val.lit_value;
    } elif (
        isinstance(val, UnaryExpr)
        and val.op.name == Tok.MINUS
        and isinstance(val.operand, Int)
    ) {
        base = self.prefetch.int_class;
        value = -val.operand.lit_value;
    } elif isinstance(val, String) and isinstance(val.lit_value, str) {
        base = self.prefetch.str_class;
        value = val.lit_value;
    } elif isinstance(val, MultiString) {
        text = "";
        for s in val.strings {
            if not (isinstance(s, String) and isinstance(s.lit_value, str)) {
                return None;
            }
            text += s.lit_value;
        }
        base = self.prefetch.str_class;
        value = text;
    }
    if base is None {
        return None;
    }
    return self._convert_to_instance(base.clone_with_literal(value));
}

impl TypeEvaluator._build_typeddict_fields(
    class_type: ClassType
) -> dict[str, TypeBase] {
    fields: dict[str, TypeBase] = {};
    for cls in class_type.shared.mro[::-1] {
        if cls.shared.class_name == "TypedDict" {
            continue;
        }
        for has_var in cls.shared.symbol_table.get_has_vars() {
            if has_var.accessors {
                continue;
            }
            field_type: TypeBase = UnknownType();
            if has_var.type_tag {
                field_type = self._convert_to_instance(
                    self.get_type_of_expression(has_var.type_tag.tag)
                );
            }
            fields[has_var.name.value] = field_type;
        }
    }
    return fields;
}

impl TypeEvaluator._has_typeddict_special_form_base(node_: Archetype) -> bool {
    for base_expr in node_.base_classes or [] {
        base_name: str | None = None;
        if isinstance(base_expr, Name) {
            base_name = base_expr.value;
        } elif (
            isinstance(base_expr, AtomTrailer) and isinstance(base_expr.right, Name)
        ) {
            base_name = base_expr.right.value;
        }
        if base_name == "TypedDict" {
            base_t = self.get_type_of_expression(base_expr);
            if (
                isinstance(base_t, ClassType)
                and base_t.shared.class_name == "_SpecialForm"
            ) {
                return True;
            }
        }
    }
    return False;
}

impl TypeEvaluator._typeddict_value_union(base_type: ClassType) -> TypeBase {
    field_types = list((base_type.shared.typeddict_fields or {}).values());
    if not field_types {
        return UnknownType();
    }
    if len(field_types) == 1 {
        return field_types[0];
    }
    return UnionType(types=field_types);
}

impl TypeEvaluator._get_typeddict_indexed_type(
    base_type: ClassType, key_expr: Expr, err_node: UniNode
) -> TypeBase | None {
    key_type = self.get_type_of_expression(key_expr);
    if not (isinstance(key_type, ClassType) and key_type.is_builtin("str")) {
        return None;
    }
    fields = base_type.shared.typeddict_fields or {};
    lit = key_type.get_literal_value();
    if not isinstance(lit, str) {
        return self._typeddict_value_union(base_type);
    }
    if lit in fields {
        return fields[lit];
    }
    self.emit_diag(E1043, err_node, type=base_type.shared.class_name, key=lit);
    return UnknownType();
}

impl TypeEvaluator._synthesize_typeddict_method(
    base_type: ClassType, method: str
) -> OverloadedType | None {
    if not (self.prefetch and self.prefetch.str_class) {
        return None;
    }
    none_inst: TypeBase = UnknownType();
    if self.prefetch.none_type_class {
        none_inst = self._convert_to_instance(self.prefetch.none_type_class);
    }
    object_inst: TypeBase = UnknownType();
    if self.prefetch.object_class {
        object_inst = self._convert_to_instance(self.prefetch.object_class);
    }

    def param(name: str, ty: TypeBase, is_self: bool = False) -> Parameter {
        return Parameter(
            name=name,
            category=ParameterCategory.Positional,
            param_type=ty,
            is_self=is_self,
            param_kind=ParamKind.NORMAL if is_self else ParamKind.POSONLY,
        );
    }

    def func(params: list[Parameter], ret: TypeBase) -> FunctionType {
        return FunctionType(
            func_name=method,
            return_type=ret,
            parameters=params,
            function_flags=FunctionTypeFlags.SynthesizedMethod,
        );
    }

    self_p = param("self", base_type, is_self=True);
    default_p = param("default", object_inst);

    def overloads_for(key_ty: TypeBase, value: TypeBase) -> list[FunctionType] {
        key_p = param("key", key_ty);
        with_default = func([self_p, key_p, default_p], value);
        if method == "setdefault" {
            return [with_default];
        }
        return [
            func([self_p, key_p], UnionType(types=[value, none_inst])),
            with_default
        ];
    }

    overloads: list[FunctionType] = [];
    for (field_name, field_type) in (base_type.shared.typeddict_fields or {}).items() {
        key_lit = self._convert_to_instance(
            self.prefetch.str_class.clone_with_literal(field_name)
        );
        overloads.extend(overloads_for(key_lit, field_type));
    }
    str_inst = self._convert_to_instance(self.prefetch.str_class);
    overloads.extend(overloads_for(str_inst, self._typeddict_value_union(base_type)));
    return OverloadedType(overloads=overloads);
}

impl TypeEvaluator._typeddict_as_dict(base_type: ClassType) -> ClassType | None {
    if not (self.prefetch and self.prefetch.dict_class and self.prefetch.str_class) {
        return None;
    }
    str_inst = self._convert_to_instance(self.prefetch.str_class);
    dict_type = self.prefetch.dict_class.specialize_generics(
        [str_inst, self._typeddict_value_union(base_type)]
    );
    return self._convert_to_instance(dict_type);
}

impl TypeEvaluator._create_dataclass_init_method(
    class_type: ClassType
) -> FunctionType {
    param_map = self._build_field_params(class_type, skip_deferred=True);
    parameters = list(param_map.values());

    ret_type: TypeBase = UnknownType();
    if self.prefetch and self.prefetch.none_type_class {
        ret_type = self._convert_to_instance(self.prefetch.none_type_class);
    }
    return FunctionType(
        func_name="__init__", return_type=ret_type, parameters=parameters,
    );
}

impl TypeEvaluator._create_namedtuple_new_method(
    class_type: ClassType
) -> FunctionType {
    parameters: list[Parameter] = [];

    parameters.append(
        Parameter(
            name="cls",
            category=ParameterCategory.Positional,
            param_type=class_type,
            is_cls=True,
            param_kind=ParamKind.NORMAL,
        )
    );
    param_map = self._build_field_params(class_type, skip_deferred=False);
    parameters.extend(list(param_map.values()));
    return FunctionType(
        func_name="__new__",
        return_type=class_type.clone_as_instance(),
        parameters=parameters,
        function_flags=FunctionTypeFlags.SynthesizedMethod,
    );
}

impl TypeEvaluator._lookup_object_member(
    base_type: ClassType, member: str
) -> ClassMember | None {
    assert self.prefetch.int_class is not None;
    if isinstance(base_type, ClassType) and base_type.is_class_instance() {
        return self._lookup_class_member(base_type, member);
    }
    return None;
}

impl TypeEvaluator._lookup_class_member(
    base_type: ClassType, member: str
) -> ClassMember | None {
    for cls in base_type.shared.mro {
        overloaded_syms: list[Symbol] = [];
        if sym := cls.lookup_member_symbol(member, overloaded_syms) {
            return ClassMember(sym, cls, overloaded_syms);
        }
    }
    return None;
}

impl TypeEvaluator._is_type_subscript(class_type: ClassType) -> bool {
    return (
        class_type.is_builtin("type")
        and class_type.private.type_args is not None
        and len(class_type.private.type_args) >= 1
    );
}

impl TypeEvaluator._get_type_for_member_lookup(object_type: ClassType) -> ClassType {
    if self._is_type_subscript(object_type) {
        inner_type = object_type.private.type_args[0];

        if isinstance(inner_type, ClassType) {
            lookup_type = inner_type;
            if not lookup_type.is_instantiable() {
                lookup_type = lookup_type.clone_as_class();
            }
            return lookup_type;
        }
    }
    return object_type;
}

impl TypeEvaluator.get_type_of_member(
    member: ClassMember, class_type: ClassType
) -> TypeBase {
    raw_type = self.get_type_of_symbol(member.symbol);
    if isinstance(raw_type, FunctionType) {
        params = raw_type.parameters or [];
        is_static_cls = (
            len(params) >= 1
            and params[0].is_cls
            and not (raw_type.function_flags & FunctionTypeFlags.ClassMethod)
        );
        is_static = bool(raw_type.function_flags & FunctionTypeFlags.StaticMethod);
        if is_static_cls or is_static {
            solution = build_type_var_solution(class_type);
            return apply_solved_type_vars(
                raw_type,
                solution,
                None,
                shadowed_type_var_names(
                    solution, self.declaring_class_of(member.symbol, class_type)
                )
            );
        }
    }
    return self.specialize_member_type(
        raw_type, class_type, self.declaring_class_of(member.symbol, class_type)
    );
}

impl TypeEvaluator.declaring_class_of(
    symbol: Symbol, base_type: ClassType
) -> (ClassType | None) {
    if symbol.decl is None {
        return None;
    }
    arch = symbol.decl.find_parent_of_type(Archetype);
    if arch is None {
        return None;
    }
    for cls in base_type.shared.mro {
        if cls.shared.symbol_table is arch {
            return cls;
        }
    }
    return None;
}

impl TypeEvaluator.specialize_member_type(
    member_type: TypeBase,
    class_type: ClassType,
    declaring_class: (ClassType | None) = None
) -> TypeBase {
    solution = build_type_var_solution(class_type);

    return apply_solved_type_vars(
        member_type,
        solution,
        class_type,
        shadowed_type_var_names(solution, declaring_class)
    );
}

impl TypeEvaluator._get_getattr_return_type(base_type: ClassType) -> TypeBase | None {
    if member := self._lookup_class_member(base_type, "__getattr__") {
        getattr_type = self.get_type_of_symbol(member.symbol);
        if isinstance(getattr_type, FunctionType) {
            return getattr_type.return_type or UnknownType();
        }
    }
    return None;
}

impl TypeEvaluator._resolve_enum_value_type(enum_type: ClassType) -> TypeBase | None {
    val_type = enum_type.shared.enum_value_type;
    if val_type is None and enum_type.shared.enum_members {
        member_types = [
            m.value_type
            for m in enum_type.shared.enum_members.values()
            if m.value_type is not None
        ];
        if member_types
            and all(
                isinstance(t, ClassType)
                    and isinstance(member_types[0], ClassType)
                    and t.shared == member_types[0].shared for t in member_types
            ) {
            val_type = member_types[0];
        }
    }
    return val_type;
}

impl TypeEvaluator._synthesize_enum_metaclass_attr(
    enum_type: ClassType, attr_name: str
) -> TypeBase | None {
    if not (
        self.prefetch
        and self.prefetch.dict_class
        and self.prefetch.list_class
        and self.prefetch.str_class
    ) {
        return None;
    }
    str_inst = self._convert_to_instance(self.prefetch.str_class);
    if attr_name == "_member_names_" {
        list_type = self.prefetch.list_class.specialize_generics([str_inst]);
        return self._convert_to_instance(list_type);
    }
    if attr_name == "__members__" {
        member_inst = enum_type.clone_as_instance();
        if self.prefetch.mappingproxy_class {
            proxy_type = self.prefetch.mappingproxy_class.specialize_generics(
                [str_inst, member_inst]
            );
            return self._convert_to_instance(proxy_type);
        }
        dict_type = self.prefetch.dict_class.specialize_generics(
            [str_inst, member_inst]
        );
        return self._convert_to_instance(dict_type);
    }
    if attr_name == "_member_map_" {
        member_inst = enum_type.clone_as_instance();
        dict_type = self.prefetch.dict_class.specialize_generics(
            [str_inst, member_inst]
        );
        return self._convert_to_instance(dict_type);
    }
    if attr_name == "_value2member_map_" {
        member_inst = enum_type.clone_as_instance();
        val_type = self._resolve_enum_value_type(enum_type);
        key_type = (
            self._convert_to_instance(val_type)
                if val_type is not None
                else types.AnyType()
        );
        dict_type = self.prefetch.dict_class.specialize_generics(
            [key_type, member_inst]
        );
        return self._convert_to_instance(dict_type);
    }
    return None;
}

impl TypeEvaluator._convert_to_instance(jtype: TypeBase) -> TypeBase {
    return convert_to_instance(jtype);
}

impl TypeEvaluator._edge_endpoint_type(
    edge_type: ClassType, edge_dir: EdgeDir
) -> TypeBase | None {
    for cls in edge_type.shared.mro {
        arch = cls.shared.symbol_table;
        if not isinstance(arch, Archetype) {
            continue;
        }
        endpoint: Expr | None = None;
        if edge_dir == EdgeDir.OUT {
            endpoint = arch.tgt_endpoint;
        } elif edge_dir == EdgeDir.IN {
            endpoint = arch.src_endpoint;
        }
        if endpoint is not None {
            ep_type = self.get_type_of_expression(endpoint);
            if isinstance(ep_type, ClassType) {
                return ep_type;
            }
            return None;
        }
    }
    return None;
}

impl TypeEvaluator._type_in_list(ty: TypeBase, type_list: list[TypeBase]) -> bool {
    for existing in type_list {
        if isinstance(ty, ClassType) and isinstance(existing, ClassType) {
            if ty.shared == existing.shared {
                return True;
            }
        } elif ty is existing {
            return True;
        }
    }
    return False;
}

impl TypeEvaluator._collect_unique_types(ty: TypeBase, result: list[TypeBase]) -> None {
    if isinstance(ty, UnionType) {
        for member in ty.types {
            self._collect_unique_types(member, result);
        }
    } else {
        if not self._type_in_list(ty, result) {
            result.append(ty);
        }
    }
}

impl TypeEvaluator._get_expected_element_type(
    expected_type: TypeBase | None, container_class: TypeBase
) -> TypeBase | None {
    if expected_type is None {
        return None;
    }
    if (
        isinstance(expected_type, ClassType)
        and isinstance(container_class, ClassType)
        and expected_type.shared == container_class.shared
        and expected_type.private.type_args
        and len(expected_type.private.type_args) >= 1
    ) {
        return self._convert_to_instance(expected_type.private.type_args[0]);
    }
    return None;
}

impl TypeEvaluator._get_expected_kv_types(
    expected_type: TypeBase | None, dict_class: TypeBase
) -> tuple[TypeBase, TypeBase] | None {
    if expected_type is None {
        return None;
    }
    if (
        isinstance(expected_type, ClassType)
        and isinstance(dict_class, ClassType)
        and expected_type.shared == dict_class.shared
        and expected_type.private.type_args
        and len(expected_type.private.type_args) >= 2
    ) {
        return (
            self._convert_to_instance(expected_type.private.type_args[0]),
            self._convert_to_instance(expected_type.private.type_args[1])
        );
    }
    return None;
}

impl TypeEvaluator._infer_list_elem_from_mutations(expr: ListVal) -> TypeBase | None {
    asg = expr.parent;
    if (
        not isinstance(asg, Assignment)
        or asg.value is not expr
        or asg.aug_op is not None
    ) {
        return None;
    }
    refs: list[NameAtom] = [];
    for tgt in asg.target {
        if isinstance(tgt, Name) and tgt.sym is not None {
            refs.extend(tgt.sym.uses);
            refs.extend(tgt.sym.defn);
        }
    }
    if not refs {
        return None;
    }
    elem_types: list[TypeBase] = [];
    seen_refs: set[int] = set();
    saw_none = False;
    for ref in refs {
        if id(ref) in seen_refs {
            continue;
        }
        seen_refs.add(id(ref));
        contrib = self._list_mutation_elem_contrib(ref);
        if contrib is None {
            continue;
        }
        widened = self._widen_literal_for_declaration(contrib);
        if (
            isinstance(widened, ClassType) and widened.is_builtin(["NoneType", "None"])
        ) {
            saw_none = True;
            continue;
        }
        if not (
            isinstance(widened, ClassType)
            and widened.is_builtin(["int", "float", "str", "bool"])
        ) {
            return None;
        }
        if not self._type_in_list(widened, elem_types) {
            elem_types.append(widened);
        }
    }
    if not elem_types {
        return None;
    }
    if len(elem_types) == 1 and not saw_none {
        return elem_types[0];
    }
    if self.prefetch and self.prefetch.any_class {
        return self._convert_to_instance(self.prefetch.any_class);
    }
    return None;
}

impl TypeEvaluator._list_mutation_elem_contrib(ref: NameAtom) -> TypeBase | None {
    tr = ref.parent;
    if isinstance(tr, AtomTrailer) and tr.target is ref {
        if (
            tr.is_attr
            and isinstance(tr.right, Name)
            and isinstance(tr.parent, FuncCall)
            and tr.parent.target is tr
        ) {
            args = [
                p
                for p in (tr.parent.params or [])
                if not isinstance(p, KWPair)
            ];
            if tr.right.value in ("append", "insert") {
                arg_idx = 0 if tr.right.value == "append" else 1;
                if len(args) > arg_idx {
                    return self.get_type_of_expression(args[arg_idx]);
                }
                return None;
            }
            if tr.right.value == "extend" and args {
                if not (self.prefetch and self.prefetch.list_class) {
                    return None;
                }
                return self._get_expected_element_type(
                    self.get_type_of_expression(args[0]), self.prefetch.list_class
                );
            }
            return None;
        }
        if (
            not tr.is_attr
            and isinstance(tr.right, IndexSlice)
            and not tr.right.is_range
            and isinstance(tr.parent, Assignment)
            and tr.parent.aug_op is None
            and tr.parent.value is not None
            and any(t is tr for t in tr.parent.target)
        ) {
            return self.get_type_of_expression(tr.parent.value);
        }
        return None;
    }
    if (
        isinstance(tr, Assignment)
        and tr.aug_op is not None
        and tr.aug_op.name == Tok.ADD_EQ
        and tr.value is not None
        and any(t is ref for t in tr.target)
    ) {
        if not (self.prefetch and self.prefetch.list_class) {
            return None;
        }
        return self._get_expected_element_type(
            self.get_type_of_expression(tr.value), self.prefetch.list_class
        );
    }
    return None;
}

impl TypeEvaluator._get_enclosing_class(nd: UniNode) -> Archetype | None {
    impl_ := nd.find_parent_of_type(ImplDef);
    if impl_ and isinstance(impl_.decl_link, Archetype) {
        return impl_.decl_link;
    }
    return nd.find_parent_of_type(Archetype);
}

impl TypeEvaluator._get_enclosing_method(nd: UniNode) -> Ability | None {
    enclosing_fn = self._get_enclosing_function(nd);
    while enclosing_fn and (not enclosing_fn.is_method) {
        enclosing_fn = self._get_enclosing_function(enclosing_fn);
    }
    if enclosing_fn and enclosing_fn.is_method {
        return enclosing_fn;
    }
    return None;
}

impl TypeEvaluator._get_enclosing_return_scope(
    nd: UniNode
) -> Ability | LambdaExpr | None {
    while nd := nd.parent {
        if isinstance(nd, LambdaExpr) {
            return nd;
        }
        if isinstance(nd, Ability) {
            return nd;
        }
        if isinstance(nd, ImplDef) and isinstance(nd.decl_link, Ability) {
            return nd.decl_link;
        }
    }
    return None;
}


impl TypeEvaluator._get_declared_return_type(
    scope: Ability | LambdaExpr
) -> TypeBase | None {
    import from jaclang.compiler.type_system { types }

    if isinstance(scope, LambdaExpr) {
        if (
            isinstance(scope.signature, FuncSignature)
            and scope.signature.return_type is not None
        ) {
            return self._convert_to_instance(
                self.get_type_of_expression(scope.signature.return_type)
            );
        }
        return None;
    }

    if (
        isinstance(scope, Ability)
        and (scope.accessor_kind == "property")
        and (
            (scope.signature is None)
            or (
                isinstance(scope.signature, FuncSignature)
                and (scope.signature.return_type is None)
            )
        )
    ) {
        hv = scope.find_parent_of_type(HasVar);
        if hv and hv.type_tag {
            return self._convert_to_instance(
                self.get_type_of_expression(hv.type_tag.tag)
            );
        }
    }

    if (
        isinstance(scope, Ability)
        and isinstance(scope.signature, FuncSignature)
        and isinstance(scope.signature.return_type, Expr)
    ) {
        return self._unwrap_type_guard_return(
            self._convert_to_instance(
                self.get_type_of_expression(scope.signature.return_type)
            )
        );
    }

    fn_type_base = self.get_type_of_ability(scope);
    if not isinstance(fn_type_base, FunctionType) {
        return None;
    }
    return self._convert_to_instance(fn_type_base.return_type);
}

impl TypeEvaluator._get_enclosing_function(nd: UniNode) -> Ability | None {
    while nd := nd.parent {
        if isinstance(nd, Ability) {
            return nd;
        }
        if isinstance(nd, ImplDef) and isinstance(nd.decl_link, Ability) {
            return nd.decl_link;
        }
    }
    return None;
}


impl TypeEvaluator._resolution_scope_for(expr: UniNode) -> UniScopeNode | None {
    scope = expr.find_parent_of_type(UniScopeNode);
    if scope is None {
        return None;
    }
    if isinstance(scope, Archetype) and scope.base_classes {
        cur: UniNode | None = expr;
        while cur is not None and cur.parent is not scope {
            cur = cur.parent;
        }
        if cur is not None {
            for base in scope.base_classes {
                if base is cur {
                    if isinstance(expr, Name) and scope.type_params {
                        for tp in scope.type_params {
                            if tp.name.value == expr.value {
                                return scope;
                            }
                        }
                    }
                    return scope.parent_scope or scope;
                }
            }
        }
    }
    return scope;
}

impl TypeEvaluator._is_expr_self(expr: Expr) -> bool {
    if (
        isinstance(expr, Name)
        and (expr.value == TOKEN_MAP[Tok.KW_SELF])
        and (fn := self._get_enclosing_method(expr))
        and (not fn.is_static)
        and (not fn.is_cls_method)
    ) {
        return True;
    }
    return False;
}

impl TypeEvaluator._is_expr_super(expr: Expr) -> bool {
    if (
        isinstance(expr, Name)
        and (expr.value == TOKEN_MAP[Tok.KW_SUPER])
        and (fn := self._get_enclosing_method(expr))
        and (not fn.is_static)
        and (not fn.is_cls_method)
    ) {
        return True;
    }
    return False;
}

impl TypeEvaluator._is_unbound_method_call(expr: FuncCall) -> bool {
    first_positional_arg: Expr | None = None;
    for arg in expr.params {
        if not isinstance(arg, KWPair) {
            first_positional_arg = arg;
            break;
        }
    }

    if first_positional_arg is None or not self._is_expr_self(first_positional_arg) {
        return False;
    }

    if isinstance(expr.target, AtomTrailer) and expr.target.is_attr {
        base_type = self.get_type_of_expression(expr.target.target);
        if isinstance(base_type, ClassType) and base_type.is_instantiable_class() {
            if isinstance(expr.target.right, Name) {
                member = self._lookup_class_member(base_type, expr.target.right.value);
                if member {
                    member_type = self.get_type_of_symbol(member.symbol);
                    if isinstance(member_type, FunctionType) {
                        if member_type.function_flags
                            & FunctionTypeFlags.StaticMethod {
                            return False;
                        }
                        return True;
                    }
                }
            }
        }
    }
    return False;
}

impl TypeEvaluator._set_symbol_to_expr(expr: Expr, sym: Symbol) -> TypeBase {
    sym.add_use(expr);
    sym_type = self.get_type_of_symbol(sym);
    if isinstance(sym_type, UnknownType) and sym_type.is_incomplete {
        return sym_type;
    }
    expr.type = sym_type;
    return sym_type;
}

impl TypeEvaluator.resolve_imported_symbols(sym: Symbol) -> Symbol {
    if (isinstance(sym.decl, Name) and sym.decl.find_parent_of_type(ModuleItem)) {
        mod_item = sym.decl.find_parent_of_type(ModuleItem);
        assert (mod_item is not None);
        self.get_type_of_module(mod_item.from_mod_path);
        if isinstance(mod_item.name, Name) and mod_item.name.sym {
            return mod_item.name.sym;
        }

        self.get_type_of_module_item(mod_item);
        if isinstance(mod_item.name, Name) and mod_item.name.sym {
            return mod_item.name.sym;
        }
        return sym;
    }
    return sym;
}

impl TypeEvaluator._set_module_item_symbol_and_type(
    node_: ModuleItem, sym: Symbol
) -> TypeBase {
    if isinstance(node_.name, Name) {
        node_.name.sym = sym;
    }
    if node_.alias {
        node_.alias.sym = sym;
    }
    sym_type = self.get_type_of_symbol(sym);
    if binding := node_.binding_name {
        if not (isinstance(sym_type, UnknownType) and sym_type.is_incomplete) {
            binding.type = sym_type;
        }
    }
    return sym_type;
}

impl TypeEvaluator._extract_type_params(node_: Archetype) -> list[TypeVarType] {
    type_params: list[TypeVarType] = [];

    if node_.type_params {
        for tp in node_.type_params {
            tv = TypeVarType(name=tp.sym_name, is_class_type_param=True);
            type_params.append(tv);
        }
        return type_params;
    }

    outer_type_params = self._get_outer_scope_type_params(node_);
    outer_names = {tp.name for tp in outer_type_params};

    seen_names: set[str] = set();
    generic_base: AtomTrailer | None = None;
    for base_class in node_.base_classes or [] {
        if (not isinstance(base_class, AtomTrailer))
            or base_class.is_attr
            or base_class.is_null_ok {
            continue;
        }
        target_type = self.get_type_of_expression(base_class.target);
        is_generic = (
            isinstance(target_type, ClassType)
            and target_type.is_special_form("Generic")
        );
        if (
            not is_generic
            and isinstance(base_class.target, Name)
            and base_class.target.value == "Generic"
        ) {
            is_generic = True;
        }
        if is_generic {
            generic_base = base_class;
            break;
        }
    }
    if generic_base is not None {
        self._collect_typevars_from_base(
            generic_base, outer_names, seen_names, type_params
        );
    }

    for base_class in node_.base_classes or [] {
        if (not isinstance(base_class, AtomTrailer))
            or base_class.is_attr
            or base_class.is_null_ok {
            continue;
        }
        if base_class is generic_base {
            continue;
        }
        self._collect_typevars_from_base(
            base_class, outer_names, seen_names, type_params
        );
    }
    return type_params;
}

impl TypeEvaluator._is_class_scoped_type_param(node_: TypeParam) -> bool {
    owner: UniNode | None = node_.parent;
    while owner is not None {
        if isinstance(owner, Archetype) {
            return True;
        }
        if isinstance(owner, (Ability, TypeAlias)) {
            return False;
        }
        owner = owner.parent;
    }
    return False;
}

impl TypeEvaluator._collect_typevars_from_base(
    base_class: AtomTrailer,
    outer_names: set[str],
    seen_names: set[str],
    type_params: list[TypeVarType]
) -> None {
    if not (isinstance(base_class.right, IndexSlice) and base_class.right.slices) {
        return;
    }
    type_vars = base_class.right.slices[0].start;
    if isinstance(type_vars, TupleVal) {
        for val in type_vars.values {
            type_var_type = self.get_type_of_expression(val);
            if isinstance(type_var_type, TypeVarType) {
                if type_var_type.name in outer_names {
                    self.emit_diag(E1062, val, name=type_var_type.name);
                }
                if type_var_type.name not in seen_names {
                    seen_names.add(type_var_type.name);

                    class_type_var = TypeVarType(
                        name=type_var_type.name,
                        is_covariant=type_var_type.is_covariant,
                        is_contravariant=type_var_type.is_contravariant,
                        bound=type_var_type.bound,
                        constraints=type_var_type.constraints,
                        is_class_type_param=True
                    );
                    type_params.append(class_type_var);
                }
            }
        }
    } else {
        type_var_type = self.get_type_of_expression(type_vars);
        if isinstance(type_var_type, TypeVarType) {
            if type_var_type.name in outer_names {
                self.emit_diag(E1062, type_vars, name=type_var_type.name);
            }
            if type_var_type.name not in seen_names {
                seen_names.add(type_var_type.name);

                class_type_var = TypeVarType(
                    name=type_var_type.name,
                    is_covariant=type_var_type.is_covariant,
                    is_contravariant=type_var_type.is_contravariant,
                    bound=type_var_type.bound,
                    constraints=type_var_type.constraints,
                    is_class_type_param=True
                );
                type_params.append(class_type_var);
            }
        }
    }
}

impl TypeEvaluator.emit_diag(
    diag: DiagnosticInfo, nd: UniNode, **kwargs: object
) -> None {
    if self._pass is not None {
        self._pass.emit(diag, node_override=nd, **kwargs);
    }
}

impl TypeEvaluator._invalidate_expr_type_cache(node_: UniNode) -> None {
    if isinstance(node_, Expr) {
        node_.type = None;
    }
    for kid in node_.kid {
        self._invalidate_expr_type_cache(kid);
    }
}

impl TypeEvaluator._is_ability_classmethod(node_: Ability) -> bool {
    if node_.decorators {
        for decorator in node_.decorators {
            decor_type = self.get_type_of_expression(decorator);
            if (
                isinstance(decor_type, ClassType)
                and self.prefetch.classmethod_class is not None
                and self.prefetch.classmethod_class.shared == decor_type.shared
            ) {
                return True;
            }
        }
    }
    return False;
}

impl TypeEvaluator._is_ability_staticmethod(node_: Ability) -> bool {
    if node_.is_static {
        return True;
    }
    if node_.decorators {
        for decorator in node_.decorators {
            decor_type = self.get_type_of_expression(decorator);
            if (
                isinstance(decor_type, ClassType)
                and decor_type.is_builtin("staticmethod")
            ) {
                return True;
            }
        }
    }
    return False;
}

impl TypeEvaluator._classify_property_symbol(symbol: Symbol) -> PropertyWriteKind {
    import from jaclang.compiler.type_system.type_utils { PropertyWriteKind }
    node_ = symbol.decl.name_of;

    if isinstance(node_, HasVar) and node_.accessors {
        for acc in node_.accessors {
            if acc.accessor_kind == "setter" {
                return PropertyWriteKind.WRITABLE;
            }
        }
        return PropertyWriteKind.READ_ONLY;
    }
    if not isinstance(node_, Ability) {
        return PropertyWriteKind.NOT_PROPERTY;
    }
    ability = node_;
    if not ability.decorators {
        return PropertyWriteKind.NOT_PROPERTY;
    }
    for decorator in ability.decorators {
        decorator_type = self.get_type_of_expression(decorator);
        if is_cached_property_decorator_type(decorator_type) {
            return PropertyWriteKind.WRITABLE;
        }
        if is_property_decorator_type(decorator_type) {
            return PropertyWriteKind.READ_ONLY;
        }
    }
    return PropertyWriteKind.NOT_PROPERTY;
}

impl TypeEvaluator.get_getter_type_from_property(symbol: Symbol) -> (TypeBase | None) {
    import from jaclang.compiler.type_system.type_utils { PropertyWriteKind }
    kind = self._classify_property_symbol(symbol);
    if kind == PropertyWriteKind.NOT_PROPERTY {
        return None;
    }
    node_ = symbol.decl.name_of;
    if not isinstance(node_, Ability) {
        return None;
    }
    func_type = self.get_type_of_ability(node_);
    if not isinstance(func_type, FunctionType) {
        return None;
    }
    return func_type.return_type;
}

impl TypeEvaluator.get_property_write_type(symbol: Symbol) -> PropertyWriteResult {
    import from jaclang.compiler.type_system.type_utils {
        PropertyWriteKind,
        PropertyWriteResult
    }
    kind = self._classify_property_symbol(symbol);
    if kind == PropertyWriteKind.NOT_PROPERTY {
        return PropertyWriteResult(kind=PropertyWriteKind.NOT_PROPERTY);
    }

    node_decl = symbol.decl.name_of;
    if isinstance(node_decl, HasVar) and node_decl.accessors {
        if kind == PropertyWriteKind.READ_ONLY {
            return PropertyWriteResult(kind=PropertyWriteKind.READ_ONLY);
        }
        if node_decl.type_tag {
            decl_ty = self._convert_to_instance(
                self.get_type_of_expression(node_decl.type_tag.tag)
            );
            return PropertyWriteResult(
                kind=PropertyWriteKind.WRITABLE, write_type=decl_ty
            );
        }
        return PropertyWriteResult(
            kind=PropertyWriteKind.WRITABLE, write_type=UnknownType()
        );
    }

    if kind == PropertyWriteKind.WRITABLE {
        node_ = symbol.decl.name_of;
        if isinstance(node_, Ability) {
            func_type = self.get_type_of_ability(node_);
            if isinstance(func_type, FunctionType)
                and func_type.return_type is not None {
                return PropertyWriteResult(
                    kind=PropertyWriteKind.WRITABLE, write_type=func_type.return_type
                );
            }
        }

        return PropertyWriteResult(
            kind=PropertyWriteKind.WRITABLE, write_type=UnknownType()
        );
    }

    prop_name = symbol.sym_name;
    method_scope = symbol.symbol_table;
    class_scope = method_scope.parent_scope if method_scope is not None else None;
    if class_scope is not None {
        overload_syms = class_scope.names_in_scope_overload.get(prop_name);
        if overload_syms {
            for overload_sym in overload_syms {
                setter_type = self._get_setter_value_type(overload_sym, prop_name);
                if setter_type is not None {
                    return PropertyWriteResult(
                        kind=PropertyWriteKind.WRITABLE, write_type=setter_type
                    );
                }
            }
        }
    }

    return PropertyWriteResult(kind=PropertyWriteKind.READ_ONLY);
}

impl TypeEvaluator._get_setter_value_type(
    symbol: Symbol, prop_name: str
) -> (TypeBase | None) {
    node_ = symbol.decl.name_of;
    if not isinstance(node_, Ability) {
        return None;
    }
    ability = node_;
    if not ability.decorators {
        return None;
    }
    for decorator in ability.decorators {
        if isinstance(decorator, AtomTrailer) and decorator.is_attr {
            if (
                isinstance(decorator.right, Name)
                and decorator.right.value == "setter"
                and isinstance(decorator.target, Name)
                and decorator.target.value == prop_name
            ) {
                func_type = self.get_type_of_ability(ability);
                if isinstance(func_type, FunctionType) and func_type.parameters {
                    for param in func_type.parameters {
                        if not param.is_self and not param.is_cls {
                            return param.param_type;
                        }
                    }
                }
                return None;
            }
        }
    }
    return None;
}

impl TypeEvaluator._create_callable_type(
    type_args_expr: Expr | None, error_node: Expr
) -> FunctionType {
    param_types: list[TypeBase] = [];
    return_type: TypeBase = UnknownType();
    is_gradual: bool = False;
    if type_args_expr is None {
        is_gradual = True;
        return create_callable_type([], return_type, is_gradual=True);
    }

    if isinstance(type_args_expr, TupleVal) {
        type_arg_values = type_args_expr.values;
        if len(type_arg_values) == 0 {
            self.emit_diag(E1070, error_node);
            return create_callable_type([], UnknownType(), is_gradual=True);
        }

        first_arg = type_arg_values[0];
        if isinstance(first_arg, Ellipsis) {
            is_gradual = True;
        } elif isinstance(first_arg, ListVal) {
            for param_expr in first_arg.values {
                param_type = self.get_type_of_expression(param_expr);
                param_type = self._convert_to_instance(param_type);
                param_types.append(param_type);
            }
        } else {
            resolved_first = self.get_type_of_expression(first_arg);
            if isinstance(resolved_first, TypeVarType) {
                is_gradual = True;
            } elif self.is_paramspec_class(resolved_first)
                or self.is_type_var_tuple_class(resolved_first) {
                is_gradual = True;
            } else {
                self.emit_diag(E1071, first_arg);
                param_type = self._convert_to_instance(resolved_first);
                param_types.append(param_type);
            }
        }

        if len(type_arg_values) >= 2 {
            return_type_expr = type_arg_values[1];
            return_type = self.get_type_of_expression(return_type_expr);
            return_type = self._convert_to_instance(return_type);
        } else {
            self.emit_diag(E1072, error_node);
            return_type = UnknownType();
        }

        if len(type_arg_values) > 2 {
            self.emit_diag(E1073, type_arg_values[2]);
        }
    } else {
        return_type = self.get_type_of_expression(type_args_expr);
        return_type = self._convert_to_instance(return_type);
        is_gradual = True;
    }
    return create_callable_type(param_types, return_type, is_gradual=is_gradual);
}

impl TypeEvaluator._get_special_form_type(
    name: str, symbol_type: TypeBase
) -> TypeBase | None {
    if not self.prefetch {
        return None;
    }

    is_special_form = (
        isinstance(symbol_type, ClassType)
        and self.prefetch.callable_class
        and symbol_type.shared == self.prefetch.callable_class.shared
    );

    is_known_special_form_name = name
        in (
            "Self",
            "Callable",
            "Protocol",
            "Final",
            "LiteralString",
            "Union",
            "Optional",
            "Generic",
            "Type",
            "ClassVar",
            "Annotated",
            "Concatenate",
            "TypeGuard",
            "TypeIs",
            "Unpack",
            "Required",
            "NotRequired",
            "Never",
            "NoReturn",
            "Literal",
            "TypeForm",

        );

    if not is_special_form and not is_known_special_form_name {
        return None;
    }

    match name {
        case "Callable":
            return create_callable_type([], AnyType(), is_gradual=True);

        case "Protocol":
            return self.prefetch.protocol_class;

        case "Final":
            return self.prefetch.final_class;

        case "LiteralString":
            return self.prefetch.literal_string_class;

        case "Self":
            return synthesize_self_type_var();

        case "Never":
            return NeverType();

        case "NoReturn":
            return NeverType();

    }
    return None;
}

impl TypeEvaluator._resolve_from_path(from_mod: ModulePath) -> Path {
    if from_mod.level > 0 and not from_mod.path {
        base = Path(from_mod.loc.mod_path).parent;
        for _ in range(max(from_mod.level - 1, 0)) {
            base = base.parent;
        }
        return base;
    }

    return Path(from_mod.resolve_relative_path());
}

impl TypeEvaluator._resolve_client_npm_module(node_: ModulePath) -> (str | None) {
    spec = node_.string_path_value or node_.dot_path_str;
    if not spec {
        return None;
    }
    if not node_.in_client_context() {
        return None;
    }
    mod_path = node_.loc.mod_path if node_.loc else None;
    if not mod_path {
        return None;
    }
    import from jaclang.jac0core.modresolver { resolve_client_npm_package }
    base = self._client_npm_base(spec, mod_path);
    if base is None {
        return None;
    }
    return resolve_client_npm_package(spec, base);
}

impl TypeEvaluator._client_npm_base(spec: str, mod_path: str) -> (str | None) {
    import from jaclang.jac0core.modresolver { has_client_npm_package }
    if has_client_npm_package(spec, mod_path) {
        return mod_path;
    }
    entry_path = self._client_entry_mod_path();
    if (
        entry_path
        and entry_path != mod_path
        and has_client_npm_package(spec, entry_path)
    ) {
        return entry_path;
    }
    return None;
}

impl TypeEvaluator._client_entry_mod_path -> (str | None) {
    main_mod = self.program.mod.main;
    if main_mod and main_mod.loc {
        return main_mod.loc.mod_path or None;
    }
    return None;
}

impl TypeEvaluator._is_fstring_all_literal(fstring: FString) -> bool {
    for part in fstring.parts {
        if isinstance(part, String) {
            continue;
        }
        if isinstance(part, FormattedValue) {
            part_type = self.get_type_of_expression(part.format_part);
            if isinstance(part_type, ClassType) {
                if part_type.is_literal_type() {
                    continue;
                }
                if self.prefetch and self.prefetch.literal_string_class {
                    if isinstance(self.prefetch.literal_string_class, ClassType) {
                        if part_type.shared
                            == self.prefetch.literal_string_class.shared {
                            continue;
                        }
                    }
                }
            }

            return False;
        }
    }
    return True;
}

impl TypeEvaluator._create_special_builtin_type(
    name: str, base_class: ClassType
) -> ClassType {
    if base_class.shared._derived_special_types is not None {
        cached = base_class.shared._derived_special_types.get(name);
        if cached is not None {
            return cached;
        }
    }
    shared = ClassDetailsShared(
        class_name=name,
        symbol_table=base_class.shared.symbol_table,
        base_classes=[base_class],
        mro=[],
        is_builtin_class=True
    );
    special_type = ClassType(_shared=shared, flags=base_class.flags);

    special_type.shared.mro = [special_type] + base_class.shared.mro;
    if base_class.shared._derived_special_types is None {
        base_class.shared._derived_special_types = {};
    }
    base_class.shared._derived_special_types[name] = special_type;
    return special_type;
}

impl TypeEvaluator._get_signature_type_params(sig: FuncSignature) -> list[TypeVarType] {
    type_params: list[TypeVarType] = [];

    def collect_typevars(expr: Expr) {
        if isinstance(expr, Name) {
            t = self.get_type_of_expression(expr);
            if isinstance(t, TypeVarType) {
                type_params.append(t);
            }
        } elif isinstance(expr, AtomTrailer) and not expr.is_attr {
            if isinstance(expr.right, IndexSlice) {
                for s in expr.right.slices {
                    if s.start {
                        collect_typevars(s.start);
                    }
                }
            }
        } elif isinstance(expr, AtomUnit) and isinstance(expr.value, Expr) {
            collect_typevars(expr.value);
        } elif isinstance(expr, TupleVal) {
            for v in expr.values {
                collect_typevars(v);
            }
        } elif isinstance(expr, BinaryExpr) {
            collect_typevars(expr.left);
            collect_typevars(expr.right);
        }
    }

    for param in sig.get_parameters() {
        if isinstance(param, ParamVar) and param.type_tag {
            collect_typevars(param.type_tag.tag);
        }
    }

    if sig.return_type {
        collect_typevars(sig.return_type);
    }

    return type_params;
}

impl TypeEvaluator._get_function_type_params(func: Ability) -> list[TypeVarType] {
    type_params: list[TypeVarType] = [];

    for tp in func.type_params or [] {
        type_params.append(TypeVarType(name=tp.sym_name));
    }

    if isinstance(func.signature, FuncSignature) {
        type_params.extend(self._get_signature_type_params(func.signature));
    }

    return type_params;
}

impl TypeEvaluator.validate_typevar_in_type_expr(expr: Expr) -> None {
    if isinstance(expr, Name) {
        resolved_type = self.get_type_of_expression(expr);
        if isinstance(resolved_type, TypeVarType) {
            self.validate_typevar_scope(expr, resolved_type);
        }
    } elif isinstance(expr, AtomTrailer) {
        if not expr.is_attr and isinstance(expr.right, IndexSlice) {
            for slice in expr.right.slices {
                if slice.start {
                    self.validate_typevar_in_type_expr(slice.start);
                }
            }
        }
    } elif isinstance(expr, TupleVal) {
        for val in expr.values {
            self.validate_typevar_in_type_expr(val);
        }
    } elif isinstance(expr, BinaryExpr) {
        self.validate_typevar_in_type_expr(expr.left);
        self.validate_typevar_in_type_expr(expr.right);
    }
}

impl TypeEvaluator.validate_typevar_variance(func: Ability) -> None {
    if not isinstance(func.parent, Archetype) {
        return;
    }
    enclosing_class = func.parent;

    class_type = self.get_type_of_class(enclosing_class);
    if not class_type or not class_type.shared.type_params {
        return;
    }

    class_tvars: dict[str, TypeVarType] = {};
    for tp in class_type.shared.type_params {
        class_tvars[tp.name] = tp;
    }

    def check_expr(expr: Expr, is_return: bool) {
        if isinstance(expr, Name) {
            resolved = self.get_type_of_expression(expr);
            if isinstance(resolved, TypeVarType) and resolved.name in class_tvars {
                tv = class_tvars[resolved.name];
                if is_return and tv.is_contravariant {
                    self.emit_diag(E1080, expr);
                } elif not is_return and tv.is_covariant {
                    self.emit_diag(E1081, expr);
                }
            }
        } elif isinstance(expr, BinaryExpr) and is_return {
            check_expr(expr.left, is_return);
            check_expr(expr.right, is_return);
        }
    }

    if not isinstance(func.signature, FuncSignature) {
        return;
    }

    params = func.signature.get_parameters();
    if params {
        for param in params {
            if param.type_tag and isinstance(param.type_tag.tag, Expr) {
                check_expr(param.type_tag.tag, False);
            }
        }
    }

    if func.signature.return_type {
        check_expr(func.signature.return_type, True);
    } else {
        for ret_stmt in func.get_all_sub_nodes(ReturnStmt) {
            if ret_stmt.expr and isinstance(ret_stmt.expr, Name) {
                resolved = self.get_type_of_expression(ret_stmt.expr);
                if isinstance(resolved, TypeVarType) and resolved.name in class_tvars {
                    tv = class_tvars[resolved.name];
                    if tv.is_contravariant {
                        self.emit_diag(E1080, ret_stmt);
                    }
                }
            }
        }
    }
}

impl TypeEvaluator.validate_typevar_scope(expr: Expr, type_var: TypeVarType) -> None {
    if isinstance(expr, Name) and expr.sym {
        sym_decl = expr.sym.decl;
        if sym_decl {
            is_module_level = False;
            decl_parent = sym_decl.parent;
            while decl_parent {
                if isinstance(decl_parent, Module) {
                    is_module_level = True;
                    break;
                }
                if isinstance(decl_parent, (Archetype, Ability)) {
                    break;
                }
                decl_parent = decl_parent.parent;
            }

            if is_module_level {
                sig_check = expr.parent;
                while sig_check {
                    if isinstance(sig_check, FuncSignature) {
                        return;
                    }
                    if isinstance(sig_check, (Ability, Archetype, Module)) {
                        break;
                    }
                    sig_check = sig_check.parent;
                }
            }
        }
    }

    if self._type_var_bound_in_scope(expr, type_var.name) {
        return;
    }

    self.emit_diag(E1065, expr, name=type_var.name);
}

impl TypeEvaluator._type_var_bound_in_scope(node_: UniNode, name: str) -> bool {
    current: UniNode | None = node_.parent;
    seen: set[int] = set();

    while current {
        if id(current) in seen {
            return False;
        }
        seen.add(id(current));

        if isinstance(current, Ability) {
            for tp in self._get_function_type_params(current) {
                if tp.name == name {
                    return True;
                }
            }
        } elif isinstance(current, Archetype) {
            class_type = self.get_type_of_class(current);
            for tp in class_type.shared.type_params or [] {
                if tp.name == name {
                    return True;
                }
            }
            return False;
        } elif isinstance(current, ImplDef) {
            if isinstance(current.spec, FuncSignature) {
                for tp in self._get_signature_type_params(current.spec) {
                    if tp.name == name {
                        return True;
                    }
                }
            }
            decl = current.decl_link;
            if isinstance(decl, (Ability, Archetype)) {
                current = decl;
                continue;
            }
        }

        current = current.parent;
    }
    return False;
}

impl TypeEvaluator._get_outer_scope_type_params(node_: UniNode) -> list[TypeVarType] {
    type_params: list[TypeVarType] = [];
    current: UniNode | None = node_.parent;

    while current {
        if isinstance(current, Archetype) {
            class_type = self.get_type_of_class(current);
            if class_type.shared.type_params {
                for tp in class_type.shared.type_params {
                    type_params.append(tp);
                }
            }
        } elif isinstance(current, Ability) {
            func_params = self._get_function_type_params(current);
            for tp in func_params {
                type_params.append(tp);
            }
        }
        current = current.parent;
    }
    return type_params;
}

impl TypeEvaluator._is_ellipsis_only_body(body: list[CodeBlockStmt]) -> bool {
    has_ellipsis = False;
    for stmt in body {
        if isinstance(stmt, Semi) {
            continue;
        }
        if isinstance(stmt, ExprStmt) and isinstance(stmt.expr, Ellipsis) {
            has_ellipsis = True;
            continue;
        }
        return False;
    }
    return has_ellipsis;
}

impl TypeEvaluator._infer_lambda_block_return_type(
    body: list[CodeBlockStmt]
) -> TypeBase {
    import from jaclang.compiler.type_system { types }

    none_type = self._convert_to_instance(self.get_none_type());
    return_types: list[TypeBase] = [];
    always_returns = self._collect_return_types(body, return_types);

    non_semi = [
        s
        for s in body
        if not isinstance(s, Semi)
    ];
    if (len(non_semi) == 1 and isinstance(non_semi[0], ExprStmt)) {
        return_types.append(
            self._convert_to_instance(self.get_type_of_expression(non_semi[0].expr))
        );
        always_returns = True;
    }

    if not return_types {
        return none_type;
    }

    if not always_returns {
        return_types.append(none_type);
    }

    seen: list[TypeBase] = [];
    for rt in return_types {
        is_dup = False;
        for s in seen {
            if str(rt) == str(s) {
                is_dup = True;
                break;
            }
        }
        if not is_dup {
            seen.append(rt);
        }
    }

    if len(seen) == 1 {
        return seen[0];
    }

    return UnionType(types=seen);
}

impl TypeEvaluator._collect_return_types(
    stmts: list[CodeBlockStmt], out: list[TypeBase]
) -> bool {
    for stmt in stmts {
        if isinstance(stmt, (Ability, LambdaExpr)) {
            continue;
        }

        if isinstance(stmt, ReturnStmt) {
            if stmt.expr and not isinstance(stmt.expr, Null) {
                out.append(self.get_type_of_expression(stmt.expr));
            }

            return True;
        }

        if isinstance(stmt, RaiseStmt) {
            return True;
        }

        if isinstance(stmt, IfStmt) {
            if_returns = self._collect_return_types(list(stmt.body), out);
            else_returns = self._collect_if_else_returns(stmt.else_body, out);
            if if_returns and else_returns {
                return True;
            }
            continue;
        }

        if isinstance(stmt, MatchStmt) {
            if stmt.cases {
                all_return = True;
                for `case in stmt.cases {
                    mc: MatchCase = `case;
                    if not self._collect_return_types(list(mc.body), out) {
                        all_return = False;
                    }
                }
                if all_return {
                    return True;
                }
            }
            continue;
        }

        if isinstance(stmt, SwitchStmt) {
            if stmt.cases {
                has_default = False;
                all_return = True;
                for `case in stmt.cases {
                    sc: SwitchCase = `case;
                    if sc.pattern is None {
                        has_default = True;
                    }
                    if not self._collect_return_types(list(sc.body), out) {
                        all_return = False;
                    }
                }
                if has_default and all_return {
                    return True;
                }
            }
            continue;
        }

        if isinstance(stmt, TryStmt) {
            try_returns = self._collect_return_types(list(stmt.body), out);
            if try_returns {
                if not stmt.excepts or len(stmt.excepts) == 0 {
                    return True;
                }
                all_except = True;
                for exc in stmt.excepts {
                    ex: Except = exc;
                    if not self._collect_return_types(list(ex.body), out) {
                        all_except = False;
                    }
                }
                if all_except {
                    return True;
                }
            }
            continue;
        }

        if isinstance(stmt, WithStmt) {
            if self._collect_return_types(list(stmt.body), out) {
                return True;
            }
            continue;
        }

        if isinstance(stmt, OpenStmt) {
            if self._collect_return_types(list(stmt.body), out) {
                return True;
            }
            continue;
        }

        if isinstance(stmt, (IterForStmt, InForStmt, WhileStmt, ForeverStmt)) {
            self._collect_return_types(list(stmt.body), out);
            _is_infinite_loop = isinstance(stmt, ForeverStmt)
                or (
                    isinstance(stmt, WhileStmt)
                    and isinstance(stmt.condition, Bool)
                    and stmt.condition.lit_value
                );
            if _is_infinite_loop {
                _has_break = False;
                import from jaclang.jac0core.constant { Tokens as _Tok }
                _loop_types = (WhileStmt, ForeverStmt, IterForStmt, InForStmt);
                for _ctrl in stmt.get_all_sub_nodes(CtrlStmt) {
                    if _ctrl.ctrl.name != _Tok.KW_BREAK {
                        continue;
                    }
                    _anc = _ctrl.parent;
                    while _anc is not None and _anc is not stmt {
                        if isinstance(_anc, _loop_types) {
                            break;
                        }
                        _anc = _anc.parent;
                    }
                    if _anc is stmt {
                        _has_break = True;
                        break;
                    }
                }
                if not _has_break {
                    return True;
                }
            }
            continue;
        }
    }
    return False;
}

impl TypeEvaluator._collect_if_else_returns(
    else_body: ElseIf | ElseStmt | None, out: list[TypeBase]
) -> bool {
    if else_body is None {
        return False;
    }
    if isinstance(else_body, ElseStmt) {
        return self._collect_return_types(list(else_body.body), out);
    }
    if isinstance(else_body, ElseIf) {
        if_returns = self._collect_return_types(list(else_body.body), out);
        else_returns = self._collect_if_else_returns(else_body.else_body, out);
        return if_returns and else_returns;
    }
    return False;
}
