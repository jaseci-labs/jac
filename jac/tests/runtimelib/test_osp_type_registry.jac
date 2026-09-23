"""Contract tests for the kernel's type and descriptor registry (#8775 step 2).

The kernel owns the isa table: hosts register each archetype tag with its
ancestor tags once, and every backend's edge-type filter, plan builder and
descriptor lookup reads the same tables. Pins the three semantics the hosts
used to re-implement: subtype-aware tag filtering on hops and
disconnect-between, refusal of a tag re-registered with a different ancestor
set, and the descriptor registry returning an empty descriptor on a miss
without caching it.
"""

import jaclang.runtime.osp_graph as _g;
import from jaclang.runtime.osp_kernel {
    OspNodeDesc,
    OspSlot,
    UNTYPED,
    osp_has_desc,
    osp_node_desc,
    osp_register_desc
}

glob T_BASE: int = 9100100,
     T_SUB: int = 9100101,
     T_OTHER: int = 9100102;

def _noop_ability(a: any, b: any) -> None {
    return;
}

def _fresh_graph {
    _g.DEFAULT_GRAPH.adj.clear();
    _g.DEFAULT_GRAPH.rows.clear();
    _g.DEFAULT_GRAPH.free_rows.clear();
    _g.DEFAULT_GRAPH.row_of.clear();
    _g.DEFAULT_GRAPH.dead.clear();
    _g.DEFAULT_GRAPH.regions.clear();
}

test "register_type is idempotent and refuses a re-register with different bases" {
    assert _g.osp_register_type(T_BASE, []) == 1;
    assert _g.osp_register_type(T_SUB, [T_BASE]) == 1;
    assert _g.osp_register_type(T_SUB, [T_BASE]) == 1 , "idempotent re-register refused";
    assert _g.osp_register_type(T_SUB, [T_OTHER]) == 0 , "conflicting re-register accepted";
    assert _g.osp_is_a(T_SUB, T_BASE);
    assert _g.osp_is_a(T_SUB, T_SUB);
    assert not _g.osp_is_a(T_BASE, T_SUB);
    assert not _g.osp_is_a(T_SUB, T_OTHER);
}

test "unregistered tags fall back to exact-match is_a" {
    assert _g.osp_is_a(424242, 424242);
    assert not _g.osp_is_a(424242, 424243);
}

test "refs and disconnect_between honour subtyping in the edge-tag filter" {
    _fresh_graph();
    _g.osp_register_type(T_BASE, []);
    _g.osp_register_type(T_SUB, [T_BASE]);
    assert _g.osp_conn(11, 22, 71, 0, T_SUB, 0, 0) == 22;
    assert _g.osp_conn(11, 33, 72, 0, T_OTHER, 0, 0) == 33;
    assert _g.osp_refs(11, 2, T_BASE, 0) == [22] , "[->:Base:->] missed the Sub edge";
    assert _g.osp_refs(11, 2, T_SUB, 0) == [22];
    assert _g.osp_refs(11, 2, -1, 0) == [22, 33];
    assert _g.osp_disconn_between(11, 22, 2, T_BASE) == 1 , "disconnect-between missed the Sub edge";
    assert _g.osp_refs(11, 2, -1, 0) == [33];
}

test "descriptor registry: registered descs return, misses stay uncached" {
    t = 9100200;
    assert not osp_has_desc(t);
    miss = osp_node_desc(t);
    assert miss.type_tag == t and miss.`entry == [];
    assert not osp_has_desc(t) , "a miss was cached";
    nd = OspNodeDesc(
        type_tag=t, `entry=[OspSlot(trig_tag=UNTYPED, fn=_noop_ability)], `exit=[]
    );
    osp_register_desc(t, nd);
    assert osp_has_desc(t);
    assert osp_node_desc(t) is nd;
}
