import from jaclang.compiler.ir.identity { MutationPermit }
import from jaclang.compiler.analysis.binding.facts { ImportEdge }
import from jaclang.compiler.analysis.boundaries.facts { ServingFacts }
import from jaclang.compiler.analysis.placement.products { PlacementSpaces }
import os;
import sys;
import jaclang.compiler.ir.schema as uni;
import from jaclang.compiler.ir.symbols.edges { ScopeChild }
import from jaclang.compiler.pipeline.pass_base { Alert, PassResult }
import type from jaclang.compiler.lowering.mtir { Info }
import type from jaclang.compiler.backends.common.artifacts { ClientArtifact }
import from jaclang.compiler.pipeline.contracts {
    PassIdentity,
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
        import from jaclang.compiler.session.cache.keys { module_revision }
        try {
            self.stamps[resolved_path] = module_revision(resolved_path);
        } except OSError {
            self.stamps.pop(resolved_path, None);
        }
    }

    def is_fresh(resolved_path: str) -> bool {
        import from jaclang.compiler.session.cache.keys { module_revision }
        cached = self.stamps.get(resolved_path);
        if cached is None {
            return not os.path.isfile(resolved_path);
        }
        try {
            return module_revision(resolved_path) == cached;
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

    def reset(permit: MutationPermit) {
        import from jaclang.compiler.ir.identity { MutationPermit, MutationScope }
        with MutationScope(permit, 3) {
            retained_mods: dict[str, uni.Module] = {};
            retained_stamps: dict[str, str] = {};
            dropped: list[uni.Module] = [];
            for (path, mod) in self.mod.hub.items() {
                if path.endswith(".pyi") {
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
}

obj DepGraph {
    has imports: dict[str, list[ImportEdge]] = {},
        dependents: dict[str, set[str]] = {},
        tracking: bool = False;

    def restore_imports(path: str, rows: list[tuple[str, str, str]]) {
        import from jaclang.compiler.ir.enums { CodeContext }
        self.imports[path] = [
            ImportEdge(
                target,
                'j' in flags,
                'k' in flags,
                CodeContext.CLIENT
                    if 'c' in flags
                    else (CodeContext.NATIVE if 'n' in flags else CodeContext.SERVER),
                't' in flags,
                'm' in flags
            ) for (target, digest, flags) in rows
        ];
        for edge in self.imports[path] {
            self.record(path, edge.target);
        }
    }

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
        self.imports.pop(resolved_path, None);
        for bucket in self.dependents.values() {
            bucket.discard(resolved_path);
        }
    }

    def clear {
        self.dependents.clear();
        self.imports.clear();
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
