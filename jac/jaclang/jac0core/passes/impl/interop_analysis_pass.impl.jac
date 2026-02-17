"""Implementation for interop_analysis_pass constructs."""

"""Initialize function definition tracking."""
impl InteropAnalysisPass.before_pass(self: InteropAnalysisPass) -> None {
    self._func_defs: dict[(str, tuple[(InteropContext, uni.Ability)])] = {};
    self._imported_native_funcs: dict[(str, tuple[(str, InteropContext)])] = {};
}

"""Determine the codespace context of a node."""
impl InteropAnalysisPass._get_context(
    self: InteropAnalysisPass, nd: uni.UniNode
) -> InteropContext {
    if nd.in_native_context() {
        return InteropContext.NATIVE;
    }
    if nd.in_client_context() {
        return InteropContext.CLIENT;
    }
    return InteropContext.SERVER;
}

"""Extract a type name string from a type annotation expression."""
impl InteropAnalysisPass._extract_type_name(
    self: InteropAnalysisPass, expr: (uni.UniNode | None)
) -> str {
    if (expr is None) {
        return 'int';
    }
    if isinstance(expr, uni.Name) {
        return expr.value;
    }
    if isinstance(expr, uni.Token) {
        return expr.value;
    }
    return 'int';
}

"""Check if a module name refers to a .na.jac file and return the path
suffix.

        Given a module name like 'na_math_utils', checks if
'na_math_utils.na.jac'
        exists relative to the current module. Returns the module path for
linking
        (e.g., 'na_math_utils.na') or None if not a native module.
        """
impl InteropAnalysisPass._resolve_native_module(
    self: InteropAnalysisPass, module_name: str
) -> (str | None) {
    import os;
    base_dir = '.';
    if (self.ir_in and self.ir_in.loc) {
        base_dir = os.path.dirname(self.ir_in.loc.mod_path);
    }
    na_jac_path = os.path.join(base_dir, f"{module_name}.na.jac");
    if os.path.exists(na_jac_path) {
        return f"{module_name}.na";
    }
    return None;
}

"""Track imports from .na.jac modules."""
impl InteropAnalysisPass.enter_import(
    self: InteropAnalysisPass, nd: uni.Import
) -> None {
    import_context = self._get_context(nd);
    if (nd.from_loc and isinstance(nd.from_loc, uni.ModulePath)) {
        module_name = getattr(nd.from_loc, 'dot_path_str', None);
        if (not module_name and nd.from_loc?.path and nd.from_loc.path) {
            module_name = '.'.join(
                getattr(p, 'value', str(p)) for p in nd.from_loc.path
            );
        }
        if module_name {
            native_path = self._resolve_native_module(module_name);
            if (native_path and nd.items) {
                for item in nd.items {
                    if isinstance(item, uni.ModuleItem) {
                        func_name = getattr(item.name, 'value', str(item.name));
                        self._imported_native_funcs[func_name] = (
                            native_path,
                            import_context
                        );
                    }
                }
            }
        }
    }
}

"""Record function definition and its context."""
impl InteropAnalysisPass.enter_ability(
    self: InteropAnalysisPass, nd: uni.Ability
) -> None {
    if (nd.sym_name and isinstance(nd.signature, uni.FuncSignature)) {
        ctx = self._get_context(nd);
        self._func_defs[nd.sym_name] = (ctx, nd);
    }
}

"""Check if a function call crosses context boundaries."""
impl InteropAnalysisPass.enter_func_call(
    self: InteropAnalysisPass, nd: uni.FuncCall
) -> None {
    func_name = None;
    if isinstance(nd.target, uni.Name) {
        func_name = nd.target.value;
    } elif isinstance(nd.target, uni.NameAtom) {
        func_name = nd.target.sym_name;
    }
    if not func_name {
        return;
    }
    caller_ctx = self._get_context(nd);
    manifest = self.ir_in.gen.interop_manifest;
    if (func_name in self._imported_native_funcs) {
        (source_module, import_ctx) = self._imported_native_funcs[func_name];
        if (caller_ctx == InteropContext.NATIVE) {
            if (func_name not in manifest.bindings) {
                binding = InteropBinding(
                    name=func_name,
                    source_context=InteropContext.NATIVE,
                    callers={InteropContext.NATIVE},
                    ret_type='int',
                    param_types=[],
                    param_names=[],
                    ast_node=None,
                    route=[InteropContext.NATIVE, InteropContext.NATIVE],
                    source_module=source_module
                );
                manifest.bindings[func_name] = binding;
            } else {
                manifest.bindings[func_name].callers.add(InteropContext.NATIVE);
            }
        }
        return;
    }
    if (func_name not in self._func_defs) {
        return;
    }
    (callee_ctx, callee_node) = self._func_defs[func_name];
    if (caller_ctx == callee_ctx) {
        return;
    }
    if (func_name in manifest.bindings) {
        manifest.bindings[func_name].callers.add(caller_ctx);
    } else {
        sig = callee_node.signature;
        assert isinstance(sig, uni.FuncSignature);
        ret_type = self._extract_type_name(sig.return_type);
        param_types: list = [];
        param_names: list = [];
        for p in sig.params {
            param_names.append(p.sym_name);
            if p.type_tag {
                param_types.append(self._extract_type_name(p.type_tag.tag));
            } else {
                param_types.append('int');
            }
        }
        binding = InteropBinding(
            name=func_name,
            source_context=callee_ctx,
            callers={caller_ctx},
            ret_type=ret_type,
            param_types=param_types,
            param_names=param_names,
            ast_node=callee_node,
            route=[caller_ctx, callee_ctx]
        );
        manifest.bindings[func_name] = binding;
    }
}
