"""Remove errors and warnings for a specific file from the lists."""

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

"""Update modules in JacProgram's hub and semantic managers."""
impl ModuleManager.update(
    file_path: str,
    build: uni.Module,
    update_annexed: bool = True,
    files: (list[str] | None) = None
) -> None {
    self.program.mod.hub[file_path] = build;
    # Annex bodies are merged into `build` (the head module) and resolved in
    # place by JacAnnexPass + DeclImplMatchPass -- there are no separate impl
    # modules in the hub. Tokens are still served per source file (the editor
    # opens foo.impl.jac, not the head), so register one manager per involved
    # file -- `files` is the engine's files_to_check (the head plus its
    # .impl/.test annexes) -- each filtered to its own loc.mod_path provenance.
    if update_annexed {
        hub = self.program.mod.hub;
        for f in (files or [file_path]) {
            self.sem_managers[f] = SemTokManager(ir=build, hub=hub, target_path=f);
        }
        # Refresh a head-filtered manager for every other hub module; their own
        # annex managers persist from when those files were last updated.
        for (p, mod) in hub.items() {
            if p != file_path {
                self.sem_managers[p] = SemTokManager(ir=mod, hub=hub, target_path=p);
            }
        }
    }
}
