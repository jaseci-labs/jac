import os;

obj SelfHostCache {
    has _program: (JacProgram | None) = None,
        _jaclang_root: (str | None) = None,
        _bytecode_depth: int = 0,
        _execution_depth: int = 0,
        _release_pending: bool = False,
        _collect_pending: bool = False;

    has program: JacProgram { getter; }

    def peek_program -> (JacProgram | None);
    def is_selfhost(prog: (JacProgram | None)) -> bool;
    def jaclang_root -> str;
    def owns(file_path: str) -> bool;
    def resolve(
        file_path: str,
        target_program: JacProgram,
        force: bool = False,
        native_unit: bool = False,
        execution: bool = False
    ) -> JacProgram;

    def evict_unit(
        full_target: str, result: (uni.Module | None), collect: bool = True
    ) -> None;

    def enter_execution;
    def exit_execution;
    def enter_bytecode;
    def exit_bytecode;
    def at_outermost_bytecode -> bool;
}
