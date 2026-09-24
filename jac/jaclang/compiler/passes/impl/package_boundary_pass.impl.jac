import os;
import from jaclang.compiler.frontend.module_facts { ModuleFacts }
import from jaclang.compiler.frontend.diagnostics { E2095, E2096 }

impl PackageBoundaryPass.run_walk with Module entry {
    import from jaclang.compiler.driver.jir { is_compiler_source_path }
    mod = here;
    path = mod.loc.mod_path if mod.loc else "";
    if not path or not path.endswith(".jac") or is_compiler_source_path(path) {
        return;
    }
    import from jaclang.project.package_scope { package_root_of }
    importer_root = package_root_of(path);
    for imp in [
        *ModuleFacts.iter_module_imports(mod),
        *ModuleFacts.iter_nested_imports(mod)
    ] {
        for target in self._targets(imp) {
            self._check_target(importer_root, target);
        }
    }
}

impl PackageBoundaryPass._targets(imp: Import) -> list[ModulePath] {
    if imp.from_loc is not None {
        return [imp.from_loc];
    }
    return [
        item
        for item in imp.items
        if isinstance(item, ModulePath)
    ];
}

impl PackageBoundaryPass._check_target(
    importer_root: (str | None), path_node: ModulePath
) -> None {
    import from jaclang.project.package_scope {
        declared_package_name,
        import_prefix,
        is_exported,
        module_name_in,
        package_exports,
        package_root_of
    }
    try {
        resolved = path_node.resolve_relative_path();
    } except Exception {
        return;
    }
    if not resolved or not os.path.isfile(resolved) {
        return;
    }
    target_root = package_root_of(resolved);
    if target_root is None {
        return;
    }
    module = module_name_in(target_root, resolved);
    if module is None {
        return;
    }
    prefix = import_prefix(declared_package_name(target_root));
    if importer_root is not None
        and os.path.realpath(importer_root) == os.path.realpath(target_root) {
        dotted = path_node.dot_path_str;
        if path_node.level > 0 or dotted == prefix or dotted.startswith(prefix + ".") {
            return;
        }
        self.ctx.emit(
            E2095,
            node_override=path_node,
            module=dotted,
            qualified=f"{prefix}.{module}"
        );
        return;
    }
    exports = package_exports(target_root);
    if exports and not is_exported(module, exports) {
        self.ctx.emit(
            E2096,
            node_override=path_node,
            module=f"{prefix}.{module}",
            package=declared_package_name(target_root),
            exports=", ".join(exports)
        );
    }
}
