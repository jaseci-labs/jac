import builtins;
import from typing { Optional }

import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.codeinfo { CodeLocInfo }
import from jaclang.jac0core.passes.transform { Alert }
import from jaclang.jac0core.unitree { Symbol, UniScopeNode }
import from jaclang.lsp { uris }

import jaclang.lsp.types as lspt;

glob _BUILTIN_NAMES = frozenset(dir(builtins));

def gen_diagnostics(
    from_path: str, errors: list[Alert], warnings: list[Alert]
) -> list[lspt.Diagnostic];

def position_within_node(n: uni.UniNode, line: int, character: int) -> bool;

def find_index(sem_tokens: list[int], line: int, char: int) -> Optional[int];

def get_symbols_for_outline(nd: UniScopeNode) -> list[lspt.DocumentSymbol];

def owner_sym(table: UniScopeNode) -> Optional[Symbol];

def create_range(loc: CodeLocInfo) -> lspt.Range;

def kind_map(sub_tab: uni.UniNode) -> lspt.SymbolKind;

def add_unique_text_edit(
    changes: dict[(str, list[lspt.TextEdit])], key: str, new_edit: lspt.TextEdit
) -> None;
