"""SAM (Sparse Adjacency Matrix) and GTI (Graph Topology Index) implementations."""

import os;
import from collections { defaultdict }
import from pathlib { Path }
import from pickle { loads }
import from uuid { UUID }

# ---------------------------------------------------------------------------
# Qualified-name helper
# ---------------------------------------------------------------------------
impl _qname(arch: object) -> str {
    import sys;
    t = type(arch);
    mod_name: str = str(getattr(t, '__module__', '') or '');
    name: str = str(getattr(t, '__name__', '') or '');
    # Resolve via __file__ to get a stable entry-point-relative stem,
    # matching the MTIR scope format (_get_scope_str uses Path(mod_path).stem).
    # This strips synthetic test-package prefixes like _jac_test_pkg_XX.
    mod = sys.modules.get(mod_name);
    if mod is not None {
        mod_file: str = str(getattr(mod, '__file__', '') or '');
        if mod_file {
            stem = Path(mod_file).stem;
            for suffix in ['.impl', '.cl', '.sv'] {
                if stem.endswith(suffix) {
                    stem = stem[:-len(suffix)];
                    break;
                }
            }
            return stem + '.' + name;
        }
    }
    # Fallback: last dotted component of module name
    return (mod_name.rsplit('.', 1)[-1] if '.' in mod_name else mod_name) + '.' + name;
}

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
    import sys;
    result = [];
    for cls in type(instance).__mro__ {
        mod_name: str = str(getattr(cls, '__module__', '') or '');
        if mod_name.startswith('jaclang')
        or mod_name.startswith('builtins')
        or cls.__name__ == 'object' {
            break;
        }
        cls_name: str = str(getattr(cls, '__name__', '') or '');
        # Resolve via __file__ to match _qname key format
        mod = sys.modules.get(mod_name);
        if mod is not None {
            mod_file: str = str(getattr(mod, '__file__', '') or '');
            if mod_file {
                stem = Path(mod_file).stem;
                for suffix in ['.impl', '.cl', '.sv'] {
                    if stem.endswith(suffix) {
                        stem = stem[:-len(suffix)];
                        break;
                    }
                }
                result.append(stem + '.' + cls_name);
                continue;
            }
        }
        local_mod = mod_name.rsplit('.', 1)[-1] if '.' in mod_name else mod_name;
        result.append(local_mod + '.' + cls_name);
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
        # Edge-type columns: "e:EdgeType" for each MRO ancestor (mirrors node fan-out).
        # Fall back to _qname when edge is jaclang-internal (e.g. GenericEdge) and
        # get_type_mro returns [] due to the jaclang module guard.
        e_type_keys = get_type_mro(edge_arch) or [_qname(edge_arch)];
        for edge_type_name in e_type_keys {
            edge_col = 'e:' + edge_type_name;
            if tgt_str not in bucket[edge_col] {
                bucket[edge_col].append(tgt_str);
            }
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
    target_type = _qname(target.archetype);
    root_id = str(target.root) if target.root else None;

    # node_topology: upsert target node under all MRO types
    for t in get_type_mro(target.archetype) {
        sqlite.__conn__.execute(
            'INSERT OR IGNORE INTO node_topology (node_id, node_type, root_id) '
            'VALUES (?, ?, ?)',
            (str(target.id), t, root_id)
        );
    }

    # edge_topology: one row per MRO ancestor of the edge (mirrors node fan-out).
    # Fall back to _qname for jaclang-internal edges (e.g. GenericEdge).
    e_type_keys = get_type_mro(eanch.archetype) or [_qname(eanch.archetype)];
    for e_type in e_type_keys {
        sqlite.__conn__.execute(
            'INSERT OR IGNORE INTO edge_topology '
            '(edge_id, source_id, target_id, edge_type, target_type) '
            'VALUES (?, ?, ?, ?, ?)',
            (str(eanch.id), str(source.id), str(target.id), e_type, target_type)
        );
    }
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
        node_type_map[node_id_str] = _qname(anchor.archetype);
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
        source_id_str = str(anchor.source.id);
        target_id_str = str(anchor.target.id);
        target_type = node_type_map.get(target_id_str);
        if target_type is None {
            continue;
        }
        for e_type in (get_type_mro(anchor.archetype) or [_qname(anchor.archetype)]) {
            conn.execute(
                'INSERT OR IGNORE INTO edge_topology '
                '(edge_id, source_id, target_id, edge_type, target_type) '
                'VALUES (?, ?, ?, ?, ?)',
                (str(anchor.id), source_id_str, target_id_str, e_type, target_type)
            );
        }
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

# ---------------------------------------------------------------------------
# Scale backend globals + implementations
# ---------------------------------------------------------------------------
glob _TOPO_PREFIX: str = 'jac:topo',
     _TOPO_INVALIDATE_CHANNEL: str = 'jac:topo:invalidate';

impl _get_scale_topo(mem: object) -> (tuple | None) {
    try {
        import from jac_scale.memory_hierarchy {
            ScaleTieredMemory,
            RedisBackend,
            MongoBackend
        }
    } except ImportError {
        return None;
    }
    if not isinstance(mem, ScaleTieredMemory) {
        return None;
    }
    l2 = getattr(mem, 'l2', None);
    l3 = getattr(mem, 'l3', None);
    if (
        isinstance(l2, RedisBackend)
        and l2.redis_client is not None
        and isinstance(l3, MongoBackend)
        and l3.client is not None
    ) {
        return (l2.redis_client, l3);
    }
    return None;
}

impl _gti_write_edge_redis(
    redis_client: object, eanch: object, source: object, target: object
) -> None {
    src_str = str(source.id);
    tgt_str = str(target.id);
    pipe = redis_client.pipeline(transaction=False);
    for t in get_type_mro(target.archetype) {
        pipe.sadd(f"{_TOPO_PREFIX}:n:{src_str}:{t}", tgt_str);
    }
    for e_type in (get_type_mro(eanch.archetype) or [_qname(eanch.archetype)]) {
        pipe.sadd(f"{_TOPO_PREFIX}:e:{src_str}:{e_type}", tgt_str);
    }
    pipe.execute();
}

impl _gti_delete_edge_redis(
    redis_client: object,
    source_id: UUID,
    target_id: UUID,
    target_arch: object,
    edge_arch: object
) -> None {
    src_str = str(source_id);
    tgt_str = str(target_id);
    pipe = redis_client.pipeline(transaction=False);
    for t in get_type_mro(target_arch) {
        pipe.srem(f"{_TOPO_PREFIX}:n:{src_str}:{t}", tgt_str);
    }
    for e_type in (get_type_mro(edge_arch) or [_qname(edge_arch)]) {
        pipe.srem(f"{_TOPO_PREFIX}:e:{src_str}:{e_type}", tgt_str);
    }
    pipe.execute();
}

impl _gti_delete_node_redis(redis_client: object, node_id: UUID) -> None {
    node_str = str(node_id);
    for pattern in [
        f"{_TOPO_PREFIX}:n:{node_str}:*",
        f"{_TOPO_PREFIX}:e:{node_str}:*"
    ] {
        cursor = 0;
        while True {
            (cursor, keys) = redis_client.scan(cursor, match=pattern, count=100);
            if keys {
                redis_client.delete(*keys);
            }
            if cursor == 0 {
                break;
            }
        }
    }
}

impl gti_query_targets_redis(
    redis_client: object,
    source_id: UUID,
    edge_type: (str | None),
    target_type: (str | None)
) -> (list[str] | None) {
    src_str = str(source_id);
    try {
        if target_type and edge_type {
            n_key = f"{_TOPO_PREFIX}:n:{src_str}:{target_type}";
            e_key = f"{_TOPO_PREFIX}:e:{src_str}:{edge_type}";
            raw = redis_client.sinter(n_key, e_key);
        } elif target_type {
            raw = redis_client.smembers(f"{_TOPO_PREFIX}:n:{src_str}:{target_type}");
        } elif edge_type {
            raw = redis_client.smembers(f"{_TOPO_PREFIX}:e:{src_str}:{edge_type}");
        } else {
            return None;
        }
        _stats['gti_hits'] += 1;
        return [b.decode() if isinstance(b, bytes) else b for b in raw];
    } except Exception {
        _stats['gti_misses'] += 1;
        return None;
    }
}

impl sam_broadcast_invalidate(redis_client: object, source_id: UUID) -> None {
    try {
        redis_client.publish(_TOPO_INVALIDATE_CHANNEL, str(source_id));
    } except Exception {
    # Fire-and-forget — don't fail the write path on pub/sub error.
    }
}

impl rebuild_gti_redis(redis_client: object, mongo_backend: object) -> int {
    import from jaclang.jac0core.archetype { EdgeAnchor, NodeAnchor }

    node_type_map: dict[str, list[str]] = {};
    for anchor in mongo_backend.query() {
        if isinstance(anchor, NodeAnchor) and anchor.is_populated() {
            node_type_map[str(anchor.id)] = get_type_mro(anchor.archetype);
        }
    }

    pipe = redis_client.pipeline(transaction=False);
    count = 0;
    for anchor in mongo_backend.query() {
        if not (isinstance(anchor, EdgeAnchor) and anchor.is_populated()) {
            continue;
        }
        if not (anchor.source and anchor.target) {
            continue;
        }
        src_str = str(anchor.source.id);
        tgt_str = str(anchor.target.id);
        for t in node_type_map.get(tgt_str, []) {
            pipe.sadd(f"{_TOPO_PREFIX}:n:{src_str}:{t}", tgt_str);
        }
        for e_type in (get_type_mro(anchor.archetype) or [_qname(anchor.archetype)]) {
            pipe.sadd(f"{_TOPO_PREFIX}:e:{src_str}:{e_type}", tgt_str);
        }
        count += 1;
    }
    pipe.execute();
    return count;
}

impl rebuild_topology_index_scale(mem: object) -> dict[str, str] {
    scale = _get_scale_topo(mem);
    if scale is None {
        return {'gti': 'skipped (scale backends not active)', 'sam': 'skipped'};
    }
    (redis_client, mongo_backend) = scale;
    count = rebuild_gti_redis(redis_client, mongo_backend);
    sam_clear();
    return {'gti': f'rebuilt ({count} edges)', 'sam': 'cleared'};
}
