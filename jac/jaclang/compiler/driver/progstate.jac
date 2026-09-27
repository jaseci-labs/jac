import from jaclang.compiler.frontend.roles { Kid }
import os;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.relations { ScopeChild }
import from jaclang.compiler.passes.context { Alert, PassResult }
import type from jaclang.runtime.semantic { Info }
import type from jaclang.compiler.frontend.codeinfo { ClientArtifact, CodeGenTarget }
import type from jaclang.compiler.placement.placement { PlacementSummary }
import type from jaclang.compiler.placement.placement_work { PlacementWork }
import from jaclang.compiler.driver.pipeline_types {
    AnalysisFact,
    CompilationProduct,
    ProductTask
}

obj ModuleHub {
    has mod: uni.ProgramModule,
        stamps: dict[str, float] = {},
        artifacts: dict[str, CodeGenTarget] = {},
        client_artifacts: dict[str, ClientArtifact] = {};

    def stamp(resolved_path: str) {
        import time;
        import from jaclang.compiler.frontend.host { active_host }
        seen = time.time();
        try {
            seen = max(seen, os.path.getmtime(resolved_path));
            for related in active_host().annex_files(resolved_path) {
                seen = max(seen, os.path.getmtime(related));
            }
            wiring = active_host().wiring_file(resolved_path);
            if wiring is not None {
                seen = max(seen, os.path.getmtime(wiring));
            }
        } except OSError {}
        self.stamps[resolved_path] = seen;
    }

    def is_fresh(resolved_path: str) -> bool {
        import os;
        import from jaclang.compiler.frontend.host { active_host }
        cached_at = self.stamps.get(resolved_path);
        if cached_at is None {
            return True;
        }
        try {
            if os.path.getmtime(resolved_path) > cached_at {
                return False;
            }
            for related in active_host().annex_files(resolved_path) {
                if os.path.getmtime(related) > cached_at {
                    return False;
                }
            }
            wiring = active_host().wiring_file(resolved_path);
            if wiring is not None and os.path.getmtime(wiring) > cached_at {
                return False;
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
        dropped_ids: set[int] = {id(m) for m in dropped};
        prog_root = self.mod;
        main = prog_root.main_mod;
        if main is not None and id(main) in dropped_ids {
            prog_root.main_mod = None;
        }
        prog_root.set_kids(
            [
                k
                for k in [prog_root->:Kid:->]
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
        if mod.loc is None {
            return;
        }
        mod_path = mod.loc.mod_path;
        if not mod_path.endswith(".jac") {
            return;
        }
        importer = os.path.realpath(mod_path);
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
                    target = os.path.realpath(mp.resolve_relative_path());
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
        kept_errors = [
            a
            for a in self.errors
            if not self._owned(a, resolved_path)
        ];
        kept_warnings = [
            a
            for a in self.warnings
            if not self._owned(a, resolved_path)
        ];
        self.errors.clear();
        self.errors.extend(kept_errors);
        self.warnings.clear();
        self.warnings.extend(kept_warnings);
    }

    def _owned(alert: Alert, path: str) -> bool {
        import os;
        import from jaclang.compiler.frontend.host { active_host }
        try {
            norm = os.path.realpath(path);
        } except OSError {
            return False;
        }
        return alert.owner == norm or active_host().is_annex_path_of(alert.owner, norm);
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
    has _tags: dict[int, set[AnalysisFact]],
        _owners: dict[int, uni.Module];

    def init(self: AnalysisLedger) {
        self._tags: dict[int, set[AnalysisFact]] = {};
        self._owners: dict[int, uni.Module] = {};
    }

    def provided(self: AnalysisLedger, mod: uni.Module) -> set[AnalysisFact] {
        key = id(mod);
        if self._owners.get(key) is mod {
            return self._tags[key];
        }
        tags: set[AnalysisFact] = set();
        self._tags[key] = tags;
        self._owners[key] = mod;
        return tags;
    }

    def provides(self: AnalysisLedger, mod: uni.Module, tag: AnalysisFact) -> bool {
        key = id(mod);
        return self._owners.get(key) is mod and tag in self._tags[key];
    }

    def mark(self: AnalysisLedger, mod: uni.Module, tags: set[AnalysisFact]) {
        live = self.provided(mod);
        live.clear();
        live.update(tags);
    }

    def forget(self: AnalysisLedger, mod: uni.Module) {
        key = id(mod);
        if self._owners.get(key) is mod {
            self._tags.pop(key, None);
            self._owners.pop(key, None);
        }
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
    has placement_summaries: dict[str, PlacementSummary],
        placement_work: (PlacementWork | None),
        placement_evidence: dict[str, list[str]],
        native_verdict_notes: dict[str, tuple[str, str]],
        analyses_run: AnalysisLedger,
        mtir_map: dict[(str, Info)],
        pass_runs: dict[str, int],
        pass_time: dict[str, float],
        phase_time: dict[str, float],
        completed_passes: dict[int, set[str]],
        product_tasks: dict[int, dict[CompilationProduct, ProductTask]],
        task_owners: dict[int, uni.Module],
        early_passes: dict[int, PendingPassResults],
        cache_events: dict[str, int];

    def init(self: AnalysisCaches) {
        self.placement_summaries: dict[str, PlacementSummary] = {};
        self.placement_work: (PlacementWork | None) = None;
        self.placement_evidence: dict[str, list[str]] = {};
        self.native_verdict_notes: dict[str, tuple[str, str]] = {};
        self.analyses_run: AnalysisLedger = AnalysisLedger();
        self.mtir_map: dict[(str, Info)] = {};
        self.pass_runs: dict[str, int] = {};
        self.pass_time: dict[str, float] = {};
        self.phase_time: dict[str, float] = {};
        self.completed_passes: dict[int, set[str]] = {};
        self.product_tasks: dict[int, dict[CompilationProduct, ProductTask]] = {};
        self.task_owners: dict[int, uni.Module] = {};
        self.early_passes: dict[int, PendingPassResults] = {};
        self.cache_events: dict[str, int] = {};
    }

    def retain_tasks(self: AnalysisCaches, module: uni.Module) {
        key = id(module);
        if self.task_owners.get(key) is module {
            return;
        }
        self.drop_tasks(key);
        self.task_owners[key] = module;
    }

    def drop_tasks(self: AnalysisCaches, key: int) {
        self.completed_passes.pop(key, None);
        self.product_tasks.pop(key, None);
        self.task_owners.pop(key, None);
    }

    def forget_module(self: AnalysisCaches, module: uni.Module) {
        key = id(module);
        self.analyses_run.forget(module);
        if self.task_owners.get(key) is module {
            self.drop_tasks(key);
        }
        pending = self.early_passes.get(key);
        if pending is not None and pending.module is module {
            self.early_passes.pop(key, None);
        }
    }

    def reset_module_state(self: AnalysisCaches) {
        self.analyses_run.clear();
        self.placement_work = None;
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
