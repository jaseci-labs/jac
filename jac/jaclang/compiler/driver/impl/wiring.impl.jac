impl WireBinding.wire_text(consumer: str) -> str {
    words = self.form.split(" ");
    prefix = " ".join(
        [
            w
            for w in words
            if w in ("comptime", "include", "type")
        ]
    );
    if prefix == "type" {
        prefix = "type";
    }
    head = (prefix + " " if prefix else "") + self.provider;
    if "from" in words {
        item = self.name + (" as " + self.alias if self.alias else "");
        return f"{head} --> {consumer} {{ {item} }}";
    }
    alias = " as " + self.alias if self.alias else "";
    return f"{head}{alias} --> {consumer};";
}

impl WiringSpec.postinit -> None {
    import from jaclang.compiler.frontend.parser.frontend { parse_woven }
    self.digest = hashlib.sha256(self.source.encode()).hexdigest();
    self._lines = self.source.split("\n");
    (mod, had_error) = parse_woven(self.source, self.path, None, []);
    self.module = mod;
    self.parse_failed = bool(had_error);
    self.blocks = [
        s
        for s in mod.body
        if isinstance(s, ImplImport)
    ];
    for block in self.blocks {
        for stmt in block.body {
            if isinstance(stmt, ImportWire) {
                self.wires.append(stmt);
                for consumer in stmt.consumer_paths {
                    self._by_consumer.setdefault(consumer, []).append(stmt);
                }
            } elif isinstance(stmt, ImportRule) {
                self.rules.append(stmt);
            }
        }
    }
    rows: list[str] = [];
    for rule in self.rules {
        srcs = "|".join([WiringSpec.pattern_text(p) for p in rule.sources]);
        tgts = "|".join([WiringSpec.pattern_text(p) for p in rule.targets]);
        names = ",".join(sorted(rule.item_names)) if not rule.is_open else "*";
        rows.append(
            f"{rule.block.scope_prefix}:{rule.name.value}:{srcs}-->{tgts}:{names}"
        );
    }
    self._rule_rows = rows;
}

impl WiringSpec._ensure_policy -> None {
    if self._policy_loaded {
        return;
    }
    self._policy_loaded = True;
    if not self.closed_patterns {
        self.closed_patterns = _closed_patterns_for(self.root_dir);
    }
    rows = list(self._rule_rows) + ["closed:" + p for p in self.closed_patterns];
    self._policy_digest = hashlib.sha256("\n".join(rows).encode()).hexdigest()
        if rows
        else "";
}

