impl span_at(loc: Span) -> SourceSpan {
    return SourceSpan(
        path=loc.mod_path,
        line=loc.first_line,
        col=loc.col_start,
        end_line=loc.last_line,
        end_col=loc.col_end
    );
}

impl file_start(path: str) -> SourceSpan {
    return SourceSpan(path=path, line=1, col=1, end_line=1, end_col=1);
}

impl position_within(nd: uni.UniNode, line: int, col: int) -> bool {
    loc = nd.loc;
    if loc.first_line < line < loc.last_line {
        return True;
    }
    if line < loc.first_line or line > loc.last_line {
        return False;
    }
    if line == loc.first_line and col < loc.col_start {
        return False;
    }
    if line == loc.last_line and col >= loc.col_end {
        return False;
    }
    return True;
}

impl belongs_to(nd: uni.UniNode, path: str) -> bool {
    mod_path = nd.loc.mod_path;
    return bool(mod_path) and os.path.realpath(mod_path) == path;
}

impl symbol_nodes(module: uni.Module, path: str) -> list[uni.NameAtom] {
    found: list[uni.NameAtom] = [];
    seen: set[tuple[int, int]] = set();
    for nd in module._in_mod_nodes or [] {
        if not isinstance(nd, uni.NameAtom) or not nd.sem_token {
            continue;
        }
        if not belongs_to(nd, path) {
            continue;
        }
        key = (nd.loc.first_line, nd.loc.col_start);
        if key in seen {
            continue;
        }
        seen.add(key);
        found.append(nd);
    }
    found.sort(key=lambda (n: uni.NameAtom) { (n.loc.first_line, n.loc.col_start); });
    return found;
}

impl token_at(
    module: uni.Module, path: str, line: int, col: int
) -> (uni.NameAtom | None) {
    for nd in symbol_nodes(module, path) {
        if nd.loc.first_line == line and nd.loc.col_start <= col <= nd.loc.col_end {
            return nd;
        }
    }
    return None;
}

impl node_at(
    module: uni.Module, line: int, col: int, path: str = ""
) -> (uni.Token | None) {
    for nd in module._in_mod_nodes or [] {
        if not isinstance(nd, uni.Token) or not position_within(nd, line, col) {
            continue;
        }
        if path and not belongs_to(nd, path) {
            continue;
        }
        return nd;
    }
    return None;
}

impl semantic_token_data(module: uni.Module, path: str) -> list[int] {
    data: list[int] = [];
    prev_line = 0;
    prev_col = 0;
    for nd in symbol_nodes(module, path) {
        line = nd.loc.first_line - 1;
        col = nd.loc.col_start - 1;
        length = nd.loc.col_end - nd.loc.col_start;
        data.extend(
            [
                line - prev_line,
                col if line != prev_line else col - prev_col,
                length,
                nd.sem_token[0],
                nd.sem_token[1]
            ]
        );
        prev_line = line;
        prev_col = col;
    }
    return data;
}

impl doc_of_symbol(sym: uni.Symbol) -> str {
    if not sym.decl {
        return "";
    }
    decl = sym.decl.name_of;
    if isinstance(decl, uni.AstDocNode) and decl.doc {
        doc_lit = decl.doc.lit_value;
        if isinstance(doc_lit, str) {
            return doc_lit;
        }
    }
    if isinstance(decl, uni.HasVar) {
        arch_has = decl.find_parent_of_type(uni.ArchHas);
        if arch_has is not None and arch_has.doc {
            arch_doc_lit = arch_has.doc.lit_value;
            if isinstance(arch_doc_lit, str) {
                return arch_doc_lit;
            }
        }
    }
    return "";
}

impl hover_text(nd: uni.NameAtom) -> str {
    if nd.is_getattr_resolved {
        return f"(dynamic attribute) {nd.value}: {nd.type}";
    }
    owner = nd.name_of;
    if not isinstance(owner, uni.AstSymbolNode) {
        return "";
    }
    access = (owner.sym.access.value + " ") if owner.sym else "";
    info = f"({access}{owner.sym_category.value}) {owner.sym_name}";
    if not isinstance(owner, uni.Ability) {
        if isinstance(owner, uni.Expr) and owner.type is not None {
            info += f": {owner.type}";
        } elif owner.name_spec.clean_type {
            info += f": {owner.name_spec.clean_type}";
        } elif isinstance(owner.name_spec.type, ClassType) {
            info += f": {owner.name_spec.type.shared.class_name}";
        }
    }
    if owner.sym {
        doc = doc_of_symbol(owner.sym);
        if doc {
            info += f"\n{doc}";
        }
    }
    if isinstance(owner, uni.Ability) and owner.signature {
        info += f"\n{unparse_node(owner.signature)}";
    }
    top = owner.top_element or owner;
    if isinstance(top, uni.ContextAwareNode) {
        tags: list[str] = [];
        if top.codespace_dual {
            tags.append("dual");
        }
        tags.append("inferred");
        info += f"\nplacement: {owner.codespace().value} ({', '.join(tags)})";
    }
    return info.strip();
}

