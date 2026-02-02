"""Worker process for the Jac Language Server.

The worker is a dumb process that owns the JacProgram, module hub, AST,
SemTokManagers, and TypeEvaluator. It executes whatever the main process
asks — compilation, hover, goto-def, etc. — and returns serialized results
over a multiprocessing.Pipe.

The worker has ZERO scheduling logic. All priority decisions happen in the
main process.
"""

import from multiprocessing { Process }
import from multiprocessing.connection { Connection }
import from multiprocessing.synchronize { Event }
import from typing { Optional }

import jaclang.pycore.unitree as uni;
import from jaclang.pycore.program { JacProgram }
import from jaclang.pycore.constant { SymbolType }
import from jaclang.compiler.type_system.type_utils { get_completion_items }
import from jaclang.compiler.type_system.types {
    ClassType,
    FunctionType,
    OverloadedType,
    ModuleType,
    TypeBase
}
import from jaclang.pycore.unitree { UniScopeNode }
import from .sem_manager { SemTokManager }
import from .module_manager { ModuleManager }
import from .utils {
    gen_diagnostics,
    find_index,
    get_symbols_for_outline,
    create_range,
    position_within_node,
    add_unique_text_edit
}
import from jaclang.vendor.pygls { uris }

import lsprotocol.types as lspt;

"""Worker object that owns all compilation state."""
obj Worker {
    has conn: Connection,
        cancel_event: Event,
        program: JacProgram by postinit,
        module_manager: ModuleManager | None by postinit,
        sem_managers: dict = {};

    def postinit -> None;
    def run -> None;
    def dispatch(cmd: dict) -> dict | None;

    # ── Compilation ──────────────────────────────────────────────
    def handle_compile(file_path: str, source: str) -> dict;
    def type_check_file(
        file_path: str,
        source: str,
        annex_view: Optional[str] = None
    ) -> dict;
    def _collect_diagnostics(
        file_path: str, annex_view: Optional[str] = None
    ) -> dict;

    # ── Foreground request handlers ──────────────────────────────
    def handle_hover(file_path: str, line: int, character: int) -> dict;
    def handle_definition(file_path: str, line: int, character: int) -> dict;
    def handle_references(file_path: str, line: int, character: int) -> dict;
    def handle_outline(file_path: str) -> dict;
    def handle_semantic_tokens(file_path: str) -> dict;
    def handle_completion(
        file_path: str, line: int, character: int, trigger: Optional[str]
    ) -> dict;
    def handle_rename(
        file_path: str, line: int, character: int, new_name: str
    ) -> dict;
    def handle_format(file_path: str, source: str) -> dict;

    # ── Module management ────────────────────────────────────────
    def handle_delete_module(file_path: str) -> None;
    def handle_rename_module(old_path: str, new_path: str) -> None;

    # ── Internal helpers ─────────────────────────────────────────
    def get_token_at_position(
        file_path: str, line: int, character: int
    ) -> Optional[uni.AstNode];
    def get_node_at_position(
        file_path: str, line: int, col: int
    ) -> Optional[uni.AstNode];
    def get_node_info(sym_node: uni.AstSymbolNode) -> Optional[str];
    def get_node_type(n: uni.AstNode) -> Optional[TypeBase];
    def get_completion_items_of(ty: TypeBase | uni.UniScopeNode) -> list[dict];
    def get_completion_of_node(node: uni.AstNode) -> list[dict];
    def debug(msg: str) -> None;
}

"""Entry point for the worker process (target for multiprocessing.Process)."""
def worker_main(conn: Connection, cancel_event: Event) -> None;
