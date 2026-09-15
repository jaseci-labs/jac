import from jaclang.runtime.osp_graph { _new_graph }

def probe -> bool {
    store = _new_graph();
    store.connect(1, 1, 11, True, 1, 101, 101);
    store.connect(2, 3, 12, False, 1, 102, 102);
    retired = store.row_of[11];
    survivor = store.row_of[12];
    if store.region_died(101) != 1
        or store.rows[retired] is not None
        or store.rows[survivor] is None
        or store.edge_peer(12, 2) != 3 {
        return False;
    }
    store.connect(4, 5, 13, False, 1, 102, 102);
    if store.row_of[13] != retired or store.edge_peer(13, 4) != 5 {
        return False;
    }
    if store.region_died(102) != 2 {
        return False;
    }
    if store.rows or store.free_rows or store.adj or store.row_of {
        return False;
    }
    store.connect(1, 2, 11, False, 1, 0, 0);
    store.drop_node(1);
    store.drop_node(2);
    return not store.rows and not store.free_rows and not store.adj;
}

with entry {
    assert probe();
}
