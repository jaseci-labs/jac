"""Validate that the argument types can be assigned to the parameter types."""

impl TypeEvaluator.validate_arg_types(
    args: MatchArgsToParamsResult, checking_overload: bool = False
) -> bool {
    has_errors: bool = False;
    for (arg, param) in args.arg_params.items() {
        if param is None or param.param_type is None {
            continue;
        }
        # Pass param type as expected_type for bidirectional inference
        if isinstance(arg, uni.KWPair) {
            arg_type = self.get_type_of_expression(
                arg.value, expected_type=param.param_type
            );
        } else {
            arg_type = self.get_type_of_expression(arg, expected_type=param.param_type);
        }

        if not self.assign_type(arg_type, param.param_type) {
            has_errors = True;
            if not checking_overload {
                self.emit_diag(
                    E1053,
                    arg,
                    actual=str(arg_type),
                    name=param.name,
                    expected=str(param.param_type)
                );
            }
        }
    }
    return not has_errors;
}

"""
Validate that the arguments can be assigned to the call's parameter list.

Specializes the call based on arg types, and returns the specialized
type of the return value. If it detects an error along the way, it emits
a diagnostic and sets argumentErrors to true.
"""
impl TypeEvaluator.validate_call_args(expr: uni.FuncCall) -> TypeBase {
    caller_type = self.get_type_of_expression(expr.target);

    # `super()` in a method behaves like bare `super` — a proxy for the
    # parent class. Attribute access (`super().method(...)`) dispatches
    # through the parent's MRO; there is no __init__/__call__ to validate.
    if self._is_expr_super(expr.target) {
        return caller_type;
    }

    # Special-form handling for enum.auto() -> int
    if isinstance(caller_type, types.ClassType)
    and caller_type.is_builtin("auto")
    and (not expr.params or len(expr.params) == 0) {
        return self.prefetch.int_class if self.prefetch else types.UnknownType();
    }

    # TypeVar handling - use bound/constraints if available
    if isinstance(caller_type, types.TypeVarType) {
        # Constrained TypeVar - check all constraint types
        if caller_type.constraints {
            for constraint_type in caller_type.constraints {
                if isinstance(constraint_type, types.ClassType) {
                    call_member = self._lookup_class_member(
                        constraint_type, "__call__"
                    );
                    if call_member {
                        # Validate call arguments against this constraint's __call__
                        call_type = self.get_type_of_symbol(call_member.symbol);
                        if isinstance(call_type, types.FunctionType) {
                            arg_param_match = self.match_args_to_params(
                                expr.params, expr, call_type
                            );
                            if not arg_param_match.argument_errors {
                                self.validate_arg_types(arg_param_match);
                            }
                        }
                    } else {
                        self.emit_diag(E1023, expr, type=str(constraint_type));
                    }
                }
            }
            return types.UnknownType();
        }
        if caller_type.bound {
            # Bounded TypeVar - check if bound type has __call__
            bound_type = caller_type.bound;
            if isinstance(bound_type, types.ClassType) {
                # First check if bound type has __call__ method at all
                call_member = self._lookup_class_member(bound_type, "__call__");
                if call_member {
                    # Bound type is callable - validate call arguments
                    call_type = self.get_type_of_symbol(call_member.symbol);
                    if isinstance(call_type, types.FunctionType) {
                        # Validate arguments against the __call__ signature
                        arg_param_match = self.match_args_to_params(
                            expr.params, expr, call_type
                        );
                        if not arg_param_match.argument_errors {
                            self.validate_arg_types(arg_param_match);
                        }
                        return call_type.return_type or types.UnknownType();
                    }
                    # Fallback to magic method call
                    call_ret = self.get_type_of_magic_method_call(
                        bound_type, "__call__", expr.params, expr
                    );
                    if call_ret {
                        return call_ret;
                    }
                    return types.UnknownType();
                }
                # Bound type is not callable (no __call__ method)
                self.emit_diag(E1023, expr, type=str(bound_type));
                return types.UnknownType();
            }
        }
        # Unbounded TypeVar - not callable
        self.emit_diag(E1023, expr, type=caller_type.name);
        return types.UnknownType();
    }

    # Special-form handling for typing.cast(T, val) -> T
    # Without this, cast() matches the `object` overload and returns Any/Unknown.
    if isinstance(caller_type, types.OverloadedType) {
        target_node = expr.target;
        is_cast = False;
        if isinstance(target_node, uni.Name) and target_node.sym {
            dotted = target_node.sym.sym_dotted_name;
            is_cast = dotted.endswith("typing.cast");
        }
        if is_cast and len(expr.params) >= 1 {
            first_arg = expr.params[0];
            first_arg_expr = first_arg.value
                if isinstance(first_arg, uni.KWPair)
                else first_arg;
            cast_target_type = self.get_type_of_expression(first_arg_expr);
            if isinstance(cast_target_type, types.ClassType)
            and cast_target_type.is_instantiable_class() {
                return cast_target_type.clone_as_instance();
            }
            # For non-class types (e.g. cast(str, x)), return the type directly
            if not isinstance(cast_target_type, types.UnknownType) {
                return cast_target_type;
            }
        }
    }

