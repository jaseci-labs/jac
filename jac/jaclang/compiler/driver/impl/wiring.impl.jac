impl WiringSpec.postinit -> None {
    self.package_prefix = _package_prefix(self.root_dir);
    for (i, wire) in enumerate(self.wires) {
        wire.index = i;
        self._wire_lines.setdefault(wire.line, []).append(wire);
        for consumer in wire.consumers {
            held = self._raw.setdefault(consumer, []);
            if not any([w is wire for w in held]) {
                held.append(wire);
            }
        }
    }
    rows: list[str] = [];
    for rule in self.rules {
        srcs = "|".join([p.text for p in rule.sources]);
        tgts = "|".join([p.text for p in rule.targets]);
        names = ",".join(sorted(rule.item_names)) if not rule.is_open else "*";
        rows.append(f"{rule.name}:{srcs}-->{tgts}:{names}");
    }
    self._policy_digest = hashlib.sha256("\n".join(rows).encode()).hexdigest()
        if rows
        else "";
}

impl WiringSpec.import_prefix -> str {
    if self._prefix is None {
        self._prefix = import_prefix_for(self.root_dir);
    }
    return self._prefix;
}

impl import_prefix_for(root_dir: str) -> str {
    project = active_host().project_root(root_dir);
    stop = os.path.realpath(project) if project else None;
    chain: list[str] = [];
    top = -1;
    cur = os.path.realpath(root_dir);
    while cur != stop {
        if os.path.isfile(os.path.join(cur, "__init__.jac"))
            or os.path.isfile(os.path.join(cur, "__init__.py")) {
            top = len(chain);
        }
        chain.append(os.path.basename(cur));
        parent = os.path.dirname(cur);
        if parent == cur {
            break;
        }
        cur = parent;
    }
    return ".".join(reversed(chain[:top + 1]));
}

impl WiringSpec.import_name(name: str) -> str {
    prefix = self.import_prefix();
    if prefix and name {
        return prefix + "." + name;
    }
    return prefix or name;
}

impl WiringSpec.module_name(path: str) -> (str | None) {
    local = local_module_name(self.root_dir, path);
    return self.package_prefix + local if local is not None else None;
}

impl local_module_name(root_dir: str, path: str) -> (str | None) {
    try {
        rel = os.path.relpath(os.path.realpath(path), os.path.realpath(root_dir));
    } except ValueError {
        return None;
    }
    if rel.startswith("..") {
        return None;
    }
    stem: str;
    if rel.endswith(".jac") {
        stem = rel[:-4];
    } elif rel.endswith(".py") {
        stem = rel[:-3];
    } else {
        return None;
    }
    parts = stem.split(os.sep);
    if parts and parts[-1] == "__init__" {
        parts = parts[:-1];
    }
    if not parts {
        return None;
    }
    for part in parts {
        if not part.isidentifier() {
            return None;
        }
    }
    return ".".join(parts);
}

impl WiringSpec._local_name(name: str) -> (str | None) {
    if not self.package_prefix {
        return name;
    }
    if not name.startswith(self.package_prefix) {
        return None;
    }
    return name[len(self.package_prefix):];
}

def _package_prefix(root_dir: str) -> str;

impl WiringSpec.module_file(name: str) -> (str | None) {
    local = self._local_name(name) if name else None;
    if not local {
        return None;
    }
    parts = local.split(".");
    if any([not p for p in parts]) {
        return None;
    }
    found = active_host().resolve_local_module(self.root_dir, parts);
    if found is None or found[1] not in ("jac", "py") or not self.owns(found[0]) {
        return None;
    }
    return found[0];
}

impl WiringSpec.owns(path: str) -> bool {
    top = os.path.realpath(self.root_dir);
    cur = os.path.dirname(os.path.realpath(path));
    if cur != top and not cur.startswith(top + os.sep) {
        return False;
    }
    walked: list[str] = [];
    owned = True;
    while cur != top {
        cached = self._owned_dirs.get(cur);
        if cached is not None {
            owned = cached;
            break;
        }
        walked.append(cur);
        if os.path.isfile(os.path.join(cur, ARCH_FILE_NAME))
            or os.path.isfile(os.path.join(cur, "jac.toml")) {
            owned = False;
            break;
        }
        cur = os.path.dirname(cur);
    }
    for d in walked {
        self._owned_dirs[d] = owned;
    }
    return owned;
}

impl WiringSpec.split_consumer(path: str) -> (tuple[str, list[str]] | None) {
    if path in self._splits {
        return self._splits[path];
    }
    found: (tuple[str, list[str]] | None) = None;
    parts = path.split(".");
    for i in range(len(parts), 0, -1) {
        head = ".".join(parts[:i]);
        if self.module_file(head) is not None {
            found = (head, parts[i:]);
            break;
        }
    }
    self._splits[path] = found;
    return found;
}

impl WiringSpec.consumer_scope(consumer: str, wire: WireRec) -> list[str] {
    scopes = self.consumer_scopes(consumer, wire);
    return scopes[0] if scopes else [];
}

impl WiringSpec.consumer_scopes(consumer: str, wire: WireRec) -> list[list[str]] {
    self.consumer_wires(consumer);
    return self._scopes.get((consumer, id(wire)), []);
}

impl WiringSpec.wire_for_import(
    stmt: Import, consumer: str, taken: set[int]
) -> (WireRec | None) {
    held = self.consumer_wires(consumer);
    from_loc = stmt.from_loc;
    written = {
        (item.name.value, item.alias.value if item.alias is not None else "")
        for item in stmt.items
        if isinstance(item, ModuleItem)
    };
    for wire in self._wire_lines.get(stmt.loc.first_line, []) {
        if wire.index in taken or not any([w is wire for w in held]) {
            continue;
        }
        if from_loc is not None
            and (
                from_loc.dot_path_str != self.import_name(wire.provider)
                or written != set(wire.items)
            ) {
            continue;
        }
        taken.add(wire.index);
        return wire;
    }
    return None;
}

