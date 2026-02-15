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

"""JacProgram holds the state of a compiled Jac program.

    This class contains:
    - mod: The ProgramModule containing all compiled modules in mod.hub
    - errors_had: List of compilation errors
    - warnings_had: List of compilation warnings
    - type_evaluator: Optional type evaluator for type checking
    - py_raise_map: Mapping for Python exception translation

    Compilation is performed by JacCompiler, which takes a JacProgram
    as a target to store compiled modules and track errors.
    """
class JacProgram {
    """Initialize the JacProgram object.

        Args:
            main_mod: Optional main module to initialize with.
            bytecode_cache: Optional custom bytecode cache. If None, uses
default.
        """
    def init(
        self: JacProgram,
        main_mod: (uni.ProgramModule | None) = None,
        bytecode_cache: (BytecodeCache | None) = None
    ) -> None {
        self.mod: uni.ProgramModule = main_mod or uni.ProgramModule();
        self.py_raise_map: dict[(str, str)] = {};
        self.mtir_map: dict[(str, Info)] = {};
        self.errors_had: list[Alert] = [];
        self.warnings_had: list[Alert] = [];
        self.type_evaluator: (TypeEvaluator | None) = None;
        self._bytecode_cache: BytecodeCache = bytecode_cache or get_bytecode_cache();
        self._compiler: (JacCompiler | None) = None;
        self._compile_options: CompileOptions = CompileOptions();
    }

    """Get a JacCompiler instance configured with this program's cache."""
    def _get_compiler(self: JacProgram) -> JacCompiler {
        if self._compiler {
            return self._compiler;
        }
        import from jaclang.jac0core.compiler { JacCompiler }
        self._compiler = JacCompiler(bytecode_cache=self._bytecode_cache);
        return self._compiler;
    }

    """Return the type evaluator, creating one if needed."""
    def get_type_evaluator(self: JacProgram) -> TypeEvaluator {
        import from jaclang.compiler.type_system.type_evaluator { TypeEvaluator }
        if not self.type_evaluator {
            self.type_evaluator = TypeEvaluator(program=self);
        }
        return self.type_evaluator;
    }

    """Clear all type information from the program.

        This method resets the type evaluator and clears cached type information
        from all AST nodes. This is useful for test isolation when running
multiple
        tests in the same process, as type information attached to AST nodes can
        persist in sys.modules and pollute subsequent tests.

        Args:
            clear_hub: If True, also clear all modules from mod.hub. Use with
                       caution as this removes all compiled modules.
        """
    def clear_type_system(self: JacProgram, clear_hub: bool = False) -> None {
        self.type_evaluator = None;
        if clear_hub {
            self.mod.hub.clear();
        } else {
            for mod in self.mod.hub.values() {
                for nd in mod.get_all_sub_nodes(uni.Expr, brute_force=True) {
                    nd.type = None;
                }
            }
        }
    }

    """Get the bytecode for a specific module.

        Args:
            full_target: The full path to the module file.
            minimal: If True, use minimal compilation (no JS/type analysis).
                     This avoids circular imports for bootstrap-critical
modules.
        """
    def get_bytecode(
        self: JacProgram, full_target: str, minimal: bool = False
    ) -> (types.CodeType | None) {
        return self._get_compiler().get_bytecode(full_target, self, minimal);
    }

    """Parse source string into an AST module."""
    def parse_str(
        self: JacProgram,
        source_str: str,
        file_path: str,
        cancel_token: (Event | None) = None
    ) -> uni.Module {
        return self._get_compiler().parse_str(
            source_str, file_path, self, cancel_token
        );
    }

    """Compile a Jac file into a module AST.

        Args:
            file_path: Path to the Jac file to compile.
            use_str: Optional source string to use instead of reading from file.
            no_cgen: If True, skip code generation entirely.
            type_check: If True, run type checking pass.
            symtab_ir_only: If True, only build symbol table (skip semantic
analysis).
            minimal: If True, use minimal compilation mode (bytecode only, no
JS).
                     This avoids circular imports for bootstrap-critical
modules.
            cancel_token: Optional event to cancel compilation.
            options: CompileOptions instance. If provided, overrides individual
params.
        """
    def compile(
        self: JacProgram,
        file_path: str,
        use_str: (str | None) = None,
        no_cgen: bool = False,
        type_check: bool = False,
        symtab_ir_only: bool = False,
        minimal: bool = False,
        cancel_token: (Event | None) = None,
        options: (CompileOptions | None) = None
    ) -> uni.Module {
        if (options is None) {
            options = CompileOptions(
                minimal=minimal,
                type_check=type_check,
                symtab_ir_only=symtab_ir_only,
                no_cgen=no_cgen,
                cancel_token=cancel_token
            );
        }
        return self._get_compiler().compile(
            file_path=file_path, target_program=self, use_str=use_str, options=options
        );
    }

    """Build a Jac file with import dependency resolution."""
    def build(
        self: JacProgram,
        file_path: str,
        use_str: (str | None) = None,
        type_check: bool = False
    ) -> uni.Module {
        return self._get_compiler().build(
            file_path, self, use_str, type_check=type_check
        );
    }

    """Run a schedule of passes on a module."""
    def run_schedule(
        self: JacProgram,
        mod: uni.Module,
        passes: list[type[Transform[(uni.Module, uni.Module)]]],
        cancel_token: (Event | None) = None
    ) -> None {
        self._get_compiler().run_schedule(mod, self, passes, cancel_token);
    }

    """Format a Jac file and return the JacProgram.

        Args:
            file_path: Path to the Jac file to format.
            auto_lint: If True, apply auto-linting corrections before
formatting.
        """
    static def jac_file_formatter(
        file_path: str, auto_lint: bool = False
    ) -> JacProgram {
        import from jaclang.jac0core.compiler { JacCompiler }
        return JacCompiler.jac_file_formatter(file_path, auto_lint);
    }

    """Format a Jac string and return the JacProgram.

        Args:
            source_str: The Jac source code string to format.
            file_path: Path to use for error messages.
            auto_lint: If True, apply auto-linting corrections before
formatting.
        """
    static def jac_str_formatter(
        source_str: str, file_path: str, auto_lint: bool = False
    ) -> JacProgram {
        import from jaclang.jac0core.compiler { JacCompiler }
        return JacCompiler.jac_str_formatter(source_str, file_path, auto_lint);
    }

    """Lint a Jac file (report only, no formatting or output generation).

        Args:
            file_path: Path to the Jac file to lint.
        """
    static def jac_file_linter(file_path: str) -> JacProgram {
        import from jaclang.jac0core.compiler { JacCompiler }
        return JacCompiler.jac_file_linter(file_path);
    }
}
