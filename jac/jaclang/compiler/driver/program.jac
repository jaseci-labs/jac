import sys;
import types;
import from threading { Event }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.relations { ScopeChild }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.passes.transform { Alert }
import from jaclang.compiler.driver.progstate {
    AnalysisCaches,
    BuildScratch,
    DepGraph,
    DiagLedger,
    ModuleHub,
    unit_collect_budget
}
import type from jaclang.compiler.frontend.codeinfo { ClientArtifact }
import type from jaclang.compiler.types.type_evaluator { TypeEvaluator }
import type from jaclang.compiler.driver.compiler { JacCompiler }
import type from jaclang.compiler.driver.mtp { Info }
import type from jaclang.compiler.passes.transform { Transform }

with entry {
    if sys.getrecursionlimit() < 12000 {
        sys.setrecursionlimit(12000);
    }
}

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
        _iface: any,
        _natives: any;

    def init(self: JacProgram, main_mod: (uni.ProgramModule | None) = None) -> None;
    def _get_compiler(self: JacProgram) -> JacCompiler;
    def iface_registry(self: JacProgram) -> any;
    def native_units(self: JacProgram) -> any;
    def get_type_evaluator(self: JacProgram) -> TypeEvaluator;
    def stub_catalog(self: JacProgram) -> any;
    def clear_type_system(self: JacProgram, clear_hub: bool = False) -> None;
    def release_compile_closure(self: JacProgram, collect: bool = True) -> None;
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
    def _search_hubs(self: JacProgram) -> list[dict[(str, uni.Module)]];
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

    def run_schedule(
        self: JacProgram,
        mod: uni.Module,
        passes: list[type[Transform]],
        cancel_token: (Event | None) = None
    ) -> None;

    static def jac_file_formatter(
        file_path: str, auto_lint: bool = False
    ) -> JacProgram {
        import from jaclang.compiler.driver.compiler { JacCompiler }
        return JacCompiler.jac_file_formatter(file_path, auto_lint);
    }

    static def jac_str_formatter(
        source_str: str, file_path: str, auto_lint: bool = False
    ) -> JacProgram {
        import from jaclang.compiler.driver.compiler { JacCompiler }
        return JacCompiler.jac_str_formatter(source_str, file_path, auto_lint);
    }

    static def jac_file_linter(file_path: str) -> JacProgram {
        import from jaclang.compiler.driver.compiler { JacCompiler }
        return JacCompiler.jac_file_linter(file_path);
    }
}