impl WiringSpec.wire_import(wire: WireRec) -> (Import | None) {
    """The import one wire generates, parsed on its own at the place the annex
    puts it. A scope with several owners needs one import each, and a node
    cannot be copied in native code, so the copies come from the wire.""";
    lines: list[str] = [];
    for (line0, col, text) in self._wire_pieces(wire) {
        while len(lines) <= line0 {
            lines.append("");
        }
        lines[line0] = (" " * col) + text;
    }
    (mod, had_error) = parse_woven("\n".join(lines), self.path, None, []);
    if had_error {
        return None;
    }
    for stmt in mod.body {
        if isinstance(stmt, Import) {
            mod._role_set(BodyRole, []);
            mod.set_kids(nodes=[EmptyToken()], pos_update=False);
            mod._invalidate_sub_node_tab();
            return stmt;
        }
    }
    return None;
}

impl WiringSpec.is_package_dir(name: str) -> bool {
    local = self._local_name(name) if name else None;
    if not local {
        return False;
    }
    return os.path.isdir(os.path.join(self.root_dir, local.replace(".", os.sep)));
}

impl WiringSpec.project_modules -> list[str] {
    if self._project_modules is not None {
        return self._project_modules;
    }
    paths: list[str] = [];
    self._scan_modules(self.root_dir, paths, set());
    ignored = set(
        active_host().native_fact(
            HOST_FACT_GIT_IGNORED, os.path.realpath(self.root_dir)
        ).split(
            HOST_FACT_SEP
        )
    );
    found: list[str] = [];
    for path in paths {
        if os.path.realpath(path) in ignored {
            continue;
        }
        name = self.module_name(path);
        if name is not None {
            found.append(name);
        }
    }
    self._project_modules = found;
    return found;
}

impl WiringSpec._scan_modules(
    directory: str, found: list[str], seen: set[str]
) -> None {
    real = os.path.realpath(directory);
    if real in seen {
        return;
    }
    seen.add(real);
    try {
        entries = sorted(os.listdir(directory));
    } except OSError {
        return;
    }
    subdirs: list[str] = [];
    for fname in entries {
        full = os.path.join(directory, fname);
        if os.path.isdir(full) {
            if not fname.startswith(".")
                and fname not in SKIPPED_PROJECT_DIRS
                and not os.path.isfile(os.path.join(full, "jac.toml"))
                and not os.path.isfile(os.path.join(full, ARCH_FILE_NAME)) {
                subdirs.append(full);
            }
        } elif fname.endswith(".jac") {
            found.append(full);
        }
    }
    for sub in subdirs {
        self._scan_modules(sub, found, seen);
    }
}

impl WiringSpec.consumer_wires(consumer: str) -> list[WireRec] {
    held = self._by_consumer.get(consumer);
    if held is not None {
        return held;
    }
    dotted = consumer + ".";
    candidates: dict[int, WireRec] = {};
    for (path, wires) in self._raw.items() {
        if path == consumer or path.startswith(dotted) {
            for wire in wires {
                candidates[wire.index] = wire;
            }
        }
    }
    found: list[WireRec] = [];
    for index in sorted(candidates.keys()) {
        wire = candidates[index];
        scopes: list[list[str]] = [];
        for path in wire.consumers {
            if path != consumer and not path.startswith(dotted) {
                continue;
            }
            split = self.split_consumer(path);
            owner = split[0] if split is not None else path;
            if owner != consumer {
                continue;
            }
            scope = split[1] if split is not None else [];
            if scope not in scopes {
                scopes.append(scope);
            }
        }
        if scopes {
            found.append(wire);
            self._scopes[(consumer, id(wire))] = scopes;
        }
    }
    self._by_consumer[consumer] = found;
    return found;
}

impl WiringSpec.is_covered(consumer: str) -> bool {
    return bool(self.consumer_wires(consumer));
}

impl WiringSpec._wire_pieces(wire: WireRec) -> list[tuple[int, int, str]] {
    line0 = wire.line - 1;
    col = wire.col;
    head_form = import_form(wire.is_absorb, wire.is_typed, wire.is_comptime, False);
    if wire.is_module_form {
        text = head_form
            + " "
            + self.import_name(wire.provider)
            + (" as " + wire.alias if wire.alias else "")
            + ";";
        return [(line0, col, text)];
    }
    if not wire.payload {
        return [];
    }
    header = head_form + " from " + self.import_name(wire.provider);
    if wire.lb_line > wire.line {
        header = header + ("\n" * (wire.lb_line - wire.line)) + (" " * wire.lb_col);
    } elif wire.lb_col >= col + len(header) + 1 {
        header = header + (" " * (wire.lb_col - col - len(header)));
    } else {
        header = header + " ";
    }
    out: list[tuple[int, int, str]] = [];
    for (i, line) in enumerate((header + wire.payload).split("\n")) {
        out.append((line0 + i, col if i == 0 else 0, line));
    }
    return out;
}

impl WiringSpec.annex_source(consumer: str) -> (str | None) {
    wires = self.consumer_wires(consumer);
    if not wires {
        return None;
    }
    cached = self._annex_cache.get(consumer);
    if cached is not None {
        return cached;
    }
    placed: dict[int, list[tuple[int, str]]] = {};
    for wire in wires {
        if not wire.is_injected {
            continue;
        }
        for (line0, col, text) in self._wire_pieces(wire) {
            placed.setdefault(line0, []).append((col, text));
        }
    }
    if not placed {
        return None;
    }
    out: list[str] = [""] * (max(placed.keys()) + 1);
    for (line0, pieces) in placed.items() {
        pieces.sort();
        buf = "";
        for (col, text) in pieces {
            if len(buf) < col {
                buf = buf + (" " * (col - len(buf)));
            } elif buf {
                buf = buf + " ";
            }
            buf = buf + text;
        }
        out[line0] = buf;
    }
    text = "\n".join(out) + "\n";
    self._annex_cache[consumer] = text;
    return text;
}

