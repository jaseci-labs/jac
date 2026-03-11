"""SAM (Sparse Adjacency Matrix) and GTI (Graph Topology Index) implementations."""

import os;
import from collections { defaultdict }
import from pickle { loads }
import from uuid { UUID }

# ---------------------------------------------------------------------------
# Lock helper
# ---------------------------------------------------------------------------
impl _get_lock(source_id: str) -> Lock {
    with _locks_mu {
        if source_id not in _locks {
            _locks[source_id] = Lock();
        }
        return _locks[source_id];
    }
}

# ---------------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------------
impl reset_stats -> None {
    for k in _stats {
        _stats[k] = 0;
    }
}

# ---------------------------------------------------------------------------
# MRO helper
# ---------------------------------------------------------------------------
impl get_type_mro(instance: object) -> list[str] {
    result = [];
    for cls in type(instance).__mro__ {
        mod = getattr(cls, '__module__', '') or '';
        if mod.startswith('jaclang') or cls.__name__ == 'object' {
            break;
        }
        result.append(cls.__name__);
    }
    return result;
}

# ---------------------------------------------------------------------------
# SAM operations
# ---------------------------------------------------------------------------
impl sam_put(
    source_id: UUID, target_id: UUID, target_arch: object, edge_arch: object
) -> None {
    src_str = str(source_id);
    tgt_str = str(target_id);
    lock = _get_lock(src_str);
    with lock {
        bucket = sam_index[src_str];
        # Node-type columns: "n:TypeName" for each MRO ancestor
        for type_name in get_type_mro(target_arch) {
            col = 'n:' + type_name;
            if tgt_str not in bucket[col] {
                bucket[col].append(tgt_str);
            }
        }
        # Edge-type column: "e:EdgeType" (no MRO — edges have no inheritance)
        edge_col = 'e:' + type(edge_arch).__name__;
        if tgt_str not in bucket[edge_col] {
            bucket[edge_col].append(tgt_str);
        }
    }
}

impl sam_invalidate(source_id: UUID) -> None {
    src_str = str(source_id);
    lock = _get_lock(src_str);
    with lock {
        sam_index.pop(src_str, None);
    }
}

impl sam_query(source_id: UUID, key: str) -> (list[str] | None) {
    src_str = str(source_id);
    bucket = sam_index.get(src_str);
    if bucket is None {
        _stats['sam_misses'] += 1;
        return None;
    }
    result = bucket.get(key);
    if result is None {
        # Bucket exists but this column was never populated — treat as a miss
        # so the caller falls back to GTI rather than returning an empty result.
        _stats['sam_misses'] += 1;
        return None;
    }
    _stats['sam_hits'] += 1;
    return result;
}

impl sam_populate_from_gti(source_id: UUID, gt_rows: list[tuple[str, str]]) -> None {
    src_str = str(source_id);
    lock = _get_lock(src_str);
    with lock {
        bucket = sam_index[src_str];
        for (tgt_id, col_key) in gt_rows {
            if tgt_id not in bucket[col_key] {
                bucket[col_key].append(tgt_id);
            }
        }
    }
}

impl sam_clear -> None {
    with _locks_mu {
        sam_index.clear();
        _locks.clear();
    }
}

# ---------------------------------------------------------------------------
# GTI helper: resolve SqliteMemory from any mem object
# ---------------------------------------------------------------------------
impl _get_sqlite(mem: object) -> (object | None) {
    import from jaclang.runtimelib.memory { SqliteMemory }
    if isinstance(mem, SqliteMemory) {
        return mem;
    }
    l3 = getattr(mem, 'l3', None);
    if isinstance(l3, SqliteMemory) {
        return l3;
    }
    return None;
}

# ---------------------------------------------------------------------------
# GTI write/delete hooks
# ---------------------------------------------------------------------------
impl _gti_write_edge(
    mem: object, eanch: object, source: object, target: object
) -> None {
    sqlite = _get_sqlite(mem);
    if sqlite is None {
        return;
    }
    sqlite._ensure_connection();
    if sqlite.__conn__ is None {
        return;
    }
    edge_type = type(eanch.archetype).__name__;
    target_type = type(target.archetype).__name__;
    root_id = str(target.root) if target.root else None;

    # node_topology: upsert target node under all MRO types
    for t in get_type_mro(target.archetype) {
        sqlite.__conn__.execute(
            'INSERT OR IGNORE INTO node_topology (node_id, node_type, root_id) '
            'VALUES (?, ?, ?)',
            (str(target.id), t, root_id)
        );
    }

    # edge_topology: one row per edge (directed: source -> target)
    sqlite.__conn__.execute(
        'INSERT OR REPLACE INTO edge_topology '
        '(edge_id, source_id, target_id, edge_type, target_type) '
        'VALUES (?, ?, ?, ?, ?)',
        (str(eanch.id), str(source.id), str(target.id), edge_type, target_type)
    );
    # Commit immediately to stay consistent with SqliteMemory.put() behavior
    sqlite.__conn__.commit();
}

impl _gti_delete_edge(mem: object, edge_id: UUID) -> None {
    sqlite = _get_sqlite(mem);
    if sqlite is None {
        return;
    }
    sqlite._ensure_connection();
    if sqlite.__conn__ is None {
        return;
    }
    sqlite.__conn__.execute(
        'DELETE FROM edge_topology WHERE edge_id = ?', (str(edge_id), )
    );
    sqlite.__conn__.commit();
}

