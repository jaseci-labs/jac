impl primitive_type_name_of(ty: (types.TypeBase | None)) -> (str | None) {
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    if not isinstance(ty, types.ClassType) {
        return None;
    }
    if JAC_TYPE_REGISTRY.is_primitive(ty.shared.class_name) {
        return ty.shared.class_name;
    }

    for base in ty.shared.mro {
        if JAC_TYPE_REGISTRY.is_primitive(base.shared.class_name) {
            return base.shared.class_name;
        }
    }
    return None;
}

impl expr_primitive_name(prog: object, expr_node: uni.UniNode) -> str {
    _ty = expr_node?.type;
    if _ty is None {
        try {
            _te = prog.get_type_evaluator();
            if _te {
                _ty = _te.get_type_of_expression(expr_node);
            }
        } except Exception {
            _ty = None;
        }
    }
    return primitive_type_name_of(_ty) or "";
}

impl get_generator_type_args(
    return_type: types.TypeBase
) -> (list[types.TypeBase] | None) {
    if not isinstance(return_type, types.ClassType) {
        return None;
    }
    if return_type.is_builtin(["Generator", "AsyncGenerator"]) {
        return return_type.private.type_args;
    }
    if return_type.is_builtin("AwaitableGenerator") {
        if return_type.private.type_args {
            return return_type.private.type_args[0:3];
        }
        return None;
    }
    return None;
}

impl get_generator_yield_type(
    declared_return_type: types.TypeBase, is_async: bool
) -> (types.TypeBase | None) {
    if not isinstance(declared_return_type, types.ClassType) {
        return None;
    }
    sync_names = ["Iterable", "Iterator", "Generator", "AwaitableGenerator"];
    async_names = ["AsyncIterable", "AsyncIterator", "AsyncGenerator"];
    candidates = async_names if is_async else sync_names;
    if not declared_return_type.is_builtin(candidates) {
        return None;
    }
    if (
        declared_return_type.private.type_args
        and len(declared_return_type.private.type_args) >= 1
    ) {
        return declared_return_type.private.type_args[0];
    }
    return None;
}

impl get_declared_generator_return_type(
    return_type: types.TypeBase
) -> (types.TypeBase | None) {
    args = get_generator_type_args(return_type);
    if args is None {
        return None;
    }
    if len(args) >= 3 {
        return args[2];
    }
    return None;
}

impl is_generator_family_type(return_type: types.TypeBase) -> bool {
    if not isinstance(return_type, types.ClassType) {
        return False;
    }
    return return_type.is_builtin(
        [
            "Generator",
            "AsyncGenerator",
            "AwaitableGenerator",
            "Iterator",
            "Iterable",
            "AsyncIterator",
            "AsyncIterable"
        ]
    );
}


glob _proto_checks_in_progress: set = set();

