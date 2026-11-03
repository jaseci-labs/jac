impl WireInfo.to_dict -> dict[str, any] {
    return {
        "provider": self.provider,
        "consumer": self.consumer,
        "scope": self.scope,
        "names": self.names,
        "injected": self.injected,
        "form": self.form,
        "archwire": self.archwire,
        "line": self.line,
        "violation": self.violation,
        "rules": self.rules,
        "crosses": self.crosses
    };
}

impl ProjectModel.postinit {
    self.root_dir = os.path.realpath(self.root_dir);
    self.top = StProject(
        key="",
        name=os.path.basename(self.root_dir),
        kind="project",
        root_dir=self.root_dir
    );
    self.lock = threading.RLock();
}

impl ProjectModel.client -> SessionClient {
    if self._session is None {
        self._session = tool_session(self.root_dir);
    }
    return self._session;
}

impl ProjectModel.build(on_progress: any = None, index: bool = True) {
    t0 = time.time();
    with self.lock {
        self._discover();
    }
    self.build_secs = time.time() - t0;
    if index {
        self.index_all(on_progress);
    }
}

impl ProjectModel.index_all(on_progress: any = None) {
    t0 = time.time();
    keys = sorted(
        [
            k
            for (k, m) in self.modules.items()
            if m.kind == "module"
        ]
    );
    total = len(keys);
    n = 0;
    for k in keys {
        self.index_module(k);
        n += 1;
        if on_progress is not None {
            on_progress(n, total, k);
        }
    }
    with self.lock {
        self._link_walkers();
    }
    self.index_secs = time.time() - t0;
}

impl ProjectModel._arch_files -> list[str] {
    found: list[str] = [];
    for (d, ds, fs) in os.walk(self.root_dir) {
        ds[:] = sorted(
            [
                x
                for x in ds
                if not x.startswith(".") and x not in SKIP_DIRS
            ]
        );
        if ARCH_FILE_NAME in fs {
            found.append(os.path.join(d, ARCH_FILE_NAME));
        }
    }
    return found;
}

impl ProjectModel._head_files -> list[str] {
    found: list[str] = [];
    for (d, ds, fs) in os.walk(self.root_dir) {
        ds[:] = sorted(
            [
                x
                for x in ds
                if not x.startswith(".") and x not in SKIP_DIRS
            ]
        );
        self._note_dir(d);
        for f in sorted(fs) {
            if f.endswith(".jac") and f.count(".") == 1 and f != ARCH_FILE_NAME {
                found.append(os.path.join(d, f));
            }
        }
    }
    return found;
}

impl ProjectModel._rel_dotted(path: str) -> str {
    rel = os.path.relpath(path, self.root_dir);
    if rel.endswith(".jac") {
        rel = rel[:-4];
    }
    parts = [
        p
        for p in rel.split(os.sep)
        if p and p != "."
    ];
    if parts and parts[-1] == "__init__" {
        parts = parts[:-1];
    }
    return ".".join(parts);
}

impl ProjectModel._ensure_package(dotted: str) -> StNode {
    if not dotted {
        return self.top;
    }
    if dotted in self.packages {
        return self.packages[dotted];
    }
    pkg = StPackage(key=dotted, name=dotted.split(".")[-1], kind="package");
    self.packages[dotted] = pkg;
    parent_key = ".".join(dotted.split(".")[:-1]);
    parent = self._ensure_package(parent_key);
    parent +>:Contains():+> pkg;
    return pkg;
}

impl ProjectModel._add_module(
    key: str, path: str, archwire: str, local_name: str
) -> StModule {
    if key in self.modules {
        return self.modules[key];
    }
    real = os.path.realpath(path) if path else "";
    mod = StModule(
        key=key,
        name=key.split(".")[-1],
        kind="module" if path else "external",
        file=real,
        files=[real] if real else [],
        archwire=archwire,
        local_name=local_name
    );
    self.modules[key] = mod;
    if real {
        self.by_file[real] = key;
        try {
            mod.mtime = os.path.getmtime(real);
        } except OSError {}
        parent = self._ensure_package(".".join(key.split(".")[:-1]));
        parent +>:Contains():+> mod;
    }
    return mod;
}

impl ProjectModel._wiring_models -> list[WiringModel] {
    models: list[WiringModel] = [];
    for arch in self._arch_files() {
        self.archwires.append(arch);
        models.append(self.client().wiring_model(arch));
    }
    return models;
}

