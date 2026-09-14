import enum;
import io;
import json;
import logging;
import os;
import re;
import sys;
import threading;
import from contextlib { contextmanager }
import from contextvars { ContextVar }
import from concurrent.futures { ThreadPoolExecutor }
import from typing { Optional, Union }

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
    Diagnostic,
    TEXT_DOCUMENT_PUBLISH_DIAGNOSTICS,
    TEXT_DOCUMENT_SEMANTIC_TOKENS_FULL,
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

glob logger = logging.getLogger("jaclang.lsp.protocol.server"),
     RE_CONTENT_LENGTH = re.compile(r"Content-Length: (\d+)");

def _to_camel_case(name: str) -> str;
def _to_snake_case(name: str) -> str;
def to_dict(`obj: any) -> any;
def encode_message(body: dict) -> bytes;
def from_dict(data: any, cls: any) -> any;

enum ResponseErrorCode {
    InvalidRequest = -32600,
    MethodNotFound = -32601,
    InternalError = -32603,
    RequestCancelled = -32800,
    ContentModified = -32801,
    ServerCancelled = -32802
}

obj Request {
    has message_id: int | str,
        method: str,
        params: any,
        revision: int,
        cancel_token: threading.Event postinit,
        snapshot: WorkspaceSnapshot | None = None,
        inputs_current: Callable[[], bool] | None = None,
        responded: bool = False;

    def postinit {
        self.cancel_token = threading.Event();
    }

    def is_current(workspace: Workspace) -> bool {
        return self.inputs_current() if self.inputs_current is not None
            else self.revision == workspace.revision;
    }
}

obj PositionCodec {
    has encoding: PositionEncodingKind = PositionEncodingKind.Utf16;

    def utf16_unit_offset(chars: str) -> int;
    def client_num_units(chars: str) -> int;
    def position_from_client_units(lines: list[str], position: Position) -> Position;
    def position_to_client_units(lines: list[str], position: Position) -> Position;
    def range_from_client_units(lines: list[str], range: Range) -> Range;
}

obj TextDocument {
    has uri: str = "",
        _source: Optional[str] = None,
        version: Optional[int] = None,
        path: str postinit,
        _position_codec: PositionCodec postinit;

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
        _root_path: Optional[str] postinit,
        _position_codec: PositionCodec postinit,
        _view: ContextVar[WorkspaceView | None] postinit,
        lock: threading.RLock postinit,
        revision: int = 0;

    def convert_positions(value: any, uri: str = '', to_client: bool = True) -> any;
    def encode_semantic_tokens(uri: str, data: list[int]) -> list[int];
    def postinit -> None;
    def get_text_document(doc_uri: str) -> TextDocument;
    def put_text_document(text_document: TextDocumentItem) -> None;
    def update_text_document(
        text_doc: VersionedTextDocumentIdentifier, change: any
    ) -> None;

    def remove_text_document(doc_uri: str) -> None;
    def rename_text_document(old_uri: str, new_uri: str) -> None;
    def touch -> None;
    def snapshot(live: bool = False) -> WorkspaceSnapshot;
    @contextmanager
    def read_scope(
        snapshot: WorkspaceSnapshot, reader: Callable[[str], str]
    ) -> Iterator[None] {
        token = self._view.set(WorkspaceView(snapshot, reader));
        try {
            yield ;
        } finally {
            self._view.reset(token);
        }
    }
    def change_text_document(params: DidChangeTextDocumentParams) -> None;
}

obj WorkspaceView {
    has snapshot: WorkspaceSnapshot,
        reader: Callable[[str], str];
}

obj WorkspaceSnapshot {
    has revision: int,
        documents: dict[str, TextDocument];

    def sources -> dict[str, str] {
        return {
            os.path.realpath(doc.path): doc.source for doc in self.documents.values()
        };
    }
}

obj LanguageServer {
    has name: str = "",
        version: str = "",
        _features: dict[str, Callable[[any, any], any]] = {},
        _feature_options: dict[str, any] = {},
        _workspace: Optional[Workspace] = None,
        _transport_writer: Optional[any] = None,
        _write_lock: threading.Lock postinit,
        _next_request_id: int = 0,
        _shutdown_flag: bool = False,
        _requests: dict[int | str, Request] = {},
        _request_lock: threading.RLock postinit,
        watch_patterns: list[str] = [],
        _dynamic_file_watching: bool = False,
        _request_executor: ThreadPoolExecutor | None = None;

    def postinit -> None;

    has workspace: Workspace { getter; }
    has lsp: LanguageServer { getter; }

    def feature(method: str, options: any = None) -> Callable;
    def start_io -> None;
    def publish_diagnostics(
        uri: str, diagnostics: list[Diagnostic], version: int | None = None
    ) -> None;

    def submit_request(request: Request) -> None;
    def _run_request(request: Request) -> None;
    def _finish_request(
        request: Request,
        result: any = None,
        error: ResponseErrorCode | None = None,
        message: str = ''
    ) -> None;

    def _cancel_request(message_id: int | str) -> None;
    def _invoke_handler(method: str, params: any) -> any;
    def show_message(message: str, msg_type: any = None) -> None;
    def show_message_log(message: str, msg_type: any = None) -> None;
    def send_request(method: str, params: any = None) -> None;
    def shutdown -> None;
    def _send_notification(method: str, params: any) -> None;
    def _send_response(msg_id: any, result: any) -> None;
    def _write_content(content: bytes) -> None;
    def _write_message(body: dict[str, any]) -> None;
    def _read_message(stream: any) -> Optional[dict[str, any]];
    def _handle_initialize(params: dict[str, any]) -> dict[str, any];
    def _build_capabilities -> dict[str, any];
}
