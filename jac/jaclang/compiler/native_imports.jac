import jaclang.compiler.frontend.unitree as uni;

obj NativePythonImport {
    has module: str,
        binding: str,
        attribute: str = "",
        bind_module: str = "";
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
