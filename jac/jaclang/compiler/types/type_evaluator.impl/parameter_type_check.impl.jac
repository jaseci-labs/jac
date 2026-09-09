impl TypeEvaluator.validate_arg_types(
    args: MatchArgsToParamsResult,
    checking_overload: bool = False,
    solved_type_vars: (dict[str, TypeBase] | None) = None
) -> bool {
    has_errors: bool = False;
    binding_failures: set[Expr | KWPair] = set();

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
        if not self.assign_type_to_type_var(
            param.param_type, self.get_type_of_expression(value), bindings
        ) {
            binding_failures.add(arg);
            has_errors = True;
        }
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
        if arg in binding_failures {
            if not checking_overload {
                self.emit_diag(
                    E1053,
                    arg,
                    actual=str(arg_type),
                    name=param.name,
                    expected=str(expected)
                );
            }
            continue;
        }
        if isinstance(arg_type, UnknownType) and arg_type.is_incomplete {
            continue;
        }
        if param.is_comptime and not checking_overload {
            if self.ct_site_error(
                value,
                f"argument for comptime parameter '{param.name}'",
                self.ct_demand(value)
            ) {
                has_errors = True;
            }
        }

        verdict = self.assign_expr(
            value,
            arg_type,
            expected,
            strict=self._is_strict_site(arg),
            probe=checking_overload
        );
        if not verdict.ok {
            has_errors = True;
            if not checking_overload and not verdict.diagnosed {
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

impl TypeEvaluator.validate_call_args(expr: FuncCall) -> TypeBase {
    return self._validate_call_type(expr, self.get_type_of_expression(expr.target));
}

impl TypeEvaluator._validate_call_type(
    expr: FuncCall, caller_type: TypeBase
) -> TypeBase {
    if isinstance(caller_type, UnionType) {
        return self._union_narrowed_types(
            [self._validate_call_type(expr, member) for member in caller_type.types]
        );
    }
    if isinstance(caller_type, ClassType) and self._is_type_subscript(caller_type) {
        constructor = self._get_type_for_member_lookup(caller_type);
        if constructor is not caller_type {
            return self._validate_call_type(expr, constructor);
        }
        inner_type = caller_type.private.type_args[0];
        if isinstance(inner_type, TypeVarType) {
            candidates = inner_type.constraints
                or ([inner_type.bound] if inner_type.bound is not None else []);
            for candidate in candidates {
                if isinstance(candidate, ClassType) {
                    self._validate_call_type(expr, candidate.clone_as_class());
                }
            }
            return inner_type;
        }
    }

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

    fw_type = fixed_width_call_type(self, expr, caller_type);
    if fw_type is not None {
        return fw_type;
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
            callable_bound = caller_type.bound;
            if isinstance(callable_bound, ClassType) {
                call_member = self._lookup_class_member(callable_bound, "__call__");
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
                        callable_bound, "__call__", expr.params, expr
                    );
                    if call_ret {
                        return call_ret;
                    }
                    return UnknownType();
                }

                self.emit_diag(E1023, expr, type=str(callable_bound));
                return UnknownType();
            }
        }

        if caller_type.is_self {
            _self_arch: Archetype | Enum | None = expr.find_parent_of_type(Archetype);
            if _self_arch is None {
                _self_impl = expr.find_parent_of_type(ImplDef);
                if _self_impl is not None
                    and isinstance(_self_impl.decl_link, Ability) {
                    _self_arch = _self_impl.decl_link.method_owner;
                }
            }
            if isinstance(_self_arch, Archetype) {
                _self_cls = self.get_type_of_class(_self_arch);
                if isinstance(_self_cls, ClassType) {
                    return _self_cls.clone_as_instance();
                }
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

        if self._is_sv_async_call(expr)
            or (
                caller_type.is_async
                and not (caller_type.function_flags & FunctionTypeFlags.Generator)
            ) {
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

        for overload in caller_type.overloads {
            if not is_unbound_call
                and not self._overload_accepts_receiver(
                    overload, self._call_receiver_type(expr)
                ) {
                continue;
            }
            arg_param_match = self.match_args_to_params(
                expr.params,
                expr,
                overload,
                checking_overload=True,
                is_unbound_call=is_unbound_call
            );

            if not arg_param_match.argument_errors {
                if self.validate_arg_types(arg_param_match, checking_overload=True) {
                    self.validate_arg_types(arg_param_match);
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
                    "Unannotated lambda parameter '"
                    + lambda_param
                    + "' could not be inferred from the call context, so it stays Unknown and no overload matches. Annotate it, e.g. `lambda "
                    + lambda_param
                    + ": <type> : ...`, or pass a typed `def` as the callback."
                )
            );
        } else {
            self.emit_diag(E1054, expr);
        }
        return UnknownType();
    }
    if self.is_typevar_class(caller_type) {
        type_var_name = "";
        first_constraint_arg: Expr | None = None;
        constraint_count = 0;

        is_covariant = False;
        is_contravariant = False;
        bound_type: TypeBase | None = None;
        constraint_types: list[TypeBase] = [];

        if expr.params and len(expr.params) > 0 {
            first_arg = expr.params[0];
            type_var_name = literal_string_value(first_arg) or "";
            if not type_var_name {
                self.emit_diag(E1063, first_arg);
            }

            for i in range(1, len(expr.params)) {
                arg = expr.params[i];
                if isinstance(arg, KWPair) {
                    if isinstance(arg.key, Name) {
                        if arg.key.value == "covariant"
                            and isinstance(arg.value, Bool) {
                            is_covariant = arg.value.lit_value;
                        } elif arg.key.value == "contravariant"
                            and isinstance(arg.value, Bool) {
                            is_contravariant = arg.value.lit_value;
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

        if expr.params and len(expr.params) > 0 {
            param_spec_name = literal_string_value(expr.params[0]) or "";
            if not param_spec_name {
                self.emit_diag(E1063, expr.params[0]);
            }
            for i in range(1, len(expr.params)) {
                arg = expr.params[i];
                if isinstance(arg, KWPair) and isinstance(arg.key, Name) {
                    if arg.key.value == "covariant" and isinstance(arg.value, Bool) {
                        is_covariant = arg.value.lit_value;
                    } elif arg.key.value == "contravariant"
                        and isinstance(arg.value, Bool) {
                        is_contravariant = arg.value.lit_value;
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
            tvt_name = literal_string_value(expr.params[0]) or "";
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
        sv_async_ctor = self._is_sv_async_call(expr);

        ctor_arch = caller_type.shared.symbol_table;
        if isinstance(ctor_arch, Archetype)
            and ctor_arch.find_parent_of_type(Import) is not None {
            self._check_extern_ctor_args(expr, ctor_arch);
            return caller_type.clone_as_instance();
        }

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
            is_from_object = init_method is not None
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
                    expr, self._create_object_init_method(caller_type)
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
                specialized_class = caller_type.specialize_generics(inferred_type_args);
                inst = specialized_class.clone_as_instance();
                return self._make_coroutine_type(inst) if sv_async_ctor else inst;
            }
        }
        inst = caller_type.clone_as_instance();
        return self._make_coroutine_type(inst) if sv_async_ctor else inst;
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
    node_for_error: UniNode | None,
    func_type: FunctionType,
    checking_overload: bool = False,
    is_unbound_call: bool = False
) -> MatchArgsToParamsResult {
    arg_params: dict[Expr | KWPair, Parameter | None] = {};
    argument_errors = False;
    if func_type.is_gradual_callable_form() {
        for arg_node in (arg_nodes or []) {
            arg_params[arg_node] = None;
        }
        return MatchArgsToParamsResult(arg_params=arg_params, argument_errors=False);
    }
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
                        name=arg.key.sym_name
                            if isinstance(arg, KWPair) and arg.key is not None
                            else ""
                    );
                } elif "Positional only parameter" in err_msg {
                    pname = err_msg.split("'")[1] if "'" in err_msg else "";
                    self.emit_diag(E1056, arg, name=pname);
                } elif "already matched" in err_msg {
                    pname = err_msg.split("'")[1] if "'" in err_msg else "";
                    self.emit_diag(E1057, arg, name=pname);
                } else {
                    self.emit_diag(E1051, arg);
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
        if has_params
            or method_type.function_flags & FunctionTypeFlags.SynthesizedMethod {
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
                    self.validate_arg_types(arg_param_match);
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
        bound_method = method.clone();
        bound_method.parameters = bound_method.parameters[1:];
        return bound_method;
    }
    return method;
}

impl TypeEvaluator._get_method_with_overloads(
    method_member: ClassMember, caller_type: ClassType
) -> TypeBase {
    method_ty = self.get_type_of_member(method_member, caller_type);

    if not isinstance(method_ty, FunctionType) {
        return method_ty;
    }
    overloaded_fns: list[FunctionType] = [method_ty];
    for overload in method_member.overloads {
        overload_member_ty = self.specialize_member_type(
            self.get_type_of_symbol(overload),
            caller_type,
            self.declaring_class_of(overload, caller_type)
        );
        if isinstance(overload_member_ty, FunctionType) {
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
                _w_arg = self._widen_literal_for_declaration(resolved_arg);
                _w_prev = self._widen_literal_for_declaration(existing);
                if self.assign_type(_w_arg, _w_prev) {
                    bindings[param_type.name] = _w_prev;
                } elif self.assign_type(_w_prev, _w_arg) {
                    bindings[param_type.name] = _w_arg;
                } else {
                    return False;
                }
            }
        } else {
            bindings[param_type.name] = resolved_arg;
        }
        return True;
    }

    if isinstance(arg_type, (UnknownType, AnyType)) or arg_type.is_any_instance() {
        self.bind_type_vars_to_opaque(param_type, bindings, arg_type);
        return True;
    }

    if isinstance(arg_type, UnionType) {
        solutions: dict[str, dict[str, TypeBase]] = {};
        for argument in arg_type.types {
            candidate = dict(bindings);
            if not self.assign_type_to_type_var(param_type, argument, candidate) {
                return False;
            }
            for (name, value) in candidate.items() {
                value_alternatives = value.types
                    if isinstance(value, UnionType)
                    else [value];
                for alternative in value_alternatives {
                    solutions.setdefault(name, {})[alternative.mangle()] = alternative;
                }
            }
        }
        for (name, merged_alternatives) in solutions.items() {
            values = list(merged_alternatives.values());
            opaque = next(
                (
                    value
                    for value in values
                    if self.is_explicit_any(value)
                ),
                None
            );
            bindings[name] = opaque
                if opaque is not None
                else (values[0] if len(values) == 1 else UnionType(types=values));
        }
        return True;
    }

    if isinstance(param_type, UnionType) {
        if not any(
            isinstance(member, (TypeVarType, FunctionType, UnionType))
                or (isinstance(member, ClassType) and bool(member.private.type_args))
            for member in param_type.types
        ) {
            return True;
        }
        members = [
            m
            for m in param_type.types
            if not isinstance(m, TypeVarType)
        ]
            + [
                m
                for m in param_type.types
                if isinstance(m, TypeVarType)
            ];
        for member in members {
            candidate = dict(bindings);
            if self.assign_type_to_type_var(member, arg_type, candidate)
                and self.assign_type(
                    arg_type,
                    self._convert_to_instance(apply_solved_type_vars(member, candidate))
                ) {
                bindings.update(candidate);
                return True;
            }
        }
        return False;
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

        _unresolved = (not arg_type_args)
            or any(isinstance(a, TypeVarType) for a in arg_type_args);
        if _unresolved and param_type_args and self._is_protocol_class(param_type) {
            proto_bindings: dict[str, TypeBase] = {};
            if self._solve_protocol_type_args(arg_type, param_type, proto_bindings) {
                type_params = param_type.shared.type_params or [];
                solved_args: list[TypeBase] = [];
                for i in range(len(param_type_args)) {
                    solved = proto_bindings.get(type_params[i].name)
                        if i < len(type_params)
                        else None;
                    if solved is None or isinstance(solved, TypeVarType) {
                        solved_args = [];
                        break;
                    }
                    solved_args.append(solved);
                }
                if solved_args {
                    arg_type_args = solved_args;
                }
            }
        }

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


impl TypeEvaluator.bind_type_vars_to_opaque(
    param_type: TypeBase, bindings: dict[str, TypeBase], fill: TypeBase
) -> None {
    if isinstance(param_type, TypeVarType) {
        if param_type.name and param_type.name not in bindings {
            bindings[param_type.name] = fill;
        }
        return;
    }
    if isinstance(param_type, UnionType) {
        for member in param_type.types {
            self.bind_type_vars_to_opaque(member, bindings, fill);
        }
        return;
    }
    if isinstance(param_type, FunctionType) {
        for parameter in (param_type.parameters or []) {
            if parameter.param_type is not None {
                self.bind_type_vars_to_opaque(parameter.param_type, bindings, fill);
            }
        }
        if param_type.return_type is not None {
            self.bind_type_vars_to_opaque(param_type.return_type, bindings, fill);
        }
        return;
    }
    if isinstance(param_type, ClassType) and param_type.private {
        for type_arg in param_type.private.type_args {
            self.bind_type_vars_to_opaque(type_arg, bindings, fill);
        }
    }
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

impl TypeEvaluator.class_constructor_callables(
    cls_type: ClassType
) -> list[FunctionType] {
    out: list[FunctionType] = [];
    instance = cls_type.clone_as_instance();
    for name in ['init', '__init__', '__new__'] {
        member = self._lookup_class_member(cls_type, name);
        if member is None {
            continue;
        }
        if member.class_type.shared.class_name == "object" {
            continue;
        }
        raw_type = self.get_type_of_symbol(member.symbol);
        candidates: list[TypeBase] = [];
        if isinstance(raw_type, OverloadedType) and raw_type.overloads {
            candidates = list(raw_type.overloads);
        } else {
            candidates = [raw_type];
        }
        for overload_sym in (member.overloads or []) {
            overload_type = self.get_type_of_symbol(overload_sym);
            if overload_type not in candidates {
                candidates.append(overload_type);
            }
        }
        for cand in candidates {
            if not isinstance(cand, FunctionType) {
                continue;
            }
            params = [
                p
                for p in (cand.parameters or [])
                if not p.is_self and not p.is_cls
            ];
            out.append(
                create_callable_type(
                    [
                        p.param_type if p.param_type is not None else UnknownType()
                        for p in params
                    ],
                    instance
                )
            );
        }
        if out {
            return out;
        }
    }
    return out;
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
        dc_init = self._create_object_init_method(caller_type);
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
        return self._create_object_init_method(caller_type);
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

impl TypeEvaluator._call_receiver_type(expr: FuncCall) -> TypeBase | None {
    if not (
        isinstance(expr.target, AtomTrailer)
        and isinstance(expr.target.target, Expr)
        and expr.target.target.type is not None
    ) {
        return None;
    }
    recv = expr.target.target.type;
    if isinstance(recv, UnionType) {
        if recv.types
            and all(
                isinstance(member, ClassType) and member.is_instance()
                for member in recv.types
            ) {
            return recv;
        }
        return None;
    }
    if not (
        isinstance(recv, ClassType)
        and recv._shared is not None
        and recv.shared.class_name != "object"
    ) {
        return None;
    }
    if self._is_type_subscript(recv) {
        inner = recv.private.type_args[0];
        if isinstance(inner, ClassType)
            and not self._member_is_metaclass_only(inner.clone_as_class(), expr) {
            return inner.clone_as_instance();
        }
        return recv;
    }
    if not recv.is_instance() and recv.is_instantiable() {
        if self._member_is_metaclass_only(recv, expr)
            and self.prefetch.type_class is not None {
            meta_self = self.prefetch.type_class.clone_as_instance();
            meta_self.private.type_args = [recv.clone_as_instance()];
            return meta_self;
        }
        return recv.clone_as_instance();
    }
    return recv;
}

impl TypeEvaluator._overload_accepts_receiver(
    overload: FunctionType, receiver: TypeBase | None
) -> bool {
    if not overload.parameters {
        return True;
    }
    first = overload.parameters[0];
    declared = first.param_type;
    if not first.is_self or not isinstance(declared, ClassType) {
        return True;
    }
    if receiver is None or self.is_any_type(receiver) {
        return True;
    }
    if not isinstance(receiver, ClassType) or not receiver.is_instance() {
        return True;
    }
    return self.assign_type(receiver, self._convert_to_instance(declared));
}


impl TypeEvaluator._receiver_type_var_bindings(
    method: FunctionType, receiver: TypeBase | None
) -> dict[str, TypeBase] {
    if receiver is None {
        return {};
    }
    bindings: dict[str, TypeBase] = {"Self": receiver};
    if method.parameters {
        first = method.parameters[0];
        if (first.is_self or first.is_cls) and first.param_type is not None {
            self.assign_type_to_type_var(first.param_type, receiver, bindings);
        }
    }
    return bindings;
}

impl TypeEvaluator._collect_type_var_bindings(
    method: FunctionType,
    expr: FuncCall,
    is_unbound_call: bool = False,
    is_constructor_call: bool = False
) -> dict[str, TypeBase] {
    receiver = self._call_receiver_type(expr);
    bindings = self._receiver_type_var_bindings(method, receiver)
        if not is_unbound_call
        else {};
    if is_unbound_call and receiver is not None {
        bindings["Self"] = receiver;
    }

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


impl TypeEvaluator._member_is_metaclass_only(
    cls_type: ClassType, expr: FuncCall
) -> bool {
    if not isinstance(expr.target, AtomTrailer)
        or not isinstance(expr.target.right, Name) {
        return False;
    }
    member_name = expr.target.right.value;
    if self._lookup_class_member(cls_type, member_name) is not None {
        return False;
    }

    meta_cls = self._metaclass_of(cls_type) or self.prefetch.type_class;
    if meta_cls is None {
        return False;
    }
    meta_inst = self._convert_to_instance(meta_cls);
    return isinstance(meta_inst, ClassType)
        and self._lookup_object_member(meta_inst, member_name) is not None;
}
