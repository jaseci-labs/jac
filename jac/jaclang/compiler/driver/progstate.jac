import type from jaclang.compiler.driver.inputs { InputManifest }
import os;
import sys;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.relations { ScopeChild }
import from jaclang.compiler.frontend.roles { MainRole }
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
        stamps: dict[str, float] = {},
        inputs: dict[str, InputManifest] = {},
        artifacts: dict[str, any] = {},
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
        was_main = any(item is prev for item in [self.mod->:MainRole:->]);
        self.detach([prev]);
        if was_main {
            self.mod.main_mod = mod;
            self.mod.add_kids_right([mod]);
        }
        return prev;
    }

    def detach(modules: list[uni.Module]) {
        removed = {id(module) for module in modules};
        if any(id(item) in removed for item in [self.mod->:MainRole:->]) {
            self.mod.main_mod = None;
        }
        self.mod.set_kids(
            [
                child
                for child in self.mod.kid
                if id(child) not in removed
            ],
            pos_update=False
        );
        for module in modules {
            del [edge module<-:ScopeChild:<-];
        }
        if self.mod.kid {
            (first_tok, last_tok) = self.mod.resolve_tok_range();
            self.mod.loc.update_token_range(first_tok, last_tok);
        } else {
            empty_tok = uni.EmptyToken();
            self.mod.loc.update_token_range(empty_tok, empty_tok);
        }
    }

    def evict(resolved_path: str) {
        self.inputs.pop(resolved_path, None);
        previous = self.mod.hub.pop(resolved_path, None);
        if previous is not None {
            self.detach([previous]);
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
        retained_stamps: dict[str, float] = {};
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
        prog_root = self.mod;
        self.detach(dropped);
        prog_root.hub.clear();
        prog_root.hub.update(retained_mods);
        self.stamps.clear();
        self.inputs.clear();
        self.stamps.update(retained_stamps);
        self.client_artifacts.clear();
    }
}

obj DepGraph {
    has dependents: dict[str, set[str]] = {},
        dependencies: dict[str, set[str]] = {},
        pending: dict[str, set[str]] = {},
        tracking: bool = False;

    def record(importer_path: str, target_path: str) -> None {
        self._record(os.path.realpath(importer_path), os.path.realpath(target_path));
    }

    """Record source-store inputs, whose paths are already canonical."""
    def record_inputs(importer_path: str, inputs: InputManifest) -> None {
        importer_path = os.path.realpath(importer_path);
        for target_path in inputs.files {
            self._record(importer_path, target_path);
        }
    }

    def _record(importer_path: str, target_path: str) -> None {
        if importer_path == target_path {
            return;
        }
        self.dependencies.setdefault(importer_path, set()).add(target_path);
        if importer_path in self.pending {
            self.pending[importer_path].add(target_path);
        }
        bucket = self.dependents.get(target_path);
        if bucket is None {
            bucket = set();
            self.dependents[target_path] = bucket;
        }
        bucket.add(importer_path);
    }

    def begin(path: str) {
        self.pending[os.path.realpath(path)] = set();
    }

    def finish(path: str, complete: bool) -> None {
        path = os.path.realpath(path);
        current = self.pending.pop(path, None);
        if current is None or not complete {
            return;
        }
        for target in self.dependencies.get(path, set()) - current {
            bucket = self.dependents.get(target);
            if bucket is not None {
                bucket.discard(path);
                if not bucket {
                    del self.dependents[target];
                }
            }
        }
        self.dependencies[path] = current;
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
        for dependency in mod.ct_file_deps {
            self.record(importer, dependency);
        }
    }

    def transitive_dependents(target_path: str) -> set[str] {
        out: set[str] = set();
        target_path = os.path.realpath(target_path);
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
        out.discard(target_path);
        return out;
    }

    def forget(resolved_path: str) {
        resolved_path = os.path.realpath(resolved_path);
        self.pending.pop(resolved_path, None);
        for target in self.dependencies.pop(resolved_path, set()) {
            bucket = self.dependents.get(target);
            if bucket is not None {
                bucket.discard(resolved_path);
                if not bucket {
                    del self.dependents[target];
                }
            }
        }
    }

    def clear {
        self.dependents.clear();
        self.dependencies.clear();
        self.pending.clear();
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
        na_unverified_live: dict[str, dict[str, set[str]]] = {},
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

obj PendingPassResults {
    has module: uni.Module,
        results: dict[str, PassResult];
}

obj NativeScanRecord {
    has inputs: InputManifest,
        server_reason: str,
        dependencies: tuple[str, ...];
}

class AnalysisCaches {
    has native_scans: dict[tuple[str, bool], NativeScanRecord],
        placement_summaries: dict[str, any],
        placement_state: dict[str, any],
        analyses_run: AnalysisLedger,
        mtir_map: dict[(str, Info)],
        pass_runs: dict[str, int],
        pass_time: dict[str, float],
        phase_time: dict[str, float],
        completed_passes: dict[int, set[str]],
        product_tasks: dict[int, dict[CompilationProduct, ProductTask]],
        task_owners: dict[int, any],
        early_passes: dict[int, PendingPassResults],
        cache_events: dict[str, int];

    def init(self: AnalysisCaches) {
        self.native_scans = {};
        self.placement_summaries: dict[str, any] = {};
        self.placement_state: dict[str, any] = {};
        self.analyses_run: AnalysisLedger = AnalysisLedger();
        self.mtir_map: dict[(str, Info)] = {};
        self.pass_runs: dict[str, int] = {};
        self.pass_time: dict[str, float] = {};
        self.phase_time: dict[str, float] = {};
        self.completed_passes = {};
        self.product_tasks = {};
        self.task_owners = {};
        self.early_passes: dict[int, PendingPassResults] = {};
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
        self.task_owners.pop(key, None);
    }

    def forget_module(self: AnalysisCaches, module: uni.Module) {
        self.early_passes.pop(id(module), None);
        self.drop_tasks(id(module));
    }

    def release(self: AnalysisCaches) {
        self.native_scans.clear();
        self.analyses_run.clear();
        self.placement_summaries.clear();
        self.placement_state.clear();
        self.early_passes.clear();
        self.product_tasks.clear();
        self.completed_passes.clear();
        self.task_owners.clear();
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