impl WiringSpec.module_name(path: str) -> (str | None) {
    try {
        rel = os.path.relpath(os.path.realpath(path), os.path.realpath(self.root_dir));
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

impl WiringSpec.module_file(name: str) -> (str | None) {
    if not name {
        return None;
    }
    parts = name.split(".");
    if any([not p for p in parts]) {
        return None;
    }
    found = resolve_local_module(self.root_dir, parts);
    if found is None or found[1] not in ("jac", "py") {
        return None;
    }
    return found[0];
}

impl WiringSpec.is_package_dir(name: str) -> bool {
    if not name {
        return False;
    }
    return os.path.isdir(os.path.join(self.root_dir, *name.split(".")));
}

impl WiringSpec.project_modules -> list[str] {
    if self._project_modules is not None {
        return self._project_modules;
    }
    found: list[str] = [];
    for (dirpath, dirnames, filenames) in os.walk(self.root_dir) {
        dirnames[:] = sorted(
            [
                d
                for d in dirnames
                if not d.startswith(".") and d not in ("node_modules", "__pycache__")
            ]
        );
        for fname in sorted(filenames) {
            if not fname.endswith(".jac") {
                continue;
            }
            name = self.module_name(os.path.join(dirpath, fname));
            if name is not None {
                found.append(name);
            }
        }
    }
    self._project_modules = found;
    return found;
}

impl WiringSpec.consumer_wires(consumer: str) -> list[ImportWire] {
    return self._by_consumer.get(consumer, []);
}

impl WiringSpec.is_covered(consumer: str) -> bool {
    return consumer in self._by_consumer;
}

impl WiringSpec.is_project_module(module: str) -> bool {
    return module in self.project_modules();
}

impl WiringSpec.pattern_matches(pattern: str, module: str) -> bool {
    if pattern == "*" or pattern == "any" {
        return True;
    }
    if pattern.endswith(".*") {
        base = pattern[:-2];
        return module == base or module.startswith(base + ".");
    }
    return module == pattern;
}

impl WiringSpec.is_mentioned(module: str) -> bool {
    if self._mentioned is None {
        named: set[str] = set(self._by_consumer.keys());
        for wire in self.wires {
            named.add(wire.provider_path);
        }
        patterns: list[tuple[ModulePattern, str]] = [];
        for rule in self.rules {
            prefix = rule.block.scope_prefix;
            patterns.extend(
                [
                    (p, prefix)
                    for p in rule.sources
                    if not p.is_any
                ]
            );
            patterns.extend(
                [
                    (t, "")
                    for t in rule.targets
                    if not t.is_any
                ]
            );
        }
        if patterns {
            for name in self.project_modules() {
                if any([p.matches(name, prefix) for (p, prefix) in patterns]) {
                    named.add(name);
                }
            }
        }
        self._mentioned = named;
    }
    return module in self._mentioned;
}

impl WiringSpec.is_closed(module: str) -> bool {
    self._ensure_policy();
    return any([WiringSpec.pattern_matches(p, module) for p in self.closed_patterns]);
}

impl WiringSpec.is_sealed(module: str) -> bool {
    return self.is_mentioned(module) or self.is_closed(module);
}

impl WiringSpec.import_form(
    is_absorb: bool, is_typed: bool, is_comptime: bool, from_form: bool
) -> str {
    words: list[str] = [];
    if is_comptime {
        words.append("comptime");
    }
    words.append("include" if is_absorb else "import");
    if is_typed {
        words.append("type");
    }
    if from_form {
        words.append("from");
    }
    return " ".join(words);
}

impl WiringSpec.pattern_text(pattern: ModulePattern) -> str {
    if pattern.is_any {
        return "any";
    }
    if pattern.path is None {
        return "*";
    }
    return pattern.dotted + (".*" if pattern.is_glob else "");
}

impl WiringSpec._column_of(pos: int) -> int {
    return pos - (self.source.rfind("\n", 0, pos) + 1);
}

impl WiringSpec._wire_text(wire: ImportWire) -> list[tuple[int, int, str]] {
    first = wire.loc.first_tok;
    line0 = first.line_no - 1;
    col = self._column_of(first.pos_start);
    head_form = WiringSpec.import_form(
        wire.is_absorb, wire.is_typed, wire.is_comptime, False
    );
    if wire.is_module_form {
        alias = wire.provider.alias;
        text = head_form
            + " "
            + wire.provider_path
            + (" as " + alias.value if alias is not None else "")
            + ";";
        return [(line0, col, text)];
    }
    lbrace: (Token | None) = None;
    rbrace: (Token | None) = None;
    for k in [wire->:Kid:->] {
        if isinstance(k, Token) {
            if k.name == Tok.LBRACE and lbrace is None {
                lbrace = k;
            } elif k.name == Tok.RBRACE {
                rbrace = k;
            }
        }
    }
    if lbrace is None or rbrace is None {
        return [];
    }
    payload = self.source[lbrace.pos_start:rbrace.pos_end];
    header = head_form + " from " + wire.provider_path;
    lb_col = self._column_of(lbrace.pos_start);
    if lbrace.line_no > first.line_no {
        header = header + ("\n" * (lbrace.line_no - first.line_no)) + (" " * lb_col);
    } elif lb_col >= col + len(header) + 1 {
        header = header + (" " * (lb_col - col - len(header)));
    } else {
        header = header + " ";
    }
    out: list[tuple[int, int, str]] = [];
    for (i, line) in enumerate((header + payload).split("\n")) {
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
        for (line0, col, text) in self._wire_text(wire) {
            placed.setdefault(line0, []).append((col, text));
        }
    }
    out: list[str] = [""] * len(self._lines);
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
        while line0 >= len(out) {
            out.append("");
        }
        out[line0] = buf;
    }
    text = "\n".join(out) + "\n";
    self._annex_cache[consumer] = text;
    return text;
}

impl WiringSpec.digest_for(consumer: str) -> str {
    self._ensure_policy();
    annex = self.annex_source(consumer) or "";
    if not annex and not self._policy_digest {
        return "";
    }
    return hashlib.sha256((annex + "\x00" + self._policy_digest).encode()).hexdigest();
}

impl WiringSpec.wire_bindings(wire: ImportWire) -> list[WireBinding] {
    provider = wire.provider_path;
    if wire.is_module_form {
        alias = wire.provider.alias;
        return [
            WireBinding(
                provider=provider,
                form=WiringSpec.import_form(
                    wire.is_absorb, wire.is_typed, wire.is_comptime, False
                ),
                alias=alias.value if alias is not None else ""
            )
        ];
    }
    form = WiringSpec.import_form(
        wire.is_absorb, wire.is_typed, wire.is_comptime, True
    );
    return [
        WireBinding(
            provider=provider,
            form=form,
            name=item.name.value,
            alias=item.alias.value if item.alias is not None else ""
        ) for item in wire.items
    ];
}

impl WiringSpec.consumer_bindings(
    consumer: str
) -> dict[tuple[str, str, str, str], ImportWire] {
    out: dict[tuple[str, str, str, str], ImportWire] = {};
    for wire in self.consumer_wires(consumer) {
        for binding in self.wire_bindings(wire) {
            out.setdefault(binding.key(), wire);
        }
    }
    return out;
}

impl WiringSpec.import_provider(path_node: ModulePath) -> (str | None) {
    try {
        resolved = path_node.resolve_relative_path();
    } except Exception {
        return None;
    }
    if not resolved or not os.path.isfile(resolved) {
        return None;
    }
    return self.module_name(resolved);
}

impl WiringSpec.rules_for_provider(provider: str) -> list[ImportRule] {
    return [
        rule
        for rule in self.rules
        if any([p.matches(provider, rule.block.scope_prefix) for p in rule.sources])
    ];
}

impl WiringSpec.rules_admitting(provider: str, consumer: str) -> list[ImportRule] {
    return [
        rule
        for rule in self.rules_for_provider(provider)
        if any([t.matches(consumer) for t in rule.targets])
    ];
}

impl WiringSpec.admitted_names(rules: list[ImportRule]) -> (set[str] | None) {
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

impl is_arch_file(path: str) -> bool {
    if os.path.basename(path) != ARCH_FILE_NAME {
        return False;
    }
    return os.path.isfile(
        os.path.join(os.path.dirname(os.path.abspath(path)), "jac.toml")
    );
}

impl arch_file_for(path: str) -> (str | None) {
    root_dir = find_jac_project_root(path);
    if not root_dir {
        return None;
    }
    arch = os.path.join(root_dir, ARCH_FILE_NAME);
    return arch if os.path.isfile(arch) else None;
}

impl _closed_patterns_for(root_dir: str) -> list[str] {
    import from jaclang.project.config { get_config_for_path }
    import from pathlib { Path }
    try {
        cfg = get_config_for_path(Path(root_dir));
    } except Exception {
        return [];
    }
    if cfg is None {
        return [];
    }
    return list(cfg.arch.closed);
}

impl _load_spec(root_dir: str, arch_path: str) -> WiringSpec {
    try {
        st = os.stat(arch_path);
        stamp = (st.st_mtime, st.st_size);
    } except OSError {
        stamp = (-1.0, -1);
    }
    key = os.path.realpath(root_dir);
    cached = _spec_cache.get(key);
    if cached is not None and cached[0] == stamp {
        return cached[1];
    }
    spec = WiringSpec(
        root_dir=root_dir, path=arch_path, source=read_file_with_encoding(arch_path)
    );
    _spec_cache[key] = (stamp, spec);
    return spec;
}

impl wiring_for_path(path: str, policy: bool = True) -> (WiringSpec | None) {
    if not path {
        return None;
    }
    root_dir = find_jac_project_root(path);
    if not root_dir {
        return None;
    }
    scope = _resolution.get();
    if scope is not None and root_dir in scope and scope[root_dir] is not None {
        return scope[root_dir];
    }
    if root_dir in _building {
        return None;
    }
    arch = os.path.join(root_dir, ARCH_FILE_NAME);
    spec: (WiringSpec | None) = None;
    _building.add(root_dir);
    try {
        if os.path.isfile(arch) {
            spec = _load_spec(root_dir, arch);
        } elif not policy or (scope is not None and root_dir in scope) {
            return None;
        } else {
            closed = _closed_patterns_for(root_dir);
            if closed {
                spec = WiringSpec(
                    root_dir=root_dir,
                    path=arch,
                    source="",
                    closed_patterns=closed,
                    _policy_loaded=True
                );
                spec._ensure_policy();
            }
        }
    } finally {
        _building.discard(root_dir);
    }
    if scope is not None {
        scope[root_dir] = spec;
    }
    return spec;
}

impl dedupe_generated_imports(mod: Module) -> None {
    spec = wiring_for_path(mod.loc.mod_path, policy=False);
    if spec is None {
        return;
    }
    written: set[tuple[str, str, str, str]] = set();
    generated: list[Import] = [];
    for stmt in mod.body {
        if not isinstance(stmt, Import) {
            continue;
        }
        if stmt.loc.mod_path == spec.path {
            generated.append(stmt);
            continue;
        }
        written |= _import_keys(stmt);
    }
    if not generated or not written {
        return;
    }
    consumer = spec.module_name(mod.loc.mod_path) or "";
    removed: set[int] = set();
    for stmt in generated {
        doomed: set[int] = set();
        for (key, item) in _import_items(stmt) {
            if key in written or _relative_twin(key, consumer) in written {
                doomed.add(id(item));
            }
        }
        if doomed and stmt.prune_items(doomed) {
            removed.add(id(stmt));
        }
    }
    if removed {
        mod._role_set(
            BodyRole,
            [
                s
                for s in mod.body
                if id(s) not in removed
            ]
        );
        mod.set_kids(
            nodes=[
                k
                for k in [mod->:Kid:->]
                if id(k) not in removed
            ]
                or [EmptyToken()]
        );
        mod._invalidate_sub_node_tab();
    }
}

impl _import_items(stmt: Import) -> list[tuple[tuple[str, str, str, str], UniNode]] {
    from_loc = stmt.from_loc;
    form = WiringSpec.import_form(
        stmt.is_absorb, stmt.is_typed, stmt.is_comptime, from_loc is not None
    );
    out: list[tuple[tuple[str, str, str, str], UniNode]] = [];
    for item in stmt.items {
        alias = item.alias.value if item.alias is not None else "";
        if isinstance(item, ModuleItem) and from_loc is not None {
            out.append(((from_loc.dot_path_str, form, item.name.value, alias), item));
        } elif isinstance(item, ModulePath) {
            out.append(((item.dot_path_str, form, "", alias), item));
        }
    }
    return out;
}

impl _import_keys(stmt: Import) -> set[tuple[str, str, str, str]] {
    return {key for (key, _item) in _import_items(stmt)};
}

impl _relative_twin(
    key: tuple[str, str, str, str], consumer: str
) -> tuple[str, str, str, str] {
    (provider, form, name, alias) = key;
    if "." not in consumer {
        return key;
    }
    package = consumer.rsplit(".", 1)[0] + ".";
    if provider.startswith(package) {
        return ("." + provider[len(package):], form, name, alias);
    }
    return key;
}

impl wiring_annex_for(file_path: str) -> (tuple[str, str] | None) {
    if is_arch_file(file_path) {
        return None;
    }
    spec = wiring_for_path(file_path, policy=False);
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
    return (text, spec.path);
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