impl ProjectModel._add_project_modules(wiring: WiringModel, skip_known: bool) {
    nested = self._is_nested_project(wiring.arch_path);
    for row in wiring.modules {
        if not row.project
            or not row.file
            or os.path.basename(row.file) == ARCH_FILE_NAME {
            continue;
        }
        if skip_known and row.file in self.by_file {
            continue;
        }
        key = self._rel_dotted(row.file) if nested else row.import_name;
        self._add_module(key, row.file, wiring.arch_path, row.local);
    }
}

impl ProjectModel._discover {
    models = self._wiring_models();
    for wiring in models {
        self._add_project_modules(wiring, False);
    }
    for path in self._head_files() {
        real = os.path.realpath(path);
        if real in self.by_file {
            continue;
        }
        self._add_module(self._rel_dotted(real), real, "", "");
    }
    for wiring in models {
        self._add_wiring(wiring);
    }
    self._note_arch_mtimes();
}

impl ProjectModel._spec_key(wiring: WiringModel, local: str) -> str {
    for row in wiring.modules {
        if row.local != local {
            continue;
        }
        if row.file and row.file in self.by_file {
            return self.by_file[row.file];
        }
        if row.file {
            return row.import_name;
        }
        break;
    }
    return local;
}

impl ProjectModel._add_wiring(wiring: WiringModel) {
    arch = wiring.arch_path;
    for link in wiring.edges {
        prov_key = self._spec_key(wiring, link.provider);
        prov = self.modules.get(prov_key);
        if prov is None {
            prov = self._add_module(prov_key, "", arch, link.provider);
        }
        ckey = self._spec_key(wiring, link.consumer);
        cnode = self.modules.get(ckey);
        if cnode is None {
            cnode = self._add_module(ckey, "", arch, link.consumer);
        }
        info = WireInfo(
            provider=prov_key,
            consumer=ckey,
            scope=".".join(link.scope),
            names=list(link.names),
            injected=link.injected,
            form=link.form,
            archwire=arch,
            line=link.line,
            violation=link.violation,
            rules=[f"{arch}#{name}" for name in link.rules],
            crosses=link.crosses,
            arms=[f"{arch}#{arm}" for arm in link.arms]
        );
        self.wires.append(info);
        prov +>:Wire(
            names=info.names,
            injected=link.injected,
            form=link.form,
            archwire=arch,
            line=link.line
        ):+> cnode;
    }
    for r in wiring.rules {
        rule = StRule(
            key=f"{arch}#{r.name}",
            name=r.name,
            kind="rule",
            file=os.path.realpath(arch),
            sources=list(r.sources),
            targets=list(r.targets),
            names=list(r.names)
        );
        self.rules.append(rule);
        self.top +>:Contains():+> rule;
        governed = set(r.governs);
        for mod in self.modules.values() {
            if mod.archwire == arch and mod.local_name in governed {
                rule +>:Governs():+> mod;
            }
        }
    }
}

impl ProjectModel._add_symbol(owner: StNode, sym: StNode) {
    self.symbols[sym.key] = sym;
    owner +>:Contains():+> sym;
}

impl ProjectModel._clear_module_symbols(mod: StModule) {
    owned: list[StNode] = [];
    todo: list[StNode] = [mod];
    while todo {
        cur = todo.pop();
        for kid in [cur->:Contains:->] {
            if isinstance(kid, (StModule, StPackage)) {
                continue;
            }
            owned.append(kid);
            todo.append(kid);
        }
    }
    for sym in owned {
        if self.symbols.get(sym.key) is sym {
            self.symbols.pop(sym.key);
        }
        del sym;
    }
    for kid in [mod->:Contains:->] {
        del [edge mod->:Contains:->kid];
    }
    for f in mod.files[1:] {
        self.by_file.pop(f, None);
    }
    mod.files = mod.files[:1];
}

impl ProjectModel._span(sym: StNode, row: OutlineSymbol) {
    sym.file = row.file;
    sym.line = row.line;
    sym.end_line = row.end_line;
    sym.col = row.col;
}

