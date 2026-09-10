import os;
import sys;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.relations { ScopeChild }
import from jaclang.compiler.passes.transform { Alert, PassResult }
import type from jaclang.compiler.driver.mtp { Info }
import type from jaclang.compiler.frontend.codeinfo { ClientArtifact, CodeGenTarget }

obj ModuleHub {
    has mod: uni.ProgramModule,
        stamps: dict[str, float] = {},
        artifacts: dict[str, CodeGenTarget] = {},
        client_artifacts: dict[str, ClientArtifact] = {};

    def stamp(resolved_path: str) {
        import time;
        import from jaclang.compiler.driver.bccache { discover_annex_files }
        seen = time.time();
        try {
            seen = max(seen, os.path.getmtime(resolved_path));
            for related in discover_annex_files(resolved_path) {
                seen = max(seen, os.path.getmtime(related));
            }
        } except OSError {}
        self.stamps[resolved_path] = seen;
    }

    def is_fresh(resolved_path: str) -> bool {
        import os;
        import from jaclang.compiler.driver.bccache { discover_annex_files }
        cached_at = self.stamps.get(resolved_path);
        if cached_at is None {
            return True;
        }
        try {
            if os.path.getmtime(resolved_path) > cached_at {
                return False;
            }
            for related in discover_annex_files(resolved_path) {
                if os.path.getmtime(related) > cached_at {
                    return False;
                }
            }
            return True;
        } except OSError {
            return False;
        }
    }

    def install(resolved_path: str, mod: uni.Module) -> (uni.Module | None) {
        prev = self.mod.hub.get(resolved_path);
        self.mod.hub[resolved_path] = mod;
        self.stamp(resolved_path);
        if prev is None or prev is mod {
            return None;
        }
        return prev;
    }

    def evict(resolved_path: str) {
        if resolved_path in self.mod.hub {
            self.mod.hub.pop(resolved_path);
        }
        if resolved_path in self.stamps {
            del self.stamps[resolved_path];
        }
        if resolved_path in self.artifacts {
            del self.artifacts[resolved_path];
        }
        if resolved_path in self.client_artifacts {
            del self.client_artifacts[resolved_path];
        }
    }

    def reset {
        dropped = list(self.mod.hub.values());
        dropped_ids: set[int] = set(id(m) for m in dropped);
        prog_root = self.mod;
        main = prog_root.main_mod;
        if main is not None and id(main) in dropped_ids {
            prog_root.main_mod = None;
        }
        prog_root.set_kids(
            [
                k
                for k in prog_root.kid
                if id(k) not in dropped_ids
            ],
            pos_update=False
        );
        for mod in dropped {
            del [edge mod<-:ScopeChild:<-];
        }
        prog_root.hub.clear();
        self.stamps.clear();
        self.client_artifacts.clear();
    }
}

obj DepGraph {
    has dependents: dict[str, set[str]] = {},
        tracking: bool = False;

    def record(importer_path: str, target_path: str) -> None {
        if importer_path == target_path {
            return;
        }
        bucket = self.dependents.get(target_path);
        if bucket is None {
            bucket = set();
            self.dependents[target_path] = bucket;
        }
        bucket.add(importer_path);
    }

    def record_module(mod: uni.Module) -> None {
        import from pathlib { Path }
        if mod.loc is None {
            return;
        }
        mod_path = mod.loc.mod_path;
        if not mod_path.endswith(".jac") {
            return;
        }
        try {
            importer = str(Path(mod_path).resolve());
        } except Exception {
            return;
        }
        for imp in mod.get_all_sub_nodes(uni.Import) {
            paths: list[uni.ModulePath] = [];
            if imp.from_loc is not None {
                paths.append(imp.from_loc);
            } else {
                for item in imp.items {
                    if isinstance(item, uni.ModulePath) {
                        paths.append(item);
                    }
                }
            }
            for mp in paths {
                try {
                    target = str(Path(mp.resolve_relative_path()).resolve());
                } except Exception {
                    continue;
                }
                self.record(importer, target);
            }
        }
    }

    def transitive_dependents(target_path: str) -> set[str] {
        out: set[str] = set();
        frontier: list[str] = [target_path];
        while frontier {
            current = frontier.pop();
            for importer in self.dependents.get(current, set()) {
                if importer in out {
                    continue;
                }
                out.add(importer);
                frontier.append(importer);
            }
        }
        return out;
    }

    def forget(resolved_path: str) {
        for bucket in self.dependents.values() {
            bucket.discard(resolved_path);
        }
    }

    def clear {
        self.dependents.clear();
    }
}

obj DiagLedger {
    has errors: list[Alert] = [],
        warnings: list[Alert] = [];

    def owned_errors(path: str) -> list[Alert] {
        return [
            a
            for a in self.errors
            if self._owned(a, path)
        ];
    }

    def owned_warnings(path: str) -> list[Alert] {
        return [
            a
            for a in self.warnings
            if self._owned(a, path)
        ];
    }

    def drop_module(resolved_path: str) {
        self.errors[:] = [
            a
            for a in self.errors
            if not self._owned(a, resolved_path)
        ];
        self.warnings[:] = [
            a
            for a in self.warnings
            if not self._owned(a, resolved_path)
        ];
    }

    def _owned(alert: Alert, path: str) -> bool {
        import os;
        import from jaclang.jac0core.ext_registry { is_annex_path_of }
        try {
            norm = os.path.realpath(path);
        } except OSError {
            return False;
        }
        return alert.owner == norm or is_annex_path_of(alert.owner, norm);
    }

    def clear {
        self.errors.clear();
        self.warnings.clear();
    }
}

