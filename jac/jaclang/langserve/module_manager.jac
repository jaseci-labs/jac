import jaclang.pycore.unitree as uni;
import from jaclang.pycore.program { JacProgram }
import from .sem_manager { SemTokManager }

"""Handles Jac module, semantic manager, and alert management."""
class ModuleManager {
    """Initialize ModuleManager."""
    def init(self: ModuleManager, program: JacProgram, sem_managers: dict) -> None {
        self.program = program;
        self.sem_managers = sem_managers;
    }

    """Update modules in JacProgram's hub and semantic managers."""
    def update(
        self: ModuleManager,
        file_path: str,
        build: uni.Module,
        update_annexed: bool = True
    ) -> None {
        self.program.mod.hub[file_path] = build;
        if update_annexed {
            self.sem_managers[file_path] = SemTokManager(ir=build);
            for (p, mod) in self.program.mod.hub.items() {
                if p != file_path {
                    self.sem_managers[p] = SemTokManager(ir=mod);
                }
            }
        }
    }

    """Remove errors and warnings for a specific file from the lists."""
    def clear_alerts_for_file(self: ModuleManager, file_path_fs: str) -> None {
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
}
