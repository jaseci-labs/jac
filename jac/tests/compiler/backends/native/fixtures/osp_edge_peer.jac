import from jaclang.runtime.osp_graph { osp_conn, osp_disconnect, osp_edge_peer }

def probe -> bool {
    osp_conn(101, 102, 201, 0, 1, 0, 0);
    osp_conn(101, 101, 202, 1, 1, 0, 0);
    connected = osp_edge_peer(201, 101) == 102
        and osp_edge_peer(201, 102) == 101
        and osp_edge_peer(201, 103) == -1
        and osp_edge_peer(203, 101) == -1
        and osp_edge_peer(202, 101) == 101;
    osp_disconnect(201);
    osp_disconnect(202);
    return connected and osp_edge_peer(201, 101) == -1;
}

with entry {
    assert probe();
}
