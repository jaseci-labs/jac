"""Interop Analysis Pass - identifies cross-boundary function calls.

Walks the module AST to detect calls between different codespace contexts
(server/Python, native/LLVM, client/JavaScript) and builds an InteropManifest.
"""

from __future__ import annotations

import jaclang.pycore.unitree as uni
from jaclang.pycore.codeinfo import InteropBinding, InteropContext
from jaclang.pycore.passes.uni_pass import UniPass


class InteropAnalysisPass(UniPass):
    """Identify cross-boundary function calls between sv, na, and cl contexts.

    Walks the module AST to:
    1. Record each function's definition context (SERVER, NATIVE, CLIENT)
    2. Detect function calls that cross context boundaries
    3. Build an InteropManifest with bindings for each cross-boundary call
    """

    def before_pass(self) -> None:
        """Initialize function definition tracking."""
        self._func_defs: dict[str, tuple[InteropContext, uni.Ability]] = {}

    def _get_context(self, node: uni.UniNode) -> InteropContext:
        """Determine the codespace context of a node."""
        if node.in_native_context():
            return InteropContext.NATIVE
        if node.in_client_context():
            return InteropContext.CLIENT
        return InteropContext.SERVER

    def _extract_type_name(self, expr: uni.UniNode | None) -> str:
        """Extract a type name string from a type annotation expression."""
        if expr is None:
            return "int"
        if isinstance(expr, uni.Name):
            return expr.value
        if isinstance(expr, uni.Token):
            return expr.value
        return "int"

    def enter_ability(self, node: uni.Ability) -> None:
        """Record function definition and its context."""
        if node.sym_name and isinstance(node.signature, uni.FuncSignature):
            ctx = self._get_context(node)
            self._func_defs[node.sym_name] = (ctx, node)

    def enter_func_call(self, node: uni.FuncCall) -> None:
        """Check if a function call crosses context boundaries."""
        func_name = None
        if isinstance(node.target, uni.Name):
            func_name = node.target.value
        elif isinstance(node.target, uni.NameAtom):
            func_name = node.target.sym_name

        if not func_name or func_name not in self._func_defs:
            return

        callee_ctx, callee_node = self._func_defs[func_name]
        caller_ctx = self._get_context(node)

        if caller_ctx == callee_ctx:
            return

        manifest = self.ir_in.gen.interop_manifest

        if func_name in manifest.bindings:
            manifest.bindings[func_name].callers.add(caller_ctx)
        else:
            sig = callee_node.signature
            assert isinstance(sig, uni.FuncSignature)

            ret_type = self._extract_type_name(sig.return_type)
            param_types: list[str] = []
            param_names: list[str] = []
            for p in sig.params:
                param_names.append(p.sym_name)
                if p.type_tag:
                    param_types.append(self._extract_type_name(p.type_tag.tag))
                else:
                    param_types.append("int")

            binding = InteropBinding(
                name=func_name,
                source_context=callee_ctx,
                callers={caller_ctx},
                ret_type=ret_type,
                param_types=param_types,
                param_names=param_names,
                ast_node=callee_node,
                route=[caller_ctx, callee_ctx],
            )
            manifest.bindings[func_name] = binding
