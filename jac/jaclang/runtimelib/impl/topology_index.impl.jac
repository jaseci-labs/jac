"""TopologyIndex implementation.

The canonical `adj_list` is the source of truth for encode/decode and preserves
multi-edge multiplicity. The `buckets` map is a derived index keyed by
`(src_lid, col_key) -> (in_adj_indices, out_adj_indices)` where `col_key` is
`"n:<type_id>"` or `"e:<edge_type_id>"`. Each entry is an index into `adj_list`,
kept in sorted order so ordered intersections preserve edge insertion order.
Targets are fanned out under every ancestor type id so parent-type queries
resolve via a single merge-intersection.
"""

"""Build a lookup column key for a node-type id."""
def _n_key(type_id: int) -> str {
    return "n:" + str(type_id);
}

"""Build a lookup column key for an edge-type id."""
def _e_key(edge_type_id: int) -> str {
    return "e:" + str(edge_type_id);
}

"""Get or create the (in, out) sorted adj_list index lists for `(src_lid, col_key)`."""
def _get_col(
    buckets: dict[int, dict[str, tuple[list[int], list[int]]]],
    src_lid: int,
    col_key: str
) -> tuple[list[int], list[int]] {
    bucket = buckets.get(src_lid);
    if bucket is None {
        bucket = {};
        buckets[src_lid] = bucket;
    }
    col = bucket.get(col_key);
    if col is None {
        col = ([], []);
        bucket[col_key] = col;
    }
    return col;
}

"""Ordered intersection of two sorted integer lists."""
def _intersect_sorted(a: list[int], b: list[int]) -> list[int] {
    result: list[int] = [];
    i = 0;
    j = 0;
    while i < len(a) and j < len(b) {
        if a[i] < b[j] {
            i += 1;
        } elif a[i] > b[j] {
            j += 1;
        } else {
            result.append(a[i]);
            i += 1;
            j += 1;
        }
    }
    return result;
}

"""Fan out one edge into the bucket index under MRO ancestors."""
def _index_edge(
    buckets: dict[int, dict[str, tuple[list[int], list[int]]]],
    adj_idx: int,
    src: int,
    etid: int,
    tgt: int,
    type_mro_ids: list[list[int]],
    node_table: list[tuple[UUID, int, UUID]]
) {
    (_, src_type_id, _) = node_table[src];
    (_, tgt_type_id, _) = node_table[tgt];
    src_ancestors = type_mro_ids[src_type_id] or [src_type_id];
    tgt_ancestors = type_mro_ids[tgt_type_id] or [tgt_type_id];

    for anc in tgt_ancestors {
        out_col = _get_col(buckets, src, _n_key(anc));
        out_col[1].append(adj_idx);
    }
    e_out = _get_col(buckets, src, _e_key(etid));
    e_out[1].append(adj_idx);

    for anc in src_ancestors {
        in_col = _get_col(buckets, tgt, _n_key(anc));
        in_col[0].append(adj_idx);
    }
    e_in = _get_col(buckets, tgt, _e_key(etid));
    e_in[0].append(adj_idx);
}

"""Rebuild all buckets from scratch by replaying adj_list."""
def _rebuild_buckets(
    adj_list: list[tuple[int, int, int]],
    type_mro_ids: list[list[int]],
    node_table: list[tuple[UUID, int, UUID]]
) -> dict[int, dict[str, tuple[list[int], list[int]]]] {
    buckets: dict[int, dict[str, tuple[list[int], list[int]]]] = {};
    for (adj_idx, (src, etid, tgt)) in enumerate(adj_list) {
        _index_edge(buckets, adj_idx, src, etid, tgt, type_mro_ids, node_table);
    }
    return buckets;
}

"""Return type_id for type_name, registering it (and its MRO chain) if new."""
impl TopologyIndex._ensure_type(
    type_name: str, mro_chain: (list[str] | None) = None
) -> int {
    tid = self.type_to_id.get(type_name);
    if tid is None {
        tid = len(self.type_table);
        self.type_table.append(type_name);
        self.type_to_id[type_name] = tid;
        self.type_mro_ids.append([]);
    }
    # Lazily fill / upgrade the MRO chain. The first element of `mro_chain`
    # is the concrete type itself, so encoded chains always include `tid`
    # at index 0. We also accept a longer chain over a shorter one — this
    # lets the v1->v2 migration's stub `[tid]` chain upgrade to the real
    # ancestor list on the next mutation that provides one.
    if mro_chain and len(mro_chain) > len(self.type_mro_ids[tid]) {
        chain_ids: list[int] = [];
        for anc in mro_chain {
            chain_ids.append(self._ensure_type(anc));
        }
        self.type_mro_ids[tid] = chain_ids;
    } elif not self.type_mro_ids[tid] {
        self.type_mro_ids[tid] = [tid];
    }
    return tid;
}

