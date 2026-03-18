"""SAM TopologyIndex implementation."""

import from pickle { dumps, loads }

"""Add an edge with MRO fan-out. O(M) where M = len(target_mro)."""
impl TopologyIndex.add_edge(
    source_id: UUID, target_id: UUID,
    target_mro: list[str], edge_type: str
) -> None {
    src = str(source_id);
    tgt = str(target_id);
    bucket = self.sam.get(src);
    if bucket is None {
        bucket = {};
        self.sam[src] = bucket;
    }
    # Index under each MRO type name
    for t in target_mro {
        key = "n:" + t;
        col = bucket.get(key);
        if col is None {
            col = [];
            bucket[key] = col;
        }
        if tgt not in col {
            col.append(tgt);
        }
    }
    # Index under edge type
    ekey = "e:" + edge_type;
    col = bucket.get(ekey);
    if col is None {
        col = [];
        bucket[ekey] = col;
    }
    if tgt not in col {
        col.append(tgt);
    }
}

"""Remove all index entries for a target from a source (coarse invalidation)."""
impl TopologyIndex.remove_edge(source_id: UUID, target_id: UUID) -> None {
    src = str(source_id);
    tgt = str(target_id);
    bucket = self.sam.get(src);
    if bucket is None {
        return;
    }
    empty_keys: list[str] = [];
    for (key, col) in bucket.items() {
        if tgt in col {
            col.remove(tgt);
        }
        if not col {
            empty_keys.append(key);
        }
    }
    for key in empty_keys {
        del bucket[key];
    }
}

"""Remove a node — drop its bucket and remove from all other buckets."""
impl TopologyIndex.remove_node(node_id: UUID) -> None {
    nid = str(node_id);
    # Drop outgoing bucket
    self.sam.pop(nid, None);
    self.node_owners.pop(nid, None);
    # Remove from all incoming references
    for (src, bucket) in list(self.sam.items()) {
        empty_keys: list[str] = [];
        for (key, col) in bucket.items() {
            if nid in col {
                col.remove(nid);
            }
            if not col {
                empty_keys.append(key);
            }
        }
        for key in empty_keys {
            del bucket[key];
        }
    }
}

"""Query targets from a source by node type and/or edge type. O(1) per lookup."""
impl TopologyIndex.query_targets(
    source_id: UUID, node_type: (str | None) = None,
    edge_type: (str | None) = None
) -> set[UUID] {
    src = str(source_id);
    bucket = self.sam.get(src);
    if bucket is None {
        return set();
    }
    n_col: (list[str] | None) = None;
    e_col: (list[str] | None) = None;
    if node_type is not None {
        n_col = bucket.get("n:" + node_type);
        if n_col is None {
            return set();
        }
    }
    if edge_type is not None {
        e_col = bucket.get("e:" + edge_type);
        if e_col is None {
            return set();
        }
    }
    if n_col is not None and e_col is not None {
        # Intersect
        e_set = set(e_col);
        return {UUID(s) for s in n_col if s in e_set};
    }
    if n_col is not None {
        return {UUID(s) for s in n_col};
    }
    if e_col is not None {
        return {UUID(s) for s in e_col};
    }
    # No filter — return all targets across all columns (deduplicated)
    all_ids: set[str] = set();
    for col in bucket.values() {
        for s in col { all_ids.add(s); }
    }
    return {UUID(s) for s in all_ids};
}

"""Resolve a multi-hop chain. Each hop uses O(1) SAM lookup."""
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

"""Number of source nodes with index entries."""
impl TopologyIndex.__len__ -> int {
    return len(self.sam);
}

"""String representation."""
impl TopologyIndex.__repr__ -> str {
    total_entries = sum(
        sum(len(col) for col in bucket.values())
        for bucket in self.sam.values()
    );
    return f"TopologyIndex(sources={len(self.sam)}, entries={total_entries})";
}
