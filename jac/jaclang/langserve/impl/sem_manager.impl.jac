"""Semantic Token Manager Implementation."""

"""Initialize semantic token manager."""
impl SemTokManager.postinit -> None {
    self.sem_tokens = self.gen_sem_tokens(self.ir);
    self.static_sem_tokens = self.gen_sem_tok_node(self.ir);
}

"""Collect all resolved NameAtom nodes from the module IR.

Iterates all in-module nodes and collects those with valid semantic tokens.
"""
impl SemTokManager.collect_resolved_nodes(ir: uni.Module) -> list {
    nodes: list = [];
    for nd in ir._in_mod_nodes {
        if isinstance(nd, uni.NameAtom) {
            if nd.sem_token {
                nodes.append(nd);
            }
        }
    }
    return nodes;
}

"""Return semantic tokens as position-mapped nodes."""
impl SemTokManager.gen_sem_tok_node(
    ir: uni.Module
) -> List[Tuple[(lspt.Position, int, int, uni.AstSymbolNode)]] {
    tokens: List[Tuple[(lspt.Position, int, int, uni.AstSymbolNode)]] = [];
    seen_locs: dict = {};
    try {
        for nd in self.collect_resolved_nodes(ir) {
            (line, col_start, col_end) = (
                (nd.loc.first_line - 1),
                (nd.loc.col_start - 1),
                (nd.loc.col_end - 1)
            );
            loc_key = (line, col_start);
            if loc_key not in seen_locs {
                seen_locs[loc_key] = True;
                length = col_end - col_start;
                pos = lspt.Position(line, col_start);
                tokens.append((pos, col_end, length, nd));
            }
        }
    } except Exception as e {
        logger.error(f"Error generating semantic token nodes: {e}");
    }
    return tokens;
}

"""Return semantic tokens as delta-encoded flat list."""
impl SemTokManager.gen_sem_tokens(ir: uni.Module) -> list[int] {
    tokens = [];
    seen_locs: dict = {};
    try {
        for nd in self.collect_resolved_nodes(ir) {
            if nd.sem_token {
                (line, col_start, col_end) = (
                    (nd.loc.first_line - 1),
                    (nd.loc.col_start - 1),
                    (nd.loc.col_end - 1)
                );
                loc_key = (line, col_start);
                if loc_key not in seen_locs {
                    seen_locs[loc_key] = True;
                    length = col_end - col_start;
                    tokens.append(
                        (line, col_start, length, nd.sem_token[0], nd.sem_token[1])
                    );
                }
            }
        }
    } except Exception as e {
        logger.error(f"Error generating semantic tokens: {e}");
    }
    # Sort by (line, col) and convert to delta format
    tokens.sort(key=lambda x: Any : (x[0], x[1]));
    result = [];
    (prev_line, prev_col) = (0, 0);
    for (line, col_start, length, tok_type, tok_mod) in tokens {
        result += [
            (line - prev_line),
            col_start if line != prev_line else (col_start - prev_col),
            length,
            tok_type,
            tok_mod
        ];
        (prev_line, prev_col) = (line, col_start);
    }
    return result;
}