impl WiringSpec.digest_for(consumer: str) -> str {
    rows: list[str] = [];
    for wire in self.consumer_wires(consumer) {
        provider = self.import_name(wire.provider);
        for scope_parts in self.consumer_scopes(consumer, wire) {
            scope = ".".join(scope_parts);
            for (line0, col, text) in self._wire_pieces(wire) {
                rows.append("\x1f".join([scope, "@", str(line0), str(col), text]));
            }
            for binding in wire.bindings() {
                rows.append(
                    "\x1f".join(
                        [
                            scope,
                            binding.form,
                            provider,
                            binding.name,
                            binding.alias,
                            "++>" if binding.injected else "-->"
                        ]
                    )
                );
            }
        }
    }
    if not rows and not self._policy_digest {
        return "";
    }
    rows.sort();
    return hashlib.sha256(
        (consumer + "\x00" + "\n".join(rows) + "\x00" + self._policy_digest).encode()
    ).hexdigest();
}

impl WireRec.bindings -> list[WireBinding] {
    if self.is_module_form {
        return [
            WireBinding(
                provider=self.provider,
                form=import_form(
                    self.is_absorb, self.is_typed, self.is_comptime, False
                ),
                alias=self.alias,
                injected=self.is_injected
            )
        ];
    }
    form = import_form(self.is_absorb, self.is_typed, self.is_comptime, True);
    return [
        WireBinding(
            provider=self.provider,
            form=form,
            name=name,
            alias=alias,
            injected=self.is_injected
        ) for (name, alias) in self.items
    ];
}

impl WiringSpec.consumer_bindings(
    consumer: str, scope: (list[str] | None) = None
) -> dict[tuple[str, str, str, str], WireRec] {
    want = scope or [];
    out: dict[tuple[str, str, str, str], WireRec] = {};
    for wire in self.consumer_wires(consumer) {
        if want not in self.consumer_scopes(consumer, wire) {
            continue;
        }
        for binding in wire.bindings() {
            out.setdefault(binding.key(), wire);
        }
    }
    return out;
}

impl WiringSpec.import_provider(path_node: ModulePath) -> (str | None) {
    if path_node.level == 0
        and path_node.string_path_value is None
        and (
            is_stdlib_module(path_node.dot_path_str.split(".")[0])
            or is_bundled_native_module(path_node.dot_path_str)
        ) {
        return None;
    }
    try {
        resolved = path_node.resolve_relative_path();
    } except Exception {
        return None;
    }
    if not resolved or not os.path.isfile(resolved) {
        return None;
    }
    module = self.module_name(resolved) if self.owns(resolved) else None;
    if module is None
        or path_node.level != 0
        or path_node.string_path_value is not None {
        return module;
    }
    if path_node.dot_path_str == self.import_name(module)
        or path_node.in_client_context()
        or path_node.in_native_context() {
        return module;
    }
    return None;
}

impl WiringSpec.rules_governing(
    provider: str, consumer: str, local: bool
) -> list[RuleRec] {
    named = [
        rule
        for rule in self.rules
        if any([p.matches(provider) for p in rule.sources])
    ];
    if not local {
        return named;
    }
    top = self.top_package(consumer);
    return [
        rule
        for rule in named
        if any(
            [
                not t.is_string and (not t.dotted or self.top_package(t.dotted) == top)
                for t in rule.targets
            ]
        )
    ];
}

impl WiringSpec.rules_admitting(
    provider: str, consumer: str, local: bool
) -> list[RuleRec] {
    return [
        rule
        for rule in self.rules_governing(provider, consumer, local)
        if any([t.matches(consumer) for t in rule.targets])
    ];
}

impl WiringSpec.top_package(module: str) -> str {
    local = self._local_name(module);
    if not local {
        return module.split(".")[0];
    }
    return self.package_prefix + local.split(".")[0];
}

impl WiringSpec.top_pattern(top: str) -> PatternRec {
    is_glob = self.is_package_dir(top);
    return PatternRec(dotted=top, is_glob=is_glob, text=top + ".*" if is_glob else top);
}

impl WiringSpec.needs_rule(provider: str, consumer: str, local: bool) -> bool {
    return local
        and self.top_package(provider) != self.top_package(consumer)
        and not self.rules_governing(provider, consumer, local);
}

impl WiringSpec.edge_rule(source: str, targets: list[str]) -> RuleRec {
    return RuleRec(
        name=rule_name_for(self._local_name(source) or source),
        sources=[self.top_pattern(source)],
        targets=[self.top_pattern(t) for t in sorted(set(targets))],
        is_open=True
    );
}

impl WiringSpec.admitted_names(rules: list[RuleRec]) -> (set[str] | None) {
    payload_rules = [
        r
        for r in rules
        if not r.is_open
    ];
    if not payload_rules {
        return None;
    }
    names: set[str] = set();
    for rule in payload_rules {
        names |= rule.item_names;
    }
    return names;
}

impl PatternRec.matches(module: str) -> bool {
    if self.is_glob {
        return (not self.dotted)
            or module == self.dotted
            or module.startswith(self.dotted + ".");
    }
    return module == self.dotted;
}

