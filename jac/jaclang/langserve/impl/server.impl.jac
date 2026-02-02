import from jaclang.cli.console { console }

"""Run the language server."""
impl run_lang_server -> None {
    server = JacLangServer();
    # Register all features
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

"""Provide semantic tokens."""
impl semantic_tokens_full(
    ls: JacLangServer, params: lspt.SemanticTokensParams
) -> lspt.SemanticTokens {
    return ls.get_semantic_tokens(params.text_document.uri);
}

"""Rename symbol."""
impl rename(
    ls: JacLangServer, params: lspt.RenameParams
) -> Optional[lspt.WorkspaceEdit] {
    ls.log_warning('Auto Rename is Experimental, Please use with caution.');
    return ls.rename_symbol(params.text_document.uri, params.position, params.new_name);
}

"""Provide references."""
impl references(ls: JacLangServer, params: lspt.ReferenceParams) -> list[lspt.Location] {
    return ls.get_references(params.text_document.uri, params.position);
}

"""Provide definition."""
impl definition(
    ls: JacLangServer, params: lspt.TextDocumentPositionParams
) -> Optional[lspt.Location] {
    return ls.get_definition(params.text_document.uri, params.position);
}

"""Provide document symbols."""
impl document_symbol(
    ls: JacLangServer, params: lspt.DocumentSymbolParams
) -> list[lspt.DocumentSymbol] {
    return ls.get_outline(params.text_document.uri);
}

"""Provide hover information for the given hover request."""
impl hover(
    ls: JacLangServer, params: lspt.TextDocumentPositionParams
) -> Optional[lspt.Hover] {
    return ls.get_hover_info(params.text_document.uri, params.position);
}

"""Clean up resources when a document is closed."""
impl did_close(ls: JacLangServer, params: lspt.DidCloseTextDocumentParams) -> None {
    ls.close_module(params.text_document.uri);
}

"""Check syntax on file delete."""
impl did_delete_files(ls: JacLangServer, params: lspt.DeleteFilesParams) -> None {
    for file in params.files {
        ls.delete_module(file.uri);
    }
}

"""Check syntax on file rename."""
impl did_rename_files(ls: JacLangServer, params: lspt.RenameFilesParams) -> None {
    new_uris = [file.new_uri for file in params.files];
    old_uris = [file.old_uri for file in params.files];
    for i in range(len(new_uris)) {
        ls.rename_module(old_uris[i], new_uris[i]);
    }
}

"""Format the given document."""
impl formatting(
    ls: JacLangServer, params: lspt.DocumentFormattingParams
) -> list[lspt.TextEdit] {
    return ls.formatted_jac(params.text_document.uri);
}

impl debug(msg: str) -> None {
    console.error(f"[SERVER] {msg}");
}