impl ProjectModel.index_module(key: str) -> bool {
    mod = self.modules.get(key);
    if mod is None or mod.kind != "module" {
        return False;
    }
    if not mod.indexed and self._load_cache(mod) {
        return True;
    }
    outline = self.client().module_outline(mod.file);
    if outline.error {
        mod.error = outline.error;
        return False;
    }
    with self.lock {
        self._clear_module_symbols(mod);
        mod.error = "";
        mod.doc = outline.doc;
        self._index_outline(mod, outline);
        newest = 0.0;
        for f in mod.files {
            try {
                newest = max(newest, os.path.getmtime(f));
            } except OSError {}
        }
        mod.mtime = newest;
        mod.indexed = True;
    }
    self._save_cache(mod);
    return True;
}

impl ProjectModel._index_outline(mod: StModule, outline: ModuleOutline) {
    owners: dict[str, StArchetype] = {};
    for row in outline.symbols {
        if row.kind == "impl" {
            continue;
        }
        if row.kind == "has" {
            owner = owners.get(row.owner);
            if owner is None {
                continue;
            }
            field = StField(
                key=f"{owner.key}.{row.name}",
                name=row.name,
                kind="has",
                type_str=row.type_str,
                owner=owner.key
            );
            self._span(field, row);
            self._add_symbol(owner, field);
        } elif row.kind in ["def", "method", "can"] {
            owner = owners.get(row.owner) if row.owner else None;
            if row.owner and owner is None {
                continue;
            }
            parent: StNode = owner if owner is not None else mod;
            anode = StAbility(
                key=f"{parent.key}.{row.name}",
                name=row.name,
                kind=row.kind,
                signature=row.signature,
                owner=owner.key if owner is not None else "",
                event=row.event,
                doc=row.doc
            );
            self._span(anode, row);
            self._add_symbol(parent, anode);
            if owner is not None and anode.event {
                owner.walker_targets.append(anode.event);
            }
        } else {
            snode = StArchetype(
                key=f"{mod.key}.{row.name}",
                name=row.name,
                kind=row.kind,
                bases=list(row.bases),
                doc=row.doc
            );
            self._span(snode, row);
            self._add_symbol(mod, snode);
            owners[row.name] = snode;
        }
    }
    for row in outline.symbols {
        if row.kind == "impl" {
            self._index_impl(mod, row);
        }
    }
}

impl ProjectModel._index_impl(mod: StModule, row: OutlineSymbol) -> None {
    target = row.target;
    ikey = f"{mod.key}::idef::{target}";
    snode = StImpl(key=ikey, name=target, kind="impl", target=target);
    self._span(snode, row);
    if snode.file and snode.file not in mod.files {
        mod.files.append(snode.file);
        self.by_file[snode.file] = mod.key;
    }
    self.symbols[ikey] = snode;
    mod +>:Contains():+> snode;
    decl = self.symbols.get(f"{mod.key}.{target}");
    if decl is not None {
        snode +>:Implements():+> decl;
        if isinstance(decl, StAbility) {
            decl.impl_file = snode.file;
            decl.impl_line = snode.line;
            decl.impl_end_line = snode.end_line;
        } elif isinstance(decl, StArchetype) {
            decl.impl_file = snode.file;
            decl.impl_line = snode.line;
        }
    }
}

impl ProjectModel._link_walkers {
    by_name: dict[str, list[StNode]] = {};
    for sym in self.symbols.values() {
        if isinstance(sym, StArchetype) and sym.kind in ["node", "edge"] {
            by_name.setdefault(sym.name, []).append(sym);
        }
    }
    for sym in list(self.symbols.values()) {
        if not isinstance(sym, StArchetype) or sym.kind != "walker" {
            continue;
        }
        for tgt in [sym->:Traverses:->] {
            del [edge sym->:Traverses:->tgt];
        }
        seen: set[str] = set();
        for ev in sym.walker_targets {
            for word in ev.replace("(", " ").replace(")", " ").replace(
                "|", " "
            ).replace(
                ",", " "
            ).split() {
                for cand in by_name.get(word, []) {
                    if cand.key not in seen {
                        seen.add(cand.key);
                        sym +>:Traverses():+> cand;
                    }
                }
            }
        }
    }
}

