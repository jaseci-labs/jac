impl SymbolCollector.collect_scope with uni.UniScopeNode entry {
    if here.folded {
        return;
    }
    self.symbols.extend(here.names_in_scope.values());
    for bucket in here.names_in_scope_overload.values() {
        self.symbols.extend(bucket);
    }
}

impl _real(path: str) -> str {
    try {
        return str(Path(path).resolve());
    } except Exception {
        return path;
    }
}

impl SourceRef.render -> str {
    loc = f"{self.file}:{self.line}";
    return f"{loc}  {self.snippet}" if self.snippet else loc;
}

impl SourceRef.to_dict -> dict[str, any] {
    return {
        "file": self.file,
        "line": self.line,
        "col": self.col,
        "role": self.role,
        "snippet": self.snippet
    };
}

impl SymbolInfo.render -> str {
    head = f"{self.kind} {self.name}";
    if self.signature {
        head += self.signature;
    } elif self.type_str {
        head += f": {self.type_str}";
    }
    lines = [f"{head}    [{self.file}:{self.line}]"];
    if self.base_classes {
        lines.append("  extends: " + ", ".join(self.base_classes));
    }
    for f in self.fields {
        lines.append(f"  has {f}");
    }
    for a in self.abilities {
        lines.append(f"  def {a}");
    }
    if self.doc {
        lines.append("  " + self.doc.strip().splitlines()[0]);
    }
    return "\n".join(lines);
}

impl SymbolInfo.to_dict -> dict[str, any] {
    return {
        "name": self.name,
        "kind": self.kind,
        "file": self.file,
        "line": self.line,
        "col": self.col,
        "type_str": self.type_str,
        "doc": self.doc,
        "signature": self.signature,
        "fields": self.fields,
        "abilities": self.abilities,
        "base_classes": self.base_classes,
        "is_genai": self.is_genai
    };
}

impl SymbolInfo.from_dict(d: dict[str, any]) -> SymbolInfo {
    return SymbolInfo(
        name=str(d.get("name", "")),
        kind=str(d.get("kind", "symbol")),
        file=str(d.get("file", "")),
        line=int(d.get("line", 0)),
        col=int(d.get("col", 0)),
        type_str=str(d.get("type_str", "")),
        doc=str(d.get("doc", "")),
        signature=str(d.get("signature", "")),
        fields=list(d.get("fields", [])),
        abilities=list(d.get("abilities", [])),
        base_classes=list(d.get("base_classes", [])),
        is_genai=bool(d.get("is_genai", False))
    );
}

impl Diagnostic.render -> str {
    return f"{self.severity}: {self.file}:{self.line}: {self.message}";
}

impl Diagnostic.to_dict -> dict[str, any] {
    return {
        "file": self.file,
        "line": self.line,
        "severity": self.severity,
        "message": self.message
    };
}

impl _diag_key(d: Diagnostic) -> str {
    return f"{_real(d.file)}:{d.line}:{d.severity}:{d.message}";
}

impl EntryPoint.render -> str {
    return f"{self.walker_name}.{self.ability}  ({self.event} {self.node_type})  [{self.file}:{self.line}]";
}

impl EntryPoint.to_dict -> dict[str, any] {
    return {
        "walker_name": self.walker_name,
        "ability": self.ability,
        "node_type": self.node_type,
        "event": self.event,
        "file": self.file,
        "line": self.line
    };
}

impl EntryPoint.from_dict(d: dict[str, any]) -> EntryPoint {
    return EntryPoint(
        walker_name=str(d.get("walker_name", "")),
        ability=str(d.get("ability", "")),
        node_type=str(d.get("node_type", "")),
        event=str(d.get("event", "")),
        file=str(d.get("file", "")),
        line=int(d.get("line", 0))
    );
}

