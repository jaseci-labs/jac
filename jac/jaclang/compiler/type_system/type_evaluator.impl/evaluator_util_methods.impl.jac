impl TypeEvaluator._create_dataclass_init_method(
    class_type: types.ClassType
) -> types.FunctionType {
    parameters: list[types.Parameter] = [];
    for cls in class_type.shared.mro[::-1] {
        for has_var in cls.shared.symbol_table.get_has_vars() {
            if has_var.defer {
                continue;
            }
            param_type: TypeBase | None = None;

            if has_var.type_tag {
                var_type_expr = has_var.type_tag.tag;
                type_cls = self.get_type_of_expression(var_type_expr);
                param_type = self._convert_to_instance(type_cls);
            }
            parameters.append(
                types.Parameter(
                    name=has_var.name.value,
                    category=types.ParameterCategory.Positional,
                    param_type=param_type,
                    default_value=has_var.value,
                    is_self=False,
                    param_kind=types.ParamKind.NORMAL,
                )
            );
        }
    }
    return types.FunctionType(
        func_name="__init__", return_type=types.UnknownType(), parameters=parameters,
    );
}

"""Lookup the object member type."""
impl TypeEvaluator._lookup_object_member(
    base_type: types.ClassType, member: str
) -> type_utils.ClassMember | None {
    assert self.prefetch.int_class is not None;
    if isinstance(base_type, types.ClassType) and base_type.is_class_instance() {
        return self._lookup_class_member(base_type, member);
    }
    return None;
}

"""Lookup the class member type."""
impl TypeEvaluator._lookup_class_member(
    base_type: types.ClassType, member: str
) -> type_utils.ClassMember | None {
    for cls in base_type.shared.mro {
        overloaded_syms: list[uni.Symbol] = [];

        if sym := cls.lookup_member_symbol(member, overloaded_syms) {
            return type_utils.ClassMember(sym, cls, overloaded_syms);
        }
    }
    return None;
}

"""Convert a class type to an instance type."""
impl TypeEvaluator._convert_to_instance(jtype: TypeBase) -> TypeBase {
    if jtype.is_instantiable_class() {
        assert isinstance(jtype, types.ClassType);
        return jtype.clone_as_instance();
    }
    if isinstance(jtype, types.UnionType) {
        converted = [self._convert_to_instance(t) for t in jtype.types];
        return types.UnionType(types=converted);
    }
    return jtype;
}

impl TypeEvaluator._get_enclosing_class(nd: uni.UniNode) -> uni.Archetype | None {
    impl_ := nd.find_parent_of_type(uni.ImplDef);
    if impl_ and isinstance(impl_.decl_link, uni.Archetype) {
        return impl_.decl_link;
    }
    return nd.find_parent_of_type(uni.Archetype);
}

"""Get the enclosing method (ability) of the given node."""
impl TypeEvaluator._get_enclosing_method(nd: uni.UniNode) -> uni.Ability | None {
    enclosing_fn = self._get_enclosing_function(nd);
    while enclosing_fn and (not enclosing_fn.is_method) {
        enclosing_fn = self._get_enclosing_function(enclosing_fn);
    }
    if enclosing_fn and enclosing_fn.is_method {
        return enclosing_fn;
    }
    return None;
}

"""Get the enclosing function (ability) of the given node."""
impl TypeEvaluator._get_enclosing_function(nd: uni.UniNode) -> uni.Ability | None {
    while nd := nd.parent {
        if isinstance(nd, uni.Ability) {
            return nd;
        }
        if isinstance(nd, uni.ImplDef) and isinstance(nd.decl_link, uni.Ability) {
            return nd.decl_link;
        }
    }
    return None;
}

"""Check if the expression is Name that is 'self' and in the method context."""
impl TypeEvaluator._is_expr_self(expr: uni.Expr) -> bool {
    if (
        isinstance(expr, uni.Name)
        and (expr.value == TOKEN_MAP[Tok.KW_SELF])
        and (fn := self._get_enclosing_method(expr))
        and (not fn.is_static)
        and (not fn.is_cls_method)
    ) {
        return True;
    }
    return False;
}

