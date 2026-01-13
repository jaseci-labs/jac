"""Living Workspace of Jac project."""

import asyncio;
import logging;
import os;
import sys;
import time;
import threading;
import from concurrent.futures { Future }
import from queue { Queue, Empty }
import from typing { Callable, Optional }

import jaclang.pycore.unitree as uni;
import from jaclang { JacRuntimeInterface as Jac }
import from jaclang.pycore.constant { SymbolType }
import from jaclang.pycore.program { JacProgram }
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
import from jaclang.vendor.pygls { uris }
import from jaclang.vendor.pygls.server { LanguageServer }

import lsprotocol.types as lspt;
import from . { utils }
import from .module_manager { ModuleManager }

obj Task {
    has file_uri: str,
        task_id: int = 0,
        cancel_token: threading.Event | None = None;

    static has _task_id: int = 0;

    def postinit -> None;
}

"""Jac Language Server, manages JacProgram and LSP."""
obj JacLangServer(JacProgram, LanguageServer) {
    has sem_managers: dict = {},
        module_manager: ModuleManager | None = None,
        queue: Queue = Queue(),
        worker_future: Future | None = None,
        last_task: Task | None = None,
        _shutdown_called: bool = False;

    def postinit -> None;
    def dispatcher -> None;
    @property
    def diagnostics -> dict[str, list];

    def _clear_alerts_for_file(file_path: str) -> None;
    def get_ir(file_path: str) -> Optional[uni.Module];
    def update_modules(file_path: str, build: uni.Module, need: bool = True) -> None;
    def type_check_file(
        file_uri: str,
        cancel_token: Event | None = None,
        annex_view: Optional[str] = None,
        # This parameter will be passed recursively
        # and dont need to pass when the function itself is called
        # outside.
    ) -> bool;

    def type_check(file_uri: str) -> None;
    def get_token_at_position(
        file_path: str, position: lspt.Position
    ) -> Optional[uni.AstNode];

    def debug(msg: str) -> None;
    async def wait_till_idle -> None;
    def wait_till_idle_sync -> None;
    async def get_completion(
        file_uri: str, position: lspt.Position, completion_trigger: Optional[str]
    ) -> lspt.CompletionList;

    def get_ast_of_file(file_path: str) -> Optional[uni.AstNode];
    def get_node_at_position(
        file_path: str, line: int, col: int
    ) -> Optional[uni.AstNode];

    def get_completion_of_node(node: uni.AstNode) -> lspt.CompletionList;
    def get_node_type(n: uni.AstNode) -> Optional[TypeBase];
    def get_completion_items_of(ty: TypeBase | uni.UniScopeNode) -> lspt.CompletionList;
    def rename_module(old_path: str, new_path: str) -> None;
    def delete_module(uri: str) -> None;
    def formatted_jac(file_path: str) -> list[lspt.TextEdit];
    def get_hover_info(file_path: str, position: lspt.Position) -> Optional[lspt.Hover];
    def get_node_info(sym_node: uni.AstSymbolNode) -> Optional[str];
    def get_outline(file_path: str) -> list[lspt.DocumentSymbol];
    def get_definition(
        file_path: str, position: lspt.Position
    ) -> Optional[lspt.Location];

    def get_references(file_path: str, position: lspt.Position) -> list[lspt.Location];
    def rename_symbol(
        file_path: str, position: lspt.Position, new_name: str
    ) -> Optional[lspt.WorkspaceEdit];

    def get_semantic_tokens(file_path: str) -> lspt.SemanticTokens;
    def log_error(message: str) -> None;
    def log_warning(message: str) -> None;
    def log_info(message: str) -> None;
    def log_py(message: str) -> None;
    def shutdown -> None;
}
