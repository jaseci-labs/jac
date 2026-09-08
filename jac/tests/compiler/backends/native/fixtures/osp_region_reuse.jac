import from jaclang.runtime.osp_graph {
    osp_conn,
    osp_drop_node,
    osp_refs,
    osp_region_died
}

def probe -> bool {
    osp_conn(101, 102, 201, 0, -1, 1001, 1001);
    osp_drop_node(101);
    osp_conn(101, 103, 202, 0, -1, 1002, 1002);
    osp_region_died(1001);
    peers = osp_refs(101, 2, -1, 0);
    valid = len(peers) == 1 and peers[0] == 103;
    osp_region_died(1002);
    return valid and not osp_refs(101, 2, -1, 0);
}
