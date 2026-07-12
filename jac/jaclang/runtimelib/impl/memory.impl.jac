import asyncio;
import json;
import logging;
import os;
import sqlite3;
import threading;
import from collections.abc { Callable, Generator, Iterable }
import from datetime { datetime, timezone }
import from typing { cast }
import from uuid { UUID }
import from jaclang.jac0core.archetype { Anchor, EdgeAnchor, NodeAnchor, Root }
import from jaclang.runtimelib.changeset {
    ApplyReport,
    ChangeSet,
    WriteIntent,
    derive_dirty_fields,
    snapshot_field_hashes
}
import from jaclang.runtimelib.exceptions { WriteConflict }
import from jaclang.runtimelib.serializer { Serializer }
import from jaclang.runtimelib.query_plan { QueryPlan }
import from jaclang.runtimelib.typecache { get_field_types }

glob logger = logging.getLogger(__name__),
     SQLITE_DB_FORMAT_VERSION: int = 1;

impl Memory.aget(id: UUID) -> (Anchor | None) {
    return await asyncio.to_thread(self.get, id);
}

impl Memory.aput(anchor: Anchor) -> None {
    await asyncio.to_thread(self.put, anchor);
}

impl Memory.adelete(id: UUID) -> None {
    await asyncio.to_thread(self.delete, id);
}

