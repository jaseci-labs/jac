"""Determine if a class implements a protocol.

This checks if a class has all the methods required by a protocol,
including methods inherited from base classes via MRO.

Uses symbol table lookup to properly handle stub file classes where AST
parent relationships may not be set correctly. When an evaluator is provided,
method signatures are compared using resolved types (via get_type_of_ability
and _assign_callable), which handles complex types like generics, unions, and
aliases correctly.
"""
impl class_implements_protocol(
    cls: types.ClassType, proto: types.ClassType, evaluator: Any = None
) -> bool {
    # Get protocol methods from symbol table (handles stubs where get_methods() may fail)
    proto_methods: dict[str, Any] = {};
    proto_symtab = proto.shared.symbol_table;
    if isinstance(proto_symtab, uni.UniScopeNode) {
        for (name, sym) in proto_symtab.names_in_scope.items() {
            # Include methods (Ability nodes) but skip special attributes
            if sym.decl and isinstance(sym.decl.name_of, uni.Ability) {
                proto_methods[name] = sym.decl.name_of;
            }
        }
    }

    # If no protocol methods found, protocol is trivially satisfied
    if not proto_methods {
        return True;
    }

    # Collect methods from the class and all its MRO classes (first found wins)
    cls_methods: dict[str, Any] = {};
    for mro_cls in cls.shared.mro {
        mro_symtab = mro_cls.shared.symbol_table;
        if isinstance(mro_symtab, uni.UniScopeNode) {
            for (name, sym) in mro_symtab.names_in_scope.items() {
                if sym.decl and isinstance(sym.decl.name_of, uni.Ability) {
                    if name not in cls_methods {
                        cls_methods[name] = sym.decl.name_of;
                    }
                }
            }
        }
    }

    # Check all protocol methods exist AND have compatible signatures
    for (name, proto_method) in proto_methods.items() {
        if name not in cls_methods {
            return False;
        }
        cls_method = cls_methods[name];
        # When evaluator is available, use resolved types for signature comparison.
        # This is the proper approach: resolve each method to a FunctionType and
        # compare using _assign_callable (which handles parameter contravariance
        # and return type covariance correctly).
        if evaluator is not None {
            proto_func_type = evaluator.get_type_of_ability(proto_method);
            cls_func_type = evaluator.get_type_of_ability(cls_method);
            if isinstance(proto_func_type, types.FunctionType)
            and isinstance(cls_func_type, types.FunctionType) {
                if not evaluator._assign_callable(cls_func_type, proto_func_type) {
                    return False;
                }
            }
        }
    }
    return True;
}

"""Lookup a symbol in the symbol table."""
impl lookup_symtab(
    symtable: uni.UniScopeNode, name: str, builtins_to_inject: uni.Module
) -> (Symbol | None) {
    mod: (uni.Module | None) = None;
    if isinstance(symtable, uni.Module) {
        mod = symtable;
    } else {
        mod = symtable.find_parent_of_type(uni.Module);
    }
    if (mod and ((mod.parent_scope is None) and (mod != builtins_to_inject))) {
        mod.parent_scope = builtins_to_inject;
    }
    symbol = symtable.lookup(name, deep=True, incl_inner_scope=True);
    # Filter out imported symbols from builtins module when accessed from user code.
    # In Python stub files, imports are NOT re-exported by default.
    # Symbols like 'types', 'SupportsAdd' are imported into builtins.pyi
    # for internal use, not for user code access.
    # Only filter when the lookup originates from OUTSIDE builtins (user code).
    if (
        symbol
        and symbol.imported
        and symbol.parent_tab is builtins_to_inject
        and mod is not None
        and mod is not builtins_to_inject
    ) {
        return None;
    }
    return symbol;
}