"""Register a node. Returns its local_id. Idempotent on `node_id`."""
impl TopologyIndex.add_node(
    node_id: UUID,
    type_name: str,
    mro_chain: (list[str] | None) = None,
    owner_root: (UUID | None) = None
) -> int {
    if node_id in self.node_to_lid {
        if mro_chain {
            self._ensure_type(type_name, mro_chain);
        }
        return self.node_to_lid[node_id];
    }
    tid = self._ensure_type(type_name, mro_chain);
    lid = len(self.node_table);
    self.node_table.append((node_id, tid, owner_root or SELF_ROOT));
    self.node_to_lid[node_id] = lid;
    return lid;
}

"""Remove a node and every edge involving it. Rebuilds buckets from scratch."""
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
    self.buckets = _rebuild_buckets(self.adj_list, self.type_mro_ids, self.node_table);
}

"""Add an edge to `adj_list` and fan out into the buckets under MRO ancestors."""
impl TopologyIndex.add_edge(
    source_id: UUID, target_id: UUID, edge_type_name: str
) -> None {
    src_lid = self.node_to_lid.get(source_id);
    tgt_lid = self.node_to_lid.get(target_id);
    if src_lid is None or tgt_lid is None {
        return;
    }
    etid = self._ensure_type(edge_type_name);
    adj_idx = len(self.adj_list);
    self.adj_list.append((src_lid, etid, tgt_lid));
    _index_edge(
        self.buckets,
        adj_idx,
        src_lid,
        etid,
        tgt_lid,
        self.type_mro_ids,
        self.node_table
    );
}

"""Remove a single edge between source and target. If `edge_type_name` is None,
drops the first edge found between them."""
impl TopologyIndex.remove_edge(
    source_id: UUID, target_id: UUID, edge_type_name: (str | None) = None
) -> None {
    src_lid = self.node_to_lid.get(source_id);
    tgt_lid = self.node_to_lid.get(target_id);
    if src_lid is None or tgt_lid is None {
        return;
    }
    filter_etid = self.type_to_id.get(edge_type_name) if edge_type_name else None;

    # Find and remove the first matching edge.
    removed_pos: int = -1;
    new_adj: list[tuple[int, int, int]] = [];
    for (i, entry) in enumerate(self.adj_list) {
        (s, et, t) = entry;
        if removed_pos < 0 and s == src_lid and t == tgt_lid {
            if filter_etid is None or et == filter_etid {
                removed_pos = i;
                continue;
            }
        }
        new_adj.append(entry);
    }
    if removed_pos < 0 {
        return;
    }
    self.adj_list = new_adj;

    # Reindex all bucket lists: remove the deleted position and shift
    # everything above it down by one.
    empty_nodes: list[int] = [];
    for (node_lid, bucket) in self.buckets.items() {
        empty_keys: list[str] = [];
        for (key, col) in bucket.items() {
            col[0][:] = [
                x - 1 if x > removed_pos else x
                for x in col[0]
                if x != removed_pos
            ];
            col[1][:] = [
                x - 1 if x > removed_pos else x
                for x in col[1]
                if x != removed_pos
            ];
            if not col[0] and not col[1] {
                empty_keys.append(key);
            }
        }
        for k in empty_keys {
            bucket.pop(k, None);
        }
        if not bucket {
            empty_nodes.append(node_lid);
        }
    }
    for n in empty_nodes {
        self.buckets.pop(n, None);
    }
}

