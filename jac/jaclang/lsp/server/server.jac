import logging;

import from typing { Optional }

import from jaclang.compiler.frontend.constant {
    JacSemTokenModifier as SemTokMod,
    JacSemTokenType as SemTokType
}

import from .engine { JacLangServer }

import jaclang.lsp.protocol.types as lspt;

def did_open(ls: JacLangServer, params: lspt.DidOpenTextDocumentParams) {
    ls.type_check(params.text_document.uri);
}

def did_save(ls: JacLangServer, params: lspt.DidSaveTextDocumentParams) {
    ls.type_check(params.text_document.uri);
}

def did_change(ls: JacLangServer, params: lspt.DidChangeTextDocumentParams) {
    ls.type_check(params.text_document.uri);
}

def formatting(
    ls: JacLangServer, params: lspt.DocumentFormattingParams
) -> list[lspt.TextEdit];

def lintfix_formatting(
    ls: JacLangServer, params: lspt.DocumentFormattingParams
) -> list[lspt.TextEdit];

def did_create_files(ls: JacLangServer, params: lspt.CreateFilesParams) {
    ls.files_changed([file.uri for file in params.files]);
}

def did_change_watched_files(
    ls: JacLangServer, params: lspt.DidChangeWatchedFilesParams
) {
    ls.files_changed([file.uri for file in params.changes]);
}

def did_change_configuration(ls: JacLangServer, params: dict) {
    import os;
    import from jaclang.lsp.protocol { uris }
    directory = ls.workspace._root_path;
    if directory is not None {
        ls.files_changed(
            [uris.from_fs_path(os.path.join(directory, 'jac.toml')) or '']
        );
    }
}

def did_rename_files(ls: JacLangServer, params: lspt.RenameFilesParams) -> None;

def did_close(ls: JacLangServer, params: lspt.DidCloseTextDocumentParams) -> None;

def did_delete_files(ls: JacLangServer, params: lspt.DeleteFilesParams) -> None;

def completion(
    ls: JacLangServer, params: lspt.CompletionParams
) -> lspt.CompletionList {
    return ls.get_completion(
        params.text_document.uri,
        params.position,
        (params.context.trigger_character if params.context else None)
    );
}

def inlay_hint(
    ls: JacLangServer, params: lspt.InlayHintParams
) -> list[lspt.InlayHint];

def hover(
    ls: JacLangServer, params: lspt.TextDocumentPositionParams
) -> Optional[lspt.Hover];

def document_symbol(
    ls: JacLangServer, params: lspt.DocumentSymbolParams
) -> list[lspt.DocumentSymbol];

def definition(
    ls: JacLangServer, params: lspt.TextDocumentPositionParams
) -> Optional[lspt.Location];

def references(ls: JacLangServer, params: lspt.ReferenceParams) -> list[lspt.Location];

def rename(
    ls: JacLangServer, params: lspt.RenameParams
) -> Optional[lspt.WorkspaceEdit];

def semantic_tokens_full(
    ls: JacLangServer, params: lspt.SemanticTokensParams
) -> lspt.SemanticTokens;

def run_lang_server -> None;

with entry:__main__ {
    run_lang_server();
}
