"""Utility functions for the language server."""

import asyncio;
import builtins;
import re;
import from functools { wraps }
import from typing { Any, Awaitable, Callable, Coroutine, Optional, ParamSpec, TypeVar }

import jaclang.pycore.unitree as uni;
import from jaclang.pycore.codeinfo { CodeLocInfo }
import from jaclang.pycore.constant { SymbolType }
import from jaclang.pycore.passes.transform { Alert }
import from jaclang.pycore.unitree { Symbol, UniScopeNode }
import from jaclang.vendor.pygls { uris }

import lsprotocol.types as lspt;

glob P = ParamSpec('P'),
     T = TypeVar('T', bound=Callable[(P, Coroutine[(Any, Any, Any)])]),
     _BUILTIN_NAMES = frozenset(dir(builtins));

def gen_diagnostics(
    from_path: str, errors: list[Alert], warnings: list[Alert]
) -> list[lspt.Diagnostic];

def debounce(<>wait: float) -> Callable[[T], Callable[(..., Awaitable[None])]];

def sym_tab_list(sym_tab: UniScopeNode, file_path: str) -> list[UniScopeNode];

def find_deepest_symbol_node_at_pos(
    <>node: uni.UniNode, line: int, character: int
) -> Optional[uni.AstSymbolNode];

def position_within_node(n: uni.UniNode, line: int, character: int) -> bool;

def find_index(sem_tokens: list[int], line: int, char: int) -> Optional[int];

def get_symbols_for_outline(<>node: UniScopeNode) -> list[lspt.DocumentSymbol];

def owner_sym(table: UniScopeNode) -> Optional[Symbol];

def create_range(loc: CodeLocInfo) -> lspt.Range;

def kind_map(sub_tab: uni.UniNode) -> lspt.SymbolKind;

def label_map(sub_tab: SymbolType) -> lspt.CompletionItemKind;

def collect_all_symbols_in_scope(
    sym_tab: UniScopeNode, up_tree: bool = True
) -> list[lspt.CompletionItem];

def collect_child_tabs(sym_tab: UniScopeNode) -> list[lspt.CompletionItem];

def parse_symbol_path(text: str, dot_position: int) -> list[str];

def get_token_start(
    token_index: (int | None), sem_tokens: list[int]
) -> tuple[int, int, int];

def find_surrounding_tokens(
    change_start_line: int,
    change_start_char: int,
    change_end_line: int,
    change_end_char: int,
    sem_tokens: list[int]
) -> tuple[(int | None), (int | None), bool];

def get_line_of_code(line_number: int, lines: list[str]) -> Optional[tuple[(str, int)]];

def add_unique_text_edit(
    changes: dict[(str, list[lspt.TextEdit])], key: str, new_edit: lspt.TextEdit
) -> None;
