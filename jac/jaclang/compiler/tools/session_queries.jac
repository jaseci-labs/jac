"""Editor queries over an analysed module, answered inside the kernel session.
Positions are 1-based lines and columns, the compiler's own convention."""
import os;

glob LOOP_SCOPES: tuple[type, ...] = (
         uni.IfStmt,
         uni.ElseStmt,
         uni.WhileStmt,
         uni.ForeverStmt,
         uni.IterForStmt,
         uni.InForStmt
     );

def span_at(loc: Span) -> SourceSpan;

def file_start(path: str) -> SourceSpan;

def position_within(nd: uni.UniNode, line: int, col: int) -> bool;

def belongs_to(nd: uni.UniNode, path: str) -> bool;

def symbol_nodes(module: uni.Module, path: str) -> list[uni.NameAtom];

def token_at(module: uni.Module, path: str, line: int, col: int) -> (uni.NameAtom | None);

def node_at(module: uni.Module, line: int, col: int) -> (uni.Token | None);

def semantic_token_data(module: uni.Module, path: str) -> list[int];

def doc_of_symbol(sym: uni.Symbol) -> str;

def hover_text(nd: uni.NameAtom) -> str;

def definition_symbol(sym: uni.Symbol) -> uni.Symbol;

def definition_spans(program: JacProgram, nd: uni.NameAtom) -> list[SourceSpan];

def module_spec_target(mp: uni.ModulePath) -> str;

def string_import_definition(module: uni.Module, line: int, col: int) -> list[SourceSpan];

def reference_spans(nd: uni.NameAtom) -> list[SourceSpan];

def rename_edits(nd: uni.NameAtom, new_name: str) -> list[TextEdit];

def completion_kind(sym: uni.Symbol) -> str;

def completion_from_symbol(name: str, sym: uni.Symbol) -> CompletionItem;

def members_of(ty: (TypeBase | uni.UniScopeNode)) -> list[CompletionItem];

def scope_at(module: uni.Module, line: int, col: int) -> uni.UniScopeNode;

def keyword_items(seen: set[str]) -> list[CompletionItem];

def node_type(program: JacProgram, nd: uni.UniNode) -> (TypeBase | None);

def completion_items(
    program: JacProgram, module: uni.Module, line: int, col: int, trigger: str
) -> list[CompletionItem];

def inlay_hint_rows(module: uni.Module, first_line: int, last_line: int) -> list[InlayHint];

def symbol_kind(nd: uni.UniNode) -> str;

def owner_symbol(table: uni.UniScopeNode) -> (uni.Symbol | None);

def outline(nd: uni.UniScopeNode) -> list[DocumentSymbol];
