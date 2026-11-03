impl is_string_kind(kind_str: str) -> bool {
    return 'STRING' in kind_str or 'FSTR' in kind_str or 'JSX' in kind_str;
}

impl dotted_target(tokens: list[LexToken], start: int) -> str {
    parts: list[str] = [];
    j = start;
    while j < len(tokens) {
        val = tokens[j].value;
        if val in ('{', ';', 'as') {
            break;
        }
        parts.append(val);
        j += 1;
    }
    return ''.join(parts);
}

impl first_name_after(tokens: list[LexToken], start: int) -> str {
    j = start;
    while j < len(tokens) and j < start + 8 {
        tok = tokens[j];
        kind_str = str(tok.kind);
        if (
            not is_string_kind(kind_str)
            and tok.value not in (':', 'pub', 'priv', 'protect', 'async', 'static')
            and tok.value
            and (tok.value[0].isalpha() or tok.value[0] == '_')
            and tok.value not in ELEMENT_KEYWORDS
        ) {
            return tok.value;
        }
        j += 1;
    }
    return '';
}

impl collect_block_claims(
    tokens: list[LexToken], body_start: int, body_end: int, space: str, res: MarkerScan
) {
    depth = 0;
    j = body_start;
    while j < body_end {
        tok = tokens[j];
        if tok.value == '{' and str(tok.kind) == 'TokenKind.LBRACE' {
            depth += 1;
        } elif tok.value == '}' and str(tok.kind) == 'TokenKind.RBRACE' {
            depth -= 1;
        } elif depth == 0 and not is_string_kind(str(tok.kind)) {
            if tok.value == 'import' and space == 'server' {
                k = j + 1;
                if k < body_end and tokens[k].value == 'from' {
                    tgt = dotted_target(tokens, k + 1);
                    if tgt {
                        res.sv_imports.append(ImportSpace(target=tgt, line=tok.loc.line));
                    }
                }
            } elif tok.value in NAMED_ELEMENT_KEYWORDS {
                nm = first_name_after(tokens, j + 1);
                if nm {
                    res.claims.append(
                        ElementSpace(name=nm, space=space, line=tok.loc.line)
                    );
                }
                while j < body_end
                    and tokens[j].value != '{'
                    and tokens[j].value != ';' {
                    j += 1;
                }
                continue;
            }
        }
        j += 1;
    }
}

impl marker_scan(src: str, file_path: str) -> MarkerScan {
    res = MarkerScan(text=src);
    (tokens, err_count) = tokenize(src, file_path);
    if err_count {
        res.note = "lex errors; skipped";
        return res;
    }
    edits: list[tuple[int, int, str]] = [];
    depth = 0;
    stmt_start = True;
    i = 0;
    n = len(tokens);
    while i < n {
        tok = tokens[i];
        kind_str = str(tok.kind);
        if tok.value == '{' and kind_str == 'TokenKind.LBRACE' {
            depth += 1;
            stmt_start = False;
            i += 1;
            continue;
        }
        if tok.value == '}' and kind_str == 'TokenKind.RBRACE' {
            depth -= 1;
            stmt_start = depth == 0;
            i += 1;
            continue;
        }
        if tok.value == ';' {
            stmt_start = depth == 0;
            i += 1;
            continue;
        }
        if depth == 0 and 'STRING' in kind_str {
            stmt_start = True;
            i += 1;
            continue;
        }
        if (
            depth == 0
            and stmt_start
            and tok.value in MARKER_SPACES
            and not is_string_kind(kind_str)
            and i + 1 < n
        ) {
            space = MARKER_SPACES[tok.value];
            nxt = tokens[i + 1];
            if nxt.value == '{' and str(nxt.kind) == 'TokenKind.LBRACE' {
                d = 1;
                j = i + 2;
                close_idx = -1;
                while j < n {
                    jv = tokens[j];
                    if jv.value == '{' and str(jv.kind) == 'TokenKind.LBRACE' {
                        d += 1;
                    } elif jv.value == '}' and str(jv.kind) == 'TokenKind.RBRACE' {
                        d -= 1;
                        if d == 0 {
                            close_idx = j;
                            break;
                        }
                    }
                    j += 1;
                }
                if close_idx < 0 {
                    res.note = "unbalanced marker block; skipped";
                    return res;
                }
                edits.append((tok.loc.pos_start, nxt.loc.pos_end, ''));
                edits.append(
                    (tokens[close_idx].loc.pos_start, tokens[close_idx].loc.pos_end, '')
                );
                collect_block_claims(tokens, i + 2, close_idx, space, res);
                depth += 1;
                i += 2;
                continue;
            }
            if nxt.value in ELEMENT_KEYWORDS and not is_string_kind(str(nxt.kind)) {
                edits.append((tok.loc.pos_start, nxt.loc.pos_start, ''));
                if nxt.value == 'import' {
                    if space == 'server'
                        and i + 2 < n
                        and tokens[i + 2].value == 'from' {
                        tgt = dotted_target(tokens, i + 3);
                        if tgt {
                            res.sv_imports.append(
                                ImportSpace(target=tgt, line=nxt.loc.line)
                            );
                        }
                    }
                } elif nxt.value in NAMED_ELEMENT_KEYWORDS {
                    nm = first_name_after(tokens, i + 2);
                    if nm {
                        res.claims.append(
                            ElementSpace(name=nm, space=space, line=tok.loc.line)
                        );
                    }
                }
                i += 1;
                continue;
            }
        }
        if depth == 0 {
            stmt_start = False;
        }
        i += 1;
    }
    if not edits {
        return res;
    }
    edits.sort();
    src_bytes = src.encode('utf-8');
    out: list[bytes] = [];
    cursor = 0;
    for (start, end, repl) in edits {
        out.append(src_bytes[cursor:start]);
        out.append(repl.encode('utf-8'));
        out.append(b'\n' * src_bytes[start:end].count(b'\n'));
        cursor = end;
    }
    out.append(src_bytes[cursor:]);
    res.text = (b''.join(out)).decode('utf-8');
    res.changed = True;
    return res;
}

