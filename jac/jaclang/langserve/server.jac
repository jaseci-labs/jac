"""Jaclang Language Server."""

import asyncio;
import sys;
import time;
import logging;

import from typing { Optional }

import from jaclang.pycore.constant {
    JacSemTokenModifier as SemTokMod,
    JacSemTokenType as SemTokType
}

import from .engine { JacLangServer }

import lsprotocol.types as lspt;

def debug(msg: str) -> None;

"""Check syntax on change."""
async def did_open(ls: JacLangServer, params: lspt.DidOpenTextDocumentParams) -> None {
    ls.type_check(params.text_document.uri);
}

"""Check syntax on change."""
async def did_save(ls: JacLangServer, params: lspt.DidOpenTextDocumentParams) -> None {
    ls.type_check(params.text_document.uri);
}

"""Check syntax on change with debouncing."""
async def did_change(
    ls: JacLangServer, params: lspt.DidChangeTextDocumentParams
) -> None {
    debug(f"Did change: Type checking started.");
    ls.type_check(params.text_document.uri);
}

def formatting(
    ls: JacLangServer, params: lspt.DocumentFormattingParams
) -> list[lspt.TextEdit];

"""Check syntax on file creation."""
def did_create_files(ls: JacLangServer, params: lspt.CreateFilesParams) -> None { }

def did_rename_files(ls: JacLangServer, params: lspt.RenameFilesParams) -> None;

def did_close(ls: JacLangServer, params: lspt.DidCloseTextDocumentParams) -> None;

def did_delete_files(ls: JacLangServer, params: lspt.DeleteFilesParams) -> None;

"""Provide completion."""
async def completion(
    ls: JacLangServer, params: lspt.CompletionParams
) -> lspt.CompletionList {
    file_path = params.text_document.uri;
    debug("Completion requested");
    return await ls.get_completion(
        params.text_document.uri,
        params.position,
        (params.context.trigger_character if params.context else None)
    );
}

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