    is_unbound_call = self._is_unbound_method_call(expr);
    if isinstance(caller_type, types.FunctionType) {
        arg_param_match = self.match_args_to_params(
            expr.params, expr, caller_type, is_unbound_call=is_unbound_call
        );
        if not arg_param_match.argument_errors {
            self.validate_arg_types(arg_param_match);
        }
        # Always collect TypeVar bindings, even when the function has no
        # formal `type_params`. Self (PEP 673) is not a declared type param
        # but still needs to be solved from argument types — e.g.
        # `object.__new__(self.__class__)` binds Self → enclosing class via
        # the `cls: type[Self]` parameter.
        bindings = self._collect_type_var_bindings(
            caller_type, expr, is_unbound_call=is_unbound_call
        );
        if bindings {
            specialized = caller_type.specialize_func_type_vars(bindings);
            return specialized.return_type or types.UnknownType();
        }
        return caller_type.return_type or types.UnknownType();
    }
    if isinstance(caller_type, types.OverloadedType) {
        # Prefer overloads with concrete (non-Unknown) return types
        # to avoid broken overloads (e.g. LiteralString) shadowing correct ones.
        _fallback_result: types.TypeBase | None = None;

        # Helper to check if a type contains Unknown or unresolved TypeVars
        def _contains_unknown(ty: types.TypeBase) -> bool {
            if isinstance(ty, types.UnknownType) {
                return True;
            }
            if isinstance(ty, types.TypeVarType) {
                return True;
            }
            if isinstance(ty, types.UnionType) {
                return any(_contains_unknown(member) for member in ty.types);
            }
            if isinstance(ty, types.ClassType) and ty.private.type_args {
                return any(_contains_unknown(arg) for arg in ty.private.type_args);
            }
            return False;
        }

        for overload in caller_type.overloads {
            arg_param_match = self.match_args_to_params(
                expr.params,
                expr,
                overload,
                checking_overload=True,
                is_unbound_call=is_unbound_call
            );

            if not arg_param_match.argument_errors {
                if self.validate_arg_types(arg_param_match, checking_overload=True) {
                    ret_type = overload.return_type;
                    # Infer method-level TypeVars from call arguments and
                    # specialize the return type. Uses the existing
                    # _collect_type_var_bindings infrastructure which handles
                    # bounds, constraints, variance, and nested generics via
                    # assign_type_to_type_var.
                    if ret_type and _contains_unknown(ret_type) {
                        bindings = self._collect_type_var_bindings(
                            overload, expr, is_unbound_call=is_unbound_call
                        );
                        if bindings {
                            ret_type = self._substitute_type_vars(ret_type, bindings);
                        }
                    }
                    # Check if return type is concrete (no Unknown types anywhere)
                    if not _contains_unknown(ret_type or types.UnknownType()) {
                        return ret_type or types.UnknownType();
                    }
                    if _fallback_result is None {
                        _fallback_result = ret_type;
                    }
                }
            }
        }
        if _fallback_result is not None {
            return _fallback_result;
        }
        self.emit_diag(E1054, expr);
        return types.UnknownType();
    }
    if self.is_typevar_class(caller_type) {
        # Pyright: createTypeVarType() - Extract TypeVar name and validate constraints
        type_var_name = "";
        first_constraint_arg: uni.Expr | None = None;
        constraint_count = 0;

        # Helper to extract string literal value from String or MultiString
        def _get_string_lit_value(arg: uni.Expr) -> str | None {
            if isinstance(arg, uni.String) {
                return arg.lit_value;
            } elif isinstance(arg, uni.MultiString) and arg.strings {
                if isinstance(arg.strings[0], uni.String) {
                    return arg.strings[0].lit_value;
                }
            }
            return None;
        }

        is_covariant = False;
        is_contravariant = False;
        bound_type: types.TypeBase | None = None;
        constraint_types: list[types.TypeBase] = [];

        if expr.params and len(expr.params) > 0 {
            first_arg = expr.params[0];
            type_var_name = _get_string_lit_value(first_arg) or "";
            if not type_var_name {
                # Pyright: typeVarFirstArg
                self.emit_diag(E1063, first_arg);
            }

            # Count positional constraint arguments and extract variance kwargs
            for i in range(1, len(expr.params)) {
                arg = expr.params[i];
                if isinstance(arg, uni.KWPair) {
                    # Extract covariant=, contravariant=, and bound= keyword args
                    if isinstance(arg.key, uni.Name) {
                        if arg.key.value == "covariant"
                        and isinstance(arg.value, uni.Bool) {
                            is_covariant = arg.value.value;
                        } elif arg.key.value == "contravariant"
                        and isinstance(arg.value, uni.Bool) {
                            is_contravariant = arg.value.value;
                        } elif arg.key.value == "bound" {
                            # Parse bound type expression
                            bound_type = self.get_type_of_expression(arg.value);
                            # Convert to instance type if needed
                            if isinstance(bound_type, types.ClassType)
                            and bound_type.is_instantiable() {
                                bound_type = bound_type.clone_as_instance();
                            }
                        }
                    }
                    continue;
                }
                # Collect constraint types (positional args after the name)
                constraint_type = self.get_type_of_expression(arg);
                if isinstance(constraint_type, types.ClassType)
                and constraint_type.is_instantiable() {
                    constraint_type = constraint_type.clone_as_instance();
                }
                constraint_types.append(constraint_type);
                constraint_count += 1;
                if first_constraint_arg is None {
                    first_constraint_arg = arg;
                }
            }

            # Pyright: typeVarSingleConstraint
            if constraint_count == 1 and first_constraint_arg {
                self.emit_diag(E1064, first_constraint_arg);
            }
        } else {
            # Pyright: typeVarFirstArg
            self.emit_diag(E1063, expr);
        }
        return types.TypeVarType(
            name=type_var_name,
            is_covariant=is_covariant,
            is_contravariant=is_contravariant,
            bound=bound_type,
            constraints=constraint_types or None
        );
    }
    if self.is_paramspec_class(caller_type) {
        # Handle ParamSpec("P", bound=..., covariant=..., contravariant=...)
        # ParamSpec accepts only a name and optional bound/variance kwargs (no positional constraints).
        param_spec_name = "";
        is_covariant = False;
        is_contravariant = False;
        bound_type: types.TypeBase | None = None;

        def _get_str_lit(arg: uni.Expr) -> str | None {
            if isinstance(arg, uni.String) {
                return arg.lit_value;
            } elif isinstance(arg, uni.MultiString) and arg.strings {
                if isinstance(arg.strings[0], uni.String) {
                    return arg.strings[0].lit_value;
                }
            }
            return None;
        }

        if expr.params and len(expr.params) > 0 {
            param_spec_name = _get_str_lit(expr.params[0]) or "";
            if not param_spec_name {
                self.emit_diag(E1063, expr.params[0]);
            }
            for i in range(1, len(expr.params)) {
                arg = expr.params[i];
                if isinstance(arg, uni.KWPair) and isinstance(arg.key, uni.Name) {
                    if arg.key.value == "covariant"
                    and isinstance(arg.value, uni.Bool) {
                        is_covariant = arg.value.value;
                    } elif arg.key.value == "contravariant"
                    and isinstance(arg.value, uni.Bool) {
                        is_contravariant = arg.value.value;
                    } elif arg.key.value == "bound" {
                        bound_type = self.get_type_of_expression(arg.value);
                        if isinstance(bound_type, types.ClassType)
                        and bound_type.is_instantiable() {
                            bound_type = bound_type.clone_as_instance();
                        }
                    }
                }
            }
        } else {
            self.emit_diag(E1063, expr);
        }
        return types.TypeVarType(
            name=param_spec_name,
            is_covariant=is_covariant,
            is_contravariant=is_contravariant,
            is_param_spec=True,
            bound=bound_type
        );
    }
    if self.is_type_var_tuple_class(caller_type) {
        # Handle TypeVarTuple("Ts") - only accepts a name, no variance or bound
        tvt_name = "";
        if expr.params and len(expr.params) > 0 {
            if isinstance(expr.params[0], uni.String) {
                tvt_name = expr.params[0].lit_value;
            } elif (
                isinstance(expr.params[0], uni.MultiString)
                and expr.params[0].strings
                and isinstance(expr.params[0].strings[0], uni.String)
            ) {
                tvt_name = expr.params[0].strings[0].lit_value;
            }
            if not tvt_name {
                self.emit_diag(E1063, expr.params[0]);
            }
        } else {
            self.emit_diag(E1063, expr);
        }
        return types.TypeVarType(name=tvt_name, is_param_spec=False);
    }
    if (
        isinstance(caller_type, types.ClassType) and caller_type.is_instantiable_class()
    ) {
        matched_method: types.FunctionType | None = None;
        # NamedTuple: use synthesized __new__ with field parameters (not inherited tuple.__new__)
        if caller_type.is_namedtuple() {
            self._validate_constructor_method(
                expr, self._create_namedtuple_new_method(caller_type)
            );
            return caller_type.clone_as_instance();
        }
        if new_method := self._lookup_class_member(caller_type, "__new__") {
            is_from_object = new_method.class_type.shared.class_name == "object";
            if not is_from_object {
                matched_method = self._validate_constructor_method(
                    expr, self._get_method_with_overloads(new_method, caller_type)
                );
            }
        }
        # Fall back to init if __new__ didn't have meaningful params
        if matched_method is None {
            init_method = self._lookup_class_member(caller_type, "init");
            is_from_object = init_method
            and init_method.class_type.shared.class_name == "object";
            # User-defined init: validate args against explicit init.
            if init_method and not is_from_object {
                # Get init type including overloads, then validate call args.
                method_ty = self._get_method_with_overloads(init_method, caller_type);
                matched_method = self._validate_constructor_method(expr, method_ty);
                if matched_method is None and expr.params {
                    # Validate args for init without matching overload to emit arity errors.
                    init_sym_type = self.get_type_of_symbol(init_method.symbol);
                    if isinstance(init_sym_type, types.FunctionType) {
                        self.match_args_to_params(expr.params, expr, init_sym_type);
                    }
                }
            } elif caller_type.is_data_class() {
                # Validate args for dataclass init auto-generated from has-vars.
                self._validate_constructor_method(
                    expr, self._create_dataclass_init_method(caller_type)
                );
            }
        }
        # Infer type arguments for generic classes from call arguments.
        # Use the matched overload for inference (important for zip, filter, etc.)
        # Pyright: validateConstructorArgs uses matched __new__ overload
        inferred_type_args = self._infer_type_args_from_method(
            caller_type, expr, matched_method
        );
        if inferred_type_args {
            has_inferred = any(
                not isinstance(ta, types.UnknownType) for ta in inferred_type_args
            );
            if has_inferred {
                specialized = caller_type.specialize_generics(inferred_type_args);
                return specialized.clone_as_instance();
            }
        }
        return caller_type.clone_as_instance();
    }
    if caller_type.is_class_instance() {
        # Any type is callable and returns Any. This is essential for
        # proxy patterns using __getattr__ that return Any.
        if (
            isinstance(caller_type, types.ClassType)
            and self.prefetch.any_class
            and caller_type.shared == self.prefetch.any_class.shared
        ) {
            return caller_type;  # Any() -> Any

        }
        magic_call_ret = self.get_type_of_magic_method_call(
            caller_type, "__call__", expr.params, expr
        );
        if magic_call_ret {
            return magic_call_ret;
        }
    }
    return types.UnknownType();
}

