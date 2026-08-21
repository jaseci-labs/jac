impl TypeEvaluator.validate_arg_types(
    args: MatchArgsToParamsResult,
    checking_overload: bool = False,
    mismatches: list[ArgTypeMismatch] | None = None,
    solved_type_vars: (dict[str, TypeBase] | None) = None
) -> bool {
    has_errors: bool = False;

    bindings: dict[str, TypeBase] = solved_type_vars
        if solved_type_vars is not None
        else {};
    for (arg, param) in args.arg_params.items() {
        if param is None or param.param_type is None {
            continue;
        }
        value = arg.value if isinstance(arg, KWPair) else arg;
        if isinstance(value, LambdaExpr) {
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
            expected = apply_solved_type_vars(expected, bindings);
        }
        value = arg.value if isinstance(arg, KWPair) else arg;
        arg_type = self.get_type_of_expression(value, expected_type=expected);
        if isinstance(arg_type, UnknownType) and arg_type.is_incomplete {
            continue;
        }

        if not self.assign_type(arg_type, expected, strict=self._is_strict_site(arg)) {
            has_errors = True;
            if mismatches is not None {
                mismatches.append(
                    ArgTypeMismatch(
                        param_name=param.name,
                        actual=str(arg_type),
                        expected=str(expected),
                        callable_reason=self._callable_reason(arg_type, expected)
                    )
                );
            }
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

def _q(value: object) -> str {
    return "'" + str(value) + "'";
}

impl TypeEvaluator._callable_reason(
    arg_type: TypeBase, expected: TypeBase
) -> str | None {
    if not isinstance(arg_type, FunctionType)
        or not isinstance(expected, FunctionType)
        or expected.is_gradual_callable_form() {
        return None;
    }

    def visible(fn: FunctionType) -> list[Parameter] {
        return [
            p
            for p in (fn.parameters or [])
            if not p.is_self and not p.is_cls
        ];
    }

    (src_params, dest_params) = (visible(arg_type), visible(expected));
    want = len(dest_params);

    if any(not p.is_optional for p in src_params[want:]) {
        return f"takes {len(src_params)} parameter(s), but a callable taking {want} is expected";
    }

    src_ret = arg_type.return_type;
    dest_ret = expected.return_type;
    if src_ret is None or dest_ret is None or isinstance(src_ret, UnknownType) {
        return None;
    }
    got_ret = self._convert_to_instance(src_ret);
    want_ret = self._convert_to_instance(dest_ret);
    if self.assign_type(got_ret, want_ret) {
        return None;
    }
    return f"returns {_q(got_ret)}, but must return {_q(want_ret)}";
}

impl TypeEvaluator._describe_overload_rejections(
    rejections: list[tuple[int, ArgTypeMismatch]]
) -> str | None {
    if not rejections {
        return None;
    }

    if len({m.param_name for (_, m) in rejections}) > 1 {
        lines = ["no overload accepts these arguments:"];
        for (no, m) in rejections[:MAX_LISTED_OVERLOADS] {
            lines.append(
                f"  overload {no}: cannot assign {_q(m.actual)} to parameter {_q(
                    m.param_name
                )} of type {_q(m.expected)}"
            );
        }
        return "\n".join(lines);
    }

    for (no, m) in rejections {
        if m.callable_reason {
            return f"the callable passed for parameter {_q(m.param_name)} {m.callable_reason} (overload {no}). Annotate the callable so it matches.";
        }
    }

    first = rejections[0][1];
    head = f"the argument for parameter {_q(first.param_name)} has type {_q(
        first.actual
    )}, which no overload accepts.";
    wanted: list[str] = [];
    for (_, m) in rejections {
        if m.expected not in wanted {
            wanted.append(m.expected);
        }
    }
    if len(wanted) == 1 {
        return f"{head} Every overload expects {_q(wanted[0])}.";
    }
    lines = [f"{head} The candidates expect:"];
    for (no, m) in rejections[:MAX_LISTED_OVERLOADS] {
        lines.append(f"  overload {no}: {_q(m.expected)}");
    }
    return "\n".join(lines);
}

impl TypeEvaluator.validate_call_args(expr: FuncCall) -> TypeBase {
    caller_type = self.get_type_of_expression(expr.target);

    if self._is_expr_super(expr.target) {
        return caller_type;
    }

    if isinstance(expr.target, SpecialVarRef)
        and expr.target.name == Tok.KW_ROOT
        and (not expr.params or len(expr.params) == 0) {
        self.emit_diag(E0049, expr);
        return caller_type;
    }

