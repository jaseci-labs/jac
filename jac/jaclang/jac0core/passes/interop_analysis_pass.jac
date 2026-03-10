"""Interop Analysis Pass - identifies cross-boundary function calls.

Walks the module AST to detect calls between different codespace contexts
(server/Python, native/LLVM, client/JavaScript) and builds an InteropManifest.
"""
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.codeinfo { InteropBinding, InteropContext }
import from jaclang.jac0core.passes.uni_pass { UniPass }
"""Identify cross-boundary function calls between sv, na, and cl contexts.

    Walks the module AST to:
    1. Record each function's definition context (SERVER, NATIVE, CLIENT)
    2. Detect function calls that cross context boundaries
    3. Track imports from .na.jac modules for nativeânative linking
    4. Build an InteropManifest with bindings for each cross-boundary call
    """
class InteropAnalysisPass(UniPass) {
    """Initialize function definition tracking."""
    def before_pass(self: InteropAnalysisPass) -> None;

    """Determine the codespace context of a node."""
    def _get_context(self: InteropAnalysisPass, nd: uni.UniNode) -> InteropContext;

    """Extract a type name string from a type annotation expression."""
    def _extract_type_name(
        self: InteropAnalysisPass, expr: (uni.UniNode | None)
    ) -> str;

    """Check if a module name refers to a .na.jac file and return the path
suffix.

        Given a module name like 'na_math_utils', checks if
'na_math_utils.na.jac'
        exists relative to the current module. Returns the module path for
linking
        (e.g., 'na_math_utils.na') or None if not a native module.
        """
    def _resolve_native_module(
        self: InteropAnalysisPass, module_name: str
    ) -> (str | None);

    """Track imports from .na.jac modules."""
    def enter_import(self: InteropAnalysisPass, nd: uni.Import) -> None;

    """Record function definition and its context."""
    def enter_ability(self: InteropAnalysisPass, nd: uni.Ability) -> None;

    """Check if a function call crosses context boundaries."""
    def enter_func_call(self: InteropAnalysisPass, nd: uni.FuncCall) -> None;
}