"""
Match arguments passed to a function to the corresponding parameters in that function.

This matching is done based on positions and keywords. Type evaluation and
validation is left to the caller.
This logic is based on PEP 3102: https://www.python.org/dev/peps/pep-3102/
"""
impl TypeEvaluator.match_args_to_params(
    arg_nodes: list[uni.Expr | uni.KWPair],
    node_for_error: uni.Expr | None,
    func_type: types.FunctionType,
    checking_overload: bool = False,
    is_unbound_call: bool = False
) -> MatchArgsToParamsResult {
    arg_params: dict[uni.Expr | uni.KWPair, types.Parameter | None] = {};
    argument_errors = False;
    params_to_match = func_type.parameters.copy();
    if is_unbound_call {
        # Unbound call: caller provides self explicitly
        # For obj types without explicit self param, inject synthetic self
        if (
            len(func_type.parameters) == 0
            or not (func_type.parameters[0].is_self or func_type.parameters[0].is_cls)
        ) {
            # Inject synthetic self parameter for matching
            synthetic_self = types.Parameter(
                name="self",
                category=types.ParameterCategory.Positional,
                param_type=None,
                is_self=True,
                param_kind=types.ParamKind.NORMAL,
            );
            params_to_match.insert(0, synthetic_self);
        }
        # For class types with explicit self, keep it in params_to_match (don't pop)
    } else {
        # Bound call: pop self/cls as usual.
        # For is_cls, only pop when the function is a classmethod (cls is auto-bound).
        # __new__ is a staticmethod in CPython — its cls param has is_cls=True for
        # constructor resolution but should NOT be auto-stripped in direct calls.
        if len(func_type.parameters) >= 1 {
            first = func_type.parameters[0];
            if first.is_self
            or (
                first.is_cls
                and func_type.function_flags & types.FunctionTypeFlags.ClassMethod
            ) {
                params_to_match.pop(0);
            }
        }
    }
    param_tracker = type_utils.ParamAssignmentTracker(params_to_match);
    for arg in arg_nodes {
        try {
            if isinstance(arg, uni.KWPair) {
                matching_param = param_tracker.match_named_argument(arg);
                arg_params[arg] = matching_param;
            } else {
                matching_param = param_tracker.match_positional_argument(arg);
                arg_params[arg] = matching_param;
            }
        } except Exception as e {
            if not checking_overload {
                err_msg = str(e);
                if "Too many positional arguments" in err_msg {
                    self.emit_diag(E1051, arg);
                } elif "does not match any parameter" in err_msg {
                    self.emit_diag(
                        E1052,
                        arg,
                        name=arg.key.sym_name if isinstance(arg, uni.KWPair) else ""
                    );
                } elif "Positional only parameter" in err_msg {
                    # Extract param name from "Positional only parameter 'X' cannot..."
                    pname = err_msg.split("'")[1] if "'" in err_msg else "";
                    self.emit_diag(E1056, arg, name=pname);
                } elif "already matched" in err_msg {
                    pname = err_msg.split("'")[1] if "'" in err_msg else "";
                    self.emit_diag(E1057, arg, name=pname);
                } elif self._pass is not None {
                    self._pass.emit(E1051, node_override=arg);
                }
            }
            argument_errors = True;
        }
    }
    if unmatched_params := param_tracker.get_unmatched_required_params() {
        argument_errors = True;
        names = ", ".join([f"'{p.name}'" for p in unmatched_params]);
        if not checking_overload {
            error_node = node_for_error or (arg_nodes[0] if arg_nodes else None);
            if error_node {
                self.emit_diag(E1050, error_node, params=names);
            }
        }
    }
    return MatchArgsToParamsResult(
        arg_params=arg_params, argument_errors=argument_errors
    );
}

