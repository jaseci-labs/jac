import from jaclang.compiler.session.services { AnalysisServices }
import type from jaclang.compiler.session.imports { IfaceRegistry }
import type from jaclang.compiler.backends.common.artifacts { NativeModuleLayout }
import from jaclang.compiler.pipeline.contracts { PassIdentity }
import from jaclang.compiler.backends.common.artifact_store { artifact_for }
import from jaclang.compiler.pipeline.contracts { CompilationProduct }
import from jaclang.compiler.pipeline.contracts { AnalysisFact }
import type from jaclang.compiler.session.cache.catalog_reader { StubCatalog }
import types;
import from threading { Event }
import jaclang.compiler.ir.schema as uni;
import from jaclang.compiler.ir.symbols.edges { ScopeChild }
import from jaclang.compiler.session.options { CompileOptions }
import from jaclang.compiler.pipeline.pass_base { Alert }
import from jaclang.compiler.pipeline.products { ProductStore }
import from jaclang.compiler.session.modules {
    BuildScratch,
    DepGraph,
    DiagLedger,
    ModuleHub,
    unit_collect_budget
}
import type from jaclang.compiler.backends.common.artifacts { ClientArtifact }
import type from jaclang.compiler.analysis.types.type_evaluator { TypeEvaluator }
import type from jaclang.compiler.session.compiler { JacCompiler }
import type from jaclang.compiler.lowering.mtir { Info }
import type from jaclang.compiler.pipeline.pass_base { Transform }
import type from jaclang.compiler.session.sources { SourceStore }

class JacProgram(AnalysisServices) {
    has hub: ModuleHub,
        deps: DepGraph,
        diags: DiagLedger,
        scratch: BuildScratch,
        analysis: ProductStore,
        options: CompileOptions,
        mod: uni.ProgramModule,
        errors_had: list[Alert],
        warnings_had: list[Alert],
        mtir_map: dict[(str, Info)],
        type_evaluator: TypeEvaluator | None,
        _compiler: JacCompiler | None,
        _iface: IfaceRegistry | None,
        _catalog: StubCatalog | None,
        source_store: SourceStore,
        context_root: JacProgram | None,
        context_key: str,
        contexts: dict[str, JacProgram];

    def init(self: JacProgram, main_mod: (uni.ProgramModule | None) = None) -> None;
    def _get_compiler(self: JacProgram) -> JacCompiler;
    def module_context(self: JacProgram, module: uni.Module) -> AnalysisServices {
        permit = module.mutation_permit;
        if permit is None or permit is self.analysis.mutations {
            return self;
        }
        context_root = self.context_root if self.context_root is not None else self;
        if permit is context_root.analysis.mutations {
            return context_root;
        }
        for context in context_root.contexts.values() {
            if permit is context.analysis.mutations {
                return context;
            }
        }
        bootstrap = self._get_compiler().selfhost.program;
        if permit is bootstrap.analysis.mutations {
            return bootstrap;
        }
        raise ValueError("Module belongs to another compilation session");
    }

    def is_bootstrap(self: JacProgram) -> bool {
        return self._get_compiler().selfhost.is_selfhost(self);
    }

    def native_layout(self: JacProgram, path: str) -> NativeModuleLayout | None {
        return self._get_compiler().get_native_layout(path, self);
    }

    def iface_registry(self: JacProgram) -> IfaceRegistry;
    def get_type_evaluator(self: JacProgram) -> TypeEvaluator;
    def stub_catalog(self: JacProgram) -> StubCatalog | None;
    def clear_type_system(self: JacProgram, clear_hub: bool = False) -> None;
    def release_compile_closure(self: JacProgram, collect: bool = True) -> None;
    def release_native_dep_units(self: JacProgram) -> None;
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
    def find_module(self: JacProgram, path: str) -> (uni.Module | None);
    def get_bytecode(self: JacProgram, full_target: str) -> (types.CodeType | None);
    def get_client_artifact(
        self: JacProgram, full_target: str
    ) -> (ClientArtifact | None);

    def parse_str(
        self: JacProgram,
        source_str: str,
        file_path: str,
        cancel_token: (Event | None) = None
    ) -> uni.Module;

    def compile(
        self: JacProgram,
        file_path: str,
        use_str: (str | None) = None,
        no_cgen: bool = False,
        symtab_ir_only: bool = False,
        cancel_token: (Event | None) = None,
        options: (CompileOptions | None) = None
    ) -> uni.Module;

    def build(
        self: JacProgram, file_path: str, use_str: (str | None) = None
    ) -> uni.Module;

    static def jac_file_formatter(
        file_path: str, auto_lint: bool = False
    ) -> JacProgram {
        import from jaclang.compiler.session.compiler { JacCompiler }
        return JacCompiler.jac_file_formatter(file_path, auto_lint);
    }

    static def jac_str_formatter(
        source_str: str, file_path: str, auto_lint: bool = False
    ) -> JacProgram {
        import from jaclang.compiler.session.compiler { JacCompiler }
        return JacCompiler.jac_str_formatter(source_str, file_path, auto_lint);
    }

    static def jac_file_linter(file_path: str) -> JacProgram {
        import from jaclang.compiler.session.compiler { JacCompiler }
        return JacCompiler.jac_file_linter(file_path);
    }
}
