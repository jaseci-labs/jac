import logging;
import os;
import time;
import threading;
import from collections { deque }
import from concurrent.futures { Future }
import from typing { Optional }

import from jaclang.lsp.protocol { uris }

import from . { utils }

def _uri_of(path: str) -> str;
def _path_of(uri: str) -> str;

obj Task {
    has file_uri: str,
        task_id: int postinit,
        cancel_token: CancelToken postinit;

    static has _task_id: int = 0;

    def postinit -> None;
}

obj JacLangServer(LanguageServer) {
    has session: (SessionClient | None) = None,
        kernel_diagnostics: dict[str, list[KernelDiagnostic]] = {},
        last_error: str = "",
        pipe: deque = deque(maxlen=1),
        dirty_files: dict[str, bool] = {},
        last_task: Task | None = None,
        worker_future: Future | None postinit,
        _synced: dict[str, str] = {},
        _state_lock: ReadWriteLock postinit,
        _work_event: threading.Event = threading.Event(),
        _idle_event: threading.Event postinit,
        _shutdown_called: bool = False,
        _debounce_timer: threading.Timer | None = None;

    def postinit -> None;
    def client -> SessionClient;
    def dispatcher -> None;

    has diagnostics: dict[str, list[lspt.Diagnostic]] { getter; }

    def _open_documents -> dict[str, str];
    def _sync_document(path: str) -> None;
    def _unit_files(path: str) -> list[str];
    def type_check_file(
        file_uri: str, cancel_token: (CancelToken | None) = None
    ) -> bool;

    def type_check(file_uri: str) -> None;
    def _do_type_check(file_uri: str) -> None;
    def _fanout_dependents(file_uri: str) -> None;
    def debug(msg: str) -> None;
    def wait_till_idle_sync(file_uri: str) -> None;
    async def get_completion(
        file_uri: str, position: lspt.Position, completion_trigger: Optional[str]
    ) -> lspt.CompletionList;

    def _flush_completion_state(file_uri: str) -> None;
    def rename_module(old_uri: str, new_uri: str) -> None;
    def close_module(uri: str) -> None;
    def delete_module(uri: str) -> None;
    def format_document(
        file_path: str, auto_lint: bool = False
    ) -> list[lspt.TextEdit];

    def get_inlay_hints(file_path: str, range: lspt.Range) -> list[lspt.InlayHint];
    def get_hover_info(
        file_path: str, position: lspt.Position
    ) -> Optional[lspt.Hover];

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