impl ProjectModel.refresh(path: str) -> list[str] {
    real = os.path.realpath(path);
    if real in self.found {
        self.found.remove(real);
    }
    if not os.path.exists(real) and os.path.basename(real) != ARCH_FILE_NAME {
        return self._forget_file(real);
    }
    if os.path.basename(real) == ARCH_FILE_NAME {
        self.rewire();
        return [real];
    }
    key = self.by_file.get(real);
    if key is None {
        base = discover_base_file(real);
        if base {
            key = self.by_file.get(os.path.realpath(base));
        }
    }
    if key is None {
        if real.endswith(".jac")
            and os.path.exists(real)
            and real.startswith(self.root_dir) {
            with self.lock {
                key = self._rel_dotted(real);
                self._add_module(key, real, "", "");
            }
        } else {
            return [];
        }
    }
    self.index_module(key);
    with self.lock {
        self._link_walkers();
        self.uses_done = set();
    }
    return [key];
}

impl ProjectModel._forget_file(real: str) -> list[str] {
    key = self.by_file.get(real);
    mod = self.modules.get(key) if key else None;
    if mod is None {
        return [];
    }
    if real != mod.file {
        with self.lock {
            if real in mod.files {
                mod.files.remove(real);
            }
            self.by_file.pop(real, None);
        }
        self.index_module(mod.key);
        return [mod.key];
    }
    with self.lock {
        self._clear_module_symbols(mod);
        for f in mod.files {
            self.by_file.pop(f, None);
        }
        self.modules.pop(mod.key, None);
        self.uses_done = set();
        del mod;
    }
    return [str(key)];
}

impl ProjectModel._note_dir(path: str) -> None {
    try {
        stamp = os.path.getmtime(path);
    } except OSError {
        return;
    }
    self.dir_mtimes[path] = stamp;
    if time.time() - stamp < 2.0 {
        self.hot_dirs.add(path);
    } else {
        self.hot_dirs.discard(path);
    }
}

impl ProjectModel.new_files -> list[str] {
    for (d, seen) in list(self.dir_mtimes.items()) {
        try {
            now = os.path.getmtime(d);
        } except OSError {
            self.dir_mtimes.pop(d, None);
            self.hot_dirs.discard(d);
            continue;
        }
        if now == seen and d not in self.hot_dirs {
            continue;
        }
        self._note_dir(d);
        try {
            names = sorted(os.listdir(d));
        } except OSError {
            continue;
        }
        for name in names {
            full = os.path.join(d, name);
            if os.path.isdir(full) {
                if name.startswith(".")
                    or name in SKIP_DIRS
                    or full in self.dir_mtimes {
                    continue;
                }
                for (sub, subdirs, files) in os.walk(full) {
                    subdirs[:] = [
                        x
                        for x in subdirs
                        if not x.startswith(".") and x not in SKIP_DIRS
                    ];
                    self._note_dir(sub);
                    for f in files {
                        if f == ARCH_FILE_NAME {
                            arch = os.path.realpath(os.path.join(sub, f));
                            if arch not in self.arch_mtimes
                                and arch not in self.found {
                                self.found.append(arch);
                            }
                        } elif f.endswith(".jac") {
                            path = os.path.realpath(os.path.join(sub, f));
                            if path not in self.by_file and path not in self.found {
                                self.found.append(path);
                            }
                        }
                    }
                }
            } elif name == ARCH_FILE_NAME {
                arch = os.path.realpath(full);
                if arch not in self.arch_mtimes and arch not in self.found {
                    self.found.append(arch);
                }
            } elif name.endswith(".jac") {
                path = os.path.realpath(full);
                if path not in self.by_file and path not in self.found {
                    self.found.append(path);
                }
            }
        }
    }
    return list(self.found);
}

impl ProjectModel.stale_files -> list[str] {
    out: list[str] = [];
    for (arch, seen) in list(self.arch_mtimes.items()) {
        try {
            if os.path.getmtime(arch) > seen + 0.0001 {
                out.append(arch);
            }
        } except OSError {
            out.append(arch);
        }
    }
    out += self.new_files();
    for mod in list(self.modules.values()) {
        if mod.kind != "module" {
            continue;
        }
        for f in mod.files {
            try {
                if os.path.getmtime(f) > mod.mtime + 0.0001 {
                    out.append(f);
                    break;
                }
            } except OSError {
                out.append(f);
                break;
            }
        }
    }
    return out;
}

impl ProjectModel.module_for_file(path: str) -> (StModule | None) {
    key = self.by_file.get(os.path.realpath(path));
    return self.modules.get(key) if key else None;
}

