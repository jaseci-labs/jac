import os;
import time;
import jaclang.compiler.frontend.unitree as uni;
import from pathlib { Path }
import from jaclang.project.source { iter_source_units }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.passes { Alert }
import from jaclang.compiler.tools.symbol_index {
    SourceRef,
    SymbolInfo,
    SymbolExtractor
}
import from jaclang.jac0core.ext_registry {
    ANNEX_SUFFIXES,
    ANNEX_FOLDER,
    IMPL_SUFFIX,
    is_annex
}


def _real(path: str) -> str {
    try {
        return str(Path(path).resolve());
    } except Exception {
        return path;
    }
}


obj Diagnostic {
    has file: str,
        line: int,
        severity: str,
        message: str;

    def render -> str {
        return f"{self.severity}: {self.file}:{self.line}: {self.message}";
    }

    def to_dict -> dict {
        return {
            "file": self.file,
            "line": self.line,
            "severity": self.severity,
            "message": self.message
        };
    }
}


def _diag_key(d: Diagnostic) -> str {
    return f"{_real(d.file)}:{d.line}:{d.severity}:{d.message}";
}


obj EntryPoint {
    has walker_name: str,
        ability: str,
        node_type: str,
        event: str,
        file: str = "",
        line: int = 0;

    def render -> str {
        return f"{self.walker_name}.{self.ability}  ({self.event} {self.node_type})  [{self.file}:{self.line}]";
    }

    def to_dict -> dict {
        return {
            "walker_name": self.walker_name,
            "ability": self.ability,
            "node_type": self.node_type,
            "event": self.event,
            "file": self.file,
            "line": self.line
        };
    }

    static def from_dict(d: dict) -> EntryPoint {
        return EntryPoint(
            walker_name=str(d.get("walker_name", "")),
            ability=str(d.get("ability", "")),
            node_type=str(d.get("node_type", "")),
            event=str(d.get("event", "")),
            file=str(d.get("file", "")),
            line=int(d.get("line", 0))
        );
    }
}