impl class_implements_protocol(
    cls: types.ClassType, proto: types.ClassType, evaluator: any = None
) -> bool {
    proto_methods: dict[str, any] = {};
    proto_symtab = proto.shared.symbol_table;
    if isinstance(proto_symtab, uni.UniScopeNode) {
        for (name, sym) in proto_symtab.names_in_scope.items() {
            if sym.decl and isinstance(sym.decl.name_of, uni.Ability) {
                proto_methods[name] = sym.decl.name_of;
            }
        }
    }

    if not proto_methods {
        return True;
    }

    cls_methods: dict[str, any] = {};
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

    _key = (id(cls.shared), id(proto.shared));
    if _key in _proto_checks_in_progress {
        return True;
    }
    _proto_checks_in_progress.add(_key);
    try {
        for (name, proto_method) in proto_methods.items() {
            if name not in cls_methods {
                return False;
            }
            cls_method = cls_methods[name];

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
    } finally {
        _proto_checks_in_progress.discard(_key);
    }
}

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

    symbol: (Symbol | None) = None;
    if (inner := collect_member_syms(symtable, name, deep=True)) {
        symbol = inner[0];
    }
    if symbol is None {
        symbol = symtable.lookup(name, deep=True, incl_inner_scope=False);
    }

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

impl collect_member_syms(
    scope: uni.UniScopeNode, name: str, deep: bool = False
) -> list[Symbol] {
    import from jaclang.jac0core.helpers { evaluate_version_condition }

    def live_branches(guard: uni.IfStmt) -> list[uni.UniScopeNode] {
        eval_result = evaluate_version_condition(guard.condition);
        if eval_result is None or eval_result {
            return [guard];
        }
        if isinstance(guard.else_body, uni.ElseIf) {
            return live_branches(guard.else_body);
        }
        if isinstance(guard.else_body, uni.ElseStmt) {
            return [guard.else_body];
        }
        return [];
    }

    def descend(s: uni.UniScopeNode) -> list[Symbol] {
        if (here := s.lookup_all(name, deep=False)) {
            return here;
        }
        for kid in s.kid_scope {
            if isinstance(kid, uni.UniScopeNode.get_python_scoping_nodes()) {
                continue;
            }
            if isinstance(kid, (uni.ElseStmt, uni.ElseIf))
            and isinstance(kid.parent, uni.IfStmt) {
                continue;
            }
            branches = live_branches(kid) if isinstance(kid, uni.IfStmt) else [kid];
            for branch in branches {
                if (found := descend(branch)) {
                    return found;
                }
            }
        }
        return [];
    }

    if not deep {
        return descend(scope);
    }

    s: uni.UniScopeNode | None = scope;
    while s is not None {
        if (found := descend(s)) {
            return found;
        }
        s = s.parent_scope;
    }
    return [];
}

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

impl ParamAssignmentTracker.get_unmatched_required_params -> list[types.Parameter] {
    ret: list[types.Parameter] = [];
    for param in self.params {
        if (
            (param not in self.matched_params)
            and (param not in self.spread_filled)
            and not param.is_optional
            and (
                param.param_kind not in (types.ParamKind.VARARG, types.ParamKind.KWARG)
            )
        ) {
            ret.append(param);
        }
    }
    return ret;
}

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

impl ParamAssignmentTracker._mark_all_positional_params_as_matched -> None {
    for param in self.params {
        if (
            param.param_kind in (
                types.ParamKind.POSONLY,
                types.ParamKind.NORMAL,
                types.ParamKind.VARARG
            )
        ) {
            self.spread_filled.add(param);
        }
    }
    self.curr_param_idx = -1;
}

impl ParamAssignmentTracker._mark_all_named_params_as_matched -> None {
    for param in self.params {
        if (
            param.param_kind in (
                types.ParamKind.NORMAL,
                types.ParamKind.KWONLY,
                types.ParamKind.KWARG
            )
        ) {
            self.spread_filled.add(param);
        }
    }
}

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

impl ParamAssignmentTracker.postinit -> None {
    for param in self.params {
        if (param.param_kind == types.ParamKind.VARARG) {
            self.varargs = param;
        } elif (param.param_kind == types.ParamKind.KWARG) {
            self.kwargs = param;
        }
    }
}

impl compute_mro_linearization(cls: types.ClassType) -> None {
    if cls.shared.mro {
        return;
    }

    for base in cls.shared.base_classes {
        if isinstance(base, types.ClassType) {
            compute_mro_linearization(base);
        }
    }

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
            break;
        }
        result.append(candidate);

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

impl compute_module_source_flags(file_path: str) -> ModuleSourceFlags {
    flags = ModuleSourceFlags();

    flags.is_stub_file = file_path.endswith(".pyi");

    if not flags.is_stub_file {
        return flags;
    }

    normalized_path = file_path.replace("\\", "/");
    flags.is_stdlib_stub = "vendor/typeshed/stdlib/" in normalized_path;

    if normalized_path.endswith("stdlib/typing.pyi")
    or normalized_path.endswith("typing_extensions.pyi") {
        flags.is_typing_stub = True;
    }

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
        or normalized_path.endswith("type_system/jac_builtins.pyi")
    ) {
        flags.is_builtin_stub = True;
    }

    return flags;
}

impl convert_to_instance(ty: types.TypeBase) -> types.TypeBase {
    if ty.is_instantiable_class() {
        assert isinstance(ty, types.ClassType);
        return ty.clone_as_instance();
    }

    if isinstance(ty, types.UnionType) {
        converted = [convert_to_instance(t) for t in ty.types];
        return types.UnionType(types=converted);
    }
    return ty;
}

impl synthesize_self_type_var -> types.TypeVarType {
    return types.TypeVarType(name="Self", is_self=True);
}

