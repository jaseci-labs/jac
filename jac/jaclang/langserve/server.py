"""Jaclang Language Server."""
from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _
from typing import Optional
from jaclang.compiler.constant import JacSemTokenModifier as SemTokMod, JacSemTokenType as SemTokType
from jaclang.langserve.engine import JacLangServer
from jaclang.settings import settings
import lsprotocol.types as lspt
server = JacLangServer()

@server.feature(lspt.TEXT_DOCUMENT_DID_OPEN)
async def did_open(ls: JacLangServer, params: lspt.DidOpenTextDocumentParams) -> None:
    """Check syntax on change."""
    await ls.launch_deep_check(params.text_document.uri)
    ls.lsp.send_request(lspt.WORKSPACE_SEMANTIC_TOKENS_REFRESH)

@server.feature(lspt.TEXT_DOCUMENT_DID_SAVE)
async def did_save(ls: JacLangServer, params: lspt.DidOpenTextDocumentParams) -> None:
    """Check syntax on save - immediate response for save events."""
    file_path = params.text_document.uri
    # For save events, do immediate checking (no debouncing needed)
    quick_check_passed = await ls.launch_quick_check(file_path)
    if not quick_check_passed:
        return
    await ls.launch_deep_check(file_path)
    ls.lsp.send_request(lspt.WORKSPACE_SEMANTIC_TOKENS_REFRESH)

@server.feature(lspt.TEXT_DOCUMENT_DID_CHANGE)
async def did_change(ls: JacLangServer, params: lspt.DidChangeTextDocumentParams) -> None:
    """Check syntax on change with debouncing for rapid typing."""
    file_path = params.text_document.uri
    
    # Use debounced quick check for rapid typing - this is the KEY fix!
    await ls.debounced_quick_check(file_path, delay=0.2)
    
    # Always update semantic tokens immediately for responsive UI
    document = ls.workspace.get_text_document(file_path)
    lines = document.source.splitlines()
    fs_path = file_path.removeprefix('file://')
    
    if fs_path in ls.sem_managers:
        sem_manager = ls.sem_managers[fs_path]
        sem_manager.update_sem_tokens(params, sem_manager.sem_tokens, lines)
        ls.lsp.send_request(lspt.WORKSPACE_SEMANTIC_TOKENS_REFRESH)
    
    # Use debounced deep check to avoid overwhelming during rapid typing
    await ls.debounced_deep_check(file_path, delay=0.5)

@server.feature(lspt.TEXT_DOCUMENT_FORMATTING)
def formatting(ls: JacLangServer, params: lspt.DocumentFormattingParams) -> list[lspt.TextEdit]:
    """Format the given document."""
    return ls.formatted_jac(params.text_document.uri)

@server.feature(lspt.WORKSPACE_DID_CREATE_FILES, lspt.FileOperationRegistrationOptions(filters=[lspt.FileOperationFilter(pattern=lspt.FileOperationPattern('**/*.jac'))]))
def did_create_files(ls: JacLangServer, params: lspt.CreateFilesParams) -> None:
    """Check syntax on file creation."""
    pass

@server.feature(lspt.WORKSPACE_DID_RENAME_FILES, lspt.FileOperationRegistrationOptions(filters=[lspt.FileOperationFilter(pattern=lspt.FileOperationPattern('**/*.jac'))]))
def did_rename_files(ls: JacLangServer, params: lspt.RenameFilesParams) -> None:
    """Check syntax on file rename."""
    new_uris = [file.new_uri for file in params.files]
    old_uris = [file.old_uri for file in params.files]
    for i in range(len(new_uris)):
        ls.rename_module(old_uris[i], new_uris[i])

@server.feature(lspt.WORKSPACE_DID_DELETE_FILES, lspt.FileOperationRegistrationOptions(filters=[lspt.FileOperationFilter(pattern=lspt.FileOperationPattern('**/*.jac'))]))
def did_delete_files(ls: JacLangServer, params: lspt.DeleteFilesParams) -> None:
    """Check syntax on file delete."""
    for file in params.files:
        ls.delete_module(file.uri)

@server.feature(lspt.TEXT_DOCUMENT_COMPLETION, lspt.CompletionOptions(trigger_characters=['.', ':', 'a-zA-Z0-9']))
def completion(ls: JacLangServer, params: lspt.CompletionParams) -> lspt.CompletionList:
    """Provide completion."""
    return ls.get_completion(params.text_document.uri, params.position, params.context.trigger_character if params.context else None)

@server.feature(lspt.TEXT_DOCUMENT_HOVER, lspt.HoverOptions(work_done_progress=True))
def hover(ls: JacLangServer, params: lspt.TextDocumentPositionParams) -> Optional[lspt.Hover]:
    """Provide hover information for the given hover request."""
    return ls.get_hover_info(params.text_document.uri, params.position)

@server.feature(lspt.TEXT_DOCUMENT_DOCUMENT_SYMBOL)
def document_symbol(ls: JacLangServer, params: lspt.DocumentSymbolParams) -> list[lspt.DocumentSymbol]:
    """Provide document symbols."""
    return ls.get_outline(params.text_document.uri)

@server.feature(lspt.TEXT_DOCUMENT_DEFINITION)
def definition(ls: JacLangServer, params: lspt.TextDocumentPositionParams) -> Optional[lspt.Location]:
    """Provide definition."""
    return ls.get_definition(params.text_document.uri, params.position)

@server.feature(lspt.TEXT_DOCUMENT_REFERENCES)
def references(ls: JacLangServer, params: lspt.ReferenceParams) -> list[lspt.Location]:
    """Provide references."""
    return ls.get_references(params.text_document.uri, params.position)

@server.feature(lspt.TEXT_DOCUMENT_RENAME)
def rename(ls: JacLangServer, params: lspt.RenameParams) -> Optional[lspt.WorkspaceEdit]:
    """Rename symbol."""
    ls.log_warning('Auto Rename is Experimental, Please use with caution.')
    return ls.rename_symbol(params.text_document.uri, params.position, params.new_name)

@server.feature(lspt.TEXT_DOCUMENT_SEMANTIC_TOKENS_FULL, lspt.SemanticTokensLegend(token_types=SemTokType.as_str_list(), token_modifiers=SemTokMod.as_str_list()))
def semantic_tokens_full(ls: JacLangServer, params: lspt.SemanticTokensParams) -> lspt.SemanticTokens:
    """Provide semantic tokens."""
    return ls.get_semantic_tokens(params.text_document.uri)

def run_lang_server() -> None:
    """Run the language server."""
    settings.pass_timer = True
    server.start_io()
if __name__ == '__main__':
    run_lang_server()
