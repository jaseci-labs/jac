import os;
import jaclang.compiler.frontend.unitree as uni;


obj PlacementWork {
    has modules: dict[int, uni.Module] = {},
        edges: dict[int, tuple[uni.Import, uni.Module]] = {},
        owned: dict[int, list[int]] = {},
        readers: dict[int, dict[int, bool]] = {},
        path_readers: dict[str, dict[int, bool]] = {},
        reads: dict[int, set[int]] = {},
        paths: dict[int, set[str]] = {},
        references: dict[int, dict[int, set[int]]] = {},
        pending: set[int] = set(),
        queue: list[int] = [],
        cursor: int = 0,
        current: int | None = None,
        solving: bool = False;

    def enqueue(edge_id: int) {
        if edge_id in self.edges and edge_id not in self.pending {
            self.pending.add(edge_id);
            self.queue.append(edge_id);
        }
    }

    def track(module: uni.Module) {
        if id(module) not in self.modules {
            self.refresh(module);
        }
    }

    def refresh(module: uni.Module) {
        mid = id(module);
        self.modules[mid] = module;
        self.references.pop(mid, None);
        old = self.owned.get(mid, []);
        owned: list[int] = [];
        for stmt in module.get_all_sub_nodes(uni.Import) {
            eid = id(stmt);
            owned.append(eid);
            self.edges[eid] = (stmt, module);
        }
        for eid in set(old) - set(owned) {
            self.unwatch(eid);
            self.edges.pop(eid, None);
        }
        self.owned[mid] = owned;
        self.changed(module);
    }

    def changed(module: uni.Module) {
        mid = id(module);
        for eid in self.owned.get(mid, []) {
            self.enqueue(eid);
        }
        for eid in self.readers.get(mid, {}) {
            self.enqueue(eid);
        }
        path = module.loc.mod_path;
        if path {
            for eid in self.path_readers.get(os.path.abspath(path), {}) {
                self.enqueue(eid);
            }
        }
    }

    def forget(module: uni.Module) {
        self.changed(module);
        mid = id(module);
        self.modules.pop(mid, None);
        self.references.pop(mid, None);
        for eid in self.readers.pop(mid, {}) {
            self.reads.get(eid, set()).discard(mid);
        }
        removed = self.owned.pop(mid, []);
        for eid in removed {
            self.unwatch(eid);
            self.edges.pop(eid, None);
        }
    }

    def forget_path(path: str) {
        path = os.path.abspath(path);
        for module in list(self.modules.values()) {
            if module.loc.mod_path and os.path.abspath(module.loc.mod_path) == path {
                self.forget(module);
            }
        }
    }

    def observe(module: uni.Module) {
        self.track(module);
        eid = self.current;
        if eid is not None {
            self.readers.setdefault(id(module), {})[eid] = True;
            self.reads.setdefault(eid, set()).add(id(module));
        }
    }

    def observe_path(path: str) {
        eid = self.current;
        if eid is not None {
            path = os.path.abspath(path);
            self.path_readers.setdefault(path, {})[eid] = True;
            self.paths.setdefault(eid, set()).add(path);
        }
    }

    def unwatch(eid: int) {
        for mid in self.reads.pop(eid, set()) {
            readers = self.readers.get(mid, {});
            readers.pop(eid, None);
            if not readers {
                self.readers.pop(mid, None);
            }
        }
        for path in self.paths.pop(eid, set()) {
            readers = self.path_readers.get(path, {});
            readers.pop(eid, None);
            if not readers {
                self.path_readers.pop(path, None);
            }
        }
    }

    def refs(module: uni.Module) -> dict[int, set[int]] {
        import from jaclang.compiler.placement.placement_solver { _ref_top_ids }
        self.observe(module);
        mid = id(module);
        cached = self.references.get(mid);
        if cached is None {
            cached = {id(top): _ref_top_ids(module, top) for top in module.body};
            self.references[mid] = cached;
        }
        return cached;
    }

    def drain(prog: any) {
        import from jaclang.compiler.placement.placement_solver {
            _pull_boundary_import
        }
        if self.solving {
            return;
        }
        self.solving = True;
        try {
            while self.cursor < len(self.queue) {
                eid = self.queue[self.cursor];
                self.cursor += 1;
                self.pending.discard(eid);
                pair = self.edges.get(eid);
                if pair is None {
                    continue;
                }
                self.unwatch(eid);
                self.current = eid;
                try {
                    _pull_boundary_import(pair[0], pair[1], prog);
                } except Exception {
                    self.enqueue(eid);
                    raise;
                }
            }
        } finally {
            self.current = None;
            self.solving = False;
            self.queue = self.queue[self.cursor:];
            self.cursor = 0;
        }
    }
}
