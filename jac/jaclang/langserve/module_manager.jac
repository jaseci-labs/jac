import jaclang.pycore.unitree as uni;
import from jaclang.pycore.program { JacProgram }
import from .sem_manager { SemTokManager }

"""Handles Jac module, semantic manager, and alert management."""
class ModuleManager {
    def init(self: ModuleManager, program: JacProgram, sem_managers: dict) -> None;
    def update(
        self: ModuleManager,
        file_path: str,
        build: uni.Module,
        update_annexed: bool = True
    ) -> None;

    def clear_alerts_for_file(self: ModuleManager, file_path_fs: str) -> None;
}