impl _gti_delete_node(mem: object, node_id: UUID) -> None {
    sqlite = _get_sqlite(mem);
    if sqlite is None {
        return;
    }
    sqlite._ensure_connection();
    if sqlite.__conn__ is None {
        return;
    }
    node_id_str = str(node_id);
    sqlite.__conn__.execute(
        'DELETE FROM node_topology WHERE node_id = ?', (node_id_str, )
    );
    sqlite.__conn__.execute(
        'DELETE FROM edge_topology WHERE source_id = ? OR target_id = ?',
        (node_id_str, node_id_str)
    );
    sqlite.__conn__.commit();
}

# ---------------------------------------------------------------------------
# GTI query
# ---------------------------------------------------------------------------
impl gti_query_targets(
    mem: object, source_id: UUID, edge_type: (str | None), target_type: (str | None)
) -> (list[str] | None) {
    sqlite = _get_sqlite(mem);
    if sqlite is None {
        _stats['gti_misses'] += 1;
        return None;
    }
    if sqlite.__conn__ is None and not os.path.exists(sqlite.path) {
        _stats['gti_misses'] += 1;
        return None;
    }
    if sqlite.__conn__ is None {
        sqlite._ensure_connection();
    }

    params: list[object] = [str(source_id)];

    if target_type {
        # Join with node_topology to support MRO-based type queries
        # (e.g. querying 'BaseContent' returns PostNode + CommentNode targets)
        where = ['et.source_id = ?', 'nt.node_type = ?'];
        params.append(target_type);
        if edge_type {
            where.append('et.edge_type = ?');
            params.append(edge_type);
        }
        sql = (
            'SELECT DISTINCT et.target_id '
            'FROM edge_topology et '
            'JOIN node_topology nt ON et.target_id = nt.node_id '
            'WHERE ' + ' AND '.join(where)
        );
    } else {
        where = ['source_id = ?'];
        if edge_type {
            where.append('edge_type = ?');
            params.append(edge_type);
        }
        sql = 'SELECT target_id FROM edge_topology WHERE ' + ' AND '.join(where);
    }

    try {
        cur = sqlite.__conn__.execute(sql, params);
        rows = [row[0] for row in cur.fetchall()];
        _stats['gti_hits'] += 1;
        return rows;
    } except Exception {
        _stats['gti_misses'] += 1;
        return None;
    }
}

# ---------------------------------------------------------------------------
# GTI rebuild from anchor store
# ---------------------------------------------------------------------------
impl rebuild_gti(mem: object) -> None {
    import from jaclang.jac0core.archetype { EdgeAnchor, NodeAnchor }
    sqlite = _get_sqlite(mem);
    if sqlite is None {
        return;
    }
    sqlite._ensure_connection();
    conn = sqlite.__conn__;

    # Pass 1: NodeAnchors -> node_topology + id->type map
    node_type_map: dict[str, str] = {};

    cur = conn.execute('SELECT data FROM anchors');
    rows = cur.fetchall();

    for (blob, ) in rows {
        try {
            anchor = loads(blob);
        } except Exception {
            continue;
        }
        if not isinstance(anchor, NodeAnchor) or not anchor.is_populated() {
            continue;
        }
        root_id = str(anchor.root) if anchor.root else None;
        node_id_str = str(anchor.id);
        node_type_map[node_id_str] = type(anchor.archetype).__name__;
        for t in get_type_mro(anchor.archetype) {
            conn.execute(
                'INSERT OR IGNORE INTO node_topology (node_id, node_type, root_id) '
                'VALUES (?, ?, ?)',
                (node_id_str, t, root_id)
            );
        }
    }

    # Pass 2: EdgeAnchors -> edge_topology
    for (blob, ) in rows {
        try {
            anchor = loads(blob);
        } except Exception {
            continue;
        }
        if not isinstance(anchor, EdgeAnchor) or not anchor.is_populated() {
            continue;
        }
        edge_type = type(anchor.archetype).__name__;
        source_id_str = str(anchor.source.id);
        target_id_str = str(anchor.target.id);
        target_type = node_type_map.get(target_id_str);
        if target_type is None {
            continue;
        }
        conn.execute(
            'INSERT OR REPLACE INTO edge_topology '
            '(edge_id, source_id, target_id, edge_type, target_type) '
            'VALUES (?, ?, ?, ?, ?)',
            (str(anchor.id), source_id_str, target_id_str, edge_type, target_type)
        );
    }

    conn.commit();
}

# ---------------------------------------------------------------------------
# Public rebuild API
# ---------------------------------------------------------------------------
impl rebuild_topology_index(mem: object) -> dict[str, str] {
    sam_clear();
    rebuild_gti(mem);

    sqlite = _get_sqlite(mem);
    if sqlite is None or sqlite.__conn__ is None {
        return {'gti': 'rebuilt', 'sam': 'skipped (no sqlite)'};
    }

    cur = sqlite.__conn__.execute(
        'SELECT source_id, target_id, edge_type, target_type FROM edge_topology'
    );
    count = 0;
    for (src, tgt, etype, ttype) in cur.fetchall() {
        bucket = sam_index[src];
        # Node-type column
        n_col = 'n:' + ttype;
        if tgt not in bucket[n_col] {
            bucket[n_col].append(tgt);
        }
        # Edge-type column
        e_col = 'e:' + etype;
        if tgt not in bucket[e_col] {
            bucket[e_col].append(tgt);
        }
        count += 1;
    }

    return {'gti': 'rebuilt', 'sam': f'warmed ({count} edges)'};
}
