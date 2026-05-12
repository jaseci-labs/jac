"""TopologyIndex implementation.

The canonical `adj_list` is the source of truth for encode/decode and preserves
multi-edge multiplicity. The `buckets` map is a derived index keyed by
`(src_lid, col_key) -> (in_lids, out_lids)` where `col_key` is `"n:<type_id>"`
or `"e:<edge_type_id>"`. Targets are fanned out under every ancestor type id so
parent-type queries resolve in O(1).
"""

"""Build a lookup column key for a node-type id."""
def _n_key(type_id: int) -> str {
    return "n:" + str(type_id);
}

"""Build a lookup column key for an edge-type id."""
def _e_key(edge_type_id: int) -> str {
    return "e:" + str(edge_type_id);
}

"""Get or create the (in, out) sets for `(src_lid, col_key)` in the lookup.

Backed by sets (not lists) so add/discard/membership are all O(1) â keeps
add_edge linear-per-call even for hub nodes with thousands of outgoing
edges. Order is not preserved, but the canonical adj_list already provides
deterministic ordering for any caller that needs it."""
def _get_col(
    buckets: dict[int, dict[str, tuple[set[int], set[int]]]], src_lid: int, col_key: str
) -> tuple[set[int], set[int]] {
    bucket = buckets.get(src_lid);
    if bucket is None {
        bucket = {};
        buckets[src_lid] = bucket;
    }
    col = bucket.get(col_key);
    if col is None {
        col = (set(), set());
        bucket[col_key] = col;
    }
    return col;
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

"""Remove a node and every edge involving it."""
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
    self.buckets.pop(lid, None);
    for (_, bucket) in self.buckets.items() {
        for (_, col) in bucket.items() {
            col[0].discard(lid);
            col[1].discard(lid);
        }
    }
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
    self.adj_list.append((src_lid, etid, tgt_lid));

    (_, src_type_id, _) = self.node_table[src_lid];
    (_, tgt_type_id, _) = self.node_table[tgt_lid];
    src_ancestors = self.type_mro_ids[src_type_id] or [src_type_id];
    tgt_ancestors = self.type_mro_ids[tgt_type_id] or [tgt_type_id];

    for anc in tgt_ancestors {
        out_col = _get_col(self.buckets, src_lid, _n_key(anc));
        out_col[1].add(tgt_lid);
    }
    e_out = _get_col(self.buckets, src_lid, _e_key(etid));
    e_out[1].add(tgt_lid);

    for anc in src_ancestors {
        in_col = _get_col(self.buckets, tgt_lid, _n_key(anc));
        in_col[0].add(src_lid);
    }
    e_in = _get_col(self.buckets, tgt_lid, _e_key(etid));
    e_in[0].add(src_lid);
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

    new_adj: list[tuple[int, int, int]] = [];
    removed_etid: int = 0;
    removed_any = False;
    for entry in self.adj_list {
        (s, et, t) = entry;
        if not removed_any and s == src_lid and t == tgt_lid {
            if filter_etid is None or et == filter_etid {
                removed_etid = et;
                removed_any = True;
                continue;
            }
        }
        new_adj.append(entry);
    }
    if not removed_any {
        return;
    }
    self.adj_list = new_adj;

    edge_type_still_connects = False;
    any_edge_remains = False;
    for (s, et, t) in self.adj_list {
        if s == src_lid and t == tgt_lid {
            any_edge_remains = True;
            if et == removed_etid {
                edge_type_still_connects = True;
            }
        }
    }

    src_bucket = self.buckets.get(src_lid);
    tgt_bucket = self.buckets.get(tgt_lid);

    if not edge_type_still_connects {
        e_key = _e_key(removed_etid);
        if src_bucket is not None {
            e_col = src_bucket.get(e_key);
            if e_col is not None {
                e_col[1].discard(tgt_lid);
                if not e_col[0] and not e_col[1] {
                    src_bucket.pop(e_key, None);
                }
            }
        }
        if tgt_bucket is not None {
            e_col_rev = tgt_bucket.get(e_key);
            if e_col_rev is not None {
                e_col_rev[0].discard(src_lid);
                if not e_col_rev[0] and not e_col_rev[1] {
                    tgt_bucket.pop(e_key, None);
                }
            }
        }
    }

    if not any_edge_remains {
        if src_bucket is not None {
            empty: list[str] = [];
            for (key, col) in src_bucket.items() {
                if key.startswith("n:") {
                    col[1].discard(tgt_lid);
                    if not col[0] and not col[1] {
                        empty.append(key);
                    }
                }
            }
            for k in empty {
                src_bucket.pop(k, None);
            }
        }
        if tgt_bucket is not None {
            empty_rev: list[str] = [];
            for (key, col) in tgt_bucket.items() {
                if key.startswith("n:") {
                    col[0].discard(src_lid);
                    if not col[0] and not col[1] {
                        empty_rev.append(key);
                    }
                }
            }
            for k in empty_rev {
                tgt_bucket.pop(k, None);
            }
        }
    }

    if src_bucket is not None and not src_bucket {
        self.buckets.pop(src_lid, None);
    }
    if tgt_bucket is not None and not tgt_bucket {
        self.buckets.pop(tgt_lid, None);
    }
}

