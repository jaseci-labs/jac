import asyncio;
import enum;
import io;
import json;
import logging;
import os;
import re;
import sys;
import threading;
import from typing { Callable, Dict, List, Optional, Union }

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

def _to_camel_case(name: str) -> str;
def _to_snake_case(name: str) -> str;
def to_dict(`obj: any) -> any;
def from_dict(data: any, cls: any) -> any;

obj PositionCodec {
    has encoding: str = PositionEncodingKind.Utf16;

    def utf16_unit_offset(chars: str) -> int;
    def client_num_units(chars: str) -> int;
    def position_from_client_units(lines: list[str], position: Position) -> Position;
    def range_from_client_units(lines: list[str], range: Range) -> Range;
}

obj TextDocument {
    has uri: str = "",
        _source: Optional[str] = None,
        version: Optional[int] = None,
        path: str by postinit,
        _position_codec: PositionCodec by postinit;

    def postinit -> None;

    has source: str { getter; }
    has lines: list[str] { getter; }

    def apply_change(change: any) -> None;
    def _apply_incremental_change(
        change: TextDocumentContentChangeEvent_Type1
    ) -> None;

    def _apply_full_change(change: any) -> None;
}

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
        text_doc: VersionedTextDocumentIdentifier, change: any
    ) -> None;

    def remove_text_document(doc_uri: str) -> None;
}

obj LanguageServer {
    has name: str = "",
        version: str = "",
        _features: dict[str, Callable] = {},
        _feature_options: dict[str, any] = {},
        _workspace: Optional[Workspace] = None,
        _transport_writer: Optional[any] = None,
        _write_lock: threading.Lock by postinit,
        _next_request_id: int = 0,
        _shutdown_flag: bool = False;

    def postinit -> None;

    has workspace: Workspace { getter; }
    has lsp: LanguageServer { getter; }

    def feature(method: str, options: any = None) -> Callable;
    def start_io -> None;
    def publish_diagnostics(uri: str, diagnostics: list) -> None;
    def show_message(message: str, msg_type: any = None) -> None;
    def show_message_log(message: str, msg_type: any = None) -> None;
    def send_request(method: str, params: any = None) -> None;
    def shutdown -> None;
    def _send_notification(method: str, params: any) -> None;
    def _send_response(msg_id: any, result: any) -> None;
    def _write_message(body: dict) -> None;
    def _read_message(stream: any) -> Optional[dict];
    def _handle_initialize(params: dict) -> dict;
    def _build_capabilities -> dict;
}
