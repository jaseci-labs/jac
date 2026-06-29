import types;
import from threading { Event }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.mtp { Info }
import from jaclang.jac0core.passes { Alert }
import type from jaclang.compiler.type_system.type_evaluator { TypeEvaluator }
import type from jaclang.jac0core.compiler { JacCompiler }
import type from jaclang.jac0core.passes { Transform }

class JacProgram {
    def init(self: JacProgram, main_mod: (uni.ProgramModule | None) = None) -> None;
    def _get_compiler(self: JacProgram) -> JacCompiler;
    def get_type_evaluator(self: JacProgram) -> TypeEvaluator;
    def clear_type_system(self: JacProgram, clear_hub: bool = False) -> None;
    def hub_cache_stamp(self: JacProgram, resolved_path: str) -> None;
    def is_hub_entry_fresh(self: JacProgram, resolved_path: str) -> bool;
    def record_dependency(
        self: JacProgram, importer_path: str, target_path: str
    ) -> None;

    def record_module_dependencies(self: JacProgram, mod: uni.Module) -> None;
    def transitive_dependents(self: JacProgram, target_path: str) -> set[str];
    def invalidate_module(self: JacProgram, resolved_path: str) -> None;
    def _search_hubs(self: JacProgram) -> list[dict];
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
        passes: list[type[Transform[uni.Module, uni.Module]]],
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
