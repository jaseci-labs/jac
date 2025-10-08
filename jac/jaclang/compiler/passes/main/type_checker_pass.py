"""
Type checker pass.

This will perform type checking on the Jac program and accumulate any type
errors found during the process in the pass's had_errors, had_warnings list.

Reference:
    Pyright: packages/pyright-internal/src/analyzer/checker.ts
    craizy_type_expr branch: type_checker_pass.py
"""

import jaclang.compiler.unitree as uni
from jaclang.compiler.passes import UniPass
from jaclang.compiler.type_system import types as jtypes


class TypeCheckPass(UniPass):
    """Type checker pass for JacLang."""

    def before_pass(self) -> None:
        """Initialize the checker pass."""
        self.evaluator = self.prog.get_type_evaluator()
        self.evaluator.diagnostic_callback = self._add_diagnostic
        self._insert_builtin_symbols()

    def _add_diagnostic(self, node: uni.UniNode, message: str, warning: bool) -> None:
        """Add a diagnostic message to the pass."""
        if warning:
            self.log_warning(message, node)
        else:
            self.log_error(message, node)

    # --------------------------------------------------------------------------
    # Internal helper functions
    # --------------------------------------------------------------------------

    def _insert_builtin_symbols(self) -> None:
        # Don't insert builtin symbols into the builtin module itself.
        if self.ir_in == self.evaluator.builtins_module:
            return

        # TODO: Insert these symbols.
        # Reference: pyright Binder.bindModule()
        #
        # List taken from https://docs.python.org/3/reference/import.html#__name__
        # '__name__', '__loader__', '__package__', '__spec__', '__path__',
        # '__file__', '__cached__', '__dict__', '__annotations__',
        # '__builtins__', '__doc__',
        if self.ir_in.parent_scope is not None:
            self.log_info("Builtins module is already bound, skipping.")
            return
        # Review: If we ever assume a module cannot have a parent scope, this will
        # break that contract.
        self.ir_in.parent_scope = self.evaluator.builtins_module

    # --------------------------------------------------------------------------
    # Ast walker hooks
    # --------------------------------------------------------------------------

    def enter_ability(self, node: uni.Ability) -> None:
        """Enter an ability node."""
        # If the node has @staticmethod decorator, mark it as static method.
        # this is needed since ast raised from python does not have this info.
        for decor in node.decorators or []:
            ty = self.evaluator.get_type_of_expression(decor)
            if isinstance(ty, jtypes.ClassType) and ty.is_builtin("staticmethod"):
                node.is_static = True
                break

    def exit_import(self, node: uni.Import) -> None:
        """Exit an import node."""
        # import from math {sqrt, sin as s}
        if node.from_loc:
            self.evaluator.get_type_of_module(node.from_loc)
            for item in node.items:
                if isinstance(item, uni.ModuleItem):
                    self.evaluator.get_type_of_module_item(item)
        else:
            # import math as m, os, sys;
            for item in node.items:
                if isinstance(item, uni.ModulePath):
                    self.evaluator.get_type_of_module(item)

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

    def exit_func_call(self, node: uni.FuncCall) -> None:
        """Handle the function call node."""
        # TODO:
        # 1. Function Existence & Callable Validation
        # 2. Argument Matching(count, types, names)
        self.evaluator.get_type_of_expression(node)
