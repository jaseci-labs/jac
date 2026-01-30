"""Jaclang Language Server.

Thin routing layer: registers LSP handlers and delegates to JacLangServer (engine).
All request logic lives in the engine.
"""

import asyncio;
import sys;

import from typing { Optional }

import from jaclang.pycore.constant {
    JacSemTokenModifier as SemTokMod,
    JacSemTokenType as SemTokType
}

import from .engine { JacLangServer }

import lsprotocol.types as lspt;

def debug(msg: str) -> None;

"""Handle file open - track file and schedule initial analysis."""
async def did_open(ls: JacLangServer, params: lspt.DidOpenTextDocumentParams) -> None {
    uri = params.text_document.uri;
    debug(f"did_open: {uri}");
    ls.on_file_opened(uri);
    # Only analyze saved files - schedule analysis to read from disk
    ls.schedule_analysis(uri);
}

"""Handle file save - schedule reanalysis."""
async def did_save(ls: JacLangServer, params: lspt.DidOpenTextDocumentParams) -> None {
    uri = params.text_document.uri;
    debug(f"did_save: {uri}");
    # File saved to disk - schedule analysis
    ls.schedule_analysis(uri);
}

"""Handle file change - ignored for now (only analyze on save)."""
async def did_change(
    ls: JacLangServer, params: lspt.DidChangeTextDocumentParams
) -> None {
    # TODO: integrate Semantic Tokens delta updates here without analysis
    debug(f"did_change: {params.text_document.uri} (ignored - only analyze on save)");
}

def formatting(
    ls: JacLangServer, params: lspt.DocumentFormattingParams
) -> list[lspt.TextEdit];

def did_rename_files(ls: JacLangServer, params: lspt.RenameFilesParams) -> None;

def did_delete_files(ls: JacLangServer, params: lspt.DeleteFilesParams) -> None;

"""Provide completion."""
def completion(ls: JacLangServer, params: lspt.CompletionParams) -> lspt.CompletionList;

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