"""
Validate constructor method call arguments.

Returns the matched FunctionType overload (for __new__/__init__) or None.
This allows the caller to use the matched overload's return type for
classes like zip where __new__ returns a specialized type.

Pyright equivalent: validateNewMethod / validateInitMethod
"""
impl TypeEvaluator._validate_constructor_method(
    expr: uni.FuncCall, method_type: TypeBase
) -> types.FunctionType | None {
    if isinstance(method_type, types.FunctionType) {
        has_params = len(method_type.parameters) > 0;
        if has_params
        and (method_type.parameters[0].is_self or method_type.parameters[0].is_cls) {
            has_params = len(method_type.parameters) > 1;
        }
        if has_params {
            # During construction, self/cls is implicitly provided by the metacall.
            # Strip it before arg matching so user args match the remaining params.
            # This is necessary because __new__ is a staticmethod — its cls param
            # won't be auto-stripped by match_args_to_params (no ClassMethod flag).
            ctor_type = self._strip_implicit_self_cls(method_type);
            arg_param_match = self.match_args_to_params(expr.params, expr, ctor_type);
            if not arg_param_match.argument_errors {
                self.validate_arg_types(arg_param_match);
            }
            return method_type;
        }
        return None;
    }
    if isinstance(method_type, types.OverloadedType) {
        matched_overload: types.FunctionType | None = None;
        for overload in method_type.overloads {
            ctor_overload = self._strip_implicit_self_cls(overload);
            arg_param_match = self.match_args_to_params(
                expr.params, expr, ctor_overload, checking_overload=True
            );

            if not arg_param_match.argument_errors {
                if self.validate_arg_types(arg_param_match, checking_overload=True) {
                    matched_overload = overload;
                    break;
                }
            }
        }
        if matched_overload is None and method_type.overloads {
            ctor_first = self._strip_implicit_self_cls(method_type.overloads[0]);
            self.match_args_to_params(
                expr.params, expr, ctor_first, checking_overload=False
            );
        }
        return matched_overload;
    }
    return None;
}