impl ContextSlice.render -> str {
    if self.target is None {
        return f"(no symbol named {self.query} was found)";
    }
    parts = ["# Definition", self.target.render()];
    if self.related {
        parts.append("\n# Referenced types");
        for s in self.related {
            parts.append(s.render());
        }
    }
    if self.uses {
        parts.append(f"\n# Used in {len(self.uses)} place(s)");
        for u in self.uses {
            parts.append("  " + u.render());
        }
    }
    return "\n".join(parts);
}

impl ContextSlice.to_dict -> dict[str, any] {
    return {
        "query": self.query,
        "target": self.target.to_dict() if self.target is not None else None,
        "related": [s.to_dict() for s in self.related],
        "uses": [u.to_dict() for u in self.uses]
    };
}

impl CodeIntelligence.postinit {
    self._root_real: str = _real(self.proj_dir);
    self.prog: JacProgram = JacProgram();

    self.prog.deps.tracking = True;
    self._files: list[str] = [];
    self._file_set: set[str] = set();
    self._records: dict[str, dict[str, any]] = {};

    self._dir_sig: dict[str, float] = {};
    self._loaded: bool = False;
}

impl CodeIntelligence.load {
    t0 = time.time();
    self._files = self._discover();
    self._file_set = {_real(f) for f in self._files};
    records: dict[str, dict[str, any]] = {};
    stale: set[str] = set();
    for real in sorted(self._file_set) {
        rec = self._cached_record(real);
        if rec is None {
            stale.add(real);
        } else {
            records[real] = rec;
        }
    }
    changed = True;
    while changed {
        changed = False;
        for (real, rec) in list(records.items()) {
            if any(
                [d in stale or d not in self._file_set for d in rec.get("deps", [])]
            ) {
                stale.add(real);
                records.pop(real);
                changed = True;
            }
        }
    }
    self._records = records;
    self._compile_and_index(stale);
    self._dir_sig = self._dir_signature();
    self._loaded = True;
    self._emit("load", "", len(stale), t0, cached=len(records));
}

impl CodeIntelligence._emit(
    op: str, file: str, recompiled: int, t0: float, cached: int = 0
) {
    cb = self.on_event;
    if cb is None {
        return;
    }
    try {
        cb(
            {
                "op": op,
                "file": file,
                "recompiled": recompiled,
                "cached": cached,
                "total": len(self._file_set),
                "ms": (time.time() - t0) * 1000.0
            }
        );
    } except Exception as e {
        _ = e;
    }
}

impl CodeIntelligence.refresh(file: str = "") -> None {
    if not file or not self._loaded {
        self.load();
        return;
    }
    t0 = time.time();
    target = self._head_for(_real(file));
    mode = "edit";
    stale: set[str] = set();
    if not Path(target).exists() {
        mode = "delete";
        self._drop_file(target);
        stale = self._dependents_of({target});
    } else {
        if target not in self._file_set {
            mode = "create";
            self._files.append(target);
            self._file_set.add(target);
            self._dir_sig = self._dir_signature();
        }
        stale = self._dependents_of({target});
        stale.add(target);
    }
    stale = {
        p
        for p in stale
        if p in self._file_set
    };
    for p in stale {
        self._records.pop(p, None);
        try {
            self.prog.invalidate_module(p);
        } except Exception as e {
            _ = e;
        }
    }
    self._compile_and_index(stale);
    self._emit(mode, target, len(stale), t0);
}

impl CodeIntelligence._head_for(real: str) -> str {
    p = Path(real);
    head: (Path | None) = None;
    name = p.name;

    for asuf in ANNEX_SUFFIXES {
        if name.endswith(asuf) {
            head = p.with_name(name[:-len(asuf)] + ".jac");
            break;
        }
    }

    parent = p.parent;
    impl_folder = ANNEX_FOLDER[IMPL_SUFFIX];
    if parent.name.endswith(impl_folder) {
        head = parent.with_name(parent.name[:-len(impl_folder)] + ".jac");
    }
    if head is not None {
        candidate = _real(str(head));
        if candidate in self._file_set {
            return candidate;
        }
    }
    return real;
}