impl ProjectModel.providers(key: str) -> list[WireInfo] {
    return [
        w
        for w in self.wires
        if w.consumer == key
    ];
}

impl ProjectModel.consumers(key: str) -> list[WireInfo] {
    return [
        w
        for w in self.wires
        if w.provider == key
    ];
}

impl ProjectModel.children(key: str) -> list[StNode] {
    nd: (StNode | None) = None;
    if key == "" {
        nd = self.top;
    } elif key in self.packages {
        nd = self.packages[key];
    } elif key in self.modules {
        nd = self.modules[key];
    } elif key in self.symbols {
        nd = self.symbols[key];
    }
    if nd is None {
        return [];
    }
    kids = [
        k
        for k in [nd->:Contains:->]
        if not isinstance(k, StImpl)
    ];
    return sorted(kids, key=lambda (k: StNode) -> tuple[int, str] { (k.line, k.name) });
}

impl ProjectModel.node_for(key: str) -> (StNode | None) {
    if key in self.modules {
        return self.modules[key];
    }
    if key in self.packages {
        return self.packages[key];
    }
    return self.symbols.get(key);
}

impl ProjectModel.implementations(key: str) -> list[StImpl] {
    nd = self.symbols.get(key);
    if nd is None {
        return [];
    }
    return [
        i
        for i in [nd<-:Implements:<-]
        if isinstance(i, StImpl)
    ];
}

impl ProjectModel.traversals(key: str) -> list[StNode] {
    nd = self.symbols.get(key);
    if nd is None {
        return [];
    }
    return [n for n in [nd->:Traverses:->]];
}

impl ProjectModel.walkers_of(key: str) -> list[StNode] {
    nd = self.symbols.get(key);
    if nd is None {
        return [];
    }
    return [n for n in [nd<-:Traverses:<-]];
}

impl ProjectModel.rules_for(key: str) -> list[StRule] {
    mod = self.modules.get(key);
    if mod is None {
        return [];
    }
    return [
        r
        for r in [mod<-:Governs:<-]
        if isinstance(r, StRule)
    ];
}

impl ProjectModel.search(
    query: str, limit: int = 50, kinds: (list[str] | None) = None
) -> list[StNode] {
    q = query.lower().strip();
    scored: list[tuple[int, str, StNode]] = [];
    pool: list[StNode] = list(self.modules.values()) + list(self.symbols.values());
    for nd in pool {
        if isinstance(nd, StImpl) {
            continue;
        }
        if kinds and nd.kind not in kinds {
            continue;
        }
        s = fuzzy_score(q, nd.key.lower(), nd.name.lower());
        if s >= 0 {
            scored.append((s, nd.key, nd));
        }
    }
    scored.sort(
        key=lambda (t: tuple[int, str, StNode]) -> tuple[int, int, str] { (
            -t[0],
            len(t[1]),
            t[1]
        ) }
    );
    return [t[2] for t in scored[:limit]];
}

impl ProjectModel.node_dict(nd: StNode) -> dict[str, any] {
    d: dict[str, any] = {
        "key": nd.key,
        "name": nd.name,
        "kind": nd.kind,
        "file": nd.file,
        "line": nd.line,
        "end_line": nd.end_line
    };
    if isinstance(nd, StArchetype) {
        d["bases"] = nd.bases;
        if nd.kind == "walker" {
            d["traverses"] = [t.key for t in self.traversals(nd.key)];
        }
    } elif isinstance(nd, StAbility) {
        d["signature"] = nd.signature;
        if nd.impl_file {
            d["impl"] = {
                "file": nd.impl_file,
                "line": nd.impl_line,
                "end_line": nd.impl_end_line
            };
        }
    } elif isinstance(nd, StField) {
        d["type"] = nd.type_str;
    } elif isinstance(nd, StModule) {
        d["files"] = nd.files;
        d["archwire"] = nd.archwire;
        if nd.error {
            d["error"] = nd.error;
        }
    }
    if nd.doc {
        d["doc"] = nd.doc;
    }
    return d;
}

