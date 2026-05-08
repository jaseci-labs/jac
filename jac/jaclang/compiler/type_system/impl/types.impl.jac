"""Initialize obviously."""
impl UnionType.postinit -> None {
    # Flatten nested union types
    flattened_types: list[TypeBase] = [];
    for ty in self.types {
        if isinstance(ty, UnionType) {
            flattened_types.extend(ty.types);
        } else {
            flattened_types.append(ty);
        }
    }
    self.types = flattened_types;
}

"""Return a string representation of the union type."""
impl UnionType.__str__ -> str {
    if not self.types or len(self.types) == 0 {
        return "<Union>";
    }
    return " | ".join(str(ty) for ty in self.types);
}

"""Return a string representation of the unbound type."""
impl UnboundType.__str__ -> str {
    return "<Unbound>";
}

"""Return a string representation of the unknown type."""
impl UnknownType.__str__ -> str {
    return "<Unknown>";
}

"""Return a string representation of the never type."""
impl NeverType.__str__ -> str {
    return "<Never>";
}

"""Return a string representation of the any type."""
impl AnyType.__str__ -> str {
    return "<Any>";
}

"""Return a string representation of the module type."""
impl ModuleType.__str__ -> str {
    if self.mod_name {
        return f"<module {self.mod_name}>";
    }
    if self.file_uri and str(self.file_uri) != "." {
        return f"<module {self.file_uri}>";
    }
    return "<module>";
}

"""Return a string representation of the type variable."""
impl TypeVarType.__str__ -> str {
    if self.name {
        return self.name;
    }
    return "<TypeVar>";
}

"""Specialize the function type based on the given class type. (Pyright: applySolvedTypeVars)

Uses the unified apply_solved_type_vars from type_utils.
"""
impl FunctionType.specialize(class_type: ClassType) -> FunctionType {
    # Local import to avoid circular dependency at module load time
    import from jaclang.compiler.type_system.type_utils {
        apply_solved_type_vars,
        build_type_var_solution
    }

    # Build cumulative TypeVar solution by walking MRO (handles transitive bindings)
    solution = build_type_var_solution(class_type);

    # Use unified apply_solved_type_vars (handles TypeVar, Self, nested types)
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
        ],
        type_params=self.type_params,
    );

    # Specialize parameter types
    for param in clone.parameters {
        if param.param_type {
            param.param_type = apply_solved_type_vars(
                param.param_type, solution, class_type
            );
        }
    }

    # Specialize return type
    if clone.return_type {
        clone.return_type = apply_solved_type_vars(
            clone.return_type, solution, class_type
        );
    }

    return clone;
}

"""Specialize function-level TypeVars using a pre-built solution mapping.

Used for generic functions like `def find_parent_of_type[T](typ: type[T]) -> (T | None)`.
The solution maps TypeVar names to concrete types (e.g., {"T": Ability}).
"""
impl FunctionType.specialize_func_type_vars(
    solution: dict[(str, TypeBase)]
) -> FunctionType {
    import from jaclang.compiler.type_system.type_utils { apply_solved_type_vars }

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
        ],
        function_flags=self.function_flags,
        type_params=self.type_params,
    );

    # Specialize parameter types
    for param in clone.parameters {
        if param.param_type {
            param.param_type = apply_solved_type_vars(param.param_type, solution);
        }
    }

    # Specialize return type
    if clone.return_type {
        clone.return_type = apply_solved_type_vars(clone.return_type, solution);
    }

    return clone;
}

impl FunctionType.postinit -> None {
    self.parameters = self.parameters or [];
}