"""Return a list of completion items for the type."""
impl get_completion_items(
    ty: (types.TypeBase | uni.UniScopeNode)
) -> list[CompletionItem] {
    ret = [];
    if isinstance(ty, uni.UniScopeNode) {
        scope: (uni.UniScopeNode | None) = ty;
        while scope {
            for (name, sym) in scope.names_in_scope.items() {
                kind = completion_kind_from_sym(sym);
                ret.append(CompletionItem(label=name, kind=kind));
            }
            scope = scope.parent_scope;
        }
    } elif isinstance(ty, types.ClassType) {
        if not ty.shared.mro {
            compute_mro_linearization(ty);
        }
        for cls in ty.shared.mro {
            for (name, sym) in cls.shared.symbol_table.names_in_scope.items() {
                kind = completion_kind_from_sym(sym);
                ret.append(CompletionItem(label=name, kind=kind));
            }
        }
    } elif isinstance(ty, types.ModuleType) {
        for (name, sym) in ty.symbol_table.names_in_scope.items() {
            kind = completion_kind_from_sym(sym);
            ret.append(CompletionItem(label=name, kind=kind));
        }
    }
    return ret;
}

"""Get the completion item kind from a symbol."""
impl completion_kind_from_sym(sym: Symbol) -> int {
    match sym.decl.name_of {
        case uni.ModulePath():
            return CompletionItemKind.Module;

        case uni.Ability():
            return CompletionItemKind.Function;

        case uni.Archetype():
            return CompletionItemKind.Class;

        case uni.Enum():
            return CompletionItemKind.Enum;

        case uni.HasVar():
            return CompletionItemKind.Variable;

    }
    return CompletionItemKind.Text;
}

"""Check if there are any unmatched required parameters."""
impl ParamAssignmentTracker.get_unmatched_required_params -> list[types.Parameter] {
    ret: list[types.Parameter] = [];
    for param in self.params {
        if (
            (param not in self.matched_params)
            and (param.default_value is None)
            and (
                param.param_kind not in (types.ParamKind.VARARG, types.ParamKind.KWARG)
            )
        ) {
            ret.append(param);
        }
    }
    return ret;
}

"""Match a positional argument to a parameter."""
impl ParamAssignmentTracker.match_positional_argument(
    arg: uni.Expr
) -> (types.Parameter | None) {
    if (self.curr_param_idx == -1) {
        return self.varargs;
    }
    if (isinstance(arg, uni.UnaryExpr) and (arg.op.name == Tok.STAR_MUL)) {
        self._mark_all_positional_params_as_matched();
        return None;
    } else {
        if (self.curr_param_idx < len(self.params)) {
            param = self.params[self.curr_param_idx];
            if (param.param_kind == types.ParamKind.VARARG) {
                self.matched_params.add(param);
                return param;
            }
            if (
                param.param_kind in (types.ParamKind.NORMAL, types.ParamKind.POSONLY)
            ) {
                self.curr_param_idx += 1;
                self.matched_params.add(param);
                return param;
            }
        }
        raise Exception('Too many positional arguments');
    }
}

"""Match a named argument to a parameter."""
impl ParamAssignmentTracker.match_named_argument(
    arg: uni.KWPair
) -> (types.Parameter | None) {
    if (arg.key is None) {
        self._mark_all_named_params_as_matched();
        return None;
    } else {
        if (param := self.lookup_named_parameter(arg.key.sym_name)) {
            return param;
        }
        raise Exception(
            f"Named argument '{arg.key.sym_name}' does not match any parameter"
        );
    }
}

"""Mark all positional parameters as matched."""
impl ParamAssignmentTracker._mark_all_positional_params_as_matched -> None {
    for param in self.params {
        if (
            param.param_kind in (
                types.ParamKind.POSONLY,
                types.ParamKind.NORMAL,
                types.ParamKind.VARARG
            )
        ) {
            self.matched_params.add(param);
        }
    }
    self.curr_param_idx = -1;
}

"""Mark all named parameters as matched."""
impl ParamAssignmentTracker._mark_all_named_params_as_matched -> None {
    for param in self.params {
        if (
            param.param_kind in (
                types.ParamKind.NORMAL,
                types.ParamKind.KWONLY,
                types.ParamKind.KWARG
            )
        ) {
            self.matched_params.add(param);
        }
    }
}

