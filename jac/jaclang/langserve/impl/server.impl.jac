"""Run the language server - simplified architecture with direct worker access."""

import os;
import from . { configure_logging }
import from jaclang.vendor.pygls { uris }
import from jaclang.langserve { utils }

impl run_lang_server -> None {
    # Configure logging from environment or defaults
    log_level = os.environ.get("JAC_LSP_LOG_LEVEL", "INFO");
    log_file = os.environ.get("JAC_LSP_LOG_FILE", None);
    configure_logging(level=log_level, log_file=log_file);
    debug(f"Starting JacLang Language Server (log_level={log_level})");
    server = JacLangServer();
    # Register file event handlers
    server.feature(lspt.TEXT_DOCUMENT_DID_OPEN)(did_open);
    server.feature(lspt.TEXT_DOCUMENT_DID_SAVE)(did_save);
    server.feature(lspt.TEXT_DOCUMENT_DID_CHANGE)(did_change);
    server.feature(lspt.TEXT_DOCUMENT_DID_CLOSE)(did_close);
    server.feature(lspt.TEXT_DOCUMENT_FORMATTING)(formatting);
    server.feature(
        lspt.WORKSPACE_DID_CREATE_FILES,
        lspt.FileOperationRegistrationOptions(
            filters=[
                lspt.FileOperationFilter(pattern=lspt.FileOperationPattern('**/*.jac'))
            ]
        )
    )(
        did_create_files
    );
    server.feature(
        lspt.WORKSPACE_DID_RENAME_FILES,
        lspt.FileOperationRegistrationOptions(
            filters=[
                lspt.FileOperationFilter(pattern=lspt.FileOperationPattern('**/*.jac'))
            ]
        )
    )(
        did_rename_files
    );
    server.feature(
        lspt.WORKSPACE_DID_DELETE_FILES,
        lspt.FileOperationRegistrationOptions(
            filters=[
                lspt.FileOperationFilter(pattern=lspt.FileOperationPattern('**/*.jac'))
            ]
        )
    )(
        did_delete_files
    );
    server.feature(
        lspt.TEXT_DOCUMENT_COMPLETION,
        lspt.CompletionOptions(trigger_characters=['.', ':', 'a-zA-Z0-9'])
    )(
        completion
    );
    server.feature(
        lspt.TEXT_DOCUMENT_HOVER, lspt.HoverOptions(work_done_progress=True)
    )(
        hover
    );
    server.feature(lspt.TEXT_DOCUMENT_DOCUMENT_SYMBOL)(document_symbol);
    server.feature(lspt.TEXT_DOCUMENT_DEFINITION)(definition);
    server.feature(lspt.TEXT_DOCUMENT_REFERENCES)(references);
    server.feature(lspt.TEXT_DOCUMENT_RENAME)(rename);
    server.feature(
        lspt.TEXT_DOCUMENT_SEMANTIC_TOKENS_FULL,
        lspt.SemanticTokensLegend(
            token_types=SemTokType.as_str_list(),
            token_modifiers=SemTokMod.as_str_list()
        )
    )(
        semantic_tokens_full
    );
    server.start_io();
}

# ============== LSP Request Handlers (direct worker access) ==============
"""Provide definition - go to definition."""
impl definition(
    ls: JacLangServer, params: lspt.TextDocumentPositionParams
) -> Optional[lspt.Location] {
    debug(f"definition: {params.text_document.uri} at {params.position}");
    fs_path = uris.to_fs_path(params.text_document.uri);
    if ls._worker_manager and ls._worker_manager.is_running() {
        response = ls._worker_manager.request_definition(
            fs_path, params.position.line, params.position.character, timeout_ms=2000
        );
        return utils.response_to_location(response);
    }
    return None;
}

"""Provide hover information."""
impl hover(
    ls: JacLangServer, params: lspt.TextDocumentPositionParams
) -> Optional[lspt.Hover] {
    debug(f"hover: {params.text_document.uri} at {params.position}");
    fs_path = uris.to_fs_path(params.text_document.uri);
    if ls._worker_manager and ls._worker_manager.is_running() {
        response = ls._worker_manager.request_hover(
            fs_path, params.position.line, params.position.character, timeout_ms=2000
        );
        return utils.response_to_hover(response);
    }
    return None;
}

