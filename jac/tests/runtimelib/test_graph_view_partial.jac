"""The graph view walk must render what it can, not 500 on one bad edge.

`collect_node_connections` backs the /graph/data endpoint. A node whose edge
list cites an anchor that cannot be loaded in this process (quarantined row,
peer service's class in a shared store, legacy corruption) must be skipped --
raising turns one dangling reference into a blank graph for the whole app.
"""

import from uuid { uuid4 }

import from jaclang.jac0core.archetype { EdgeAnchor, GenericEdge, Root }
import from jaclang.runtimelib.utils { collect_node_connections }


"""An unpopulatable EdgeAnchor stub (its backing row is unreadable/gone)."""
def _dangling_edge_stub -> any {
    stub: any = EdgeAnchor.__new__(EdgeAnchor);
    stub.id = uuid4();
    return stub;
}


test "collect_node_connections skips an unresolvable edge instead of raising" {
    root_arch: any = Root();
    ranch: any = root_arch.__jac__;
    ranch.edges.append(_dangling_edge_stub());

    visited: set = set();
    connections: set = set();
    edge_ids: set = set();
    collect_node_connections(root_arch, visited, connections, edge_ids);

    assert root_arch in visited;
    assert len(connections) == 0;
}

test "collect_node_connections still returns the resolvable part of the graph" {
    root_arch: any = Root();
    other_arch: any = Root();
    ranch: any = root_arch.__jac__;

    edge_arch: any = GenericEdge();
    e: any = edge_arch.__jac__;
    e.source = ranch;
    e.target = other_arch.__jac__;
    ranch.edges.append(e);
    ranch.edges.append(_dangling_edge_stub());

    visited: set = set();
    connections: set = set();
    edge_ids: set = set();
    collect_node_connections(root_arch, visited, connections, edge_ids);

    assert len(connections) == 1 , (
        f"the healthy edge must survive a dangling sibling entry, "
        f"got {len(connections)} connections"
    );
    assert other_arch in visited;
}
