import logging;
import os;
import threading;
import from typing { Optional }

import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.constant { SymbolType }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.passes.transform { Alert }
import from jaclang.compiler.driver.bccache { discover_base_file }
import from jaclang.lsp.server.utils { doc_of_sym, get_completion_items }
import from jaclang.compiler.types.types {
    ClassType,
    FunctionType,
    OverloadedType,
    ModuleType,
    TypeBase
}
import from jaclang.compiler.frontend.constant { TOKEN_MAP }
import from jaclang.compiler.frontend.unitree { UniScopeNode }
import from .sem_manager { SemTokManager }
import from jaclang.lsp.protocol { uris }
import from jaclang.lsp.protocol.server {
    LanguageServer,
    Request,
    ResponseErrorCode,
    WorkspaceSnapshot
}

import jaclang.lsp.protocol.types as lspt;
import from . { utils }
import from .module_manager { ModuleManager }
import from .scheduler { WorkQueue, WorkItem, WorkKind }

glob LSP_SHARED_APP_LIMIT: int = 4;

def _uri_of(path: str) -> str;
def _path_of(uri: str) -> str;
obj AppDiagnostics {
    has app: str,
        errors: list[Alert],
        warnings: list[Alert];
}

def _merge_app_alerts(
    collected: list[AppDiagnostics]
) -> tuple[list[Alert], list[Alert]];

obj JacLangServer(LanguageServer) {
    has program: JacProgram postinit,
        sem_managers: dict[str, SemTokManager] = {},
        module_manager: ModuleManager postinit,
        work: WorkQueue postinit,
        worker: threading.Thread postinit,
        _compiler_lock: threading.RLock postinit,
        _shutdown_called: bool = False,
        _dep_edges_seeded: bool = False,
        _published_diagnostics: dict[str, list[lspt.Diagnostic]] = {};

    def postinit -> None;
    def dispatcher -> None;

    has diagnostics: dict[str, list[lspt.Diagnostic]] { getter; }

    def _clear_alerts_for_file(file_path: str) -> None;
    def update_modules(
        file_path: str,
        build: uni.Module,
        need: bool = True,
        files: (list[str] | None) = None
    ) -> None;

    def type_check_file(
        file_uri: str,
        cancel_token: threading.Event | None = None,
        symbols_only: bool = False
    ) -> bool;

    def type_check(file_uri: str) -> None;
    def submit_request(request: Request) -> None;
    def _sync_sources(snapshot: WorkspaceSnapshot) -> None;
    def _ensure_query(request: Request) -> None;
    def _release_document(uri: str, deleted: bool = False) -> None;
    def get_token_at_position(
        file_path: str, position: lspt.Position
    ) -> Optional[uni.AstSymbolNode];

    def wait_till_idle_sync(file_uri: str) -> None;
    def get_completion(
        file_uri: str, position: lspt.Position, completion_trigger: Optional[str]
    ) -> lspt.CompletionList;

    def get_ast_of_file(file_path: str) -> Optional[uni.UniNode];
    def get_node_at_position(
        file_path: str, line: int, col: int
    ) -> Optional[uni.UniNode];

    def get_completion_of_node(nd: uni.UniNode) -> lspt.CompletionList;
    def get_node_type(n: uni.UniNode) -> Optional[TypeBase];
    def get_completion_items_of(
        ty: TypeBase | uni.UniScopeNode
    ) -> lspt.CompletionList;

    def get_scope_completion(scope: uni.UniScopeNode) -> lspt.CompletionList;
    def get_scope_at_position(
        file_path: str, line: int, col: int
    ) -> Optional[uni.UniScopeNode];

    def _position_in_string_or_comment(file_uri: str, line: int, col: int) -> bool;
    def rename_module(old_path: str, new_path: str) -> None;
    def close_module(uri: str) -> None;
    def delete_module(uri: str) -> None;
    def format_document(
        file_path: str, auto_lint: bool = False
    ) -> list[lspt.TextEdit];

    def get_inlay_hints(file_path: str, range: lspt.Range) -> list[lspt.InlayHint];
    def get_hover_info(
        file_path: str, position: lspt.Position
    ) -> Optional[lspt.Hover];

    def get_node_info(sym_node: uni.AstSymbolNode) -> Optional[str];
    def get_outline(file_path: str) -> list[lspt.DocumentSymbol];
    def get_definition(
        file_path: str, position: lspt.Position
    ) -> Optional[lspt.Location];

    def _string_import_definition(
        file_path: str, position: lspt.Position
    ) -> Optional[lspt.Location];

    def _module_spec_target(mp: uni.ModulePath) -> Optional[str];
    def _npm_item_location(
        from_loc: uni.ModulePath, item_name: str
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
