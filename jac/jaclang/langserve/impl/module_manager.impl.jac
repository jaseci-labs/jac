"""Remove errors and warnings for a specific file from the lists."""
import sys;

def _modmgr_debug(msg: str) -> None {
    print(f"[ModuleManager] {msg}", file=sys.stderr);
}

impl ModuleManager.clear_alerts_for_file(file_path_fs: str) -> None {
    old_errors = len(self.program.errors_had);
    old_warnings = len(self.program.warnings_had);
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
    _modmgr_debug(f"clear_alerts_for_file: {file_path_fs} - cleared {old_errors - len(self.program.errors_had)} errors, {old_warnings - len(self.program.warnings_had)} warnings");
}

"""Update modules in JacProgram's hub and semantic managers."""
impl ModuleManager.update(
    file_path: str, build: uni.Module, update_annexed: bool = True
) -> None {
    _modmgr_debug(f"update: {file_path} (update_annexed={update_annexed})");
    self.program.mod.hub[file_path] = build;
    if update_annexed {
        hub = self.program.mod.hub;
        self.sem_managers[file_path] = SemTokManager(ir=build, hub=hub);
        _modmgr_debug(f"Created SemTokManager for {file_path}");
        for (p, mod) in hub.items() {
            if p != file_path {
                self.sem_managers[p] = SemTokManager(ir=mod, hub=hub);
            }
        }
        _modmgr_debug(f"Updated {len(hub)} modules total");
    }
}
