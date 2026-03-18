"""SAM TopologyIndex implementation."""

import from pickle { dumps, loads }

"""Helper: get or create a column (tuple of (in, out) lists) in a bucket."""
can _get_col(bucket: dict[str, tuple[list[str], list[str]]], key: str) -> tuple[list[str], list[str]] {
    col = bucket.get(key);
    if col is None {
        col = ([], []);
        bucket[key] = col;
    }
    return col;
}

"""Add an edge with MRO fan-out, populating both forward and reverse entries."""
impl TopologyIndex.add_edge(
    source_id: UUID, target_id: UUID,
    target_mro: list[str], edge_type: str,
    source_mro: list[str] = []
) -> None {
    src = str(source_id);
    tgt = str(target_id);

    # --- source bucket: outgoing (index 1) under target types ---
    src_bucket = self.sam.get(src);
    if src_bucket is None {
        src_bucket = {};
        self.sam[src] = src_bucket;
    }
    for t in target_mro {
        col = _get_col(src_bucket, "n:" + t);
        if tgt not in col[1] {
            col[1].append(tgt);
        }
    }
    ecol = _get_col(src_bucket, "e:" + edge_type);
    if tgt not in ecol[1] {
        ecol[1].append(tgt);
    }

    # --- target bucket: incoming (index 0) under source types ---
    tgt_bucket = self.sam.get(tgt);
    if tgt_bucket is None {
        tgt_bucket = {};
        self.sam[tgt] = tgt_bucket;
    }
    for t in source_mro {
        col = _get_col(tgt_bucket, "n:" + t);
        if src not in col[0] {
            col[0].append(src);
        }
    }
    ecol = _get_col(tgt_bucket, "e:" + edge_type);
    if src not in ecol[0] {
        ecol[0].append(src);
    }
}

"""Remove all index entries for an edge between source and target."""
impl TopologyIndex.remove_edge(source_id: UUID, target_id: UUID) -> None {
    src = str(source_id);
    tgt = str(target_id);

    # Remove target from source's OUT lists
    src_bucket = self.sam.get(src);
    if src_bucket is not None {
        empty_keys: list[str] = [];
        for (key, col) in src_bucket.items() {
            if tgt in col[1] {
                col[1].remove(tgt);
            }
            if not col[0] and not col[1] {
                empty_keys.append(key);
            }
        }
        for key in empty_keys {
            del src_bucket[key];
        }
    }

    # Remove source from target's IN lists
    tgt_bucket = self.sam.get(tgt);
    if tgt_bucket is not None {
        empty_keys: list[str] = [];
        for (key, col) in tgt_bucket.items() {
            if src in col[0] {
                col[0].remove(src);
            }
            if not col[0] and not col[1] {
                empty_keys.append(key);
            }
        }
        for key in empty_keys {
            del tgt_bucket[key];
        }
    }
}

"""Remove a node — drop its bucket and remove from all other buckets."""
impl TopologyIndex.remove_node(node_id: UUID) -> None {
    nid = str(node_id);
    # Drop own bucket
    self.sam.pop(nid, None);
    self.node_owners.pop(nid, None);
    # Remove from all other buckets (both IN and OUT lists)
    for (_, bucket) in list(self.sam.items()) {
        empty_keys: list[str] = [];
        for (key, col) in bucket.items() {
            if nid in col[0] {
                col[0].remove(nid);
            }
            if nid in col[1] {
                col[1].remove(nid);
            }
            if not col[0] and not col[1] {
                empty_keys.append(key);
            }
        }
        for key in empty_keys {
            del bucket[key];
        }
    }
}

"""Query outgoing targets from a source. O(1) per lookup."""
impl TopologyIndex.query_targets(
    source_id: UUID, node_type: (str | None) = None, edge_type: (str | None) = None
) -> set[UUID] {
    src = str(source_id);
    bucket = self.sam.get(src);
    if bucket is None {
        return set();
    }
    n_out: (list[str] | None) = None;
    e_out: (list[str] | None) = None;
    if node_type is not None {
        col = bucket.get("n:" + node_type);
        if col is None {
            return set();
        }
        n_out = col[1];
    }
    if edge_type is not None {
        col = bucket.get("e:" + edge_type);
        if col is None {
            return set();
        }
        e_out = col[1];
    }
    if n_out is not None and e_out is not None {
        e_set = set(e_out);
        return {UUID(s) for s in n_out if s in e_set};
    }
    if n_out is not None {
        return {UUID(s) for s in n_out};
    }
    if e_out is not None {
        return {UUID(s) for s in e_out};
    }
    # No filter — return all outgoing across all columns (deduplicated)
    all_ids: set[str] = set();
    for col in bucket.values() {
        for s in col[1] {
            all_ids.add(s);
        }
    }
    return {UUID(s) for s in all_ids};
}

