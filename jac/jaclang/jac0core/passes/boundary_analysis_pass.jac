"""Interop Analysis Pass - identifies cross-boundary function calls.

Walks the module AST to detect calls between different codespace contexts
(server/Python, native/LLVM, client/JavaScript) and builds an InteropManifest.
"""
import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { SymbolType, Tokens as Tok }
import from jaclang.jac0core.codeinfo {
    BoundaryTypeInfo,
    InteropBinding,
    InteropContext
}
import from jaclang.jac0core.passes.uni_pass { UniPass }
"""Identify cross-boundary function calls between sv, na, and cl contexts.

    Walks the module AST to:
    1. Record each function's definition context (SERVER, NATIVE, CLIENT)
    2. Detect function calls that cross context boundaries
    3. Track imports from .na.jac modules for nativeânative linking
    4. Build an InteropManifest with bindings for each cross-boundary call
    """
class BoundaryAnalysisPass(UniPass) {
    """Initialize function definition tracking."""
    def before_pass(self: BoundaryAnalysisPass) -> None;

    """Determine the codespace context of a node."""
    def _get_context(self: BoundaryAnalysisPass, nd: uni.UniNode) -> InteropContext;

    """Extract a type name string from a type annotation expression."""
    def _extract_type_name(
        self: BoundaryAnalysisPass, expr: (uni.UniNode | None)
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
        self: BoundaryAnalysisPass, module_name: str
    ) -> (str | None);

    """Track imports from .na.jac modules and sv-to-sv microservice imports."""
    def enter_import(self: BoundaryAnalysisPass, nd: uni.Import) -> None;

    """Register a flat `import json;` of a bundled / project-local na_stdlib
    module: create a NATIVE binding per public top-level symbol so the link
    pass pulls the module in (issue #6964)."""
    def _register_flat_native_import(
        self: BoundaryAnalysisPass, nd: uni.Import, import_context: InteropContext
    ) -> None;

    """Collect a native module's PUBLIC top-level symbol names (`def:pub`
    abilities and `:pub` archetypes). See issue #6964."""
    def _collect_pub_native_symbols(
        self: BoundaryAnalysisPass, source_mod: uni.Module
    ) -> list[str];

    """Register an sv import edge (sv->sv or cl->sv): bindings per item."""
    def _register_sv_import(
        self: BoundaryAnalysisPass,
        nd: uni.Import,
        module_name: str,
        caller_ctx: InteropContext
    ) -> None;

    """Walk a module AST collecting Ability nodes by name."""
    def _collect_abilities(
        self: BoundaryAnalysisPass, nd: any, out: dict[str, any]
    ) -> None;

    """Walk a module AST collecting public walker Archetype nodes by name.

    Used by sv-to-sv import resolution to bind `sv import { SomeWalker }`
    to a real walker definition on the provider side. Only `walker:pub`
    archetypes participate -- private walkers are excluded since they
    are not exposed at `/walker/<name>` on the HTTP boundary.
    """
    def _collect_pub_walkers(
        self: BoundaryAnalysisPass, nd: any, out: dict[str, any]
    ) -> None;

    """Extract `has` field (name, type-name) pairs from a walker archetype.

    Only `has` declarations participate in the wire contract; other body
    members (abilities, can blocks, static state) stay on the provider.
    Used by `_register_sv_to_sv_import` to derive RPC param shape.
    """
    def _extract_walker_has_fields(
        self: BoundaryAnalysisPass, walker_nd: any
    ) -> tuple[list[str], list[str]];

    """Find an Archetype or Enum node by name via AST walk."""
    def _find_archetype(self: BoundaryAnalysisPass, nd: any, target: str) -> any;

    """Parse a source file standalone (no semantic analysis)."""
    def _parse_only_source_module(self: BoundaryAnalysisPass, file_path: str) -> any;

    """Record function definition and its context."""
    def enter_ability(self: BoundaryAnalysisPass, nd: uni.Ability) -> None;

    """Check if a function call crosses context boundaries."""
    def enter_func_call(self: BoundaryAnalysisPass, nd: uni.FuncCall) -> None;

    """Extract the inner type name from a subscript expression."""
    def _extract_subscript_inner(
        self: BoundaryAnalysisPass, expr: (uni.UniNode | None)
    ) -> str;

    """Extract all user-defined type names from a subscript."""
    def _extract_all_subscript_types(
        self: BoundaryAnalysisPass, expr: (uni.UniNode | None)
    ) -> list[str];

    """Extract all user-defined type names from a type annotation expression."""
    def _extract_all_type_names(
        self: BoundaryAnalysisPass, expr: (uni.UniNode | None)
    ) -> list[str];

    """Collect a type that crosses the codespace boundary into the manifest."""
    def _collect_boundary_type(
        self: BoundaryAnalysisPass, type_name: str, source_mod: (uni.Module | None)
    ) -> None;

    """After all nodes visited, collect boundary types from SV->CL bindings."""
    def after_pass(self: BoundaryAnalysisPass) -> None;

    """Record compile-time auth requirement for this module's endpoints."""
    def _record_access_levels(self: BoundaryAnalysisPass, manifest: any) -> None;

    """Classify a walker archetype's graph effects (RPC endpoint)."""
    def enter_archetype(self: BoundaryAnalysisPass, nd: uni.Archetype) -> None;

    """Run the effect scan over a flat body, returning the manifest entry."""
    def _classify(self: BoundaryAnalysisPass, body_nodes: list) -> dict;

    """Recursively classify a node and its descendants for graph effects."""
    def _scan(self: BoundaryAnalysisPass, nd: (uni.UniNode | None)) -> None;

    """Resolve a call's target to its symbol (resolved, with scope lookup)."""
    def _call_target_symbol(
        self: BoundaryAnalysisPass, call: uni.FuncCall
    ) -> (uni.Symbol | None);

    """The callee ability's impl-resolved body, or [] if unresolved."""
    def _callee_body(self: BoundaryAnalysisPass, call: uni.FuncCall) -> list;

    """Flatten an archetype/ability body, resolving a separate impl block."""
    def _resolved_body(self: BoundaryAnalysisPass, owner: uni.UniNode) -> list;
}