impl definition_symbol(sym: uni.Symbol) -> uni.Symbol {
    cur = sym;
    seen: set[int] = set();
    while cur.provider is not None and id(cur) not in seen {
        seen.add(id(cur));
        target = cur.provider.definition();
        if target is None or target is cur {
            break;
        }
        cur = target;
    }
    return cur;
}

impl module_spec_target(mp: uni.ModulePath) -> str {
    resolved = mp.resolve_relative_path();
    if resolved and os.path.isfile(resolved) {
        return resolved;
    }
    spec = mp.string_path_value or mp.dot_path_str;
    src_path = mp.loc.mod_path;
    if not spec or not src_path or not in_client_npm_world(spec, src_path) {
        return "";
    }
    return resolve_client_npm_declarations(spec, src_path)
        or resolve_client_npm_package(spec, src_path)
        or "";
}

impl string_import_definition(
    module: uni.Module, line: int, col: int
) -> list[SourceSpan] {
    tok = node_at(module, line, col);
    if not isinstance(tok, uni.String) or not isinstance(tok.parent, uni.ModulePath) {
        return [];
    }
    target = module_spec_target(tok.parent);
    return [file_start(target)] if target else [];
}

impl definition_spans(program: JacProgram, nd: uni.NameAtom) -> list[SourceSpan] {
    ty: (TypeBase | None) = nd.type if isinstance(nd, uni.Expr) else None;
    parent = nd.parent;
    if isinstance(parent, uni.AstImplNeedingNode) and parent.body {
        body_nd = parent.body;
        if isinstance(body_nd, uni.ImplDef) and body_nd.sym {
            return [span_at(body_nd.sym.decl.loc)];
        }
    }
    if isinstance(ty, ModuleType) {
        return [file_start(str(ty.file_uri))];
    }
    if isinstance(parent, uni.ModulePath) and parent.path {
        index = -1;
        for (position, part) in enumerate(parent.path) {
            if part is nd {
                index = position;
            }
        }
        targets = parent.resolve_relative_path_list();
        if 0 <= index < len(targets) and os.path.exists(targets[index]) {
            return [file_start(targets[index])];
        }
    }
    if isinstance(parent, uni.ModuleItem) and isinstance(nd, uni.Name) {
        if nd.sym and nd.sym.defn and nd.sym.defn[0].loc.mod_path != nd.loc.mod_path {
            return [span_at(nd.sym.defn[0].loc)];
        }
        import_node = parent.parent_of_type(uni.Import);
        if import_node is not None and import_node.from_loc {
            mod_path = import_node.from_loc.resolve_relative_path();
            if mod_path and os.path.isfile(mod_path) {
                target_mod = program.mod.hub.get(os.path.realpath(mod_path));
                if target_mod is not None {
                    sym = target_mod.lookup(nd.value, deep=True, incl_inner_scope=True);
                    if sym is not None and sym.defn {
                        return [span_at(sym.defn[0].loc)];
                    }
                }
                return [file_start(mod_path)];
            }
            target = module_spec_target(import_node.from_loc);
            if target {
                declared = dts_declaration(target, parent.name.value)
                    if target.endswith(".d.ts")
                    else None;
                return [declared or file_start(target)];
            }
        }
    }
    if isinstance(ty, (ClassType, FunctionType, OverloadedType)) and nd.sym {
        return [span_at(definition_symbol(nd.sym).decl.loc)];
    }
    if isinstance(parent, uni.ImplDef) and parent.decl_link {
        decl_link = parent.decl_link;
        if isinstance(decl_link, uni.AstSymbolNode) and decl_link.sym {
            return [span_at(decl_link.sym.decl.loc)];
        }
    }
    if nd.sym and nd.sym.defn {
        first = definition_symbol(nd.sym).defn[0];
        if first is nd
            or (
                first.loc.mod_path == nd.loc.mod_path
                and first.loc.first_line == nd.loc.first_line
                and first.loc.col_start == nd.loc.col_start
            ) {
            return [];
        }
        return [span_at(first.loc)];
    }
    return [];
}

