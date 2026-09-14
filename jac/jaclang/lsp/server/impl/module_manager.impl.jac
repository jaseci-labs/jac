impl ModuleManager.clear_alerts_for_file(file_path_fs: str) -> None {
    self.program.errors_had[:] = [
        e
        for e in self.program.errors_had
        if e.loc.mod_path != file_path_fs
    ];
    self.program.warnings_had[:] = [
        w
        for w in self.program.warnings_had
        if w.loc.mod_path != file_path_fs
    ];
}

impl ModuleManager.update(
    file_path: str,
    build: uni.Module,
    update_annexed: bool = True,
    files: (list[str] | None) = None
) -> None {
    self.completions.clear();
    snapshot = self.program.source_store.snapshot;
    inputs = snapshot.manifest() if snapshot is not None else None;
    if update_annexed {
        for f in (files or [file_path]) {
            manager = SemTokManager(ir=build, target_path=f);
            self.sem_managers[f] = manager;
            self.products[f] = DocumentProducts(
                file_path, inputs, list(manager.sem_tokens)
            );
        }
    }
}

impl ModuleManager.trim -> None {
    self.trim_editor_caches();
    (contexts, nodes) = self.program.analysis_cache_usage();
    if contexts <= self.budget.max_contexts and nodes <= self.budget.max_nodes {
        return;
    }
    import from jaclang.lsp.server.utils { get_symbols_for_outline }
    for (path, manager) in self.sem_managers.items() {
        products = self.products.get(path);
        if products is not None and products.outline is None {
            products.outline = get_symbols_for_outline(manager.ir.sym_tab, path);
        }
    }
    self.program.trim_analysis_cache(self.budget);
    self.completions.clear();
    for path in list(self.sem_managers) {
        if self.program.module_owner(self.sem_managers[path].ir) is None {
            self.sem_managers.pop(path);
        }
    }
}
