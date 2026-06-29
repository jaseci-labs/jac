impl TypeEvaluator.validate_arg_types(
    args: MatchArgsToParamsResult, checking_overload: bool = False
) -> bool {
    has_errors: bool = False;

    bindings: dict[str, TypeBase] = {};
    for (arg, param) in args.arg_params.items() {
        if param is None or param.param_type is None {
            continue;
        }
        value = arg.value if isinstance(arg, uni.KWPair) else arg;
        if isinstance(value, uni.LambdaExpr) {
            continue;
        }
        self.assign_type_to_type_var(
            param.param_type, self.get_type_of_expression(value), bindings
        );
    }

    for (arg, param) in args.arg_params.items() {
        if param is None or param.param_type is None {
            continue;
        }
        expected = param.param_type;
        if bindings {
            expected = type_utils.apply_solved_type_vars(expected, bindings);
        }
        value = arg.value if isinstance(arg, uni.KWPair) else arg;
        arg_type = self.get_type_of_expression(value, expected_type=expected);

        if not self.assign_type(arg_type, expected, strict=self._is_strict_site(arg)) {
            has_errors = True;
            if not checking_overload {
                self.emit_diag(
                    E1053,
                    arg,
                    actual=str(arg_type),
                    name=param.name,
                    expected=str(expected)
                );
            }
        }
    }
    return not has_errors;
}

impl TypeEvaluator.validate_call_args(expr: uni.FuncCall) -> TypeBase {
    caller_type = self.get_type_of_expression(expr.target);

    if self._is_expr_super(expr.target) {
        return caller_type;
    }

    if isinstance(expr.target, uni.SpecialVarRef)
    and expr.target.name == Tok.KW_ROOT
    and (not expr.params or len(expr.params) == 0) {
        self.emit_diag(W0062, expr);
        return caller_type;
    }

    if isinstance(caller_type, types.ClassType)
    and caller_type.is_builtin("auto")
    and (not expr.params or len(expr.params) == 0) {
        return self.prefetch.int_class if self.prefetch else types.UnknownType();
    }

    if self._in_native_context() {
        na_iter_ret = self._native_iter_next_result(expr);
        if na_iter_ret is not None {
            return na_iter_ret;
        }
    }

