"""LSP server infrastructure: LanguageServer, Workspace, TextDocument, PositionCodec."""

import asyncio;
import enum;
import io;
import json;
import logging;
import os;
import re;
import sys;
import threading;
import from typing { Any, Callable, Dict, List, Optional, Union }

import from .types {
    Position,
    Range,
    TextDocumentItem,
    VersionedTextDocumentIdentifier,
    TextDocumentContentChangeEvent_Type1,
    TextDocumentContentChangeEvent,
    DidOpenTextDocumentParams,
    DidChangeTextDocumentParams,
    DidCloseTextDocumentParams,
    PositionEncodingKind,
    TextDocumentSyncKind,
    TEXT_DOCUMENT_DID_OPEN,
    TEXT_DOCUMENT_DID_CHANGE,
    TEXT_DOCUMENT_DID_CLOSE,
    TEXT_DOCUMENT_PUBLISH_DIAGNOSTICS,
    WINDOW_SHOW_MESSAGE,
    WINDOW_LOG_MESSAGE,
    INITIALIZE,
    INITIALIZED,
    SHUTDOWN,
    EXIT,
    WORKSPACE_SEMANTIC_TOKENS_REFRESH,
    METHOD_TO_PARAMS
}
import from . { uris }

glob logger = logging.getLogger("jaclang.lsp.server"),
     RE_CONTENT_LENGTH = re.compile(r"Content-Length: (\d+)");

# ---------------------------------------------------------------------------
# Serialization helpers
# ---------------------------------------------------------------------------
def _to_camel_case(name: str) -> str;
def _to_snake_case(name: str) -> str;
def to_dict(`obj: Any) -> Any;
def from_dict(data: Any, cls: Any) -> Any;

# ---------------------------------------------------------------------------
# PositionCodec — UTF-16 ↔ UTF-32 position conversion
# ---------------------------------------------------------------------------
"""Converts between LSP client positions (UTF-16) and Python positions (UTF-32)."""
obj PositionCodec {
    has encoding: str = PositionEncodingKind.Utf16;

    def utf16_unit_offset(chars: str) -> int;
    def client_num_units(chars: str) -> int;
    def position_from_client_units(lines: list[str], position: Position) -> Position;
    def position_to_client_units(lines: list[str], position: Position) -> Position;
    def range_from_client_units(lines: list[str], range: Range) -> Range;
    def range_to_client_units(lines: list[str], range: Range) -> Range;
}

# ---------------------------------------------------------------------------
# TextDocument — in-memory document with incremental sync
# ---------------------------------------------------------------------------
"""A text document managed by the workspace."""
obj TextDocument {
    has uri: str = "",
        _source: Optional[str] = None,
        version: Optional[int] = None,
        path: str by postinit,
        _position_codec: PositionCodec by postinit;

    def postinit -> None;
    @property
    def source -> str;

    @property
    def lines -> list[str];

    def apply_change(change: Any) -> None;
    def _apply_incremental_change(
        change: TextDocumentContentChangeEvent_Type1
    ) -> None;

    def _apply_full_change(change: Any) -> None;
}

# ---------------------------------------------------------------------------
# Workspace — manages open text documents
# ---------------------------------------------------------------------------
"""Manages open documents and workspace folders."""
obj Workspace {
    has root_uri: Optional[str] = None,
        _sync_kind: TextDocumentSyncKind = TextDocumentSyncKind.Incremental,
        _text_documents: dict[str, TextDocument] = {},
        _root_path: Optional[str] by postinit,
        _position_codec: PositionCodec by postinit;

    def postinit -> None;
    def get_text_document(doc_uri: str) -> TextDocument;
    def put_text_document(text_document: TextDocumentItem) -> None;
    def update_text_document(
        text_doc: VersionedTextDocumentIdentifier, change: Any
    ) -> None;

    def remove_text_document(doc_uri: str) -> None;
}

# ---------------------------------------------------------------------------
# LanguageServer — the main LSP server
# ---------------------------------------------------------------------------
"""Base language server with feature registration, transport, and lifecycle."""
obj LanguageServer {
    has name: str = "",
        version: str = "",
        _features: dict[str, Callable] = {},
        _feature_options: dict[str, Any] = {},
        _workspace: Optional[Workspace] = None,
        _transport_writer: Optional[Any] = None,
        _write_lock: threading.Lock by postinit,
        _next_request_id: int = 0,
        _shutdown_flag: bool = False;

    def postinit -> None;
    @property
    def workspace -> Workspace;

    @property
    def lsp -> LanguageServer;

    def feature(method: str, options: Any = None) -> Callable;
    def start_io -> None;
    def publish_diagnostics(uri: str, diagnostics: list) -> None;
    def show_message(message: str, msg_type: Any = None) -> None;
    def show_message_log(message: str, msg_type: Any = None) -> None;
    def send_request(method: str, params: Any = None) -> None;
    def shutdown -> None;
    # Internal transport methods
    def _send_notification(method: str, params: Any) -> None;
    def _send_response(msg_id: Any, result: Any) -> None;
    def _write_message(body: dict) -> None;
    def _read_message(stream: Any) -> Optional[dict];
    def _dispatch(msg: dict) -> None;
    def _handle_initialize(params: dict) -> dict;
    def _build_capabilities -> dict;
}
