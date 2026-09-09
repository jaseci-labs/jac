import from jaclang.runtime.osp_graph { OspGraph }

test "edge peers require live incidence and survive graph row reuse" {
    topology = OspGraph(adj={}, rows=[], free_rows=[], row_of={}, dead={}, regions={});
    assert topology.edge_peer(201, 101) == -1;
    topology.connect(101, 102, 201, False, 1, 0, 0);
    assert topology.edge_peer(201, 101) == 102;
    assert topology.edge_peer(201, 102) == 101;
    assert topology.edge_peer(201, 103) == -1;
    topology.connect(101, 101, 202, True, 1, 0, 0);
    assert topology.edge_peer(202, 101) == 101;
    assert topology.disconnect(201);
    assert topology.edge_peer(201, 101) == -1;
    topology.connect(103, 104, 203, True, 1, 0, 0);
    assert topology.edge_peer(201, 103) == -1;
    assert topology.edge_peer(203, 103) == 104;
    assert topology.edge_peer(203, 104) == 103;
    assert topology.edge_peer(203, 101) == -1;
}
