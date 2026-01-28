"""Jac Language Server.

Single worker process architecture:
- Main Process: LSP handlers, response polling
- Worker Process: Compilation with debounce, foreground LSP requests
- IPC: multiprocessing.Queue (lightweight diagnostics only)
"""

import asyncio;
import logging;
import os;
import sys;
import time;
import threading;
import from typing { Callable, Optional, Dict }

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
import from .worker { WorkerManager, WorkerConfig }

with entry{
    logging.getLogger().setLevel(logging.CRITICAL);
}

"""Jac Language Server with single worker process architecture."""
obj JacLangServer(JacProgram, LanguageServer) {
    has sem_managers: dict = {},
        module_manager: ModuleManager | None = None,
        _shutdown_called: bool = False,
        # Worker-based analysis
        _worker_manager: WorkerManager | None = None,
        # Logger
        _logger: logging.Logger | None = None,
        # Async response polling task
        _polling_task: asyncio.Task | None = None,
        _polling_interval_ms: float = 50;

    def postinit -> None;

    @property
    def diagnostics -> dict[str, list];

    def _clear_alerts_for_file(file_path: str) -> None;
    def get_ir(file_path: str) -> Optional[uni.Module];
    def update_modules(file_path: str, build: uni.Module, need: bool = True) -> None;

    """Request type checking for a file."""
    def type_check(file_uri: str) -> None;

    """Synchronous type check for testing."""
    def type_check_file(file_uri: str) -> bool;

    def get_token_at_position(
        file_path: str, position: lspt.Position
    ) -> Optional[uni.AstNode];

    def debug(msg: str) -> None;

    """Wait for all pending analysis to complete."""
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
    def _convert_outline_dict_to_lsp(symbols_data: list) -> list[lspt.DocumentSymbol];
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

    """Schedule a file for analysis. Worker reads source from disk."""
    def schedule_analysis(file_uri: str) -> None;

    """Mark a file as opened in editor."""
    def on_file_opened(file_uri: str) -> None;

    """Mark a file as closed in editor."""
    def on_file_closed(file_uri: str) -> None;

    """Mark a file as focused."""
    def on_file_focused(file_uri: str) -> None;

    """Handle diagnostics from worker."""
    def _on_worker_diagnostics(response: dict) -> None;

    # Async response polling
    """Start the async response polling task."""
    def start_response_polling -> None;

    """Stop the async response polling task."""
    def stop_response_polling -> None;

    """Async loop that polls worker responses."""
    async def _response_polling_loop -> None;
}
