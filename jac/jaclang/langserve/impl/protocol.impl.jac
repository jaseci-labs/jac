"""IPC Protocol implementation — request builders and response parsers."""

# ── Request builders ──────────────────────────────────────────────────

impl make_compile_request(file_path: str, source: str) -> dict {
    return {"type": "compile", "file_path": file_path, "source": source};
}

impl make_hover_request(file_path: str, line: int, character: int) -> dict {
    return {"type": "hover", "file_path": file_path, "line": line, "character": character};
}

impl make_definition_request(file_path: str, line: int, character: int) -> dict {
    return {"type": "definition", "file_path": file_path, "line": line, "character": character};
}

impl make_references_request(file_path: str, line: int, character: int) -> dict {
    return {"type": "references", "file_path": file_path, "line": line, "character": character};
}

impl make_outline_request(file_path: str) -> dict {
    return {"type": "outline", "file_path": file_path};
}

impl make_semantic_tokens_request(file_path: str) -> dict {
    return {"type": "semantic_tokens", "file_path": file_path};
}

impl make_completion_request(
    file_path: str, line: int, character: int, trigger: Optional[str]
) -> dict {
    return {
        "type": "completion",
        "file_path": file_path,
        "line": line,
        "character": character,
        "trigger": trigger
    };
}

impl make_rename_request(
    file_path: str, line: int, character: int, new_name: str
) -> dict {
    return {
        "type": "rename",
        "file_path": file_path,
        "line": line,
        "character": character,
        "new_name": new_name
    };
}

impl make_format_request(file_path: str, source: str) -> dict {
    return {"type": "format", "file_path": file_path, "source": source};
}

impl make_delete_module_request(file_path: str) -> dict {
    return {"type": "delete_module", "file_path": file_path};
}

impl make_rename_module_request(old_path: str, new_path: str) -> dict {
    return {"type": "rename_module", "old_path": old_path, "new_path": new_path};
}

impl make_shutdown_request -> dict {
    return {"type": "shutdown"};
}

# ── Response parsers ──────────────────────────────────────────────────

"""Parse hover response dict into LSP Hover type."""
impl parse_hover_response(resp: dict) -> Optional[lspt.Hover] {
    contents = resp.get("contents");
    if contents is None {
        return None;
    }
    return lspt.Hover(
        contents=lspt.MarkupContent(
            kind=lspt.MarkupKind.PlainText, value=contents
        )
    );
}

"""Parse definition response dict into LSP Location type."""
impl parse_definition_response(resp: dict) -> Optional[lspt.Location] {
    uri = resp.get("uri");
    r = resp.get("range");
    if uri is None or r is None {
        return None;
    }
    return lspt.Location(
        uri=uri,
        range=lspt.Range(
            start=lspt.Position(line=r["start_line"], character=r["start_char"]),
            end=lspt.Position(line=r["end_line"], character=r["end_char"])
        )
    );
}

"""Parse references response into list of LSP Location."""
impl parse_references_response(resp: dict) -> list[lspt.Location] {
    locations = [];
    for loc in resp.get("locations", []) {
        r = loc["range"];
        locations.append(
            lspt.Location(
                uri=loc["uri"],
                range=lspt.Range(
                    start=lspt.Position(line=r["start_line"], character=r["start_char"]),
                    end=lspt.Position(line=r["end_line"], character=r["end_char"])
                )
            )
        );
    }
    return locations;
}

"""Parse outline response into list of DocumentSymbol."""
impl parse_outline_response(resp: dict) -> list[lspt.DocumentSymbol] {
    def _parse_symbol(s: dict) -> lspt.DocumentSymbol {
        r = s["range"];
        sr = s["selection_range"];
        children = [_parse_symbol(c) for c in s.get("children", [])];
        return lspt.DocumentSymbol(
            name=s["name"],
            kind=lspt.SymbolKind(s["kind"]),
            range=lspt.Range(
                start=lspt.Position(line=r["start_line"], character=r["start_char"]),
                end=lspt.Position(line=r["end_line"], character=r["end_char"])
            ),
            selection_range=lspt.Range(
                start=lspt.Position(line=sr["start_line"], character=sr["start_char"]),
                end=lspt.Position(line=sr["end_line"], character=sr["end_char"])
            ),
            children=children
        );
    }
    return [_parse_symbol(s) for s in resp.get("symbols", [])];
}

"""Parse semantic tokens response."""
impl parse_semantic_tokens_response(resp: dict) -> lspt.SemanticTokens {
    return lspt.SemanticTokens(data=resp.get("data", []));
}

"""Parse completion response."""
impl parse_completion_response(resp: dict) -> lspt.CompletionList {
    items = [];
    for item in resp.get("items", []) {
        detail: lspt.CompletionItemLabelDetails | None = None;
        if item.get("detail") {
            detail = lspt.CompletionItemLabelDetails(detail=item["detail"]);
        }
        items.append(
            lspt.CompletionItem(
                label=item["label"],
                kind=lspt.CompletionItemKind(item["kind"]) if item.get("kind") else None,
                label_details=detail
            )
        );
    }
    return lspt.CompletionList(
        is_incomplete=resp.get("is_incomplete", False),
        items=items
    );
}

"""Parse rename response into WorkspaceEdit."""
impl parse_rename_response(resp: dict) -> Optional[lspt.WorkspaceEdit] {
    changes_dict = resp.get("changes");
    if changes_dict is None {
        return None;
    }
    changes: dict[(str, list[lspt.TextEdit])] = {};
    for (uri, edits) in changes_dict.items() {
        changes[uri] = [
            lspt.TextEdit(
                range=lspt.Range(
                    start=lspt.Position(line=e["start_line"], character=e["start_char"]),
                    end=lspt.Position(line=e["end_line"], character=e["end_char"])
                ),
                new_text=e["new_text"]
            )
            for e in edits
        ];
    }
    return lspt.WorkspaceEdit(changes=changes);
}

"""Parse format response into list of TextEdit."""
impl parse_format_response(resp: dict) -> list[lspt.TextEdit] {
    return [
        lspt.TextEdit(
            range=lspt.Range(
                start=lspt.Position(line=e["start_line"], character=e["start_char"]),
                end=lspt.Position(line=e["end_line"], character=e["end_char"])
            ),
            new_text=e["new_text"]
        )
        for e in resp.get("edits", [])
    ];
}

"""Parse diagnostics from compile response."""
impl parse_diagnostics_response(resp: dict) -> dict[str, list[lspt.Diagnostic]] {
    result: dict[(str, list[lspt.Diagnostic])] = {};
    for (uri, diags) in resp.get("diagnostics", {}).items() {
        result[uri] = [
            lspt.Diagnostic(
                range=lspt.Range(
                    start=lspt.Position(line=d["start_line"], character=d["start_char"]),
                    end=lspt.Position(line=d["end_line"], character=d["end_char"])
                ),
                message=d["message"],
                severity=lspt.DiagnosticSeverity(d["severity"])
            )
            for d in diags
        ];
    }
    return result;
}
