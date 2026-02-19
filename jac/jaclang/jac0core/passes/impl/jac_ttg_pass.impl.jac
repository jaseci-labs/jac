"""Implementation for JacTTGPass constructs."""

"""Process walker archetypes when entering them in the AST traversal."""
impl JacTTGPass.enter_archetype(self: JacTTGPass, nd: uni.Archetype) -> None {
    if (nd.arch_type.name == Tok.KW_WALKER) {
        self._annotate_walker(nd);
    }
}

"""Annotate a walker archetype with its visit type metadata.

The metadata is stored as a list of (from_node_archetype, edge_archetype)
tuples on the AST node using the TTG_VISIT_FIELD attribute. The code
generator later translates these into runtime VisitType instances.
"""
impl JacTTGPass._annotate_walker(self: JacTTGPass, warch_node: uni.Archetype) -> None {
    visits = self._get_visits_for_walker(warch_node);
    setattr(warch_node, TTG_VISIT_FIELD, visits);
}

"""Extract all visit types from a walker's abilities.

For each ability with an EventSignature (e.g., `can do with NodeType entry`),
extracts the node type. For each VisitStmt with a FilterCompr
(e.g., `visit [->:EdgeType:->]`), extracts the edge type.

Returns a list of (from_node_archetype_or_None, edge_archetype_or_None) tuples.
"""
impl JacTTGPass._get_visits_for_walker(
    self: JacTTGPass, warch_node: uni.Archetype
) -> list[tuple[((uni.Archetype | None), (uni.Archetype | None))]] {
    result: list[tuple[((uni.Archetype | None), (uni.Archetype | None))]] = [];
    abilities = self.get_all_sub_nodes(warch_node, uni.Ability);
    for ability in abilities {
        event_sigs = self.get_all_sub_nodes(ability, uni.EventSignature);
        if (len(event_sigs) == 0) {
            continue;
        }
        # Determine the from-node type from the event signature.
        node_type: (uni.Archetype | None) = None;
        node_type_names = self.get_all_sub_nodes(event_sigs[0], uni.Name);
        if (len(node_type_names) > 0) {
            node_type = self._resolve_archetype(
                node_type_names[0], node_type_names[0].value
            );
        }
        # Collect visit statements within this ability.
        visit_stmts = self.get_all_sub_nodes(ability, uni.VisitStmt);
        for visit_stmt in visit_stmts {
            edge_type = self._get_edge_type_from_visit(visit_stmt);
            result.append((node_type, edge_type));
        }
    }
    return result;
}

"""Determine edge type from a visit statement's edge reference.

Inspects EdgeOpRef children of the VisitStmt and extracts the edge type
from the EdgeOpRef.filter_cond (e.g., `[-:EdgeType:->]`). FilterCompr
nodes that appear as direct children of VisitStmt (e.g., `(?:NodeType)`)
are node filters, NOT edge types — those are intentionally ignored here.
Returns None if no edge type filter is present (generic edge).
"""
impl JacTTGPass._get_edge_type_from_visit(
    self: JacTTGPass, visit_stmt: uni.VisitStmt
) -> (uni.Archetype | None) {
    edge_refs = self.get_all_sub_nodes(visit_stmt, uni.EdgeOpRef);
    if (len(edge_refs) == 0) {
        return None;
    }
    # Check the first EdgeOpRef for a filter_cond (edge type filter).
    edge_ref = edge_refs[0];
    fc = getattr(edge_ref, 'filter_cond', None);
    if (fc is None) {
        return None;
    }
    # Extract the type name from the FilterCompr's f_type field.
    ft = getattr(fc, 'f_type', None);
    if (ft is None) {
        return None;
    }
    names = self.get_all_sub_nodes(fc, uni.Name);
    if (len(names) == 0) {
        return None;
    }
    return self._resolve_archetype(visit_stmt, names[0].value);
}

"""Resolve a name to an Archetype AST node via symbol table lookup.

Returns None if the lookup fails (e.g., unresolved type).
"""
impl JacTTGPass._resolve_archetype(
    self: JacTTGPass, scope_src: uni.UniNode, name: str
) -> (uni.Archetype | None) {
    scope = self.find_parent_of_type(scope_src, uni.UniScopeNode);
    if (scope is None) {
        return None;
    }
    result = scope.lookup(name);
    if (result is None) {
        return None;
    }
    arch = self.find_parent_of_type(result.decl, uni.Archetype);
    return arch;
}