"""Walk the buckets using ordered merge-intersections. `chain` is a list of
`(edge_type, node_type, direction)` where direction is 1=IN, 2=OUT, 3=ANY.

Returns results in canonical edge-insertion order (adj_list order).

When `bail_on_intermediate_foreign` is True, returns None if any hop
*before* the final hop produces a node owned by a different root — those
nodes' outgoing edges live in their owner's index, not this one, so the
chain would silently miss them. The final hop is allowed to land on
foreign nodes because their incoming edges are mirrored into this
index by `_index_edge_into`."""
impl TopologyIndex.resolve_chain(
    origin_ids: set[UUID],
    chain: list[tuple[(str | None), (str | None), int]],
    bail_on_intermediate_foreign: bool = False
) -> (list[UUID] | None) {
    current_lids: list[int] = [];
    seen_lids: set[int] = set();
    for uid in origin_ids {
        lid = self.node_to_lid.get(uid);
        if lid is not None and lid not in seen_lids {
            seen_lids.add(lid);
            current_lids.append(lid);
        }
    }
    if not current_lids {
        return [];
    }
    last_idx = len(chain) - 1;
    for (hop_idx, (edge_type, node_type, direction)) in enumerate(chain) {
        etid = self.type_to_id.get(edge_type) if edge_type else None;
        ntid = self.type_to_id.get(node_type) if node_type else None;
        if edge_type and etid is None {
            return [];
        }
        if node_type and ntid is None {
            return [];
        }
        want_out = direction in (2, 3);
        want_in = direction in (1, 3);
        col_keys: list[str] = [];
        if etid is not None {
            col_keys.append(_e_key(etid));
        }
        if ntid is not None {
            col_keys.append(_n_key(ntid));
        }

        # Collect (adj_idx, neighbor_lid) from all origins.
        candidates: list[tuple[int, int]] = [];
        for src_lid in current_lids {
            bucket = self.buckets.get(src_lid);
            if bucket is None {
                continue;
            }
            if not col_keys {
                # Wildcard: union all adj indices from all columns, deduped.
                out_set: set[int] = set();
                in_set: set[int] = set();
                for (_, col) in bucket.items() {
                    if want_out {
                        for ai in col[1] {
                            out_set.add(ai);
                        }
                    }
                    if want_in {
                        for ai in col[0] {
                            in_set.add(ai);
                        }
                    }
                }
                for ai in out_set {
                    candidates.append((ai, self.adj_list[ai][2]));
                }
                for ai in in_set {
                    candidates.append((ai, self.adj_list[ai][0]));
                }
                continue;
            }

            # Intersect column lists for OUT and IN separately.
            if want_out {
                out_result: (list[int] | None) = None;
                for ck in col_keys {
                    col = bucket.get(ck);
                    if col is None {
                        out_result = [];
                        break;
                    }
                    out_result = col[1]
                        if out_result is None
                        else _intersect_sorted(out_result, col[1]);
                }
                if out_result {
                    for ai in out_result {
                        candidates.append((ai, self.adj_list[ai][2]));
                    }
                }
            }
            if want_in {
                in_result: (list[int] | None) = None;
                for ck in col_keys {
                    col = bucket.get(ck);
                    if col is None {
                        in_result = [];
                        break;
                    }
                    in_result = col[0]
                        if in_result is None
                        else _intersect_sorted(in_result, col[0]);
                }
                if in_result {
                    for ai in in_result {
                        candidates.append((ai, self.adj_list[ai][0]));
                    }
                }
            }
        }

        # Sort by adj_list index to recover insertion order, dedupe neighbors.
        candidates.sort();
        next_lids: list[int] = [];
        next_seen: set[int] = set();
        for (_, neighbor) in candidates {
            if neighbor not in next_seen {
                next_seen.add(neighbor);
                next_lids.append(neighbor);
            }
        }

        current_lids = next_lids;
        seen_lids = next_seen;
        if not current_lids {
            return [];
        }
        if bail_on_intermediate_foreign and hop_idx < last_idx {
            for lid in current_lids {
                if self.node_table[lid][2] != SELF_ROOT {
                    return None;
                }
            }
        }
    }
    return [self.node_table[lid][0] for lid in current_lids];
}

"""For a set of node UUIDs, return mapping of foreign_root_uuid -> {node_ids}."""
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

