import sys;
import types;
import from threading { Event }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.mtp { Info }
import from jaclang.jac0core.passes { Alert }
import type from jaclang.compiler.type_system.type_evaluator { TypeEvaluator }
import type from jaclang.jac0core.compiler { JacCompiler }
import type from jaclang.jac0core.passes { Transform }

with entry {
    if sys.getrecursionlimit() < 12000 {
        sys.setrecursionlimit(12000);
    }
}

class JacProgram {
    has mod: uni.ProgramModule,
        py_raise_map: dict[(str, str)],
        mtir_map: dict[(str, Info)],
        errors_had: list[Alert],
        warnings_had: list[Alert],
        type_evaluator: TypeEvaluator | None,
        _compiler: JacCompiler | None,
        _compile_options: CompileOptions,
        _native_cache: dict[(str, any)],
        _na_dep_units: dict[(str, any)],
        _na_dep_inflight: set,
        _na_verdict_resolving: set,
        _na_unverified_live: dict[(str, dict)],
        _na_verdict_misses: int,
        _hub_cache_times: dict[str, float],
        _dependents: dict[str, set[str]],
        _track_dependencies: bool,
        _inferred_mods: set,
        _analyses_run: dict,
        _placement_summaries: dict,
        _placement_state: dict,
        _boundary_parse_memo: dict,
        _compile_depth: int;

    def init(self: JacProgram, main_mod: (uni.ProgramModule | None) = None) -> None;
    def _get_compiler(self: JacProgram) -> JacCompiler;
    def get_type_evaluator(self: JacProgram) -> TypeEvaluator;
    def clear_type_system(self: JacProgram, clear_hub: bool = False) -> None;
    def release_compile_closure(self: JacProgram, keep_stubs: bool = False) -> None;
    def release_native_dep_units(self: JacProgram) -> None;
    def release_check_caches(self: JacProgram) -> None;
    def hub_cache_stamp(self: JacProgram, resolved_path: str) -> None;
    def is_hub_entry_fresh(self: JacProgram, resolved_path: str) -> bool;
    def record_dependency(
        self: JacProgram, importer_path: str, target_path: str
    ) -> None;

    def record_module_dependencies(self: JacProgram, mod: uni.Module) -> None;
    def transitive_dependents(self: JacProgram, target_path: str) -> set[str];
    def invalidate_module(self: JacProgram, resolved_path: str) -> None;
    def load_dependency_module(
        self: JacProgram,
        source_path: str,
        importer_path: (str | None) = None,
        use_str: (str | None) = None
    ) -> uni.Module;

    def drop_module_alerts(self: JacProgram, resolved_path: str) -> None;
    static def hub_key(path: str) -> str;
    def has_failed_parse(self: JacProgram, path: str) -> bool;
    def _search_hubs(self: JacProgram) -> list[dict[(str, uni.Module)]];
    def find_module(self: JacProgram, path: str) -> (uni.Module | None);
    def get_bytecode(self: JacProgram, full_target: str) -> (types.CodeType | None);
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
        type_check: bool = False,
        symtab_ir_only: bool = False,
        cancel_token: (Event | None) = None,
        options: (CompileOptions | None) = None
    ) -> uni.Module;

    def build(
        self: JacProgram,
        file_path: str,
        use_str: (str | None) = None,
        type_check: bool = False
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
        import from jaclang.jac0core.compiler { JacCompiler }
        return JacCompiler.jac_file_formatter(file_path, auto_lint);
    }

    static def jac_str_formatter(
        source_str: str, file_path: str, auto_lint: bool = False
    ) -> JacProgram {
        import from jaclang.jac0core.compiler { JacCompiler }
        return JacCompiler.jac_str_formatter(source_str, file_path, auto_lint);
    }

    static def jac_file_linter(file_path: str) -> JacProgram {
        import from jaclang.jac0core.compiler { JacCompiler }
        return JacCompiler.jac_file_linter(file_path);
    }
}
