"""LLVM compatibility analysis pass.

This pass analyzes Jac functions to determine if they can be compiled to LLVM IR
for JIT compilation. Functions marked as compatible will have LLVM IR generated
alongside Python bytecode for hybrid execution.
"""

from __future__ import annotations

from threading import Event
from typing import TYPE_CHECKING

import jaclang.compiler.unitree as uni
from jaclang.compiler.passes import UniPass

if TYPE_CHECKING:
    from jaclang.compiler.program import JacProgram


class LlvmCompatibilityPass(UniPass):
    """Analyzes functions for LLVM compatibility.

    This pass walks the AST and marks functions that can be compiled to LLVM IR.
    Compatible functions will have `node.gen.llvm_compatible = True` set.

    Compatibility Requirements:
    - Must be a plain `def` function (not async, not method)
    - All parameters must have type annotations
    - Return type must be annotated
    - Function body must only use supported constructs

    Unsupported Constructs (currently):
    - Control flow (if/else, while, for) - coming soon
    - Function calls (except builtins) - coming soon
    - String operations
    - List/dict/set operations
    - Try/except blocks
    - With statements
    - Yield/generators
    - Class definitions
    - Import statements
    """

    def __init__(
        self, ir_in: uni.Module, prog: JacProgram, cancel_token: Event | None = None
    ) -> None:
        """Initialize the compatibility analysis pass."""
        super().__init__(ir_in, prog, cancel_token=cancel_token)

    def before_pass(self) -> None:
        """Initialize counters before pass execution."""
        self.compatible_count = 0
        self.incompatible_count = 0
        self.incompatible_reasons: dict[str, list[str]] = {}

    def enter_ability(self, node: uni.Ability) -> None:
        """Analyze a function for LLVM compatibility."""
        # Default to not compatible
        node.gen.llvm_compatible = False

        # Only analyze plain def functions
        if not node.is_def:
            self._mark_incompatible(node, "not a plain 'def' function")
            return

        if node.is_async:
            self._mark_incompatible(node, "async functions not supported")
            return

        if node.is_method:
            self._mark_incompatible(node, "methods not supported yet")
            return

        # Check function signature
        if not isinstance(node.signature, uni.FuncSignature):
            self._mark_incompatible(node, "missing function signature")
            return

        # Check parameter type annotations
        params = node.signature.get_parameters()
        for param in params:
            if param.is_vararg or param.is_kwargs:
                self._mark_incompatible(
                    node, f"variadic parameters not supported: {param.name.value}"
                )
                return

            if not param.type_tag:
                self._mark_incompatible(
                    node, f"parameter '{param.name.value}' missing type annotation"
                )
                return

        # Check return type annotation
        if not node.signature.return_type:
            self._mark_incompatible(node, "missing return type annotation")
            return

        # Check function body
        if not isinstance(node.body, list):
            self._mark_incompatible(node, "function body must be a code block")
            return

        # Analyze body for unsupported constructs
        unsupported = self._find_unsupported_nodes(node.body)
        if unsupported:
            for reason in unsupported:
                self._mark_incompatible(node, reason)
            return

        # Function is compatible!
        node.gen.llvm_compatible = True
        self.compatible_count += 1

        if self.prog.type_evaluator and hasattr(self.prog, "settings"):
            from jaclang.settings import settings

            if settings.jit_debug:
                func_name = node.py_resolve_name()
                print(f"[JIT] ✓ {func_name}: LLVM-compatible")

    def _mark_incompatible(self, node: uni.Ability, reason: str) -> None:
        """Mark a function as incompatible and record the reason."""
        node.gen.llvm_compatible = False
        self.incompatible_count += 1

        func_name = node.py_resolve_name()
        if func_name not in self.incompatible_reasons:
            self.incompatible_reasons[func_name] = []
        self.incompatible_reasons[func_name].append(reason)

        if self.prog.type_evaluator and hasattr(self.prog, "settings"):
            from jaclang.settings import settings

            if settings.jit_debug:
                print(f"[JIT] ✗ {func_name}: {reason}")

    def _find_unsupported_nodes(self, body: list[uni.CodeBlockStmt]) -> list[str]:
        """Find unsupported constructs in the function body.

        Returns:
            List of reasons why the body is not compatible.
        """
        unsupported = []

        for stmt in body:
            # Check for control flow (not yet supported)
            if isinstance(stmt, uni.IfStmt):
                unsupported.append("if statements not yet supported")
                continue

            if isinstance(stmt, (uni.WhileStmt, uni.IterForStmt, uni.InForStmt)):
                unsupported.append("loops not yet supported")
                continue

            # Check for try/except
            if isinstance(stmt, uni.TryStmt):
                unsupported.append("try/except not supported")
                continue

            # Check for with statements
            if isinstance(stmt, uni.WithStmt):
                unsupported.append("with statements not supported")
                continue

            # Check for yield/async
            if isinstance(stmt, (uni.YieldExpr, uni.AwaitExpr)):
                unsupported.append("generators/async not supported")
                continue

            # Check expressions in the statement
            expr_unsupported = self._check_expression_support(stmt)
            if expr_unsupported:
                unsupported.extend(expr_unsupported)

        return unsupported

    def _check_expression_support(self, node: uni.UniNode) -> list[str]:
        """Recursively check if expressions are supported.

        Returns:
            List of unsupported expression types found.
        """
        unsupported = []

        # Check for function calls (not yet supported)
        if isinstance(node, uni.FuncCall):
            # Allow some built-in operations that map to LLVM
            # For now, disallow all function calls
            unsupported.append("function calls not yet supported")
            return unsupported

        # Check for string operations
        if isinstance(node, (uni.String, uni.FString)):
            unsupported.append("string operations not supported")
            return unsupported

        # Check for collection literals
        if isinstance(node, (uni.ListVal, uni.DictVal, uni.SetVal, uni.TupleVal)):
            # TupleVal with single element is OK (parentheses)
            if isinstance(node, uni.TupleVal) and len(node.values) == 1:
                return self._check_expression_support(node.values[0])
            unsupported.append("collection types not supported")
            return unsupported

        # Check for list comprehensions, dict comprehensions, etc.
        if isinstance(node, (uni.ListCompr, uni.DictCompr, uni.SetCompr)):
            unsupported.append("comprehensions not supported")
            return unsupported

        # Check for lambda
        if isinstance(node, uni.LambdaExpr):
            unsupported.append("lambda expressions not supported")
            return unsupported

        # For now, keep recursion shallow to avoid deep checks
        # The main unsupported constructs are caught above
        return unsupported

    def after_pass(self) -> None:
        """Report compatibility analysis results."""
        from jaclang.settings import settings

        if settings.jit_debug and hasattr(self, "compatible_count"):
            total = self.compatible_count + self.incompatible_count
            if total > 0:
                print("\n[JIT] Compatibility Analysis:")
                print(f"[JIT]   ✓ Compatible:   {self.compatible_count}")
                print(f"[JIT]   ✗ Incompatible: {self.incompatible_count}")
                print(
                    f"[JIT]   Coverage: {self.compatible_count}/{total} ({100 * self.compatible_count // total}%)"
                )

                if (
                    hasattr(self, "incompatible_reasons")
                    and self.incompatible_reasons
                    and settings.jit_debug
                ):
                    print("\n[JIT] Incompatibility reasons:")
                    for func_name, reasons in self.incompatible_reasons.items():
                        print(f"[JIT]   {func_name}:")
                        for reason in set(reasons):  # Deduplicate
                            print(f"[JIT]     - {reason}")
