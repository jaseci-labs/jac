"""Utility functions for the language server."""

import asyncio;
import builtins;
import from functools { wraps }
import from typing { Any, Awaitable, Callable, Coroutine, Optional, ParamSpec, TypeVar }

import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.codeinfo { CodeLocInfo }
import from jaclang.jac0core.passes.transform { Alert }
import from jaclang.jac0core.unitree { Symbol, UniScopeNode }
import from jaclang.lsp { uris }

import jaclang.lsp.types as lspt;

glob P = ParamSpec('P'),
     T = TypeVar('T', bound=Callable[(P, Coroutine[(Any, Any, Any)])]),
     _BUILTIN_NAMES = frozenset(dir(builtins));

def gen_diagnostics(
    from_path: str, errors: list[Alert], warnings: list[Alert]
) -> list[lspt.Diagnostic];

def debounce(`wait: float) -> Callable[[T], Callable[(..., Awaitable[None])]];

def position_within_node(n: uni.UniNode, line: int, character: int) -> bool;

def find_index(sem_tokens: list[int], line: int, char: int) -> Optional[int];

def get_symbols_for_outline(nd: UniScopeNode) -> list[lspt.DocumentSymbol];

def owner_sym(table: UniScopeNode) -> Optional[Symbol];

def create_range(loc: CodeLocInfo) -> lspt.Range;

def kind_map(sub_tab: uni.UniNode) -> lspt.SymbolKind;

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

def get_line_of_code(
    line_number: int, lines: list[str]
) -> Optional[tuple[(str, int)]];

def add_unique_text_edit(
    changes: dict[(str, list[lspt.TextEdit])], key: str, new_edit: lspt.TextEdit
) -> None;
