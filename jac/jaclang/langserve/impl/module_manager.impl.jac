impl ModuleManager.clear_alerts_for_file(file_path_fs: str) -> None {
    self.program.errors_had = [
        e
        for e in self.program.errors_had
        if e.loc.mod_path != file_path_fs
    ];
    self.program.warnings_had = [
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
    self.program.mod.hub[file_path] = build;

    if update_annexed {
        hub = self.program.mod.hub;
        for f in (files or [file_path]) {
            self.sem_managers[f] = SemTokManager(ir=build, hub=hub, target_path=f);
        }

        for (p, mod) in hub.items() {
            if p != file_path {
                self.sem_managers[p] = SemTokManager(ir=mod, hub=hub, target_path=p);
            }
        }
    }
}