"""
Strip the implicit self/cls parameter from a method type for constructor matching.

During construction (MyClass(...)), the metacall provides self/cls implicitly.
Returns a new FunctionType with the first parameter removed if it is self or cls.
"""
impl TypeEvaluator._strip_implicit_self_cls(
    method: types.FunctionType
) -> types.FunctionType {
    if (
        method.parameters
        and (method.parameters[0].is_self or method.parameters[0].is_cls)
    ) {
        return types.FunctionType(
            func_name=method.func_name,
            return_type=method.return_type,
            parameters=method.parameters[1:],
            function_flags=method.function_flags,
            type_params=method.type_params,
        );
    }
    return method;
}

"""
Extract and build the complete method type including all overloads.

Combines the base method with all its overload signatures, specializing each
with the caller's class type. Returns an OverloadedType when multiple signatures
exist, otherwise returns the base FunctionType.
"""
impl TypeEvaluator._get_method_with_overloads(
    method_member: Any, caller_type: types.ClassType
) -> TypeBase {
    # Start with the base method as the first (and possibly only) signature.
    method_ty = self.get_type_of_symbol(method_member.symbol);
    # Replace generic T with actual type for the base method too (e.g. T -> int for Foo[int]).
    if isinstance(method_ty, types.FunctionType) {
        method_ty = method_ty.specialize(caller_type);
    }
    overloaded_fns: list[types.FunctionType] = [method_ty];
    for overload in method_member.overloads {
        overload_member_ty = self.get_type_of_symbol(overload);
        if isinstance(overload_member_ty, types.FunctionType) {
            # Replace generic T with actual type, e.g. T -> int for Foo[int].
            overload_member_ty = overload_member_ty.specialize(caller_type);
            overloaded_fns.append(overload_member_ty);
        }
    }
    # Multiple signatures: return all so the caller picks the right one.
    if len(overloaded_fns) > 1 {
        return types.OverloadedType(overloads=overloaded_fns);
    }
    return method_ty;
}

"""
Assign a type to a TypeVar, collecting bindings.

When param_type contains TypeVars and arg_type is concrete, extracts bindings.
Example: param=Iterable[_T], arg=list[Item] -> bindings[_T] = Item
"""
impl TypeEvaluator.assign_type_to_type_var(
    param_type: TypeBase, arg_type: TypeBase, bindings: dict[str, TypeBase]
) -> bool {
    # Direct TypeVar binding
    if isinstance(param_type, types.TypeVarType) {
        if not param_type.name {
            return True;
        }
        resolved_arg = self._convert_to_instance(arg_type);

        # Validate against bound: T(bound=X) requires arg <: X
        if param_type.bound {
            if not self.assign_type(resolved_arg, param_type.bound) {
                return False;
            }
        }

        # Validate against constraints: T(A, B) requires arg <: A or arg <: B
        if param_type.constraints {
            matched = False;
            for constraint in param_type.constraints {
                if self.assign_type(resolved_arg, constraint) {
                    matched = True;
                    break;
                }
            }
            if not matched {
                return False;
            }
        }

        # Check consistency: if already bound, arg must be compatible
        if param_type.name in bindings {
            existing = bindings[param_type.name];
            # Both directions: allow widening (arg assignable to existing
            # OR existing assignable to arg)
            if (
                not self.assign_type(resolved_arg, existing)
                and not self.assign_type(existing, resolved_arg)
            ) {
                return False;
            }
        } else {
            bindings[param_type.name] = resolved_arg;
        }
        return True;
    }

    # Union param type: try to bind TypeVars in each member
    if isinstance(param_type, types.UnionType) {
        for member in param_type.types {
            if isinstance(member, types.TypeVarType) {
                self.assign_type_to_type_var(member, arg_type, bindings);
            }
        }
        return True;
    }

    if (
        isinstance(param_type, types.ClassType)
        and isinstance(arg_type, types.ClassType)
        and self._is_type_subscript(param_type)
        and (arg_type.flags & types.TypeFlags.Instantiable)
    ) {
        for pta in param_type.private.type_args {
            self.assign_type_to_type_var(pta, arg_type.clone_as_instance(), bindings);
        }
        return True;
    }

    # Generic ClassType: match type_args recursively
    if isinstance(param_type, types.ClassType)
    and isinstance(arg_type, types.ClassType) {
        param_type_args = param_type.private.type_args if param_type.private else [];
        specialized = type_utils.specialize_for_base_class(arg_type, param_type);
        arg_type_args = specialized.private.type_args if specialized.private else [];

        for (i, pta) in enumerate(param_type_args) {
            if i < len(arg_type_args) {
                if not self.assign_type_to_type_var(pta, arg_type_args[i], bindings) {
                    return False;
                }
            }
        }
    }
    return True;
}


