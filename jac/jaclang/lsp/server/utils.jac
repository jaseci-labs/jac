import builtins;
import from jaclang.compiler.types.types { TypeBase, ClassType, ModuleType }
import from jaclang.compiler.types.type_utils { compute_mro_linearization }
import from typing { Optional }

import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.codeinfo { CodeLocInfo }
import from jaclang.compiler.frontend.srcloc { Span }
import from jaclang.compiler.passes.transform { Alert }
import from jaclang.compiler.frontend.unitree { Symbol, UniScopeNode }
import from jaclang.lsp.protocol { uris }

import jaclang.lsp.protocol.types as lspt;

glob _BUILTIN_NAMES = frozenset(dir(builtins));

def gen_diagnostics(
    from_path: str, errors: list[Alert], warnings: list[Alert]
) -> list[lspt.Diagnostic];

def position_within_node(n: uni.UniNode, line: int, character: int) -> bool;

def find_index(sem_tokens: list[int], line: int, char: int) -> Optional[int];

def get_symbols_for_outline(nd: UniScopeNode) -> list[lspt.DocumentSymbol];

def owner_sym(table: UniScopeNode) -> Optional[Symbol];

def create_range(loc: (CodeLocInfo | Span)) -> lspt.Range;

def find_dts_decl_range(dts_path: str, name: str) -> Optional[lspt.Range];

def kind_map(sub_tab: uni.UniNode) -> lspt.SymbolKind;

def add_unique_text_edit(
    changes: dict[(str, list[lspt.TextEdit])], key: str, new_edit: lspt.TextEdit
) -> None;

def doc_of_sym(sym: Symbol) -> str | None;
def completion_item_from_sym(name: str, sym: Symbol) -> lspt.CompletionItem;
def completion_kind_from_sym(sym: Symbol) -> lspt.CompletionItemKind;
def get_completion_items(ty: TypeBase | UniScopeNode) -> list[lspt.CompletionItem];
