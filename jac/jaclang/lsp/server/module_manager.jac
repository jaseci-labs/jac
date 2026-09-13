import jaclang.compiler.ir.schema as uni;
import from jaclang.compiler.session.session { JacProgram }
import from .sem_manager { SemTokManager }

obj ModuleManager {
    has program: JacProgram,
        sem_managers: dict[str, SemTokManager];

    def update(
        file_path: str,
        build: uni.Module,
        update_annexed: bool = True,
        files: (list[str] | None) = None
    ) -> None;

    def clear_alerts_for_file(file_path_fs: str) -> None;
}