"""
Infer type arguments for a generic class using the matched constructor overload.

This is the preferred method when we have already matched an overload during
constructor validation (e.g., for zip, filter with overloaded __new__).

IMPORTANT: We use the RAW method type (with TypeVars preserved) for inference,
not the specialized version. The specialized version has TypeVars replaced with
Unknown when the class has no type_args yet (which is what we're trying to infer).

Pyright equivalent: validateNewMethod uses the matched overload's return type
to determine the specialized class type.
"""
impl TypeEvaluator._infer_type_args_from_method(
    caller_type: types.ClassType,
    expr: uni.FuncCall,
    matched_method: types.FunctionType | None
) -> list[TypeBase] {
    # Skip if not generic or already has type_args
    if not caller_type.shared.type_params {
        return [];
    }
    if caller_type.private.type_args {
        return caller_type.private.type_args;
    }

    # Find the raw constructor method that matches the call arguments.
    # We need the RAW version (with TypeVars preserved) for inference.
    init_method = self._find_matching_raw_constructor(
        caller_type, expr, matched_method
    );
    if not init_method {
        return [];
    }

    # Match args to params and collect TypeVar bindings.
    # This is a constructor call, so `cls` is implicit and must be stripped.
    bindings = self._collect_type_var_bindings(
        init_method, expr, is_constructor_call=True
    );

    # First, try direct binding from class type_params (works for enumerate)
    direct_args = [
        bindings.get(tp.name, types.UnknownType())
        for tp in caller_type.shared.type_params
        if tp.name
    ];
    if any(not isinstance(ta, types.UnknownType) for ta in direct_args) {
        return direct_args;
    }

    # If direct binding failed, use return type approach (works for zip)
    # The return type is e.g. zip[tuple[_T1, _T2]] - substitute TypeVars and use
    ret_type = init_method.return_type;
    if isinstance(ret_type, types.ClassType) and ret_type.private.type_args {
        substituted_args: list[TypeBase] = [];
        for arg in ret_type.private.type_args {
            substituted = self._substitute_type_vars(arg, bindings);
            substituted_args.append(substituted);
        }
        if any(not isinstance(ta, types.UnknownType) for ta in substituted_args) {
            return substituted_args;
        }
    }

    return direct_args;
}

"""
Substitute TypeVars in a type using bindings.
"""
impl TypeEvaluator._substitute_type_vars(
    typ: types.TypeBase, bindings: dict[str, types.TypeBase]
) -> types.TypeBase {
    if isinstance(typ, types.TypeVarType) {
        return bindings.get(typ.name, typ);
    }
    if isinstance(typ, types.UnionType) {
        new_members = [
            self._substitute_type_vars(member, bindings) for member in typ.types
        ];
        return types.UnionType(types=new_members);
    }
    if isinstance(typ, types.ClassType) and typ.private.type_args {
        new_args = [
            self._substitute_type_vars(arg, bindings) for arg in typ.private.type_args
        ];
        return typ.specialize_generics(new_args);
    }
    return typ;
}

"""
Find the raw constructor method that matches the call arguments.

For overloaded constructors (like zip.__new__), we need to find the overload
that matches the argument count, then return the RAW version (with TypeVars).
"""
impl TypeEvaluator._find_matching_raw_constructor(
    caller_type: types.ClassType,
    expr: uni.FuncCall,
    matched_method: types.FunctionType | None
) -> types.FunctionType | None {
    # Count call arguments
    positional_arg_count = sum(
        1
        for arg in expr.params
        if not isinstance(arg, uni.KWPair)
    );
    keyword_arg_names = set(
        arg.key.value
        for arg in expr.params
        if isinstance(arg, uni.KWPair) and isinstance(arg.key, uni.Name)
    );

    # Dataclass synthesized init takes priority for dataclasses with keyword args
    if caller_type.is_data_class() and keyword_arg_names {
        dc_init = self._create_dataclass_init_method(caller_type);
        if dc_init {
            # Check if keyword args match dataclass fields
            param_names = {
                p.name
                for p in dc_init.parameters
                if not p.is_self
            };
            if keyword_arg_names.issubset(param_names) {
                return dc_init;
            }
        }
    }

    # Try __new__ first (for builtins like zip, enumerate)
    if new_member := self._lookup_class_member(caller_type, "__new__") {
        if new_member.class_type.shared.class_name != "object" {
            raw_type = self.get_type_of_symbol(new_member.symbol);
            found = self._find_overload_by_arg_count(
                raw_type, positional_arg_count, new_member.overloads
            );
            if found {
                return found;
            }
        }
    }

    # Fall back to init/__init__
    for name in ['init', '__init__'] {
        if member := self._lookup_class_member(caller_type, name) {
            if member.class_type.shared.class_name != "object" {
                raw_type = self.get_type_of_symbol(member.symbol);
                found = self._find_overload_by_arg_count(
                    raw_type, positional_arg_count, member.overloads
                );
                if found {
                    return found;
                }
            }
        }
    }

    # Dataclass synthesized init (fallback for positional args)
    if caller_type.is_data_class() {
        return self._create_dataclass_init_method(caller_type);
    }

    return None;
}

