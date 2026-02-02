"""Main process engine for the Jac Language Server.

This is the scheduler/coordinator that owns the pygls LanguageServer,
manages the worker process, and implements priority-based scheduling.
It does NOT own JacProgram — that lives in the worker process.
"""

import asyncio;
import logging;
import os;
import sys;
import time;
import from multiprocessing { Process, Pipe, Event as MPEvent }
import from multiprocessing.connection { Connection }
import from typing { Optional }

import lsprotocol.types as lspt;

import from jaclang.vendor.pygls { uris }
import from jaclang.vendor.pygls.server { LanguageServer }

import from .protocol {
    make_compile_request,
    make_hover_request,
    make_definition_request,
    make_references_request,
    make_outline_request,
    make_semantic_tokens_request,
    make_completion_request,
    make_rename_request,
    make_format_request,
    make_delete_module_request,
    make_rename_module_request,
    make_shutdown_request,
    parse_hover_response,
    parse_definition_response,
    parse_references_response,
    parse_outline_response,
    parse_semantic_tokens_response,
    parse_completion_response,
    parse_rename_response,
    parse_format_response,
    parse_diagnostics_response
}

import from .worker { worker_main }

glob WORKER_STATE_IDLE = "IDLE",
     WORKER_STATE_COMPILING = "COMPILING",
     WORKER_STATE_SERVING_FG = "SERVING_FG",
     DEBOUNCE_DELAY = 0.3;



"""Jac Language Server — main process scheduler."""
obj JacLangServer(LanguageServer) {
    has main_conn: Connection | None by postinit,
        worker_process: Process | None by postinit,
        cancel_event: object | None by postinit,
        worker_state: str = WORKER_STATE_IDLE,
        compiling_file: str | None = None,
        dirty_files: dict = {},
        debounce_handle: object | None = None,
        _last_diagnostics: dict = {},
        _shutdown_called: bool = False;

    def postinit -> None;
    def shutdown -> None;

    # ── Priority scheduling ──────────────────────────────────────
    def schedule_compile(file_uri: str) -> None;
    def _fire_compile(file_uri: str) -> None;
    def _cancel_current -> dict | None;
    def _send_and_recv(request: dict) -> dict;
    def _on_compile_response(file_uri: str) -> None;
    def _schedule_next_dirty -> None;
    def _handle_compile_response(resp: dict, file_uri: str) -> None;

    # ── Foreground request dispatch ──────────────────────────────
    def send_fg_request(request: dict) -> dict;

    # ── Public API (same interface as old engine) ────────────────
    def type_check(file_uri: str) -> None;
    def type_check_file(
        file_uri: str,
        cancel_token: object | None = None,
        annex_view: Optional[str] = None
    ) -> bool;

    def get_hover_info(file_path: str, position: lspt.Position) -> Optional[lspt.Hover];
    def get_definition(
        file_path: str, position: lspt.Position
    ) -> Optional[lspt.Location];
    def get_references(file_path: str, position: lspt.Position) -> list[lspt.Location];
    def get_outline(file_path: str) -> list[lspt.DocumentSymbol];
    def get_semantic_tokens(file_path: str) -> lspt.SemanticTokens;
    async def get_completion(
        file_uri: str, position: lspt.Position, completion_trigger: Optional[str]
    ) -> lspt.CompletionList;
    def rename_symbol(
        file_path: str, position: lspt.Position, new_name: str
    ) -> Optional[lspt.WorkspaceEdit];
    def formatted_jac(file_path: str) -> list[lspt.TextEdit];

    # ── Module management ────────────────────────────────────────
    def delete_module(uri: str) -> None;
    def rename_module(old_path: str, new_path: str) -> None;

    # ── Idle wait (for tests) ────────────────────────────────────
    async def wait_till_idle -> None;
    def wait_till_idle_sync -> None;

    # ── Diagnostics cache (for test compatibility) ─────────────
    @property
    def diagnostics -> dict[str, list];
    def clear_type_system(clear_hub: bool = False) -> None;

    # ── Logging ──────────────────────────────────────────────────
    def debug(msg: str) -> None;
    def log_error(message: str) -> None;
    def log_warning(message: str) -> None;
    def log_info(message: str) -> None;
    def log_py(message: str) -> None;
}
