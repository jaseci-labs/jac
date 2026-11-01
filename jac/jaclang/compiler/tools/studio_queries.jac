"""Project-structure queries studio and the code index ask a kernel session:
module outlines, edit-review symbol tables, wiring models and per-token
symbols. Lines are 1-based; `TokenSymbol` columns are 0-based, as the editor
draws them."""
import os;

def node_text(nd: any) -> str;

def source_text(nd: any) -> str;

def doc_text(nd: any) -> str;

def lines_text(lines: list[str], first: int, last: int) -> str;

def span_into(row: OutlineSymbol, nd: uni.UniNode);

def ability_symbol(ab: uni.Ability, owner: str) -> OutlineSymbol;

def module_outline_of(host: ProjectHost, path: str) -> ModuleOutline;

def outline_rows(tree: uni.Module, out: ModuleOutline);

def edit_symbol_rows(text: str, path: str) -> list[EditSymbol];

def import_text_rows(text: str, path: str) -> list[str];

def wiring_fact_texts(recs: list[WireRec]) -> dict[tuple[str, ...], str];

def wiring_change_rows(old_text: str, new_text: str, path: str) -> list[WiringChange];

def wired_dependent_files(head: str, names: list[str]) -> WiredFiles;

def wiring_files_of(arch_path: str, consumers: list[str]) -> list[str];

def wire_violation(
    spec: WiringSpec, provider: str, consumer: str, names: list[str], whole: bool
) -> str;

def wire_form(w: WireRec) -> str;

def wiring_model_of(arch_path: str) -> WiringModel;

def token_symbol_rows(module: uni.Module, path: str) -> list[TokenSymbol];

def assignment_hint_rows(module: uni.Module, path: str) -> list[InlayHint];

def token_stream(text: str, path: str) -> TokenStream;