impl CodeIntelligence._drop_file(real: str) {
    self._files = [
        f
        for f in self._files
        if _real(f) != real
    ];
    self._file_set.discard(real);
    self._records.pop(real, None);
    self._dir_sig = self._dir_signature();
}

impl CodeIntelligence._full_compile_one(file: str) -> tuple[list[Alert], list[Alert]] {
    err0 = len(self.prog.errors_had);
    warn0 = len(self.prog.warnings_had);
    try {
        import from jaclang.compiler.driver.compile_options { CompileOptions }
        self.prog.compile(
            file_path=file, options=CompileOptions(no_cgen=True, need_full_ast=True)
        );
    } except Exception as e {
        _ = e;
    }
    return (list(self.prog.errors_had[err0:]), list(self.prog.warnings_had[warn0:]));
}

impl CodeIntelligence._cached_record(real: str) -> (dict[str, any] | None) {
    try {
        cache_path = get_module_cache_path(real);
        if not is_module_cache_valid(real, cache_path) {
            return None;
        }
        raw = read_section_bytes(read_jir(cache_path), SEC_SYMINDEX);
        if not raw {
            return None;
        }
        rec = json.loads(raw.decode("utf-8"));
    } except (OSError, ValueError) {
        return None;
    }
    if not isinstance(rec, dict)
        or rec.get("schema") != INDEX_SCHEMA
        or rec.get("file") != real {
        return None;
    }
    return rec;
}

impl CodeIntelligence._compile_and_index(stale: set[str]) {
    if not stale {
        return;
    }
    """Diagnostics land on the module whose source they point into; one
    reported outside the project stays with the file whose compile raised it.""";
    diags: dict[str, list[list[any]]] = {p: [] for p in stale};
    seen_diags: set[str] = set();
    for real in sorted(stale) {
        (errors, warnings) = self._full_compile_one(real);
        for (sev, alerts) in [("error", errors), ("warning", warnings)] {
            for al in alerts {
                loc = al.loc;
                path = loc.mod_path if loc else "";
                owner = self._head_for(_real(path)) if path else real;
                if owner not in self._file_set {
                    owner = real;
                }
                if owner not in diags {
                    continue;
                }
                row = [sev, path, loc.first_line if loc else 0, str(al.msg)];
                key = json.dumps(row);
                if key in seen_diags {
                    continue;
                }
                seen_diags.add(key);
                diags[owner].append(row);
            }
        }
    }
    modules = self._project_modules();
    uses: dict[str, list[list[any]]] = {p: [] for p in stale};
    seen_uses: set[str] = set();
    for (owner_path, mod) in modules.items() {
        syms: list[uni.Symbol] = [];
        try {
            self._collect_syms(mod.sym_tab, syms);
        } except Exception as e {
            _ = e;
        }
        for sym in syms {
            decl = sym.decl;
            if getattr(sym, "imported", False) or decl is None or decl.loc is None {
                continue;
            }
            key = f"{decl.loc.mod_path}:{decl.loc.first_line}";
            for nd in sym.uses {
                use_loc = nd.loc;
                if use_loc is None {
                    continue;
                }
                at = self._head_for(_real(use_loc.mod_path));
                if at not in uses {
                    continue;
                }
                row = [
                    key,
                    sym.sym_name,
                    use_loc.mod_path,
                    use_loc.first_line,
                    use_loc.col_start
                ];
                mark = json.dumps(row);
                if mark not in seen_uses {
                    seen_uses.add(mark);
                    uses[at].append(row);
                }
            }
        }
    }
    for real in sorted(stale) {
        mod = modules.get(real);
        if mod is None {
            continue;
        }
        rec = self._build_record(real, mod, uses.get(real, []), diags.get(real, []));
        self._records[real] = rec;
        try {
            write_module_cache(
                real,
                None,
                extra_sections={SEC_SYMINDEX: json.dumps(rec).encode("utf-8")}
            );
        } except OSError {}
    }
}