"""Check if the expression is Name that is 'super' and in the method context."""
impl TypeEvaluator._is_expr_super(expr: uni.Expr) -> bool {
    if (
        isinstance(expr, uni.Name)
        and (expr.value == TOKEN_MAP[Tok.KW_SUPER])
        and (fn := self._get_enclosing_method(expr))
        and (not fn.is_static)
        and (not fn.is_cls_method)
    ) {
        return True;
    }
    return False;
}

impl TypeEvaluator._set_symbol_to_expr(expr: uni.Expr, sym: uni.Symbol) -> TypeBase {
    sym.add_use(expr);
    expr.type = self.get_type_of_symbol(sym);
    return expr.type;
}

"""Resolve the imported symbols to the actual symbol."""
impl TypeEvaluator.resolve_imported_symbols(sym: uni.Symbol) -> uni.Symbol {
    if (
        isinstance(sym.decl, uni.Name) and sym.decl.find_parent_of_type(uni.ModuleItem)
    ) {
        mod_item = sym.decl.find_parent_of_type(uni.ModuleItem);
        assert (mod_item is not None);
        self.get_type_of_module(mod_item.from_mod_path);
        if isinstance(mod_item.name, uni.Name) and mod_item.name.sym {
            return mod_item.name.sym;
        }
        return sym;
    }
    return sym;
}

"""Set symbol and type for a module item node and its alias if present."""
impl TypeEvaluator._set_module_item_symbol_and_type(
    node_: uni.ModuleItem, sym: uni.Symbol
) -> TypeBase {
    node_.name.sym = sym;
    if node_.alias {
        node_.alias.sym = sym;
    }
    node_.name.type = self.get_type_of_symbol(sym);
    return node_.name.type;
}

impl TypeEvaluator._extract_type_params(
    node_: uni.Archetype
) -> list[types.TypeVarType] {
    type_params: list[types.TypeVarType] = [];
    for base_class in node_.base_classes or [] {
        if (not isinstance(base_class, uni.AtomTrailer))
        or base_class.is_attr
        or base_class.is_null_ok {
            continue;
        }

        if isinstance(base_class.right, uni.IndexSlice) and base_class.right.slices {
            type_vars = base_class.right.slices[0].start;
            if isinstance(type_vars, uni.TupleVal) {
                for val in type_vars.values {
                    type_var_type = self.get_type_of_expression(val);

                    if isinstance(type_var_type, types.TypeVarType) {
                        type_params.append(type_var_type);
                    }
                }
            } else {
                type_var_type = self.get_type_of_expression(type_vars);
                if isinstance(type_var_type, types.TypeVarType) {
                    type_params.append(type_var_type);
                }
            }
        }
    }
    return type_params;
}

"""Add a diagnostic message to the program."""
impl TypeEvaluator.add_diagnostic(
    nd: uni.UniNode, message: str, warning: bool = False
) -> None {
    if self.diagnostic_callback {
        self.diagnostic_callback(nd, message, warning);
    }
}

impl TypeEvaluator._is_ability_classmethod(node_: uni.Ability) -> bool {
    if node_.name_spec and node_.name_spec.sym_name == "__new__" {
        return True;
    }
    if node_.decorators {
        for decorator in node_.decorators {
            decor_type = self.get_type_of_expression(decorator);

            if (
                isinstance(decor_type, types.ClassType)
                and self.prefetch.classmethod_class is not None
                and self.prefetch.classmethod_class.shared == decor_type.shared
            ) {
                return True;
            }
        }
    }
    return False;
}

"""Check if a symbol represents a property."""
impl TypeEvaluator._is_symbol_property(symbol: uni.Symbol) -> bool {
    node_ = symbol.decl.name_of;
    if isinstance(node_, uni.Ability) {
        ability = node_;
        if ability.decorators {
            for decorator in ability.decorators {
                if isinstance(decorator, uni.Name) and decorator.value == "property" {
                    return True;
                }
            }
        }
    }
    return False;
}
