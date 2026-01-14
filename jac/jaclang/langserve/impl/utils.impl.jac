"""Add a new text edit to the changes dictionary if it is unique."""

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

"""Get the line of code, and the first non-space character index."""
impl get_line_of_code(
    line_number: int, lines: list[str]
) -> Optional[tuple[(str, int)]] {
    if 0 <= line_number < len(lines) {
        line = lines[line_number].rstrip('\n');
        first_non_space = len(line) - len(line.lstrip());
        return (
            line,
            (first_non_space + 4)
            if line.strip().endswith(('(', '{', '['))
            else first_non_space
        );
    }
    return None;
}

"""Find the indices of the previous and next tokens surrounding the change."""
impl find_surrounding_tokens(
    change_start_line: int,
    change_start_char: int,
    change_end_line: int,
    change_end_char: int,
    sem_tokens: list[int]
) -> tuple[(int | None), (int | None), bool] {
    prev_token_index = None;
    next_token_index = None;
    inside_tok = False;
    for (i, tok) in enumerate(
        [get_token_start(i, sem_tokens) for i in range(0, len(sem_tokens), 5)][0:]
    ) {
        if (not (prev_token_index is None or next_token_index is None))
        and (
            tok[0] > change_end_line
            or (tok[0] == change_end_line and tok[1] > change_end_char)
        ) {
            prev_token_index = i * 5;
            break;
        } elif change_start_line == tok[0] == change_end_line
        and tok[1] <= change_start_char
        and tok[2] >= change_end_char {
            prev_token_index = i * 5;
            inside_tok = True;
            break;
        } elif tok[0] < change_start_line
        or tok[0] == change_start_line
        and tok[1] < change_start_char {
            prev_token_index = i * 5;
        } elif tok[0] > change_end_line
        or tok[0] == change_end_line
        and tok[1] > change_end_char {
            next_token_index = i * 5;
            break;
        }
    }
    return (prev_token_index, next_token_index, inside_tok);
}

"""Return the starting position of a token."""
impl get_token_start(
    token_index: (int | None), sem_tokens: list[int]
) -> tuple[int, int, int] {
    if token_index is None or token_index >= len(sem_tokens) {
        return (0, 0, 0);
    }
    current_line = 0;
    current_char = 0;
    current_tok_index = 0;
    while current_tok_index < len(sem_tokens) {
        token_line_delta = sem_tokens[current_tok_index];
        token_start_char = sem_tokens[(current_tok_index + 1)];
        if token_line_delta > 0 {
            current_line += token_line_delta;
            current_char = 0;
        }
        if current_tok_index == token_index {
            if token_line_delta > 0 {
                return (
                    current_line,
                    token_start_char,
                    (token_start_char + sem_tokens[(current_tok_index + 2)])
                );
            }
            return (
                current_line,
                (current_char + token_start_char),
                (
                    (current_char + token_start_char) + sem_tokens[
                        (current_tok_index + 2)
                    ]
                )
            );
        }
        current_char += token_start_char;
        current_tok_index += 5;
    }
    return (
        current_line,
        current_char,
        (current_char + sem_tokens[(current_tok_index + 2)])
    );
}

"""Parse text and return a list of symbols."""
impl parse_symbol_path(text: str, dot_position: int) -> list[str] {
    text = text[:dot_position][:-1].strip();
    valid_character_pattern = re.compile('[a-zA-Z0-9_]');
    reversed_text = text[::-1];
    all_words = [];
    current_word = [];
    for char in reversed_text {
        if valid_character_pattern.fullmatch(char) {
            current_word.append(char);
        } elif char == '.' {
            if current_word {
                all_words.append(''.join(current_word[::-1]));
                current_word = [];
            }
        } elif current_word {
            all_words.append(''.join(current_word[::-1]));
            current_word = [];
        }
    }
    all_words = all_words[::-1]
    if not current_word
    else ([''.join(current_word[::-1])] + all_words[::-1]);
    return all_words;
}

"""Return all child tab's as completion items."""
impl collect_child_tabs(sym_tab: UniScopeNode) -> list[lspt.CompletionItem] {
    symbols: list[lspt.CompletionItem] = [];
    for tab in sym_tab.kid_scope {
        if tab.scope_name not in [i.label for i in symbols] {
            symbols.append(
                lspt.CompletionItem(
                    label=tab.scope_name, kind=label_map(tab.get_type())
                )
            );
        }
    }
    return symbols;
}

"""Return all symbols in scope."""
impl collect_all_symbols_in_scope(
    sym_tab: UniScopeNode, up_tree: bool = True
) -> list[lspt.CompletionItem] {
    symbols = [];
    visited = set();
    current_tab: Optional[UniScopeNode] = sym_tab;
    while current_tab is not None and current_tab not in visited {
        visited.add(current_tab);
        for (name, symbol) in current_tab.names_in_scope.items() {
            if name not in dir(builtins) and symbol.sym_type != SymbolType.IMPL {
                symbols.append(
                    lspt.CompletionItem(label=name, kind=label_map(symbol.sym_type))
                );
            }
        }
        if not up_tree {
            return symbols;
        }
        current_tab = current_tab.parent_scope
        if current_tab.parent_scope != current_tab
        else None;
    }
    return symbols;
}

