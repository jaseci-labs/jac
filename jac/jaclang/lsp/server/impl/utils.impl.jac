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

impl find_dts_decl_range(dts_path: str, name: str) -> Optional[lspt.Range] {
    import re;
    try {
        with open(dts_path, 'r', encoding='utf-8', errors='replace') as f {
            src = f.read();
        }
    } except OSError {
        return None;
    }
    escaped = re.escape(name);
    if name == 'default' {
        patterns = [r'(?m)^[ \t]*export[ \t]+(default)\b'];
    } else {
        patterns = [
            r'(?m)^[ \t]*(?:export[ \t]+)?(?:declare[ \t]+)?(?:abstract[ \t]+)?'
            r'(?:const|let|var|function|class|interface|enum|namespace|type)'
            r'[ \t]+('
                + escaped
                + r')\b',
            r'export[ \t]+(?:type[ \t]+)?\{[^{}]*?\b(' + escaped + r')\b',

        ];
    }
    for pat in patterns {
        found = re.search(pat, src);
        if found {
            start = found.start(1);
            line = src.count('\n', 0, start);
            col = start - (src.rfind('\n', 0, start) + 1);
            return lspt.Range(
                start=lspt.Position(line=line, character=col),
                end=lspt.Position(line=line, character=col + len(found.group(1)))
            );
        }
    }
    return None;
}

impl kind_map(sub_tab: uni.UniNode) -> lspt.SymbolKind {
    return lspt.SymbolKind.Function
        if isinstance(sub_tab, uni.Ability)
        else lspt.SymbolKind.Enum
            if isinstance(sub_tab, uni.Enum)
            else lspt.SymbolKind.Class
                if isinstance(sub_tab, (uni.Archetype, uni.ImplDef))
                else lspt.SymbolKind.Module
                    if isinstance(sub_tab, uni.Module)
                    else lspt.SymbolKind.Variable;
}

impl create_range(loc: (CodeLocInfo | Span)) -> lspt.Range {
    return lspt.Range(
        start=lspt.Position(
            line=(loc.first_line - 1) if loc.first_line > 0 else 0,
            character=(loc.col_start - 1) if loc.col_start > 0 else 0
        ),
        end=lspt.Position(
            line=(loc.last_line - 1) if loc.last_line > 0 else 0,
            character=(loc.col_end - 1) if loc.col_end > 0 else 0
        )
    );
}

impl owner_sym(table: UniScopeNode) -> Optional[Symbol] {
    parent = table.parent_scope;
    if parent is not None and isinstance(table, uni.AstSymbolNode) {
        return parent.lookup(table.sym_name);
    }
    return None;
}

impl get_symbols_for_outline(nd: UniScopeNode) -> list[lspt.DocumentSymbol] {
    symbols = [];
    owner_syms = {owner_sym(tab) for tab in nd.kid_scope};
    for (key, item) in nd.names_in_scope.items() {
        if key in _BUILTIN_NAMES
            or item in owner_syms
            or item.decl.loc.mod_path != nd.loc.mod_path {
            continue;
        }
        pos = create_range(item.decl.loc);
        symbol = lspt.DocumentSymbol(
            name=key,
            kind=kind_map(item.decl),
            range=pos,
            selection_range=pos,
            children=[]
        );
        symbols.append(symbol);
    }
    for sub_tab in [
        i
        for i in nd.kid_scope
        if i.loc.mod_path == nd.loc.mod_path
    ] {
        sub_symbols = get_symbols_for_outline(sub_tab);
        if isinstance(
            sub_tab,
            (
                uni.IfStmt,
                uni.ElseStmt,
                uni.WhileStmt,
                uni.ForeverStmt,
                uni.IterForStmt,
                uni.InForStmt
            )
        ) {
            symbols.extend(sub_symbols);
        } else {
            sub_pos = create_range(sub_tab.loc);
            symbol = lspt.DocumentSymbol(
                name=sub_tab.scope_name,
                kind=kind_map(sub_tab),
                range=sub_pos,
                selection_range=sub_pos,
                children=sub_symbols
            );
            symbols.append(symbol);
        }
    }
    return symbols;
}

impl find_index(sem_tokens: list[int], line: int, char: int) -> Optional[int] {
    current_line = 0;
    current_char = 0;
    token_idx = 0;
    i = 0;
    while (i + 4) < len(sem_tokens) {
        token_line_delta = sem_tokens[i];
        token_start_char = sem_tokens[(i + 1)];
        token_length = sem_tokens[(i + 2)];
        if token_line_delta > 0 {
            current_line += token_line_delta;
            current_char = token_start_char;
        } else {
            current_char += token_start_char;
        }
        col_end = current_char + token_length;
        if current_line == line and current_char <= char <= col_end {
            return token_idx;
        }
        token_idx += 1;
        i += 5;
    }
    return None;
}