"""Lookup a named parameter by name and if any match is found we mark it as such."""
impl ParamAssignmentTracker.lookup_named_parameter(
    param_name: str
) -> (types.Parameter | None) {
    for param in self.params {
        if (
            (param.param_kind == types.ParamKind.POSONLY) and (param_name == param.name)
        ) {
            self.matched_params.add(param);
            raise Exception(
                f"Positional only parameter '{param.name}' cannot be matched with a named argument"
            );
        }
        if (param.param_kind not in (types.ParamKind.NORMAL, types.ParamKind.KWONLY)) {
            continue;
        }
        if (param.name == param_name) {
            if (param in self.matched_params) {
                raise Exception(f"Parameter '{param.name}' already matched");
            }
            self.matched_params.add(param);
            return param;
        }
    }
    return self.kwargs;
}

"""Initialize varargs and kwargs from params."""
impl ParamAssignmentTracker.postinit -> None {
    for param in self.params {
        if (param.param_kind == types.ParamKind.VARARG) {
            self.varargs = param;
        } elif (param.param_kind == types.ParamKind.KWARG) {
            self.kwargs = param;
        }
    }
}

"""
Compute the method resolution order (MRO) for a class type.

    This uses the C3 linearization algorithm to compute the MRO.
    See https://www.python.org/download/releases/2.3/mro/
"""
impl compute_mro_linearization(cls: types.ClassType) -> None {
    if cls.shared.mro {
        return;
    }
    # Ensure base classes have their MRO computed first
    for base in cls.shared.base_classes {
        if isinstance(base, types.ClassType) {
            compute_mro_linearization(base);
        }
    }
    # C3 linearization: merge base MROs + direct base list
    linearizations: list[list[types.ClassType]] = [];
    for base in cls.shared.base_classes {
        if isinstance(base, types.ClassType) {
            linearizations.append(base.shared.mro[:]);
        }
    }
    base_list: list[types.ClassType] = [];
    for base in cls.shared.base_classes {
        if isinstance(base, types.ClassType) {
            base_list.append(base);
        }
    }
    if base_list {
        linearizations.append(base_list);
    }
    result: list[types.ClassType] = [cls];
    while linearizations {
        # Find a good head: not in the tail of any linearization
        candidate: (types.ClassType | None) = None;
        for lin in linearizations {
            if not lin {
                continue;
            }
            head = lin[0];
            in_tail = False;
            for other_lin in linearizations {
                if head in other_lin[1:] {
                    in_tail = True;
                    break;
                }
            }
            if not in_tail {
                candidate = head;
                break;
            }
        }
        if candidate is None {
            break;  # Inconsistent hierarchy
        }
        result.append(candidate);
        # Remove candidate from all lists
        new_linearizations: list[list[types.ClassType]] = [];
        for lin in linearizations {
            new_lin = [
                c
                for c in lin
                if c is not candidate
            ];
            if new_lin {
                new_linearizations.append(new_lin);
            }
        }
        linearizations = new_linearizations;
    }
    cls.shared.mro = result;
}

"""
Compute module source flags from file path.

Similar to Pyright's SourceFileInfo which computes _isStubFile, _isTypingStubFile,
_isTypeshedStubFile, _isBuiltInStubFile based on the file URI.

These flags help determine how to handle types from the module:
- is_stub_file: True for .pyi files (type stubs)
- is_stdlib_stub: True for files from vendor/typeshed/stdlib/
- is_typing_stub: True for typing.pyi or typing_extensions.pyi
- is_builtin_stub: True for core builtin stubs (builtins.pyi, abc.pyi, etc.)
"""
impl compute_module_source_flags(file_path: str) -> ModuleSourceFlags {
    flags = ModuleSourceFlags();

    # Check if it's a stub file (.pyi)
    flags.is_stub_file = file_path.endswith(".pyi");

    if not flags.is_stub_file {
        return flags;
    }

    # Check if it's from stdlib (vendor/typeshed/stdlib/)
    # Normalize path separators for cross-platform compatibility
    normalized_path = file_path.replace("\\", "/");
    flags.is_stdlib_stub = "vendor/typeshed/stdlib/" in normalized_path;

    # Check if it's a typing stub
    # Similar to Pyright: _isTypingStubFile for typing.pyi and typing_extensions.pyi
    if normalized_path.endswith("stdlib/typing.pyi")
    or normalized_path.endswith("typing_extensions.pyi") {
        flags.is_typing_stub = True;
    }

