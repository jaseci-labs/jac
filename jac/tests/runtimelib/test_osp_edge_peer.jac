import from jaclang.runtime.osp_graph { OspGraph }

test "edge peers require live incidence and survive graph row reuse" {
    graph = OspGraph(adj={}, rows=[], free_rows=[], row_of={}, dead={}, regions={});
    assert graph.edge_peer(201, 101) == -1;
    graph.connect(101, 102, 201, False, 1, 0, 0);
    assert graph.edge_peer(201, 101) == 102;
    assert graph.edge_peer(201, 102) == 101;
    assert graph.edge_peer(201, 103) == -1;
    graph.connect(101, 101, 202, True, 1, 0, 0);
    assert graph.edge_peer(202, 101) == 101;
    assert graph.disconnect(201);
    assert graph.edge_peer(201, 101) == -1;
    graph.connect(103, 104, 203, True, 1, 0, 0);
    assert graph.edge_peer(201, 103) == -1;
    assert graph.edge_peer(203, 103) == 104;
    assert graph.edge_peer(203, 104) == 103;
    assert graph.edge_peer(203, 101) == -1;
}