obj ContextSlice {
    has query: str,
        target: SymbolInfo | None = None,
        related: list[SymbolInfo] = [],
        uses: list[SourceRef] = [];

    def render -> str {
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

    def to_dict -> dict {
        return {
            "query": self.query,
            "target": self.target.to_dict() if self.target is not None else None,
            "related": [s.to_dict() for s in self.related],
            "uses": [u.to_dict() for u in self.uses]
        };
    }
}


obj CodeIntelligence(SymbolExtractor) {
    has proj_dir: str,
        on_event: any = None;

    def postinit {
        self._root_real: str = _real(self.proj_dir);
        self.prog: JacProgram = JacProgram.for_analysis();
        self._files: list[str] = [];
        self._file_set: set[str] = set();
        self._compiled: dict[str, uni.Module] = {};

        self._dir_sig: dict[str, float] = {};
        self._loaded: bool = False;
    }

    def load {
        t0 = time.time();
        self._files = self._discover();
        self._file_set = {_real(f) for f in self._files};
        self.prog.diags.clear();
        self._compiled = {};
        for f in self._files {
            self._full_compile_one(f);
        }
        self._dir_sig = self._dir_signature();
        self._loaded = True;
        self._emit("load", "", len(self._files), t0);
    }

    def _emit(op: str, file: str, recompiled: int, t0: float, cached: int = 0) {
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

    def refresh(file: str = "") -> None {
        if not file or not self._loaded {
            self.load();
            return;
        }
        t0 = time.time();
        target = self._head_for(_real(file));
        mode = "edit";
        if not Path(target).exists() {
            mode = "delete";
            self._drop_file(target);
            stale: set[str] = self.prog.transitive_dependents(target);
        } else {
            if target not in self._file_set {
                mode = "create";
                self._files.append(target);
                self._file_set.add(target);
                self._dir_sig = self._dir_signature();
            }
            stale = self.prog.transitive_dependents(target);
            stale.add(target);
        }
        for p in stale {
            try {
                self.prog.invalidate_module(p);
            } except Exception as e {
                _ = e;
            }
        }

        self.prog.errors_had[:] = self._keep_diagnostics(self.prog.errors_had, stale);
        self.prog.warnings_had[:] = self._keep_diagnostics(
            self.prog.warnings_had, stale
        );
        recompiled = 0;
        for p in stale {
            if p in self._file_set {
                self._full_compile_one(p);
                recompiled += 1;
            }
        }
        self._emit(mode, target, recompiled, t0);
    }

    def _head_for(real: str) -> str {
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

    def _drop_file(real: str) {
        self._files = [
            f
            for f in self._files
            if _real(f) != real
        ];
        self._file_set.discard(real);
        if real in self._compiled {
            self._compiled.pop(real);
        }
        self._dir_sig = self._dir_signature();
    }

    def _full_compile_one(file: str) {
        try {
            import from jaclang.compiler.driver.compile_options { CompileOptions }
            mod = self.prog.compile(
                file_path=file, options=CompileOptions(no_cgen=True, need_full_ast=True)
            );
            if mod is not None and mod.loc {
                self._compiled[_real(mod.loc.mod_path)] = mod;
            }
        } except Exception as e {
            _ = e;
        }
    }

    def _dir_signature -> dict[str, float] {
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

    def _keep_diagnostics(alerts: list[Alert], stale: set[str]) -> list[Alert] {
        out: list[Alert] = [];
        for al in alerts {
            loc = al.loc;
            if loc is None or _real(loc.mod_path) not in stale {
                out.append(al);
            }
        }
        return out;
    }

    def _ensure {
        if not self._loaded {
            self.load();
        }
    }

    def is_loaded -> bool {
        return self._loaded;
    }

    def files -> list[str] {
        self._ensure();
        return list(self._files);
    }

    def _discover -> list[str] {
        return sorted(iter_source_units(self._root_real));
    }

    def _modules -> list[uni.Module] {
        self._ensure();
        return list(self._compiled.values());
    }

    def _all_syms -> list[uni.Symbol] {
        out: list[uni.Symbol] = [];
        for mod in self._modules() {
            try {
                self._collect_syms(mod.sym_tab, out);
            } except Exception as e {
                _ = e;
            }
        }
        return out;
    }

    def _resolve(name: str) -> list[uni.Symbol] {
        hits: list[uni.Symbol] = [];
        seen: set[str] = set();
        for sym in self._all_syms() {
            if sym.sym_name != name {
                continue;
            }
            if getattr(sym, "imported", False) {
                continue;
            }
            decl = sym.decl;
            if decl is None or decl.loc is None {
                continue;
            }
            key = f"{decl.loc.mod_path}:{decl.loc.first_line}";
            if key in seen {
                continue;
            }
            seen.add(key);
            hits.append(sym);
        }
        return hits;
    }

    def lookup(name: str) -> list[SymbolInfo] {
        out: list[SymbolInfo] = [];
        for sym in self._resolve(name) {
            info = self._info(sym);
            if info is not None {
                out.append(info);
            }
        }
        return out;
    }

    def definition(name: str) -> SymbolInfo | None {
        hits = self.lookup(name);
        return hits[0] if hits else None;
    }

    def references(name: str) -> list[SourceRef] {
        out: list[SourceRef] = [];
        seen: set[str] = set();
        for sym in self._resolve(name) {
            for (role, nodes) in [("def", sym.defn), ("use", sym.uses)] {
                for nd in nodes {
                    loc = nd.loc;
                    if loc is None {
                        continue;
                    }
                    key = f"{loc.mod_path}:{loc.first_line}:{loc.col_start}";
                    if key in seen {
                        continue;
                    }
                    seen.add(key);
                    out.append(
                        SourceRef(
                            file=loc.mod_path,
                            line=loc.first_line,
                            col=loc.col_start,
                            role=role
                        )
                    );
                }
            }
        }
        return out;
    }

    def importers(name: str) -> list[str] {
        files: list[str] = [];
        for ref in self.references(name) {
            if ref.file not in files {
                files.append(ref.file);
            }
        }
        return files;
    }

    def symbols(file: str = "") -> list[SymbolInfo] {
        target = _real(file) if file else "";
        out: list[SymbolInfo] = [];
        for mod in self._modules() {
            try {
                if target and _real(mod.loc.mod_path) != target {
                    continue;
                }
                for sym in mod.sym_tab.names_in_scope.values() {
                    if getattr(sym, "imported", False) {
                        continue;
                    }
                    info = self._info(sym);
                    if info is not None {
                        out.append(info);
                    }
                }
            } except Exception as e {
                _ = e;
            }
        }
        return out;
    }

    def archetypes(kind: str = "") -> list[SymbolInfo] {
        out: list[SymbolInfo] = [];
        for mod in self._modules() {
            try {
                for arch in mod.get_all_sub_nodes(uni.Archetype) {
                    info = self._archetype_info(arch);
                    if info is not None and (not kind or info.kind == kind) {
                        out.append(info);
                    }
                }
            } except Exception as e {
                _ = e;
            }
        }
        return out;
    }

    def _archetype_info(arch: uni.Archetype) -> SymbolInfo | None {
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

    def entry_points -> list[EntryPoint] {
        out: list[EntryPoint] = [];
        for mod in self._modules() {
            out.extend(self._module_entry_points(mod));
        }
        return out;
    }

    def _module_entry_points(mod: uni.Module) -> list[EntryPoint] {
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

    def walkers_visiting(node_type: str) -> list[EntryPoint] {
        return [
            ep
            for ep in self.entry_points()
            if ep.node_type == node_type or ep.node_type == "any"
        ];
    }

    def nodes_visited_by(walker_name: str) -> list[EntryPoint] {
        return [
            ep
            for ep in self.entry_points()
            if ep.walker_name == walker_name
        ];
    }

    def diagnostics(file: str = "") -> list[Diagnostic] {
        self._ensure();

        target = _real(file) if file else "";
        out: list[Diagnostic] = [];
        for (sev, alerts) in [
            ("error", self.prog.errors_had),
            ("warning", self.prog.warnings_had)
        ] {
            for al in alerts {
                loc = al.loc;
                path = loc.mod_path if loc else "";
                if target and (not path or _real(path) != target) {
                    continue;
                }
                out.append(
                    Diagnostic(
                        file=path,
                        line=loc.first_line if loc else 0,
                        severity=sev,
                        message=str(al.msg)
                    )
                );
            }
        }
        return out;
    }

    def refresh_and_diff(file: str = "") -> list[Diagnostic] {
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

    def slice_for(name: str, depth: int = 1) -> ContextSlice {
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

    def _type_names(info: SymbolInfo) -> list[str] {
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

    def _idents(text: str) -> list[str] {
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
}