impl dts_declaration(dts_path: str, name: str) -> (SourceSpan | None) {
    with open(dts_path, "r", encoding="utf-8", errors="replace") as handle {
        src = handle.read();
    }
    escaped = re.escape(name);
    if name == "default" {
        patterns = [r"(?m)^[ \t]*export[ \t]+(default)\b"];
    } else {
        patterns = [
            r"(?m)^[ \t]*(?:export[ \t]+)?(?:declare[ \t]+)?(?:abstract[ \t]+)?"
            r"(?:const|let|var|function|class|interface|enum|namespace|type)"
            r"[ \t]+(" + escaped + r")\b",
            r"export[ \t]+(?:type[ \t]+)?\{[^{}]*?\b(" + escaped + r")\b"
        ];
    }
    for pattern in patterns {
        found = re.search(pattern, src);
        if found {
            start = found.start(1);
            line = src.count("\n", 0, start) + 1;
            col = start - (src.rfind("\n", 0, start) + 1) + 1;
            return SourceSpan(
                path=dts_path,
                line=line,
                col=col,
                end_line=line,
                end_col=col + len(found.group(1))
            );
        }
    }
    return None;
}

impl reference_spans(nd: uni.NameAtom) -> list[SourceSpan] {
    if not nd.sym {
        return [];
    }
    return [span_at(occ.loc) for occ in [*nd.sym.defn, *nd.sym.uses]];
}

impl rename_edits(nd: uni.NameAtom, new_name: str) -> list[TextEdit] {
    if not nd.sym {
        return [];
    }
    edits: list[TextEdit] = [];
    seen: set[tuple[str, int, int, int, int]] = set();
    for occ in [*nd.sym.uses, nd.sym.defn[0]] {
        span = span_at(occ.loc);
        key = (span.path, span.line, span.col, span.end_line, span.end_col);
        if key in seen {
            continue;
        }
        seen.add(key);
        edits.append(TextEdit(span=span, text=new_name));
    }
    return edits;
}

impl completion_kind(sym: uni.Symbol) -> str {
    decl = sym.decl.name_of;
    if isinstance(decl, uni.ModulePath) {
        return "module";
    }
    if isinstance(decl, uni.Ability) {
        return "function";
    }
    if isinstance(decl, uni.Archetype) {
        return "class";
    }
    if isinstance(decl, uni.Enum) {
        return "enum";
    }
    if isinstance(decl, uni.HasVar) {
        return "variable";
    }
    return "text";
}

impl completion_from_symbol(name: str, sym: uni.Symbol) -> CompletionItem {
    return CompletionItem(
        label=name, kind=completion_kind(sym), detail=doc_of_symbol(sym)
    );
}

impl members_of(ty: (TypeBase | uni.UniScopeNode)) -> list[CompletionItem] {
    items: list[CompletionItem] = [];
    if isinstance(ty, uni.UniScopeNode) {
        scope: (uni.UniScopeNode | None) = ty;
        while scope is not None {
            for (name, sym) in scope.names_in_scope.items() {
                items.append(completion_from_symbol(name, sym));
            }
            scope = scope.parent_scope;
        }
    } elif isinstance(ty, ClassType) {
        if not ty.shared.mro {
            compute_mro_linearization(ty);
        }
        for cls in ty.shared.mro {
            for (name, sym) in cls.shared.symbol_table.names_in_scope.items() {
                items.append(completion_from_symbol(name, sym));
            }
        }
    } elif isinstance(ty, ModuleType) and ty.symbol_table is not None {
        for (name, sym) in ty.symbol_table.names_in_scope.items() {
            items.append(completion_from_symbol(name, sym));
        }
    }
    return items;
}

impl scope_at(
    module: uni.Module, line: int, col: int, path: str = ""
) -> uni.UniScopeNode {
    best: uni.UniScopeNode = module;
    stack = list(module.kid_scope);
    while stack {
        scope = stack.pop();
        if path and not belongs_to(scope, path) {
            continue;
        }
        if position_within(scope, line, col) {
            best = scope;
            stack.extend(scope.kid_scope);
        }
    }
    return best;
}

impl scope_items(scope: uni.UniScopeNode) -> list[CompletionItem] {
    items = members_of(scope);
    items.extend(keyword_items({item.label for item in items}));
    return items;
}

impl node_items(program: JacProgram, nd: uni.UniNode) -> list[CompletionItem] {
    ty = node_type(program, nd);
    if ty is not None {
        return members_of(ty);
    }
    if isinstance(nd, uni.UniScopeNode) {
        return scope_items(nd);
    }
    return [];
}

