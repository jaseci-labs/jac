"""AM index and GT topology helper implementations."""

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

impl get_type_mro(obj: object) -> list[str] {
    result = [];
    for cls in type(obj).__mro__ {
        mod = getattr(cls, '__module__', '') or '';
        if mod.startswith('jaclang') or cls.__name__ == 'object' {
            break;
        }
        result.append(cls.__name__);
    }
    return result;
}

# ---------------------------------------------------------------------------
# AM operations
# ---------------------------------------------------------------------------

impl am_put(source_id: UUID, target_id: UUID, target_arch: object) -> None {
    src_str = str(source_id);
    tgt_str = str(target_id);
    lock = _get_lock(src_str);
    with lock {
        bucket = am_index[src_str];
        for type_name in get_type_mro(target_arch) {
            if tgt_str not in bucket[type_name] {
                bucket[type_name].append(tgt_str);
            }
        }
    }
}

impl am_invalidate(source_id: UUID) -> None {
    src_str = str(source_id);
    lock = _get_lock(src_str);
    with lock {
        am_index.pop(src_str, None);
    }
}

impl am_query(source_id: UUID, target_type: str) -> (list[str] | None) {
    src_str = str(source_id);
    bucket = am_index.get(src_str);
    if bucket is None {
        _stats['am_misses'] += 1;
        return None;
    }
    _stats['am_hits'] += 1;
    return bucket.get(target_type, []);
}

impl am_populate_from_gt(source_id: UUID, gt_rows: list[tuple[str, str]]) -> None {
    src_str = str(source_id);
    lock = _get_lock(src_str);
    with lock {
        bucket = am_index[src_str];
        for (tgt_id, tgt_type) in gt_rows {
            if tgt_id not in bucket[tgt_type] {
                bucket[tgt_type].append(tgt_id);
            }
        }
    }
}

impl am_clear -> None {
    with _locks_mu {
        am_index.clear();
        _locks.clear();
    }
}

# ---------------------------------------------------------------------------
# GT helper: resolve SqliteMemory from any mem object
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
# GT write/delete hooks
# ---------------------------------------------------------------------------

impl _gt_write_edge(
    mem: object, eanch: object, source: object, target: object
) -> None {
    sqlite = _get_sqlite(mem);
    if sqlite is None or sqlite.__conn__ is None {
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

impl _gt_delete_edge(mem: object, edge_id: UUID) -> None {
    sqlite = _get_sqlite(mem);
    if sqlite is None or sqlite.__conn__ is None {
        return;
    }
    sqlite.__conn__.execute(
        'DELETE FROM edge_topology WHERE edge_id = ?', (str(edge_id),)
    );
    sqlite.__conn__.commit();
}

# ---------------------------------------------------------------------------
# GT query
# ---------------------------------------------------------------------------

impl gt_query_targets(
    mem: object,
    source_id: UUID,
    edge_type: (str | None),
    target_type: (str | None)
) -> (list[str] | None) {
    sqlite = _get_sqlite(mem);
    if sqlite is None {
        _stats['gt_misses'] += 1;
        return None;
    }
    if sqlite.__conn__ is None and not os.path.exists(sqlite.path) {
        _stats['gt_misses'] += 1;
        return None;
    }
    if sqlite.__conn__ is None {
        sqlite._ensure_connection();
    }

    params: list[object] = [str(source_id)];
    where = ['source_id = ?'];
    if edge_type {
        where.append('edge_type = ?');
        params.append(edge_type);
    }
    if target_type {
        where.append('target_type = ?');
        params.append(target_type);
    }

    sql = 'SELECT target_id FROM edge_topology WHERE ' + ' AND '.join(where);
    try {
        cur = sqlite.__conn__.execute(sql, params);
        rows = [row[0] for row in cur.fetchall()];
        _stats['gt_hits'] += 1;
        return rows;
    } except Exception {
        _stats['gt_misses'] += 1;
        return None;
    }
}

# ---------------------------------------------------------------------------
# GT rebuild from anchor store
# ---------------------------------------------------------------------------

impl rebuild_gt(mem: object) -> None {
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

    for (blob,) in rows {
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
    for (blob,) in rows {
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
    am_clear();
    rebuild_gt(mem);

    sqlite = _get_sqlite(mem);
    if sqlite is None or sqlite.__conn__ is None {
        return {'gt': 'rebuilt', 'am': 'skipped (no sqlite)'};
    }

    cur = sqlite.__conn__.execute(
        'SELECT source_id, target_id, target_type FROM edge_topology'
    );
    count = 0;
    for (src, tgt, ttype) in cur.fetchall() {
        bucket = am_index[src];
        if tgt not in bucket[ttype] {
            bucket[ttype].append(tgt);
        }
        count += 1;
    }

    return {'gt': 'rebuilt', 'am': f'warmed ({count} edges)'};
}