impl position_within_node(n: uni.UniNode, line: int, character: int) -> bool {
    if n.loc.first_line < line < n.loc.last_line {
        return True;
    }
    if line < n.loc.first_line or line > n.loc.last_line {
        return False;
    }
    if line == n.loc.first_line and character < n.loc.col_start {
        return False;
    }
    if line == n.loc.last_line and character >= n.loc.col_end {
        return False;
    }
    return True;
}

impl gen_diagnostics(
    from_path: str, errors: list[Alert], warnings: list[Alert]
) -> list[lspt.Diagnostic] {
    def _message(alert: Alert) -> str {
        hint = alert.code.help_text if alert.code else None;
        if alert.help_text {
            hint = alert.help_text;
        }
        return (alert.msg + "\n\nhelp: " + hint) if hint else alert.msg;
    }
    return [
        lspt.Diagnostic(
            range=create_range(error.loc),
            message=_message(error),
            severity=lspt.DiagnosticSeverity.Error,
            code=error.code.code if error.code else None,
            source="jac"
        )
        for error in errors
        if error.loc.mod_path == from_path
    ]
        + [
            lspt.Diagnostic(
                range=create_range(warning.loc),
                message=_message(warning),
                severity=lspt.DiagnosticSeverity.Warning,
                code=warning.code.code if warning.code else None,
                source="jac"
            )
            for warning in warnings
            if warning.loc.mod_path == from_path
        ];
}

impl doc_of_sym(sym: Symbol) -> (str | None) {
    if not sym.decl {
        return None;
    }
    decl = sym.decl.name_of;
    if isinstance(decl, uni.AstDocNode) and decl.doc {
        doc_lit = decl.doc.lit_value;
        if isinstance(doc_lit, str) {
            return doc_lit;
        }
    }
    if isinstance(decl, uni.HasVar) {
        if (arch_has := decl.find_parent_of_type(uni.ArchHas)) and arch_has.doc {
            arch_doc_lit = arch_has.doc.lit_value;
            if isinstance(arch_doc_lit, str) {
                return arch_doc_lit;
            }
        }
    }
    return None;
}

impl completion_item_from_sym(name: str, sym: Symbol) -> lspt.CompletionItem {
    kind = completion_kind_from_sym(sym);
    text = doc_of_sym(sym);
    documentation = lspt.MarkupContent(kind=lspt.MarkupKind.PlainText, value=text)
        if text
        else None;
    return lspt.CompletionItem(label=name, kind=kind, documentation=documentation);
}

impl get_completion_items(ty: (TypeBase | UniScopeNode)) -> list[lspt.CompletionItem] {
    ret: list[lspt.CompletionItem] = [];
    if isinstance(ty, UniScopeNode) {
        scope: (UniScopeNode | None) = ty;
        while scope {
            for (name, sym) in scope.names_in_scope.items() {
                ret.append(completion_item_from_sym(name, sym));
            }
            scope = scope.parent_scope;
        }
    } elif isinstance(ty, ClassType) {
        if not ty.shared.mro {
            compute_mro_linearization(ty);
        }
        for cls in ty.shared.mro {
            for (name, sym) in cls.shared.symbol_table.names_in_scope.items() {
                ret.append(completion_item_from_sym(name, sym));
            }
        }
    } elif isinstance(ty, ModuleType) {
        mod_symtab = ty.symbol_table;
        if mod_symtab is not None {
            for (name, sym) in mod_symtab.names_in_scope.items() {
                ret.append(completion_item_from_sym(name, sym));
            }
        }
    }
    return ret;
}

impl completion_kind_from_sym(sym: Symbol) -> lspt.CompletionItemKind {
    decl = sym.decl.name_of;
    if isinstance(decl, uni.ModulePath) {
        return lspt.CompletionItemKind.Module;
    }
    if isinstance(decl, uni.Ability) {
        return lspt.CompletionItemKind.Function;
    }
    if isinstance(decl, uni.Archetype) {
        return lspt.CompletionItemKind.Class;
    }
    if isinstance(decl, uni.Enum) {
        return lspt.CompletionItemKind.Enum;
    }
    if isinstance(decl, uni.HasVar) {
        return lspt.CompletionItemKind.Variable;
    }
    return lspt.CompletionItemKind.Text;
}