impl ProjectModel.module_dict(key: str, deep: bool = True) -> dict[str, any] {
    mod = self.modules[key];
    d = self.node_dict(mod);
    d["providers"] = [w.to_dict() for w in self.providers(key)];
    d["consumers"] = [w.to_dict() for w in self.consumers(key)];
    d["rules"] = [r.name for r in self.rules_for(key)];
    if deep {
        d["symbols"] = [self._tree_dict(k) for k in self.children(key)];
    }
    return d;
}

impl ProjectModel._tree_dict(nd: StNode) -> dict[str, any] {
    d = self.node_dict(nd);
    kids = self.children(nd.key);
    if kids {
        d["children"] = [self._tree_dict(k) for k in kids];
    }
    return d;
}

impl ProjectModel.to_dict(module: str = "") -> dict[str, any] {
    if module {
        if module not in self.modules {
            return {"error": f"no module '{module}'"};
        }
        return self.module_dict(module);
    }
    mods = sorted(self.modules.keys());
    return {
        "root": self.root_dir,
        "archwires": self.archwires,
        "stats": self.stats(),
        "modules": [self.module_dict(k, deep=True) for k in mods],
        "rules": [
            {
                "name": r.name,
                "archwire": r.file,
                "sources": r.sources,
                "targets": r.targets,
                "names": r.names,
                "governs": [m.key for m in [r->:Governs:->]]
            } for r in self.rules
        ]
    };
}

impl ProjectModel.stats -> dict[str, any] {
    counts: dict[str, int] = {};
    for s in self.symbols.values() {
        counts[s.kind] = counts.get(s.kind, 0) + 1;
    }
    return {
        "modules": len(
            [
                m
                for m in self.modules.values()
                if m.kind == "module"
            ]
        ),
        "external": len(
            [
                m
                for m in self.modules.values()
                if m.kind == "external"
            ]
        ),
        "packages": len(self.packages),
        "wires": len(self.wires),
        "rules": len(self.rules),
        "symbols": counts,
        "discover_secs": round(self.build_secs, 3),
        "index_secs": round(self.index_secs, 3),
        "errors": len(
            [
                m
                for m in self.modules.values()
                if m.error
            ]
        )
    };
}

impl fuzzy_score(q: str, key: str, name: str) -> int {
    if not q {
        return 1;
    }
    if name == q {
        return 1000;
    }
    if name.startswith(q) {
        return 800 - len(name);
    }
    if q in name {
        return 600 - len(name);
    }
    if q in key {
        return 400 - len(key);
    }
    pos = 0;
    run = 0;
    score = 0;
    for ch in q {
        idx = key.find(ch, pos);
        if idx < 0 {
            return -1;
        }
        run = run + 1 if idx == pos else 0;
        score += 1 + run;
        pos = idx + 1;
    }
    return score;
}

impl sym_uri(key: str) -> str {
    return SYM_SCHEME + key;
}

impl find_project_root(start: str) -> str {
    cur = os.path.realpath(start);
    while True {
        if os.path.exists(os.path.join(cur, "jac.toml")) {
            return cur;
        }
        parent = os.path.dirname(cur);
        if parent == cur {
            return os.path.realpath(start);
        }
        cur = parent;
    }
}

impl ProjectModel._is_nested_project(arch: str) -> bool {
    cur = os.path.dirname(os.path.realpath(arch));
    while cur.startswith(self.root_dir) and cur != self.root_dir {
        if os.path.exists(os.path.join(cur, "jac.toml")) {
            return True;
        }
        cur = os.path.dirname(cur);
    }
    return False;
}

