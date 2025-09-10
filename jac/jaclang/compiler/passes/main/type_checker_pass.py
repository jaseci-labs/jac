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

    # REVIEW: Making the evaluator a static (singleton) variable to make sure only one
    # instance is used across mulitple compilation units. This can also be attached to an
    # attribute of JacProgram, however the evaluator is a temproary object that we dont
    # want bound to the program for long term, Also the program is the one that will be
    # dumped in the compiled bundle.
    _EVALUATOR: TypeEvaluator | None = None

    def before_pass(self) -> None:
        """Initialize the checker pass."""
        self._load_builtins_stub_module()
        self._insert_builtin_symbols()

    @property
    def evaluator(self) -> TypeEvaluator:
        """Return the type evaluator."""
        if TypeCheckPass._EVALUATOR is None:
            assert TypeCheckPass._BUILTINS_MODULE is not None
            TypeCheckPass._EVALUATOR = TypeEvaluator(
                builtins_module=TypeCheckPass._BUILTINS_MODULE,
                program=self.prog,
            )
        return TypeCheckPass._EVALUATOR

    # --------------------------------------------------------------------------
    # Internal helper functions
    # --------------------------------------------------------------------------

    def _binding_builtins(self) -> bool:
        """Return true if we're binding the builtins stub file."""
        return self.ir_in == TypeCheckPass._BUILTINS_MODULE

    def _load_builtins_stub_module(self) -> None:
        """Return the builtins stub module.

        This will parse and cache the stub file and return the cached module on
        subsequent calls.
        """
        if self._binding_builtins() or TypeCheckPass._BUILTINS_MODULE is not None:
            return

        if not os.path.exists(TypeCheckPass._BUILTINS_STUB_FILE_PATH):
            raise FileNotFoundError(
                f"Builtins stub file not found at {TypeCheckPass._BUILTINS_STUB_FILE_PATH}"
            )

        file_content = read_file_with_encoding(TypeCheckPass._BUILTINS_STUB_FILE_PATH)
        uni_source = uni.Source(file_content, TypeCheckPass._BUILTINS_STUB_FILE_PATH)
        mod = PyastBuildPass(
            ir_in=uni.PythonModuleAst(
                py_ast.parse(file_content),
                orig_src=uni_source,
            ),
            prog=self.prog,
        ).ir_out
        SymTabBuildPass(ir_in=mod, prog=self.prog)
        TypeCheckPass._BUILTINS_MODULE = mod

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
        assert (
            TypeCheckPass._BUILTINS_MODULE is not None
        ), "Builtins module is not loaded"
        if self.ir_in.parent_scope is not None:
            self.log_info("Builtins module is already bound, skipping.")
            return
        # Review: If we ever assume a module cannot have a parent scope, this will
        # break that contract.
        self.ir_in.parent_scope = TypeCheckPass._BUILTINS_MODULE

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
