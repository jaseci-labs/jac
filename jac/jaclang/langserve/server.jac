"""Jaclang Language Server."""

import asyncio;

import from typing { Optional }

import from jaclang.compiler.constant {
    JacSemTokenModifier as SemTokMod,
    JacSemTokenType as SemTokType
}

import from engine { JacLangServer }
import from jaclang.settings { settings }

import lsprotocol.types as lspt;


with entry {
    server = JacLangServer();
}

def debug(ls: JacLangServer, msg: str) -> None {
    ls.log_py(f"[DEBUG] " + ("-" * 80));
    ls.log_py(f"[DEBUG]' {msg} ");
    ls.log_py(f"[DEBUG] " + ("-" * 80));
}

"""Check syntax on change."""
@server.feature(lspt.TEXT_DOCUMENT_DID_OPEN)
async def did_open(ls: JacLangServer, params: lspt.DidOpenTextDocumentParams) -> None {
    await ls.launch_deep_check(params.text_document.uri, delay=0.001);
    ls.lsp.send_request(lspt.WORKSPACE_SEMANTIC_TOKENS_REFRESH);
}


"""Check syntax on change."""
@server.feature(lspt.TEXT_DOCUMENT_DID_SAVE)
async def did_save(ls: JacLangServer, params: lspt.DidOpenTextDocumentParams) -> None {
    file_path = params.text_document.uri;
    quick_check_passed = await ls.launch_quick_check(file_path, delay=0.1);
    if not quick_check_passed {
        return;
    }
    await ls.launch_deep_check(file_path, delay=0.2);
    ls.lsp.send_request(lspt.WORKSPACE_SEMANTIC_TOKENS_REFRESH);
}

glob still_compiling = False;

"""Check syntax on change with debouncing."""
@ server.feature(lspt.TEXT_DOCUMENT_DID_CHANGE)
async def did_change(
    ls: JacLangServer,
    params: lspt.DidChangeTextDocumentParams
) -> None {
    global still_compiling;
    still_compiling = True;

    file_path = params.text_document.uri;
    try {
        document = ls.workspace.get_text_document(file_path);
        lines = document.source.splitlines();
        fs_path = document.path;
        if (fs_path in ls.sem_managers) {
            sem_manager = ls.sem_managers[fs_path];
            sem_manager.update_sem_tokens(params, sem_manager.sem_tokens, lines);
            ls.lsp.send_request(lspt.WORKSPACE_SEMANTIC_TOKENS_REFRESH);
        }
    } except Exception as e {
        ls.log_py(f" 'Failed to update semantic tokens: ' {e} ");
    }

    debug(ls, "Compilation started...");
    ls.log_py(f" 'Launching debounced quick check for ' {file_path} ");
    quick_check_passed = await ls.launch_quick_check(file_path, delay=0.5);
    if quick_check_passed {
        ls.log_py(
            f" 'Quick check passed, launching debounced deep check for ' {file_path} "
        );
        await ls.launch_deep_check(file_path, delay=1.0);

        ls.lsp.send_request(lspt.WORKSPACE_SEMANTIC_TOKENS_REFRESH);
    }
    still_compiling = False;
    debug(ls, "Compilation finished...");
}

"""Format the given document."""
@server.feature(lspt.TEXT_DOCUMENT_FORMATTING)
def formatting(
    ls: JacLangServer,
    params: lspt.DocumentFormattingParams
) -> list[lspt.TextEdit] {
    return ls.formatted_jac(params.text_document.uri);
}


"""Check syntax on file creation."""
@server.feature(
    lspt.WORKSPACE_DID_CREATE_FILES,
    lspt.FileOperationRegistrationOptions(
        filters=[lspt.FileOperationFilter(pattern=lspt.FileOperationPattern('**/*.jac'))]
    )
)
def did_create_files(ls: JacLangServer, params: lspt.CreateFilesParams) -> None {}