impl ProjectModel.link_uses(key: str) -> None {
    with self.lock {
        mod = self.modules.get(key);
        if mod is None or key in self.uses_done {
            return;
        }
        self.uses_done.add(key);
        visible: dict[str, StNode] = {};
        for w in self.providers(key) {
            prov = self.modules.get(w.provider);
            if prov is None {
                continue;
            }
            names = list(w.names);
            if not names {
                names = [
                    k.name
                    for k in [prov->:Contains:->]
                    if not isinstance(k, StImpl)
                ];
            }
            for n in names {
                parts = n.split(" as ");
                orig = parts[0].strip();
                local = parts[-1].strip();
                sym = self.symbols.get(f"{w.provider}.{orig}");
                if sym is not None {
                    visible[local] = sym;
                }
            }
        }
        spans: list[tuple[str, int, int, StNode]] = [];
        for (k, sym) in self.symbols.items() {
            if not k.startswith(key + ".") and not k.startswith(key + "::") {
                continue;
            }
            if isinstance(sym, StImpl) {
                tgt = self.symbols.get(f"{key}.{sym.target}");
                if tgt is not None {
                    spans.append((sym.file, sym.line, sym.end_line, tgt));
                }
                continue;
            }
            if k.count(".") == key.count(".") + 1 {
                visible.setdefault(sym.name, sym);
            }
            spans.append((sym.file, sym.line, sym.end_line, sym));
        }
        if not visible {
            return;
        }
        pat = re.compile(
            r"\b("
                + "|".join(
                    [re.escape(n) for n in sorted(visible, key=len, reverse=True)]
                )
                + r")\b"
        );
        seen: set[tuple[str, str]] = set();
        for f in mod.files {
            try {
                with open(f, encoding="utf-8", errors="replace") as fh {
                    lines = fh.read().split("\n");
                }
            } except OSError {
                continue;
            }
            for (i, text) in enumerate(lines) {
                ln = i + 1;
                if "import" in text
                    or not text.strip()
                    or text.lstrip().startswith("#") {
                    continue;
                }
                hits = pat.findall(text);
                if not hits {
                    continue;
                }
                inner: (StNode | None) = None;
                best = 1 << 30;
                for (sf, a, b, sym) in spans {
                    if sf == f and a <= ln <= b and b - a < best {
                        inner = sym;
                        best = b - a;
                    }
                }
                user: StNode = inner if inner is not None else mod;
                for name in hits {
                    target = visible[name];
                    if target is user or (target.file == f and target.line == ln) {
                        continue;
                    }
                    if user.key.startswith(target.key + ".") {
                        continue;
                    }
                    pair = (user.key, target.key);
                    if pair in seen {
                        continue;
                    }
                    seen.add(pair);
                    if not [edge user->:Uses:->target] {
                        user +>:Uses():+> target;
                    }
                }
            }
        }
    }
}

impl ProjectModel.neighbourhood(key: str) -> (Neighbourhood | None) {
    nd = self.node_for(key);
    if nd is None {
        return None;
    }
    self._link_for(nd);
    return Neighbourhood() spawn nd;
}

impl ProjectModel.users_of(key: str) -> list[StNode] {
    nd = self.node_for(key);
    if nd is None {
        return [];
    }
    self._link_for(nd);
    return (UsesOf() spawn nd).users;
}

impl ProjectModel.uses_of(key: str) -> list[StNode] {
    nd = self.node_for(key);
    if nd is None {
        return [];
    }
    self._link_for(nd);
    return (UsesOf() spawn nd).uses;
}

impl ProjectModel._link_for(nd: StNode) -> None {
    mod_key = self.by_file.get(os.path.realpath(nd.file), "") if nd.file else "";
    if isinstance(nd, StModule) {
        mod_key = nd.key;
    }
    if not mod_key {
        return;
    }
    self.link_uses(mod_key);
    for w in self.consumers(mod_key) {
        self.link_uses(w.consumer);
    }
}

impl Neighbourhood.gather with StNode entry {
    self.members = [
        k
        for k in [here->:Contains:->]
        if not isinstance(k, StImpl)
    ];
    if isinstance(here, StModule) {
        self.providers = [here<-:Wire:<-];
        self.consumers = [here->:Wire:->];
        self.rules = [here<-:Governs:<-];
    } else {
        self.impls = [here<-:Implements:<-];
        self.walkers = [here<-:Traverses:<-];
        self.targets = [here->:Traverses:->];
        self.users = [here<-:Uses:<-];
        self.uses = [here->:Uses:->];
    }
    disengage;
}

impl UsesOf.gather with StNode entry {
    self.users = [here<-:Uses:<-];
    self.uses = [here->:Uses:->];
    disengage;
}

impl ProjectModel._note_arch_mtimes -> None {
    for arch in self.archwires {
        try {
            self.arch_mtimes[os.path.realpath(arch)] = os.path.getmtime(arch);
        } except OSError {}
    }
}

impl ProjectModel.rewire -> None {
    with self.lock {
        for mod in list(self.modules.values()) {
            for other in [mod->:Wire:->] {
                del [edge mod->:Wire:->other];
            }
        }
        for rule in self.rules {
            del rule;
        }
        self.wires = [];
        self.rules = [];
        self.archwires = [];
        models = self._wiring_models();
        for wiring in models {
            self._add_project_modules(wiring, True);
        }
        for wiring in models {
            self._add_wiring(wiring);
        }
        self.uses_done = set();
        self._note_arch_mtimes();
    }
}