impl CodeIntelligence._build_record(
    real: str, mod: uni.Module, uses: list[list[any]], diags: list[list[any]]
) -> dict[str, any] {
    decls: list[dict[str, any]] = [];
    seen: set[str] = set();
    syms: list[uni.Symbol] = [];
    try {
        self._collect_syms(mod.sym_tab, syms);
    } except Exception as e {
        _ = e;
    }
    for sym in syms {
        decl = sym.decl;
        if getattr(sym, "imported", False) or decl is None or decl.loc is None {
            continue;
        }
        key = f"{decl.loc.mod_path}:{decl.loc.first_line}";
        if key in seen {
            continue;
        }
        seen.add(key);
        info = self._info(sym);
        decls.append(
            {
                "name": sym.sym_name,
                "key": key,
                "info": info.to_dict() if info is not None else None,
                "defs": [
                    [nd.loc.mod_path, nd.loc.first_line, nd.loc.col_start]
                    for nd in sym.defn
                    if nd.loc is not None
                ]
            }
        );
    }
    top: list[dict[str, any]] = [];
    try {
        for sym in mod.sym_tab.names_in_scope.values() {
            if getattr(sym, "imported", False) {
                continue;
            }
            info = self._info(sym);
            if info is not None {
                top.append(info.to_dict());
            }
        }
    } except Exception as e {
        _ = e;
    }
    archetypes: list[dict[str, any]] = [];
    try {
        for arch in mod.get_all_sub_nodes(uni.Archetype) {
            info = self._archetype_info(arch);
            if info is not None {
                archetypes.append(info.to_dict());
            }
        }
    } except Exception as e {
        _ = e;
    }
    deps: set[str] = set();
    for prog in [self.prog] + list(self.prog.contexts.values()) {
        for (target, importers) in prog.deps.dependents.items() {
            if real in {_real(i) for i in importers} {
                dep = self._head_for(_real(target));
                if dep in self._file_set and dep != real {
                    deps.add(dep);
                }
            }
        }
    }
    for row in uses {
        dep = self._head_for(_real(str(row[0]).rsplit(":", 1)[0]));
        if dep in self._file_set and dep != real {
            deps.add(dep);
        }
    }
    return {
        "schema": INDEX_SCHEMA,
        "file": real,
        "deps": sorted(deps),
        "decls": decls,
        "uses": uses,
        "top": top,
        "archetypes": archetypes,
        "entries": [ep.to_dict() for ep in self._module_entry_points(mod)],
        "diags": diags
    };
}

impl CodeIntelligence._project_modules -> dict[str, uni.Module] {
    """Project modules across the program and its per-app contexts.""";
    out: dict[str, uni.Module] = {};
    for prog in [self.prog] + list(self.prog.contexts.values()) {
        for (path, mod) in list(prog.mod.hub.items()) {
            real = _real(path);
            if real in self._file_set
                and real not in out
                and mod is not None
                and mod.loc {
                out[real] = mod;
            }
        }
    }
    return out;
}

impl CodeIntelligence._dependents_of(targets: set[str]) -> set[str] {
    out: set[str] = set();
    frontier = set(targets);
    while frontier {
        nxt: set[str] = set();
        for (real, rec) in self._records.items() {
            if real in out or real in targets {
                continue;
            }
            if any([d in frontier for d in rec.get("deps", [])]) {
                out.add(real);
                nxt.add(real);
            }
        }
        for t in frontier {
            for p in self.prog.transitive_dependents(t) {
                real = _real(p);
                if real not in out and real not in targets and real in self._file_set {
                    out.add(real);
                    nxt.add(real);
                }
            }
        }
        frontier = nxt;
    }
    return out;
}

impl CodeIntelligence._decls_named(name: str) -> list[dict[str, any]] {
    hits: list[dict[str, any]] = [];
    seen: set[str] = set();
    for real in sorted(self._records) {
        for decl in self._records[real].get("decls", []) {
            if decl.get("name") != name or decl.get("key") in seen {
                continue;
            }
            seen.add(decl.get("key"));
            hits.append(decl);
        }
    }
    return hits;
}

