"""Jac TTG (Temporal Trace Graph) analysis pass.

Collects visit metadata for walker abilities so that the runtime TTG
generator can predict traversal paths without re-parsing source code.
"""
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { TTG_VISIT_FIELD, Tokens as Tok }
import from jaclang.jac0core.passes.uni_pass { UniPass }

"""Annotate walker archetypes with visit type metadata for TTG generation."""
class JacTTGPass(UniPass) {
    """Process a single walker archetype to extract visit metadata."""
    def _annotate_walker(self: JacTTGPass, warch_node: uni.Archetype) -> None;

    """Extract all visit types from a walker's abilities."""
    def _get_visits_for_walker(
        self: JacTTGPass, warch_node: uni.Archetype
    ) -> list[tuple[((uni.Archetype | None), (uni.Archetype | None))]];

    """Determine edge type from a visit statement's filter comprehension."""
    def _get_edge_type_from_visit(
        self: JacTTGPass, visit_stmt: uni.VisitStmt
    ) -> (uni.Archetype | None);

    """Resolve a name to an Archetype AST node via symbol table lookup."""
    def _resolve_archetype(
        self: JacTTGPass, scope_src: uni.UniNode, name: str
    ) -> (uni.Archetype | None);

    def enter_archetype(self: JacTTGPass, nd: uni.Archetype) -> None;
}
