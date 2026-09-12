import type from threading { Event }
import type from jaclang.compiler.ir.schema { Module, ProgramModule }
import type from jaclang.compiler.pipeline.products { ProductStore }
import type from jaclang.compiler.pipeline.pass_base { Alert }
import type from jaclang.compiler.session.options { CompileOptions }
import type from jaclang.compiler.session.modules { DepGraph, ModuleHub, BuildScratch }
import type from jaclang.compiler.session.sources { SourceStore }
import type from jaclang.compiler.session.imports { IfaceRegistry }
import type from jaclang.compiler.session.cache.catalog_reader { StubCatalog }
import type from jaclang.compiler.analysis.types.type_evaluator { TypeEvaluator }
import type from jaclang.compiler.backends.common.artifacts { NativeModuleLayout }

class AnalysisServices {
    has analysis: ProductStore,
        options: CompileOptions,
        deps: DepGraph,
        hub: ModuleHub,
        scratch: BuildScratch,
        mod: ProgramModule,
        source_store: SourceStore,
        context_key: str,
        errors_had: list[Alert],
        warnings_had: list[Alert],
        type_evaluator: TypeEvaluator | None;

    def module_context(
        self: AnalysisServices, module: Module
    ) -> AnalysisServices abst;

    def is_bootstrap(self: AnalysisServices) -> bool abst;
    def native_layout(
        self: AnalysisServices, path: str
    ) -> NativeModuleLayout | None abst;

    def iface_registry(self: AnalysisServices) -> IfaceRegistry abst;
    def get_type_evaluator(self: AnalysisServices) -> TypeEvaluator abst;
    def stub_catalog(self: AnalysisServices) -> StubCatalog | None abst;
    def find_module(self: AnalysisServices, path: str) -> Module | None abst;
    def has_failed_parse(self: AnalysisServices, path: str) -> bool abst;
    def is_hub_entry_fresh(self: AnalysisServices, resolved_path: str) -> bool abst;
    def record_dependency(
        self: AnalysisServices, importer_path: str, target_path: str
    ) abst;

    def transitive_dependents(
        self: AnalysisServices, target_path: str
    ) -> set[str] abst;

    def invalidate_module(self: AnalysisServices, resolved_path: str) abst;
    static def hub_key(path: str) -> str abst;
    def load_dependency_module(
        self: AnalysisServices,
        source_path: str,
        importer_path: str | None = None,
        use_str: str | None = None,
        need_tree: bool = False
    ) -> Module abst;

    def compile(
        self: AnalysisServices,
        file_path: str,
        use_str: str | None = None,
        no_cgen: bool = False,
        symtab_ir_only: bool = False,
        cancel_token: Event | None = None,
        options: CompileOptions | None = None
    ) -> Module abst;
}