impl CodeIntelligence._dir_signature -> dict[str, float] {
    dirs: set[str] = {self._root_real};
    for f in self._files {
        dirs.add(os.path.dirname(_real(f)));
    }
    sig: dict[str, float] = {};
    for d in dirs {
        try {
            sig[d] = os.path.getmtime(d);
        } except OSError as e {
            _ = e;
        }
    }
    return sig;
}

impl CodeIntelligence._ensure {
    if not self._loaded {
        self.load();
    }
}

impl CodeIntelligence.is_loaded -> bool {
    return self._loaded;
}

impl CodeIntelligence.files -> list[str] {
    self._ensure();
    return list(self._files);
}

impl CodeIntelligence._discover -> list[str] {
    found: list[str] = [];
    base = Path(self._root_real);
    if not base.exists() {
        return found;
    }
    for p in sorted(base.rglob("*.jac")) {
        if any([part in _SKIP_DIRS or part.startswith(".") for part in p.parts]) {
            continue;
        }
        name = p.name;
        if is_annex(name) {
            continue;
        }
        found.append(str(p));
    }
    return found;
}

impl CodeIntelligence._collect_syms(scope: uni.UniScopeNode, out: list[uni.Symbol]) {
    scope spawn SymbolCollector(symbols=out);
}

impl CodeIntelligence._kind_of(owner: uni.UniNode) -> str {
    if isinstance(owner, uni.Archetype) {
        raw = "";
        try {
            raw = str(owner.arch_type.value);
        } except Exception as e {
            _ = e;
        }
        return _ARCH_KIND.get(raw, raw or "obj");
    }
    if isinstance(owner, uni.Enum) {
        return "enum";
    }
    if isinstance(owner, uni.Ability) {
        return "ability";
    }
    if isinstance(owner, uni.HasVar) {
        return "field";
    }
    if isinstance(owner, uni.Module) {
        return "module";
    }
    return "symbol";
}

impl CodeIntelligence._expr_str(expr: uni.UniNode | None) -> str {
    if expr is None {
        return "";
    }
    try {
        return str(unparse_node(expr)).strip();
    } except Exception as e {
        _ = e;
        return "";
    }
}

impl CodeIntelligence._doc_of(owner: uni.UniNode) -> str {
    try {
        if isinstance(owner, uni.AstDocNode) {
            doc = owner.doc;
            if doc is not None and doc.value {
                return str(doc.value).strip().strip('"');
            }
        }
    } except Exception as e {
        _ = e;
    }
    return "";
}

impl CodeIntelligence._info(sym: uni.Symbol) -> SymbolInfo | None {
    decl = sym.decl;
    if decl is None {
        return None;
    }
    owner: uni.UniNode = decl;
    try {
        owner = decl.name_of;
    } except Exception as e {
        _ = e;
    }
    loc = decl.loc;
    info = SymbolInfo(
        name=sym.sym_name,
        kind=self._kind_of(owner),
        file=loc.mod_path if loc else "",
        line=loc.first_line if loc else 0,
        col=loc.col_start if loc else 0,
        doc=self._doc_of(owner)
    );
    if isinstance(owner, uni.Archetype) {
        self._fill_archetype(info, owner);
    } elif isinstance(owner, uni.Ability) {
        info.signature = self._expr_str(owner.signature);
        info.is_genai = bool(getattr(owner, "is_genai_ability", False));
    } elif isinstance(owner, uni.HasVar) {
        info.type_str = self._expr_str(owner.type_tag.tag) if owner.type_tag else "";
    } else {
        try {
            owner_type = owner?.type;
            info.type_str = str(owner_type) if owner_type else "";
        } except Exception as e {
            _ = e;
        }
    }
    return info;
}