    # Check if it's a builtin stub (core Python stubs)
    # Similar to Pyright's _isBuiltInStubFile list
    if (
        normalized_path.endswith("stdlib/builtins.pyi")
        or normalized_path.endswith("stdlib/abc.pyi")
        or normalized_path.endswith("stdlib/collections/__init__.pyi")
        or normalized_path.endswith("stdlib/asyncio/futures.pyi")
        or normalized_path.endswith("stdlib/asyncio/tasks.pyi")
        or normalized_path.endswith("stdlib/dataclasses.pyi")
        or normalized_path.endswith("stdlib/enum.pyi")
        or normalized_path.endswith("stdlib/types.pyi")
        or normalized_path.endswith("stdlib/typing.pyi")
        or normalized_path.endswith("stdlib/_typeshed/__init__.pyi")
    ) {
        flags.is_builtin_stub = True;
    }

    return flags;
}

# -------------------------------------------------------------------------
# Type specialization utilities (Pyright: typeUtils.ts)
# -------------------------------------------------------------------------
"""
Convert a type to its instance form. (Pyright: convertToInstance)
"""
impl convert_to_instance(ty: types.TypeBase) -> types.TypeBase {
    if ty.is_instantiable_class() {
        assert isinstance(ty, types.ClassType);
        return ty.clone_as_instance();
    }
    # Handle UnionType: convert each member type to instance form
    if isinstance(ty, types.UnionType) {
        converted = [convert_to_instance(t) for t in ty.types];
        return types.UnionType(types=converted);
    }
    return ty;
}

"""
Apply type variable substitutions to a type.

This is the unified function for TypeVar substitution. Handles all cases:
- Direct TypeVarType -> lookup in solution
- Self type -> class_type instance
- Nested TypeVars in ClassType
- UnionType -> specialize each member
- FunctionType -> specialize parameters and return type
"""
impl apply_solved_type_vars(
    ty: types.TypeBase,
    solution: dict[str, types.TypeBase],
    class_type: (types.ClassType | None) = None
) -> types.TypeBase {
    # Case 1: Direct TypeVar replacement
    if isinstance(ty, types.TypeVarType) {
        # Self TypeVar -> class_type instance (Pyright: isSynthesizedSelf)
        if ty.is_self and class_type is not None {
            return class_type.clone_as_instance();
        }
        # Only substitute TypeVars that are declared class type parameters.
        # Module-level TypeVars that are NOT used as class type params should
        # not be substituted, as they are independent of the class hierarchy.
        #
        # A TypeVar should be substituted if:
        # 1. is_class_type_param flag is True (set when created from class type param), OR
        # 2. Name matches a class type_param AND the TypeVar has NO bound
        #    (module-level TypeVars typically have bounds from TypeVar(...) call,
        #    while class type params from Generic[T] don't unless explicitly bounded)
        #
        # This allows typeshed TypeVars (which don't have is_class_type_param) to be
        # substituted when they match class type params, while preventing module-level
        # TypeVars with explicit bounds from being incorrectly substituted.
        is_declared_class_param = ty.is_class_type_param;
        if not is_declared_class_param and ty.name {
            # Check if this TypeVar matches a class type param by name AND bound
            if class_type is not None {
                for tp in class_type.shared.type_params {
                    if tp.name == ty.name {
                        # Only substitute if the TypeVar's bound matches the class type param's bound
                        # (or if neither has a bound)
                        if ty.bound is None
                        or (tp.bound is not None and ty.bound == tp.bound) {
                            is_declared_class_param = True;
                        }
                        break;
                    }
                }
            }
            # Also allow substitution if the TypeVar has no bound AND name is in solution
            # This handles typeshed TypeVars without bounds
            if not is_declared_class_param
            and ty.bound is None
            and ty.name in solution {
                is_declared_class_param = True;
            }
        }
        if not is_declared_class_param {
            return ty;
        }
        # Regular TypeVar (class type param) -> lookup in solution by name
        if ty.name and ty.name in solution {
            resolved = solution[ty.name];
            return convert_to_instance(resolved);
        }
        # TypeVar not in solution -> check class type_args by index
        if class_type is not None and ty.name {
            for (idx, tp) in enumerate(class_type.shared.type_params) {
                if tp.name == ty.name {
                    if idx < len(class_type.private.type_args) {
                        resolved = class_type.private.type_args[idx];
                        return convert_to_instance(resolved);
                    } else {
                        # TypeVar found but no type_arg available -> Unknown
                        return types.UnknownType();
                    }
                }
            }
        }
        # TypeVar not resolved -> return as is
        return ty;
    }

    # Case 2: FunctionType -> specialize parameters and return type
    if isinstance(ty, types.FunctionType) {
        return _apply_to_function(ty, solution, class_type);
    }

    # Case 3: ClassType with type_args -> recursively specialize nested TypeVars
    if isinstance(ty, types.ClassType) and ty.private.type_args {
        new_args: list[types.TypeBase] = [];
        any_changed = False;
        for type_arg in ty.private.type_args {
            specialized = apply_solved_type_vars(type_arg, solution, class_type);
            new_args.append(specialized);
            if specialized is not type_arg {
                any_changed = True;
            }
        }
        if any_changed {
            return ty.specialize_generics(new_args);
        }
    }

    # Case 4: UnionType -> specialize each member
    if isinstance(ty, types.UnionType) {
        new_types = [apply_solved_type_vars(t, solution, class_type) for t in ty.types];
        return types.UnionType(types=new_types);
    }

    return ty;
}

