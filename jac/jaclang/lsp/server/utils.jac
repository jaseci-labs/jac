import from jaclang.lsp.protocol { uris }

def span_range(span: SourceSpan) -> lspt.Range;

def span_location(span: SourceSpan) -> lspt.Location;

def lsp_diagnostic(diag: KernelDiagnostic) -> lspt.Diagnostic;

def symbol_kind(kind: str) -> lspt.SymbolKind;

def document_symbol(symbol: DocumentSymbol) -> lspt.DocumentSymbol;

def completion_kind(kind: str) -> lspt.CompletionItemKind;

def completion_item(item: CompletionItem) -> lspt.CompletionItem;

def add_unique_text_edit(
    changes: dict[(str, list[lspt.TextEdit])], key: str, new_edit: lspt.TextEdit
) -> None;
