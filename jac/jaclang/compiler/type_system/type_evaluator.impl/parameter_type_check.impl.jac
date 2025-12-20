"""Validate that the argument types can be assigned to the parameter types."""
impl TypeEvaluator.validate_arg_types(
    self: TypeEvaluator, args: MatchArgsToParamsResult
) -> None {
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
            self.add_diagnostic(
                arg,
                f"Cannot assign {arg_type} to parameter '{param.name}' of type {param.param_type}",
            );
        }
    }
}

"""
Validate that the arguments can be assigned to the call's parameter list.

Specializes the call based on arg types, and returns the specialized
type of the return value. If it detects an error along the way, it emits
a diagnostic and sets argumentErrors to true.
"""
impl TypeEvaluator.validate_call_args(
    self: TypeEvaluator, expr: uni.FuncCall
) -> TypeBase {
    caller_type = self.get_type_of_expression(expr.target);
    # 1. Call to a function.
    if isinstance(caller_type, types.FunctionType) {
        arg_param_match = self.match_args_to_params(expr, caller_type);
        if not arg_param_match.argument_errors {
            self.validate_arg_types(arg_param_match);
        }
        return caller_type.return_type or types.UnknownType();
    }
    # 2. Call to TypeVar.
    if isinstance(caller_type, types.ClassType)
    and caller_type.shared == (self.prefetch and self.prefetch.type_var_class.shared) {
        # TODO: validate the args and pass the typevar name.
        return types.TypeVarType();
    }
    # 3. Call to an instantiable class.
    if (
        isinstance(caller_type, types.ClassType)
        and caller_type.is_instantiable_class()
    ) {
        # TODO: validate args for __init__()

        # If it has __init__ method, try to call it.
        if init_method := self._lookup_class_member(caller_type, "__init__") {
            init_fn_type = self.get_type_of_symbol(init_method.symbol);
            if isinstance(init_fn_type, types.FunctionType) {
                arg_param_match = self.match_args_to_params(expr, init_fn_type);
                if not arg_param_match.argument_errors {
                    self.validate_arg_types(arg_param_match);
                }
            }
        } elif caller_type.is_data_class() {
            init_fn_type = self._create_dataclass_init_method(caller_type);
            arg_param_match = self.match_args_to_params(expr, init_fn_type);
            if not arg_param_match.argument_errors {
                self.validate_arg_types(arg_param_match);
            }
        }
        return caller_type.clone_as_instance();
    }
    # 4. Call to a callable object (__call__).
    if caller_type.is_class_instance() {
        # TODO: validate args.
        magic_call_ret = self.get_type_of_magic_method_call(caller_type, "__call__");
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
    self: TypeEvaluator, expr: uni.FuncCall, func_type: types.FunctionType
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
    for arg in expr.params {
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
            self.add_diagnostic(arg, str(e));
            argument_errors = True;
        }
    }
    if unmatched_params := param_tracker.get_unmatched_required_params() {
        names = ", ".join([f"'{p.name}'" for p in unmatched_params]);
        argument_errors = True;
        self.add_diagnostic(
            expr,
            f"Not all required parameters were provided in the function call: {names}",
        );
    }
    return MatchArgsToParamsResult(
        arg_params=arg_params, argument_errors=argument_errors
    );
}
