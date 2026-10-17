import os;

obj ModuleHub {
    has mod: uni.ProgramModule,
        stamps: dict[str, float] = {},
        artifacts: dict[str, CodeGenTarget] = {},
        client_artifacts: dict[str, ClientArtifact] = {};

    def stamp(resolved_path: str) {
        import time;
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

obj ModuleBuild {
    has module: uni.Module,
        done: set[str],
        tasks: dict[CompilationProduct, ProductTask],
        facts: set[AnalysisFact],
        early: dict[str, PassResult];
}

class AnalysisCaches {
    has placement_summaries: dict[str, PlacementSummary],
        placement_work: (PlacementWork | None),
        placement_evidence: dict[str, list[str]],
        capability_notes: dict[str, dict[str, CapabilityNote]],
        native_bindings: any,
        placement_refusals: dict[str, dict[str, set[int]]],
        mtir_map: dict[(str, Info)],
        mtir_owned: dict[str, list[str]],
        pass_runs: dict[str, int],
        pass_time: dict[str, float],
        phase_time: dict[str, float],
        builds: dict[int, ModuleBuild],
        product_facts: dict[CompilationProduct, set[AnalysisFact]],
        cache_events: dict[str, int],
        running: (CompileContext | None);

    def init(self: AnalysisCaches) {
        self.placement_summaries: dict[str, PlacementSummary] = {};
        self.placement_work: (PlacementWork | None) = None;
        self.placement_evidence: dict[str, list[str]] = {};
        self.capability_notes: dict[str, dict[str, CapabilityNote]] = {};
        self.native_bindings: any = None;
        self.placement_refusals: dict[str, dict[str, set[int]]] = {};
        self.mtir_map: dict[(str, Info)] = {};
        self.mtir_owned: dict[str, list[str]] = {};
        self.pass_runs: dict[str, int] = {};
        self.pass_time: dict[str, float] = {};
        self.phase_time: dict[str, float] = {};
        self.builds: dict[int, ModuleBuild] = {};
        self.product_facts: dict[CompilationProduct, set[AnalysisFact]] = {};
        self.cache_events: dict[str, int] = {};
        self.running: (CompileContext | None) = None;
    }

    def build(self: AnalysisCaches, module: uni.Module) -> ModuleBuild {
        key = id(module);
        found = self.builds.get(key);
        if found is not None and found.module is module {
            return found;
        }
        fresh = ModuleBuild(module=module, done=set(), tasks={}, facts=set(), early={});
        self.builds[key] = fresh;
        return fresh;
    }

    def peek(self: AnalysisCaches, module: uni.Module) -> (ModuleBuild | None) {
        found = self.builds.get(id(module));
        if found is not None and found.module is module {
            return found;
        }
        return None;
    }

    def provides(self: AnalysisCaches, module: uni.Module, fact: AnalysisFact) -> bool {
        found = self.peek(module);
        return found is not None and fact in found.facts;
    }

    def mark_facts(self: AnalysisCaches, module: uni.Module, facts: set[AnalysisFact]) {
        live = self.build(module).facts;
        live.clear();
        live.update(facts);
    }

    def forget_module(self: AnalysisCaches, module: uni.Module) {
        if self.peek(module) is not None {
            self.builds.pop(id(module), None);
        }
    }

    def reset_module_state(self: AnalysisCaches) {
        self.placement_work = None;
        self.capability_notes.clear();
        self.placement_refusals.clear();
        self.native_bindings = None;
        self.builds.clear();
    }

    def record_early(
        self: AnalysisCaches, module: uni.Module, results: dict[str, PassResult]
    ) {
        self.build(module).early = results;
    }

    def take_early(
        self: AnalysisCaches, module: uni.Module, name: str
    ) -> (PassResult | None) {
        found = self.peek(module);
        if found is None {
            return None;
        }
        return found.early.pop(name, None);
    }
}