"""Return a string representation of the function type."""
impl FunctionType.__str__ -> str {
    # For functions created from Callable annotations, use Callable[...] format
    if self.is_from_callable_annotation() {
        if self.is_gradual_callable_form() {
            return_type_str = str(self.return_type) if self.return_type else "Unknown";
            return f"Callable[..., {return_type_str}]";
        }
        # Collect parameter types
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
    # Standard function representation
    param_strs: list[str] = [];
    for param in self.parameters or [] {
        param_str = param.name;
        if param.param_type {
            param_str = f"{param_str}: {param.param_type}";
        }
        if param.default_value is not None {
            param_str = f"{param_str} = ...";
        }
        param_strs.append(param_str);
    }
    params_str = ", ".join(param_strs);
    func_name = self.func_name or "<anonymous>";
    return_type_str = f" -> {self.return_type}" if self.return_type else "";
    return f"<function {func_name}({params_str}){return_type_str}>";
}

impl OverloadedType.postinit -> None {
    self.overloads = self.overloads or [];
}

"""Return a string representation of the overloaded type."""
impl OverloadedType.__str__ -> str {
    count = len(self.overloads) if self.overloads else 0;
    return f"<overload {count} overloads>";
}

"""Return true if this class is the built-in Node type."""
impl ClassType.is_node_type -> bool {
    import jaclang.jac0core.unitree as uni;
    import from jaclang.jac0core.constant { SymbolType }
    if self.shared.is_root_class {
        return True;
    }
    arch = self.shared.symbol_table;
    assert isinstance(arch, uni.Archetype);
    return (arch.sym_category == SymbolType.NODE_ARCH);
}

"""Return true if this class is the built-in Edge type."""
impl ClassType.is_edge_type -> bool {
    import jaclang.jac0core.unitree as uni;
    import from jaclang.jac0core.constant { SymbolType }
    arch = self.shared.symbol_table;
    assert isinstance(arch, uni.Archetype);
    return (arch.sym_category == SymbolType.EDGE_ARCH);
}

"""Return true if this class is a data class."""
impl ClassType.is_data_class -> bool {
    return self.shared.is_data_class;
}

"""Return true if this class is a NamedTuple."""
impl ClassType.is_namedtuple -> bool {
    return self.shared.is_namedtuple;
}

"""Return true if this class is an enum class."""
impl ClassType.is_enum_class -> bool {
    return self.shared.is_enum_class;
}

"""
        Return true if this class is a builtin class.

        If class_name is provided, also check if the class name matches.
"""
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

"""Lookup a member in the class type."""
impl ClassType.lookup_member_symbol(
    member: str, r_overloaded: list | None = None
) -> (Symbol | None) {
    import jaclang.jac0core.unitree as uni;
    for cls in self.shared.mro {
        all_syms = cls.shared.symbol_table.lookup_all(member, deep=False);
        if all_syms {
            if r_overloaded is not None and len(all_syms) > 1 {
                r_overloaded.extend(all_syms[1:]);
            }
            return all_syms[0];
        }
    }
    # Fallback: check init/postinit parameters and body for self-assignments.
    # When a class/obj is imported from another module, its impl file's self.x
    # assignments may not have been processed by _populate_self_member_symbols.
    # This fallback scans init/postinit to resolve instance attributes.
    for cls in self.shared.mro {
        arch = cls.shared.symbol_table;
        if not isinstance(arch, uni.Archetype) {
            continue;
        }
        is_class = arch.arch_type.name == 'KW_CLASS';
        # Scan both init and postinit (__post_init__) methods.
        for method_name in ('init', '__post_init__') {
            method_sym = arch.lookup(method_name, deep=False);
            if not method_sym or not isinstance(method_sym.decl.name_of, uni.Ability) {
                continue;
            }
            method_ability = method_sym.decl.name_of;
            # Check init parameters (postinit typically has none)
            if (
                isinstance(method_ability.signature, uni.FuncSignature)
                and method_ability.signature.params
            ) {
                for param in method_ability.signature.params {
                    if param.name.value == member and param.name.value != 'self' {
                        arch.def_insert(param.name, access_spec=arch);
                        return arch.lookup(member, deep=False);
                    }
                }
            }
            # Check self.x = ... assignments in method body (including impl body).
            # For class archetypes: accept all self-assignments.
            # For obj/node/edge/walker: only accept annotated assignments
            # (self.x: Type = value) — these should be 'has' fields but we
            # resolve them here to avoid cascading errors.
            for trailer in method_ability.get_all_sub_nodes(uni.AtomTrailer) {
                if not (
                    trailer.parent and isinstance(trailer.parent, uni.Assignment)
                ) {
                    continue;
                }
                if trailer != trailer.parent.target[0] {
                    continue;
                }
                # For obj types, only resolve annotated assignments.
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

"""Return the symbol representing the class."""
impl ClassType.get_class_symbol -> Symbol {
    return self.shared.symbol_table.name.sym;
}

"""Return a new class type specialized with the given type arguments."""
impl ClassType.specialize_generics(type_args: list[TypeBase]) -> ClassType {
    new_private = ClassType.ClassDetailsPrivate(
        type_args=type_args,
        alias_name=self.private.alias_name,  # Preserve alias_name
        literal_value=self.private.literal_value  # Preserve literal_value
    );
    return ClassType(_shared=self.shared, private=new_private, flags=self.flags);
}

impl ClassType.clone_as_class -> ClassType {
    if not self.is_instance() {
        return self;
    }
    private = ClassType.ClassDetailsPrivate(
        type_args=self.private.type_args[:],
        alias_name=self.private.alias_name,  # Preserve alias_name
        literal_value=self.private.literal_value  # Preserve literal_value
    );
    new_flag = self.flags;
    new_flag = TypeFlags((new_flag & ~TypeFlags.Instance));
    new_flags = TypeFlags((new_flag | TypeFlags.Instantiable));
    new_class = ClassType(_shared=self.shared, private=private, flags=new_flags);
    return new_class;
}

"""Clone this class type as an instance type."""
impl ClassType.clone_as_instance -> ClassType {
    if self.is_instance() {
        return self;
    }
    private = ClassType.ClassDetailsPrivate(
        type_args=self.private.type_args[:],
        alias_name=self.private.alias_name,  # Preserve alias_name
        literal_value=self.private.literal_value  # Preserve literal_value
    );
    new_instance = ClassType(_shared=self.shared, private=private, flags=self.flags);
    new_flag = self.flags;
    new_flag = TypeFlags((new_flag & ~TypeFlags.Instantiable));
    new_flags = TypeFlags((new_flag | TypeFlags.Instance));
    new_instance.flags = new_flags;
    return new_instance;
}

"""
Check if this class type is a special form with the given alias name.

Similar to Pyright's ClassType.isSpecialBuiltIn(). Special forms like
Callable, Union, Optional are all _SpecialForm in typing.pyi but have
different alias_names to distinguish them.
"""
impl ClassType.is_special_form(name: str | None = None) -> bool {
    if self.private.alias_name is None {
        return False;
    }
    if name is None {
        return True;  # Any special form
    }
    return self.private.alias_name == name;
}

"""Clone this class type with a literal value.

Creates a new ClassType instance representing a Literal type like Literal["hello"].
Similar to Pyright's creating a class type with literalValue set.
"""
impl ClassType.clone_with_literal(value: (str | int | bool | None)) -> ClassType {
    new_private = ClassType.ClassDetailsPrivate(
        type_args=self.private.type_args[:],
        alias_name=None,  # Clear alias_name for literal types
        literal_value=value
    );
    return ClassType(_shared=self.shared, private=new_private, flags=self.flags);
}

"""Check if this class type is a literal type (has a literal value)."""
impl ClassType.is_literal_type -> bool {
    return self.private.literal_value is not None;
}

"""Get the literal value of this type, or None if not a literal type."""
impl ClassType.get_literal_value -> (str | int | bool | None) {
    return self.private.literal_value;
}

"""Check if this ClassType is a property class (@property or @cached_property)."""
impl ClassType.is_property_class -> bool {
    return self.private.is_property_class;
}

"""Get the return type of the property getter, or None if not a property."""
impl ClassType.get_getter_type_from_property -> (TypeBase | None) {
    if not self.private.is_property_class {
        return None;
    }
    fget = self.private.fget_info;
    if fget is None {
        return None;
    }
    return fget.return_type;
}

"""Return a string representation of the class type."""
impl ClassType.__str__ -> str {
    # Display literal types as Literal[value]
    if self.private.literal_value is not None {
        lit_val = self.private.literal_value;
        if isinstance(lit_val, str) {
            return f"Literal[\"{lit_val}\"]";
        }
        return f"Literal[{lit_val}]";
    }
    # `_shared` can legitimately be None for detached property ClassTypes
    # produced by create_property without an enclosing class context.
    class_name = self._shared.class_name if self._shared is not None else "<unbound>";
    # Include type_args in display for parameterized types (e.g., list[int], dict[str, bool])
    if self.private.type_args {
        args_str = ", ".join(str(arg) for arg in self.private.type_args);
        return f"{class_name}[{args_str}]";
    }
    return f"{class_name}";
}

"""Non-null view of the shared details (asserted)."""
impl ClassType.shared -> ClassType.ClassDetailsShared {
    assert self._shared is not None , "ClassType.shared accessed before construction (detached property ClassType?)";
    return self._shared;
}

"""Initialize obviously."""
impl ClassType.ClassDetailsPrivate.postinit -> None {
    self.type_args = self.type_args or [];
}

"""Initialize obviously."""
impl ClassType.ClassDetailsShared.postinit -> None {
    self.type_params = self.type_params or [];
    self.base_classes = self.base_classes or [];
    self.mro = [];
}

"""Return whether the class is an instance."""
impl TypeBase.is_class_instance -> bool {
    return ((self.category == TypeCategory.Class) and self.is_instance());
}

"""Return whether the class can be instantiated."""
impl TypeBase.is_instantiable_class -> bool {
    return ((self.category == TypeCategory.Class) and self.is_instantiable());
}

"""Return whether the type is an instance."""
impl TypeBase.is_instance -> bool {
    return bool((self.flags & TypeFlags.Instance));
}

"""Return whether the type is instantiable."""
impl TypeBase.is_instantiable -> bool {
    return bool((self.flags & TypeFlags.Instantiable));
}

"""Return an instance of an unknown type."""
impl TypeBase.unknown -> UnknownType {
    return UnknownType();
}

"""Returns the category of the type."""
impl TypeBase.category -> TypeCategory {
    return self.CATEGORY;
}

"""Return true if this type is AnyType, TypeVarType, or object."""
impl TypeBase.is_any_type -> bool {
    # Check for AnyType or TypeVarType using category
    if self.category in (TypeCategory.Any, TypeCategory.TypeVar) {
        return True;
    }
    # Check for object type
    if isinstance(self, ClassType) {
        return self.is_builtin("object");
    }
    return False;
}

"""Return string representation of enum member (e.g., <Color.RED>)."""
impl EnumMemberType.__str__ -> str {
    return f"<{self.enum_class.shared.class_name}.{self.member_info.member_name}>";
}

"""Return the member name as a string (e.g., "RED", "BLUE")."""
impl EnumMemberType.get_name_as_str -> str {
    return self.member_info.member_name;
}

"""Get value type: check member's explicit type first, then enum's inherited type requirement."""
impl EnumMemberType.get_value_type -> TypeBase {
    return self.member_info.value_type
    or self.enum_class.shared.enum_value_type
    or UnknownType();
}

# --- FunctionType Callable support methods ---
"""
Check if this is a gradual callable form (Callable[..., T]).

Gradual callable forms accept any arguments and are compatible with
any function signature. This is used when the parameter types are
not specified (using ellipsis).
"""
impl FunctionType.is_gradual_callable_form -> bool {
    return bool(self.function_flags & FunctionTypeFlags.GradualCallableForm);
}

"""
Check if this function type was created from a Callable annotation.

This distinguishes between:
- Actual function definitions: `def foo(x: int) -> str: ...`
- Callable type annotations: `callback: Callable[[int], str]`

In Jac, Callable annotations are identified by having an empty func_name,
since all actual function definitions have a name.
"""
impl FunctionType.is_from_callable_annotation -> bool {
    return self.func_name == "";
}