impl CodeIntelligence._fill_archetype(info: SymbolInfo, arch: uni.Archetype) {
    try {
        for v in arch.get_has_vars() {
            vt = self._expr_str(v.type_tag.tag) if v.type_tag else "";
            info.fields.append(f"{v.name.sym_name}: {vt}" if vt else v.name.sym_name);
        }
    } except Exception as e {
        _ = e;
    }
    try {
        for m in arch.get_methods() {
            mname = m.name_ref.sym_name if m.name_ref else "?";
            tag = " by llm" if getattr(m, "is_genai_ability", False) else "";
            info.abilities.append(mname + "()" + tag);
        }
    } except Exception as e {
        _ = e;
    }
    try {
        if arch.base_classes {
            for b in arch.base_classes {
                info.base_classes.append(self._expr_str(b));
            }
        }
    } except Exception as e {
        _ = e;
    }
}

impl CodeIntelligence.lookup(name: str) -> list[SymbolInfo] {
    self._ensure();
    return [
        SymbolInfo.from_dict(decl["info"])
        for decl in self._decls_named(name)
        if decl.get("info")
    ];
}

impl CodeIntelligence.definition(name: str) -> SymbolInfo | None {
    hits = self.lookup(name);
    return hits[0] if hits else None;
}

impl CodeIntelligence.references(name: str) -> list[SourceRef] {
    self._ensure();
    out: list[SourceRef] = [];
    seen: set[str] = set();
    for decl in self._decls_named(name) {
        rows: list[tuple[str, list[any]]] = [("def", r) for r in decl.get("defs", [])];
        for rec in self._records.values() {
            for use in rec.get("uses", []) {
                if use[0] == decl["key"] and use[1] == decl["name"] {
                    rows.append(("use", use[2:]));
                }
            }
        }
        for (role, loc) in rows {
            key = f"{loc[0]}:{loc[1]}:{loc[2]}";
            if key in seen {
                continue;
            }
            seen.add(key);
            out.append(SourceRef(file=loc[0], line=loc[1], col=loc[2], role=role));
        }
    }
    return out;
}

impl CodeIntelligence.importers(name: str) -> list[str] {
    files: list[str] = [];
    for ref in self.references(name) {
        if ref.file not in files {
            files.append(ref.file);
        }
    }
    return files;
}

impl CodeIntelligence.symbols(file: str = "") -> list[SymbolInfo] {
    self._ensure();
    target = _real(file) if file else "";
    out: list[SymbolInfo] = [];
    for real in sorted(self._records) {
        if target and real != target {
            continue;
        }
        out.extend(
            [SymbolInfo.from_dict(d) for d in self._records[real].get("top", [])]
        );
    }
    return out;
}

impl CodeIntelligence.archetypes(kind: str = "") -> list[SymbolInfo] {
    self._ensure();
    out: list[SymbolInfo] = [];
    for real in sorted(self._records) {
        for d in self._records[real].get("archetypes", []) {
            info = SymbolInfo.from_dict(d);
            if not kind or info.kind == kind {
                out.append(info);
            }
        }
    }
    return out;
}

impl CodeIntelligence._archetype_info(arch: uni.Archetype) -> SymbolInfo | None {
    loc = arch.loc;
    info = SymbolInfo(
        name=arch.name.sym_name,
        kind=self._kind_of(arch),
        file=loc.mod_path if loc else "",
        line=loc.first_line if loc else 0,
        doc=self._doc_of(arch)
    );
    self._fill_archetype(info, arch);
    return info;
}

impl CodeIntelligence.entry_points -> list[EntryPoint] {
    self._ensure();
    out: list[EntryPoint] = [];
    for real in sorted(self._records) {
        out.extend(
            [EntryPoint.from_dict(d) for d in self._records[real].get("entries", [])]
        );
    }
    return out;
}

