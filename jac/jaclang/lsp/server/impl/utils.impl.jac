impl span_range(span: SourceSpan) -> lspt.Range {
    return lspt.Range(
        start=lspt.Position(
            line=(span.line - 1) if span.line > 0 else 0,
            character=(span.col - 1) if span.col > 0 else 0
        ),
        end=lspt.Position(
            line=(span.end_line - 1) if span.end_line > 0 else 0,
            character=(span.end_col - 1) if span.end_col > 0 else 0
        )
    );
}

impl span_location(span: SourceSpan) -> lspt.Location {
    return lspt.Location(uri=uris.from_fs_path(span.path) or "", range=span_range(span));
}

impl lsp_diagnostic(diag: KernelDiagnostic) -> lspt.Diagnostic {
    return lspt.Diagnostic(
        range=span_range(diag.span),
        message=(diag.message + "\n\nhelp: " + diag.help) if diag.help else diag.message,
        severity=lspt.DiagnosticSeverity.Error
            if diag.severity == "error"
            else lspt.DiagnosticSeverity.Warning,
        code=diag.code or None,
        source="jac"
    );
}

impl symbol_kind(kind: str) -> lspt.SymbolKind {
    if kind == "function" {
        return lspt.SymbolKind.Function;
    }
    if kind == "enum" {
        return lspt.SymbolKind.Enum;
    }
    if kind == "class" {
        return lspt.SymbolKind.Class;
    }
    if kind == "module" {
        return lspt.SymbolKind.Module;
    }
    return lspt.SymbolKind.Variable;
}

impl document_symbol(symbol: DocumentSymbol) -> lspt.DocumentSymbol {
    where = span_range(symbol.span);
    return lspt.DocumentSymbol(
        name=symbol.name,
        kind=symbol_kind(symbol.kind),
        range=where,
        selection_range=where,
        children=[document_symbol(child) for child in symbol.children]
    );
}

impl completion_kind(kind: str) -> lspt.CompletionItemKind {
    if kind == "module" {
        return lspt.CompletionItemKind.Module;
    }
    if kind == "function" {
        return lspt.CompletionItemKind.Function;
    }
    if kind == "class" {
        return lspt.CompletionItemKind.Class;
    }
    if kind == "enum" {
        return lspt.CompletionItemKind.Enum;
    }
    if kind == "variable" {
        return lspt.CompletionItemKind.Variable;
    }
    if kind == "keyword" {
        return lspt.CompletionItemKind.Keyword;
    }
    return lspt.CompletionItemKind.Text;
}

impl completion_item(item: CompletionItem) -> lspt.CompletionItem {
    return lspt.CompletionItem(
        label=item.label,
        kind=completion_kind(item.kind),
        documentation=lspt.MarkupContent(
            kind=lspt.MarkupKind.PlainText, value=item.detail
        )
            if item.detail
            else None,
        insert_text=item.insert_text or None
    );
}

impl add_unique_text_edit(
    changes: dict[(str, list[lspt.TextEdit])], key: str, new_edit: lspt.TextEdit
) -> None {
    if key not in changes {
        changes[key] = [new_edit];
    } else {
        for existing_edit in changes[key] {
            if existing_edit.range.start == new_edit.range.start
                and existing_edit.range.end == new_edit.range.end
                and existing_edit.new_text == new_edit.new_text {
                return;
            }
        }
        changes[key].append(new_edit);
    }
}