"""Find overload matching argument count."""
impl TypeEvaluator._find_overload_by_arg_count(
    method_type: types.TypeBase, arg_count: int, overload_symbols: list
) -> types.FunctionType | None {
    # Collect all overloads (base + additional)
    overloads: list[types.FunctionType] = [];
    if isinstance(method_type, types.FunctionType) {
        overloads.append(method_type);
    }
    for sym in overload_symbols {
        ovl_type = self.get_type_of_symbol(sym);
        if isinstance(ovl_type, types.FunctionType) {
            overloads.append(ovl_type);
        }
    }

    # Find overload with matching parameter count (excluding self/cls)
    for ovl in overloads {
        # Count non-self/cls, non-keyword-only parameters
        positional_params = sum(
            1
            for p in ovl.parameters
            if not p.is_self and not p.is_cls and p.param_kind != types.ParamKind.KWONLY
        );
        if positional_params == arg_count {
            return ovl;
        }
    }

    # If no exact match, return first with meaningful params
    for ovl in overloads {
        if any(not p.is_self and not p.is_cls for p in ovl.parameters) {
            return ovl;
        }
    }

    return None;
}

"""
Infer type arguments for a generic class from constructor call.

enumerate(items: list[Item]) -> enumerate[Item]
MyGeneric(data=Item()) -> MyGeneric[Item]
"""
impl TypeEvaluator.infer_type_args(
    caller_type: types.ClassType, expr: uni.FuncCall
) -> list[TypeBase] {
    # Skip if not generic or already has type_args
    if not caller_type.shared.type_params {
        return [];
    }
    if caller_type.private.type_args {
        return caller_type.private.type_args;
    }

    # Try own constructor first
    init_method = self._get_constructor_for_inference(caller_type);
    if init_method {
        bindings = self._collect_type_var_bindings(
            init_method, expr, is_constructor_call=True
        );
        direct_args = [
            bindings.get(tp.name, types.UnknownType())
            for tp in caller_type.shared.type_params
            if tp.name
        ];
        if any(not isinstance(ta, types.UnknownType) for ta in direct_args) {
            return direct_args;
        }
    }

    # Walk MRO for inherited constructors and translate bindings
    for mro_cls in caller_type.shared.mro {
        if mro_cls.shared == caller_type.shared {
            continue;
        }
        inherited_init = self._get_constructor_for_inference(mro_cls);
        if inherited_init {
            bindings = self._collect_type_var_bindings(
                inherited_init, expr, is_constructor_call=True
            );
            if bindings {
                # Translate base class TypeVar names to our TypeVar names.
                # If base declares T and we inherit as MyClass[U](Base[U]),
                # then binding {T: int} should become {U: int}.
                translated: dict[str, TypeBase] = {};
                if mro_cls.private.type_args and mro_cls.shared.type_params {
                    # Build reverse map: base TypeVar name -> type_arg expression
                    for (idx, base_tp) in enumerate(mro_cls.shared.type_params) {
                        if base_tp.name and base_tp.name in bindings {
                            bound_type = bindings[base_tp.name];
                            # The type_arg at this position tells us which of our TypeVars maps here
                            if idx < len(mro_cls.private.type_args) {
                                arg = mro_cls.private.type_args[idx];
                                if isinstance(arg, types.TypeVarType) and arg.name {
                                    translated[arg.name] = bound_type;
                                }
                            }
                        }
                    }
                }
                if not translated {
                    # No translation needed — TypeVar names may match directly
                    translated = bindings;
                }
                result = [
                    translated.get(tp.name, types.UnknownType())
                    for tp in caller_type.shared.type_params
                    if tp.name
                ];
                if any(not isinstance(ta, types.UnknownType) for ta in result) {
                    return result;
                }
            }
        }
    }

    return [
        types.UnknownType()
        for tp in caller_type.shared.type_params
        if tp.name
    ];
}

