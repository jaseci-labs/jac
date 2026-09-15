impl ModuleManager.update(
    file_path: str,
    build: uni.Module,
    analysis: AnalysisRecord,
    files: list[str] | None = None
) -> None {
    import from jaclang.lsp.server.utils { get_symbols_for_outline }
    self.completions.clear();
    for file in (files or [file_path]) {
        manager = SemTokManager(ir=build, target_path=file);
        self.sem_managers[file] = manager;
        self.products[file] = DocumentProducts(
            file_path,
            analysis,
            list(manager.sem_tokens),
            get_symbols_for_outline(build.sym_tab, file)
        );
    }
}

impl ModuleManager.trim -> None {
    self.trim_editor_caches();
    self.program.analysis_service().trim();
    for path in list(self.sem_managers) {
        if self.program.module_owner(self.sem_managers[path].ir) is None {
            self.sem_managers.pop(path);
            self.completions.clear();
        }
    }
}