"""Handle insert inside token."""
impl SemTokManager.handle_insert_inside_token(
    self: SemTokManager,
    change: lspt.TextDocumentContentChangeEvent_Type1,
    sem_tokens: list[int],
    prev_token_index: int,
    changing_line_text: tuple[(str, int)],
    line_delta: int,
    prev_tok_pos: tuple[(int, int, int)],
    change_start_char: int,
    change_end_char: int,
    is_token_boundary_edit: bool,
    nxt_tok_pos: tuple[(int, int, int)]
) -> tuple[list[int], bool, tuple[(int, int, int)], Optional[int]] {
    next_token_index = None;
    tok_count = len(sem_tokens);
    for i in ['\n', ' ', '\t'] {
        if i in change.text {
            if prev_tok_pos[1] == change_start_char {
                if i == '\n' {
                    if prev_token_index + TOK_LINE_DELTA < tok_count {
                        sem_tokens[prev_token_index + TOK_LINE_DELTA] += line_delta;
                    }
                    if prev_token_index + TOK_COL_DELTA < tok_count {
                        sem_tokens[prev_token_index + TOK_COL_DELTA] = changing_line_text[
                            1
                        ];
                    }
                } else {
                    if prev_token_index + TOK_COL_DELTA < tok_count {
                        sem_tokens[prev_token_index + TOK_COL_DELTA] += len(
                            change.text
                        );
                    }
                }
                return (
                    sem_tokens,
                    is_token_boundary_edit,
                    nxt_tok_pos,
                    next_token_index
                );
            } else {
                is_token_boundary_edit = True;
                next_token_index = prev_token_index + TOK_STRIDE;
                nxt_tok_pos = get_token_start(next_token_index, sem_tokens);
                break;
            }
        }
    }
    if not is_token_boundary_edit {
        selected_region = change_end_char - change_start_char;
        if prev_token_index + TOK_LENGTH < tok_count {
            sem_tokens[prev_token_index + TOK_LENGTH] += (
                len(change.text) - selected_region
            );
        }
        next_tok_start = prev_token_index + TOK_STRIDE;
        if (
            prev_tok_pos[0] == get_token_start(next_tok_start, sem_tokens)[0]
            and next_tok_start + TOK_COL_DELTA < tok_count
        ) {
            sem_tokens[next_tok_start + TOK_COL_DELTA] += (
                len(change.text) - selected_region
            );
        }
    }
    return (sem_tokens, is_token_boundary_edit, nxt_tok_pos, next_token_index);
}

"""Handle multi line insertion."""
impl SemTokManager.handle_multi_line_insertion(
    self: SemTokManager,
    sem_tokens: list[int],
    next_token_index: int,
    nxt_tok_pos: tuple[(int, int, int)],
    change_start_line: int,
    change_end_line: int,
    change_end_char: int,
    prev_tok_pos: tuple[(int, int, int)],
    tokens_on_same_line: bool,
    changing_line_text: tuple[(str, int)],
    line_delta: int
) -> list[int] {
    tok_count = len(sem_tokens);
    if tokens_on_same_line {
        char_del = nxt_tok_pos[1] - change_end_char;
        total_char_del = changing_line_text[1] + char_del;
    } else {
        is_prev_token_same_line = change_end_line == prev_tok_pos[0];
        is_next_token_same_line = change_start_line == nxt_tok_pos[0];
        if is_prev_token_same_line {
            total_char_del = nxt_tok_pos[1];
        } elif is_next_token_same_line {
            char_del = nxt_tok_pos[1] - change_end_char;
            total_char_del = changing_line_text[1] + char_del;
        } else {
            total_char_del = sem_tokens[next_token_index + TOK_COL_DELTA]
            if next_token_index + TOK_COL_DELTA < tok_count
            else 0;
            line_delta -= change_end_line - change_start_line;
        }
    }
    if next_token_index + TOK_COL_DELTA < tok_count {
        sem_tokens[next_token_index + TOK_COL_DELTA] = total_char_del;
    }
    if next_token_index + TOK_LINE_DELTA < tok_count {
        sem_tokens[next_token_index + TOK_LINE_DELTA] += line_delta;
    }
    return sem_tokens;
}

"""Handle single line insertion."""
impl SemTokManager.handle_single_line_insertion(
    self: SemTokManager,
    sem_tokens: list[int],
    next_token_index: int,
    is_next_token_same_line: bool,
    change: lspt.TextDocumentContentChangeEvent_Type1,
    tokens_on_same_line: bool,
    nxt_tok_pos: tuple[(int, int, int)],
    change_start_line: int,
    line_delta: int
) -> list[int] {
    tok_count = len(sem_tokens);
    if tokens_on_same_line {
        if next_token_index + TOK_COL_DELTA < tok_count {
            sem_tokens[next_token_index + TOK_COL_DELTA] += len(change.text);
        }
        if next_token_index + TOK_LINE_DELTA < tok_count {
            sem_tokens[next_token_index + TOK_LINE_DELTA] += line_delta;
        }
    } else {
        is_next_token_same_line = change_start_line == nxt_tok_pos[0];
        if is_next_token_same_line {
            if next_token_index + TOK_LINE_DELTA < tok_count {
                sem_tokens[next_token_index + TOK_LINE_DELTA] += line_delta;
            }
            if next_token_index + TOK_COL_DELTA < tok_count {
                sem_tokens[next_token_index + TOK_COL_DELTA] += len(change.text);
            }
        } else {
            if next_token_index + TOK_LINE_DELTA < tok_count {
                sem_tokens[next_token_index + TOK_LINE_DELTA] += line_delta;
            }
        }
    }
    return sem_tokens;
}

