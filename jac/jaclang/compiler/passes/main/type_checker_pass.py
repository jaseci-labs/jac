"""
Type checker pass.

This will perform type checking on the Jac program and accumulate any type
errors found during the process in the pass's had_errors, had_warnings list.

Reference:
    Pyright: packages/pyright-internal/src/analyzer/checker.ts
    craizy_type_expr branch: type_checker_pass.py
"""

import ast as py_ast
import os
import threading

import jaclang.compiler.unitree as uni
from jaclang.compiler.passes import UniPass
from jaclang.compiler.type_system.type_evaluator import TypeEvaluator
from jaclang.runtimelib.utils import read_file_with_encoding

from .pyast_load_pass import PyastBuildPass
from .sym_tab_build_pass import SymTabBuildPass


class TypeCheckPass(UniPass):
    """Type checker pass for JacLang."""

    # NOTE: This is done in the binder pass of pyright, however I'm doing this
    # here, cause this will be the entry point of the type checker and we're not
    # relying on the binder pass at the moment and we can go back to binder pass
    # in the future if we needed it.
    _BUILTINS_STUB_FILE_PATH = os.path.join(
        os.path.dirname(__file__),
        "../../../vendor/typeshed/stdlib/builtins.pyi",
    )

    # Cache the builtins module once it parsed.
    _BUILTINS_MODULE: uni.Module | None = None
    _BUILTINS_LOCK = threading.Lock()
    
    @classmethod
    def _get_builtins_module(cls) -> uni.Module:
        """Get the builtins module using thread-safe lazy initialization."""
        # Fast path - already loaded
        if cls._BUILTINS_MODULE is not None:
            return cls._BUILTINS_MODULE
        
        # Slow path - need to load
        with cls._BUILTINS_LOCK:
            # Double-check pattern
            if cls._BUILTINS_MODULE is not None:
                return cls._BUILTINS_MODULE
            
            # Load the builtins module
            if not os.path.exists(cls._BUILTINS_STUB_FILE_PATH):
                raise FileNotFoundError(
                    f"Builtins stub file not found at {cls._BUILTINS_STUB_FILE_PATH}"
                )

            # Use lazy import to avoid circular dependency
            from jaclang.compiler.program import JacProgram
            temp_program = JacProgram()
            
            file_content = read_file_with_encoding(cls._BUILTINS_STUB_FILE_PATH)
            uni_source = uni.Source(file_content, cls._BUILTINS_STUB_FILE_PATH)
            mod = PyastBuildPass(
                ir_in=uni.PythonModuleAst(
                    py_ast.parse(file_content),
                    orig_src=uni_source,
                ),
                prog=temp_program,
            ).ir_out
            SymTabBuildPass(ir_in=mod, prog=temp_program)
            
            # Cache and return
            cls._BUILTINS_MODULE = mod
            return mod

    def before_pass(self) -> None:
        """Initialize the checker pass."""
        self._load_builtins_stub_module()
        self._insert_builtin_symbols()

        # Use the thread-safe getter
        builtins_module = TypeCheckPass._get_builtins_module()
        self.evaluator = TypeEvaluator(
            builtins_module=builtins_module,
            program=self.prog,
        )

    # --------------------------------------------------------------------------
    # Internal helper functions
    # --------------------------------------------------------------------------

    def _binding_builtins(self) -> bool:
        """Return true if we're binding the builtins stub file."""
        return self.ir_in == TypeCheckPass._get_builtins_module()

    def _load_builtins_stub_module(self) -> None:
        """Load the builtins stub module - now just delegates to the thread-safe getter."""
        if self._binding_builtins():
            return
        # Just ensure it's loaded - the getter handles thread safety
        TypeCheckPass._get_builtins_module()

    def _insert_builtin_symbols(self) -> None:
        if self._binding_builtins():
            return

        # TODO: Insert these symbols.
        # Reference: pyright Binder.bindModule()
        #
        # List taken from https://docs.python.org/3/reference/import.html#__name__
        # '__name__', '__loader__', '__package__', '__spec__', '__path__',
        # '__file__', '__cached__', '__dict__', '__annotations__',
        # '__builtins__', '__doc__',
        builtins_module = TypeCheckPass._get_builtins_module()
        if self.ir_in.parent_scope is not None:
            self.log_info("Builtins module is already bound, skipping.")
            return
        # Review: If we ever assume a module cannot have a parent scope, this will
        # break that contract.
        self.ir_in.parent_scope = builtins_module

    # --------------------------------------------------------------------------
    # Ast walker hooks
    # --------------------------------------------------------------------------

    def exit_assignment(self, node: uni.Assignment) -> None:
        """Pyright: Checker.visitAssignment(node: AssignmentNode): boolean."""
        # TODO: In pyright this logic is present at evaluateTypesForAssignmentStatement
        # and we're calling getTypeForStatement from here, This can be moved into the
        # other place or we can keep it here.
        #
        # Grep this in pyright TypeEvaluator.ts:
        # `} else if (node.d.leftExpr.nodeType === ParseNodeType.Name) {`
        #
        if len(node.target) == 1 and (node.value is not None):  # Simple assignment.
            left_type = self.evaluator.get_type_of_expression(node.target[0])
            right_type = self.evaluator.get_type_of_expression(node.value)
            if not self.evaluator.assign_type(right_type, left_type):
                self.log_error(f"Cannot assign {right_type} to {left_type}")
        else:
            pass  # TODO: handle

    def exit_atom_trailer(self, node: uni.AtomTrailer) -> None:
        """Handle the atom trailer node."""
        self.evaluator.get_type_of_expression(node)
