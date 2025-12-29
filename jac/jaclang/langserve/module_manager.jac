import jaclang.pycore.unitree as uni;
import from jaclang.pycore.program { JacProgram }
import from .sem_manager { SemTokManager }

"""Handles Jac module, semantic manager, and alert management."""
obj ModuleManager {
    has program: JacProgram,
        sem_managers: dict;

    def update(file_path: str, build: uni.Module, update_annexed: bool = True) -> None;
    def clear_alerts_for_file(file_path_fs: str) -> None;
}