    if isinstance(caller_type, ClassType)
        and caller_type.is_builtin("auto")
        and (not expr.params or len(expr.params) == 0) {
        return self.prefetch.int_class or UnknownType();
    }

    if self._in_native_context() {
        na_iter_ret = self._native_iter_next_result(expr);
        if na_iter_ret is not None {
            return na_iter_ret;
        }
    }

    if isinstance(caller_type, AnyType) {
        return caller_type;
    }

    if isinstance(caller_type, UnknownType)
        and (caller_type.is_diagnosed or caller_type.is_incomplete) {
        return caller_type;
    }

    if isinstance(caller_type, TypeVarType) {
        if caller_type.constraints {
            for constraint_type in caller_type.constraints {
                if isinstance(constraint_type, ClassType) {
                    call_member = self._lookup_class_member(
                        constraint_type, "__call__"
                    );
                    if call_member {
                        call_type = self.get_type_of_symbol(call_member.symbol);
                        if isinstance(call_type, FunctionType) {
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
            return UnknownType();
        }
        if caller_type.bound {
            bound_type = caller_type.bound;
            if isinstance(bound_type, ClassType) {
                call_member = self._lookup_class_member(bound_type, "__call__");
                if call_member {
                    call_type = self.get_type_of_symbol(call_member.symbol);
                    if isinstance(call_type, FunctionType) {
                        arg_param_match = self.match_args_to_params(
                            expr.params, expr, call_type
                        );
                        if not arg_param_match.argument_errors {
                            self.validate_arg_types(arg_param_match);
                        }
                        return call_type.return_type or UnknownType();
                    }

                    call_ret = self.get_type_of_magic_method_call(
                        bound_type, "__call__", expr.params, expr
                    );
                    if call_ret {
                        return call_ret;
                    }
                    return UnknownType();
                }

                self.emit_diag(E1023, expr, type=str(bound_type));
                return UnknownType();
            }
        }

        self.emit_diag(E1023, expr, type=caller_type.name);
        return UnknownType();
    }

    if isinstance(caller_type, OverloadedType) {
        target_node = expr.target;
        is_cast = False;
        if isinstance(target_node, Name) and target_node.sym {
            dotted = target_node.sym.sym_dotted_name;
            is_cast = dotted.endswith("typing.cast");
        }
        if is_cast and expr.params and len(expr.params) >= 1 {
            first_arg = expr.params[0];
            first_arg_expr = first_arg.value
                if isinstance(first_arg, KWPair)
                else first_arg;
            cast_target_type = self.get_type_of_expression(first_arg_expr);
            if not isinstance(cast_target_type, UnknownType) {
                return self._convert_to_instance(cast_target_type);
            }
        }
    }

    is_unbound_call = self._is_unbound_method_call(expr);
    if isinstance(caller_type, FunctionType) {
        arg_param_match = self.match_args_to_params(
            expr.params, expr, caller_type, is_unbound_call=is_unbound_call
        );
        if not arg_param_match.argument_errors {
            self.validate_arg_types(arg_param_match);
        }

        bindings = self._collect_type_var_bindings(
            caller_type, expr, is_unbound_call=is_unbound_call
        );
        ret: TypeBase = caller_type.return_type or UnknownType();
        if bindings {
            specialized = caller_type.specialize_func_type_vars(bindings);
            ret = specialized.return_type or UnknownType();
        }

        if caller_type.is_async or self._is_sv_async_call(expr) {
            ret = self._make_coroutine_type(ret);
        }
        return ret;
    }
    if isinstance(caller_type, OverloadedType) {
        _fallback_result: TypeBase | None = None;

        def _contains_unknown(ty: TypeBase) -> bool {
            if isinstance(ty, UnknownType) {
                return True;
            }
            if isinstance(ty, TypeVarType) {
                return True;
            }
            if isinstance(ty, UnionType) {
                return any(_contains_unknown(member) for member in ty.types);
            }
            if isinstance(ty, ClassType) and ty.private.type_args {
                return any(_contains_unknown(arg) for arg in ty.private.type_args);
            }
            return False;
        }

        rejections: list[tuple[int, ArgTypeMismatch]] = [];
        overload_no = 0;

        for overload in caller_type.overloads {
            overload_no += 1;
            arg_param_match = self.match_args_to_params(
                expr.params,
                expr,
                overload,
                checking_overload=True,
                is_unbound_call=is_unbound_call
            );

            if not arg_param_match.argument_errors {
                mismatches: list[ArgTypeMismatch] = [];
                if self.validate_arg_types(
                    arg_param_match, checking_overload=True, mismatches=mismatches
                ) {
                    ret_type = overload.return_type;

                    if ret_type and _contains_unknown(ret_type) {
                        bindings = self._collect_type_var_bindings(
                            overload, expr, is_unbound_call=is_unbound_call
                        );
                        if bindings {
                            ret_type = self._substitute_type_vars(ret_type, bindings);
                        }
                    }

                    if not _contains_unknown(ret_type or UnknownType()) {
                        return ret_type or UnknownType();
                    }
                    if _fallback_result is None {
                        _fallback_result = ret_type;
                    }
                } elif mismatches {
                    rejections.append((overload_no, mismatches[0]));
                }
            }
        }
        if _fallback_result is not None {
            return _fallback_result;
        }

        help_text = self._describe_overload_rejections(rejections);
        if help_text is None {
            lambda_param = self._unannotated_lambda_arg_name(expr);
            if lambda_param is not None {
                help_text = (
                    "Unannotated lambda parameter '"
                    + lambda_param
                    + "' could not be inferred from the call context, so it stays Unknown and no overload matches. Annotate it, e.g. `lambda ("
                    + lambda_param
                    + ": <type>) { ... }`, or pass a typed `def` as the callback."
                );
            }
        }
        if help_text is not None {
            self.emit_diag(E1054, expr, help_text=help_text);
        } else {
            self.emit_diag(E1054, expr);
        }
        return UnknownType();
    }
    if self.is_typevar_class(caller_type) {
        type_var_name = "";
        first_constraint_arg: Expr | None = None;
        constraint_count = 0;

        def _get_string_lit_value(arg: Expr) -> str | None {
            if isinstance(arg, String) {
                return arg.lit_value;
            } elif isinstance(arg, MultiString) and arg.strings {
                if isinstance(arg.strings[0], String) {
                    return arg.strings[0].lit_value;
                }
            }
            return None;
        }

        is_covariant = False;
        is_contravariant = False;
        bound_type: TypeBase | None = None;
        constraint_types: list[TypeBase] = [];

        if expr.params and len(expr.params) > 0 {
            first_arg = expr.params[0];
            type_var_name = _get_string_lit_value(first_arg) or "";
            if not type_var_name {
                self.emit_diag(E1063, first_arg);
            }

            for i in range(1, len(expr.params)) {
                arg = expr.params[i];
                if isinstance(arg, KWPair) {
                    if isinstance(arg.key, Name) {
                        if arg.key.value == "covariant"
                            and isinstance(arg.value, Bool) {
                            is_covariant = arg.value.value;
                        } elif arg.key.value == "contravariant"
                            and isinstance(arg.value, Bool) {
                            is_contravariant = arg.value.value;
                        } elif arg.key.value == "bound" {
                            bound_type = self.get_type_of_expression(arg.value);
                            if isinstance(bound_type, ClassType)
                                and bound_type.is_instantiable() {
                                bound_type = bound_type.clone_as_instance();
                            }
                        }
                    }
                    continue;
                }

                constraint_type = self.get_type_of_expression(arg);
                if isinstance(constraint_type, ClassType)
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
        return TypeVarType(
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
        bound_type: TypeBase | None = None;

        def _get_str_lit(arg: Expr) -> str | None {
            if isinstance(arg, String) {
                return arg.lit_value;
            } elif isinstance(arg, MultiString) and arg.strings {
                if isinstance(arg.strings[0], String) {
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
                if isinstance(arg, KWPair) and isinstance(arg.key, Name) {
                    if arg.key.value == "covariant" and isinstance(arg.value, Bool) {
                        is_covariant = arg.value.value;
                    } elif arg.key.value == "contravariant"
                        and isinstance(arg.value, Bool) {
                        is_contravariant = arg.value.value;
                    } elif arg.key.value == "bound" {
                        bound_type = self.get_type_of_expression(arg.value);
                        if isinstance(bound_type, ClassType)
                            and bound_type.is_instantiable() {
                            bound_type = bound_type.clone_as_instance();
                        }
                    }
                }
            }
        } else {
            self.emit_diag(E1063, expr);
        }
        return TypeVarType(
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
            if isinstance(expr.params[0], String) {
                tvt_name = expr.params[0].lit_value;
            } elif (
                isinstance(expr.params[0], MultiString)
                and expr.params[0].strings
                and isinstance(expr.params[0].strings[0], String)
            ) {
                tvt_name = expr.params[0].strings[0].lit_value;
            }
            if not tvt_name {
                self.emit_diag(E1063, expr.params[0]);
            }
        } else {
            self.emit_diag(E1063, expr);
        }
        return TypeVarType(name=tvt_name, is_param_spec=False);
    }
    if (isinstance(caller_type, ClassType) and caller_type.is_instantiable_class()) {
        matched_method: FunctionType | None = None;

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
                    if isinstance(init_sym_type, FunctionType) {
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
                not isinstance(ta, UnknownType) for ta in inferred_type_args
            );
            if has_inferred {
                specialized = caller_type.specialize_generics(inferred_type_args);
                return specialized.clone_as_instance();
            }
        }
        return caller_type.clone_as_instance();
    }
    if caller_type.is_class_instance() {
        if caller_type.is_any_instance() {
            return caller_type;
        }
        magic_call_ret = self.get_type_of_magic_method_call(
            caller_type, "__call__", expr.params, expr
        );
        if magic_call_ret {
            return magic_call_ret;
        }
    }
    return UnknownType();
}

impl TypeEvaluator.match_args_to_params(
    arg_nodes: (Sequence[Expr | KWPair] | None),
    node_for_error: Expr | None,
    func_type: FunctionType,
    checking_overload: bool = False,
    is_unbound_call: bool = False
) -> MatchArgsToParamsResult {
    arg_params: dict[Expr | KWPair, Parameter | None] = {};
    argument_errors = False;
    params_to_match = func_type.parameters.copy();
    if is_unbound_call {
        if (
            len(func_type.parameters) == 0
            or not (func_type.parameters[0].is_self or func_type.parameters[0].is_cls)
        ) {
            synthetic_self = Parameter(
                name="self",
                category=ParameterCategory.Positional,
                param_type=None,
                is_self=True,
                param_kind=ParamKind.NORMAL,
            );
            params_to_match.insert(0, synthetic_self);
        }
    } else {
        if len(func_type.parameters) >= 1 {
            first = func_type.parameters[0];
            if first.is_self
                or (
                    first.is_cls
                    and func_type.function_flags & FunctionTypeFlags.ClassMethod
                ) {
                params_to_match.pop(0);
            }
        }
    }
    param_tracker = ParamAssignmentTracker(params_to_match);
    for arg in (arg_nodes or []) {
        try {
            if isinstance(arg, KWPair) {
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
                        name=arg.key.sym_name if isinstance(arg, KWPair) else ""
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

impl TypeEvaluator._unannotated_lambda_arg_name(expr: FuncCall) -> str | None {
    if expr.params is None {
        return None;
    }
    for arg in expr.params {
        lam = arg.value if isinstance(arg, KWPair) else arg;
        if not isinstance(lam, LambdaExpr) or lam.signature is None {
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
    expr: FuncCall, method_type: TypeBase
) -> FunctionType | None {
    if isinstance(method_type, FunctionType) {
        has_params = len(method_type.parameters) > 0;
        if has_params
            and (
                method_type.parameters[0].is_self or method_type.parameters[0].is_cls
            ) {
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
    if isinstance(method_type, OverloadedType) {
        matched_overload: FunctionType | None = None;
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

impl TypeEvaluator._strip_implicit_self_cls(method: FunctionType) -> FunctionType {
    if (
        method.parameters
        and (method.parameters[0].is_self or method.parameters[0].is_cls)
    ) {
        return FunctionType(
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
    method_member: ClassMember, caller_type: ClassType
) -> TypeBase {
    method_ty = self.get_type_of_symbol(method_member.symbol);

    if isinstance(method_ty, FunctionType) {
        method_ty = method_ty.specialize(caller_type);
    }
    overloaded_fns: list[FunctionType] = [method_ty];
    for overload in method_member.overloads {
        overload_member_ty = self.get_type_of_symbol(overload);
        if isinstance(overload_member_ty, FunctionType) {
            overload_member_ty = overload_member_ty.specialize(caller_type);
            overloaded_fns.append(overload_member_ty);
        }
    }

    if len(overloaded_fns) > 1 {
        return OverloadedType(overloads=overloaded_fns);
    }
    return method_ty;
}

impl TypeEvaluator.assign_type_to_type_var(
    param_type: TypeBase, arg_type: TypeBase, bindings: dict[str, TypeBase]
) -> bool {
    if isinstance(param_type, TypeVarType) {
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

    if isinstance(param_type, UnionType) {
        for member in param_type.types {
            if isinstance(member, TypeVarType) {
                self.assign_type_to_type_var(member, arg_type, bindings);
            }
        }
        return True;
    }

    if isinstance(param_type, FunctionType) and isinstance(arg_type, FunctionType) {
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
        isinstance(param_type, ClassType)
        and isinstance(arg_type, ClassType)
        and self._is_type_subscript(param_type)
        and (arg_type.flags & TypeFlags.Instantiable)
    ) {
        for pta in param_type.private.type_args {
            self.assign_type_to_type_var(pta, arg_type.clone_as_instance(), bindings);
        }
        return True;
    }

    if isinstance(param_type, ClassType) and isinstance(arg_type, ClassType) {
        param_type_args = param_type.private.type_args if param_type.private else [];
        specialized = specialize_for_base_class(arg_type, param_type);
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
    caller_type: ClassType, expr: FuncCall, matched_method: FunctionType | None
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
        bindings.get(tp.name, UnknownType())
        for tp in caller_type.shared.type_params
        if tp.name
    ];
    if any(not isinstance(ta, UnknownType) for ta in direct_args) {
        return direct_args;
    }

    ret_type = init_method.return_type;
    if isinstance(ret_type, ClassType) and ret_type.private.type_args {
        substituted_args: list[TypeBase] = [];
        for arg in ret_type.private.type_args {
            substituted = self._substitute_type_vars(arg, bindings);
            substituted_args.append(substituted);
        }
        if any(not isinstance(ta, UnknownType) for ta in substituted_args) {
            return substituted_args;
        }
    }

    return direct_args;
}

impl TypeEvaluator._substitute_type_vars(
    typ: TypeBase, bindings: dict[str, TypeBase]
) -> TypeBase {
    if isinstance(typ, TypeVarType) {
        return bindings.get(typ.name, typ);
    }
    if isinstance(typ, UnionType) {
        new_members = [
            self._substitute_type_vars(member, bindings) for member in typ.types
        ];
        return UnionType(types=new_members);
    }
    if isinstance(typ, ClassType) and typ.private.type_args {
        new_args = [
            self._substitute_type_vars(arg, bindings) for arg in typ.private.type_args
        ];
        return typ.specialize_generics(new_args);
    }
    return typ;
}

impl TypeEvaluator._find_matching_raw_constructor(
    caller_type: ClassType, expr: FuncCall, matched_method: FunctionType | None
) -> FunctionType | None {
    positional_arg_count = sum(
        1
        for arg in expr.params
        if not isinstance(arg, KWPair)
    );
    keyword_arg_names = set(
        arg.key.value
        for arg in expr.params
        if isinstance(arg, KWPair) and isinstance(arg.key, Name)
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
    method_type: TypeBase, arg_count: int, overload_symbols: list[Symbol]
) -> FunctionType | None {
    overloads: list[FunctionType] = [];
    if isinstance(method_type, FunctionType) {
        overloads.append(method_type);
    }
    for sym in overload_symbols {
        ovl_type = self.get_type_of_symbol(sym);
        if isinstance(ovl_type, FunctionType) {
            overloads.append(ovl_type);
        }
    }

    for ovl in overloads {
        positional_params = sum(
            1
            for p in ovl.parameters
            if not p.is_self and not p.is_cls and p.param_kind != ParamKind.KWONLY
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
    method: FunctionType,
    expr: FuncCall,
    is_unbound_call: bool = False,
    is_constructor_call: bool = False
) -> dict[str, TypeBase] {
    bindings: dict[str, TypeBase] = {};

    params = method.parameters.copy();
    if is_unbound_call {
        if (len(params) == 0 or not (params[0].is_self or params[0].is_cls)) {
            params.insert(
                0,
                Parameter(
                    name="self",
                    category=ParameterCategory.Positional,
                    param_type=None,
                    is_self=True,
                    param_kind=ParamKind.NORMAL,
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
                    or method.function_flags & FunctionTypeFlags.ClassMethod
                )
            ) {
            params.pop(0);
        }
    }

    def _effective_param_type(p: Parameter) -> TypeBase | None {
        is_unannotated = p.param_type is None or p.param_type.is_any_instance();
        if not is_unannotated {
            return p.param_type;
        }
        if p.is_self {
            return synthesize_self_type_var();
        }
        if (
            p.is_cls
            and self.prefetch is not None
            and self.prefetch.type_class is not None
        ) {
            synth = self.prefetch.type_class.clone_as_instance();
            synth.private.type_args = [synthesize_self_type_var()];
            return synth;
        }
        return p.param_type;
    }

    param_idx = 0;
    for arg in expr.params {
        if isinstance(arg, KWPair) {
            if isinstance(arg.key, Name) {
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