"""
Build a cumulative TypeVar name -> concrete type mapping for a specialized class.

Walks the MRO accumulating bindings so that inherited TypeVars are resolved
transitively. For example, if Box[int] extends Container[T] and Container[T]
declares get() -> T, then build_type_var_solution(Box[int]) yields {U: int, T: int}.
"""
impl build_type_var_solution(class_type: types.ClassType) -> dict[str, types.TypeBase] {
    solution: dict[str, types.TypeBase] = {};

    # Start with the class's own type_params -> type_args.
    # PEP 484: bare generics (e.g. list without [T]) default unresolved
    # TypeVars to Any so downstream operations (iteration, subscript,
    # method calls) work correctly instead of producing Unknown.
    if class_type.shared.type_params
    and class_type.private.type_args
    and len(class_type.private.type_args) > 0 {
        for (idx, tp) in enumerate(class_type.shared.type_params) {
            if tp.name and idx < len(class_type.private.type_args) {
                solution[tp.name] = class_type.private.type_args[idx];
            }
        }
    } elif class_type.shared.type_params {
        # Bare generic (e.g. list without [T]): default all TypeVars to Any
        # per PEP 484 so downstream operations (iteration, subscript,
        # method calls) work correctly instead of producing Unknown.
        for tp in class_type.shared.type_params {
            if tp.name {
                solution[tp.name] = types.AnyType();
            }
        }
    }

    # Walk MRO and accumulate base class TypeVar mappings.
    # Only add NEW bindings — never overwrite a concrete binding with a TypeVar.
    for mro_cls in class_type.shared.mro {
        if mro_cls.shared.type_params and mro_cls.private.type_args {
            for (idx, tp) in enumerate(mro_cls.shared.type_params) {
                if tp.name and idx < len(mro_cls.private.type_args) {
                    arg = mro_cls.private.type_args[idx];
                    resolved = apply_solved_type_vars(arg, solution);
                    # Only bind if the resolved value is concrete (not a TypeVar).
                    # Never overwrite an existing concrete binding.
                    if not isinstance(resolved, types.TypeVarType) {
                        if tp.name not in solution
                        or isinstance(solution[tp.name], types.TypeVarType) {
                            solution[tp.name] = resolved;
                        }
                    }
                }
            }
        }
    }

    # Propagate TypeVar bindings transitively through the inheritance chain.
    # MRO entries are unspecialized (shared only, no type_args), so Phase 2
    # above misses TypeVars defined on ancestor classes (e.g., _VT_co on
    # Mapping when specializing dict[str, int]). Use the existing
    # specialize_for_base_class infrastructure to get each MRO entry's
    # specialized form, then extract its TypeVar bindings into the solution.
    for mro_cls in class_type.shared.mro {
        if not mro_cls.shared.type_params {
            continue;
        }
        specialized = specialize_for_base_class(class_type, mro_cls);
        if specialized.private.type_args {
            for (idx, tp) in enumerate(specialized.shared.type_params) {
                if tp.name and idx < len(specialized.private.type_args) {
                    arg = specialized.private.type_args[idx];
                    if not isinstance(arg, types.TypeVarType) {
                        if tp.name not in solution
                        or isinstance(solution[tp.name], types.TypeVarType) {
                            solution[tp.name] = arg;
                        }
                    }
                }
            }
        }
    }

