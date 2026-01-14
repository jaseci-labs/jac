"""Jac Program module.

This module provides the JacProgram class which holds the state of a compiled
Jac program. The actual compilation is performed by JacCompiler.
"""

from __future__ import annotations

import types
from threading import Event
from typing import TYPE_CHECKING

import jaclang.pycore.unitree as uni
from jaclang.pycore.bccache import BytecodeCache, get_bytecode_cache
from jaclang.pycore.passes import Alert

if TYPE_CHECKING:
    from jaclang.compiler.type_system.type_evaluator import TypeEvaluator
    from jaclang.pycore.compiler import JacCompiler
    from jaclang.pycore.passes import Transform


class JacProgram:
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

    def __init__(
        self,
        main_mod: uni.ProgramModule | None = None,
        bytecode_cache: BytecodeCache | None = None,
    ) -> None:
        """Initialize the JacProgram object.

        Args:
            main_mod: Optional main module to initialize with.
            bytecode_cache: Optional custom bytecode cache. If None, uses default.
        """
        self.mod: uni.ProgramModule = main_mod if main_mod else uni.ProgramModule()
        self.py_raise_map: dict[str, str] = {}
        self.errors_had: list[Alert] = []
        self.warnings_had: list[Alert] = []
        self.type_evaluator: TypeEvaluator | None = None
        self._bytecode_cache: BytecodeCache = bytecode_cache or get_bytecode_cache()

    def _get_compiler(self) -> JacCompiler:
        """Get a JacCompiler instance configured with this program's cache."""
        from jaclang.pycore.compiler import JacCompiler

        return JacCompiler(bytecode_cache=self._bytecode_cache)

    def get_type_evaluator(self) -> TypeEvaluator:
        """Return the type evaluator, creating one if needed."""
        from jaclang.compiler.type_system.type_evaluator import TypeEvaluator

        if not self.type_evaluator:
            self.type_evaluator = TypeEvaluator(program=self)
        return self.type_evaluator

    def clear_type_system(self, clear_hub: bool = False) -> None:
        """Clear all type information from the program.

        This method resets the type evaluator and clears cached type information
        from all AST nodes. This is useful for test isolation when running multiple
        tests in the same process, as type information attached to AST nodes can
        persist in sys.modules and pollute subsequent tests.

        Args:
            clear_hub: If True, also clear all modules from mod.hub. Use with
                       caution as this removes all compiled modules.
        """
        # Clear the type evaluator (will be recreated lazily if needed)
        self.type_evaluator = None

        # Optionally clear the entire module hub (skip node traversal if clearing hub)
        if clear_hub:
            self.mod.hub.clear()
        else:
            # Clear .type attributes from all Expr nodes in all modules
            for mod in self.mod.hub.values():
                for node in mod.get_all_sub_nodes(uni.Expr, brute_force=True):
                    node.type = None

    def get_bytecode(
        self, full_target: str, minimal: bool = False
    ) -> types.CodeType | None:
        """Get the bytecode for a specific module.

        Args:
            full_target: The full path to the module file.
            minimal: If True, use minimal compilation (no JS/type analysis).
                     This avoids circular imports for bootstrap-critical modules.
        """
        return self._get_compiler().get_bytecode(full_target, self, minimal)

    def parse_str(
        self, source_str: str, file_path: str, cancel_token: Event | None = None
    ) -> uni.Module:
        """Parse source string into an AST module."""
        return self._get_compiler().parse_str(source_str, file_path, self, cancel_token)

    def compile(
        self,
        file_path: str,
        use_str: str | None = None,
        no_cgen: bool = False,
        type_check: bool = False,
        symtab_ir_only: bool = False,
        minimal: bool = False,
        cancel_token: Event | None = None,
    ) -> uni.Module:
        """Compile a Jac file into a module AST.

        Args:
            file_path: Path to the Jac file to compile.
            use_str: Optional source string to use instead of reading from file.
            no_cgen: If True, skip code generation entirely.
            type_check: If True, run type checking pass.
            symtab_ir_only: If True, only build symbol table (skip semantic analysis).
            minimal: If True, use minimal compilation mode (bytecode only, no JS).
                     This avoids circular imports for bootstrap-critical modules.
            cancel_token: Optional event to cancel compilation.
        """
        return self._get_compiler().compile(
            file_path=file_path,
            target_program=self,
            use_str=use_str,
            no_cgen=no_cgen,
            type_check=type_check,
            symtab_ir_only=symtab_ir_only,
            minimal=minimal,
            cancel_token=cancel_token,
        )

    def build(
        self, file_path: str, use_str: str | None = None, type_check: bool = False
    ) -> uni.Module:
        """Build a Jac file with import dependency resolution."""
        return self._get_compiler().build(
            file_path, self, use_str, type_check=type_check
        )

    def run_schedule(
        self,
        mod: uni.Module,
        passes: list[type[Transform[uni.Module, uni.Module]]],
        cancel_token: Event | None = None,
    ) -> None:
        """Run a schedule of passes on a module."""
        self._get_compiler().run_schedule(mod, self, passes, cancel_token)

    @staticmethod
    def jac_file_formatter(file_path: str, auto_lint: bool = False) -> JacProgram:
        """Format a Jac file and return the JacProgram.

        Args:
            file_path: Path to the Jac file to format.
            auto_lint: If True, apply auto-linting corrections before formatting.
        """
        from jaclang.pycore.compiler import JacCompiler

        return JacCompiler.jac_file_formatter(file_path, auto_lint)

    @staticmethod
    def jac_str_formatter(
        source_str: str, file_path: str, auto_lint: bool = False
    ) -> JacProgram:
        """Format a Jac string and return the JacProgram.

        Args:
            source_str: The Jac source code string to format.
            file_path: Path to use for error messages.
            auto_lint: If True, apply auto-linting corrections before formatting.
        """
        from jaclang.pycore.compiler import JacCompiler

        return JacCompiler.jac_str_formatter(source_str, file_path, auto_lint)
