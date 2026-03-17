"""Jac Program module."""
import types;
import from threading { Event }
import from typing { TYPE_CHECKING }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.mtp { Info }
import from jaclang.jac0core.passes { Alert }

with entry {
    if TYPE_CHECKING {
        import from jaclang.compiler.type_system.type_evaluator { TypeEvaluator }
        import from jaclang.jac0core.compiler { JacCompiler }
        import from jaclang.jac0core.passes { Transform }
    }
}

"""Holds the state of a compiled Jac program."""
obj JacProgram {
    has mod: uni.ProgramModule by postinit,
        py_raise_map: dict[(str, str)] by postinit,
        mtir_map: dict[(str, Info)] by postinit,
        errors_had: list[Alert] by postinit,
        warnings_had: list[Alert] by postinit,
        type_evaluator: (TypeEvaluator | None) = None,
        _compiler: (JacCompiler | None) = None,
        _compile_options: CompileOptions by postinit,
        _native_cache: dict by postinit;

    def postinit -> None;
    def _get_compiler -> JacCompiler;
    def get_type_evaluator -> TypeEvaluator;
    def clear_type_system(clear_hub: bool = False) -> None;
    def get_bytecode(full_target: str) -> (types.CodeType | None);
    def parse_str(
        source_str: str, file_path: str, cancel_token: (Event | None) = None
    ) -> uni.Module;

    def compile(
        file_path: str,
        use_str: (str | None) = None,
        no_cgen: bool = False,
        type_check: bool = False,
        symtab_ir_only: bool = False,
        cancel_token: (Event | None) = None,
        options: (CompileOptions | None) = None
    ) -> uni.Module;

    def build(
        file_path: str, use_str: (str | None) = None, type_check: bool = False
    ) -> uni.Module;

    def run_schedule(
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
