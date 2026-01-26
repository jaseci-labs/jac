"""Living Workspace of Jac project.

Production-grade LSP server with multiprocess architecture for bypassing
Python's GIL during type checking. Uses immutable snapshots for lock-free
foreground queries and a dedicated worker process for background analysis.

Architecture:
- Main Process: LSP handlers, scheduler, query dispatch
- Worker Process: Compilation, type checking (CPU-bound)
- IPC: multiprocessing.Queue for request/response
- Sync: Immutable snapshots + atomic swap (no locking for reads)
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
import from .scheduler { AnalysisScheduler, SchedulerConfig }
import from .snapshot { SnapshotManager, ProgramSnapshot }
import from .sync { LockManager }
import from .cancellation { CancellationToken, CancellationTokenSource }

"""Jac Language Server, manages JacProgram and LSP.

Uses a multiprocess architecture with:
- Scheduler: Manages analysis priority queue with user-activity backoff
- Worker: Separate process for CPU-bound compilation
- Snapshots: Immutable state for lock-free foreground queries
"""
obj JacLangServer(JacProgram, LanguageServer) {
    has sem_managers: dict = {},
        module_manager: ModuleManager | None = None,
        _shutdown_called: bool = False,
        # Scheduler-based analysis
        _scheduler: AnalysisScheduler | None = None,
        _snapshot_manager: SnapshotManager | None = None,
        # Lock manager for thread-safe state updates
        _lock_manager: LockManager | None = None,
        # LSP request tracking for cancellation
        _pending_requests: Dict[str, CancellationTokenSource] | None = None,
        _pending_requests_lock: threading.Lock | None = None,
        # Logger
        _logger: logging.Logger | None = None;

    def postinit -> None;

    @property
    def diagnostics -> dict[str, list];

    def _clear_alerts_for_file(file_path: str) -> None;
    def get_ir(file_path: str) -> Optional[uni.Module];
    def update_modules(file_path: str, build: uni.Module, need: bool = True) -> None;

    """Request type checking for a file.

    This schedules analysis via the scheduler, which dispatches to the
    worker process. Compilation does NOT happen in the main process.
    """
    def type_check(file_uri: str) -> None;

    """Synchronous type check for testing.

    Schedules analysis and waits for completion. This is a blocking call
    that should only be used in tests, not in production LSP handlers.
    """ 
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

    # Scheduler integration methods
    """Schedule a file for analysis."""
    def schedule_analysis(file_uri: str, source: str) -> None;

    """Mark a file as opened in editor."""
    def on_file_opened(file_uri: str) -> None;

    """Mark a file as closed in editor."""
    def on_file_closed(file_uri: str) -> None;

    """Mark a file as focused (for priority)."""
    def on_file_focused(file_uri: str) -> None;

    """Handle diagnostics from scheduler."""
    def _on_scheduler_diagnostics(snapshot: ProgramSnapshot) -> None;

    """Sync snapshot data to main process state."""
    def _sync_snapshot_to_state(snapshot: ProgramSnapshot) -> None;

    # LSP Request cancellation support
    """Register a pending LSP request for cancellation tracking."""
    def register_request(request_id: str) -> CancellationToken;

    """Unregister a completed LSP request."""
    def unregister_request(request_id: str) -> None;

    """Cancel a pending LSP request."""
    def cancel_request(request_id: str) -> None;

    """Get current snapshot for queries (non-blocking)."""
    def get_current_snapshot -> Optional[ProgramSnapshot];
}