obj BuildScratch {
    has boundary_parse_memo: dict[str, any] = {},
        compile_depth: int = 0;

    def clear {
        self.boundary_parse_memo.clear();
        self.compile_depth = 0;
    }
}

class AnalysisLedger {
    has _tags: dict[int, set[str]],
        _owners: dict[int, any];

    def init(self: AnalysisLedger) {
        self._tags: dict[int, set[str]] = {};
        self._owners: dict[int, any] = {};
    }

    def _drop(self: AnalysisLedger, key: int) {
        try {
            self._tags.pop(key, None);
            self._owners.pop(key, None);
        } except Exception {}
    }

    def provided(self: AnalysisLedger, mod: any) -> set[str] {
        import weakref;
        key = id(mod);
        owner = self._owners.get(key);
        if owner is not None and owner() is mod {
            return self._tags[key];
        }
        tags: set[str] = set();
        self._tags[key] = tags;
        self._owners[key] = weakref.ref(mod, lambda (_ref: any) { self._drop(key); });
        return tags;
    }

    def provides(self: AnalysisLedger, mod: any, tag: str) -> bool {
        owner = self._owners.get(id(mod));
        return owner is not None and owner() is mod and tag in self._tags[id(mod)];
    }

    def mark(self: AnalysisLedger, mod: any, tags: set[str]) {
        live = self.provided(mod);
        live.clear();
        live.update(tags);
    }

    def clear(self: AnalysisLedger) {
        self._tags.clear();
        self._owners.clear();
    }

    def __len__(self: AnalysisLedger) -> int {
        return len(self._tags);
    }
}

obj PendingPassResults {
    has module: uni.Module,
        results: dict[str, PassResult];
}

class AnalysisCaches {
    has placement_summaries: dict[str, any],
        placement_state: dict[str, any],
        native_verdict_notes: dict[str, tuple[str, str]],
        analyses_run: AnalysisLedger,
        mtir_map: dict[(str, Info)],
        pass_runs: dict[str, int],
        pass_time: dict[str, float],
        early_passes: dict[int, PendingPassResults],
        cache_events: dict[str, int];

    def init(self: AnalysisCaches) {
        self.placement_summaries: dict[str, any] = {};
        self.placement_state: dict[str, any] = {};
        self.native_verdict_notes: dict[str, tuple[str, str]] = {};
        self.analyses_run: AnalysisLedger = AnalysisLedger();
        self.mtir_map: dict[(str, Info)] = {};
        self.pass_runs: dict[str, int] = {};
        self.pass_time: dict[str, float] = {};
        self.early_passes: dict[int, PendingPassResults] = {};
        self.cache_events: dict[str, int] = {};
    }

    def record_early(
        self: AnalysisCaches, module: uni.Module, results: dict[str, PassResult]
    ) {
        self.early_passes[id(module)] = PendingPassResults(module, results);
    }

    def take_early(
        self: AnalysisCaches, module: uni.Module, name: str
    ) -> (PassResult | None) {
        pending = self.early_passes.get(id(module));
        if pending is None {
            return None;
        }
        result = pending.results.pop(name, None);
        if not pending.results {
            self.early_passes.pop(id(module));
        }
        return result;
    }
}

glob UNIT_COLLECT_EVERY: int = 16,
     UNIT_COLLECT_GROWTH_MB: int = 512;

def _env_int(name: str, fallback: int) -> int {
    raw = os.environ.get(name, "").strip();
    if not raw {
        return fallback;
    }
    try {
        return int(raw);
    } except ValueError {
        return fallback;
    }
}

def _peak_rss_mb -> int {
    try {
        import resource;
    } except ImportError {
        return 0;
    }
    peak = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss;
    if sys.platform == "darwin" {
        return int(peak // (1024 * 1024));
    }
    return int(peak // 1024);
}

obj UnitCollectBudget {
    has releases: int = 0,
        last_peak_mb: int = 0;

    def due(units: int = 1) -> bool {
        self.releases += units;
        every = _env_int("JAC_UNIT_COLLECT_EVERY", UNIT_COLLECT_EVERY);
        growth = _env_int("JAC_UNIT_COLLECT_GROWTH_MB", UNIT_COLLECT_GROWTH_MB);
        peak = _peak_rss_mb();
        if self.last_peak_mb == 0 {
            self.last_peak_mb = peak;
        }
        by_count = every > 0 and self.releases >= every;
        by_growth = growth > 0 and (peak - self.last_peak_mb) >= growth;
        if not (by_count or by_growth) {
            return False;
        }
        self.releases = 0;
        self.last_peak_mb = peak;
        return True;
    }
}

glob unit_collect_budget: UnitCollectBudget = UnitCollectBudget();