impl pattern_record(pattern: ModulePattern, scope: str = "") -> PatternRec {
    path = pattern.path;
    if path is not None and path.string_path_value is not None {
        return PatternRec(
            dotted=path.string_path_value,
            is_string=True,
            text="\"" + path.string_path_value + "\""
        );
    }
    dotted = ModulePattern.join_scope(scope, pattern.dotted);
    text = dotted;
    if pattern.is_glob {
        text = dotted + ".*" if dotted else "*";
    }
    return PatternRec(dotted=dotted, is_glob=pattern.is_glob, text=text);
}

impl rule_record(rule: ImportRule) -> RuleRec {
    scope = rule.block.scope_prefix;
    return RuleRec(
        name=rule.name.value,
        sources=[pattern_record(p, scope) for p in rule.sources],
        targets=[pattern_record(p, scope) for p in rule.targets],
        item_names=set(rule.item_names),
        is_open=rule.is_open
    );
}

impl wire_records(wire: ImportWire, source: str = "") -> list[WireRec] {
    alias = wire.provider.alias;
    records: list[WireRec] = [];
    for target in wire.targets {
        first = (target if wire.is_grouped else wire).loc.first_tok;
        rec = WireRec(
            provider=wire.provider_path,
            consumers=target.consumer_paths,
            is_module_form=target.is_module_form,
            is_absorb=wire.is_absorb,
            is_typed=wire.is_typed,
            is_comptime=wire.is_comptime,
            is_injected=wire.is_injected,
            alias=alias.value if alias is not None and target.is_module_form else "",
            items=[]
                if target.is_module_form
                else [
                    (
                        item.name.value,
                        item.alias.value if item.alias is not None else ""
                    ) for item in target.items
                ],
            line=first.line_no
        );
        records.append(rec);
        if not source {
            continue;
        }
        rec.col = first.pos_start - (source.rfind("\n", 0, first.pos_start) + 1);
        lbrace: (Token | None) = None;
        rbrace: (Token | None) = None;
        for k in [target->:Kid:->] {
            if isinstance(k, Token) {
                if k.name == Tok.LBRACE and lbrace is None {
                    lbrace = k;
                } elif k.name == Tok.RBRACE {
                    rbrace = k;
                }
            }
        }
        if lbrace is not None and rbrace is not None {
            rec.lb_line = lbrace.line_no;
            rec.lb_col = lbrace.pos_start
                - (source.rfind("\n", 0, lbrace.pos_start) + 1);
            rec.payload = source[lbrace.pos_start:rbrace.pos_end];
        }
    }
    return records;
}

impl module_records(mod: Module, source: str) -> tuple[list[WireRec], list[RuleRec]] {
    wires: list[WireRec] = [];
    rules: list[RuleRec] = [];
    for stmt in mod.body {
        if not isinstance(stmt, GraphImport) {
            continue;
        }
        for item in stmt.body {
            if isinstance(item, ImportWire) {
                wires.extend(wire_records(item, source));
            } elif isinstance(item, ImportRule) {
                rules.append(rule_record(item));
            }
        }
    }
    return (wires, rules);
}

impl parse_records(
    source: str, path: str
) -> tuple[bool, list[WireRec], list[RuleRec]] {
    (mod, had_error) = parse_woven(source, path, None, [], load_kernel=False);
    (wires, rules) = module_records(mod, source);
    return (bool(had_error), wires, rules);
}

impl _split_list(text: str) -> list[str] {
    if not text {
        return [];
    }
    return text.split("\x1e");
}

impl _encode_patterns(patterns: list[PatternRec]) -> str {
    return "\x1e".join(
        [
            p.dotted
                + "\x1d"
                + ("1" if p.is_glob else "0")
                + ("1" if p.is_string else "0")
                + "\x1d"
                + p.text for p in patterns
        ]
    );
}

impl _decode_patterns(text: str) -> (list[PatternRec] | None) {
    out: list[PatternRec] = [];
    for part in _split_list(text) {
        bits = part.split("\x1d");
        if len(bits) != 3 or len(bits[1]) != 2 {
            return None;
        }
        out.append(
            PatternRec(
                dotted=bits[0],
                is_glob=bits[1][0] == "1",
                is_string=bits[1][1] == "1",
                text=bits[2]
            )
        );
    }
    return out;
}

impl encode_records(
    parse_failed: bool, wires: list[WireRec], rules: list[RuleRec]
) -> str {
    lines: list[str] = [
        "jacwire\x1f" + str(RECORDS_FORMAT) + "\x1f" + ("1" if parse_failed else "0")
    ];
    for w in wires {
        flags = ("1" if w.is_module_form else "0")
            + ("1" if w.is_absorb else "0")
            + ("1" if w.is_typed else "0")
            + ("1" if w.is_comptime else "0")
            + ("1" if w.is_injected else "0");
        items = "\x1e".join([name + "\x1d" + alias for (name, alias) in w.items]);
        lines.append(
            "\x1f".join(
                [
                    "W",
                    w.provider,
                    "\x1e".join(w.consumers),
                    flags,
                    w.alias,
                    items,
                    str(w.line),
                    str(w.col),
                    str(w.lb_line),
                    str(w.lb_col),
                    w.payload.replace("\n", "\x1c")
                ]
            )
        );
    }
    for r in rules {
        lines.append(
            "\x1f".join(
                [
                    "R",
                    r.name,
                    _encode_patterns(r.sources),
                    _encode_patterns(r.targets),
                    "\x1e".join(sorted(r.item_names)),
                    "1" if r.is_open else "0"
                ]
            )
        );
    }
    return "\n".join(lines);
}