impl CodeIntelligence._module_entry_points(mod: uni.Module) -> list[EntryPoint] {
    out: list[EntryPoint] = [];
    try {
        for arch in mod.get_all_sub_nodes(uni.Archetype) {
            if self._kind_of(arch) != "walker" {
                continue;
            }
            for m in arch.get_methods() {
                sig = m.signature;
                if not isinstance(sig, uni.EventSignature) {
                    continue;
                }
                node_type = self._expr_str(sig.arch_tag_info) or "any";
                event = "";
                try {
                    event = str(sig.event.value);
                } except Exception as e {
                    _ = e;
                }
                mloc = m.loc;
                out.append(
                    EntryPoint(
                        walker_name=arch.name.sym_name,
                        ability=m.name_ref.sym_name if m.name_ref else "?",
                        node_type=node_type,
                        event=event,
                        file=mloc.mod_path if mloc else "",
                        line=mloc.first_line if mloc else 0
                    )
                );
            }
        }
    } except Exception as e {
        _ = e;
    }
    return out;
}

impl CodeIntelligence.walkers_visiting(node_type: str) -> list[EntryPoint] {
    return [
        ep
        for ep in self.entry_points()
        if ep.node_type == node_type or ep.node_type == "any"
    ];
}

impl CodeIntelligence.nodes_visited_by(walker_name: str) -> list[EntryPoint] {
    return [
        ep
        for ep in self.entry_points()
        if ep.walker_name == walker_name
    ];
}

impl CodeIntelligence.diagnostics(file: str = "") -> list[Diagnostic] {
    self._ensure();
    target = _real(file) if file else "";
    out: list[Diagnostic] = [];
    for sev in ("error", "warning") {
        for real in sorted(self._records) {
            for row in self._records[real].get("diags", []) {
                if row[0] != sev {
                    continue;
                }
                path = str(row[1]);
                if target and (not path or _real(path) != target) {
                    continue;
                }
                out.append(
                    Diagnostic(
                        file=path, line=int(row[2]), severity=sev, message=str(row[3])
                    )
                );
            }
        }
    }
    return out;
}

impl CodeIntelligence.refresh_and_diff(file: str = "") -> list[Diagnostic] {
    if not file or not self._loaded {
        self.refresh(file);
        return self.diagnostics();
    }

    before: set[str] = {_diag_key(d) for d in self.diagnostics()};
    self.refresh(file);
    real = _real(file);
    out: list[Diagnostic] = [];
    for d in self.diagnostics() {
        if _real(d.file) == real or _diag_key(d) not in before {
            out.append(d);
        }
    }
    return out;
}

impl CodeIntelligence.slice_for(name: str, depth: int = 1) -> ContextSlice {
    sl = ContextSlice(query=name);
    sl.target = self.definition(name);
    if sl.target is None {
        return sl;
    }
    sl.uses = [
        r
        for r in self.references(name)
        if r.role == "use"
    ];
    seen: set[str] = {name};
    frontier: list[SymbolInfo] = [sl.target];
    level = 0;
    while frontier and level < depth {
        next_frontier: list[SymbolInfo] = [];
        for info in frontier {
            for dep in self._type_names(info) {
                if dep in seen {
                    continue;
                }
                seen.add(dep);
                dep_info = self.definition(dep);
                if dep_info is not None {
                    sl.related.append(dep_info);
                    next_frontier.append(dep_info);
                }
            }
        }
        frontier = next_frontier;
        level += 1;
    }
    return sl;
}

impl CodeIntelligence._type_names(info: SymbolInfo) -> list[str] {
    names: set[str] = set();
    for b in info.base_classes {
        for tok in self._idents(b) {
            names.add(tok);
        }
    }
    for f in info.fields {
        if ":" in f {
            for tok in self._idents(f.split(":", 1)[1]) {
                names.add(tok);
            }
        }
    }
    if info.type_str {
        for tok in self._idents(info.type_str) {
            names.add(tok);
        }
    }
    return list(names);
}

impl CodeIntelligence._idents(text: str) -> list[str] {
    import re;
    out: list[str] = [];
    for tok in re.findall(r"[A-Za-z_][A-Za-z0-9_]*", text) {
        word = str(tok);
        if word and word[0].isupper() {
            out.append(word);
        }
    }
    return out;
}
