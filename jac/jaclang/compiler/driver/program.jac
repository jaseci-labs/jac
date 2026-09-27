import from jaclang.compiler.frontend.roles { Kid }
import from jaclang.compiler.driver.pipeline_types { AnalysisFact }
import type from jaclang.compiler.types.stubcat.reader { StubCatalog }
import os;
import type from jaclang.compiler.driver.compile_options { CancelToken }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.relations { ScopeChild }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.passes.context { Alert, PassSchedule }
import from jaclang.compiler.driver.progstate {
    AnalysisCaches,
    BuildScratch,
    DepGraph,
    DiagLedger,
    ModuleHub
}
import type from jaclang.compiler.types.type_evaluator { TypeEvaluator }
import type from jaclang.compiler.driver.nativecache { NativeUnitRegistry }
import type from jaclang.compiler.driver.ifacecache { IfaceRegistry }
import type from jaclang.compiler.driver.compiler { JacCompiler }
import type from jaclang.runtime.semantic { Info }


class JacProgram {
    has hub: ModuleHub,
        deps: DepGraph,
        diags: DiagLedger,
        scratch: BuildScratch,
        analysis: AnalysisCaches,
        options: CompileOptions,
        mod: uni.ProgramModule,
        errors_had: list[Alert],
        warnings_had: list[Alert],
        mtir_map: dict[(str, Info)],
        type_evaluator: TypeEvaluator | None,
        _compiler: JacCompiler | None,
        _stub_catalog: StubCatalog | None,
        _stub_trees_served: bool,
        _iface: IfaceRegistry | None,
        _natives: NativeUnitRegistry | None,
        context_root: JacProgram | None,
        context_key: str,
        contexts: dict[str, JacProgram],
        internal: bool;

    def init(self: JacProgram, main_mod: (uni.ProgramModule | None) = None) -> None;
    def _get_compiler(self: JacProgram) -> JacCompiler;
    def iface_registry(self: JacProgram) -> IfaceRegistry;
    def native_units(self: JacProgram) -> NativeUnitRegistry;
    def get_type_evaluator(self: JacProgram) -> TypeEvaluator;
    def stub_catalog(self: JacProgram) -> StubCatalog | None;
    def note_stub_tree_served(self: JacProgram, path: str) -> None;
    def clear_type_system(self: JacProgram, clear_hub: bool = False) -> None;
    def release_compile_closure(
        self: JacProgram, collect: bool = True, retain_stubs: bool = True
    ) -> None;

    def scrub_hub_types(self: JacProgram) -> None;
    def release_check_caches(self: JacProgram) -> None;
    def hub_cache_stamp(self: JacProgram, resolved_path: str) -> None;
    def install_module(self: JacProgram, resolved_path: str, mod: uni.Module) -> None;
    def is_hub_entry_fresh(self: JacProgram, resolved_path: str) -> bool;
    def record_dependency(
        self: JacProgram, importer_path: str, target_path: str
    ) -> None;

    def transitive_dependents(self: JacProgram, target_path: str) -> set[str];
    def invalidate_module(self: JacProgram, resolved_path: str) -> None;
    def release_module(self: JacProgram, resolved_path: str) -> None;
    def load_dependency_module(
        self: JacProgram,
        source_path: str,
        importer_path: (str | None) = None,
        use_str: (str | None) = None,
        need_tree: bool = False
    ) -> uni.Module;

    def drop_module_alerts(self: JacProgram, resolved_path: str) -> None;
    def reset_module_root(self: JacProgram, module_root: uni.ProgramModule) -> None;
    static def hub_key(path: str) -> str;
    def has_failed_parse(self: JacProgram, path: str) -> bool;
    def execution_hubs(self: JacProgram) -> list[dict[str, uni.Module]];
    def find_module(self: JacProgram, path: str) -> (uni.Module | None);
    def parse_source(
        self: JacProgram,
        source_str: str,
        file_path: str,
        cancel_token: (CancelToken | None) = None
    ) -> uni.Module;

    def parse_str(
        self: JacProgram,
        source_str: str,
        file_path: str,
        cancel_token: (CancelToken | None) = None
    ) -> uni.Module;

    def declared_codespace(self: JacProgram, file_path: str) -> str;
    def infers_native_codespace(self: JacProgram, file_path: str) -> bool;
    def resolve_absorb_imports(self: JacProgram, mod: uni.Module) -> None;
    def stamp_boundary_facts(self: JacProgram, mod: uni.Module) -> None;
    def stamp_app_facts(self: JacProgram, mod: uni.Module) -> None;
    def stamp_access_check_facts(self: JacProgram, mod: uni.Module) -> None;
    def stamp_native_import_facts(self: JacProgram, mod: uni.Module) -> None;
    def ingest_comptime_producers(
        self: JacProgram, mod_targ: uni.Module, file_path: str
    ) -> None;

    def count_module_blocking_errors(self: JacProgram, mod_path: str) -> int;
    def count_module_errors(self: JacProgram, mod_path: str) -> int;
    def module_scoped_errors(self: JacProgram, mod_path: str) -> bool;
    def compile(
        self: JacProgram,
        file_path: str,
        use_str: (str | None) = None,
        no_cgen: bool = False,
        symtab_ir_only: bool = False,
        cancel_token: (CancelToken | None) = None,
        options: (CompileOptions | None) = None
    ) -> uni.Module;

    def build(
        self: JacProgram, file_path: str, use_str: (str | None) = None
    ) -> uni.Module;

    def run_schedule(
        self: JacProgram,
        mod: uni.Module,
        passes: PassSchedule,
        cancel_token: (CancelToken | None) = None
    ) -> None;

    static def jac_file_formatter(
        file_path: str, auto_lint: bool = False
    ) -> JacProgram {
        import from jaclang.compiler.frontend.host { active_host }
        return active_host().format_file(file_path, auto_lint);
    }

    static def jac_str_formatter(
        source_str: str, file_path: str, auto_lint: bool = False
    ) -> JacProgram {
        import from jaclang.compiler.frontend.host { active_host }
        return active_host().format_source(source_str, file_path, auto_lint);
    }

    static def jac_file_linter(file_path: str) -> JacProgram {
        import from jaclang.compiler.frontend.host { active_host }
        return active_host().lint_file(file_path);
    }
}