impl decode_records(text: str) -> (tuple[bool, list[WireRec], list[RuleRec]] | None) {
    lines = text.split("\n");
    head = lines[0].split("\x1f");
    if len(head) != 3 or head[0] != "jacwire" or head[1] != str(RECORDS_FORMAT) {
        return None;
    }
    wires: list[WireRec] = [];
    rules: list[RuleRec] = [];
    for line in lines[1:] {
        f = line.split("\x1f");
        if f[0] == "W" and len(f) == 11 {
            flags = f[3];
            if len(flags) != 5
                or not (
                    f[6].isdigit()
                    and f[7].isdigit()
                    and f[8].isdigit()
                    and f[9].isdigit()
                ) {
                return None;
            }
            items: list[tuple[str, str]] = [];
            for pair in _split_list(f[5]) {
                bits = pair.split("\x1d");
                if len(bits) != 2 {
                    return None;
                }
                items.append((bits[0], bits[1]));
            }
            wires.append(
                WireRec(
                    provider=f[1],
                    consumers=_split_list(f[2]),
                    is_module_form=flags[0] == "1",
                    is_absorb=flags[1] == "1",
                    is_typed=flags[2] == "1",
                    is_comptime=flags[3] == "1",
                    is_injected=flags[4] == "1",
                    alias=f[4],
                    items=items,
                    line=int(f[6]),
                    col=int(f[7]),
                    lb_line=int(f[8]),
                    lb_col=int(f[9]),
                    payload=f[10].replace("\x1c", "\n")
                )
            );
        } elif f[0] == "R" and len(f) == 6 {
            sources = _decode_patterns(f[2]);
            targets = _decode_patterns(f[3]);
            if sources is None or targets is None {
                return None;
            }
            rules.append(
                RuleRec(
                    name=f[1],
                    sources=sources,
                    targets=targets,
                    item_names=set(_split_list(f[4])),
                    is_open=f[5] == "1"
                )
            );
        } else {
            return None;
        }
    }
    return (head[2] == "1", wires, rules);
}

impl is_arch_file(path: str) -> bool {
    return os.path.basename(path) == ARCH_FILE_NAME;
}

impl arch_file_for(path: str) -> (str | None) {
    project = active_host().project_root(path);
    stop = os.path.realpath(project) if project else None;
    real = os.path.realpath(path);
    cur = real if os.path.isdir(real) else os.path.dirname(real);
    while True {
        candidate = os.path.join(cur, ARCH_FILE_NAME);
        if os.path.isfile(candidate) {
            return candidate;
        }
        if stop is not None and cur == stop {
            return None;
        }
        parent = os.path.dirname(cur);
        if parent == cur {
            return None;
        }
        cur = parent;
    }
}

impl is_stdlib_module(name: str) -> bool {
    if not _STDLIB_NAMES {
        _STDLIB_NAMES.append(
            set(
                active_host().native_fact(HOST_FACT_STDLIB_MODULES, "").split(
                    HOST_FACT_SEP
                )
            )
        );
    }
    return name in _STDLIB_NAMES[0];
}

impl scope_path_of(nd: UniNode) -> (list[str] | None) {
    names: list[str] = [];
    cur = nd.parent;
    while cur is not None and not isinstance(cur, Module) {
        if isinstance(cur, ImplDef) {
            return [t.sym_name for t in cur.target] + names;
        }
        if isinstance(cur, Ability) {
            if cur.name_ref is None {
                return None;
            }
            names.insert(0, cur.name_ref.sym_name);
        } elif isinstance(cur, (Archetype, Enum)) {
            names.insert(0, cur.name.sym_name);
        }
        cur = cur.parent;
    }
    return names;
}

impl is_positional_import(imp: Import) -> bool {
    if imp.is_absorb and active_host().base_file(imp.loc.mod_path) is not None {
        return True;
    }
    owner = imp.parent;
    if not isinstance(owner, (Module, Ability, ImplDef)) {
        return True;
    }
    for stmt in [owner->:BodyRole:->] {
        if stmt is imp {
            return False;
        }
        if stmt.loc.mod_path == imp.loc.mod_path
            and not isinstance(stmt, (Import, String, EmptyToken)) {
            return True;
        }
    }
    return False;
}

impl scope_owners(mod: Module) -> dict[str, list[(Ability | ImplDef)]] {
    index: dict[str, list[(Ability | ImplDef)]] = {};
    implemented: set[str] = set();
    for impl_node in mod.get_all_sub_nodes(typ=ImplDef) {
        base = scope_path_of(impl_node);
        if base is not None and isinstance(impl_node.body, `list) {
            path = ".".join([*base, *[t.sym_name for t in impl_node.target]]);
            index.setdefault(path, []).append(impl_node);
            implemented.add(path);
        }
    }
    for ability in mod.get_all_sub_nodes(typ=Ability) {
        base = scope_path_of(ability);
        if base is not None
            and ability.name_ref is not None
            and isinstance(ability.body, `list) {
            path = ".".join([*base, ability.name_ref.sym_name]);
            if path not in implemented {
                index.setdefault(path, []).append(ability);
            }
        }
    }
    return index;
}

impl inject_into_scope(owner: (Ability | ImplDef), stmt: UniNode) -> None {
    body: list[UniNode] = [owner->:BodyRole:->];
    kids: list[UniNode] = [owner->:Kid:->];
    anchor = -1;
    for i in range(len(kids)) {
        k = kids[i];
        if body and k is body[0] {
            anchor = i;
            break;
        }
        if not body and isinstance(k, Token) and k.name == Tok.RBRACE {
            anchor = i;
        }
    }
    if anchor < 0 {
        return;
    }
    with owner.structure_thawed() {
        owner.set_kids([*kids[:anchor], stmt, *kids[anchor:]], pos_update=False);
        owner._role_set(BodyRole, [stmt, *body]);
    }
    owner._invalidate_sub_node_tab();
}

