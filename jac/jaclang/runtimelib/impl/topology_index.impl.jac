"""TopologyIndex implementation."""

"""Return type_id for type_name, registering it if new."""
impl TopologyIndex._ensure_type(type_name: str) -> int {
    tid = self.type_to_id.get(type_name);
    if tid is None {
        tid = len(self.type_table);
        self.type_table.append(type_name);
        self.type_to_id[type_name] = tid;
    }
    return tid;
}

"""Register a node. Returns its local_id."""
impl TopologyIndex.add_node(
    node_id: UUID, type_name: str, owner_root: (UUID | None) = None
) -> int {
    if node_id in self.node_to_lid {
        return self.node_to_lid[node_id];
    }
    tid = self._ensure_type(type_name);
    lid = len(self.node_table);
    self.node_table.append((node_id, tid, owner_root or SELF_ROOT));
    self.node_to_lid[node_id] = lid;
    return lid;
}

"""Remove a node and all edges involving it."""
impl TopologyIndex.remove_node(node_id: UUID) -> None {
    lid = self.node_to_lid.get(node_id);
    if lid is None {
        return;
    }
    self.adj_list = [
        (s, et, t)
        for (s, et, t) in self.adj_list
        if s != lid and t != lid
    ];
}

"""Add an edge to the adjacency list."""
impl TopologyIndex.add_edge(
    source_id: UUID, target_id: UUID, edge_type_name: str
) -> None {
    src_lid = self.node_to_lid.get(source_id);
    tgt_lid = self.node_to_lid.get(target_id);
    if src_lid is None or tgt_lid is None {
        return;
    }
    etid = self._ensure_type(edge_type_name);
    self.adj_list.append((src_lid, etid, tgt_lid));
}

"""Remove edge(s) between source and target, optionally filtered by type."""
impl TopologyIndex.remove_edge(
    source_id: UUID, target_id: UUID, edge_type_name: (str | None) = None
) -> None {
    src_lid = self.node_to_lid.get(source_id);
    tgt_lid = self.node_to_lid.get(target_id);
    if src_lid is None or tgt_lid is None {
        return;
    }
    etid = self.type_to_id.get(edge_type_name) if edge_type_name else None;
    new_adj: list[tuple[int, int, int]] = [];
    removed = False;
    for entry in self.adj_list {
        (s, et, t) = entry;
        if s == src_lid and t == tgt_lid {
            if etid is None or et == etid {
                if not removed {
                    removed = True;
                    continue;
                }
            }
        }
        new_adj.append(entry);
    }
    self.adj_list = new_adj;
}

"""Walk the adjacency list using type-only filters."""
impl TopologyIndex.resolve_chain(
    origin_ids: set[UUID], chain: list[tuple[(str | None), (str | None), int]]
) -> set[UUID] {
    current_lids: set[int] = set();
    for uid in origin_ids {
        lid = self.node_to_lid.get(uid);
        if lid is not None {
            current_lids.add(lid);
        }
    }
    if not current_lids {
        return set();
    }
    for (edge_type, node_type, direction) in chain {
        etid = self.type_to_id.get(edge_type) if edge_type else None;
        ntid = self.type_to_id.get(node_type) if node_type else None;
        if edge_type and etid is None {
            return set();
        }
        if node_type and ntid is None {
            return set();
        }
        next_lids: set[int] = set();
        for (src_lid, et, tgt_lid) in self.adj_list {
            if etid is not None and et != etid {
                continue;
            }
            if direction in (2, 3) and src_lid in current_lids {
                if ntid is None or self.node_table[tgt_lid][1] == ntid {
                    next_lids.add(tgt_lid);
                }
            }
            if direction in (1, 3) and tgt_lid in current_lids {
                if ntid is None or self.node_table[src_lid][1] == ntid {
                    next_lids.add(src_lid);
                }
            }
        }
        current_lids = next_lids;
        if not current_lids {
            return set();
        }
    }
    return {self.node_table[lid][0] for lid in current_lids};
}

"""For a set of node UUIDs, return mapping of foreign_root -> node_ids."""
impl TopologyIndex.get_cross_root_ids(node_ids: set[UUID]) -> dict[UUID, set[UUID]] {
    result: dict[UUID, set[UUID]] = {};
    for uid in node_ids {
        lid = self.node_to_lid.get(uid);
        if lid is None {
            continue;
        }
        owner = self.node_table[lid][2];
        if owner != SELF_ROOT {
            result.setdefault(owner, set()).add(uid);
        }
    }
    return result;
}

"""Serialize to compact binary format."""
impl TopologyIndex.encode -> bytes {
    num_types = len(self.type_table);
    num_nodes = len(self.node_table);
    num_edges = len(self.adj_list);
    parts = [struct.pack("<BHHi", TOPO_VERSION, num_types, num_nodes, num_edges)];
    for name in self.type_table {
        name_bytes = name.encode("utf-8");
        parts.append(struct.pack("<B", len(name_bytes)));
        parts.append(name_bytes);
    }
    for (node_id, type_id, owner_root) in self.node_table {
        parts.append(node_id.bytes);
        parts.append(struct.pack("<H", type_id));
        parts.append(owner_root.bytes);
    }
    for (src, etid, tgt) in self.adj_list {
        parts.append(struct.pack("<HHH", src, etid, tgt));
    }
    return b"".join(parts);
}

"""Deserialize from compact binary format."""
impl TopologyIndex.decode(data: bytes) -> TopologyIndex {
    idx = TopologyIndex();
    if not data {
        return idx;
    }
    offset = 0;
    (version, num_types, num_nodes, num_edges) = struct.unpack_from(
        "<BHHi", data, offset
    );
    offset += struct.calcsize("<BHHi");
    if version != TOPO_VERSION {
        return idx;
    }
    for _ in range(num_types) {
        (name_len, ) = struct.unpack_from("<B", data, offset);
        offset += 1;
        name = data[offset:offset + name_len].decode("utf-8");
        offset += name_len;
        idx.type_table.append(name);
        idx.type_to_id[name] = len(idx.type_table) - 1;
    }
    for i in range(num_nodes) {
        node_id = UUID(bytes=data[offset:offset + 16]);
        offset += 16;
        (type_id, ) = struct.unpack_from("<H", data, offset);
        offset += 2;
        owner_root = UUID(bytes=data[offset:offset + 16]);
        offset += 16;
        idx.node_table.append((node_id, type_id, owner_root));
        idx.node_to_lid[node_id] = i;
    }
    for _ in range(num_edges) {
        (src, etid, tgt) = struct.unpack_from("<HHH", data, offset);
        offset += 6;
        idx.adj_list.append((src, etid, tgt));
    }
    return idx;
}

"""Return number of edges in the index."""
impl TopologyIndex.__len__ -> int {
    return len(self.adj_list);
}

"""String representation."""
impl TopologyIndex.__repr__ -> str {
    return (
        f"TopologyIndex(types={len(self.type_table)}, "
        f"nodes={len(self.node_table)}, edges={len(self.adj_list)})"
    );
}
