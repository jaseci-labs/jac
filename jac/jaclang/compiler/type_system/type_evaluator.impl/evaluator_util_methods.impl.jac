impl TypeEvaluator._create_dataclass_init_method(
    class_type: types.ClassType
) -> types.FunctionType {
    param_map: dict[str, types.Parameter] = {};
    for cls in class_type.shared.mro[::-1] {
        # Iterate over the has vars and create parameters.
        for has_var in cls.shared.symbol_table.get_has_vars() {
            # Skip fields marked with 'by postinit' - they are initialized in postinit method
            if has_var.defer {
                continue;
            }
            # Get parameter type.
            param_type: TypeBase | None = None;
            if has_var.type_tag {
                var_type_expr = has_var.type_tag.tag;
                type_cls = self.get_type_of_expression(var_type_expr);
                param_type = self._convert_to_instance(type_cls);
            }

            # Use dict to deduplicate by name so child class fields override parent fields.
            param_map[has_var.name.value] = types.Parameter(
                name=has_var.name.value,
                category=types.ParameterCategory.Positional,
                param_type=param_type,
                default_value=has_var.value,
                is_self=False,
                param_kind=types.ParamKind.NORMAL,
            );
        }
    }
    parameters = list(param_map.values());
    # Create and return the __init__ method type.
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
        # TODO: We need to implement Member lookup flags and set SkipInstanceMember to 0.
        return self._lookup_class_member(base_type, member);
    }
    return None;
}

"""Lookup the class member type."""
impl TypeEvaluator._lookup_class_member(
    base_type: types.ClassType, member: str
) -> type_utils.ClassMember | None {
    # FIXME: Pyright's way: Implement class member iterator (based on mro and the multiple inheritance)
    # return the first found member from the iterator.

    # NOTE: This is a simple implementation to make it work and more robust implementation will
    # be done in a future PR.
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
    # TODO: Grep pyright "Handle type[x] as a special case." They handle `type[x]` as a special case:
    #
    # foo: int = 42;       # <-- Here `int` is instantiable class and, become instance after this method.
    # foo: type[int] = int # <-- Here `type[int]`, this should be `int` that's instantiable.
    #
    if jtype.is_instantiable_class() {
        assert isinstance(jtype, types.ClassType);
        return jtype.clone_as_instance();
    }
    # Handle UnionType: convert each member type to instance form.
    if isinstance(jtype, types.UnionType) {
        converted = [self._convert_to_instance(t) for t in jtype.types];
        return types.UnionType(types=converted);
    }
    return jtype;
}

impl TypeEvaluator._get_enclosing_class(nd: uni.UniNode) -> uni.Archetype | None {
    # If the symbol is from a module item, we need to resolve it to the actual symbol.
    # Check if mod_item.name is a Name and has a sym attribute before accessing it
    # Cache the type.
    # __new__ is always a classmethod in Python, even without @classmethod decorator
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

"""Check if a function call is an unbound method call (Class.method(self, ...) pattern)."""
impl TypeEvaluator._is_unbound_method_call(expr: uni.FuncCall) -> bool {
    # First check if there are positional arguments and the first one is 'self'
    first_positional_arg: uni.Expr | None = None;
    for arg in expr.params {
        if not isinstance(arg, uni.KWPair) {
            first_positional_arg = arg;
            break;
        }
    }
    # If no positional args or first arg is not 'self', it's not an unbound call
    if first_positional_arg is None or not self._is_expr_self(first_positional_arg) {
        return False;
    }
    # TODO: Atomtrailer should have a symbol