"""
Get constructor method for type inference.
"""
impl TypeEvaluator._get_constructor_for_inference(
    caller_type: types.ClassType
) -> types.FunctionType | None {
    # Try init/__init__
    for name in ['init', '__init__'] {
        if member := self._lookup_class_member(caller_type, name) {
            if member.class_type.shared.class_name != "object" {
                method = self.get_type_of_symbol(member.symbol);
                if isinstance(method, types.FunctionType)
                and self._has_meaningful_params(method) {
                    return method;
                }
            }
        }
    }

    # Try __new__ (enumerate, zip, etc.)
    if member := self._lookup_class_member(caller_type, "__new__") {
        if member.class_type.shared.class_name != "object" {
            method = self.get_type_of_symbol(member.symbol);
            if isinstance(method, types.FunctionType)
            and self._has_meaningful_params(method) {
                return method;
            }
            if isinstance(method, types.OverloadedType) {
                for overload in method.overloads {
                    if self._has_meaningful_params(overload) {
                        return overload;
                    }
                }
            }
        }
    }

    # Dataclass synthesized init
    if caller_type.is_data_class() {
        return self._create_dataclass_init_method(caller_type);
    }

    return None;
}

"""Check if method has meaningful params (not just self/cls)."""
impl TypeEvaluator._has_meaningful_params(method: types.FunctionType) -> bool {
    return any(not p.is_self and not p.is_cls for p in method.parameters);
}

"""
Collect TypeVar bindings from matching call args to method params.
"""
impl TypeEvaluator._collect_type_var_bindings(
    method: types.FunctionType,
    expr: uni.FuncCall,
    is_unbound_call: bool = False,
    is_constructor_call: bool = False
) -> dict[str, TypeBase] {
    bindings: dict[str, TypeBase] = {};
    # Effective parameter list must mirror match_args_to_params so that
    # positional args line up with the same params used during argument
    # validation. Key cases:
    #   - bound method call: first param is self (or cls on classmethods)
    #     and is auto-bound → strip it.
    #   - unbound call (Class.method(instance, ...)): keep self as-is;
    #     inject a synthetic self when the function has no explicit self
    #     param (matches match_args_to_params behavior).
    #   - constructor call (`ClassName(args)` invoking `__new__`/`__init__`):
    #     cls/self is implicit (filled in by the class construction machinery),
    #     so strip it even when the method is a staticmethod-style `__new__`.
    #   - direct staticmethod with is_cls first param (e.g. `object.__new__(x)`):
    #     the cls param is NOT auto-bound; it consumes the first positional
    #     argument and must participate in TypeVar binding. This is how
    #     `Self` gets solved in `object.__new__(self.__class__)`.
    params = method.parameters.copy();
    if is_unbound_call {
        if (len(params) == 0 or not (params[0].is_self or params[0].is_cls)) {
            # Synthetic self: no param_type, so it consumes the receiver
            # arg without contributing bindings.
            params.insert(
                0,
                types.Parameter(
                    name="self",
                    category=types.ParameterCategory.Positional,
                    param_type=None,
                    is_self=True,
                    param_kind=types.ParamKind.NORMAL,
                )
            );
        }
    } elif len(params) >= 1 {
        first = params[0];
        if first.is_self
        or (
            first.is_cls
            and (
                is_constructor_call
                or method.function_flags & types.FunctionTypeFlags.ClassMethod
            )
        ) {
            params.pop(0);
        }
    }

    # Synthesize implicit `Self` annotations for unannotated `self`/`cls`
    # params (PEP 673). Typeshed routinely writes `def __new__(cls) -> Self`
    # and `def method(self) -> Self` without explicit `cls: type[Self]` /
    # `self: Self` annotations — the type checker is expected to fill them
    # in. Without this synthesis, calls like `object.__new__(self.__class__)`
    # can't solve Self from the argument and the return type stays as the
    # raw `Self` TypeVar.
    def _effective_param_type(p: types.Parameter) -> TypeBase | None {
        # `Any`-annotated self/cls is effectively unannotated — typeshed
        # often uses `Any` as the placeholder. Treat both `None` and `Any`
        # as "no annotation" and synthesize the implicit Self form.
        is_unannotated = (
            p.param_type is None
            or (
                isinstance(p.param_type, types.ClassType)
                and self.prefetch is not None
                and self.prefetch.any_class is not None
                and p.param_type.shared == self.prefetch.any_class.shared
            )
        );
        if not is_unannotated {
            return p.param_type;
        }
        if p.is_self {
            return type_utils.synthesize_self_type_var();
        }
        if (
            p.is_cls
            and self.prefetch is not None
            and self.prefetch.type_class is not None
        ) {
            synth = self.prefetch.type_class.clone_as_instance();
            synth.private.type_args = [type_utils.synthesize_self_type_var()];
            return synth;
        }
        return p.param_type;
    }

    param_idx = 0;
    for arg in expr.params {
        if isinstance(arg, uni.KWPair) {
            # Keyword argument - get value for type, use key for param lookup
            if isinstance(arg.key, uni.Name) {
                for param in params {
                    if param.name == arg.key.value {
                        eff = _effective_param_type(param);
                        if eff is not None {
                            arg_type = self.get_type_of_expression(arg.value);
                            self.assign_type_to_type_var(eff, arg_type, bindings);
                        }
                        break;
                    }
                }
            }
            # Skip KWPair with non-Name keys (shouldn't happen in practice)
        } elif param_idx < len(params) {
            # Positional argument
            param = params[param_idx];
            eff = _effective_param_type(param);
            if eff is not None {
                arg_type = self.get_type_of_expression(arg);
                self.assign_type_to_type_var(eff, arg_type, bindings);
            }
            param_idx += 1;
        }
    }

    return bindings;
}
