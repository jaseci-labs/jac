"""The host graph handle table indexes objects without owning their lifetime."""

import gc;
import weakref;
import from jaclang.runtime.osp_graph_sv { sv_conn, sv_live_edges, sv_store_closed }

node LifetimeNode {}

edge LifetimeLink {
    has value: int = 1;
}

obj LifetimeStore {}

def cycle_refs -> list[weakref.ReferenceType] {
    first = LifetimeNode();
    second = LifetimeNode();
    first +>:LifetimeLink:+> second;
    second +>:LifetimeLink:+> first;
    return [weakref.ref(first), weakref.ref(second)];
}

test "unowned heavy graph cycles are reclaimable" {
    references = cycle_refs();
    gc.collect();
    assert all(reference() is None for reference in references);
}

def registered_pair(store: LifetimeStore) -> tuple[LifetimeNode, LifetimeNode] {
    first = LifetimeNode();
    second = LifetimeNode();
    first +>:LifetimeLink:+> second;
    links = [edge first->:LifetimeLink:->];
    sv_conn(first.__jac__, second.__jac__, links[0].__jac__, False, store);
    return (first, second);
}

test "retiring an old store cannot disconnect recycled handles in a new store" {
    old_store = LifetimeStore();
    old_pair = registered_pair(old_store);
    old_refs = [weakref.ref(node) for node in old_pair];
    del old_pair;
    gc.collect();
    assert all(reference() is None for reference in old_refs);
    new_store = LifetimeStore();
    pair = registered_pair(new_store);
    assert len(sv_live_edges(pair[0].__jac__, 2, LifetimeLink, True, new_store)) == 1;
    sv_store_closed(old_store);
    assert len(sv_live_edges(pair[0].__jac__, 2, LifetimeLink, True, new_store)) == 1;
    sv_store_closed(new_store);
}

test "closing a live store does not let old finalizers release a reused handle" {
    old_store = LifetimeStore();
    old_pair = registered_pair(old_store);
    sv_store_closed(old_store);
    new_store = LifetimeStore();
    pair = registered_pair(new_store);
    del old_pair;
    gc.collect();
    assert len(sv_live_edges(pair[0].__jac__, 2, LifetimeLink, True, new_store)) == 1;
    sv_store_closed(new_store);
}