"""Query incoming sources to a target. O(1) per lookup."""
impl TopologyIndex.query_sources(
    target_id: UUID, node_type: (str | None) = None, edge_type: (str | None) = None
) -> set[UUID] {
    tgt = str(target_id);
    bucket = self.sam.get(tgt);
    if bucket is None {
        return set();
    }
    n_in: (list[str] | None) = None;
    e_in: (list[str] | None) = None;
    if node_type is not None {
        col = bucket.get("n:" + node_type);
        if col is None {
            return set();
        }
        n_in = col[0];
    }
    if edge_type is not None {
        col = bucket.get("e:" + edge_type);
        if col is None {
            return set();
        }
        e_in = col[0];
    }
    if n_in is not None and e_in is not None {
        e_set = set(e_in);
        return {UUID(s) for s in n_in if s in e_set};
    }
    if n_in is not None {
        return {UUID(s) for s in n_in};
    }
    if e_in is not None {
        return {UUID(s) for s in e_in};
    }
    # No filter — return all incoming across all columns (deduplicated)
    all_ids: set[str] = set();
    for col in bucket.values() {
        for s in col[0] {
            all_ids.add(s);
        }
    }
    return {UUID(s) for s in all_ids};
}

"""Resolve a multi-hop chain. O(1) SAM lookup per hop per direction."""
impl TopologyIndex.resolve_chain(
    origin_ids: set[UUID], chain: list[tuple[(str | None), (str | None), int]]
) -> set[UUID] {
    current = origin_ids;
    if not current {
        return set();
    }
    for (edge_type, node_type, direction) in chain {
        next_ids: set[UUID] = set();
        # Direction: 2=OUT, 1=IN, 3=ANY
        if direction in (2, 3) {
            for oid in current {
                next_ids |= self.query_targets(oid, node_type, edge_type);
            }
        }
        if direction in (1, 3) {
            for oid in current {
                next_ids |= self.query_sources(oid, node_type, edge_type);
            }
        }
        current = next_ids;
        if not current {
            return set();
        }
    }
    return current;
}

"""Return cross-root node mapping."""
impl TopologyIndex.get_cross_root_ids(node_ids: set[UUID]) -> dict[UUID, set[UUID]] {
    result: dict[UUID, set[UUID]] = {};
    for uid in node_ids {
        owner = self.node_owners.get(str(uid));
        if owner is not None and owner != SELF_ROOT {
            result.setdefault(owner, set()).add(uid);
        }
    }
    return result;
}

"""Serialize SAM to bytes for persistence (only called during pickle)."""
impl TopologyIndex.encode -> bytes {
    return dumps({"sam": self.sam, "owners": self.node_owners, "v": TOPO_VERSION});
}

"""Deserialize SAM from bytes (only called after unpickle)."""
impl TopologyIndex.decode(data: bytes) -> TopologyIndex {
    idx = TopologyIndex();
    if not data {
        return idx;
    }
    try {
        d = loads(data);
        if isinstance(d, dict) and d.get("v") == TOPO_VERSION {
            idx.sam = d.get("sam", {});
            idx.node_owners = d.get("owners", {});
        }
    } except Exception {
        ;
    }
    return idx;
}

"""Number of nodes with index entries."""
impl TopologyIndex.__len__ -> int {
    return len(self.sam);
}

"""String representation."""
impl TopologyIndex.__repr__ -> str {
    total_entries = sum(
        sum(len(col[0]) + len(col[1]) for col in bucket.values()) for bucket in self.sam.values()
    );
    return f"TopologyIndex(nodes={len(self.sam)}, entries={total_entries})";
}
