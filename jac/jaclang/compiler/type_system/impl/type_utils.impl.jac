"""Determine if a class implements a protocol.

This checks if a class has all the methods required by a protocol,
including methods inherited from base classes via MRO.

Uses symbol table lookup instead of get_methods() to properly handle
stub file classes where AST parent relationships may not be set correctly.
"""
impl class_implements_protocol(cls: types.ClassType, proto: types.ClassType) -> bool {
    # Get protocol method names from symbol table (more reliable than get_methods())
    # This handles stub file classes where is_method may not work correctly.
    proto_method_names: set[str] = set();
    proto_symtab = proto.shared.symbol_table;
    if isinstance(proto_symtab, uni.UniScopeNode) {
        for (name, sym) in proto_symtab.names_in_scope.items() {
            # Include methods (Ability nodes) but skip special attributes
            if sym.decl and isinstance(sym.decl.name_of, uni.Ability) {
                proto_method_names.add(name);
            }
        }
    }

    # If no protocol methods found, protocol is trivially satisfied
    if not proto_method_names {
        return True;
    }

    # Collect method names from the class and all its MRO classes using symbol table
    cls_method_names: set[str] = set();
    for mro_cls in cls.shared.mro {
        mro_symtab = mro_cls.shared.symbol_table;
        if isinstance(mro_symtab, uni.UniScopeNode) {
            for (name, sym) in mro_symtab.names_in_scope.items() {
                if sym.decl and isinstance(sym.decl.name_of, uni.Ability) {
                    cls_method_names.add(name);
                }
            }
        }
    }
    return proto_method_names.issubset(cls_method_names);
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
