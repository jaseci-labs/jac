import os;
import from jaclang.compiler.frontend.module_facts { ModuleFacts }
import from jaclang.compiler.frontend.diagnostics { E2095, E2096 }
import from jaclang.compiler.frontend.host { active_host }
import from jaclang.compiler.driver.wiring { local_module_name }

impl PackageBoundaryPass.run_walk with Module entry {
    import from jaclang.compiler.frontend.codeinfo { is_compiler_source_path }
    mod = here;
    path = mod.loc.mod_path if mod.loc else "";
    if not path or not path.endswith(".jac") or is_compiler_source_path(path) {
        return;
    }
    importer = self._package_of(path);
    for imp in [
        *ModuleFacts.iter_module_imports(mod),
        *ModuleFacts.iter_nested_imports(mod)
    ] {
        for target in self._targets(imp) {
            self._check_target(importer, target);
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

impl PackageBoundaryPass._package_of(path: str) -> (ProjectFacts | None) {
    facts = active_host().project_facts(path);
    return facts if facts is not None and facts.package_name else None;
}

impl PackageBoundaryPass._check_target(
    importer: (ProjectFacts | None), path_node: ModulePath
) -> None {
    try {
        resolved = path_node.resolve_relative_path();
    } except Exception {
        return;
    }
    if not resolved or not os.path.isfile(resolved) {
        return;
    }
    target = self._package_of(resolved);
    if target is None {
        return;
    }
    module = local_module_name(target.project_root, resolved);
    if module is None {
        return;
    }
    prefix = target.package_name.replace("/", ".");
    if importer is not None
        and os.path.realpath(importer.project_root)
            == os.path.realpath(target.project_root) {
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
    exports = target.package_exports;
    if exports and not any(export_matches(module, p) for p in exports) {
        self.ctx.emit(
            E2096,
            node_override=path_node,
            module=f"{prefix}.{module}",
            package=target.package_name,
            exports=", ".join(exports)
        );
    }
}

impl export_matches(module: str, pattern: str) -> bool {
    (m, p) = (0, 0);
    (star, mark) = (-1, 0);
    while m < len(module) {
        if p < len(pattern) and (pattern[p] == "?" or pattern[p] == module[m]) {
            m += 1;
            p += 1;
        } elif p < len(pattern) and pattern[p] == "*" {
            star = p;
            mark = m;
            p += 1;
        } elif star >= 0 {
            p = star + 1;
            mark += 1;
            m = mark;
        } else {
            return False;
        }
    }
    while p < len(pattern) and pattern[p] == "*" {
        p += 1;
    }
    return p == len(pattern);
}