"""Walk the buckets using type filters. `chain` is a list of
`(edge_type, node_type, direction)` where direction is 1=IN, 2=OUT, 3=ANY."""
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
        col_keys: list[str] = [];
        if etid is not None {
            col_keys.append(_e_key(etid));
        }
        if ntid is not None {
            col_keys.append(_n_key(ntid));
        }
        for src_lid in current_lids {
            bucket = self.buckets.get(src_lid);
            if bucket is None {
                continue;
            }
            if not col_keys {
                for (_, col) in bucket.items() {
                    if direction in (2, 3) {
                        for tgt in col[1] {
                            next_lids.add(tgt);
                        }
                    }
                    if direction in (1, 3) {
                        for src in col[0] {
                            next_lids.add(src);
                        }
                    }
                }
                continue;
            }
            candidates_out: (set[int] | None) = None;
            candidates_in: (set[int] | None) = None;
            for ck in col_keys {
                col = bucket.get(ck);
                if col is None {
                    candidates_out = set();
                    candidates_in = set();
                    break;
                }
                co: set[int] = set(col[1]);
                ci: set[int] = set(col[0]);
                candidates_out = co if candidates_out is None else candidates_out & co;
                candidates_in = ci if candidates_in is None else candidates_in & ci;
            }
            if direction in (2, 3) and candidates_out is not None {
                for tgt in candidates_out {
                    next_lids.add(tgt);
                }
            }
            if direction in (1, 3) and candidates_in is not None {
                for src in candidates_in {
                    next_lids.add(src);
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

"""Single-hop ordered resolution for the slice-pushdown fast path.

The buckets index is set-keyed (fast type membership but order-lossy), so we
walk the canonical adj_list (which preserves edge insertion order) and gate
each triple by:
  * source lid in `origin_lids`
  * edge type id matches `edge_type` (with the special wildcard when None)
  * target node type id matches `node_type` via MRO fan-out (or wildcard)
  * direction: 1=IN (consider when target is the origin), 2=OUT (source is
    the origin), 3=ANY

The buckets membership lookup gives us the type-filtered "pass-set" — the
adj_list walk recovers the order. We dedupe (a single neighbor may have
multiple parallel edges), apply the slice, and return."""
impl TopologyIndex.resolve_chain_ordered(
    origin_ids: set[UUID],
    edge_type: (str | None),
    node_type: (str | None),
    direction: int,
    slc: slice
) -> list[UUID] {
    origin_lids: set[int] = set();
    for uid in origin_ids {
        lid = self.node_to_lid.get(uid);
        if lid is not None {
            origin_lids.add(lid);
        }
    }
    if not origin_lids {
        return [];
    }

    etid: (int | None) = self.type_to_id.get(edge_type) if edge_type else None;
    if edge_type and etid is None {
        # Edge type referenced doesn't exist in the index — empty result.
        return [];
    }
    ntid: (int | None) = self.type_to_id.get(node_type) if node_type else None;
    if node_type and ntid is None {
        return [];
    }

    # Build the type-filtered candidate sets per origin lid using buckets.
    # `cand_pairs` collects (src_lid, allowed_target_lids) so the adj_list walk
    # can quickly check membership without re-running MRO logic per edge.
    out_allowed: dict[int, set[int]] = {};
    in_allowed: dict[int, set[int]] = {};
    want_out = direction in (2, 3);
    want_in = direction in (1, 3);
    for src_lid in origin_lids {
        bucket = self.buckets.get(src_lid);
        if bucket is None {
            continue;
        }
        col_keys: list[str] = [];
        if etid is not None {
            col_keys.append(_e_key(etid));
        }
        if ntid is not None {
            col_keys.append(_n_key(ntid));
        }
        if not col_keys {
            # Wildcard: union all columns for this src.
            out_set: set[int] = set();
            in_set: set[int] = set();
            for (_, col) in bucket.items() {
                if want_out {
                    out_set |= col[1];
                }
                if want_in {
                    in_set |= col[0];
                }
            }
            if want_out and out_set {
                out_allowed[src_lid] = out_set;
            }
            if want_in and in_set {
                in_allowed[src_lid] = in_set;
            }
            continue;
        }
        cand_out: (set[int] | None) = None;
        cand_in: (set[int] | None) = None;
        for ck in col_keys {
            col = bucket.get(ck);
            if col is None {
                cand_out = set();
                cand_in = set();
                break;
            }
            cand_out = set(col[1]) if cand_out is None else cand_out & col[1];
            cand_in = set(col[0]) if cand_in is None else cand_in & col[0];
        }
        if want_out and cand_out {
            out_allowed[src_lid] = cand_out;
        }
        if want_in and cand_in {
            in_allowed[src_lid] = cand_in;
        }
    }

    if not out_allowed and not in_allowed {
        return [];
    }

    # Walk adj_list in insertion order; collect ordered target UUIDs that
    # pass the per-origin allow-sets. Dedupe across parallel edges.
    ordered: list[UUID] = [];
    seen: set[int] = set();
    for (s, _et, t) in self.adj_list {
        # OUT: origin is the source, target is the neighbor.
        if want_out and s in out_allowed and t in out_allowed[s] {
            if t not in seen {
                seen.add(t);
                ordered.append(self.node_table[t][0]);
            }
            continue;
        }
        # IN: origin is the target, source is the neighbor.
        if want_in and t in in_allowed and s in in_allowed[t] {
            if s not in seen {
                seen.add(s);
                ordered.append(self.node_table[s][0]);
            }
        }
    }

    return ordered[slc];
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
    # Pass 3: edges. Replay through the fan-out helper (skipping the public
    # add_edge so we don't re-resolve UUIDs back to lids).
    for _ in range(num_edges) {
        unpacked = struct.unpack_from("<HHH", data, offset);
        src: int = int(unpacked[0]);
        etid: int = int(unpacked[1]);
        tgt: int = int(unpacked[2]);
        offset += 6;
        idx.adj_list.append((src, etid, tgt));
        (_, src_t, _) = idx.node_table[src];
        (_, tgt_t, _) = idx.node_table[tgt];
        src_ancestors = idx.type_mro_ids[src_t] or [src_t];
        tgt_ancestors = idx.type_mro_ids[tgt_t] or [tgt_t];
        for anc in tgt_ancestors {
            out_col = _get_col(idx.buckets, src, _n_key(anc));
            out_col[1].add(tgt);
        }
        e_out = _get_col(idx.buckets, src, _e_key(etid));
        e_out[1].add(tgt);
        for anc in src_ancestors {
            in_col = _get_col(idx.buckets, tgt, _n_key(anc));
            in_col[0].add(src);
        }
        e_in = _get_col(idx.buckets, tgt, _e_key(etid));
        e_in[0].add(src);
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
