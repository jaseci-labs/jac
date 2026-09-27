import from jaclang.runtime.osp_graph { OspGraph }

glob HEX: str = "0123456789abcdef";

test "jid is stable per handle and never reused after the handle is dropped" {
    g = OspGraph(adj={}, rows=[], free_rows=[], row_of={}, dead={}, regions={});
    a = g.jid_of(101);
    assert len(a) == 32 and all(ch in HEX for ch in a) , a;
    assert g.jid_of(101) == a;
    assert g.jid_of(102) != a;
    g.drop_node(101);
    assert g.jid_of(101) != a , "an address reused after drop_node gets a fresh jid";
}

test "bound endpoints keep node results reaching the wanted set" {
    g = OspGraph(adj={}, rows=[], free_rows=[], row_of={}, dead={}, regions={});
    assert g.keep_toward([2, 3, 4], [1], 2, False, [3, 9]) == [3];
    assert g.keep_toward([2, 3], [1], 2, False, []) == [];
}

test "bound endpoints keep edges by their far end in the hop direction" {
    g = OspGraph(adj={}, rows=[], free_rows=[], row_of={}, dead={}, regions={});
    g.connect(1, 2, 201, False, 1, 0, 0);
    g.connect(3, 1, 202, False, 1, 0, 0);
    g.connect(1, 4, 203, True, 1, 0, 0);
    g.connect(5, 1, 204, True, 1, 0, 0);
    edges = [201, 202, 203, 204];
    assert g.keep_toward(edges, [1], 2, True, [2, 3, 4, 5]) == [201, 203, 204];
    assert g.keep_toward(edges, [1], 1, True, [2, 3, 4, 5]) == [202, 203, 204];
    assert g.keep_toward(edges, [1], 3, True, [2, 3]) == [201, 202];
    assert g.keep_toward(edges, [1], 2, True, [1]) == [] , "the origin itself is never the far end of a directed out-edge";
}