impl _load_spec(root_dir: str, arch_path: str) -> WiringSpec {
    stamp: tuple[float, int] = (-1.0, -1);
    try {
        stamp = (os.path.getmtime(arch_path), os.path.getsize(arch_path));
    } except OSError {}
    key = os.path.realpath(root_dir);
    cached = _spec_cache.get(key);
    if cached is not None and cached[0] == stamp {
        return cached[1];
    }
    host = active_host();
    source = host.read_source(arch_path);
    digest = hashlib.sha256(source.encode()).hexdigest();
    records: (tuple[bool, list[WireRec], list[RuleRec]] | None) = None;
    held = host.wiring_records(digest);
    if held {
        records = decode_records(held);
    }
    if records is None {
        records = parse_records(source, arch_path);
        host.keep_wiring_records(
            digest, encode_records(records[0], records[1], records[2])
        );
    }
    spec = WiringSpec(
        root_dir=root_dir,
        path=arch_path,
        parse_failed=records[0],
        wires=records[1],
        rules=records[2]
    );
    _spec_cache[key] = (stamp, spec);
    return spec;
}

impl wiring_for_path(path: str) -> (WiringSpec | None) {
    if not path {
        return None;
    }
    arch = arch_file_for(path);
    if arch is None {
        return None;
    }
    root_dir = os.path.dirname(arch);
    scope = _resolution.get();
    if scope is not None and root_dir in scope and scope[root_dir] is not None {
        return scope[root_dir];
    }
    if root_dir in _building {
        return None;
    }
    spec: (WiringSpec | None) = None;
    _building.add(root_dir);
    try {
        spec = _load_spec(root_dir, arch);
    } finally {
        _building.discard(root_dir);
    }
    if scope is not None {
        scope[root_dir] = spec;
    }
    return spec;
}

impl place_wired_imports(mod: Module) -> None {
    spec = wiring_for_path(mod.loc.mod_path);
    if spec is None {
        return;
    }
    consumer = spec.module_name(mod.loc.mod_path) or "";
    generated: list[Import] = [];
    scoped: set[int] = set();
    owners: (dict[str, list[(Ability | ImplDef)]] | None) = None;
    taken: set[int] = set();
    for stmt in mod.body {
        if not isinstance(stmt, Import) or stmt.loc.mod_path != spec.path {
            continue;
        }
        wire = spec.wire_for_import(stmt, consumer, taken);
        scopes = spec.consumer_scopes(consumer, wire) if wire is not None else [];
        if wire is None or not any(scopes) {
            generated.append(stmt);
            continue;
        }
        used = False;
        for scope in scopes {
            if not scope {
                at_top = stmt if not used else spec.wire_import(wire);
                if at_top is not None {
                    at_top.code_context = stmt.code_context;
                    generated.append(at_top);
                }
                used = True;
                continue;
            }
            if owners is None {
                owners = scope_owners(mod);
            }
            for owner in owners.get(".".join(scope), []) {
                placed = stmt if not used else spec.wire_import(wire);
                if placed is not None {
                    if placed is stmt {
                        scoped.add(id(stmt));
                    }
                    placed.code_context = stmt.code_context;
                    inject_into_scope(owner, placed);
                }
                used = True;
            }
        }
    }
    if not generated and not scoped {
        return;
    }
    moved = {id(stmt) for stmt in generated} | scoped;
    rest = [
        s
        for s in mod.body
        if id(s) not in moved
    ];
    kids = [
        k
        for k in [mod->:Kid:->]
        if id(k) not in moved
    ];
    anchor = len(kids);
    if rest {
        for i in range(len(kids)) {
            if kids[i] is rest[0] {
                anchor = i;
                break;
            }
        }
    }
    mod._role_set(BodyRole, [*generated, *rest]);
    mod.set_kids(
        nodes=[*kids[:anchor], *generated, *kids[anchor:]] or [EmptyToken()],
        pos_update=False
    );
    mod._invalidate_sub_node_tab();
}

impl wiring_annex_for(file_path: str) -> (WovenAnnex | None) {
    if is_arch_file(file_path) {
        return None;
    }
    spec = wiring_for_path(file_path);
    if spec is None {
        return None;
    }
    consumer = spec.module_name(file_path);
    if consumer is None {
        return None;
    }
    text = spec.annex_source(consumer);
    if not text {
        return None;
    }
    return WovenAnnex(source=text, path=spec.path, consumer=spec.import_name(consumer));
}

impl wiring_digest_for(file_path: str) -> str {
    if is_arch_file(file_path) {
        return "";
    }
    spec = wiring_for_path(file_path);
    if spec is None {
        return "";
    }
    consumer = spec.module_name(file_path);
    if consumer is None {
        return "";
    }
    return spec.digest_for(consumer);
}

impl WiringSpec.import_bindings(imp: Import) -> list[tuple[WireBinding, UniNode]] {
    out: list[tuple[WireBinding, UniNode]] = [];
    from_loc = imp.from_loc;
    if from_loc is not None {
        provider = self.import_provider(from_loc);
        if provider is None {
            return out;
        }
        form = import_form(imp.is_absorb, imp.is_typed, imp.is_comptime, True);
        for item in imp.items {
            if isinstance(item, ModuleItem) {
                alias = item.alias.value if item.alias is not None else "";
                out.append(
                    (
                        WireBinding(
                            provider=provider,
                            form=form,
                            name=item.name.value,
                            alias=alias
                        ),
                        item
                    )
                );
            }
        }
        return out;
    }
    form = import_form(imp.is_absorb, imp.is_typed, imp.is_comptime, False);
    for item in imp.items {
        if not isinstance(item, ModulePath) {
            continue;
        }
        provider = self.import_provider(item);
        if provider is not None {
            alias = item.alias.value if item.alias is not None else "";
            out.append((WireBinding(provider=provider, form=form, alias=alias), item));
        }
    }
    return out;
}