"""Map the symbol node to an lspt.CompletionItemKind."""
impl label_map(sub_tab: SymbolType) -> lspt.CompletionItemKind {
    return (
        lspt.CompletionItemKind.Function
        if sub_tab in [SymbolType.ABILITY, SymbolType.TEST]
        else lspt.CompletionItemKind.Class
        if sub_tab in [
            SymbolType.OBJECT_ARCH,
            SymbolType.NODE_ARCH,
            SymbolType.EDGE_ARCH,
            SymbolType.WALKER_ARCH
        ]
        else lspt.CompletionItemKind.Module
        if sub_tab == SymbolType.MODULE
        else lspt.CompletionItemKind.Enum
        if sub_tab == SymbolType.ENUM_ARCH
        else lspt.CompletionItemKind.Field
        if sub_tab == SymbolType.HAS_VAR
        else lspt.CompletionItemKind.Method
        if sub_tab == SymbolType.METHOD
        else lspt.CompletionItemKind.EnumMember
        if sub_tab == SymbolType.ENUM_MEMBER
        else lspt.CompletionItemKind.Interface
        if sub_tab == SymbolType.IMPL
        else lspt.CompletionItemKind.Variable
    );
}

"""Map the symbol node to an lspt.SymbolKind."""
impl kind_map(sub_tab: uni.UniNode) -> lspt.SymbolKind {
    return lspt.SymbolKind.Function
    if isinstance(sub_tab, (uni.Ability, uni.ImplDef))
    else lspt.SymbolKind.Class
    if isinstance(sub_tab, (uni.Archetype, uni.ImplDef))
    else lspt.SymbolKind.Module
    if isinstance(sub_tab, uni.Module)
    else lspt.SymbolKind.Enum
    if isinstance(sub_tab, (uni.Enum, uni.ImplDef))
    else lspt.SymbolKind.Variable;
}

"""Create an lspt.Range from a location object."""
impl create_range(loc: CodeLocInfo) -> lspt.Range {
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

"""Get owner sym."""
impl owner_sym(table: UniScopeNode) -> Optional[Symbol] {
    if table.parent_scope and isinstance(table, uni.AstSymbolNode) {
        return table.parent_scope.lookup(table.sym_name);
    }
    return None;
}

"""Recursively collect symbols from the AST."""
impl get_symbols_for_outline(<>node: UniScopeNode) -> list[lspt.DocumentSymbol] {
    symbols = [];
    for (key, item) in <>node.names_in_scope.items() {
        if key in dir(builtins)
        or item in [owner_sym(tab) for tab in <>node.kid_scope]
        or item.decl.loc.mod_path != <>node.loc.mod_path {
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
        for i in <>node.kid_scope
        if i.loc.mod_path == <>node.loc.mod_path
    ] {
        sub_symbols = get_symbols_for_outline(sub_tab);
        if isinstance(
            sub_tab,
            (uni.IfStmt, uni.ElseStmt, uni.WhileStmt, uni.IterForStmt, uni.InForStmt)
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

"""Find index."""
impl find_index(sem_tokens: list[int], line: int, char: int) -> Optional[int] {
    index = None;
    token_start_list = [
        get_token_start(i, sem_tokens) for i in range(0, len(sem_tokens), 5)
    ];
    for (i, j) in enumerate(token_start_list) {
        if j[0] == line and j[1] <= char <= j[2] {
            return i;
        }
    }
    return index;
}

"""Check if the position falls within the node's location."""
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
    return
    # All lines and columns are 1-Based
    True;
}

"""Return the deepest symbol node that contains the given position."""
impl find_deepest_symbol_node_at_pos(
    <>node: uni.UniNode, line: int, character: int
) -> Optional[uni.AstSymbolNode] {
    last_symbol_node = None;
    if position_within_node(<>node, line, character) {
        if isinstance(<>node, uni.AstSymbolNode) {
            last_symbol_node = <>node;
        }
        for child in [
            i
            for i in <>node.kid
            if i.loc.mod_path == <>node.loc.mod_path
        ] {
            if position_within_node(child, line, character) {
                deeper_node = find_deepest_symbol_node_at_pos(child, line, character);
                if deeper_node is not None {
                    last_symbol_node = deeper_node;
                }
            }
        }
    }
    return last_symbol_node;
}

"""Iterate through symbol table."""
impl sym_tab_list(sym_tab: UniScopeNode, file_path: str) -> list[UniScopeNode] {
    sym_tabs = [sym_tab]
    if not (isinstance(sym_tab, uni.Module) and sym_tab.loc.mod_path != file_path)
    else [];
    for i in sym_tab.kid_scope {
        sym_tabs += sym_tab_list(i, file_path=file_path);
    }
    return sym_tabs;
}

"""Debounce decorator for async functions."""
impl debounce(<>wait: float) -> Callable[[T], Callable[(..., Awaitable[None])]] {
    def decorator(fn: T) -> Callable[P, Awaitable[None]] {
        @wraps(fn)
        async def debounced(*args: P.args, **kwargs: P.kwargs) -> None {
            async def call_it -> None {
                await fn(*args, _=kwargs);
            }
            if debounced?._task {
                debounced._task.cancel();
            }
            async def debounced_coro -> None {
                try {
                    await asyncio.sleep(<>wait);
                    await call_it();
                } except asyncio.CancelledError {
                    ;
                }
            }
            setattr(debounced, '_task', asyncio.create_task(debounced_coro()));
        }
        return debounced;
    }
    return decorator;
}

"""Return diagnostics."""
impl gen_diagnostics(
    from_path: str, errors: list[Alert], warnings: list[Alert]
) -> list[lspt.Diagnostic] {
    return [
        lspt.Diagnostic(
            range=create_range(error.loc),
            message=error.msg,
            severity=lspt.DiagnosticSeverity.Error
        )
        for error in errors
        if error.loc.mod_path == from_path
    ] + [
        lspt.Diagnostic(
            range=create_range(warning.loc),
            message=warning.msg,
            severity=lspt.DiagnosticSeverity.Warning
        )
        for warning in warnings
        if warning.loc.mod_path == from_path
    ];
}
