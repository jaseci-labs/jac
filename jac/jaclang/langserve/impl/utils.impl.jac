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
    return (current_line, current_char, 0);
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

impl owner_sym(table: UniScopeNode) -> Optional[Symbol] {
    if table.parent_scope and isinstance(table, uni.AstSymbolNode) {
        return table.parent_scope.lookup(table.sym_name);
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

impl debounce(`wait: float) -> Callable[[T], Callable[(..., Awaitable[None])]] {
    def decorator(fn: T) -> Callable[P, Awaitable[None]] {
        @wraps(fn)
        async def debounced(*args: P.args, **kwargs: P.kwargs) {
            async def call_it {
                await fn(*args, _=kwargs);
            }
            if debounced?._task {
                debounced._task.cancel();
            }
            async def debounced_coro {
                try {
                    await asyncio.sleep(`wait);
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
    ] + [
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
