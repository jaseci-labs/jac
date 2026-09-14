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
    self.program.install_module(file_path, build);

    if update_annexed {
        for f in (files or [file_path]) {
            manager = SemTokManager(ir=build, target_path=f);
            self.sem_managers[f] = manager;
            self.products[f] = DocumentProducts(list(manager.sem_tokens));
        }
    }
}
