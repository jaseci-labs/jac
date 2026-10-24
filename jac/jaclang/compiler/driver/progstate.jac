import os;

obj ModuleHub {
    has mod: uni.ProgramModule,
        stamps: dict[str, float] = {},
        artifacts: dict[str, CodeGenTarget] = {},
        client_artifacts: dict[str, ClientArtifact] = {};

    def stamp(resolved_path: str);
    def is_fresh(resolved_path: str) -> bool;
    def install(resolved_path: str, mod: uni.Module) -> (uni.Module | None);
    def evict(resolved_path: str);
    def reset(retain_stubs: bool = True);
}

obj DepGraph {
    has dependents: dict[str, set[str]] = {},
        tracking: bool = False;

    def record(importer_path: str, target_path: str) -> None;
    def record_module(mod: uni.Module) -> None;
    def transitive_dependents(target_path: str) -> set[str];
    def forget(resolved_path: str);
    def clear;
}

obj DiagLedger {
    has errors: list[Alert] = [],
        warnings: list[Alert] = [];

    def owned_errors(path: str) -> list[Alert];
    def owned_warnings(path: str) -> list[Alert];
    def drop_module(resolved_path: str);
    def _owned(alert: Alert, path: str) -> bool;
    def clear;
}

obj BuildScratch {
    has boundary_parse_memo: dict[str, any] = {},
        compile_depth: int = 0;

    def clear;
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

    def init(self: AnalysisCaches);
    def build(self: AnalysisCaches, module: uni.Module) -> ModuleBuild;
    def peek(self: AnalysisCaches, module: uni.Module) -> (ModuleBuild | None);
    def provides(self: AnalysisCaches, module: uni.Module, fact: AnalysisFact) -> bool;
    def mark_facts(self: AnalysisCaches, module: uni.Module, facts: set[AnalysisFact]);
    def forget_module(self: AnalysisCaches, module: uni.Module);
    def reset_module_state(self: AnalysisCaches);
    def record_early(
        self: AnalysisCaches, module: uni.Module, results: dict[str, PassResult]
    );

    def take_early(
        self: AnalysisCaches, module: uni.Module, name: str
    ) -> (PassResult | None);
}