    if isinstance(caller_type, types.TypeVarType) {
        if caller_type.constraints {
            for constraint_type in caller_type.constraints {
                if isinstance(constraint_type, types.ClassType) {
                    call_member = self._lookup_class_member(
                        constraint_type, "__call__"
                    );
                    if call_member {
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
            bound_type = caller_type.bound;
            if isinstance(bound_type, types.ClassType) {
                call_member = self._lookup_class_member(bound_type, "__call__");
                if call_member {
                    call_type = self.get_type_of_symbol(call_member.symbol);
                    if isinstance(call_type, types.FunctionType) {
                        arg_param_match = self.match_args_to_params(
                            expr.params, expr, call_type
                        );
                        if not arg_param_match.argument_errors {
                            self.validate_arg_types(arg_param_match);
                        }
                        return call_type.return_type or types.UnknownType();
                    }

                    call_ret = self.get_type_of_magic_method_call(
                        bound_type, "__call__", expr.params, expr
                    );
                    if call_ret {
                        return call_ret;
                    }
                    return types.UnknownType();
                }

                self.emit_diag(E1023, expr, type=str(bound_type));
                return types.UnknownType();
            }
        }

        self.emit_diag(E1023, expr, type=caller_type.name);
        return types.UnknownType();
    }

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
            if not isinstance(cast_target_type, types.UnknownType) {
                return self._convert_to_instance(cast_target_type);
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

        bindings = self._collect_type_var_bindings(
            caller_type, expr, is_unbound_call=is_unbound_call
        );
        ret: TypeBase = caller_type.return_type or types.UnknownType();
        if bindings {
            specialized = caller_type.specialize_func_type_vars(bindings);
            ret = specialized.return_type or types.UnknownType();
        }

        if caller_type.is_async or self._is_sv_async_call(expr) {
            ret = self._make_coroutine_type(ret);
        }
        return ret;
    }
    if isinstance(caller_type, types.OverloadedType) {
        _fallback_result: types.TypeBase | None = None;

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

                    if ret_type and _contains_unknown(ret_type) {
                        bindings = self._collect_type_var_bindings(
                            overload, expr, is_unbound_call=is_unbound_call
                        );
                        if bindings {
                            ret_type = self._substitute_type_vars(ret_type, bindings);
                        }
                    }

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
        lambda_param = self._unannotated_lambda_arg_name(expr);
        if lambda_param is not None {
            self.emit_diag(
                E1054,
                expr,
                help_text=(
                    "Unannotated lambda parameter '" + lambda_param + "' could not be inferred from the call context, so it stays Unknown and no overload matches. Annotate it, e.g. `lambda " + lambda_param + ": <type> : ...`, or pass a typed `def` as the callback."
                )
            );
        } else {
            self.emit_diag(E1054, expr);
        }
        return types.UnknownType();
    }
    if self.is_typevar_class(caller_type) {
        type_var_name = "";
        first_constraint_arg: uni.Expr | None = None;
        constraint_count = 0;

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
                self.emit_diag(E1063, first_arg);
            }

            for i in range(1, len(expr.params)) {
                arg = expr.params[i];
                if isinstance(arg, uni.KWPair) {
                    if isinstance(arg.key, uni.Name) {
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
                    continue;
                }

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

            if constraint_count == 1 and first_constraint_arg {
                self.emit_diag(E1064, first_constraint_arg);
            }
        } else {
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

        if matched_method is None {
            init_method = self._lookup_class_member(caller_type, "init");
            is_from_object = init_method
            and init_method.class_type.shared.class_name == "object";

            if init_method and not is_from_object {
                method_ty = self._get_method_with_overloads(init_method, caller_type);
                matched_method = self._validate_constructor_method(expr, method_ty);
                if matched_method is None and expr.params {
                    init_sym_type = self.get_type_of_symbol(init_method.symbol);
                    if isinstance(init_sym_type, types.FunctionType) {
                        self.match_args_to_params(expr.params, expr, init_sym_type);
                    }
                }
            } elif caller_type.is_data_class() {
                self._validate_constructor_method(
                    expr, self._create_dataclass_init_method(caller_type)
                );
            }
        }

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
        if (
            isinstance(caller_type, types.ClassType)
            and self.prefetch.any_class
            and caller_type.shared == self.prefetch.any_class.shared
        ) {
            return caller_type;
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
        if (
            len(func_type.parameters) == 0
            or not (func_type.parameters[0].is_self or func_type.parameters[0].is_cls)
        ) {
            synthetic_self = types.Parameter(
                name="self",
                category=types.ParameterCategory.Positional,
                param_type=None,
                is_self=True,
                param_kind=types.ParamKind.NORMAL,
            );
            params_to_match.insert(0, synthetic_self);
        }
    } else {
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

impl TypeEvaluator._unannotated_lambda_arg_name(expr: uni.FuncCall) -> str | None {
    if expr.params is None {
        return None;
    }
    for arg in expr.params {
        lam = arg.value if isinstance(arg, uni.KWPair) else arg;
        if not isinstance(lam, uni.LambdaExpr) or lam.signature is None {
            continue;
        }
        for param in lam.signature.get_parameters() {
            if param.type_tag is None {
                return param.name.value;
            }
        }
    }
    return None;
}

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

impl TypeEvaluator._get_method_with_overloads(
    method_member: any, caller_type: types.ClassType
) -> TypeBase {
    method_ty = self.get_type_of_symbol(method_member.symbol);

    if isinstance(method_ty, types.FunctionType) {
        method_ty = method_ty.specialize(caller_type);
    }
    overloaded_fns: list[types.FunctionType] = [method_ty];
    for overload in method_member.overloads {
        overload_member_ty = self.get_type_of_symbol(overload);
        if isinstance(overload_member_ty, types.FunctionType) {
            overload_member_ty = overload_member_ty.specialize(caller_type);
            overloaded_fns.append(overload_member_ty);
        }
    }

    if len(overloaded_fns) > 1 {
        return types.OverloadedType(overloads=overloaded_fns);
    }
    return method_ty;
}

impl TypeEvaluator.assign_type_to_type_var(
    param_type: TypeBase, arg_type: TypeBase, bindings: dict[str, TypeBase]
) -> bool {
    if isinstance(param_type, types.TypeVarType) {
        if not param_type.name {
            return True;
        }
        resolved_arg = self._convert_to_instance(arg_type);

        if param_type.bound {
            if not self.assign_type(resolved_arg, param_type.bound) {
                return False;
            }
        }

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

        if param_type.name in bindings {
            existing = bindings[param_type.name];

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

    if isinstance(param_type, types.UnionType) {
        for member in param_type.types {
            if isinstance(member, types.TypeVarType) {
                self.assign_type_to_type_var(member, arg_type, bindings);
            }
        }
        return True;
    }

    if isinstance(param_type, types.FunctionType)
    and isinstance(arg_type, types.FunctionType) {
        param_params = param_type.parameters or [];
        arg_params = arg_type.parameters or [];
        for (i, pp) in enumerate(param_params) {
            if i < len(arg_params)
            and pp.param_type is not None
            and arg_params[i].param_type is not None {
                self.assign_type_to_type_var(
                    arg_params[i].param_type, pp.param_type, bindings
                );
            }
        }
        if param_type.return_type is not None and arg_type.return_type is not None {
            self.assign_type_to_type_var(
                param_type.return_type, arg_type.return_type, bindings
            );
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


impl TypeEvaluator._infer_type_args_from_method(
    caller_type: types.ClassType,
    expr: uni.FuncCall,
    matched_method: types.FunctionType | None
) -> list[TypeBase] {
    if not caller_type.shared.type_params {
        return [];
    }
    if caller_type.private.type_args {
        return caller_type.private.type_args;
    }

    init_method = self._find_matching_raw_constructor(
        caller_type, expr, matched_method
    );
    if not init_method {
        return [];
    }

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

impl TypeEvaluator._find_matching_raw_constructor(
    caller_type: types.ClassType,
    expr: uni.FuncCall,
    matched_method: types.FunctionType | None
) -> types.FunctionType | None {
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

    if caller_type.is_data_class() and keyword_arg_names {
        dc_init = self._create_dataclass_init_method(caller_type);
        if dc_init {
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

    if caller_type.is_data_class() {
        return self._create_dataclass_init_method(caller_type);
    }

    return None;
}

impl TypeEvaluator._find_overload_by_arg_count(
    method_type: types.TypeBase, arg_count: int, overload_symbols: list
) -> types.FunctionType | None {
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

    for ovl in overloads {
        positional_params = sum(
            1
            for p in ovl.parameters
            if not p.is_self and not p.is_cls and p.param_kind != types.ParamKind.KWONLY
        );
        if positional_params == arg_count {
            return ovl;
        }
    }

    for ovl in overloads {
        if any(not p.is_self and not p.is_cls for p in ovl.parameters) {
            return ovl;
        }
    }

    return None;
}

impl TypeEvaluator._collect_type_var_bindings(
    method: types.FunctionType,
    expr: uni.FuncCall,
    is_unbound_call: bool = False,
    is_constructor_call: bool = False
) -> dict[str, TypeBase] {
    bindings: dict[str, TypeBase] = {};

    params = method.parameters.copy();
    if is_unbound_call {
        if (len(params) == 0 or not (params[0].is_self or params[0].is_cls)) {
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

    def _effective_param_type(p: types.Parameter) -> TypeBase | None {
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
        } elif param_idx < len(params) {
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
