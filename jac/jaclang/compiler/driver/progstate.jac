import from jaclang.compiler.driver.dependency_graph { DepGraph }
import os;
import sys;
import time;
import from contextlib { contextmanager }
import from contextvars { ContextVar }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.relations { ScopeChild }
import from jaclang.compiler.passes.transform { Alert, PassResult }
import type from jaclang.runtime.semantic { Info }
import type from jaclang.compiler.frontend.codeinfo { ClientArtifact }
import from jaclang.compiler.driver.pipeline_types {
    AnalysisFact,
    CompilationProduct,
    ProductTask
}

obj ModuleHub {
    has mod: uni.ProgramModule,
        stamps: dict[str, str] = {},
        artifacts: dict[str, any] = {},
        client_artifacts: dict[str, ClientArtifact] = {};

    def stamp(resolved_path: str) {
        import from jaclang.compiler.driver.jir { module_source_key }
        try {
            self.stamps[resolved_path] = module_source_key(resolved_path);
        } except OSError {
            self.stamps.pop(resolved_path, None);
        }
    }

    def is_fresh(resolved_path: str) -> bool {
        import from jaclang.compiler.driver.jir { module_source_key }
        revision = self.stamps.get(resolved_path);
        if revision is None {
            return False;
        }
        try {
            return module_source_key(resolved_path) == revision;
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

    def reset(retain_stubs: bool = True) {
        retained_mods: dict[str, uni.Module] = {};
        retained_stamps: dict[str, str] = {};
        dropped: list[uni.Module] = [];
        for (path, mod) in self.mod.hub.items() {
            if retain_stubs and path.endswith(".pyi") {
                retained_mods[path] = mod;
                if path in self.stamps {
                    retained_stamps[path] = self.stamps[path];
                }
            } else {
                dropped.append(mod);
            }
        }
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
        prog_root.hub.update(retained_mods);
        self.stamps.clear();
        self.stamps.update(retained_stamps);
        self.client_artifacts.clear();
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
    has na_dep_units: dict[str, (uni.Module | str)] = {},
        na_dep_inflight: set[str] postinit,
        na_verdict_resolving: set[str] postinit,
        na_unverified_live: dict[str, dict] = {},
        na_verdict_misses: int = 0,
        compile_depth: int = 0;

    def postinit {
        self.na_dep_inflight = set();
        self.na_verdict_resolving = set();
    }

    def clear {
        self.na_dep_units.clear();
        self.na_dep_inflight.clear();
        self.na_verdict_resolving.clear();
        self.na_unverified_live.clear();
        self.na_verdict_misses = 0;
        self.compile_depth = 0;
    }
}

class AnalysisLedger {
    has _tags: dict[int, set[AnalysisFact]],
        _owners: dict[int, any];

    def init(self: AnalysisLedger) {
        self._tags: dict[int, set[AnalysisFact]] = {};
        self._owners: dict[int, any] = {};
    }

    def _drop(self: AnalysisLedger, key: int) {
        try {
            self._tags.pop(key, None);
            self._owners.pop(key, None);
        } except Exception {}
    }

    def provided(self: AnalysisLedger, mod: any) -> set[AnalysisFact] {
        import weakref;
        key = id(mod);
        owner = self._owners.get(key);
        if owner is not None and owner() is mod {
            return self._tags[key];
        }
        tags: set[AnalysisFact] = set();
        self._tags[key] = tags;
        self._owners[key] = weakref.ref(mod, lambda (_ref: any) { self._drop(key); });
        return tags;
    }

    def provides(self: AnalysisLedger, mod: any, tag: AnalysisFact) -> bool {
        owner = self._owners.get(id(mod));
        return owner is not None and owner() is mod and tag in self._tags[id(mod)];
    }

    def mark(self: AnalysisLedger, mod: any, tags: set[AnalysisFact]) {
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

obj TimingSample {
    has runs: int = 0,
        wall_seconds: float = 0.0,
        exclusive_seconds: float = 0.0;
}

glob _timing_stack: ContextVar[tuple[list[float], ...]] = ContextVar(
         "jac_compilation_timing", `default=()
     );

class AnalysisCaches {
    has placement_summaries: dict[str, any],
        placement_state: dict[str, any],
        analyses_run: AnalysisLedger,
        mtir_map: dict[(str, Info)],
        pass_runs: dict[str, int],
        pass_time: dict[str, float],
        phase_time: dict[str, float],
        parse_runs: dict[str, int],
        tree_hits: dict[str, int],
        completed_passes: dict[int, set[str]],
        product_tasks: dict[int, dict[CompilationProduct, ProductTask]],
        module_diagnostics: dict[int, dict[str, DiagLedger]],
        task_owners: dict[int, any],
        early_passes: dict[int, dict[str, PassResult]],
        cache_events: dict[str, int],
        timings: dict[str, dict[str, TimingSample]] = {};

    @contextmanager
    def measure(self: AnalysisCaches, path: str, name: str) -> Iterator[None] {
        stack = _timing_stack.get();
        children = [0.0];
        token = _timing_stack.set(stack + (children, ));
        started = time.perf_counter();
        try {
            yield ;
        } finally {
            elapsed = time.perf_counter() - started;
            _timing_stack.reset(token);
            if stack {
                stack[-1][0] += elapsed;
            }
            sample = self.timings.setdefault(path, {}).setdefault(name, TimingSample());
            sample.runs += 1;
            sample.wall_seconds += elapsed;
            sample.exclusive_seconds += max(0.0, elapsed - children[0]);
        }
    }

    def measurements(self: AnalysisCaches) -> dict[str, any] {
        return {
            "timings": {
                path: {
                    name: {
                        "runs": sample.runs,
                        "wall_seconds": sample.wall_seconds,
                        "exclusive_seconds": sample.exclusive_seconds
                    } for (name, sample) in phases.items()
                } for (path, phases) in self.timings.items()
            },
            "parse_runs": dict(self.parse_runs),
            "tree_hits": dict(self.tree_hits),
            "pass_runs": dict(self.pass_runs),
            "cache_events": dict(self.cache_events)
        };
    }

    def reset_measurements(self: AnalysisCaches) {
        self.timings.clear();
        self.parse_runs.clear();
        self.tree_hits.clear();
        self.pass_runs.clear();
        self.pass_time.clear();
        self.phase_time.clear();
        self.cache_events.clear();
    }

    def init(self: AnalysisCaches) {
        self.timings = {};
        self.placement_summaries: dict[str, any] = {};
        self.placement_state: dict[str, any] = {};
        self.analyses_run: AnalysisLedger = AnalysisLedger();
        self.mtir_map: dict[(str, Info)] = {};
        self.pass_runs: dict[str, int] = {};
        self.pass_time: dict[str, float] = {};
        self.phase_time: dict[str, float] = {};
        self.parse_runs = {};
        self.tree_hits = {};
        self.completed_passes = {};
        self.product_tasks = {};
        self.module_diagnostics = {};
        self.task_owners = {};
        self.early_passes = {};
        self.cache_events: dict[str, int] = {};
    }

    def retain_tasks(self: AnalysisCaches, module: uni.Module) {
        import weakref;
        key = id(module);
        owner = self.task_owners.get(key);
        if owner is not None and owner() is module {
            return;
        }
        self.drop_tasks(key);
        self.task_owners[key] = weakref.ref(
            module, lambda (_ref: any) { self.drop_tasks(key); }
        );
    }

    def drop_tasks(self: AnalysisCaches, key: int) {
        self.completed_passes.pop(key, None);
        self.product_tasks.pop(key, None);
        self.module_diagnostics.pop(key, None);
        self.early_passes.pop(key, None);
        self.task_owners.pop(key, None);
    }

    def clear_tasks(self: AnalysisCaches) {
        self.completed_passes.clear();
        self.product_tasks.clear();
        self.module_diagnostics.clear();
        self.early_passes.clear();
        self.task_owners.clear();
    }

    def record_early(
        self: AnalysisCaches, module: uni.Module, results: dict[str, PassResult]
    ) {
        self.retain_tasks(module);
        self.early_passes[id(module)] = results;
    }

    def take_early(
        self: AnalysisCaches, module: uni.Module, name: str
    ) -> (PassResult | None) {
        self.retain_tasks(module);
        pending = self.early_passes.get(id(module));
        if pending is None {
            return None;
        }
        result = pending.pop(name, None);
        if not pending {
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
    import from jaclang.runtime.resource_usage { peak_rss_mb }
    return peak_rss_mb();
}

obj UnitCollectBudget {
    has releases: int = 0,
        last_peak_mb: int = 0;

    def due -> bool {
        self.releases += 1;
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