    # Check if target is Class.method pattern (method on instantiable class)
    if isinstance(expr.target, uni.AtomTrailer) and expr.target.is_attr {
        base_type = self.get_type_of_expression(expr.target.target);
        if isinstance(base_type, types.ClassType) and base_type.is_instantiable_class() {
            # Accessing a method on a class (not instance)
            # Check if accessed member is a method
            if isinstance(expr.target.right, uni.Name) {
                member = self._lookup_class_member(base_type, expr.target.right.value);
                if member {
                    member_type = self.get_type_of_symbol(member.symbol);
                    if isinstance(member_type, types.FunctionType) {
                        # Static methods don't have self, so can't be unbound calls
                        if member_type.function_flags & types.FunctionTypeFlags.StaticMethod {
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

"""
Create a Callable type from type arguments.

This method evaluates type arguments for a Callable type annotation.
It should have zero to two arguments:
- The first argument, if present, should be an ellipsis (...) or a list of
  positional parameter types.
- The second argument, if present, should specify the return type.

Examples:
    Callable[[int, str], bool]  -> FunctionType with int, str params and bool return
    Callable[..., bool]         -> FunctionType with GradualCallableForm flag
    Callable                    -> FunctionType with GradualCallableForm flag (gradual)

Based on Pyright's createCallableType function.

Future work:
    - TypeVar support in parameter types and return type
    - ParamSpec support (Callable[P, T])
    - Concatenate support (Callable[Concatenate[int, P], T])
    - String annotations (forward references)
"""
impl TypeEvaluator._create_callable_type(
    type_args_expr: uni.Expr | None, error_node: uni.Expr
) -> types.FunctionType {
    param_types: list[types.TypeBase] = [];
    return_type: types.TypeBase = types.UnknownType();
    is_gradual: bool = False;
    if type_args_expr is None {
        # Bare Callable without type arguments - treat as gradual form
        is_gradual = True;
        return types.create_callable_type([], return_type, is_gradual=True);
    }
    # Handle the case where type_args_expr is a TupleVal (Callable[[...], ReturnType])
    if isinstance(type_args_expr, uni.TupleVal) {
        type_arg_values = type_args_expr.values;
        if len(type_arg_values) == 0 {
            # Empty Callable[] - emit error and return gradual form
            self.add_diagnostic(
                error_node,
                "Callable requires at least one type argument for return type"
            );
            return types.create_callable_type([], types.UnknownType(), is_gradual=True);
        }
        # First argument: parameter types list or ellipsis
        first_arg = type_arg_values[0];
        if isinstance(first_arg, uni.Ellipsis) {
            # Callable[..., ReturnType] - gradual callable form
            is_gradual = True;
        } elif isinstance(first_arg, uni.ListVal) {
            # Callable[[Type1, Type2, ...], ReturnType]
            for param_expr in first_arg.values {
                param_type = self.get_type_of_expression(param_expr);
                param_type = self._convert_to_instance(param_type);
                param_types.append(param_type);
            }
        } else {
            # Invalid first argument - should be [...] or ...
            self.add_diagnostic(
                first_arg,
                "First argument to Callable must be a list of types [...] or ellipsis (...)"
            );
            # Try to recover by treating it as a single parameter type
            # This handles cases like Callable[int, str] (incorrect but common mistake)
            param_type = self.get_type_of_expression(first_arg);
            param_type = self._convert_to_instance(param_type);
            param_types.append(param_type);
        }
        # Second argument: return type
        if len(type_arg_values) >= 2 {
            return_type_expr = type_arg_values[1];
            return_type = self.get_type_of_expression(return_type_expr);
            return_type = self._convert_to_instance(return_type);
        } else {
            # Missing return type
            self.add_diagnostic(
                error_node, "Callable requires a return type as second argument"
            );
            return_type = types.UnknownType();
        }
        # Check for extra arguments
        if len(type_arg_values) > 2 {
            self.add_diagnostic(
                type_arg_values[2],
                "Callable accepts only two type arguments: parameter types and return type"
            );
        }
    } else {
        # Single type argument - could be:
        # 1. Invalid usage like Callable[ReturnType] (should be Callable[[], ReturnType])
        # 2. Valid advanced patterns like Callable[ParamSpec, T] (not yet supported)
        #
        # For robustness (especially with typeshed stubs), we don't emit an error
        # and instead return a gradual callable form. This avoids false positives
        # when parsing typeshed files that use advanced typing features.
        #
        # Future work: Support ParamSpec, Concatenate, and other advanced Callable patterns.
        return_type = self.get_type_of_expression(type_args_expr);
        return_type = self._convert_to_instance(return_type);
        is_gradual = True;
    }
    return types.create_callable_type(param_types, return_type, is_gradual=is_gradual);
}

"""
Returns the prefetched ClassType for special forms like Callable, Union, etc.
This centralizes the special form lookup logic to avoid hardcoded string checks.
"""
impl TypeEvaluator._get_special_form_type(
    name: str, symbol_type: types.TypeBase
) -> types.ClassType | None {
    if not self.prefetch {
        return None;
    }
    # TODO: handle _SpecialForm types semantically.
    # Verify symbol_type is _SpecialForm (same shared as our prefetched callable_class)
    if not (
        isinstance(symbol_type, types.ClassType)
        and self.prefetch.callable_class
        and isinstance(self.prefetch.callable_class, types.ClassType)
        and symbol_type.shared == self.prefetch.callable_class.shared
    ) {
        return None;
    }
    # Map special form names to their prefetched types
    match name {
        case "Callable":
            return self.prefetch.callable_class;

        # Future special forms:
        # case "Union": return self.prefetch.union_class;
        # case "Optional": return self.prefetch.optional_class;

    }
    return None;
}
