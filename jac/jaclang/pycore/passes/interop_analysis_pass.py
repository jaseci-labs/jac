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
    3. Track imports from .na.jac modules for native↔native linking
    4. Build an InteropManifest with bindings for each cross-boundary call
    """

    def before_pass(self) -> None:
        """Initialize function definition tracking."""
        self._func_defs: dict[str, tuple[InteropContext, uni.Ability]] = {}
        # Track imported native functions: func_name -> (source_module_path, context)
        self._imported_native_funcs: dict[str, tuple[str, InteropContext]] = {}

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

    def _resolve_native_module(self, module_name: str) -> str | None:
        """Check if a module name refers to a .na.jac file and return the path suffix.

        Given a module name like 'na_math_utils', checks if 'na_math_utils.na.jac'
        exists relative to the current module. Returns the module path for linking
        (e.g., 'na_math_utils.na') or None if not a native module.
        """
        import os

        # Get the base directory of the current module
        base_dir = "."
        if self.ir_in and self.ir_in.loc:
            base_dir = os.path.dirname(self.ir_in.loc.mod_path)

        # Check if {module_name}.na.jac exists
        na_jac_path = os.path.join(base_dir, f"{module_name}.na.jac")
        if os.path.exists(na_jac_path):
            return f"{module_name}.na"

        return None

    def enter_import(self, node: uni.Import) -> None:
        """Track imports from .na.jac modules."""
        # Get the context where this import appears
        import_context = self._get_context(node)

        # Check for "import from module { names }" syntax
        # The module path is in from_loc, imported names are in items
        if node.from_loc and isinstance(node.from_loc, uni.ModulePath):
            # Get the module name from from_loc
            module_name = getattr(node.from_loc, "dot_path_str", None)
            if (
                not module_name
                and hasattr(node.from_loc, "path")
                and node.from_loc.path
            ):
                module_name = ".".join(
                    p.value if hasattr(p, "value") else str(p)
                    for p in node.from_loc.path
                )

            if module_name:
                # Check if this is a native module (has .na.jac file)
                native_path = self._resolve_native_module(module_name)
                # Track all imported names from this native module
                if native_path and node.items:
                    for item in node.items:
                        if isinstance(item, uni.ModuleItem):
                            func_name = (
                                item.name.value
                                if hasattr(item.name, "value")
                                else str(item.name)
                            )
                            self._imported_native_funcs[func_name] = (
                                native_path,
                                import_context,
                            )

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

        if not func_name:
            return

        caller_ctx = self._get_context(node)
        manifest = self.ir_in.gen.interop_manifest

        # Check if this is a call to an imported native function
        if func_name in self._imported_native_funcs:
            source_module, import_ctx = self._imported_native_funcs[func_name]

            # Only create binding if caller is in native context (na↔na)
            if caller_ctx == InteropContext.NATIVE:
                if func_name not in manifest.bindings:
                    binding = InteropBinding(
                        name=func_name,
                        source_context=InteropContext.NATIVE,
                        callers={InteropContext.NATIVE},
                        ret_type="int",  # Default, will be refined later
                        param_types=[],
                        param_names=[],
                        ast_node=None,
                        route=[InteropContext.NATIVE, InteropContext.NATIVE],
                        source_module=source_module,
                    )
                    manifest.bindings[func_name] = binding
                else:
                    manifest.bindings[func_name].callers.add(InteropContext.NATIVE)
            return

        # Check if callee is defined in this module
        if func_name not in self._func_defs:
            return

        callee_ctx, callee_node = self._func_defs[func_name]

        if caller_ctx == callee_ctx:
            return

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
