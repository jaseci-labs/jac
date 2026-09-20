import jaclang.compiler.frontend.unitree as uni;

obj NativePythonImport {
    has module: str,
        binding: str,
        attribute: str = "",
        bind_module: str = "";
}

def python_object_expression(nd: uni.UniNode, seen: set[int] | None = None) -> bool {
    """Identify values originating from the hosted provider, including local aliases.""";
    import os;
    if seen is None {
        seen = set();
    }
    if id(nd) in seen {
        return False;
    }
    seen.add(id(nd));
    if isinstance(nd, uni.CfgExpr) {
        return python_object_expression(nd.expr, seen);
    }
    if isinstance(nd, uni.AtomUnit) {
        return python_object_expression(nd.value, seen);
    }
    if isinstance(nd, (uni.FuncCall, uni.AtomTrailer)) {
        return python_object_expression(nd.target, seen);
    }
    if isinstance(nd, uni.BinaryExpr) {
        return python_object_expression(nd.left, seen)
            or python_object_expression(nd.right, seen);
    }
    if not isinstance(nd, uni.Name) or nd.sym is None or nd.sym.decl is None {
        return False;
    }
    declaration = nd.sym.decl;
    owner: uni.UniNode | None = declaration;
    while owner is not None {
        if isinstance(owner, (uni.ModulePath, uni.ModuleItem)) {
            base = os.path.dirname(os.path.abspath(owner.loc.mod_path));
            return python_import_binding(owner, base) is not None;
        }
        if isinstance(owner, uni.Assignment) {
            return owner.value is not None
                and python_object_expression(owner.value, seen);
        }
        if isinstance(owner, (uni.Ability, uni.ParamVar, uni.HasVar, uni.Module)) {
            break;
        }
        owner = owner.parent;
    }
    return False;
}

def python_import_binding(
    item: uni.UniNode, base_dir: str
) -> NativePythonImport | None {
    import from jaclang.compiler.passes.capability_check_pass {
        classify_native_import,
        import_bound_name,
        from_import_jac_source
    }
    import from jaclang.compiler.frontend.codeinfo { resolve_native_module }
    (module, supported) = classify_native_import(item);
    if module is None or supported {
        return None;
    }
    owner = item.parent;
    if not isinstance(owner, uni.Import) or owner.clib_decls or owner.is_absorb {
        return None;
    }
    if resolve_native_module(module, base_dir)[1] is not None {
        return None;
    }
    if isinstance(item, uni.ModuleItem) and from_import_jac_source(owner) is not None {
        return None;
    }
    binding = import_bound_name(item);
    if binding is None {
        return None;
    }
    attribute = item.name.value if isinstance(item, uni.ModuleItem) else "";
    bind_module = module;
    if isinstance(item, uni.ModulePath) and item.alias is None {
        bind_module = module.split(".")[0];
    }
    return NativePythonImport(
        module=module, binding=binding, attribute=attribute, bind_module=bind_module
    );
}