"""Check syntax on file rename."""
@server.feature(
    lspt.WORKSPACE_DID_RENAME_FILES,
    lspt.FileOperationRegistrationOptions(
        filters=[lspt.FileOperationFilter(pattern=lspt.FileOperationPattern('**/*.jac'))]
    )
)
def did_rename_files(ls: JacLangServer, params: lspt.RenameFilesParams) -> None {
    new_uris = [ file.new_uri for file in params.files ];
    old_uris = [ file.old_uri for file in params.files ];
    for i in range(len(new_uris)) {
        ls.rename_module(old_uris[i], new_uris[i]);
    }
}


"""Check syntax on file delete."""
@server.feature(
    lspt.WORKSPACE_DID_DELETE_FILES,
    lspt.FileOperationRegistrationOptions(
        filters=[lspt.FileOperationFilter(pattern=lspt.FileOperationPattern('**/*.jac'))]
    )
)
def did_delete_files(ls: JacLangServer, params: lspt.DeleteFilesParams) -> None {
    for file in params.files {
        ls.delete_module(file.uri);
    }
}


"""Provide completion."""
@server.feature(
    lspt.TEXT_DOCUMENT_COMPLETION,
    lspt.CompletionOptions(trigger_characters=['.', ':', 'a-zA-Z0-9'])
)
async def completion(ls: JacLangServer, params: lspt.CompletionParams) -> lspt.CompletionList {

    debug(ls, "Waiting for compilation to finish...");
    global still_compiling;
    while still_compiling {
        await asyncio.sleep(0.1);
    }
    debug(ls, "Compilation finished, providing completions...");

    return ls.get_completion(
        params.text_document.uri,
        params.position,
        params.context.trigger_character if params.context else None
    );
}


"""Provide hover information for the given hover request."""
@server.feature(lspt.TEXT_DOCUMENT_HOVER, lspt.HoverOptions(work_done_progress=True))
def hover(
    ls: JacLangServer,
    params: lspt.TextDocumentPositionParams
) -> Optional[lspt.Hover] {
    return ls.get_hover_info(params.text_document.uri, params.position);
}


"""Provide document symbols."""
@server.feature(lspt.TEXT_DOCUMENT_DOCUMENT_SYMBOL)
def document_symbol(
    ls: JacLangServer,
    params: lspt.DocumentSymbolParams
) -> list[lspt.DocumentSymbol] {
    return ls.get_outline(params.text_document.uri);
}


"""Provide definition."""
@server.feature(lspt.TEXT_DOCUMENT_DEFINITION)
def definition(
    ls: JacLangServer,
    params: lspt.TextDocumentPositionParams
) -> Optional[lspt.Location] {
    return ls.get_definition(params.text_document.uri, params.position);
}


"""Provide references."""
@server.feature(lspt.TEXT_DOCUMENT_REFERENCES)
def references(ls: JacLangServer, params: lspt.ReferenceParams) -> list[lspt.Location] {
    return ls.get_references(params.text_document.uri, params.position);
}


"""Rename symbol."""
@server.feature(lspt.TEXT_DOCUMENT_RENAME)
def rename(ls: JacLangServer, params: lspt.RenameParams) -> Optional[lspt.WorkspaceEdit] {
    ls.log_warning('Auto Rename is Experimental, Please use with caution.');
    return ls.rename_symbol(params.text_document.uri, params.position, params.new_name);
}


"""Provide semantic tokens."""
@server.feature(
    lspt.TEXT_DOCUMENT_SEMANTIC_TOKENS_FULL,
    lspt.SemanticTokensLegend(
        token_types=SemTokType.as_str_list(),
        token_modifiers=SemTokMod.as_str_list()
    )
)
def semantic_tokens_full(
    ls: JacLangServer,
    params: lspt.SemanticTokensParams
) -> lspt.SemanticTokens {
    return ls.get_semantic_tokens(params.text_document.uri);
}


"""Run the language server."""
def run_lang_server() -> None {
    settings.pass_timer = True;
    server.start_io();
}


with entry {
    if __name__ == '__main__' {
        run_lang_server();
    }
}
