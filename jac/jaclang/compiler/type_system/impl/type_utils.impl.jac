"""Determine if a class implements a protocol.

This checks if the source class has all the members required by the protocol.
Following Pyright's approach, we iterate through the protocol's MRO and check
if each required member exists in the source class (also through MRO lookup).

PyrightReference:
    packages/pyright-internal/src/analyzer/protocols.ts - assignToProtocolInternal()
"""
impl class_implements_protocol(cls: types.ClassType, proto: types.ClassType) -> bool {
    # Ensure MRO is computed for the source class.
    if not cls.shared.mro {
        compute_mro_linearization(cls);
    }

    # Collect all member names from the source class through its MRO.
    # This includes both methods and attributes from the class and all its bases.
    cls_member_names: set[str] = set();
    for mro_cls in cls.shared.mro {
        for name in mro_cls.shared.symbol_table.names_in_scope.keys() {
            cls_member_names.add(name);
        }
    }

    # Ensure MRO is computed for the protocol.
    if not proto.shared.mro {
        compute_mro_linearization(proto);
    }

    # Check if all required protocol members exist in the source class.
    # Following Pyright, we iterate through the protocol's MRO.
    for mro_proto in proto.shared.mro {
        # Skip base protocol/special classes in the MRO.
        # These include: Protocol, _SpecialForm, object, Generic, etc.
        # Protocol members only come from the concrete protocol definition.
        class_name = mro_proto.shared.class_name;
        if class_name in ("Protocol", "_SpecialForm", "object", "Generic", "ABCMeta", "_Final") {
            continue;
        }

        for (name, sym) in mro_proto.shared.symbol_table.names_in_scope.items() {
            # Skip dunder methods that shouldn't be part of protocol matching.
            # Following Pyright's convention for __class_getitem__ and __slots__.
            if name in ("__class_getitem__", "__slots__") {
                continue;
            }
            # Skip private attributes (single underscore prefix but not dunder).
            if name.startswith("_") and not name.startswith("__") {
                continue;
            }
            # Check if the member exists in the source class.
            if name not in cls_member_names {
                return False;
            }
        }
    }

    # TODO: For full Pyright-style checking, we should also validate:
    # 1. Type compatibility of each member (not just existence)
    # 2. Read-only vs writable attribute compatibility
    # 3. ClassVar matching
    # For now, we only check member existence through MRO.
    return True;
}

"""Get the list of missing protocol members that a class needs to implement.

Returns a list of member names that are required by the protocol but not
present in the source class. Useful for generating helpful error messages.
"""
impl get_missing_protocol_members(cls: types.ClassType, proto: types.ClassType) -> list[str] {
    missing: list[str] = [];

    # Ensure MRO is computed for the source class.
    if not cls.shared.mro {
        compute_mro_linearization(cls);
    }

    # Collect all member names from the source class through its MRO.
    cls_member_names: set[str] = set();
    for mro_cls in cls.shared.mro {
        for name in mro_cls.shared.symbol_table.names_in_scope.keys() {
            cls_member_names.add(name);
        }
    }

    # Ensure MRO is computed for the protocol.
    if not proto.shared.mro {
        compute_mro_linearization(proto);
    }

    # Find all protocol members that are missing from the source class.
    for mro_proto in proto.shared.mro {
        # Skip base protocol/special classes in the MRO.
        class_name = mro_proto.shared.class_name;
        if class_name in ("Protocol", "_SpecialForm", "object", "Generic", "ABCMeta", "_Final") {
            continue;
        }

        for (name, sym) in mro_proto.shared.symbol_table.names_in_scope.items() {
            # Skip dunder methods that shouldn't be part of protocol matching.
            if name in ("__class_getitem__", "__slots__") {
                continue;
            }
            # Skip private attributes (single underscore prefix but not dunder).
            if name.startswith("_") and not name.startswith("__") {
                continue;
            }
            # Check if the member is missing.
            if name not in cls_member_names and name not in missing {
                missing.append(name);
            }
        }
    }

    return missing;
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
    return symtable.lookup(name, deep=True, incl_inner_scope=True);
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
            if (param.param_kind in (types.ParamKind.NORMAL, types.ParamKind.POSONLY)) {
                self.curr_param_idx += 1;
                self.matched_params.add(param);
                return param;
            }
        }
        raise Exception('Too many positional arguments') ;
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
        ) ;
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
            ) ;
        }
        if (param.param_kind not in (types.ParamKind.NORMAL, types.ParamKind.KWONLY)) {
            continue;
        }
        if (param.name == param_name) {
            if (param in self.matched_params) {
                raise Exception(f"Parameter '{param.name}' already matched") ;
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
    cls.shared.mro.append(cls);
    for base in cls.shared.base_classes {
        if isinstance(base, types.ClassType) {
            compute_mro_linearization(base);
        }
    }
    for base in cls.shared.base_classes {
        if isinstance(base, types.ClassType) {
            for mro_cls in base.shared.mro {
                if (mro_cls not in cls.shared.mro) {
                    cls.shared.mro.append(mro_cls);
                }
            }
        }
    }
}
