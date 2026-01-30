"""Jac Language Server.

Single worker process architecture:
- Main Process: LSP handlers, response polling
- Worker Process: Compilation with debounce, foreground LSP requests
- IPC: multiprocessing.Queue (lightweight diagnostics only)
"""

import asyncio;
import logging;
import sys;

import from jaclang.pycore.program { JacProgram }
import from jaclang.vendor.pygls { uris }
import from jaclang.vendor.pygls.server { LanguageServer }

import lsprotocol.types as lspt;
import from . { utils }
import from .module_manager { ModuleManager }
import from .worker { WorkerManager, WorkerConfig }

with entry {
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
    def log_info(message: str) -> None;
    def log_warning(message: str) -> None;
    def log_error(message: str) -> None;
    # Analysis scheduling
    def schedule_analysis(file_uri: str) -> None;
    # File events
    def on_file_opened(file_uri: str) -> None;
    # Worker diagnostics
    def _on_worker_diagnostics(response: dict) -> None;
    # Response polling
    def start_response_polling -> None;
    def stop_response_polling -> None;
    async def _response_polling_loop -> None;
    # Module management
    def delete_module(uri: str) -> None;
    def rename_module(old_path: str, new_path: str) -> None;
    # LSP request handlers
    def get_definition(
        file_path: str, line: int, character: int
    ) -> lspt.Location | None;

    def get_hover(file_path: str, line: int, character: int) -> lspt.Hover | None;
    def get_references(
        file_path: str, line: int, character: int
    ) -> list[lspt.Location];

    def get_document_symbols(file_path: str) -> list[lspt.DocumentSymbol];
    def get_semantic_tokens(file_path: str) -> lspt.SemanticTokens;
    def get_rename(
        file_path: str, line: int, character: int, new_name: str
    ) -> lspt.WorkspaceEdit | None;

    def get_completion(
        file_path: str, line: int, character: int, trigger: str | None
    ) -> lspt.CompletionList;

    def format_document(file_path: str, source: str) -> list[lspt.TextEdit];
}