impl inside_literal_or_comment(source: str, path: str, line: int, col: int) -> bool {
    def covers(first: int, first_col: int, last: int, last_col: int) -> bool {
        if first < line < last {
            return True;
        }
        if line < first or line > last {
            return False;
        }
        if line == first and col < first_col {
            return False;
        }
        if line == last and col >= last_col {
            return False;
        }
        return True;
    }
    (tokens, comments, _diags, _count) = tokenize_full(source, path);
    for tok in tokens {
        if tok.kind not in STRING_TOKEN_KINDS {
            continue;
        }
        loc = tok.loc;
        if covers(loc.line, loc.col_start, loc.end_line, loc.col_end) {
            return True;
        }
    }
    for note in comments {
        if covers(note.line, note.col_start, note.end_line, note.col_end) {
            return True;
        }
    }
    return False;
}

impl keyword_items(seen: set[str]) -> list[CompletionItem] {
    items: list[CompletionItem] = [];
    for (tok_name, text) in TOKEN_MAP.items() {
        if not text or not (text[0].isalpha() or text[0] == "_") {
            continue;
        }
        if not all([c.isalnum() or c == "_" for c in text]) {
            continue;
        }
        if not (tok_name.startswith("KW_") or tok_name in ("NULL", "NOT", "BOOL")) {
            continue;
        }
        if text in seen {
            continue;
        }
        seen.add(text);
        items.append(CompletionItem(label=text, kind="keyword"));
    }
    return items;
}

impl node_type(program: JacProgram, nd: uni.UniNode) -> (TypeBase | None) {
    if not isinstance(nd, uni.Expr) {
        return None;
    }
    if nd.type is not None {
        return nd.type;
    }
    return program.get_type_evaluator().get_type_of_expression(nd);
}

impl completion_items(
    program: JacProgram, module: uni.Module, path: str, line: int, col: int
) -> list[CompletionItem] {
    selected = node_at(module, line, max(col - 1, 1), path)
        or node_at(module, line, col, path);
    if isinstance(selected, uni.Token) {
        parent = selected.parent;
        if selected.name == "DOT" and isinstance(parent, uni.AtomTrailer) {
            return node_items(program, parent.target);
        }
        if isinstance(selected, uni.Name) {
            if isinstance(parent, uni.AtomTrailer)
                and parent.is_attr
                and selected is parent.right {
                return node_items(program, parent.target);
            }
            enclosing = selected.find_parent_of_type(uni.UniScopeNode);
            if enclosing is not None {
                return scope_items(enclosing);
            }
        }
    }
    return scope_items(scope_at(module, line, col, path));
}

impl inlay_hint_rows(
    module: uni.Module, first_line: int, last_line: int
) -> list[InlayHint] {
    rows: list[InlayHint] = [];
    for hint in inferred_hints(module) {
        if hint.line < first_line or hint.line > last_line {
            continue;
        }
        rows.append(
            InlayHint(line=hint.line, col=hint.col, label=hint.label, kind=hint.kind)
        );
    }
    return rows;
}

impl symbol_kind(nd: uni.UniNode) -> str {
    if isinstance(nd, uni.Ability) {
        return "function";
    }
    if isinstance(nd, uni.Enum) {
        return "enum";
    }
    if isinstance(nd, (uni.Archetype, uni.ImplDef)) {
        return "class";
    }
    if isinstance(nd, uni.Module) {
        return "module";
    }
    return "variable";
}

impl owner_symbol(table: uni.UniScopeNode) -> (uni.Symbol | None) {
    parent = table.parent_scope;
    if parent is not None and isinstance(table, uni.AstSymbolNode) {
        return parent.lookup(table.sym_name);
    }
    return None;
}

impl outline(nd: uni.UniScopeNode) -> list[DocumentSymbol] {
    out: list[DocumentSymbol] = [];
    owners: list[uni.Symbol] = [];
    for tab in nd.kid_scope {
        owned = owner_symbol(tab);
        if owned is not None {
            owners.append(owned);
        }
    }
    for (key, item) in nd.names_in_scope.items() {
        if item.decl.loc.mod_path != nd.loc.mod_path {
            continue;
        }
        if any([item is owned for owned in owners]) {
            continue;
        }
        out.append(
            DocumentSymbol(name=key, kind=symbol_kind(item.decl), span=span_at(item.decl.loc))
        );
    }
    for sub in nd.kid_scope {
        if sub.loc.mod_path != nd.loc.mod_path {
            continue;
        }
        children = outline(sub);
        if isinstance(sub, LOOP_SCOPES) {
            out.extend(children);
            continue;
        }
        out.append(
            DocumentSymbol(
                name=sub.scope_name,
                kind=symbol_kind(sub),
                span=span_at(sub.loc),
                children=children
            )
        );
    }
    return out;
}
