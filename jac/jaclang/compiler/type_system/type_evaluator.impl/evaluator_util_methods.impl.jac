"""Try to resolve a string annotation as a forward reference to a type.

Returns the resolved type if the string names a type in scope, None otherwise.
This handles patterns like: -> 'Path', has x: 'SomeType' where the string
refers to a type imported under TYPE_CHECKING or defined later in the module.
"""
impl TypeEvaluator._try_resolve_forward_ref(expr: uni.String) -> TypeBase | None {
    name = expr.lit_value;
    if not isinstance(name, str) or not name {
        return None;
    }
    scope = expr.find_parent_of_type(uni.UniScopeNode);
    if not scope {
        return None;
    }
    symbol = type_utils.lookup_symtab(scope, name, self.builtins_module);
    if not symbol {
        return None;
    }
    symbol = self.resolve_imported_symbols(symbol);
    if not symbol.decl or not symbol.decl.name_of {
        return None;
    }
    resolved = self.get_type_of_expression(symbol.defn[-1])
        if symbol.defn
        else self.get_type_of_expression(symbol.decl);
    if isinstance(resolved, types.UnknownType) {
        return None;
    }
    return resolved;
}

"""Build field parameters from class MRO for synthesized constructors."""
impl TypeEvaluator._build_field_params(
    class_type: types.ClassType, skip_deferred: bool = True
) -> dict[str, types.Parameter] {
    param_map: dict[str, types.Parameter] = {};
    for cls in class_type.shared.mro[::-1] {
        for has_var in cls.shared.symbol_table.get_has_vars() {
            if skip_deferred and has_var.defer {
                continue;
            }
            param_type: TypeBase | None = None;
            if has_var.type_tag {
                var_type_expr = has_var.type_tag.tag;
                type_cls = self.get_type_of_expression(var_type_expr);
                param_type = self._convert_to_instance(type_cls);
            }
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
    return param_map;
}

impl TypeEvaluator._create_dataclass_init_method(
    class_type: types.ClassType
) -> types.FunctionType {
    param_map = self._build_field_params(class_type, skip_deferred=True);
    parameters = list(param_map.values());
    return types.FunctionType(
        func_name="__init__", return_type=types.UnknownType(), parameters=parameters,
    );
}

"""Create a synthesized __new__ method for NamedTuple classes.

NamedTuple uses __new__ (not __init__) for construction. The synthesized
__new__ method has parameters matching the declared fields.

Based on Pyright's synthesizeDataClassMethods in dataClasses.ts.
"""
impl TypeEvaluator._create_namedtuple_new_method(
    class_type: types.ClassType
) -> types.FunctionType {
    parameters: list[types.Parameter] = [];
    # Add cls parameter first (NamedTuple __new__ is a classmethod)
    parameters.append(
        types.Parameter(
            name="cls",
            category=types.ParameterCategory.Positional,
            param_type=class_type,
            is_cls=True,
            param_kind=types.ParamKind.NORMAL,
        )
    );
    param_map = self._build_field_params(class_type, skip_deferred=False);
    parameters.extend(list(param_map.values()));
    return types.FunctionType(
        func_name="__new__",
        return_type=class_type.clone_as_instance(),
        parameters=parameters,
        function_flags=types.FunctionTypeFlags.SynthesizedMethod,
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

"""Check if a ClassType is the builtin 'type' class with type arguments (type[T])."""
impl TypeEvaluator._is_type_subscript(class_type: types.ClassType) -> bool {
    return (
        class_type.is_builtin("type")
        and class_type.private.type_args is not None
        and len(class_type.private.type_args) >= 1
    );
}

"""Get lookup type for member access. For type[T], returns T; otherwise returns original."""
impl TypeEvaluator._get_type_for_member_lookup(
    object_type: types.ClassType
) -> types.ClassType {
    if self._is_type_subscript(object_type) {
        inner_type = object_type.private.type_args[0];
        # TODO: Handle TypeVar case - should look up on TypeVar's bound/constraints
        if isinstance(inner_type, types.ClassType) {
            lookup_type = inner_type;
            if not lookup_type.is_instantiable() {
                lookup_type = lookup_type.clone_as_class();
            }
            return lookup_type;
        }
    }
    return object_type;
}

"""Get bound member from a class type. Handles type[T] by looking up on T."""
impl TypeEvaluator.get_type_of_bound_member(
    object_type: types.ClassType, member_name: str
) -> type_utils.ClassMember | None {
    # TODO: Handle type[Any]/type[Unknown] - should return Any for member access
    # TODO: Handle metaclass member lookups
    # TODO: Handle descriptor protocol (__get__, __set__)
    # TODO: Handle __getattr__ fallback when member not found
    object_type_is_instantiable = object_type.is_instantiable();

    if object_type_is_instantiable {
        lookup_type = self._get_type_for_member_lookup(object_type);
        return self._lookup_class_member(lookup_type, member_name);
    } else {
        return self._lookup_object_member(object_type, member_name);
    }
}

"""
Get member type and specialize it with class type_args. (Pyright: getTypeOfMember)

This is the proper way to get a member's type from a specialized generic class.
Instead of getting raw type then manually specializing, this does it in one place.
"""
impl TypeEvaluator.get_type_of_member(
    member: Any, class_type: types.ClassType
) -> TypeBase {
    raw_type = self.get_type_of_symbol(member.symbol);
    return self.specialize_member_type(raw_type, class_type);
}

"""
Substitute TypeVars in a type using class's type_args. (Pyright: partiallySpecializeType)

Examples:
  - T with MyGeneric[Item] -> Item
  - list[T] with MyGeneric[Item] -> list[Item]
  - FunctionType with return T -> specialized return type
  - Self -> class_type (always substituted)

Uses the unified apply_solved_type_vars from type_utils.
"""
impl TypeEvaluator.specialize_member_type(
    member_type: TypeBase, class_type: types.ClassType
) -> TypeBase {
    # Build cumulative TypeVar solution by walking MRO (handles transitive bindings)
    solution = type_utils.build_type_var_solution(class_type);

    # Use unified apply_solved_type_vars (Pyright: applySolvedTypeVars)
    return type_utils.apply_solved_type_vars(member_type, solution, class_type);
}

"""Get the return type of __getattr__ if defined on the class.

When a class defines __getattr__, any attribute access that doesn't match
an explicit member should return the __getattr__ return type. This follows
Pyright's applyAttributeAccessOverride pattern.
"""
impl TypeEvaluator._get_getattr_return_type(
    base_type: types.ClassType
) -> TypeBase | None {
    if member := self._lookup_class_member(base_type, "__getattr__") {
        getattr_type = self.get_type_of_symbol(member.symbol);
        if isinstance(getattr_type, types.FunctionType) {
            return getattr_type.return_type or types.UnknownType();
        }
    }
    return None;
}

"""Convert a class type to an instance type. (Pyright: convertToInstance)

Delegates to the unified type_utils.convert_to_instance function.
"""
impl TypeEvaluator._convert_to_instance(jtype: TypeBase) -> TypeBase {
    # Use unified convert_to_instance from type_utils
    return type_utils.convert_to_instance(jtype);
}

"""Check if a type is already represented in a list (using shared identity for ClassType)."""
impl TypeEvaluator._type_in_list(ty: TypeBase, type_list: list[TypeBase]) -> bool {
    for existing in type_list {
        if isinstance(ty, types.ClassType) and isinstance(existing, types.ClassType) {
            if ty.shared == existing.shared {
                return True;
            }
        } elif ty is existing {
            return True;
        }
    }
    return False;
}

"""Flatten union types and collect unique types into result list."""
impl TypeEvaluator._collect_unique_types(ty: TypeBase, result: list[TypeBase]) -> None {
    if isinstance(ty, types.UnionType) {
        for member in ty.types {
            self._collect_unique_types(member, result);
        }
    } else {
        if not self._type_in_list(ty, result) {
            result.append(ty);
        }
    }
}

"""Extract expected element type from an expected container type.

If expected_type is a parameterized container (list[X], set[X]) matching
the given container_class, return X. Otherwise return None.
"""
impl TypeEvaluator._get_expected_element_type(
    expected_type: TypeBase | None, container_class: TypeBase
) -> TypeBase | None {
    if expected_type is None {
        return None;
    }
    if (
        isinstance(expected_type, types.ClassType)
        and isinstance(container_class, types.ClassType)
        and expected_type.shared == container_class.shared
        and expected_type.private.type_args
        and len(expected_type.private.type_args) >= 1
    ) {
        return self._convert_to_instance(expected_type.private.type_args[0]);
    }
    return None;
}

"""Extract expected key/value types from an expected dict type.

If expected_type is dict[K, V] matching the given dict_class, return (K, V).
Otherwise return None.
"""
impl TypeEvaluator._get_expected_kv_types(
    expected_type: TypeBase | None, dict_class: TypeBase
) -> tuple[TypeBase, TypeBase] | None {
    if expected_type is None {
        return None;
    }
    if (
        isinstance(expected_type, types.ClassType)
        and isinstance(dict_class, types.ClassType)
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

impl TypeEvaluator._get_enclosing_class(nd: uni.UniNode) -> uni.Archetype | None {
    # If the symbol is from a module item, we need to resolve it to the actual symbol.
    # Check if mod_item.name is a Name and has a sym attribute before accessing it
    # Cache the type.
    # __new__ is a staticmethod in CPython; cls is marked is_cls for constructor resolution
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

"""Get the nearest enclosing return scope: the first Ability or LambdaExpr walking up."""
impl TypeEvaluator._get_enclosing_return_scope(
    nd: uni.UniNode
) -> uni.Ability | uni.LambdaExpr | None {
    while nd := nd.parent {
        if isinstance(nd, uni.LambdaExpr) {
            return nd;
        }
        if isinstance(nd, uni.Ability) {
            return nd;
        }
        if isinstance(nd, uni.ImplDef) and isinstance(nd.decl_link, uni.Ability) {
            return nd.decl_link;
        }
    }
    return None;
}

"""Get the resolved return type from an Ability or LambdaExpr, or None if unresolvable."""
impl TypeEvaluator._get_declared_return_type(
    scope: uni.Ability | uni.LambdaExpr
) -> TypeBase | None {
    import from jaclang.compiler.type_system { types }

    if isinstance(scope, uni.LambdaExpr) {
        if (
            isinstance(scope.signature, uni.FuncSignature)
            and scope.signature.return_type is not None
        ) {
            return self._convert_to_instance(
                self.get_type_of_expression(scope.signature.return_type)
            );
        }
        return None;
    }
    # Ability path — resolve via get_type_of_ability (handles both annotated
    # and unannotated cases; unannotated defaults to NoneType).
    fn_type_base = self.get_type_of_ability(scope);
    if not isinstance(fn_type_base, types.FunctionType) {
        return None;
    }
    return self._convert_to_instance(fn_type_base.return_type);
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
        if isinstance(base_type, types.ClassType)
        and base_type.is_instantiable_class() {
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
        # Symbol not resolved yet - call get_type_of_module_item to set it up.
        # This is needed when modules are loaded from JIR cache and their
        # import statements haven't been processed by the type evaluator.
        self.get_type_of_module_item(mod_item);
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

"""Extract TypeVar parameters from Generic[] base class.

Pyright: Also validates that TypeVars aren't already in use by outer scopes.
This is declaration-site validation, separate from use-site validation.
"""
impl TypeEvaluator._extract_type_params(
    node_: uni.Archetype
) -> list[types.TypeVarType] {
    type_params: list[types.TypeVarType] = [];

    # Handle Jac-native generic syntax: obj Box[T], obj Pair[A, B]
    # The type_params field on the Archetype node holds TypeParam AST nodes.
    if node_.type_params {
        for tp in node_.type_params {
            tv = types.TypeVarType(name=tp.sym_name, is_class_type_param=True);
            type_params.append(tv);
        }
        return type_params;
    }

    # Get outer scope TypeVars for "already in use" validation
    outer_type_params = self._get_outer_scope_type_params(node_);
    outer_names = {tp.name for tp in outer_type_params};

    # Handle Python-style generics: obj Box(Generic[T])
    # Track seen TypeVar names to deduplicate (e.g. Mapping(Collection[_KT],
    # Generic[_KT, _VT_co]) would otherwise collect _KT twice).
    #
    # Two-pass strategy: when Generic[...] is explicitly present in the bases,
    # PEP 484 makes it the authoritative declaration of type parameter order.
    # We process it FIRST so other bases don't impose encounter order.
    # e.g. dict_values(ValuesView[_VT_co], Generic[_KT_co, _VT_co]) must produce
    # [_KT_co, _VT_co] (from Generic), not [_VT_co, _KT_co] (encounter order).
    #
    # Generic detection uses two approaches:
    #   1. is_special_form("Generic") on the resolved type (when alias_name is set).
    #   2. AST symbol name fallback — Generic in typeshed stubs resolves to
    #      type[_SpecialForm] without alias_name, so we check the Name node
    #      value directly (mirroring Pyright's aliasedName approach).
    seen_names: set[str] = set();
    generic_base: uni.AtomTrailer | None = None;
    for base_class in node_.base_classes or [] {
        if (not isinstance(base_class, uni.AtomTrailer))
        or base_class.is_attr
        or base_class.is_null_ok {
            continue;
        }
        target_type = self.get_type_of_expression(base_class.target);
        is_generic = (
            isinstance(target_type, types.ClassType)
            and target_type.is_special_form("Generic")
        );
        if (
            not is_generic
            and isinstance(base_class.target, uni.Name)
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

    # Second pass: process all non-Generic bases for remaining TypeVars.
    # When Generic[] was found, this only picks up TypeVars not already seen
    # (should be none in well-formed code). When Generic[] is absent, this is
    # the primary extraction path.
    for base_class in node_.base_classes or [] {
        if (not isinstance(base_class, uni.AtomTrailer))
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

"""Extract TypeVars from a single parameterized base class into type_params.

Handles both single-TypeVar bases like Base[T] and multi-TypeVar bases like
Generic[K, V]. Deduplicates by name using seen_names and validates against
outer_names for outer-scope reuse errors.
"""
impl TypeEvaluator._collect_typevars_from_base(
    base_class: uni.AtomTrailer,
    outer_names: set[str],
    seen_names: set[str],
    type_params: list[types.TypeVarType]
) -> None {
    if not (isinstance(base_class.right, uni.IndexSlice) and base_class.right.slices) {
        return;
    }
    type_vars = base_class.right.slices[0].start;
    if isinstance(type_vars, uni.TupleVal) {
        for val in type_vars.values {
            type_var_type = self.get_type_of_expression(val);
            if isinstance(type_var_type, types.TypeVarType) {
                if type_var_type.name in outer_names {
                    self.emit_diag(E1062, val, name=type_var_type.name);
                }
                if type_var_type.name not in seen_names {
                    seen_names.add(type_var_type.name);
                    # Mark as class type param since it's used in the class's base declaration
                    class_type_var = types.TypeVarType(
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
        if isinstance(type_var_type, types.TypeVarType) {
            if type_var_type.name in outer_names {
                self.emit_diag(E1062, type_vars, name=type_var_type.name);
            }
            if type_var_type.name not in seen_names {
                seen_names.add(type_var_type.name);
                # Mark as class type param since it's used in the class's base declaration
                class_type_var = types.TypeVarType(
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

"""Emit a structured diagnostic via the pass."""
impl TypeEvaluator.emit_diag(
    diag: DiagnosticInfo, nd: uni.UniNode, **kwargs: object
) -> None {
    if self._pass is not None {
        self._pass.emit(diag, node_override=nd, **kwargs);
    }
}

impl TypeEvaluator._is_ability_classmethod(node_: uni.Ability) -> bool {
    # Note: __new__ is a staticmethod in CPython, not a classmethod.
    # Its cls param is marked is_cls for constructor resolution but the
    # function itself should not carry the ClassMethod flag.
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

"""Classify a symbol as @property, @cached_property, or not a property.

Single decorator walk shared by both the read path (get_getter_type_from_property)
and the write path (get_property_write_type).

Returns:
  WRITABLE      — @cached_property (non-data descriptor, assignment is legal)
  READ_ONLY     — @property (data descriptor, needs setter check by caller)
  NOT_PROPERTY  — not decorated with @property or @cached_property
"""
impl TypeEvaluator._classify_property_symbol(
    symbol: uni.Symbol
) -> type_utils.PropertyWriteKind {
    import from jaclang.compiler.type_system.type_utils { PropertyWriteKind }
    node_ = symbol.decl.name_of;
    if not isinstance(node_, uni.Ability) {
        return PropertyWriteKind.NOT_PROPERTY;
    }
    ability = node_;
    if not ability.decorators {
        return PropertyWriteKind.NOT_PROPERTY;
    }
    for decorator in ability.decorators {
        decorator_type = self.get_type_of_expression(decorator);
        if properties.is_cached_property_decorator_type(decorator_type) {
            return PropertyWriteKind.WRITABLE;
        }
        if properties.is_property_decorator_type(decorator_type) {
            return PropertyWriteKind.READ_ONLY;
        }
    }
    return PropertyWriteKind.NOT_PROPERTY;
}

"""Get the return type of a property's getter (read path).

Used by atom-trailer evaluation to unwrap @property / @cached_property
into the getter's return type. Returns None for non-property symbols.
"""
impl TypeEvaluator.get_getter_type_from_property(
    symbol: uni.Symbol
) -> (TypeBase | None) {
    import from jaclang.compiler.type_system.type_utils { PropertyWriteKind }
    kind = self._classify_property_symbol(symbol);
    if kind == PropertyWriteKind.NOT_PROPERTY {
        return None;
    }
    node_ = symbol.decl.name_of;
    if not isinstance(node_, uni.Ability) {
        return None;
    }
    func_type = self.get_type_of_ability(node_);
    if not isinstance(func_type, types.FunctionType) {
        return None;
    }
    return func_type.return_type;
}

"""Classify a symbol's writability for property-aware assignment checking.

Delegates to _classify_property_symbol for the decorator walk, then
determines the concrete write type:

  NOT_PROPERTY  — not @property / @cached_property; use the normal
                  declared-type path.
  READ_ONLY     — @property with no setter; the assignment is illegal.
  WRITABLE      — @cached_property or @property with a @name.setter
                  sibling; `write_type` holds the type values must match.
"""
impl TypeEvaluator.get_property_write_type(
    symbol: uni.Symbol
) -> type_utils.PropertyWriteResult {
    import from jaclang.compiler.type_system.type_utils {
        PropertyWriteKind,
        PropertyWriteResult
    }
    kind = self._classify_property_symbol(symbol);
    if kind == PropertyWriteKind.NOT_PROPERTY {
        return PropertyWriteResult(kind=PropertyWriteKind.NOT_PROPERTY);
    }

    # @cached_property (WRITABLE from classifier): write type = getter return type.
    if kind == PropertyWriteKind.WRITABLE {
        node_ = symbol.decl.name_of;
        if isinstance(node_, uni.Ability) {
            func_type = self.get_type_of_ability(node_);
            if isinstance(func_type, types.FunctionType)
            and func_type.return_type is not None {
                return PropertyWriteResult(
                    kind=PropertyWriteKind.WRITABLE, write_type=func_type.return_type
                );
            }
        }
        # Getter return type couldn't be resolved — treat as writable
        # with unknown type to avoid a false "read-only" diagnostic.
        return PropertyWriteResult(
            kind=PropertyWriteKind.WRITABLE, write_type=types.UnknownType()
        );
    }

    # @property (READ_ONLY from classifier): look for a @<name>.setter
    # sibling in the enclosing class scope. The symbol_table of a method
    # points to the Ability's own scope; the overloads live one level up
    # in the parent (Archetype/class) scope.
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
    # No setter found — read-only.
    return PropertyWriteResult(kind=PropertyWriteKind.READ_ONLY);
}

"""Extract the value-parameter type from a @name.setter decorated method.

Given a symbol that may be decorated with `@<prop_name>.setter`, inspect
its decorators. If a matching setter decorator is found, return the type
of the setter's first non-self/cls parameter (i.e., the value type).
"""
impl TypeEvaluator._get_setter_value_type(
    symbol: uni.Symbol, prop_name: str
) -> (TypeBase | None) {
    node_ = symbol.decl.name_of;
    if not isinstance(node_, uni.Ability) {
        return None;
    }
    ability = node_;
    if not ability.decorators {
        return None;
    }
    for decorator in ability.decorators {
        # @<prop_name>.setter is an AtomTrailer: target=Name(prop_name), right=Name("setter")
        if isinstance(decorator, uni.AtomTrailer) and decorator.is_attr {
            if (
                isinstance(decorator.right, uni.Name)
                and decorator.right.value == "setter"
                and isinstance(decorator.target, uni.Name)
                and decorator.target.value == prop_name
            ) {
                func_type = self.get_type_of_ability(ability);
                if isinstance(func_type, types.FunctionType) and func_type.parameters {
                    # The setter signature is (self, value). FunctionType
                    # parameters include self for methods, so skip it.
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
            self.emit_diag(E1070, error_node);
            return types.create_callable_type(
                [], types.UnknownType(), is_gradual=True
            );
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
            # Check for valid Python 3.10+ Callable[P, T] where P is a ParamSpec/TypeVar.
            # After ParamSpec("P") is evaluated, P has type TypeVarType(is_param_spec=True).
            # After TypeVar("T") is evaluated, T has type TypeVarType.
            # The raw ParamSpec/TypeVarTuple class can also appear in typeshed stubs.
            resolved_first = self.get_type_of_expression(first_arg);
            if isinstance(resolved_first, types.TypeVarType) {
                # Callable[P, T] or Callable[T, T] — ParamSpec or TypeVar as first arg.
                # Treat as gradual: full ParamSpec substitution is future work.
                is_gradual = True;
            } elif self.is_paramspec_class(resolved_first)
            or self.is_type_var_tuple_class(resolved_first) {
                # Raw ParamSpec/TypeVarTuple class used as first arg (common in typeshed stubs).
                is_gradual = True;
            } else {
                # Genuinely invalid first argument — should be [...] or ...
                self.emit_diag(E1071, first_arg);
                # Recover by treating it as a single parameter type
                param_type = self._convert_to_instance(resolved_first);
                param_types.append(param_type);
            }
        }
        # Second argument: return type
        if len(type_arg_values) >= 2 {
            return_type_expr = type_arg_values[1];
            return_type = self.get_type_of_expression(return_type_expr);
            return_type = self._convert_to_instance(return_type);
        } else {
            # Missing return type
            self.emit_diag(E1072, error_node);
            return_type = types.UnknownType();
        }
        # Check for extra arguments
        if len(type_arg_values) > 2 {
            self.emit_diag(E1073, type_arg_values[2]);
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

Pyright reference: handleTypingStubTypeAnnotation (line 16807-16899)
Pyright uses specialTypes Map to handle special form declarations in typing.pyi.
When evaluating a type annotation like `Self: _SpecialForm`, Pyright creates a
SpecialBuiltInClass with the appropriate aliasName.

For Jac, we check if symbol_type is _SpecialForm (same shared as Callable),
then switch on the name to return the appropriate type.

IMPORTANT: Pyright does NOT follow import chains to resolve special forms like Self.
Instead, it uses HARDCODED lookup in handleTypingStubTypeAnnotation():

1. Check if file is typing stub (isTypingStubFile || isTypingExtensionsStubFile)
2. Look up the name in a hardcoded 'specialTypes' map (typeEvaluator.ts:16821-16874)
3. Create special type directly based on the name

The specialTypes map includes:
  - Self, Callable, Union, Optional, Final, Literal, Protocol, Generic,
  - Type, ClassVar, Annotated, Concatenate, TypeGuard, Unpack, Required,
  - NotRequired, Never, NoReturn, LiteralString, TypeIs, TypeForm, etc.

This function implements similar logic: if symbol_type is _SpecialForm OR
if we can't resolve the type but the symbol is from a typing stub, we
match the name against known special forms and return the appropriate type.
"""
impl TypeEvaluator._get_special_form_type(
    name: str, symbol_type: types.TypeBase
) -> types.TypeBase | None {
    if not self.prefetch {
        return None;
    }

    # Check 1: symbol_type is _SpecialForm (original approach)
    # Pyright: ClassType.isSpecialBuiltIn(classType) - checks SpecialBuiltIn flag
    # In Jac, all special forms share the same _SpecialForm class from typing.pyi,
    # so we check if symbol_type.shared matches callable_class.shared (both are _SpecialForm)
    is_special_form = (
        isinstance(symbol_type, types.ClassType)
        and self.prefetch.callable_class
        and symbol_type.shared == self.prefetch.callable_class.shared
    );

    # Check 2: symbol_type is Unknown but name is a known typing special form
    # This handles the case where Self is imported through a chain:
    #   builtins.pyi -> typing_extensions.pyi -> typing.pyi
    # The import chain can't be resolved, but we know "Self" is a special form.
    # Pyright handles this via hardcoded specialTypes map in handleTypingStubTypeAnnotation.
    is_known_special_form_name = name in (
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

    # Pyright: createSpecializedClassType switch on aliasedName (line 21074)
    # Map special form names to their handling
    match name {
        case "Callable":
            # Bare Callable is Callable[..., Any] per PEP 484.
            # Return a gradual FunctionType so it's usable as a callable.
            # The subscript handler checks is_from_callable_annotation() to
            # recognize this as a Callable base for Callable[[int], str] syntax.
            return types.create_callable_type([], types.AnyType(), is_gradual=True);

        case "Protocol":
            return self.prefetch.protocol_class;

        case "Final":
            return self.prefetch.final_class;

        case "LiteralString":
            return self.prefetch.literal_string_class;

        case "Self":
            # Pyright: createSelfType (line 21227-21228) - returns TypeVarType for Self
            return types.TypeVarType(name="Self", is_self=True);

        # TODO: Add Literal[...] annotation parsing support (e.g., x: Literal["a", "b"] = "a")
        # Requires _create_literal_type() method to parse type args into literal ClassTypes.

        # Future special forms:
        # case "Union": return self.prefetch.union_class;
        # case "Optional": return self.prefetch.optional_class;

    }
    return None;
}

"""
Create Self type if symbol is typing.Self. (Pyright: createSelfType)

Self is a special TypeVar that represents the current class type.
Returns TypeVarType("Self") if the symbol type is _SpecialForm, None otherwise.

NOTE: This function is now largely handled by _get_special_form_type which
checks if the type is _SpecialForm and switches on the name.
"""
impl TypeEvaluator.create_self_type(
    symbol_type: types.TypeBase
) -> types.TypeVarType | None {
    if not self.prefetch {
        return None;
    }
    # Pyright: Check if symbol_type is _SpecialForm (same shared as Callable)
    if not isinstance(symbol_type, types.ClassType) {
        return None;
    }
    if not self.prefetch.callable_class {
        return None;
    }
    # Check if it's a _SpecialForm
    if symbol_type.shared == self.prefetch.callable_class.shared {
        return types.TypeVarType(name="Self", is_self=True);
    }
    return None;
}

"""Resolve the filesystem path for the from-clause of an import.

Bare-dot imports (from . import x) have no named module component, so
resolve_relative_path() is unreliable. Walk up from the current file directly.
"""
impl TypeEvaluator._resolve_from_path(from_mod: uni.ModulePath) -> Path {
    if from_mod.level > 0 and not from_mod.path {
        # Start from the directory containing the current module file.
        base = Path(from_mod.loc.mod_path).parent;
        for _ in range(max(from_mod.level - 1, 0)) {
            base = base.parent;
        }
        return base;
    }
    # Named import — use the standard resolver (e.g. from .utils import x).
    return Path(from_mod.resolve_relative_path());
}

"""Check if an f-string contains only literal parts (no non-literal interpolations).

An f-string is considered all-literal if:
1. All parts are String nodes, OR
2. FormattedValue parts have expressions that evaluate to literal types

This is used to determine if an f-string result should be LiteralString or str.
Similar to Pyright's isLiteralString check in getTypeOfString().
"""
impl TypeEvaluator._is_fstring_all_literal(fstring: uni.FString) -> bool {
    for part in fstring.parts {
        if isinstance(part, uni.String) {
            # String parts are always literal
            continue;
        }
        if isinstance(part, uni.FormattedValue) {
            # Check if the formatted expression evaluates to a literal type
            part_type = self.get_type_of_expression(part.format_part);
            if isinstance(part_type, types.ClassType) {
                # Accept if it's a literal type or LiteralString
                if part_type.is_literal_type() {
                    continue;
                }
                if self.prefetch and self.prefetch.literal_string_class {
                    if isinstance(
                        self.prefetch.literal_string_class, types.ClassType
                    ) {
                        if part_type.shared == self.prefetch.literal_string_class.shared {
                            continue;
                        }
                    }
                }
            }
            # Not a literal type - f-string result is plain str
            return False;
        }
    }
    return True;
}

"""Create a synthetic special builtin type with a base class.

Similar to Pyright's createSpecialBuiltInClass which creates types like
LiteralString as a ClassType with str as base class.
"""
impl TypeEvaluator._create_special_builtin_type(
    name: str, base_class: types.ClassType
) -> types.ClassType {
    shared = types.ClassType.ClassDetailsShared(
        class_name=name,
        symbol_table=base_class.shared.symbol_table,
        base_classes=[base_class],
        mro=[],
        is_builtin_class=True
    );
    special_type = types.ClassType(_shared=shared, flags=base_class.flags);
    # Compute MRO: [SpecialType, BaseClass, ...]
    special_type.shared.mro = [special_type] + base_class.shared.mro;
    return special_type;
}

# -------------------------------------------------------------------------
# TypeVar scope validation (Pyright: validateTypeVarUsage)
# -------------------------------------------------------------------------
"""Get TypeVar parameters from the IMMEDIATE enclosing class only.

Unlike _get_enclosing_class_type_params which walked all parent classes,
this only gets type_params from the directly enclosing class.
TypeVars don't cascade into nested non-generic classes.
"""
impl TypeEvaluator._get_enclosing_class_type_params(
    node_: uni.UniNode
) -> list[types.TypeVarType] {
    type_params: list[types.TypeVarType] = [];
    current: uni.UniNode | None = node_;

    while current {
        if isinstance(current, uni.Archetype) {
            # Get type params from ONLY this class's Generic[] base
            class_type = self.get_type_of_class(current);
            if class_type.shared.type_params {
                for tp in class_type.shared.type_params {
                    type_params.append(tp);
                }
            }
            break;  # Only check immediate class, not parents
        }
        current = current.parent;
    }
    return type_params;
}

"""Get TypeVar parameters from a function's signature.

Collects TypeVars used in parameter types and return type.
Also recursively collects TypeVars from nested types like list[T].
"""
impl TypeEvaluator._get_function_type_params(
    func: uni.Ability
) -> list[types.TypeVarType] {
    type_params: list[types.TypeVarType] = [];
    if not isinstance(func.signature, uni.FuncSignature) {
        return type_params;
    }

    # Helper to recursively extract TypeVars from type expressions
    def collect_typevars(expr: uni.Expr) {
        if isinstance(expr, uni.Name) {
            t = self.get_type_of_expression(expr);
            if isinstance(t, types.TypeVarType) {
                type_params.append(t);
            }
        } elif isinstance(expr, uni.AtomTrailer) and not expr.is_attr {
            if isinstance(expr.right, uni.IndexSlice) {
                for s in expr.right.slices {
                    if s.start {
                        collect_typevars(s.start);
                    }
                }
            }
        } elif isinstance(expr, uni.TupleVal) {
            for v in expr.values {
                collect_typevars(v);
            }
        } elif isinstance(expr, uni.BinaryExpr) {
            collect_typevars(expr.left);
            collect_typevars(expr.right);
        }
    }

    # Check parameter types
    for param in func.signature.get_parameters() {
        if param.type_tag {
            collect_typevars(param.type_tag.tag);
        }
    }

    # Check return type
    if func.signature.return_type {
        collect_typevars(func.signature.return_type);
    }

    return type_params;
}

"""Recursively validate TypeVar usage in a type expression.

Pyright: This traverses type annotations to find TypeVar usages
and validates each one is in a valid scope.
"""
impl TypeEvaluator.validate_typevar_in_type_expr(expr: uni.Expr) -> None {
    if isinstance(expr, uni.Name) {
        resolved_type = self.get_type_of_expression(expr);
        if isinstance(resolved_type, types.TypeVarType) {
            self.validate_typevar_scope(expr, resolved_type);
        }
    } elif isinstance(expr, uni.AtomTrailer) {
        # Handle generic types like list[T] - check the subscript
        if not expr.is_attr and isinstance(expr.right, uni.IndexSlice) {
            for slice in expr.right.slices {
                if slice.start {
                    self.validate_typevar_in_type_expr(slice.start);
                }
            }
        }
    } elif isinstance(expr, uni.TupleVal) {
        # Handle tuple of types (e.g., Union[T, S])
        for val in expr.values {
            self.validate_typevar_in_type_expr(val);
        }
    } elif isinstance(expr, uni.BinaryExpr) {
        # Handle union types with | operator (e.g., T | None)
        self.validate_typevar_in_type_expr(expr.left);
        self.validate_typevar_in_type_expr(expr.right);
    }
}

"""Validate TypeVar variance in method parameters and return types.

Pyright: Covariant TypeVars cannot be used in parameter types (input position).
         Contravariant TypeVars cannot be used in return types (output position).
         Only applies to DIRECT methods of generic classes (not nested functions).
"""
impl TypeEvaluator.validate_typevar_variance(func: uni.Ability) -> None {
    # Only validate DIRECT methods of a generic class (not nested functions)
    # Check if parent is directly the class (not another function)
    if not isinstance(func.parent, uni.Archetype) {
        return;
    }
    enclosing_class = func.parent;

    # Get the class's type parameters
    class_type = self.get_type_of_class(enclosing_class);
    if not class_type or not class_type.shared.type_params {
        return;
    }

    # Build map of class-scoped TypeVar names to their variance
    class_tvars: dict[str, types.TypeVarType] = {};
    for tp in class_type.shared.type_params {
        class_tvars[tp.name] = tp;
    }

    # Helper to check variance - only direct TypeVar, not in unions for params
    def check_expr(expr: uni.Expr, is_return: bool) {
        if isinstance(expr, uni.Name) {
            resolved = self.get_type_of_expression(expr);
            if isinstance(resolved, types.TypeVarType)
            and resolved.name in class_tvars {
                tv = class_tvars[resolved.name];
                if is_return and tv.is_contravariant {
                    self.emit_diag(E1080, expr);
                } elif not is_return and tv.is_covariant {
                    self.emit_diag(E1081, expr);
                }
            }
        } elif isinstance(expr, uni.BinaryExpr) and is_return {
            # Only check unions for return types, not parameters
            check_expr(expr.left, is_return);
            check_expr(expr.right, is_return);
        }
        # Note: list[T] - T is in invariant position, so we don't recurse into subscripts
    }

    if not isinstance(func.signature, uni.FuncSignature) {
        return;
    }

    # Check parameter types (covariant not allowed - direct usage only)
    params = func.signature.get_parameters();
    if params {
        for param in params {
            if param.type_tag and isinstance(param.type_tag.tag, uni.Expr) {
                check_expr(param.type_tag.tag, False);
            }
        }
    }

    # Check return type (contravariant not allowed)
    if func.signature.return_type {
        check_expr(func.signature.return_type, True);
    } else {
        # Check inferred return type from return statements
        for ret_stmt in func.get_all_sub_nodes(uni.ReturnStmt) {
            if ret_stmt.expr and isinstance(ret_stmt.expr, uni.Name) {
                resolved = self.get_type_of_expression(ret_stmt.expr);
                if isinstance(resolved, types.TypeVarType)
                and resolved.name in class_tvars {
                    tv = class_tvars[resolved.name];
                    if tv.is_contravariant {
                        self.emit_diag(E1080, ret_stmt);
                    }
                }
            }
        }
    }
}

"""Validate that a TypeVar is used in a valid scope.

Pyright: validateTypeVarUsage / enforceClassTypeVarScope

A TypeVar is valid if:
1. Inside a function that uses it in parameters/return type
2. Inside a class that declares it in Generic[T, ...] (ONLY that class, not parents)
3. NOT valid: at module level or in nested non-generic class
"""
impl TypeEvaluator.validate_typevar_scope(
    expr: uni.Expr, type_var: types.TypeVarType
) -> None {
    # Module-level TypeVars (defined via glob T = TypeVar("T")) are valid
    # when used in a function/method signature (param types or return type),
    # including impl blocks. They are NOT valid in class bodies, function
    # bodies, or at module level outside signatures.
    # Check this early to avoid recursive validation loops that occur when
    # _get_function_type_params evaluates signature types.
    if isinstance(expr, uni.Name) and expr.sym {
        sym_decl = expr.sym.decl;
        if sym_decl {
            # Check if the TypeVar is declared at module level
            is_module_level = False;
            decl_parent = sym_decl.parent;
            while decl_parent {
                if isinstance(decl_parent, uni.Module) {
                    is_module_level = True;
                    break;
                }
                if isinstance(decl_parent, (uni.Archetype, uni.Ability)) {
                    break;  # Not module-level
                }
                decl_parent = decl_parent.parent;
            }
            # If module-level, check that expr is inside a function signature
            if is_module_level {
                sig_check = expr.parent;
                while sig_check {
                    if isinstance(sig_check, uni.FuncSignature) {
                        return;  # Valid: module-level TypeVar in function signature

                    }
                    if isinstance(
                        sig_check, (uni.Ability, uni.Archetype, uni.Module)
                    ) {
                        break;  # Reached a scope boundary without finding signature
                    }
                    sig_check = sig_check.parent;
                }
            }
        }
    }

    # Find IMMEDIATE enclosing scope (class or function)
    enclosing_class: uni.Archetype | None = None;
    enclosing_func: uni.Ability | None = None;
    current: uni.UniNode | None = expr.parent;

    while current {
        if isinstance(current, uni.Archetype) and enclosing_class is None {
            enclosing_class = current;
        }
        if isinstance(current, uni.Ability) and enclosing_func is None {
            enclosing_func = current;
        }
        current = current.parent;
    }

    # Case 1: Inside a function - check if TypeVar is in function's signature
    if enclosing_func {
        func_type_params = self._get_function_type_params(enclosing_func);
        for tp in func_type_params {
            if tp.name == type_var.name {
                return;  # Valid: TypeVar used in function signature

            }
        }
        # TypeVar not in scope for this function
        self.emit_diag(E1065, expr, name=type_var.name);
        return;
    }

    # Case 2: Inside a class (but not in a function) - check ONLY immediate class type_params
    if enclosing_class {
        class_type_params = self._get_enclosing_class_type_params(enclosing_class);
        for tp in class_type_params {
            if tp.name == type_var.name {
                return;  # Valid: TypeVar declared in this class

            }
        }
        # TypeVar not declared in this class
        self.emit_diag(E1065, expr, name=type_var.name);
        return;
    }

    # Case 3: At module level (not in class or function)
    self.emit_diag(E1065, expr, name=type_var.name);
}

"""Get TypeVar parameters from ALL outer scopes (classes and functions).

Pyright: Used for "TypeVar is already in use by outer scope" validation.
This collects TypeVars from ALL parent classes and functions, not just immediate.

Used when validating Generic[] declarations in nested classes.
"""
impl TypeEvaluator._get_outer_scope_type_params(
    node_: uni.UniNode
) -> list[types.TypeVarType] {
    type_params: list[types.TypeVarType] = [];
    current: uni.UniNode | None = node_.parent;

    while current {
        if isinstance(current, uni.Archetype) {
            # Get type params from this outer class
            class_type = self.get_type_of_class(current);
            if class_type.shared.type_params {
                for tp in class_type.shared.type_params {
                    type_params.append(tp);
                }
            }
        } elif isinstance(current, uni.Ability) {
            # Get type params from enclosing function
            func_params = self._get_function_type_params(current);
            for tp in func_params {
                type_params.append(tp);
            }
        }
        current = current.parent;
    }
    return type_params;
}

"""Check if a function body contains only ellipsis (stub body)."""
impl TypeEvaluator._is_ellipsis_only_body(body: list[uni.CodeBlockStmt]) -> bool {
    has_ellipsis = False;
    for stmt in body {
        if isinstance(stmt, uni.Semi) {
            continue;
        }
        if isinstance(stmt, uni.ExprStmt) and isinstance(stmt.expr, uni.Ellipsis) {
            has_ellipsis = True;
            continue;
        }
        return False;
    }
    return has_ellipsis;
}

"""Infer return type for a block-body lambda from its return statements.

Walks the body collecting ReturnStmt nodes (without descending into nested
Ability or LambdaExpr scopes). Accounts for implicit None on fall-through
paths: if not every code path returns a value, NoneType is included in the
result. If no return-with-value is found at all, returns NoneType."""
impl TypeEvaluator._infer_lambda_block_return_type(
    body: list[uni.CodeBlockStmt]
) -> TypeBase {
    import from jaclang.compiler.type_system { types }

    none_type = self._convert_to_instance(self.get_none_type());
    return_types: list[TypeBase] = [];
    always_returns = self._collect_return_types(body, return_types);

    if not return_types {
        # No return-with-value found → implicit None return.
        return none_type;
    }

    # If not all code paths return a value, the function can fall through
    # to an implicit None return.
    if not always_returns {
        return_types.append(none_type);
    }

    # Deduplicate: remove NoneType duplicates and collapse single-type results.
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

    return types.UnionType(types=seen);
}

"""Collect return-expression types from a statement block, returning whether
all code paths return a value. Stops at nested Ability/LambdaExpr boundaries."""
impl TypeEvaluator._collect_return_types(
    stmts: list[uni.CodeBlockStmt], out: list[TypeBase]
) -> bool {
    for stmt in stmts {
        # Nested scopes own their own returns.
        if isinstance(stmt, (uni.Ability, uni.LambdaExpr)) {
            continue;
        }

        if isinstance(stmt, uni.ReturnStmt) {
            if stmt.expr and not isinstance(stmt.expr, uni.Null) {
                out.append(self.get_type_of_expression(stmt.expr));
            }
            # Any return (bare or with value) means this path terminates.
            return True;
        }

        if isinstance(stmt, uni.RaiseStmt) {
            return True;
        }

        # --- Compound statements: recurse into their specific body fields ---
        if isinstance(stmt, uni.IfStmt) {
            if_returns = self._collect_return_types(list(stmt.body), out);
            else_returns = self._collect_if_else_returns(stmt.else_body, out);
            if if_returns and else_returns {
                return True;
            }
            continue;
        }

        if isinstance(stmt, uni.MatchStmt) {
            if stmt.cases {
                all_return = True;
                for case in stmt.cases {
                    mc: uni.MatchCase = case;
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

        if isinstance(stmt, uni.SwitchStmt) {
            if stmt.cases {
                has_default = False;
                all_return = True;
                for case in stmt.cases {
                    sc: uni.SwitchCase = case;
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

        if isinstance(stmt, uni.TryStmt) {
            try_returns = self._collect_return_types(list(stmt.body), out);
            if try_returns {
                if not stmt.excepts or len(stmt.excepts) == 0 {
                    return True;
                }
                all_except = True;
                for exc in stmt.excepts {
                    ex: uni.Except = exc;
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

        if isinstance(stmt, uni.WithStmt) {
            if self._collect_return_types(list(stmt.body), out) {
                return True;
            }
            continue;
        }

        # For/while loops: collect returns inside but a loop never guarantees
        # all paths return (it might iterate zero times).
        if isinstance(stmt, (uni.IterForStmt, uni.InForStmt, uni.WhileStmt)) {
            self._collect_return_types(list(stmt.body), out);
            continue;
        }
    }
    return False;
}

"""Helper: collect return types from the else branch of an IfStmt."""
impl TypeEvaluator._collect_if_else_returns(
    else_body: uni.ElseIf | uni.ElseStmt | None, out: list[TypeBase]
) -> bool {
    if else_body is None {
        return False;
    }
    if isinstance(else_body, uni.ElseStmt) {
        return self._collect_return_types(list(else_body.body), out);
    }
    if isinstance(else_body, uni.ElseIf) {
        if_returns = self._collect_return_types(list(else_body.body), out);
        else_returns = self._collect_if_else_returns(else_body.else_body, out);
        return if_returns and else_returns;
    }
    return False;
}