impl apply_solved_type_vars(
    ty: types.TypeBase,
    solution: dict[str, types.TypeBase],
    class_type: (types.ClassType | None) = None
) -> types.TypeBase {
    if isinstance(ty, types.TypeVarType) {
        if ty.is_self and class_type is not None {
            return class_type.clone_as_instance();
        }

        is_declared_class_param = ty.is_class_type_param;
        if not is_declared_class_param and ty.name {
            if class_type is not None {
                for tp in class_type.shared.type_params {
                    if tp.name == ty.name {
                        if ty.bound is None
                        or (tp.bound is not None and ty.bound == tp.bound) {
                            is_declared_class_param = True;
                        }
                        break;
                    }
                }
            }

            if not is_declared_class_param
            and ty.bound is None
            and ty.name in solution {
                is_declared_class_param = True;
            }

            if not is_declared_class_param
            and class_type is None
            and ty.name in solution {
                is_declared_class_param = True;
            }
        }
        if not is_declared_class_param {
            return ty;
        }

        if ty.name and ty.name in solution {
            resolved = solution[ty.name];
            return convert_to_instance(resolved);
        }

        if class_type is not None and ty.name {
            for (idx, tp) in enumerate(class_type.shared.type_params) {
                if tp.name == ty.name {
                    if idx < len(class_type.private.type_args) {
                        resolved = class_type.private.type_args[idx];
                        return convert_to_instance(resolved);
                    } else {
                        return types.UnknownType();
                    }
                }
            }
        }

        return ty;
    }

    if isinstance(ty, types.FunctionType) {
        return _apply_to_function(ty, solution, class_type);
    }

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

    if isinstance(ty, types.UnionType) {
        new_types = [apply_solved_type_vars(t, solution, class_type) for t in ty.types];
        return types.UnionType(types=new_types);
    }

    return ty;
}

impl build_type_var_solution(class_type: types.ClassType) -> dict[str, types.TypeBase] {
    solution: dict[str, types.TypeBase] = {};

    if class_type.shared.type_params
    and class_type.private.type_args
    and len(class_type.private.type_args) > 0 {
        for (idx, tp) in enumerate(class_type.shared.type_params) {
            if tp.name and idx < len(class_type.private.type_args) {
                solution[tp.name] = class_type.private.type_args[idx];
            }
        }
    } elif class_type.shared.type_params {
        for tp in class_type.shared.type_params {
            if tp.name {
                solution[tp.name] = types.AnyType();
            }
        }
    }

    for mro_cls in class_type.shared.mro {
        if mro_cls.shared.type_params and mro_cls.private.type_args {
            for (idx, tp) in enumerate(mro_cls.shared.type_params) {
                if tp.name and idx < len(mro_cls.private.type_args) {
                    arg = mro_cls.private.type_args[idx];
                    resolved = apply_solved_type_vars(arg, solution);

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

impl build_solution_from_specialized_class(
    class_type: types.ClassType
) -> dict[str, types.TypeBase] {
    solution: dict[str, types.TypeBase] = {};

    if class_type.shared.type_params and class_type.private.type_args {
        for (idx, tp) in enumerate(class_type.shared.type_params) {
            if tp.name and idx < len(class_type.private.type_args) {
                if tp.name not in solution {
                    solution[tp.name] = class_type.private.type_args[idx];
                }
            }
        }
    }

    return solution;
}

impl specialize_for_base_class(
    src_type: types.ClassType, base_class: types.ClassType
) -> types.ClassType {
    if src_type.shared == base_class.shared {
        return src_type;
    }

    if not base_class.shared.type_params {
        return base_class;
    }

    return _specialize_for_base_recursive(src_type, base_class);
}

def _specialize_for_base_recursive(
    src_type: types.ClassType, target_base: types.ClassType
) -> types.ClassType {
    if src_type.shared == target_base.shared {
        return src_type;
    }

    solution = build_solution_from_specialized_class(src_type);

    if src_type.shared.base_classes {
        for base in src_type.shared.base_classes {
            if not isinstance(base, types.ClassType) {
                continue;
            }

            if base.shared == target_base.shared {
                return _apply_solution_to_class(base, solution);
            }

            target_in_mro = False;
            for mro_cls in base.shared.mro {
                if mro_cls.shared == target_base.shared {
                    target_in_mro = True;
                    break;
                }
            }

            if target_in_mro {
                specialized_base = _apply_solution_to_class(base, solution);

                return _specialize_for_base_recursive(specialized_base, target_base);
            }
        }
    }

    return target_base;
}

def _apply_solution_to_class(
    class_type: types.ClassType, solution: dict[str, types.TypeBase]
) -> types.ClassType {
    if not class_type.private.type_args {
        return class_type;
    }

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

def _apply_to_function(
    func: types.FunctionType,
    solution: dict[str, types.TypeBase],
    class_type: (types.ClassType | None)
) -> types.FunctionType {
    clone = types.FunctionType(
        func_name=func.func_name,
        return_type=func.return_type,
        parameters=[param.clone() for param in func.parameters],
        function_flags=func.function_flags,
        type_params=func.type_params,
    );

    for param in clone.parameters {
        if param.param_type {
            param.param_type = apply_solved_type_vars(
                param.param_type, solution, class_type
            );
        }
    }

    if clone.return_type {
        clone.return_type = apply_solved_type_vars(
            clone.return_type, solution, class_type
        );
    }

    return clone;
}
