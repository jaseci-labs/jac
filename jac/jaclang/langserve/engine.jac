"""Living Workspace of Jac project."""

import asyncio;
import logging;
import os;
import sys;
import time;
import threading;
import from collections { deque }
import from concurrent.futures { Future }
import from typing { Callable, Optional }

import jaclang.jac0core.unitree as uni;
import from jaclang { JacRuntimeInterface as Jac }
import from jaclang.jac0core.constant { SymbolType }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.cli.console { console }
import from jaclang.jac0core.bccache { discover_base_file, discover_annex_files }
import from jaclang.compiler.type_system.type_utils { get_completion_items }
import from jaclang.compiler.type_system.types {
    ClassType,
    FunctionType,
    OverloadedType,
    ModuleType,
    TypeBase
}
import from jaclang.jac0core.unitree { UniScopeNode }
import from .sem_manager { SemTokManager }
import from jaclang.lsp { uris }
import from jaclang.lsp.server { LanguageServer }

import jaclang.lsp.types as lspt;
import from . { utils }
import from .module_manager { ModuleManager }
import from .rwlock { ReadWriteLock }

obj Task {
    has file_uri: str,
        task_id: int by postinit,
        cancel_token: threading.Event | None by postinit;

    static has _task_id: int = 0;

    def postinit -> None;
}

"""Jac Language Server, manages JacProgram and LSP."""
obj JacLangServer(JacProgram, LanguageServer) {
    has sem_managers: dict = {},
        module_manager: ModuleManager | None by postinit,
        # Task management
        pipe: deque = deque(maxlen=1),
        dirty_files: dict[str, bool] = {},
        last_task: Task | None = None,
        worker_future: Future | None by postinit,
        _state_lock: ReadWriteLock by postinit,
        _work_event: threading.Event = threading.Event(),
        _idle_event: threading.Event by postinit,
        _shutdown_called: bool = False,
        _debounce_timer: threading.Timer | None = None;

    def postinit -> None;
    def dispatcher -> None;
    @property
    def diagnostics -> dict[str, list];

    def _clear_alerts_for_file(file_path: str) -> None;
    def get_ir(file_path: str) -> Optional[uni.Module];
    def update_modules(file_path: str, build: uni.Module, need: bool = True) -> None;
    def type_check_file(
        file_uri: str, cancel_token: threading.Event | None = None
    ) -> bool;

    def type_check(file_uri: str) -> None;
    def _do_type_check(file_uri: str) -> None;
    """React to an external change at `file_uri`: drop the file's IR from
    `JacProgram` caches and queue a re-check for every open document that
    transitively imports it. Idempotent and safe to call from any LSP
    event handler. The owning file's own re-check is not queued here —
    callers normally pair this with `type_check(file_uri)` for that."""
    def _fanout_dependents(file_uri: str) -> None;

    def get_token_at_position(
        file_path: str, position: lspt.Position
    ) -> Optional[uni.UniNode];

    def debug(msg: str) -> None;
    def wait_till_idle_sync(file_uri: str) -> None;
    async def get_completion(
        file_uri: str, position: lspt.Position, completion_trigger: Optional[str]
    ) -> lspt.CompletionList;

    def get_ast_of_file(file_path: str) -> Optional[uni.UniNode];
    def get_node_at_position(
        file_path: str, line: int, col: int
    ) -> Optional[uni.UniNode];

    def get_completion_of_node(nd: uni.UniNode) -> lspt.CompletionList;
    def get_node_type(n: uni.UniNode) -> Optional[TypeBase];
    def get_completion_items_of(
        ty: TypeBase | uni.UniScopeNode
    ) -> lspt.CompletionList;

    def rename_module(old_path: str, new_path: str) -> None;
    def close_module(uri: str) -> None;
    def delete_module(uri: str) -> None;
    def format_document(
        file_path: str, auto_lint: bool = False
    ) -> list[lspt.TextEdit];

    def get_hover_info(
        file_path: str, position: lspt.Position
    ) -> Optional[lspt.Hover];

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