"""Provide references."""
impl references(ls: JacLangServer, params: lspt.ReferenceParams) -> list[lspt.Location] {
    debug(f"references: {params.text_document.uri} at {params.position}");
    fs_path = uris.to_fs_path(params.text_document.uri);
    if ls._worker_manager and ls._worker_manager.is_running() {
        response = ls._worker_manager.request_references(
            fs_path, params.position.line, params.position.character, timeout_ms=2000
        );
        return utils.response_to_locations(response);
    }
    return [];
}

"""Provide document symbols (outline)."""
impl document_symbol(
    ls: JacLangServer, params: lspt.DocumentSymbolParams
) -> list[lspt.DocumentSymbol] {
    debug(f"document_symbol: {params.text_document.uri}");
    fs_path = uris.to_fs_path(params.text_document.uri);
    if ls._worker_manager and ls._worker_manager.is_running() {
        response = ls._worker_manager.request_outline(fs_path, timeout_ms=2000);
        return utils.response_to_document_symbols(response);
    }
    return [];
}

"""Provide semantic tokens."""
impl semantic_tokens_full(
    ls: JacLangServer, params: lspt.SemanticTokensParams
) -> lspt.SemanticTokens {
    debug(f"semantic_tokens_full: {params.text_document.uri}");
    fs_path = uris.to_fs_path(params.text_document.uri);
    if ls._worker_manager and ls._worker_manager.is_running() {
        response = ls._worker_manager.request_semantic_tokens(fs_path, timeout_ms=2000);
        return utils.response_to_semantic_tokens(response);
    }
    return lspt.SemanticTokens(data=[]);
}

"""Rename symbol."""
impl rename(
    ls: JacLangServer, params: lspt.RenameParams
) -> Optional[lspt.WorkspaceEdit] {
    debug(
        f"rename: {params.text_document.uri} at {params.position} -> '{params.new_name}'"
    );
    ls.log_warning('Auto Rename is Experimental, Please use with caution.');
    fs_path = uris.to_fs_path(params.text_document.uri);
    if ls._worker_manager and ls._worker_manager.is_running() {
        response = ls._worker_manager.request_rename(
            fs_path,
            params.position.line,
            params.position.character,
            params.new_name,
            timeout_ms=3000
        );
        return utils.response_to_workspace_edit(response, params.new_name);
    }
    return None;
}

"""Provide completion."""
impl completion(
    ls: JacLangServer, params: lspt.CompletionParams
) -> lspt.CompletionList {
    trigger = params.context.trigger_character if params.context else None;
    debug(
        f"completion: {params.text_document.uri} at {params.position} (trigger='{trigger}')"
    );
    fs_path = uris.to_fs_path(params.text_document.uri);
    if ls._worker_manager and ls._worker_manager.is_running() {
        response = ls._worker_manager.request_completion(
            fs_path,
            params.position.line,
            params.position.character,
            trigger,
            timeout_ms=2000
        );
        return utils.response_to_completion_list(response);
    }
    return lspt.CompletionList(is_incomplete=False, items=[]);
}

"""Format the given document."""
impl formatting(
    ls: JacLangServer, params: lspt.DocumentFormattingParams
) -> list[lspt.TextEdit] {
    debug(f"formatting: {params.text_document.uri}");
    try {
        document = ls.workspace.get_text_document(params.text_document.uri);
        fs_path = uris.to_fs_path(params.text_document.uri);
        if ls._worker_manager and ls._worker_manager.is_running() {
            response = ls._worker_manager.request_format(
                fs_path, document.source, timeout_ms=5000
            );
            return utils.response_to_text_edits(response, document.source);
        }
        return [];
    } except Exception {
        return [];
    }
}

# ============== File Event Handlers ==============
"""Check syntax on file delete."""
impl did_delete_files(ls: JacLangServer, params: lspt.DeleteFilesParams) -> None {
    debug(f"did_delete_files: {len(params.files)} files");
    for file in params.files {
        debug(f"  Deleting: {file.uri}");
        ls.delete_module(file.uri);
    }
}

"""Check syntax on file rename."""
impl did_rename_files(ls: JacLangServer, params: lspt.RenameFilesParams) -> None {
    debug(f"did_rename_files: {len(params.files)} files");
    new_uris = [file.new_uri for file in params.files];
    old_uris = [file.old_uri for file in params.files];
    for i in range(len(new_uris)) {
        debug(f"  Renaming: {old_uris[i]} -> {new_uris[i]}");
        ls.rename_module(old_uris[i], new_uris[i]);
    }
}

impl debug(msg: str) -> None {
    print(f"[SERVER] {msg}", file=sys.stderr);
}