    return solution;
}

"""Build type_params → type_args mapping from a specialized class."""
impl build_solution_from_specialized_class(
    class_type: types.ClassType
) -> dict[str, types.TypeBase] {
    solution: dict[str, types.TypeBase] = {};

    if class_type.shared.type_params and class_type.private.type_args {
        for (idx, tp) in enumerate(class_type.shared.type_params) {
            if tp.name and idx < len(class_type.private.type_args) {
                # Skip duplicates (e.g., Generator has _YieldT_co twice)
                if tp.name not in solution {
                    solution[tp.name] = class_type.private.type_args[idx];
                }
            }
        }
    }

    return solution;
}

"""Specialize a base class using type args from the derived class."""
impl specialize_for_base_class(
    src_type: types.ClassType, base_class: types.ClassType
) -> types.ClassType {
    # If same class, return src_type directly
    if src_type.shared == base_class.shared {
        return src_type;
    }

    # If base_class has no type params, no specialization needed
    if not base_class.shared.type_params {
        return base_class;
    }

    # Find the path from src_type to base_class through base_classes
    # and progressively specialize at each step
    return _specialize_for_base_recursive(src_type, base_class);
}

"""
Recursively find and specialize base_class from src_type's inheritance hierarchy.
"""
def _specialize_for_base_recursive(
    src_type: types.ClassType, target_base: types.ClassType
) -> types.ClassType {
    # Direct match
    if src_type.shared == target_base.shared {
        return src_type;
    }

    # Build solution from src_type
    solution = build_solution_from_specialized_class(src_type);

    # Search through base_classes
    if src_type.shared.base_classes {
        for base in src_type.shared.base_classes {
            if not isinstance(base, types.ClassType) {
                continue;
            }

            # Check if this base IS the target or CONTAINS the target in its hierarchy
            if base.shared == target_base.shared {
                # Direct match - specialize base using our solution
                return _apply_solution_to_class(base, solution);
            }

            # Check if target_base is in this base's MRO
            target_in_mro = False;
            for mro_cls in base.shared.mro {
                if mro_cls.shared == target_base.shared {
                    target_in_mro = True;
                    break;
                }
            }

            if target_in_mro {
                # First specialize the intermediate base
                specialized_base = _apply_solution_to_class(base, solution);
                # Then recursively find target_base from the specialized intermediate
                return _specialize_for_base_recursive(specialized_base, target_base);
            }
        }
    }

    # Not found - return base_class unchanged
    return target_base;
}

"""
Apply a TypeVar solution to specialize a ClassType's type_args.
"""
def _apply_solution_to_class(
    class_type: types.ClassType, solution: dict[str, types.TypeBase]
) -> types.ClassType {
    if not class_type.private.type_args {
        return class_type;
    }

    # Apply solution to each type_arg
    new_args: list[types.TypeBase] = [];
    any_changed = False;

    for type_arg in class_type.private.type_args {
        specialized = apply_solved_type_vars(type_arg, solution);
        new_args.append(specialized);
        if specialized is not type_arg {
            any_changed = True;
        }
    }

    if any_changed {
        return class_type.specialize_generics(new_args);
    }

    return class_type;
}

"""Helper to apply type vars to a FunctionType."""
def _apply_to_function(
    func: types.FunctionType,
    solution: dict[str, types.TypeBase],
    class_type: (types.ClassType | None)
) -> types.FunctionType {
    # Clone the function
    clone = types.FunctionType(
        func_name=func.func_name,
        return_type=func.return_type,
        parameters=[
            types.Parameter(
                name=param.name,
                category=param.category,
                param_type=param.param_type,
                default_value=param.default_value,
                is_self=param.is_self,
                is_cls=param.is_cls,
                param_kind=param.param_kind
            ) for param in func.parameters
        ],
        type_params=func.type_params,
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