impl import_spaces(module: uni.Module) -> list[ImportSpace] {
    client: dict[tuple[int, str], bool] = {};
    read_by: dict[tuple[int, str], set[str]] = {};
    import_of: dict[tuple[int, int, str], list[tuple[int, str]]] = {};
    own_path = os.path.normpath(module.loc.mod_path);
    for stmt in module.body {
        if not isinstance(stmt, uni.Import)
            or stmt.from_loc is None
            or os.path.normpath(stmt.loc.mod_path) != own_path {
            continue;
        }
        key = (stmt.loc.first_line, stmt.from_loc.dot_path_str);
        space = stmt.code_context.value if stmt.code_context is not None else '';
        client[key] = client.get(key, True)
            and space == 'client'
            and not stmt.codespace_dual;
        read_by.setdefault(key, set());
        for item in stmt.items {
            if not isinstance(item, uni.ModuleItem) {
                continue;
            }
            bound = item.alias if item.alias is not None else item.name;
            if isinstance(bound, uni.Name) and bound.sym is not None {
                decl = bound.sym.decl.loc;
                import_of.setdefault(
                    (decl.first_line, decl.col_start, bound.value), []
                ).append(key);
            }
        }
    }
    for stmt in module.body {
        if isinstance(stmt, uni.Import) or not isinstance(stmt, uni.ContextAwareNode) {
            continue;
        }
        spaces = {stmt.code_context.value if stmt.code_context is not None else ''};
        if stmt.codespace_dual {
            spaces.add('server');
        }
        for nm in stmt.get_all_sub_nodes(uni.Name) {
            if nm.sym is None {
                continue;
            }
            decl = nm.sym.decl.loc;
            for owner in import_of.get((decl.first_line, decl.col_start, nm.value), []) {
                read_by[owner].update(spaces);
            }
        }
    }
    for (key, spaces) in read_by.items() {
        if spaces == {'client'} {
            client[key] = True;
        }
    }
    return [
        ImportSpace(target=key[1], line=key[0], client_only=only)
        for (key, only) in client.items()
    ];
}

impl top_element_spaces(module: uni.Module) -> list[ElementSpace] {
    out: list[ElementSpace] = [];
    for stmt in module.body {
        if not isinstance(stmt, uni.ContextAwareNode) {
            continue;
        }
        name = element_display_name(stmt);
        if not name {
            continue;
        }
        out.append(
            ElementSpace(
                name=name,
                space=stmt.code_context.value if stmt.code_context is not None else '',
                line=stmt.loc.first_line,
                dual=stmt.codespace_dual
            )
        );
    }
    return out;
}

impl module_has_jsx(decl: uni.UniNode) -> bool {
    return bool(decl.get_all_sub_nodes(uni.JsxElement));
}

impl returns_jsx(decl: uni.UniNode) -> bool {
    if not isinstance(decl, uni.Ability) or decl.signature is None {
        return False;
    }
    sig = decl.signature;
    if not isinstance(sig, uni.FuncSignature) or sig.return_type is None {
        return False;
    }
    return 'Jsx' in unparse_node(sig.return_type);
}

impl parse_module(path: str) -> (uni.Module | None) {
    with open(path, 'r') as f {
        src = f.read();
    }
    (mod, had_error) = rd_parse(src, path);
    return None if had_error else mod;
}

impl plain_top_decls(module: uni.Module) -> dict[str, uni.UniNode] {
    out: dict[str, uni.UniNode] = {};
    for item in module.body {
        if isinstance(item, (uni.Ability, uni.Archetype))
            and item.surface_kind
            and item.access is None {
            out[item.sym_name] = item;
        }
    }
    return out;
}

impl priv_top_decls(module: uni.Module) -> dict[str, uni.UniNode] {
    out: dict[str, uni.UniNode] = {};
    for item in module.body {
        if isinstance(item, (uni.Ability, uni.Archetype))
            and item.surface_kind
            and item.access is not None
            and item.exposure == SymbolAccess.PRIVATE {
            out[item.sym_name] = item;
        }
    }
    return out;
}

