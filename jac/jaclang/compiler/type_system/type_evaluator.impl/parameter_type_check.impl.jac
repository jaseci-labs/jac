"""Validate that the argument types can be assigned to the parameter types."""
impl TypeEvaluator.validate_arg_types(
    args: MatchArgsToParamsResult, checking_overload: bool = False
) -> bool {
    has_errors: bool = False;
    for (arg, param) in args.arg_params.items() {
        if param is None or param.param_type is None {
            continue;
        }
        if isinstance(arg, uni.KWPair) {
            arg_type = self.get_type_of_expression(arg.value);
        } else {
            arg_type = self.get_type_of_expression(arg);
        }

        if not self.assign_type(arg_type, param.param_type) {
            has_errors = True;
            # If we're checking overloads, we don't emit diagnostics here.
            # cause we will try other overloads as well.
            if not checking_overload {
                self.add_diagnostic(
                    arg,
                    f"Cannot assign {arg_type} to parameter '{param.name}' of type {param.param_type}",
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
    # 1. Call to a function.
    if isinstance(caller_type, types.FunctionType) {
        arg_param_match = self.match_args_to_params(expr.params, expr, caller_type);
        if not arg_param_match.argument_errors {
            self.validate_arg_types(arg_param_match);
        }
        return caller_type.return_type or types.UnknownType();
    }
    # 2. Call to an overloaded function.
    if isinstance(caller_type, types.OverloadedType) {
        for overload in caller_type.overloads {
            arg_param_match = self.match_args_to_params(
                expr.params, expr, overload, checking_overload=True
            );
            if not arg_param_match.argument_errors {
                if self.validate_arg_types(arg_param_match, checking_overload=True) {
                    return overload.return_type or types.UnknownType();
                }
            }
        }
        # If none of the overloads matched, emit a diagnostic.
        self.add_diagnostic(
            expr,
            "No matching overload found for the function call with the given arguments",
        );
        return types.UnknownType();
    }
    # 3. Call to TypeVar.
    if isinstance(caller_type, types.ClassType)
    and caller_type.shared == (self.prefetch and self.prefetch.type_var_class.shared) {
        # TODO: validate the args and pass the typevar name.
        return types.TypeVarType();
    }
    # 4. Call to an instantiable class.
    if (
        isinstance(caller_type, types.ClassType)
        and caller_type.is_instantiable_class()
    ) {
        validated = False;
        # Try __new__ first (Python builtins like str, int define constructors here)
        # Skip __new__ from object since it accepts anything (*args, **kwargs)
        if new_method := self._lookup_class_member(caller_type, "__new__") {
            # Only validate __new__ if it's not from object (the base class)
            # object.__new__ accepts (*args, **kwargs) which matches anything
            is_from_object = new_method.class_type.shared.class_name == "object";
            # TODO: This bellow logic to extract overloads is also used in another place
            # unify them and place them in a helper method.
            method_ty = self.get_type_of_symbol(new_method.symbol);
            overloaded_fns: list[types.FunctionType] = [method_ty];
            for overload in new_method.overloads {
                overload_member_ty = self.get_type_of_symbol(overload);
                if isinstance(overload_member_ty, types.FunctionType) {
                    overload_member_ty = overload_member_ty.specialize(caller_type);
                    overloaded_fns.append(overload_member_ty);
                }
            }
            overloaded_ty: types.OverloadedType | None = None;
            if len(overloaded_fns) > 1 {
                overloaded_ty = types.OverloadedType(overloads=overloaded_fns);
            }
            if not is_from_object {
                validated = self._validate_constructor_method(
                    expr, overloaded_ty or method_ty
                );
            }
        }
        # Fall back to __init__ if __new__ didn't have meaningful params
        if not validated {
            if init_method := self._lookup_class_member(caller_type, "__init__") {
                self._validate_constructor_method(
                    expr, self.get_type_of_symbol(init_method.symbol)
                );
            } elif caller_type.is_data_class() {
                self._validate_constructor_method(
                    expr, self._create_dataclass_init_method(caller_type)
                );
            }
        }
        return caller_type.clone_as_instance();
    }
    # 5. Call to a callable object (__call__).
    if caller_type.is_class_instance() {
        # TODO: validate args.
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
) -> MatchArgsToParamsResult {
    arg_params: dict[uni.Expr | uni.KWPair, types.Parameter | None] = {};
    argument_errors = False;
    params_to_match = func_type.parameters.copy();
    # Skip `self`, 'cls' for method calls.
    if (
        len(func_type.parameters) >= 1
        and (func_type.parameters[0].is_self or func_type.parameters[0].is_cls)
    ) {
        params_to_match.pop(0);
    }
    # Create a tracker for parameter assignment.
    param_tracker = type_utils.ParamAssignmentTracker(params_to_match);
    # We iterate over the arguments and match with the parameter, the param_tracker will
    # keep track of the matched parameters and unmatched required parameters.
    #
    # Tracker: p1, p2, /, p3, p4,   *args,       | p6,   **kwargs
    #          ^   ^      ^    ^    ^^   ^       | ^       ^^
    #          |   |      |    |    | \__ \__    | |       | \________
    # Args:    a1, a2,   a3, p4=a4, a5, a6, *a7, | p6=a8, p_kw1=a9, p_kw2=a10
    #         '--------------------------------' | '------------------------'
    #          We match positional with          |  We match named arguments with
    #          tracked parameter index.          |  param name lookup.
    #
    for arg in arg_nodes {
        try {
            if isinstance(arg, uni.KWPair) {
                # Match parameter based on name lookup.
                matching_param = param_tracker.match_named_argument(arg);
                arg_params[arg] = matching_param;
            } else {  # Match parameter based on the position of the argument.

                matching_param = param_tracker.match_positional_argument(arg);
                arg_params[arg] = matching_param;
            }
        } except Exception as e {
            if not checking_overload {
                self.add_diagnostic(arg, str(e));
            }
            argument_errors = True;
        }
    }
    if unmatched_params := param_tracker.get_unmatched_required_params() {
        argument_errors = True;
        names = ", ".join([f"'{p.name}'" for p in unmatched_params]);
        if not checking_overload {
            # Use node_for_error if available, otherwise fall back to first arg
            error_node = node_for_error or (arg_nodes[0] if arg_nodes else None);
            if error_node {
                self.add_diagnostic(
                    error_node,
                    f"Not all required parameters were provided in the function call: {names}",
                );
            }
        }
    }
    return MatchArgsToParamsResult(
        arg_params=arg_params, argument_errors=argument_errors
    );
}

"""
Validate constructor method arguments. Handles both FunctionType and OverloadedType.
Returns True if validation was performed (method has meaningful parameters), False otherwise.
"""
impl TypeEvaluator._validate_constructor_method(
    expr: uni.FuncCall, method_type: TypeBase
) -> bool {
    if isinstance(method_type, types.FunctionType) {
        # Check if method has meaningful params to validate.
        # In Jac, self is not included in the parameter list, so we check > 0.
        # In Python stubs, self/cls is included, so we check > 1.
        has_params = len(method_type.parameters) > 0;
        if has_params
        and (method_type.parameters[0].is_self or method_type.parameters[0].is_cls) {
            # Skip self/cls parameter if present (Python stubs)
            has_params = len(method_type.parameters) > 1;
        }
        if has_params {
            arg_param_match = self.match_args_to_params(expr.params, expr, method_type);
            if not arg_param_match.argument_errors {
                self.validate_arg_types(arg_param_match);
            }
            return True;
        }
        return False;
    }
    if isinstance(method_type, types.OverloadedType) {
        # Try each overload until one matches
        for overload in method_type.overloads {
            arg_param_match = self.match_args_to_params(
                expr.params, expr, overload, checking_overload=True
            );
            if not arg_param_match.argument_errors {
                if self.validate_arg_types(arg_param_match, checking_overload=True) {
                    return True;
                }
            }
        }
        # If none of the overloads matched, emit a diagnostic using the first overload
        if method_type.overloads {
            self.match_args_to_params(
                expr.params, expr, method_type.overloads[0], checking_overload=False
            );
        }
        # Overloaded methods always count as "validated" to prevent
        # falling back to inherited object.__init__ with no params
        return True;
    }
    return False;
}
