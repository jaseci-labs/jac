import os;
import time;
import from pathlib { Path }
import from jaclang.project.source { iter_source_units }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.tools.symbol_index {
    SourceRef,
    SymbolInfo,
    EntryPoint
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

    def to_dict -> dict[str, any] {
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

    def to_dict -> dict[str, any] {
        return {
            "query": self.query,
            "target": self.target.to_dict() if self.target is not None else None,
            "related": [s.to_dict() for s in self.related],
            "uses": [u.to_dict() for u in self.uses]
        };
    }
}


obj CodeIntelligence {
    has proj_dir: str,
        on_event: Callable[[dict[str, str | int | float]], None] | None = None;

    def postinit {
        self._root_real: str = _real(self.proj_dir);
        self.prog: JacProgram = JacProgram.for_analysis();
        self._files: list[str] = [];
        self._file_set: set[str] = set();

        self._loaded: bool = False;
    }

    def load {
        t0 = time.time();
        self._files = self._discover();
        self._file_set = {_real(f) for f in self._files};
        self.prog.release_compile_closure();
        for f in self._files {
            self._full_compile_one(f);
        }
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
        import from jaclang.compiler.driver.bccache { discover_base_file }
        t0 = time.time();
        target = _real(discover_base_file(_real(file)) or file);
        service = self.prog.analysis_service();
        change = service.synchronize(self.prog.source_store.overrides, {target});
        mode = 'edit';
        if not Path(target).exists() {
            mode = 'delete';
            self._drop_file(target);
            service.forget(target);
        } elif target not in self._file_set {
            mode = 'create';
            self._files.append(target);
            self._file_set.add(target);
        }
        recompiled = 0;
        for path in sorted(change.affected) {
            if path in self._file_set {
                self._full_compile_one(path);
                recompiled += 1;
            }
        }
        self._emit(mode, target, recompiled, t0);
    }

    def _drop_file(real: str) {
        self._files = [
            f
            for f in self._files
            if _real(f) != real
        ];
        self._file_set.discard(real);
    }

    def _full_compile_one(file: str) {
        service = self.prog.analysis_service();
        try {
            if service.analyze(file) is None {
                raise RuntimeError(f'Inputs changed while analyzing {file}');
            }
        } finally {
            service.trim();
        }
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

    def lookup(name: str) -> list[SymbolInfo] {
        self._ensure();
        return self.prog.analysis_service().index.lookup(name, self.prog.source_store);
    }

    def definition(name: str) -> SymbolInfo | None {
        hits = self.lookup(name);
        return hits[0] if hits else None;
    }

    def references(name: str) -> list[SourceRef] {
        self._ensure();
        return self.prog.analysis_service().index.references_named(name, self.prog.source_store);
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
        self._ensure();
        target = _real(file) if file else '';
        found = {
            key: info
            for shard in self.prog.analysis_service().index.current_shards(self.prog.source_store)
            for (key, info) in shard.definitions.items()
            if info.workspace_visible and (not target or _real(info.file) == target)
        };
        return [found[key] for key in sorted(found)];
    }

    def archetypes(kind: str = "") -> list[SymbolInfo] {
        return [info for info in self.symbols()
            if info.kind in ('obj', 'class', 'node', 'edge', 'walker', 'enum')
                and (not kind or info.kind == kind)];
    }

    def entry_points -> list[EntryPoint] {
        self._ensure();
        found = {
            (
                entry_point.file, entry_point.line,
                entry_point.walker_name, entry_point.ability
            ): entry_point
            for shard in self.prog.analysis_service().index.current_shards(self.prog.source_store)
            for entry_point in shard.entry_points
        };
        return [found[key] for key in sorted(found)];
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
            ("error", [
                alert for record in self.prog.analysis_service().records.values()
                for alert in record.errors
            ]),
            ("warning", [
                alert for record in self.prog.analysis_service().records.values()
                for alert in record.warnings
            ])
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