impl WiringSpec.wire_suggestion(binding: WireBinding, consumer: str) -> str {
    split = self.split_consumer(consumer);
    block = wire_block(binding.provider, split[0] if split is not None else consumer);
    header = "graph import " + block if block else "graph import";
    return f"`{wire_text(block, binding, [consumer])}` to the `{header}` block";
}

impl wire_block(provider: str, consumer: str) -> str {
    shared: list[str] = [];
    for (left, right) in zip(provider.split(".")[:-1], consumer.split(".")[:-1]) {
        if left != right {
            break;
        }
        shared.append(left);
    }
    return ".".join(shared);
}

impl block_relative(block: str, name: str) -> str {
    if block and name.startswith(block + ".") {
        return name[len(block) + 1:];
    }
    return name;
}

impl wire_text(
    block: str,
    binding: WireBinding,
    consumers: list[str],
    items: (list[tuple[str, str]] | None) = None
) -> str {
    words = [
        w
        for w in binding.form.split(" ")
        if w in ("comptime", "include", "type")
    ];
    head = " ".join(words + [block_relative(block, binding.provider)]);
    relative = [block_relative(block, c) for c in consumers];
    arrow = "++>" if binding.injected else "-->";
    if binding.is_module_form() {
        alias = " as " + _wire_name(binding.alias) if binding.alias else "";
        return f"{head}{alias} {arrow} {_target_text(relative, None)};";
    }
    pairs = items if items is not None else [(binding.name, binding.alias)];
    return f"{head} {arrow} {_target_text(relative, pairs)}";
}

impl _entry_order(
    pair: tuple[list[str], (list[tuple[str, str]] | None)]
) -> tuple[list[str], list[tuple[str, str]]] {
    return (pair[0], pair[1] or []);
}

impl _target_text(consumers: list[str], items: (list[tuple[str, str]] | None)) -> str {
    right = " | ".join(consumers);
    if items is None {
        return right;
    }
    payload = ", ".join(
        [
            _wire_name(name) + (" as " + _wire_name(alias) if alias else "")
            for (name, alias) in items
        ]
    );
    return f"{right} {{ {payload} }}";
}

impl _wire_name(name: str) -> str {
    kind = lookup_keyword(name);
    return "`" + name if kind is not None and not is_name_usable_kind(kind) else name;
}

impl wiring_facts(wires: list[WireRec]) -> list[tuple[str, WireBinding]] {
    facts: list[tuple[str, WireBinding]] = [];
    seen: set[tuple[str, tuple[str, str, str, str]]] = set();
    for wire in wires {
        for consumer in wire.consumers {
            for binding in wire.bindings() {
                key = (consumer, binding.key());
                if key not in seen {
                    seen.add(key);
                    facts.append((consumer, binding));
                }
            }
        }
    }
    return facts;
}

impl rule_name_for(top: str) -> str {
    return "".join(
        [
            part[:1].upper() + part[1:]
            for part in top.split("_")
            if part
        ]
    );
}

impl propose_rules(
    spec: WiringSpec, facts: list[tuple[str, WireBinding]], rules: list[RuleRec]
) -> list[RuleRec] {
    probe = WiringSpec(root_dir=spec.root_dir, path=spec.path, wires=[], rules=rules);
    wanted: dict[str, set[str]] = {};
    for (consumer, binding) in facts {
        provider = binding.provider;
        if spec.module_file(provider) is None {
            continue;
        }
        constrained = probe.rules_governing(provider, consumer, True);
        crossing = spec.top_package(provider) != spec.top_package(consumer);
        if constrained {
            if probe.rules_admitting(provider, consumer, True) {
                continue;
            }
        } elif not crossing {
            continue;
        }
        wanted.setdefault(spec.top_package(provider), set()).add(
            spec.top_package(consumer)
        );
    }
    out = list(rules);
    taken = {r.name for r in out};
    for source in sorted(wanted) {
        proposal = spec.edge_rule(source, sorted(wanted[source]));
        held = next(
            (
                r
                for r in out
                if r.name == proposal.name
            ),
            None
        );
        if held is not None
            and held.is_open
            and [p.text for p in held.sources] == [proposal.sources[0].text] {
            texts = {p.text for p in held.targets};
            out[out.index(held)] = RuleRec(
                name=held.name,
                sources=held.sources,
                targets=held.targets
                    + [
                        p
                        for p in proposal.targets
                        if p.text not in texts
                    ],
                is_open=True
            );
            continue;
        }
        base = proposal.name;
        n = 1;
        while proposal.name in taken {
            n += 1;
            proposal.name = f"{base}{n}";
        }
        taken.add(proposal.name);
        out.append(proposal);
    }
    return out;
}

impl rule_text(rule: RuleRec) -> str {
    sources = " | ".join(sorted([p.text for p in rule.sources]));
    targets = " | ".join(sorted([p.text for p in rule.targets]));
    tail = ";"
        if rule.is_open
        else " { " + ", ".join([_wire_name(n) for n in sorted(rule.item_names)]) + " }";
    return f"edge {_wire_name(rule.name)}: {sources} --> {targets}{tail}";
}

impl _block_text(block: str, body: list[str]) -> str {
    head = "graph import " + block + " {" if block else "graph import {";
    lines = [head];
    for chunk in body {
        for line in chunk.split("\n") {
            lines.append("    " + line if line else "");
        }
    }
    lines.append("}");
    return "\n".join(lines);
}