impl resolve_project_import(
    module_path: uni.ModulePath, importer: str, proj_root: str
) -> str {
    resolved = module_path.resolve_relative_path();
    if resolved and resolved.endswith('.jac') and os.path.isfile(resolved) {
        return os.path.realpath(resolved);
    }
    parts = [
        p
        for p in module_path.dot_path_str.split('.')
        if p
    ];
    if module_path.level > 0 {
        base_dir = os.path.dirname(importer);
        for _ in range(module_path.level - 1) {
            base_dir = os.path.dirname(base_dir);
        }
        candidate = os.path.join(base_dir, *parts) + '.jac';
    } else {
        candidate = os.path.join(proj_root, *parts) + '.jac';
    }
    return os.path.realpath(candidate) if os.path.isfile(candidate) else '';
}

impl imported_names(imp: uni.Import) -> list[str] {
    names: list[str] = [];
    for item in imp.items {
        if isinstance(item, uni.ModuleItem) and isinstance(item.name, uni.Name) {
            names.append(item.name.value);
        }
    }
    return names;
}

impl served_access_plan(proj_root: str) -> AccessPlan {
    ws = workspace_for_path(proj_root);
    plan = AccessPlan();
    if ws is None {
        plan.notes.append(f"{proj_root}: no jac.toml found, nothing to migrate");
        return plan;
    }
    serving = [
        a
        for a in ws.apps.values()
        if a.has_server
    ];
    if not serving {
        plan.notes.append(
            f"{ws.toml_path}: no serving app declared, nothing to migrate"
        );
        return plan;
    }
    seen: set[tuple[str, str]] = set();
    priv_seen: set[tuple[str, str]] = set();
    def add(path: str, decl: uni.UniNode, kind: str, reason: str) {
        if not isinstance(decl, uni.AstSymbolNode) {
            return;
        }
        key = (path, decl.sym_name);
        if key in seen or str(decl.sym_name).startswith('_') {
            return;
        }
        if kind == 'function' and (returns_jsx(decl) or module_has_jsx(decl)) {
            return;
        }
        seen.add(key);
        plan.rewrites.append(
            AccessRewrite(
                path=path,
                line=decl.name_spec.loc.first_line,
                kind=kind,
                name=decl.sym_name,
                reason=reason
            )
        );
    }
    project_real = os.path.realpath(ws.project_root);
    for app in serving {
        entry_rel = str(app.`entry or '').replace('.', os.sep);
        entry_path = os.path.join(ws.project_root, entry_rel + '.jac');
        if not os.path.isfile(entry_path) {
            entry_path = os.path.join(ws.project_root, str(app.`entry or ''));
        }
        if not os.path.isfile(entry_path) {
            plan.notes.append(
                f"app '{app.name}': entry '{app.`entry}' not found, skipped"
            );
            continue;
        }
        entry_path = os.path.realpath(entry_path);
        visited: set[tuple[str, bool]] = set();
        queue: list[tuple[str, bool]] = [(entry_path, True)];
        while queue {
            (path, is_entry) = queue.pop(0);
            if (path, is_entry) in visited {
                continue;
            }
            visited.add((path, is_entry));
            mod = parse_module(path);
            if mod is None {
                plan.notes.append(f"{path}: does not parse, skipped");
                continue;
            }
            for (pname, pdecl) in priv_top_decls(mod).items() {
                pkey = (path, pname);
                if pkey in priv_seen or not isinstance(pdecl, uni.AstSymbolNode) {
                    continue;
                }
                priv_seen.add(pkey);
                plan.notes.append(
                    f"{os.path.relpath(path)}:{pdecl.name_spec.loc.first_line}: "
                    f":priv {pname} was served (authenticated) before; it is now private. "
                    "Change it to :protect if it was meant to be an endpoint (left unchanged)."
                );
            }
            for (name, decl) in plain_top_decls(mod).items() {
                if isinstance(decl, uni.Ability) {
                    if is_entry {
                        add(
                            path,
                            decl,
                            'function',
                            f"plain def in entry of app '{app.name}'"
                        );
                    }
                } else {
                    add(
                        path,
                        decl,
                        'walker',
                        f"plain walker reachable from app '{app.name}'"
                    );
                }
            }
            for imp in mod.get_all_sub_nodes(uni.Import) {
                if not imp.is_jac {
                    continue;
                }
                module_path = imp.from_loc;
                if imp.is_absorb and imp.items and isinstance(imp.items[0], uni.ModulePath) {
                    module_path = imp.items[0];
                }
                if module_path is None {
                    continue;
                }
                target = resolve_project_import(module_path, path, ws.project_root);
                if not target or not target.startswith(project_real + os.sep) {
                    continue;
                }
                if is_entry and imp.items {
                    wanted = imported_names(imp);
                    tmod = parse_module(target);
                    if tmod is not None {
                        tplain = plain_top_decls(tmod);
                        for nm in wanted {
                            decl = tplain.get(nm);
                            if decl is not None and isinstance(decl, uni.Ability) {
                                add(
                                    target,
                                    decl,
                                    'function',
                                    f"plain def imported by entry of app '{app.name}'"
                                );
                            }
                        }
                    }
                }
                queue.append((target, is_entry and imp.is_absorb));
            }
        }
    }
    return plan;
}