impl arm_key(rule_key: str, source: str, target: str) -> str {
    return f"{rule_key}\x1f{source}\x1f{target}";
}

impl ProjectModel._cache_path(mod: StModule) -> str {
    digest = hashlib.sha1(f"{INDEX_FORMAT}:{mod.key}:{mod.file}".encode()).hexdigest()[:20];
    return os.path.join(self.root_dir, ".jac", "studio", "index", digest + ".json");
}

impl ProjectModel._save_cache(mod: StModule) -> None {
    records: list[dict[str, any]] = [];
    def emit(parent: StNode) {
        for kid in [parent->:Contains:->] {
            cls = type(kid).__name__;
            if cls not in NODE_EXTRA {
                continue;
            }
            rec: dict[str, any] = {"cls": cls, "parent": parent.key};
            for f in NODE_BASE + NODE_EXTRA[cls] {
                rec[f] = getattr(kid, f);
            }
            records.append(rec);
            if cls != "StImpl" {
                emit(kid);
            }
        }
    }
    with self.lock {
        emit(mod);
        stamps: dict[str, float] = {};
        for f in mod.files {
            try {
                stamps[f] = os.path.getmtime(f);
            } except OSError {
                return;
            }
        }
        data = {
            "format": INDEX_FORMAT,
            "key": mod.key,
            "stamps": stamps,
            "doc": mod.doc,
            "symbols": records
        };
    }
    path = self._cache_path(mod);
    try {
        os.makedirs(os.path.dirname(path), exist_ok=True);
        tmp = path + f".{os.getpid()}.tmp";
        with open(tmp, "w", encoding="utf-8") as fh {
            json.dump(data, fh);
        }
        os.replace(tmp, path);
    } except OSError {}
}

impl ProjectModel._load_cache(mod: StModule) -> bool {
    path = self._cache_path(mod);
    try {
        with open(path, encoding="utf-8") as fh {
            data = json.load(fh);
        }
    } except (OSError, ValueError) {
        return False;
    }
    if not isinstance(data, dict)
        or data.get("format") != INDEX_FORMAT
        or data.get("key") != mod.key {
        return False;
    }
    stamps = data.get("stamps") or {};
    if mod.file not in stamps {
        return False;
    }
    for annex in discover_annex_files(mod.file) {
        if os.path.realpath(annex) not in stamps {
            return False;
        }
    }
    for (f, seen) in stamps.items() {
        try {
            if abs(os.path.getmtime(f) - float(seen)) > 0.0001 {
                return False;
            }
        } except OSError {
            return False;
        }
    }
    classes = {
        "StArchetype": StArchetype,
        "StAbility": StAbility,
        "StField": StField,
        "StImpl": StImpl
    };
    with self.lock {
        self._clear_module_symbols(mod);
        mod.error = "";
        mod.doc = str(data.get("doc", "") or "");
        for rec in data.get("symbols") or [] {
            cls = classes.get(str(rec.get("cls", "")));
            if cls is None {
                continue;
            }
            kwargs = {
                f: rec[f]
                for f in NODE_BASE + NODE_EXTRA[rec["cls"]]
                if f in rec
            };
            snode = cls(**kwargs);
            if isinstance(snode, StImpl) {
                if snode.file and snode.file not in mod.files {
                    mod.files.append(snode.file);
                    self.by_file[snode.file] = mod.key;
                }
                self.symbols[snode.key] = snode;
                mod +>:Contains():+> snode;
                decl = self.symbols.get(f"{mod.key}.{snode.target}");
                if decl is not None {
                    snode +>:Implements():+> decl;
                }
                continue;
            }
            parent = mod
                if rec.get("parent") == mod.key
                else self.symbols.get(str(rec.get("parent", "")));
            if parent is None {
                continue;
            }
            self._add_symbol(parent, snode);
        }
        for f in stamps {
            if f not in mod.files {
                mod.files.append(f);
                self.by_file[f] = mod.key;
            }
        }
        mod.mtime = max([float(v) for v in stamps.values()] or [0.0]);
        mod.indexed = True;
    }
    return True;
}