impl render_wiring(
    spec: WiringSpec, facts: list[tuple[str, WireBinding]], rules: list[RuleRec]
) -> str {
    heads: dict[str, str] = {};
    payloads: dict[tuple[str, str, str, str, str], list[tuple[str, str]]] = {};
    groups:
        dict[tuple[str, str, str, str, str, tuple[tuple[str, str], ...]], list[str]] = {};
    for (consumer, binding) in facts {
        if consumer not in heads {
            split = spec.split_consumer(consumer);
            heads[consumer] = split[0] if split is not None else consumer;
        }
        block = wire_block(binding.provider, heads[consumer]);
        arrow = "++>" if binding.injected else "-->";
        if binding.is_module_form() {
            held = groups.setdefault(
                (block, binding.provider, binding.form, binding.alias, arrow, ()), []
            );
            if consumer not in held {
                held.append(consumer);
            }
            continue;
        }
        items = payloads.setdefault(
            (block, binding.provider, binding.form, arrow, consumer), []
        );
        pair = (binding.name, binding.alias);
        if pair not in items {
            items.append(pair);
        }
    }
    for ((block, provider, form, arrow, consumer), items) in payloads.items() {
        groups.setdefault(
            (block, provider, form, "", arrow, tuple(sorted(items))), []
        ).append(
            consumer
        );
    }
    statements:
        dict[
            tuple[str, str, str, str, str],
            list[tuple[list[str], (list[tuple[str, str]] | None)]]
        ] = {};
    for ((block, provider, form, alias, arrow, items), consumers) in groups.items() {
        module_form = "from" not in form.split(" ");
        prefix = " ".join(
            [
                w
                for w in form.split(" ")
                if w in ("comptime", "include", "type")
            ]
        );
        pending = sorted(consumers);
        while pending {
            taken: list[str] = [];
            rest: list[str] = [];
            landed: set[str] = set();
            for consumer in pending {
                if heads[consumer] in landed {
                    rest.append(consumer);
                } else {
                    landed.add(heads[consumer]);
                    taken.append(consumer);
                }
            }
            statements.setdefault((block, provider, prefix, alias, arrow), []).append(
                (
                    [block_relative(block, c) for c in taken],
                    None if module_form else list(items)
                )
            );
            pending = rest;
        }
    }
    wires: dict[str, list[tuple[tuple[str, str, str, str], str]]] = {};
    for ((block, provider, prefix, alias, arrow), entries) in statements.items() {
        head = " ".join(
            ([prefix] if prefix else []) + [block_relative(block, provider)]
        );
        if alias {
            head = head + " as " + _wire_name(alias);
        }
        texts = [
            _target_text(consumers, items)
            for (consumers, items) in sorted(entries, key=_entry_order)
        ];
        if len(texts) == 1 {
            text = f"{head} {arrow} {texts[0]}"
                + (";" if entries[0][1] is None else "");
        } else {
            text = f"{head} {arrow} [\n"
                + "".join(["    " + t + ",\n" for t in texts])
                + "]";
        }
        wires.setdefault(block, []).append(
            ((block_relative(block, provider), prefix, alias, arrow), text)
        );
    }
    policy = [rule_text(r) for r in sorted(rules, key=lambda (r: RuleRec) { r.name; })];
    top_wires = [text for (_key, text) in sorted(wires.get("", []))];
    if policy and top_wires {
        policy.append("");
    }
    blocks: list[str] = [];
    if policy or top_wires {
        blocks.append(_block_text("", policy + top_wires));
    }
    for block in sorted(
        [
            b
            for b in wires.keys()
            if b
        ],
        key=lambda (b: str) { b.split("."); }
    ) {
        blocks.append(
            _block_text(block, [text for (_key, text) in sorted(wires[block])])
        );
    }
    return "\n\n".join(blocks) + "\n" if blocks else "";
}

impl canonical_wiring_source(source: str, path: str) -> str {
    (mod, had_error) = parse_woven(source, path, None, [], load_kernel=False);
    if had_error
        or mod.doc is not None
        or mod.source.comments
        or any(
            [not isinstance(stmt, (GraphImport, EmptyToken)) for stmt in mod.body]
        ) {
        return source;
    }
    (wires, rules) = module_records(mod, source);
    spec = WiringSpec(
        root_dir=os.path.dirname(os.path.abspath(path)),
        path=path,
        wires=wires,
        rules=rules
    );
    return render_wiring(spec, wiring_facts(wires), rules);
}

impl prune_wiring_source(
    source: str, path: str, dropped: Callable[[str], bool]
) -> str {
    (mod, had_error) = parse_woven(source, path, None, [], load_kernel=False);
    if had_error {
        return source;
    }
    spec = WiringSpec(
        root_dir=os.path.dirname(os.path.abspath(path)), path=path, wires=[], rules=[]
    );
    text = list(source);
    def blank(span: UniNode) {
        for at in range(span.loc.pos_start, span.loc.pos_end) {
            if text[at] != "\n" {
                text[at] = " ";
            }
        }
    }
    for stmt in mod.body {
        if not isinstance(stmt, GraphImport) {
            continue;
        }
        kept = 0;
        for item in stmt.body {
            found = spec.module_file(item.provider_path)
                if isinstance(item, ImportWire)
                else None;
            if found is not None and dropped(found) {
                blank(item);
            } else {
                kept += 1;
            }
        }
        if stmt.body and not kept {
            blank(stmt);
        }
    }
    return "".join(text);
}

impl _package_prefix(root_dir: str) -> str {
    facts = active_host().project_facts(root_dir);
    if facts is None or not facts.package_name {
        return "";
    }
    return facts.package_name.replace("/", ".") + ".";
}

impl WireBinding.key -> tuple[str, str, str, str] {
    return (self.provider, self.form, self.name, self.alias);
}

impl WireBinding.is_module_form -> bool {
    return "from" not in self.form.split(" ");
}

impl WireBinding.bound_name -> str {
    return self.alias or self.name;
}

impl wiring_scope -> Iterator[None] {
    if _resolution.get() is not None {
        yield ;
        return;
    }
    token = _resolution.set({});
    try {
        yield ;
    } finally {
        _resolution.reset(token);
    }
}
