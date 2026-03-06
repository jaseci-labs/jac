"""Determine if a class implements a protocol.

This checks if a class has all the methods required by a protocol,
including methods inherited from base classes via MRO.
When an evaluator is provided, method signatures are compared using
resolved types (via get_type_of_ability and _assign_callable), which
handles complex types like generics, unions, and aliases correctly.
"""
impl class_implements_protocol(
    cls: types.ClassType, proto: types.ClassType, evaluator: Any = None
) -> bool {
    proto_ast: uni.Archetype = proto.shared.symbol_table;
    proto_methods = {method.sym_name: method for method in proto_ast.get_methods()};

    # Collect methods from the class and all its MRO classes (first found wins)
    cls_methods: dict[str, Any] = {};
    for mro_cls in cls.shared.mro {
        if isinstance(mro_cls.shared.symbol_table, uni.Archetype) {
            for method in mro_cls.shared.symbol_table.get_methods() {
                if method.sym_name not in cls_methods {
                    cls_methods[method.sym_name] = method;
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
            (param.param_kind == types.ParamKind.POSONLY)
            and (param_name == param.name)
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
