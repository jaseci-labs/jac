"""IPC Protocol for LSP main process ↔ worker process communication.

Messages are plain dicts sent over multiprocessing.Pipe for pickle safety.
This module provides helpers to build request/response dicts and convert
worker responses back into LSP types.
"""

import from typing { Optional }

import lsprotocol.types as lspt;

# ── Request builders (main → worker) ─────────────────────────────────

def make_compile_request(file_path: str, source: str) -> dict;
def make_hover_request(file_path: str, line: int, character: int) -> dict;
def make_definition_request(file_path: str, line: int, character: int) -> dict;
def make_references_request(file_path: str, line: int, character: int) -> dict;
def make_outline_request(file_path: str) -> dict;
def make_semantic_tokens_request(file_path: str) -> dict;
def make_completion_request(
    file_path: str, line: int, character: int, trigger: Optional[str]
) -> dict;
def make_rename_request(
    file_path: str, line: int, character: int, new_name: str
) -> dict;
def make_format_request(file_path: str, source: str) -> dict;
def make_delete_module_request(file_path: str) -> dict;
def make_rename_module_request(old_path: str, new_path: str) -> dict;
def make_shutdown_request -> dict;

# ── Response parsers (worker → main) → LSP types ─────────────────────

def parse_hover_response(resp: dict) -> Optional[lspt.Hover];
def parse_definition_response(resp: dict) -> Optional[lspt.Location];
def parse_references_response(resp: dict) -> list[lspt.Location];
def parse_outline_response(resp: dict) -> list[lspt.DocumentSymbol];
def parse_semantic_tokens_response(resp: dict) -> lspt.SemanticTokens;
def parse_completion_response(resp: dict) -> lspt.CompletionList;
def parse_rename_response(resp: dict) -> Optional[lspt.WorkspaceEdit];
def parse_format_response(resp: dict) -> list[lspt.TextEdit];
def parse_diagnostics_response(resp: dict) -> dict[str, list[lspt.Diagnostic]];