"""Handle single line deletion."""
impl SemTokManager.handle_single_line_delete(
    self: SemTokManager,
    sem_tokens: list[int],
    next_token_index: int,
    prev_token_index: int,
    is_next_token_same_line: bool,
    change: lspt.TextDocumentContentChangeEvent_Type1
) -> list[int] {
    if change.range_length is None {
        logger.warning("handle_single_line_delete: range_length is None, skipping");
        return sem_tokens;
    }
    tok_count = len(sem_tokens);
    if prev_token_index + TOK_LENGTH < tok_count {
        sem_tokens[prev_token_index + TOK_LENGTH] -= change.range_length;
    }
    if is_next_token_same_line and next_token_index + TOK_COL_DELTA < tok_count {
        sem_tokens[next_token_index + TOK_COL_DELTA] -= change.range_length;
    }
    return sem_tokens;
}

"""Handle single line deletion between tokens."""
impl SemTokManager.handle_single_line_delete_between_tokens(
    self: SemTokManager,
    sem_tokens: list[int],
    next_token_index: int,
    is_next_token_same_line: bool,
    change: lspt.TextDocumentContentChangeEvent_Type1,
    change_start_line: int,
    change_end_line: int
) -> list[int] {
    tok_count = len(sem_tokens);
    if is_next_token_same_line and change.range_length {
        if next_token_index + TOK_COL_DELTA < tok_count {
            sem_tokens[next_token_index + TOK_COL_DELTA] -= change.range_length;
        }
    } else {
        if next_token_index + TOK_LINE_DELTA < tok_count {
            sem_tokens[next_token_index + TOK_LINE_DELTA] -= change_end_line - change_start_line;
        }
    }
    return sem_tokens;
}

"""Handle multi line deletion."""
impl SemTokManager.handle_multi_line_delete(
    self: SemTokManager,
    sem_tokens: list[int],
    next_token_index: int,
    nxt_tok_pos: tuple[(int, int, int)],
    change_start_line: int,
    change_end_line: int,
    change_start_char: int,
    change_end_char: int,
    prev_tok_pos: tuple[(int, int, int)],
    is_next_token_same_line: bool
) -> list[int] {
    tok_count = len(sem_tokens);
    if is_next_token_same_line {
        char_del = nxt_tok_pos[1] - change_end_char;
        total_char_del = change_start_char + char_del;
        if next_token_index + TOK_COL_DELTA < tok_count {
            sem_tokens[next_token_index + TOK_COL_DELTA] = (
                total_char_del - prev_tok_pos[1]
            )
            if prev_tok_pos[0] == change_start_line
            else total_char_del;
        }
    }
    if next_token_index + TOK_LINE_DELTA < tok_count {
        sem_tokens[next_token_index + TOK_LINE_DELTA] -= change_end_line - change_start_line;
    }
    return sem_tokens;
}

