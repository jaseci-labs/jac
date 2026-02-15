"""Jac Program module.

This module provides the JacProgram class which holds the state of a compiled
Jac program. The actual compilation is performed by JacCompiler.
"""
import types;
import from threading { Event }
import from typing { TYPE_CHECKING }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.bccache { BytecodeCache, get_bytecode_cache }
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

"""JacProgram holds the state of a compiled Jac program."""
class JacProgram {
    """Initialize the JacProgram object."""
    def init(
        self: JacProgram,
        main_mod: (uni.ProgramModule | None) = None,
        bytecode_cache: (BytecodeCache | None) = None
    ) -> None;

    """Get a JacCompiler instance configured with this program's cache."""
    def _get_compiler(self: JacProgram) -> JacCompiler;

    """Return the type evaluator, creating one if needed."""
    def get_type_evaluator(self: JacProgram) -> TypeEvaluator;

    """Clear all type information from the program."""
    def clear_type_system(self: JacProgram, clear_hub: bool = False) -> None;

    """Get the bytecode for a specific module."""
    def get_bytecode(self: JacProgram, full_target: str) -> (types.CodeType | None);

    """Parse source string into an AST module."""
    def parse_str(
        self: JacProgram,
        source_str: str,
        file_path: str,
        cancel_token: (Event | None) = None
    ) -> uni.Module;

    """Compile a Jac file into a module AST."""
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

    """Build a Jac file with import dependency resolution."""
    def build(
        self: JacProgram,
        file_path: str,
        use_str: (str | None) = None,
        type_check: bool = False
    ) -> uni.Module;

    """Run a schedule of passes on a module."""
    def run_schedule(
        self: JacProgram,
        mod: uni.Module,
        passes: list[type[Transform[(uni.Module, uni.Module)]]],
        cancel_token: (Event | None) = None
    ) -> None;

    """Format a Jac file and return the JacProgram."""
    static def jac_file_formatter(
        file_path: str, auto_lint: bool = False
    ) -> JacProgram {
        import from jaclang.jac0core.compiler { JacCompiler }
        return JacCompiler.jac_file_formatter(file_path, auto_lint);
    }

    """Format a Jac string and return the JacProgram."""
    static def jac_str_formatter(
        source_str: str, file_path: str, auto_lint: bool = False
    ) -> JacProgram {
        import from jaclang.jac0core.compiler { JacCompiler }
        return JacCompiler.jac_str_formatter(source_str, file_path, auto_lint);
    }

    """Lint a Jac file (report only, no formatting or output generation)."""
    static def jac_file_linter(file_path: str) -> JacProgram {
        import from jaclang.jac0core.compiler { JacCompiler }
        return JacCompiler.jac_file_linter(file_path);
    }
}
