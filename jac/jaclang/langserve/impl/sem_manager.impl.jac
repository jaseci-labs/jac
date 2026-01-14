"""Handle insert inside token."""

impl SemTokManager.handle_insert_inside_token(
    self: SemTokManager,
    change: lspt.TextDocumentContentChangeEvent_Type1,
    sem_tokens: list[int],
    prev_token_index: int,
    changing_line_text: <>tuple[(str, int)],
    line_delta: int,
    prev_tok_pos: <>tuple[(int, int, int)],
    change_start_char: int,
    change_end_char: int,
    is_token_boundary_edit: bool,
    nxt_tok_pos: <>tuple[(int, int, int)]
) -> <>tuple[list[int], bool, <>tuple[(int, int, int)], Optional[int]] {
    next_token_index = None;
    for i in ['\n', ' ', '\t'] {
        if i in change.text {
            if prev_tok_pos[1] == change_start_char {
                if i == '\n' {
                    sem_tokens[prev_token_index] += line_delta;
                    sem_tokens[(prev_token_index + 1)] = changing_line_text[1];
                } else {
                    sem_tokens[(prev_token_index + 1)] += len(change.text);
                }
                return (
                    sem_tokens,
                    is_token_boundary_edit,
                    nxt_tok_pos,
                    next_token_index
                );
            } else {
                is_token_boundary_edit = True;
                next_token_index = prev_token_index + 5;
                nxt_tok_pos = get_token_start(next_token_index, sem_tokens);
                break;
            }
        }
    }
    if not is_token_boundary_edit {
        selected_region = change_end_char - change_start_char;
        index_offset = 2;
        sem_tokens[(prev_token_index + index_offset)] += (
            len(change.text) - selected_region
        );
        if prev_tok_pos[0] == get_token_start((prev_token_index + 5), sem_tokens)[0] {
            sem_tokens[((prev_token_index + index_offset) + 4)] += (
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
    nxt_tok_pos: <>tuple[(int, int, int)],
    change_start_line: int,
    change_end_line: int,
    change_end_char: int,
    prev_tok_pos: <>tuple[(int, int, int)],
    tokens_on_same_line: bool,
    changing_line_text: <>tuple[(str, int)],
    line_delta: int
) -> list[int] {
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
            total_char_del = sem_tokens[(next_token_index + 1)];
            line_delta -= change_end_line - change_start_line;
        }
    }
    sem_tokens[(next_token_index + 1)] = total_char_del;
    sem_tokens[next_token_index] += line_delta;
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
    nxt_tok_pos: <>tuple[(int, int, int)],
    change_start_line: int,
    line_delta: int
) -> list[int] {
    if tokens_on_same_line {
        sem_tokens[(next_token_index + 1)] += len(change.text);
        sem_tokens[next_token_index] += line_delta;
    } else {
        is_next_token_same_line = change_start_line == nxt_tok_pos[0];
        if is_next_token_same_line {
            sem_tokens[next_token_index] += line_delta;
            sem_tokens[(next_token_index + 1)] += len(change.text);
        } else {
            sem_tokens[next_token_index] += line_delta;
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
    assert change.range_length is not None;
    sem_tokens[(prev_token_index + 2)] -= change.range_length;
    if is_next_token_same_line {
        sem_tokens[(next_token_index + 1)] -= change.range_length;
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
    if is_next_token_same_line and change.range_length {
        sem_tokens[(next_token_index + 1)] -= change.range_length;
    } else {
        sem_tokens[next_token_index] -= change_end_line - change_start_line;
    }
    return sem_tokens;
}

"""Handle multi line deletion."""
impl SemTokManager.handle_multi_line_delete(
    self: SemTokManager,
    sem_tokens: list[int],
    next_token_index: int,
    nxt_tok_pos: <>tuple[(int, int, int)],
    change_start_line: int,
    change_end_line: int,
    change_start_char: int,
    change_end_char: int,
    prev_tok_pos: <>tuple[(int, int, int)],
    is_next_token_same_line: bool
) -> list[int] {
    if is_next_token_same_line {
        char_del = nxt_tok_pos[1] - change_end_char;
        total_char_del = change_start_char + char_del;
        sem_tokens[(next_token_index + 1)] = (total_char_del - prev_tok_pos[1])
        if prev_tok_pos[0] == change_start_line
        else total_char_del;
    }
    sem_tokens[next_token_index] -= change_end_line - change_start_line;
    return sem_tokens;
}

"""Update semantic tokens on change."""
impl SemTokManager.update_sem_tokens(
    content_changes: lspt.DidChangeTextDocumentParams,
    sem_tokens: list[int],
    document_lines: List[str]
) -> list[int] {
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
                prev_tok_pos[1] + sem_tokens[(prev_token_index + 2)]
            )
            if prev_token_index and (prev_token_index + 2) < len(sem_tokens)
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
            next_token_index = (prev_token_index + 5)
            if insert_inside_token
            and prev_token_index is not None
            or next_token_index
            and prev_token_index is not None
            and next_token_index >= 10
            and (next_token_index - prev_token_index) == 10
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
    return sem_tokens;
}

"""Return semantic tokens."""
impl SemTokManager.gen_sem_tok_node(
    ir: uni.Module
) -> List[Tuple[(lspt.Position, int, int, uni.AstSymbolNode)]] {
    import from jaclang.pycore.constant { JacSemTokenType }
    tokens: List[Tuple[(lspt.Position, int, int, uni.AstSymbolNode)]] = [];
    seen_locs: dict = {};  # Track (line, col) to avoid duplicates
    hub = self.hub;
    # Helper to resolve symbol from hub if not already set
    def resolve_symbol(nd: uni.NameAtom) -> None {
        if nd.sym is None and nd?.value {
            # Check if this is a member access (right side of AtomTrailer)
            parent = nd.parent;
            if isinstance(parent, uni.AtomTrailer)
            and parent.is_attr
            and parent.right == nd {
                # This is a member access like Task._task_id, resolve the target first
                target = parent.target;
                if isinstance(target, uni.NameAtom) and target.sym {
                    # Get the symbol table of the target (class/obj)
                    target_sym = target.sym;
                    if target_sym.decl
                    and isinstance(target_sym.decl.name_of, uni.Archetype) {
                        archetype = target_sym.decl.name_of;
                        # Look up the member in the archetype's symbol table
                        if member_sym := archetype.lookup(nd.value, deep=False) {
                            member_sym.add_use(nd);
                            nd.sym = member_sym;
                            if member_sym.decl and member_sym.decl.name_of {
                                nd.name_of = member_sym.decl.name_of;
                            }
                            # Set sem_token based on symbol type
                            if nd.sem_token is None
                            and member_sym.decl
                            and member_sym.decl.name_of {
                                decl = member_sym.decl.name_of;
                                if isinstance(decl, uni.HasVar) {
                                    nd.sem_token = (JacSemTokenType.PROPERTY, 0);
                                } elif isinstance(decl, uni.Ability) {
                                    nd.sem_token = (JacSemTokenType.FUNCTION, 0);
                                } else {
                                    nd.sem_token = (JacSemTokenType.VARIABLE, 0);
                                }
                            }
                            return;
                        }
                    }
                }
            }
            # Try to find the symbol from all loaded modules in the hub
            for (path, mod) in hub.items() {
                if symbol := mod.lookup(nd.value, deep=True, incl_inner_scope=True) {
                    # Resolve imported symbols if needed
                    if symbol?.via_import and symbol?.via_import {
                        if symbol.decl and symbol.decl?.name_of {
                            if isinstance(symbol.decl.name_of, uni.ModuleItem) {
                                if symbol.decl.name_of.sym {
                                    symbol = symbol.decl.name_of.sym;
                                }
                            }
                        }
                    }
                    symbol.add_use(nd);
                    nd.sym = symbol;
                    if symbol.decl and symbol.decl.name_of {
                        nd.name_of = symbol.decl.name_of;
                    }
                    # Also set sem_token based on symbol type
                    if nd.sem_token is None and symbol.decl and symbol.decl.name_of {
                        decl = symbol.decl.name_of;
                        if isinstance(decl, (uni.Architype, uni.Enum)) {
                            nd.sem_token = (JacSemTokenType.CLASS, 0);
                        } elif isinstance(decl, uni.Ability) {
                            nd.sem_token = (JacSemTokenType.FUNCTION, 0);
                        } elif isinstance(decl, uni.HasVar) {
                            nd.sem_token = (JacSemTokenType.PROPERTY, 0);
                        } else {
                            nd.sem_token = (JacSemTokenType.VARIABLE, 0);
                        }
                    }
                    break;
                }
            }
        }
    }
    # Helper to add a token
    def add_token(nd: uni.NameAtom) -> None {
        # Try to resolve symbol if not set
        resolve_symbol(nd);
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
                pos = lspt.Position(line, col_start);
                tokens.append((pos, col_end, length, nd));
            }
        }
    }
    # Process all NameAtom nodes in _in_mod_nodes
    for nd in ir._in_mod_nodes {
        if isinstance(nd, uni.NameAtom) {
            add_token(nd);
        }
    }
    # Also extract type annotation Name nodes from ImplDef specs
    # These may not be in _in_mod_nodes directly
    for nd in ir._in_mod_nodes {
        if isinstance(nd, uni.ImplDef) {
            if isinstance(nd.spec, uni.FuncSignature) {
                sig = nd.spec;
                all_params = (
                    list(sig.posonly_params) + list(sig.params) + (
                        [sig.varargs] if sig.varargs else []
                    ) + list(sig.kwonlyargs) + ([sig.kwargs] if sig.kwargs else [])
                );
                for param in all_params {
                    if param.type_tag and isinstance(param.type_tag, uni.SubTag) {
                        tag = param.type_tag.tag;
                        if isinstance(tag, uni.NameAtom) {
                            add_token(tag);
                        }
                    }
                }
                # Also check return type
                if sig.return_type and isinstance(sig.return_type, uni.NameAtom) {
                    add_token(sig.return_type);
                }
            }
        }
    }
    return tokens;
}

"""Return semantic tokens."""
impl SemTokManager.gen_sem_tokens(ir: uni.Module) -> list[int] {
    import from jaclang.pycore.constant { JacSemTokenType }
    tokens = [];
    (prev_line, prev_col) = (0, 0);
    seen_locs: dict = {};  # Track (line, col) to avoid duplicates
    hub = self.hub;
    # Helper to resolve symbol from hub if not already set
    def resolve_symbol(nd: uni.NameAtom) -> None {
        if nd.sym is None and nd?.value {
            # Check if this is a member access (right side of AtomTrailer)
            parent = nd.parent;
            if isinstance(parent, uni.AtomTrailer)
            and parent.is_attr
            and parent.right == nd {
                # This is a member access like Task._task_id, resolve the target first
                target = parent.target;
                if isinstance(target, uni.NameAtom) and target.sym {
                    # Get the symbol table of the target (class/obj)
                    target_sym = target.sym;
                    if target_sym.decl
                    and isinstance(target_sym.decl.name_of, uni.Archetype) {
                        archetype = target_sym.decl.name_of;
                        # Look up the member in the archetype's symbol table
                        if member_sym := archetype.lookup(nd.value, deep=False) {
                            member_sym.add_use(nd);
                            nd.sym = member_sym;
                            if member_sym.decl and member_sym.decl.name_of {
                                nd.name_of = member_sym.decl.name_of;
                            }
                            # Set sem_token based on symbol type
                            if nd.sem_token is None
                            and member_sym.decl
                            and member_sym.decl.name_of {
                                decl = member_sym.decl.name_of;
                                if isinstance(decl, uni.HasVar) {
                                    nd.sem_token = (JacSemTokenType.PROPERTY, 0);
                                } elif isinstance(decl, uni.Ability) {
                                    nd.sem_token = (JacSemTokenType.FUNCTION, 0);
                                } else {
                                    nd.sem_token = (JacSemTokenType.VARIABLE, 0);
                                }
                            }
                            return;
                        }
                    }
                }
            }
            # Try to find the symbol from all loaded modules in the hub
            for (path, mod) in hub.items() {
                if symbol := mod.lookup(nd.value, deep=True, incl_inner_scope=True) {
                    # Resolve imported symbols if needed
                    if symbol?.via_import and symbol?.via_import {
                        if symbol.decl and symbol.decl?.name_of {
                            if isinstance(symbol.decl.name_of, uni.ModuleItem) {
                                if symbol.decl.name_of.sym {
                                    symbol = symbol.decl.name_of.sym;
                                }
                            }
                        }
                    }
                    symbol.add_use(nd);
                    nd.sym = symbol;
                    if symbol.decl and symbol.decl.name_of {
                        nd.name_of = symbol.decl.name_of;
                    }
                    # Also set sem_token based on symbol type
                    if nd.sem_token is None and symbol.decl and symbol.decl.name_of {
                        decl = symbol.decl.name_of;
                        if isinstance(decl, (uni.Architype, uni.Enum)) {
                            nd.sem_token = (JacSemTokenType.CLASS, 0);
                        } elif isinstance(decl, uni.Ability) {
                            nd.sem_token = (JacSemTokenType.FUNCTION, 0);
                        } elif isinstance(decl, uni.HasVar) {
                            nd.sem_token = (JacSemTokenType.PROPERTY, 0);
                        } else {
                            nd.sem_token = (JacSemTokenType.VARIABLE, 0);
                        }
                    }
                    break;
                }
            }
        }
    }
    def add_token(nd: uni.NameAtom) -> None {
        # Try to resolve symbol if not set
        resolve_symbol(nd);
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
    for nd in ir._in_mod_nodes {
        if isinstance(nd, uni.NameAtom) {
            add_token(nd);
        }
    }
    # Also extract type annotation Name nodes from ImplDef specs
    for nd in ir._in_mod_nodes {
        if isinstance(nd, uni.ImplDef) {
            if isinstance(nd.spec, uni.FuncSignature) {
                sig = nd.spec;
                all_params = (
                    list(sig.posonly_params) + list(sig.params) + (
                        [sig.varargs] if sig.varargs else []
                    ) + list(sig.kwonlyargs) + ([sig.kwargs] if sig.kwargs else [])
                );
                for param in all_params {
                    if param.type_tag and isinstance(param.type_tag, uni.SubTag) {
                        tag = param.type_tag.tag;
                        if isinstance(tag, uni.NameAtom) {
                            add_token(tag);
                        }
                    }
                }
                # Also check return type
                if sig.return_type and isinstance(sig.return_type, uni.NameAtom) {
                    add_token(sig.return_type);
                }
            }
        }
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

"""Initialize semantic token manager."""
impl SemTokManager.postinit -> None {
    self.sem_tokens = self.gen_sem_tokens(self.ir);
    self.static_sem_tokens = self.gen_sem_tok_node(self.ir);
}