"""Update semantic tokens on change."""
impl SemTokManager.update_sem_tokens(
    content_changes: lspt.DidChangeTextDocumentParams,
    sem_tokens: list[int],
    document_lines: List[str]
) -> list[int] {
    try {
        for change in [
            x
            for x in content_changes.content_changes
            if isinstance(x, lspt.TextDocumentContentChangeEvent_Type1)
        ] {
            change_start_line = change.range.start.line;
            change_start_char = change.range.start.character;
            change_end_line = change.range.end.line;
            change_end_char = change.range.end.character;
            is_delete = change.text == '';
            (prev_token_index, next_token_index, insert_inside_token) = find_surrounding_tokens(
                change_start_line,
                change_start_char,
                change_end_line,
                change_end_char,
                sem_tokens
            );
            prev_tok_pos = get_token_start(prev_token_index, sem_tokens);
            nxt_tok_pos = get_token_start(next_token_index, sem_tokens);
            changing_line_text = get_line_of_code(change_start_line, document_lines);
            if not changing_line_text {
                return sem_tokens;
            }
            is_edit_between_tokens = bool(
                change_start_line > prev_tok_pos[0]
                or change_start_line == prev_tok_pos[0]
                and change_start_char > (
                    prev_tok_pos[1] + sem_tokens[(prev_token_index + TOK_LENGTH)]
                )
                if prev_token_index
                and (prev_token_index + TOK_LENGTH) < len(sem_tokens)
                else 0
                and change_end_line < nxt_tok_pos[0]
                or change_end_line == nxt_tok_pos[0]
                and change_end_char < nxt_tok_pos[1]
            );
            text = '%s' % change.text;
            line_delta = len(text.split('\n')) - 1;
            is_multiline_insertion = line_delta > 0;
            is_next_token_same_line = change_end_line == nxt_tok_pos[0];
            if is_delete {
                next_token_index = (prev_token_index + TOK_STRIDE)
                if insert_inside_token
                and prev_token_index is not None
                or next_token_index
                and prev_token_index is not None
                and next_token_index >= 2 * TOK_STRIDE
                and (next_token_index - prev_token_index) == 2 * TOK_STRIDE
                else next_token_index;
                if next_token_index is None {
                    return sem_tokens;
                }
                nxt_tok_pos = get_token_start(next_token_index, sem_tokens);
                is_single_line_change = change_end_line == change_start_line;
                is_next_token_same_line = change_end_line == nxt_tok_pos[0];
                if is_single_line_change
                and insert_inside_token
                and prev_token_index is not None {
                    sem_tokens = SemTokManager.handle_single_line_delete(
                        self,
                        sem_tokens,
                        next_token_index,
                        prev_token_index,
                        is_next_token_same_line,
                        change
                    );
                } elif is_single_line_change and is_edit_between_tokens {
                    sem_tokens = SemTokManager.handle_single_line_delete_between_tokens(
                        self,
                        sem_tokens,
                        next_token_index,
                        is_next_token_same_line,
                        change,
                        change_start_line,
                        change_end_line
                    );
                } else {
                    sem_tokens = SemTokManager.handle_multi_line_delete(
                        self,
                        sem_tokens,
                        next_token_index,
                        nxt_tok_pos,
                        change_start_line,
                        change_end_line,
                        change_start_char,
                        change_end_char,
                        prev_tok_pos,
                        is_next_token_same_line
                    );
                }
                return sem_tokens;
            }
            is_token_boundary_edit = False;
            if insert_inside_token and prev_token_index is not None {
                (sem_tokens, is_token_boundary_edit, nxt_tok_pos, next_token_index) = SemTokManager.handle_insert_inside_token(
                    self,
                    change,
                    sem_tokens,
                    prev_token_index,
                    changing_line_text,
                    line_delta,
                    prev_tok_pos,
                    change_start_char,
                    change_end_char,
                    is_token_boundary_edit,
                    nxt_tok_pos
                );
            }
            tokens_on_same_line = prev_tok_pos[0] == nxt_tok_pos[0];
            if is_edit_between_tokens
            or is_token_boundary_edit
            or is_multiline_insertion
            and next_token_index is not None {
                if is_multiline_insertion {
                    sem_tokens = SemTokManager.handle_multi_line_insertion(
                        self,
                        sem_tokens,
                        next_token_index,
                        nxt_tok_pos,
                        change_start_line,
                        change_end_line,
                        change_end_char,
                        prev_tok_pos,
                        tokens_on_same_line,
                        changing_line_text,
                        line_delta
                    );
                } else {
                    sem_tokens = SemTokManager.handle_single_line_insertion(
                        self,
                        sem_tokens,
                        next_token_index,
                        is_next_token_same_line,
                        change,
                        tokens_on_same_line,
                        nxt_tok_pos,
                        change_start_line,
                        line_delta
                    );
                }
            }
        }
    } except Exception as e {
        logger.error(f"Error updating semantic tokens: {e}");
    }
    return sem_tokens;
}