"""Serialize to compact binary format (version 2)."""
impl TopologyIndex.encode -> bytes {
    num_types = len(self.type_table);
    num_nodes = len(self.node_table);
    num_edges = len(self.adj_list);
    parts = [struct.pack("<BHHi", TOPO_VERSION, num_types, num_nodes, num_edges)];
    for (i, name) in enumerate(self.type_table) {
        name_bytes = name.encode("utf-8");
        parts.append(struct.pack("<B", len(name_bytes)));
        parts.append(name_bytes);
        chain = self.type_mro_ids[i] if i < len(self.type_mro_ids) else [i];
        if not chain {
            chain = [i];
        }
        parts.append(struct.pack("<B", len(chain)));
        for anc_id in chain {
            parts.append(struct.pack("<H", anc_id));
        }
    }
    for (node_id, type_id, owner_root) in self.node_table {
        parts.append(node_id.bytes);
        parts.append(struct.pack("<H", type_id));
        parts.append(owner_root.bytes);
    }
    for (src, etid, tgt) in self.adj_list {
        parts.append(struct.pack("<HHH", src, etid, tgt));
    }
    buf = bytearray();
    for p in parts {
        buf.extend(p);
    }
    return bytes(buf);
}

"""Migrate a v1 encoded blob to v2 by splicing default MRO chains into the
type table. Pure byte-level — no graph data is loaded. Each type is given a
chain of `[self]`; subsequent mutations replace it with the real ancestor
chain via `_ensure_type`'s widen-the-check logic."""
def _migrate_v1_to_v2(data: bytes) -> bytes {
    if len(data) < 9 or data[0] != 1 {
        return data;
    }
    (_, num_types, num_nodes, num_edges) = struct.unpack_from("<BHHi", data, 0);
    out = bytearray();
    out.extend(struct.pack("<BHHi", TOPO_VERSION, num_types, num_nodes, num_edges));
    offset = struct.calcsize("<BHHi");
    for tid in range(num_types) {
        (name_len, ) = struct.unpack_from("<B", data, offset);
        offset += 1;
        out.append(name_len);
        out.extend(data[offset:offset + name_len]);
        offset += name_len;
        # Stub MRO: type is its own only ancestor. Real chain gets installed
        # on the next mutation that calls _ensure_type with mro_chain.
        out.append(1);
        out.extend(struct.pack("<H", tid));
    }
    out.extend(data[offset:]);
    return bytes(out);
}

"""Deserialize from compact binary format. Rebuilds the buckets by replaying edges."""
impl TopologyIndex.decode(data: bytes) -> TopologyIndex {
    idx = TopologyIndex();
    if not data {
        return idx;
    }
    if data[0] == 1 {
        data = _migrate_v1_to_v2(data);
    }
    offset = 0;
    (version, num_types, num_nodes, num_edges) = struct.unpack_from(
        "<BHHi", data, offset
    );
    offset += struct.calcsize("<BHHi");
    if version != TOPO_VERSION {
        return idx;
    }
    # Pass 1: type names + MRO chains.
    for _ in range(num_types) {
        (name_len, ) = struct.unpack_from("<B", data, offset);
        offset += 1;
        name = data[offset:offset + name_len].decode("utf-8");
        offset += name_len;
        idx.type_table.append(name);
        idx.type_to_id[name] = len(idx.type_table) - 1;
        (mro_len, ) = struct.unpack_from("<B", data, offset);
        offset += 1;
        chain: list[int] = [];
        for _ in range(mro_len) {
            (anc, ) = struct.unpack_from("<H", data, offset);
            offset += 2;
            chain.append(anc);
        }
        idx.type_mro_ids.append(chain);
    }
    # Pass 2: nodes.
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
    # Pass 3: edges. Replay through the fan-out helper.
    for _ in range(num_edges) {
        unpacked = struct.unpack_from("<HHH", data, offset);
        src: int = int(unpacked[0]);
        etid: int = int(unpacked[1]);
        tgt: int = int(unpacked[2]);
        offset += 6;
        adj_idx = len(idx.adj_list);
        idx.adj_list.append((src, etid, tgt));
        _index_edge(
            idx.buckets, adj_idx, src, etid, tgt, idx.type_mro_ids, idx.node_table
        );
    }
    return idx;
}

"""Number of edges in the canonical adj_list."""
impl TopologyIndex.__len__ -> int {
    return len(self.adj_list);
}

"""Compact debug repr."""
impl TopologyIndex.__repr__ -> str {
    return (
        f"TopologyIndex(types={len(self.type_table)}, "
        f"nodes={len(self.node_table)}, edges={len(self.adj_list)})"
    );
}
