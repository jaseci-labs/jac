"""Run the language server - thin routing layer.

All LSP request logic lives in JacLangServer (engine).
This module registers handlers and delegates to engine methods.
"""

import os;
import from . { configure_logging }
import from jaclang.vendor.pygls { uris }

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
    server.feature(lspt.TEXT_DOCUMENT_FORMATTING)(formatting);
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

# ============== LSP Request Handlers (thin wrappers) ==============
impl definition(
    ls: JacLangServer, params: lspt.TextDocumentPositionParams
) -> Optional[lspt.Location] {
    return ls.get_definition(
        uris.to_fs_path(params.text_document.uri),
        params.position.line,
        params.position.character
    );
}

impl hover(
    ls: JacLangServer, params: lspt.TextDocumentPositionParams
) -> Optional[lspt.Hover] {
    return ls.get_hover(
        uris.to_fs_path(params.text_document.uri),
        params.position.line,
        params.position.character
    );
}

impl references(ls: JacLangServer, params: lspt.ReferenceParams) -> list[lspt.Location] {
    return ls.get_references(
        uris.to_fs_path(params.text_document.uri),
        params.position.line,
        params.position.character
    );
}

impl document_symbol(
    ls: JacLangServer, params: lspt.DocumentSymbolParams
) -> list[lspt.DocumentSymbol] {
    return ls.get_document_symbols(uris.to_fs_path(params.text_document.uri));
}

impl semantic_tokens_full(
    ls: JacLangServer, params: lspt.SemanticTokensParams
) -> lspt.SemanticTokens {
    return ls.get_semantic_tokens(uris.to_fs_path(params.text_document.uri));
}

impl rename(
    ls: JacLangServer, params: lspt.RenameParams
) -> Optional[lspt.WorkspaceEdit] {
    return ls.get_rename(
        uris.to_fs_path(params.text_document.uri),
        params.position.line,
        params.position.character,
        params.new_name
    );
}

impl completion(
    ls: JacLangServer, params: lspt.CompletionParams
) -> lspt.CompletionList {
    trigger = params.context.trigger_character if params.context else None;
    return ls.get_completion(
        uris.to_fs_path(params.text_document.uri),
        params.position.line,
        params.position.character,
        trigger
    );
}

impl formatting(
    ls: JacLangServer, params: lspt.DocumentFormattingParams
) -> list[lspt.TextEdit] {
    document = ls.workspace.get_text_document(params.text_document.uri);
    return ls.format_document(
        uris.to_fs_path(params.text_document.uri), document.source
    );
}

# ============== File Event Handlers ==============
impl did_delete_files(
    ls: JacLangServer, params: lspt.DeleteFilesParams
) -> None {
    for file in params.files {
        ls.delete_module(file.uri);
    }
}

impl did_rename_files(ls: JacLangServer, params: lspt.RenameFilesParams) -> None {
    for file in params.files {
        ls.rename_module(file.old_uri, file.new_uri);
    }
}

impl debug(msg: str) -> None {
    print(f"[SERVER] {msg}", file=sys.stderr);
}