impl Memory.ahas(id: UUID) -> bool {
    return await asyncio.to_thread(self.`has, id);
}

impl Memory.acommit(anchor: (Anchor | None) = None) -> None {
    await asyncio.to_thread(self.commit, anchor);
}

impl Memory.capabilities -> set[str] {
    return set();
}

impl Memory.execute_plan(plan: QueryPlan) -> Generator[Anchor, None, None] {
    if self.capabilities() {
        logger.debug(
            f"{type(self).__name__} declares capabilities "
            f"{self.capabilities()} but did not override execute_plan; "
            "falling back to empty result"
        );
    }
    return;
    yield ;
}

def _anchor_to_row(anchor: Anchor) -> tuple {
    data = Serializer.serialize(anchor, include_type=True);
    data_json = json.dumps(data);
    anchor_type = type(anchor).__name__;
    arch_module: (str | None) = None;
    arch_type: (str | None) = None;
    fingerprint: (str | None) = None;
    if anchor.is_populated() and anchor.archetype is not None {
        arch = anchor.archetype;
        arch_module = type(arch).__module__;
        arch_type = type(arch).__name__;
        fp = type(arch)?.__jac_fingerprint__;
        fingerprint = fp if isinstance(fp, str) and fp else None;
    }
    return (
        anchor_type,
        arch_module,
        arch_type,
        fingerprint,
        data_json,
        SQLITE_DB_FORMAT_VERSION,
        datetime.now(timezone.utc).isoformat()
    );
}

def _is_new_schema(conn: sqlite3.Connection) -> bool {
    cursor = conn.execute("PRAGMA table_info(anchors)");
    cols = {row[1] for row in cursor.fetchall()};

    return 'fingerprint' in cols and 'format_version' in cols;
}

def _is_legacy_schema(conn: sqlite3.Connection) -> bool {
    cursor = conn.execute("PRAGMA table_info(anchors)");
    rows = cursor.fetchall();
    if not rows {
        return False;
    }
    cols = {row[1] for row in rows};
    return cols == {'id', 'data'};
}

def _create_new_schema(conn: sqlite3.Connection) {
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS anchors (
            id              TEXT PRIMARY KEY,
            type            TEXT NOT NULL,
            arch_module     TEXT,
            arch_type       TEXT,
            fingerprint     TEXT,
            data            TEXT NOT NULL,
            format_version  INTEGER NOT NULL DEFAULT 1,
            updated_at      TEXT
        )
        """
    );
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS anchors_quarantine (
            id                   TEXT PRIMARY KEY,
            type                 TEXT,
            arch_module          TEXT,
            arch_type            TEXT,
            fingerprint          TEXT,
            data                 TEXT,
            error                TEXT,
            quarantined_at       TEXT,
            from_format_version  INTEGER
        )
        """
    );
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS schema_meta (
            key   TEXT PRIMARY KEY,
            value TEXT
        )
        """
    );

    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS aliases (
            old_name    TEXT PRIMARY KEY,
            new_name    TEXT NOT NULL,
            created_at  TEXT
        )
        """
    );
    conn.execute(
        "INSERT OR REPLACE INTO schema_meta (key, value) VALUES (?, ?)",
        ('db_format_version', str(SQLITE_DB_FORMAT_VERSION))
    );
    conn.commit();
}


def _load_db_aliases(conn: sqlite3.Connection) -> int {
    import from jaclang.runtimelib.serializer { Serializer }
    cursor = conn.execute("SELECT old_name, new_name FROM aliases");
    count = 0;
    for (old_name, new_name) in cursor.fetchall() {
        if isinstance(old_name, str) and isinstance(new_name, str) {
            Serializer._aliases[old_name] = new_name;
            count += 1;
        }
    }
    return count;
}

def _quarantine(
    conn: sqlite3.Connection,
    id: str,
    anchor_type: (str | None),
    arch_module: (str | None),
    arch_type: (str | None),
    fingerprint: (str | None),
    data: (str | None),
    error: str,
    from_format_version: (int | None) = None,
    manage_txn: bool = True
) {
    try {
        now_ts = datetime.now(timezone.utc).isoformat();
        conn.execute(
            """
            INSERT OR REPLACE INTO anchors_quarantine
                (id, type, arch_module, arch_type, fingerprint, data,
                 error, quarantined_at, from_format_version)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                id,
                anchor_type,
                arch_module,
                arch_type,
                fingerprint,
                data,
                error,
                now_ts,
                from_format_version
            )
        );
        conn.execute("DELETE FROM anchors WHERE id = ?", (id, ));

        if anchor_type == 'NodeAnchor' {
            cursor = conn.execute(
                """
                SELECT id, type, arch_module, arch_type, fingerprint,
                       data, format_version
                FROM anchors
                WHERE type = 'EdgeAnchor'
                  AND (json_extract(data, '$.source') = ?
                       OR json_extract(data, '$.target') = ?)
                """,
                (id, id)
            );
            orphaned_edges = cursor.fetchall();
            if orphaned_edges {
                cascade_error = f"cascade quarantine: connected node {id} was quarantined";
                orphan_edge_ids: list[str] = [];
                try {
                    conn.execute("SAVEPOINT cascade_q");
                    for row in orphaned_edges {
                        (e_id, e_type, e_mod, e_atype, e_fp, e_data, e_fv) = row;
                        orphan_edge_ids.append(e_id);
                        conn.execute(
                            """
                            INSERT OR REPLACE INTO anchors_quarantine
                                (id, type, arch_module, arch_type, fingerprint, data,
                                 error, quarantined_at, from_format_version)
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                            """,
                            (
                                e_id,
                                e_type,
                                e_mod,
                                e_atype,
                                e_fp,
                                e_data,
                                cascade_error,
                                now_ts,
                                e_fv
                            )
                        );
                    }

                    placeholders = ','.join('?' * len(orphan_edge_ids));
                    conn.execute(
                        f"DELETE FROM anchors WHERE id IN ({placeholders})",
                        orphan_edge_ids
                    );

                    live_nodes = conn.execute(
                        f"""
                        SELECT id, data FROM anchors
                        WHERE type = 'NodeAnchor'
                          AND EXISTS (
                              SELECT 1 FROM json_each(json_extract(data, '$.edges')) je
                              WHERE je.value IN ({placeholders})
                          )
                        """,
                        orphan_edge_ids
                    ).fetchall();
                    for (node_id, node_data_str) in live_nodes {
                        try {
                            node_data = json.loads(node_data_str);
                            old_edges = node_data.get('edges', []);
                            orphan_edge_id_set = set(orphan_edge_ids);
                            node_data['edges'] = [
                                e
                                for e in old_edges
                                if e not in orphan_edge_id_set
                            ];
                            conn.execute(
                                "UPDATE anchors SET data = ? WHERE id = ?",
                                (json.dumps(node_data), node_id)
                            );
                        } except Exception as patch_err {
                            logger.error(
                                f"Failed to strip orphaned edges from node {node_id}: {patch_err}"
                            );
                        }
                    }
                    conn.execute("RELEASE cascade_q");
                    logger.info(
                        f"SqliteMemory: cascade-quarantined {len(
                            orphan_edge_ids
                        )} edge(s) "
                        f"connected to quarantined node {id}."
                    );
                } except Exception as cascade_err {
                    try {
                        conn.execute("ROLLBACK TO SAVEPOINT cascade_q");
                    } except Exception { }
                    try {
                        conn.execute("RELEASE cascade_q");
                    } except Exception { }
                    logger.error(
                        f"SqliteMemory: cascade quarantine for node {id} failed "
                        f"(rolled back to savepoint): {cascade_err}"
                    );
                }
            }
        }
        if manage_txn {
            conn.commit();
        }
    } except Exception as e {
        logger.error(f"Failed to quarantine anchor {id}: {e}");
    }
}

def _record_dangling(
    conn: sqlite3.Connection,
    missing_id: object,
    referrer_id: object,
    kind: str,
    manage_txn: bool = True
) {
    try {
        now_ts = datetime.now(timezone.utc).isoformat();
        anchor_type = 'EdgeAnchor' if kind == 'edge' else 'NodeAnchor';
        ref_str = str(referrer_id) if referrer_id is not None else '?';

        err = f"DANGLING_REF: missing {kind} {missing_id} cited by {ref_str}";
        payload = json.dumps({'referrer': ref_str, 'kind': kind});
        conn.execute(
            """
            INSERT OR REPLACE INTO anchors_quarantine
                (id, type, arch_module, arch_type, fingerprint, data,
                 error, quarantined_at, from_format_version)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                str(missing_id),
                anchor_type,
                None,
                'DANGLING_REF',
                None,
                payload,
                err,
                now_ts,
                None
            )
        );
        if manage_txn {
            conn.commit();
        }
    } except Exception as e {
        logger.error(f"failed to record dangling ref {missing_id}: {e}");
    }
}

def _prune_node_edges(
    conn: sqlite3.Connection, node_id: str, remove_ids: set[str]
) -> int {
    row = conn.execute("SELECT data FROM anchors WHERE id = ?", (node_id, )).fetchone();
    if not row {
        return 0;
    }
    try {
        d = json.loads(row[0]);
    } except Exception {
        return 0;
    }
    old_edges = d.get('edges') or [];
    new_edges = [
        e
        for e in old_edges
        if str(e) not in remove_ids
    ];
    if len(new_edges) == len(old_edges) {
        return 0;
    }
    d['edges'] = new_edges;
    conn.execute("UPDATE anchors SET data = ? WHERE id = ?", (json.dumps(d), node_id));
    return len(old_edges) - len(new_edges);
}

def _migrate_legacy_pickle_db(conn: sqlite3.Connection) {
    import from pickle { loads as pickle_loads }
    import from _pickle { UnpicklingError }
    logger.warning(
        "SqliteMemory: legacy pickle schema detected; migrating to JSON. "
        "Rows that can't be unpickled will be moved to anchors_quarantine."
    );

    cursor = conn.execute("SELECT id, data FROM anchors");
    old_rows = cursor.fetchall();

    conn.execute("ALTER TABLE anchors RENAME TO anchors_legacy_pickle");
    _create_new_schema(conn);
    migrated = 0;
    quarantined = 0;
    for (id_str, blob) in old_rows {
        try {
            anchor = pickle_loads(blob);
            row = _anchor_to_row(anchor);
            conn.execute(
                """
                INSERT OR REPLACE INTO anchors
                    (id, type, arch_module, arch_type, fingerprint, data,
                     format_version, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (id_str, ) + row
            );
            migrated += 1;
        } except (
            UnpicklingError,
            ModuleNotFoundError,
            AttributeError,
            TypeError
        ) as e {
            _quarantine(
                conn,
                id_str,
                None,
                None,
                None,
                None,
                None,
                f"legacy pickle unreadable: {type(e).__name__}: {e}",
                from_format_version=0
            );
            quarantined += 1;
        } except Exception as e {
            _quarantine(
                conn,
                id_str,
                None,
                None,
                None,
                None,
                None,
                f"legacy pickle migration error: {type(e).__name__}: {e}",
                from_format_version=0
            );
            quarantined += 1;
        }
    }
    conn.execute("DROP TABLE anchors_legacy_pickle");
    conn.commit();
    logger.warning(
        f"SqliteMemory: legacy migration complete -- "
        f"{migrated} anchors migrated, {quarantined} quarantined."
    );
}

impl Memory.abort -> None { }

impl Memory.quarantine_ref(referrer: (Anchor | None), stub: Anchor) -> None { }

impl Memory.is_recoverable_quarantine(id: UUID) -> bool {
    return False;
}

impl Memory.find(
    ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
) -> Generator[Anchor, None, None] {
    id_list = [ids] if isinstance(ids, UUID) else list(ids);
    for id in id_list {
        if (anchor := self.get(id)) {
            if filter is None or filter(anchor) {
                yield anchor;
            }
        }
    }
}

impl Memory.find_one(
    ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
) -> (Anchor | None) {
    id_list = [ids] if isinstance(ids, UUID) else list(ids);
    for id in id_list {
        if (anchor := self.get(id)) {
            if filter is None or filter(anchor) {
                return anchor;
            }
        }
    }
    return None;
}

impl VolatileMemory.postinit -> None {
    self.__mem__ = {};
}

impl VolatileMemory.is_available -> bool {
    return True;
}

impl VolatileMemory.get(id: UUID) -> (Anchor | None) {
    return self.__mem__.get(id);
}

impl VolatileMemory.put(anchor: Anchor) -> None {
    self.__mem__[anchor.id] = anchor;
}

impl VolatileMemory.delete(id: UUID) -> None {
    self.__mem__.pop(id, None);
}

impl VolatileMemory.close -> None {
    self.__mem__.clear();
}

impl VolatileMemory.`has(id: UUID) -> bool {
    return id in self.__mem__;
}

impl VolatileMemory.query(
    filter: (Callable[[Anchor], bool] | None) = None
) -> Generator[Anchor, None, None] {
    for anchor in self.__mem__.values() {
        if filter is None or filter(anchor) {
            yield anchor;
        }
    }
}

impl VolatileMemory.get_roots -> Generator[Root, None, None] {
    for anchor in self.__mem__.values() {
        if isinstance(anchor.archetype, Root) {
            yield cast(Root, anchor.archetype);
        }
    }
}

impl VolatileMemory.get_mem -> dict[UUID, Anchor] {
    return self.__mem__;
}

impl VolatileMemory.commit(anchor: (Anchor | None) = None) -> None { }

impl LocalCacheMemory.exists(id: UUID) -> bool {
    return id in self.__mem__;
}

impl LocalCacheMemory.put_if_exists(anchor: Anchor) -> bool {
    if anchor.id in self.__mem__ {
        self.__mem__[anchor.id] = anchor;
        return True;
    }
    return False;
}

impl LocalCacheMemory.invalidate(id: UUID) -> None {
    self.__mem__.pop(id, None);
}

impl SqliteMemory.postinit -> None {
    self.__mem__ = {};

    self.__conn__ = None;

    self.__lock__ = threading.RLock();
    self.l3_fetch_count = 0;
}

impl SqliteMemory._ensure_connection -> None {
    if self.__conn__ is not None {
        return;
    }

    parent_dir = os.path.dirname(self.path);
    if parent_dir {
        os.makedirs(parent_dir, exist_ok=True);
    }

    self.__conn__ = sqlite3.connect(self.path, check_same_thread=False);
    self.__conn__.execute("PRAGMA journal_mode=WAL");
    self.__conn__.execute("PRAGMA synchronous=NORMAL");
    self.__conn__.execute("PRAGMA busy_timeout=5000");

    if _is_new_schema(self.__conn__) {
        _create_new_schema(self.__conn__);
    } elif _is_legacy_schema(self.__conn__) {
        _migrate_legacy_pickle_db(self.__conn__);
    } else {
        _create_new_schema(self.__conn__);
    }

    _load_db_aliases(self.__conn__);
}

impl SqliteMemory.is_available -> bool {
    return self.__conn__ is not None;
}

impl SqliteMemory.get(id: UUID) -> (Anchor | None) {
    if (anchor := self.__mem__.get(id)) {
        return anchor;
    }
    with self.__lock__ {
        if not self.__conn__ and os.path.exists(self.path) {
            self._ensure_connection();
        }
        if not self.__conn__ {
            return None;
        }
        cursor = self.__conn__.execute(
            """
            SELECT type, arch_module, arch_type, fingerprint, data, format_version
            FROM anchors WHERE id = ?
            """,
            (str(id), )
        );
        row = cast(
            (tuple[str, (str | None), (str | None), (str | None), str, int] | None),
            cursor.fetchone()
        );
        if not row {
            return None;
        }
        (anchor_type, arch_module, arch_type, fingerprint, data_json, fmt_version) = row;
        self.l3_fetch_count += 1;
        if arch_module and arch_type and fingerprint {
            cls = Serializer._get_class(arch_module, arch_type);
            current_fp = cls?.__jac_fingerprint__ if cls else None;
            if current_fp and current_fp != fingerprint {
                logger.info(
                    f"SqliteMemory: schema drift on {arch_module}.{arch_type} "
                    f"(stored fingerprint={fingerprint}, current={current_fp}, "
                    f"anchor id={id}); attempting best-effort load."
                );
            }
        }
        try {
            data = json.loads(data_json);
            anchor = Serializer.deserialize(data);
        } except Exception as e {
            logger.warning(
                f"SqliteMemory: failed to deserialize anchor {id} "
                f"({arch_module}.{arch_type}): {type(e).__name__}: {e}. "
                f"Moving to anchors_quarantine."
            );
            _quarantine(
                self.__conn__,
                str(id),
                anchor_type,
                arch_module,
                arch_type,
                fingerprint,
                data_json,
                f"deserialize error: {type(e).__name__}: {e}",
                from_format_version=fmt_version
            );
            return None;
        }
        if anchor is None {
            cls_resolved = (
                Serializer._get_class(arch_module, arch_type)
                    if (arch_module and arch_type)
                    else None
            );
            if cls_resolved is None {
                if os.environ.get("JAC_SV_SIBLING") == "1" {
                    logger.debug(
                        f"SqliteMemory: class {arch_module}.{arch_type} not "
                        f"loaded in this sibling service; skipping anchor {id} "
                        "(owned by a peer service)."
                    );
                    return None;
                }
                reason = f"class {arch_module}.{arch_type} unresolvable";
                logger.warning(
                    f"SqliteMemory: class {arch_module}.{arch_type} unresolvable "
                    f"for anchor {id}. Moving to anchors_quarantine."
                );
            } else {
                reason = f"archetype field deserialization failed: {arch_module}.{arch_type}";
                logger.warning(
                    f"SqliteMemory: archetype field deserialization failed for "
                    f"{arch_module}.{arch_type} (anchor {id}). "
                    f"Moving to anchors_quarantine."
                );
            }
            _quarantine(
                self.__conn__,
                str(id),
                anchor_type,
                arch_module,
                arch_type,
                fingerprint,
                data_json,
                reason,
                from_format_version=fmt_version
            );
            return None;
        }
        self.__mem__[id] = cast(Anchor, anchor);
        snapshot_field_hashes(cast(Anchor, anchor));
        return cast(Anchor, anchor);
    }
}

impl SqliteMemory.put(anchor: Anchor) -> None {
    self.__mem__[anchor.id] = anchor;
    if not anchor.persistent or not anchor.is_populated() {
        return;
    }
    with self.__lock__ {
        self._ensure_connection();
        conn = cast(sqlite3.Connection, self.__conn__);
        try {
            row = _anchor_to_row(anchor);
            conn.execute(
                """
                INSERT OR REPLACE INTO anchors
                    (id, type, arch_module, arch_type, fingerprint,
                     data, format_version, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (str(anchor.id), ) + row
            );
            conn.commit();
        } except (AttributeError, ModuleNotFoundError) {
            return;
        } except Exception as e {
            logger.warning(
                f"SqliteMemory.put: failed to persist {anchor.id}: "
                f"{type(e).__name__}: {e}"
            );
        }
    }
}

impl SqliteMemory.delete(id: UUID) -> None {
    self.__mem__.pop(id, None);
}

impl SqliteMemory.close -> None {
    if self.__conn__ {
        self.__conn__.close();
        self.__conn__ = None;
    }
    self.__mem__.clear();
}

impl SqliteMemory.`has(id: UUID) -> bool {
    if id in self.__mem__ {
        return True;
    }
    with self.__lock__ {
        if not self.__conn__ and os.path.exists(self.path) {
            self._ensure_connection();
        }
        if self.__conn__ {
            cursor = self.__conn__.execute(
                "SELECT 1 FROM anchors WHERE id = ?", (str(id), )
            );
            return cursor.fetchone() is not None;
        }
    }
    return False;
}

impl SqliteMemory.query(
    filter: (Callable[[Anchor], bool] | None) = None
) -> Generator[Anchor, None, None] {
    for anchor in self.__mem__.values() {
        if filter is None or filter(anchor) {
            yield anchor;
        }
    }
}

impl SqliteMemory.get_roots -> Generator[Root, None, None] {
    seen: set[UUID] = set();

    for anchor in list(self.__mem__.values()) {
        if isinstance(anchor.archetype, Root) {
            seen.add(anchor.id);
            yield cast(Root, anchor.archetype);
        }
    }

    candidate_ids: list[UUID] = [];
    with self.__lock__ {
        if not self.__conn__ and os.path.exists(self.path) {
            self._ensure_connection();
        }
        if self.__conn__ is not None {
            cursor = self.__conn__.execute(
                "SELECT id, arch_module, arch_type FROM anchors WHERE type = ?",
                ("NodeAnchor", )
            );
            for row in cursor.fetchall() {
                arch_module = row[1];
                arch_type = row[2];
                uid = UUID(row[0]);
                if uid in seen or not arch_module or not arch_type {
                    continue;
                }
                cls = Serializer._get_class(arch_module, arch_type);
                if cls is not None
                and isinstance(cls, type)
                and issubclass(cls, Root) {
                    candidate_ids.append(uid);
                }
            }
        }
    }
    for uid in candidate_ids {
        anchor = self.get(uid);
        if anchor is not None and isinstance(anchor.archetype, Root) {
            seen.add(uid);
            yield cast(Root, anchor.archetype);
        }
    }
}

def _canonical_json(val: object) -> str {
    return json.dumps(
        Serializer.serialize(val, include_type=True),
        sort_keys=True,
        default=lambda (v: str) { str(v); }
    );
}

impl SqliteMemory.apply(changeset: ChangeSet) -> ApplyReport {
    apply_report = ApplyReport();
    if changeset.is_empty() {
        return apply_report;
    }
    with self.__lock__ {
        self._ensure_connection();
        assert self.__conn__ is not None;
        conn = self.__conn__;
        conn.commit();
        try {
            conn.execute("BEGIN IMMEDIATE");
            poisoned: set[UUID] = set();
            for stage in changeset.staged() {
                for intent in stage {
                    if (deps := intent.depends_on & poisoned) {
                        dep = next(iter(deps));
                        apply_report.skipped[intent.anchor.id] = (
                            f"dependency {dep} failed"
                        );
                        poisoned.add(intent.anchor.id);
                        logger.error(
                            f"SqliteMemory.apply: skipping {intent.op.name} on "
                            f"{intent.anchor.id}: dependency {dep} failed"
                        );
                        continue;
                    }
                    try {
                        self._apply_one(conn, intent);
                        apply_report.applied.append(intent.anchor.id);
                    } except WriteConflict as wc {
                        poisoned.add(intent.anchor.id);
                        apply_report.failed[intent.anchor.id] = wc.message();
                        apply_report.conflicts.append(wc);
                        logger.debug(
                            f"SqliteMemory.apply: write conflict on "
                            f"{intent.anchor.id}: {wc.message()}"
                        );
                    } except (AttributeError, ModuleNotFoundError) as se {
                        poisoned.add(intent.anchor.id);
                        apply_report.failed[intent.anchor.id] = str(se);
                    } except Exception as e {
                        poisoned.add(intent.anchor.id);
                        apply_report.failed[intent.anchor.id] = str(e);
                        logger.error(
                            f"SqliteMemory.apply: {intent.op.name} failed for "
                            f"{intent.anchor.id}: {type(e).__name__}: {e}"
                        );
                    }
                }
            }
            if apply_report.conflicts {
                conn.rollback();
                apply_report.applied = [];
            } else {
                conn.commit();
            }
        } except Exception as te {
            conn.rollback();
            apply_report.applied = [];
            for stage in changeset.staged() {
                for intent in stage {
                    apply_report.failed[intent.anchor.id] = str(te);
                }
            }
            logger.error(f"SqliteMemory.apply: transaction rolled back: {te}");
        }
    }
    return apply_report;
}

impl SqliteMemory._apply_one(conn: sqlite3.Connection, intent: WriteIntent) -> None {
    if intent.is_delete() {
        conn.execute("DELETE FROM anchors WHERE id = ?", (str(intent.anchor.id), ));
        return;
    }
    self._merge_write(conn, intent);
}

impl SqliteMemory._merge_write(conn: sqlite3.Connection, intent: WriteIntent) -> None {
    anchor = intent.anchor;
    key = str(anchor.id);
    cursor = conn.execute(
        """
        SELECT type, arch_module, arch_type, fingerprint, data,
               format_version
        FROM anchors WHERE id = ?
        """,
        (key, )
    );
    raw_row = cursor.fetchone();
    stored: (Anchor | None) = None;
    if raw_row {
        row_type = cast(str, raw_row[0]);
        row_arch_module = cast((str | None), raw_row[1]);
        row_arch_type = cast((str | None), raw_row[2]);
        row_fingerprint = cast((str | None), raw_row[3]);
        row_data = cast(str, raw_row[4]);
        row_fmt = cast(int, raw_row[5]);
        try {
            stored = cast(
                (Anchor | None), Serializer.deserialize(json.loads(row_data))
            );
        } except Exception as de {
            logger.warning(
                f"SqliteMemory.apply: stored anchor {key} unreadable "
                f"({type(de).__name__}: {de}); quarantining and "
                "overwriting with in-memory version."
            );

            _quarantine(
                conn,
                key,
                row_type,
                row_arch_module,
                row_arch_type,
                row_fingerprint,
                row_data,
                f"apply-time deserialize: {type(de).__name__}: {de}",
                from_format_version=row_fmt,
                manage_txn=False
            );
            stored = None;
        }
    }

    if stored is not None and stored.is_populated() {
        stored_anchor = cast(Anchor, stored);
        changed = False;

        if (
            isinstance(stored_anchor, NodeAnchor)
            and isinstance(anchor, NodeAnchor)
            and stored_anchor.edges != anchor.edges
        ) {
            delta = anchor.edge_delta();
            if delta is not None {
                edges_added = set(delta[0]);
                edges_removed = set(delta[1]);

                if (edges_added or edges_removed)
                and intent.cas_version is not None
                and stored_anchor.version != intent.cas_version {
                    raise WriteConflict(
                        anchor_id=anchor.id,
                        expected_version=intent.cas_version,
                        actual_version=stored_anchor.version
                    );
                }
                stored_set = set(e.id for e in stored_anchor.edges);
                merged_ids = (stored_set | edges_added) - edges_removed;
                edge_by_id = {e.id: e for e in stored_anchor.edges};
                edge_by_id.update({e.id: e for e in anchor.edges});
                stored_anchor.edges = [
                    edge_by_id[eid]
                    for eid in merged_ids
                    if eid in edge_by_id
                ];
                if edges_added or edges_removed {
                    new_version = stored_anchor.version + 1;
                    stored_anchor.version = new_version;
                    anchor.version = new_version;
                }
            } else {
                stored_anchor.edges = anchor.edges;
            }
            if (not stored_anchor.edges and not isinstance(anchor.archetype, Root)) {
                conn.execute("DELETE FROM anchors WHERE id = ?", (key, ));
                return;
            }
            changed = True;
        }

        if (
            isinstance(stored_anchor, NodeAnchor)
            and isinstance(anchor, NodeAnchor)
            and anchor.topology_index_data != stored_anchor.topology_index_data
        ) {
            stored_anchor.topology_index_data = anchor.topology_index_data;
            changed = True;
        }
        if _canonical_json(stored_anchor.access) != _canonical_json(anchor.access) {
            stored_anchor.access = anchor.access;
            changed = True;
        }

        arch = anchor.archetype;
        fields = set(get_field_types(type(arch)).keys())
            if (intent.is_create() and arch is not None)
            else set(intent.fields);
        if fields and stored_anchor.archetype is not None and arch is not None {
            for field in fields {
                try {
                    setattr(stored_anchor.archetype, field, getattr(arch, field));
                } except AttributeError {
                    continue;
                }
            }
            changed = True;
        }
        if changed {
            merged_row = _anchor_to_row(stored_anchor);
            conn.execute(
                """
                INSERT OR REPLACE INTO anchors
                    (id, type, arch_module, arch_type, fingerprint,
                     data, format_version, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (key, ) + merged_row
            );
        }
    } else {
        new_row = _anchor_to_row(anchor);
        conn.execute(
            """
            INSERT OR REPLACE INTO anchors
                (id, type, arch_module, arch_type, fingerprint,
                 data, format_version, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (key, ) + new_row
        );
    }
}

impl SqliteMemory.get_mem -> dict[UUID, Anchor] {
    return self.__mem__;
}

impl SqliteMemory.commit(anchor: (Anchor | None) = None) -> None { }

def _sqlite_attempt_recover(conn: sqlite3.Connection, row: tuple) -> tuple {
    (
        row_id,
        anchor_type,
        arch_module,
        arch_type,
        fingerprint,
        data_json,
        _error,
        _quarantined_at,
        from_format_version
    ) = row;
    if not data_json {
        return (False, "no data payload stored");
    }
    try {
        data = json.loads(data_json);
    } except Exception as e {
        return (False, f"json decode failed: {e}");
    }
    try {
        anchor = Serializer.deserialize(data);
    } except Exception as e {
        return (False, f"deserialize raised: {type(e).__name__}: {e}");
    }
    if anchor is None {
        return (False, f"class {arch_module}.{arch_type} still unresolvable");
    }

    re_data = Serializer.serialize(anchor, include_type=True);
    re_data_json = json.dumps(re_data);
    live_arch = anchor?.archetype;
    live_module = type(live_arch).__module__ if live_arch else arch_module;
    live_type = type(live_arch).__name__ if live_arch else arch_type;
    _live_fp = type(live_arch)?.__jac_fingerprint__ if live_arch else None;
    live_fp = _live_fp if _live_fp is not None else fingerprint;
    now = datetime.now(timezone.utc).isoformat();
    conn.execute(
        """
        INSERT OR REPLACE INTO anchors
            (id, type, arch_module, arch_type, fingerprint, data,
             format_version, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            row_id,
            anchor_type or 'Anchor',
            live_module,
            live_type,
            live_fp,
            re_data_json,
            from_format_version or 1,
            now
        )
    );
    conn.execute("DELETE FROM anchors_quarantine WHERE id = ?", (row_id, ));

    if anchor_type == 'EdgeAnchor' and isinstance(data, dict) {
        source_id = data.get('source');
        target_id = data.get('target');
        is_undirected = bool(data.get('is_undirected', False));
        relink_ids: list[str] = [
            n
            for n in [source_id]
            if n
        ];
        if is_undirected and target_id and target_id != source_id {
            relink_ids.append(target_id);
        }
        for node_id in relink_ids {
            node_row = conn.execute(
                "SELECT data FROM anchors WHERE id = ? AND type = 'NodeAnchor'",
                (node_id, )
            ).fetchone();
            if node_row {
                try {
                    node_data = json.loads(node_row[0]);
                    edges = node_data.get('edges', []);
                    if row_id not in edges {
                        edges.append(row_id);
                        node_data['edges'] = edges;
                        conn.execute(
                            "UPDATE anchors SET data = ? WHERE id = ?",
                            (json.dumps(node_data), node_id)
                        );
                    }
                } except Exception as relink_err {
                    logger.warning(
                        f"SqliteMemory: recover re-link of edge {row_id} "
                        f"to node {node_id} failed: {relink_err}"
                    );
                }
            } else {
                logger.warning(
                    f"SqliteMemory: recover re-link of edge {row_id} "
                    f"to node {node_id} skipped: node not found in live anchors"
                );
            }
        }
    }
    return (True, "recovered");
}


impl SqliteMemory.inspect_summary -> dict {
    self._ensure_connection();
    assert self.__conn__ is not None;
    conn = self.__conn__;
    fmt_row = conn.execute(
        "SELECT value FROM schema_meta WHERE key='db_format_version'"
    ).fetchone();
    fmt_version = fmt_row[0] if fmt_row else '?';
    anchors_rows = cast(
        list[tuple],
        list(
            conn.execute(
                """
        SELECT COALESCE(arch_type, '<none>'), COUNT(*)
        FROM anchors
        GROUP BY arch_type
        ORDER BY COUNT(*) DESC
        """
            )
        )
    );
    quarantine_rows = cast(
        list[tuple],
        list(
            conn.execute(
                """
        SELECT COALESCE(arch_type, '<none>'), COUNT(*)
        FROM anchors_quarantine
        GROUP BY arch_type
        ORDER BY COUNT(*) DESC
        """
            )
        )
    );
    (alias_count, ) = cast(
        tuple[int], conn.execute("SELECT COUNT(*) FROM aliases").fetchone()
    );
    return {
        'format_version': str(fmt_version),
        'anchors_total': sum(r[1] for r in anchors_rows),
        'anchors_by_type': [(r[0], r[1]) for r in anchors_rows],
        'quarantine_total': sum(r[1] for r in quarantine_rows),
        'quarantine_by_type': [(r[0], r[1]) for r in quarantine_rows],
        'aliases_total': alias_count,
        'location': self.path
    };
}


impl SqliteMemory.list_quarantined(limit: int = 50) -> list {
    self._ensure_connection();
    assert self.__conn__ is not None;
    conn = self.__conn__;
    rows = cast(
        list[tuple],
        list(
            conn.execute(
                """
        SELECT id, COALESCE(arch_module, '?') || '.' ||
               COALESCE(arch_type, '?'), COALESCE(fingerprint, ''),
               COALESCE(error, ''), COALESCE(quarantined_at, '')
        FROM anchors_quarantine
        ORDER BY quarantined_at DESC
        LIMIT ?
        """,
                (limit, )
            )
        )
    );
    return [
        {
            'id': str(r[0]),
            'arch': str(r[1]),
            'fingerprint': str(r[2]),
            'error': str(r[3]),
            'quarantined_at': str(r[4])
        } for r in rows
    ];
}


impl SqliteMemory.show_quarantined(id_prefix: str) -> (dict | None) {
    self._ensure_connection();
    assert self.__conn__ is not None;
    conn = self.__conn__;
    rows = cast(
        list[tuple],
        list(
            conn.execute(
                """
        SELECT id, type, arch_module, arch_type, fingerprint, data,
               error, quarantined_at, from_format_version
        FROM anchors_quarantine
        WHERE id = ? OR id LIKE ?
        LIMIT 2
        """,
                (id_prefix, id_prefix + '%')
            )
        )
    );
    if not rows {
        return None;
    }
    if len(rows) > 1 {
        return {'error': 'ambiguous', 'count': len(rows)};
    }
    r = rows[0];
    parsed_data = None;
    try {
        parsed_data = json.loads(r[5]) if r[5] else None;
    } except Exception { }
    return {
        'id': r[0],
        'type': r[1],
        'arch_module': r[2],
        'arch_type': r[3],
        'fingerprint': r[4],
        'error': r[6],
        'quarantined_at': r[7],
        'from_format_version': r[8],
        'data': parsed_data
    };
}


impl SqliteMemory.recover_one(id_prefix: str) -> tuple {
    self._ensure_connection();
    assert self.__conn__ is not None;
    conn = self.__conn__;

    _load_db_aliases(conn);
    rows = cast(
        list[tuple],
        list(
            conn.execute(
                """
        SELECT id, type, arch_module, arch_type, fingerprint, data,
               error, quarantined_at, from_format_version
        FROM anchors_quarantine
        WHERE id = ? OR id LIKE ?
        LIMIT 2
        """,
                (id_prefix, id_prefix + '%')
            )
        )
    );
    if not rows {
        return (False, f"no quarantined row matching {id_prefix}");
    }
    if len(rows) > 1 {
        return (False, f"prefix {id_prefix} matches multiple rows");
    }
    (ok, reason) = _sqlite_attempt_recover(conn, rows[0]);
    conn.commit();
    return (ok, reason);
}


impl SqliteMemory.recover_all -> tuple {
    self._ensure_connection();
    assert self.__conn__ is not None;
    conn = self.__conn__;
    _load_db_aliases(conn);
    rows = cast(
        list[tuple],
        list(
            conn.execute(
                """
        SELECT id, type, arch_module, arch_type, fingerprint, data,
               error, quarantined_at, from_format_version
        FROM anchors_quarantine
        """
            )
        )
    );

    rows.sort(key=lambda (r) { 0 if r[1] == 'NodeAnchor' else 1; });
    recovered = 0;
    still_stuck: list = [];
    for r in rows {
        (ok, reason) = _sqlite_attempt_recover(conn, r);
        if ok {
            recovered += 1;
        } else {
            still_stuck.append((str(r[0]), reason));
        }
    }
    conn.commit();
    return (recovered, still_stuck);
}


impl SqliteMemory.quarantine_dangling(
    missing_id: UUID, referrer_id: (UUID | None), kind: str
) -> None {
    with self.__lock__ {
        self._ensure_connection();
        if self.__conn__ is not None {
            _record_dangling(self.__conn__, missing_id, referrer_id, kind);
        }
    }
}


impl SqliteMemory.is_recoverable_quarantine(id: UUID) -> bool {
    with self.__lock__ {
        if not self.__conn__ and os.path.exists(self.path) {
            self._ensure_connection();
        }
        if self.__conn__ is None {
            return False;
        }
        row = self.__conn__.execute(
            """
            SELECT 1 FROM anchors_quarantine
            WHERE id = ? AND COALESCE(error, '') NOT LIKE 'DANGLING_REF%'
            """,
            (str(id), )
        ).fetchone();
        return row is not None;
    }
}


impl SqliteMemory.fsck(repair: bool = False) -> dict {
    fsck_report: dict = {
        'location': self.path,
        'dangling_node_edge': [],
        'dangling_edge_node': [],
        'orphan_edges': [],
        'orphan_nodes': [],
        'half_linked_edges': [],
        'repaired': repair,
        'repaired_counts': {'pruned': 0, 'quarantined': 0, 'collected': 0}
    };
    with self.__lock__ {
        if not self.__conn__ and os.path.exists(self.path) {
            self._ensure_connection();
        }
        if self.__conn__ is None {
            return fsck_report;
        }
        conn = self.__conn__;
        node_ids: set[str] = set();
        edge_ids: set[str] = set();
        node_edges: dict[str, list[str]] = {};
        edge_endpoints: dict[str, tuple[(str | None), (str | None)]] = {};
        node_is_root: dict[str, bool] = {};
        for (rid, rtype, ratype, rdata) in conn.execute(
            "SELECT id, type, arch_type, data FROM anchors"
        ).fetchall() {
            try {
                d = json.loads(rdata);
            } except Exception {
                d = {};
            }
            if rtype == 'NodeAnchor' {
                node_ids.add(rid);
                node_edges[rid] = [str(e) for e in (d.get('edges') or [])];
                node_is_root[rid] = ratype == 'Root';
            } elif rtype == 'EdgeAnchor' {
                edge_ids.add(rid);
                src = d.get('source');
                tgt = d.get('target');
                edge_endpoints[rid] = (
                    (str(src) if src is not None else None),
                    (str(tgt) if tgt is not None else None)
                );
            }
        }
        cited_edges: set[str] = set();
        for (nid, eids) in node_edges.items() {
            for eid in eids {
                cited_edges.add(eid);
                if eid not in edge_ids {
                    fsck_report['dangling_node_edge'].append((nid, eid));
                }
            }
        }
        referenced_nodes: set[str] = set();
        broken_edge_ids: set[str] = set();
        for (eid, endpoints) in edge_endpoints.items() {
            for endp in endpoints {
                if endp is not None {
                    referenced_nodes.add(endp);
                    if endp not in node_ids {
                        fsck_report['dangling_edge_node'].append((eid, endp));
                        broken_edge_ids.add(eid);
                    }
                }
            }
        }
        orphan_edge_ids: set[str] = set();
        for eid in edge_ids {
            if eid not in cited_edges {
                fsck_report['orphan_edges'].append(eid);
                orphan_edge_ids.add(eid);
            }
        }
        half_linked_ids: set[str] = set();
        for (eid, ep) in edge_endpoints.items() {
            if (
                ep[0] is None
                or ep[1] is None
                or ep[0] not in node_ids
                or ep[1] not in node_ids
            ) {
                continue;
            }
            src = cast(str, ep[0]);
            tgt = cast(str, ep[1]);
            src_cites = src in node_edges and eid in node_edges[src];
            tgt_cites = tgt in node_edges and eid in node_edges[tgt];
            if src_cites != tgt_cites {
                (citing, rejecting) = (src, tgt) if src_cites else (tgt, src);
                fsck_report['half_linked_edges'].append((eid, citing, rejecting));
                half_linked_ids.add(eid);
            }
        }
        collectible_edges: set[str] = (
            orphan_edge_ids | half_linked_ids | broken_edge_ids
        );
        surviving_referenced: set[str] = set();
        for (eid, ep) in edge_endpoints.items() {
            if eid not in collectible_edges {
                if ep[0] is not None {
                    surviving_referenced.add(ep[0]);
                }
                if ep[1] is not None {
                    surviving_referenced.add(ep[1]);
                }
            }
        }
        for nid in node_ids {
            remaining = [
                e
                for e in node_edges.get(nid, [])
                if e not in collectible_edges
            ];
            if (
                not node_is_root.get(nid)
                and not remaining
                and nid not in surviving_referenced
            ) {
                fsck_report['orphan_nodes'].append(nid);
            }
        }
        if not repair {
            return fsck_report;
        }
        counts = fsck_report['repaired_counts'];
        conn.commit();
        try {
            conn.execute("BEGIN IMMEDIATE");
            remove_by_node: dict[str, set[str]] = {};
            for (nid, eid) in fsck_report['dangling_node_edge'] {
                remove_by_node.setdefault(nid, set()).add(eid);
                _record_dangling(conn, eid, nid, 'edge', manage_txn=False);
                counts['quarantined'] += 1;
            }
            broken_edges: set[str] = set();
            for (eid, nid) in fsck_report['dangling_edge_node'] {
                _record_dangling(conn, nid, eid, 'node', manage_txn=False);
                counts['quarantined'] += 1;
                broken_edges.add(eid);
            }

            collect_edges: set[str] = broken_edges | orphan_edge_ids | half_linked_ids;
            for (nid, eids) in node_edges.items() {
                also = set(eids) & collect_edges;
                if also {
                    remove_by_node.setdefault(nid, set()).update(also);
                }
            }
            for (nid, rem) in remove_by_node.items() {
                counts['pruned'] += _prune_node_edges(conn, nid, rem);
            }
            to_collect: list[str] = (
                list(collect_edges) + list(fsck_report['orphan_nodes'])
            );
            if to_collect {
                placeholders = ','.join('?' * len(to_collect));
                cur = conn.execute(
                    f"DELETE FROM anchors WHERE id IN ({placeholders})", to_collect
                );
                counts['collected'] += (
                    cur.rowcount if cur.rowcount and cur.rowcount > 0 else 0
                );
            }
            conn.commit();
        } except Exception as e {
            conn.rollback();
            logger.error(f"fsck --repair rolled back: {e}");
            fsck_report['repaired'] = False;
        }
    }
    return fsck_report;
}


impl SqliteMemory.list_aliases -> list {
    self._ensure_connection();
    assert self.__conn__ is not None;
    conn = self.__conn__;
    rows = cast(
        list[tuple],
        list(
            conn.execute(
                "SELECT old_name, new_name, COALESCE(created_at, '') "
                "FROM aliases ORDER BY created_at"
            )
        )
    );
    return [
        {'old_name': str(r[0]), 'new_name': str(r[1]), 'created_at': str(r[2])}
        for r in rows
    ];
}


impl SqliteMemory.add_alias(old_name: str, new_name: str) -> None {
    self._ensure_connection();
    assert self.__conn__ is not None;
    conn = self.__conn__;
    now = datetime.now(timezone.utc).isoformat();
    conn.execute(
        """
        INSERT OR REPLACE INTO aliases (old_name, new_name, created_at)
        VALUES (?, ?, ?)
        """,
        (old_name, new_name, now)
    );
    conn.commit();
    Serializer._aliases[old_name] = new_name;
}


impl SqliteMemory.remove_alias(old_name: str) -> bool {
    self._ensure_connection();
    assert self.__conn__ is not None;
    conn = self.__conn__;
    cursor = conn.execute("DELETE FROM aliases WHERE old_name = ?", (old_name, ));
    conn.commit();
    removed = cursor.rowcount > 0;
    if removed {
        Serializer._aliases.pop(old_name, None);
    }
    return removed;
}

impl TieredMemory.postinit -> None {
    import from jaclang.runtimelib.memory { LocalCacheMemory, SqliteMemory }
    import from jaclang.runtimelib.utils { get_db_path }

    self.__mem__ = {};

    self.changes = ChangeSet();

    if self.use_cache {
        self.l2 = LocalCacheMemory();
    } else {
        self.l2 = None;
    }

    if self.base_path {
        db_path = get_db_path(self.base_path, target_path=self.target_path);

        self.l3 = self._resolve_l3_backend(db_path);
    } else {
        self.l3 = None;
    }
}

impl TieredMemory._resolve_l3_backend(db_path: str) -> PersistentMemory {
    import from jaclang { JacRuntimeInterface as Jac }
    import from jaclang.runtimelib.memory { SqliteMemory }
    hooked: (PersistentMemory | None) = None;
    try {
        hooked = Jac.get_persistent_memory(
            {
                'db_path': db_path,
                'base_path': self.base_path,
                'target_path': self.target_path
            }
        );
    } except Exception as e {
        logger.debug(f"get_persistent_memory hook failed; using SqliteMemory: {e}");
    }
    if hooked is not None {
        return hooked;
    }
    return SqliteMemory(path=db_path);
}

impl TieredMemory.get(id: UUID) -> (Anchor | None) {
    if (anchor := self.__mem__.get(id)) {
        return anchor;
    }

    if self.l2 and (anchor := self.l2.get(id)) {
        self.__mem__[anchor.id] = anchor;
        return anchor;
    }

    if self.l3 and (anchor := self.l3.get(id)) {
        self.__mem__[anchor.id] = anchor;
        if self.l2 {
            self.l2.put(anchor);
        }
        return anchor;
    }
    return None;
}

impl TieredMemory.put(anchor: Anchor) -> None {
    self.__mem__[anchor.id] = anchor;
    if self.l2 {
        self.l2.put(anchor);
    }
}

impl TieredMemory.get_roots -> Generator[Root, None, None] {
    seen: set[int] = set();
    for anchor in list(self.__mem__.values()) {
        if isinstance(anchor.archetype, Root) {
            seen.add(id(anchor.archetype));
            yield cast(Root, anchor.archetype);
        }
    }
    if self.l3 is not None {
        for l3_root in self.l3.get_roots() {
            if id(l3_root) not in seen {
                seen.add(id(l3_root));
                yield l3_root;
            }
        }
    }
}

impl TieredMemory.delete(id: UUID) -> None {
    anchor: (Anchor | None) = self.__mem__.pop(id, None);
    if anchor is None and self.l3 is not None {
        anchor = self.l3.get(id);
    }
    if self.l3 is not None {
        self.l3.delete(id);
    }
    if self.l2 {
        self.l2.invalidate(id);
    }
    if anchor is not None and anchor.persistent {
        self.changes.record_delete(anchor);
    }
}

impl TieredMemory.close -> None {
    self.commit();
    if self.l3 {
        self.l3.close();
    }
    if self.l2 {
        self.l2.close();
    }

    self.__mem__.clear();
    self.changes.clear();
}

impl TieredMemory.`has(id: UUID) -> bool {
    if id in self.__mem__ {
        return True;
    }

    if self.l2 and self.l2.exists(id) {
        return True;
    }

    if self.l3 and self.l3.`has(id) {
        return True;
    }
    return False;
}

impl TieredMemory.get_l3_fetch_count -> int {
    import from jaclang.runtimelib.memory { SqliteMemory }
    if isinstance(self.l3, SqliteMemory) {
        return self.l3.l3_fetch_count;
    }
    return 0;
}

impl TieredMemory.reset_l3_fetch_count -> None {
    import from jaclang.runtimelib.memory { SqliteMemory }
    if isinstance(self.l3, SqliteMemory) {
        self.l3.l3_fetch_count = 0;
    }
}

impl TieredMemory.commit(anchor: (Anchor | None) = None) -> None {
    if self.l3 is None {
        self.changes.clear();
        return;
    }
    self._collect_into(self.changes);
    if self.changes.is_empty() {
        return;
    }
    apply_report = self.l3.apply(self.changes);
    self._post_apply(apply_report);
    self.changes.clear();

    if (conflict := apply_report.primary_conflict()) {
        raise conflict;
    }
}

impl TieredMemory._collect_into(changes: ChangeSet) -> None {
    import from jaclang { JacRuntimeInterface as Jac }
    for (id, anchor) in list(self.__mem__.items()) {
        if not anchor.persistent or not anchor.is_populated() {
            continue;
        }
        existing = changes.intents.get(id);
        if existing is not None and existing.is_delete() {
            continue;
        }
        try {
            computed = Serializer._compute_hash(anchor);
        } except Exception {
            continue;
        }
        if anchor.hash != 0 and computed == anchor.hash {
            continue;
        }
        if anchor.hash == 0 {
            if (
                isinstance(anchor, NodeAnchor)
                and not isinstance(anchor.archetype, Root)
                and not anchor.edges
            ) {
                continue;
            }
            if Jac.check_write_access(anchor, op_hint="field_write") {
                changes.record_create(anchor);
            }
            continue;
        }
        recorded = False;
        if isinstance(anchor, NodeAnchor) {
            delta = anchor.edge_delta();
            if delta is not None {
                added = [eid for eid in delta[0]];
                removed = [eid for eid in delta[1]];
                if (added or removed) and Jac.check_connect_access(anchor) {
                    changes.record_edge_delta(anchor, added, removed);
                    recorded = True;

                    edge_intent = changes.intents.get(id);
                    if edge_intent is not None {
                        edge_intent.cas_version = Jac.get_context().read_versions.get(
                            id
                        );
                    }
                }
            }
        }
        dirty = derive_dirty_fields(anchor);
        if dirty and Jac.check_write_access(anchor, op_hint="field_write") {
            changes.record_update(anchor, dirty);
            recorded = True;
        } elif (
            recorded
            and not anchor.archetype.__dict__.get('__jac_field_hashes__')
            and Jac.check_write_access(anchor, op_hint="field_write")
        ) {
            changes.record_update(
                anchor, set(get_field_types(type(anchor.archetype)).keys())
            );
        }
        if not recorded {
            if Jac.check_write_access(anchor, op_hint="field_write") {
                changes.record_create(anchor);
            }
        }
    }
}

impl TieredMemory._post_apply(apply_report: ApplyReport) -> None {
    import from jaclang { JacRuntimeInterface as Jac }
    applied = set(apply_report.applied);

    read_versions: dict = {};
    try {
        read_versions = Jac.get_context().read_versions;
    } except Exception {
        ;
    }
    for intent in self.changes.intents.values() {
        if intent.is_delete() or intent.anchor.id not in applied {
            continue;
        }
        anchor = intent.anchor;
        try {
            anchor.hash = Serializer._compute_hash(anchor);
            snapshot_field_hashes(anchor);
            if isinstance(anchor, NodeAnchor) {
                anchor.__dict__['_initial_edge_ids'] = frozenset(
                    e.id for e in anchor.edges
                );
                if anchor.id in read_versions {
                    read_versions[anchor.id] = anchor.version;
                }
            }
        } except Exception as e {
            logger.debug(f"post-apply re-baseline failed for {anchor.id}: {e}");
        }
    }
}

impl TieredMemory.abort -> None {
    self.changes.clear();
    for (id, anchor) in list(self.__mem__.items()) {
        if not anchor.persistent or not anchor.is_populated() {
            continue;
        }
        dirty = anchor.hash == 0;
        if not dirty {
            try {
                dirty = Serializer._compute_hash(anchor) != anchor.hash;
            } except Exception {
                dirty = True;
            }
        }
        if dirty {
            self.__mem__.pop(id, None);
            if self.l2 {
                self.l2.invalidate(id);
            }
            if self.l3 {
                self.l3.delete(id);
            }
        }
    }
}

impl TieredMemory.quarantine_ref(referrer: (Anchor | None), stub: Anchor) -> None {
    if self.l3 is not None {
        kind = 'edge' if isinstance(stub, EdgeAnchor) else 'node';
        ref_id = referrer.id if referrer is not None else None;
        try {
            self.l3.quarantine_dangling(stub.id, ref_id, kind);
        } except Exception as e {
            logger.debug(f"quarantine_dangling record failed for {stub.id}: {e}");
        }
    }

    if isinstance(referrer, NodeAnchor) {
        nanchor = cast(NodeAnchor, referrer);
        before = len(nanchor.edges);
        nanchor.edges = [
            e
            for e in nanchor.edges
            if e.id != stub.id
        ];
        if len(nanchor.edges) != before {
            if nanchor.persistent {
                try {
                    self.changes.record_edge_delta(
                        nanchor, added=[], removed=[stub.id]
                    );
                } except Exception as e {
                    logger.debug(f"heal edge-delta record failed: {e}");
                }
            }
            if self.l2 {
                self.l2.invalidate(nanchor.id);
            }
            logger.warning(
                f"healed dangling reference: pruned {stub.id} from node "
                f"{nanchor.id} (quarantined under DANGLING_REF)"
            );
        }
    }
}

impl TieredMemory.is_recoverable_quarantine(id: UUID) -> bool {
    if self.l3 is None {
        return False;
    }
    try {
        return self.l3.is_recoverable_quarantine(id);
    } except Exception {
        return False;
    }
}

impl TieredMemory.capabilities -> set[str] {
    if self.l3 is not None {
        return self.l3.capabilities();
    }
    return set();
}

impl TieredMemory.execute_plan(plan: QueryPlan) -> Generator[Anchor, None, None] {
    if self.l3 is None {
        return;
    }
    for anchor in self.l3.execute_plan(plan) {
        existing = self.__mem__.get(anchor.id);
        if existing is None {
            self.__mem__[anchor.id] = anchor;
            if self.l2 {
                self.l2.put(anchor);
            }
            yield anchor;
        } else {
            yield existing;
        }
    }
}

impl TieredMemory.batch_get(ids: list[UUID]) -> dict[UUID, Anchor] {
    result: dict[UUID, Anchor] = {};
    missing_ids: list[UUID] = [];
    for id in ids {
        if (anchor := self.__mem__.get(id)) {
            result[id] = anchor;
        } else {
            missing_ids.append(id);
        }
    }
    if missing_ids and self.l3 {
        for mid in missing_ids {
            if (anchor := self.l3.get(mid)) {
                self.__mem__[anchor.id] = anchor;
                if self.l2 {
                    self.l2.put(anchor);
                }
                result[anchor.id] = anchor;
            }
        }
    }
    return result;
}
