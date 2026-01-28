"""Jac Language Server.

Single worker process architecture:
- Main Process: LSP handlers, response polling
- Worker Process: Compilation with debounce, foreground LSP requests
- IPC: multiprocessing.Queue (lightweight diagnostics only)
"""

import asyncio;
import logging;
import sys;
import time;
import from typing { Optional }

import jaclang.pycore.unitree as uni;
import from jaclang.pycore.program { JacProgram }
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
        _worker_manager: WorkerManager | None = None,
        _logger: logging.Logger | None = None,
        _polling_task: asyncio.Task | None = None,
        _polling_interval_ms: float = 50;

    def postinit -> None;
    def shutdown -> None;

    # Logging
    def debug(msg: str) -> None;
    def log_py(message: str) -> None;
    def log_info(message: str) -> None;
    def log_warning(message: str) -> None;
    def log_error(message: str) -> None;

    # Analysis scheduling
    def schedule_analysis(file_uri: str) -> None;
    def type_check(file_uri: str) -> None;
    def type_check_file(file_uri: str) -> bool;
    async def wait_till_idle -> None;
    def wait_till_idle_sync -> None;

    # File events
    def on_file_opened(file_uri: str) -> None;
    def on_file_closed(file_uri: str) -> None;
    def on_file_focused(file_uri: str) -> None;

    # Worker diagnostics
    def _on_worker_diagnostics(response: dict) -> None;

    # Response polling
    def start_response_polling -> None;
    def stop_response_polling -> None;
    async def _response_polling_loop -> None;

    # LSP features (forward to worker)
    def get_semantic_tokens(file_path: str) -> lspt.SemanticTokens;
    async def get_completion(file_uri: str, position: lspt.Position, completion_trigger: Optional[str]) -> lspt.CompletionList;
    def get_hover_info(file_path: str, position: lspt.Position) -> Optional[lspt.Hover];
    def get_definition(file_path: str, position: lspt.Position) -> Optional[lspt.Location];
    def get_references(file_path: str, position: lspt.Position) -> list[lspt.Location];
    def rename_symbol(file_path: str, position: lspt.Position, new_name: str) -> Optional[lspt.WorkspaceEdit];
    def get_outline(file_path: str) -> list[lspt.DocumentSymbol];
    def _convert_outline_dict_to_lsp(symbols_data: list) -> list[lspt.DocumentSymbol];
    def formatted_jac(file_path: str) -> list[lspt.TextEdit];

    # Module management
    def delete_module(uri: str) -> None;
    def rename_module(old_path: str, new_path: str) -> None;
}
