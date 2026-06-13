"""Memory Hierarchy Implementations.

Implementations for VolatileMemory, LocalCacheMemory, SqliteMemory, and TieredMemory.
"""

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
import from jaclang.jac0core.archetype { Anchor, NodeAnchor, Root }
import from jaclang.runtimelib.changeset {
    ApplyReport,
    ChangeSet,
    WriteIntent,
    derive_dirty_fields,
    snapshot_field_hashes
}
import from jaclang.runtimelib.serializer { Serializer }
import from jaclang.runtimelib.query_plan { QueryPlan }
import from jaclang.runtimelib.typecache { get_field_types }

glob logger = logging.getLogger(__name__),
     # Bumped when the on-disk row layout changes in a way that requires
     # schema migration. Kept in the `schema_meta` table.
     SQLITE_DB_FORMAT_VERSION: int = 1;

# =============================================================================
# Memory — default async mirrors
# =============================================================================
# Every backend inherits these. Default behavior: offload the blocking sync
# op to the default thread pool so the calling event loop stays responsive.
# Backends with a native async driver should override to bypass the thread.
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

# =============================================================================
# Memory — default pushdown protocol
# =============================================================================
# Default: backend declares no native pushdown. The planner sees an empty
# capability set, skips `execute_plan` entirely, and uses the universal floor
# (topology_index narrowing → batch_get). Backends with real native filters
# (Mongo compound index, Postgres jsonb GIN) override both methods.
impl Memory.capabilities -> set[str] {
    return set();
}

impl Memory.execute_plan(plan: QueryPlan) -> Generator[Anchor, None, None] {
    # Default-implementation backends never get called here: the planner
    # gates on `capabilities()` first. If we get called anyway, log it —
    # most likely cause is a backend that declared capabilities but forgot
    # to override execute_plan, which would silently return zero results.
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

"""Convenience wrapper: build a QueryPlan from a type name + optional field
predicates and delegate to `execute_plan`. Returns empty when the backend
doesn't declare the needed capabilities. Backends without native pushdown
should keep using `query()` with a Python-side filter for type-based scans
— this method exists specifically to make the pushdown path ergonomic."""
impl Memory.query_by_type(
    arch_type_name: str, field_filter: (dict | None) = None
) -> Generator[Anchor, None, None] {
    plan = QueryPlan(
        node_type_final=arch_type_name, field_predicates=field_filter or {}
    );
    if not (plan.needs() <= self.capabilities()) {
        return;
    }
    for anchor in self.execute_plan(plan) {
        yield anchor;
    }
}

"""Serialize an anchor to the tuple of columns stored in the anchors table."""
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

"""Return True if the provided sqlite connection has the new anchors schema."""
def _is_new_schema(conn: sqlite3.Connection) -> bool {
    cursor = conn.execute("PRAGMA table_info(anchors)");
    cols = {row[1] for row in cursor.fetchall()};
    # Distinguishing column on the new schema. Legacy has (id, data) only.
    return 'fingerprint' in cols and 'format_version' in cols;
}

"""Return True if the connection has the legacy (id TEXT, data BLOB) schema."""
def _is_legacy_schema(conn: sqlite3.Connection) -> bool {
    cursor = conn.execute("PRAGMA table_info(anchors)");
    rows = cursor.fetchall();
    if not rows {
        return False;
    }
    cols = {row[1] for row in rows};
    return cols == {'id', 'data'};
}

"""Create the anchors + quarantine + schema_meta tables (new schema)."""
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
    # DB-resident alias table. CLI-managed; complements the
    # @archetype_alias decorator (which is code-resident, per-process).
    # DB aliases are merged into Serializer._aliases at connect time so
    # operator-driven rescues work without a code deploy.
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


"""Load all DB-resident aliases into the in-process Serializer registry.

Called at connection-open time. DB aliases merge with decorator-declared
aliases; if both touch the same old_name, the DB entry takes precedence
(the CLI is the operator's rescue path, expected to override a stale
default from code).
"""
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

"""Quarantine a row that failed to deserialize. Never raises.

When quarantining a NodeAnchor, also cascade-quarantine every EdgeAnchor
whose data.source or data.target references this node, then strip those
edge IDs from all remaining live NodeAnchor data.edges arrays. This
prevents dangling edge references after schema drift removes a node type.

`manage_txn=False` is for callers that already hold an open transaction
(apply()'s BEGIN IMMEDIATE): committing here would split their unit of
work in two, so the quarantine rides the caller's transaction instead.
"""
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
        # Cascade: when a NodeAnchor is quarantined, orphan its edges too.
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
                    # Batched delete — one round-trip instead of N.
                    placeholders = ','.join('?' * len(orphan_edge_ids));
                    conn.execute(
                        f"DELETE FROM anchors WHERE id IN ({placeholders})",
                        orphan_edge_ids
                    );
                    # Strip the orphaned edge IDs from live NodeAnchors' data.edges.
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

"""One-shot migration from legacy pickle (id TEXT, data BLOB) to JSON schema.

Called when an existing DB file has the legacy schema but none of the new
tables. Reads every pickle row, re-serializes via Serializer, writes to the
new anchors table. Rows that can't be unpickled or re-serialized are moved
to anchors_quarantine with the raw bytes hex-encoded and the error message.
"""
def _migrate_legacy_pickle_db(conn: sqlite3.Connection) {
    import from pickle { loads as pickle_loads }
    import from _pickle { UnpicklingError }
    logger.warning(
        "SqliteMemory: legacy pickle schema detected; migrating to JSON. "
        "Rows that can't be unpickled will be moved to anchors_quarantine."
    );
    # Snapshot old rows; the table will be rewritten.
    cursor = conn.execute("SELECT id, data FROM anchors");
    old_rows = cursor.fetchall();
    # Rename old table aside so we can build the new one cleanly.
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
            # We intentionally don't store the raw bytes in quarantine for
            # the legacy path — pickle bytes aren't useful to inspect and
            # bloat the DB. Record the fact and the error instead.
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
        f"SqliteMemory: legacy migration complete — "
        f"{migrated} anchors migrated, {quarantined} quarantined."
    );
}

# =============================================================================
# VolatileMemory Implementation (L1)
# =============================================================================
"""Default abort: nothing staged, nothing to discard."""
impl Memory.abort -> None { }

"""Initialize mutable defaults."""
impl VolatileMemory.postinit -> None {
    self.__mem__ = {};
}

"""In-memory storage is always available."""
impl VolatileMemory.is_available -> bool {
    return True;
}

"""Retrieve an anchor by ID."""
impl VolatileMemory.get(id: UUID) -> (Anchor | None) {
    return self.__mem__.get(id);
}

"""Store an anchor."""
impl VolatileMemory.put(anchor: Anchor) -> None {
    self.__mem__[anchor.id] = anchor;
}

"""Remove an anchor by ID."""
impl VolatileMemory.delete(id: UUID) -> None {
    self.__mem__.pop(id, None);
}

"""Close and clear memory."""
impl VolatileMemory.close -> None {
    self.__mem__.clear();
}

"""Check if an anchor is in memory."""
impl VolatileMemory.`has(id: UUID) -> bool {
    return id in self.__mem__;
}

"""Query all anchors with optional filter."""
impl VolatileMemory.query(
    filter: (Callable[[Anchor], bool] | None) = None
) -> Generator[Anchor, None, None] {
    for anchor in self.__mem__.values() {
        if filter is None or filter(anchor) {
            yield anchor;
        }
    }
}

"""Get all root anchors."""
impl VolatileMemory.get_roots -> Generator[Root, None, None] {
    for anchor in self.__mem__.values() {
        if isinstance(anchor.archetype, Root) {
            yield cast(Root, anchor.archetype);
        }
    }
}

"""Find anchors by IDs with optional filter."""
impl VolatileMemory.find(
    ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
) -> Generator[Anchor, None, None] {
    id_list = [ids] if isinstance(ids, UUID) else list(ids);
    for id in id_list {
        if (anchor := self.__mem__.get(id)) {
            if filter is None or filter(anchor) {
                yield anchor;
            }
        }
    }
}

"""Find one anchor by ID(s) with optional filter."""
impl VolatileMemory.find_one(
    ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
) -> (Anchor | None) {
    id_list = [ids] if isinstance(ids, UUID) else list(ids);
    for id in id_list {
        if (anchor := self.__mem__.get(id)) {
            if filter is None or filter(anchor) {
                return anchor;
            }
        }
    }
    return None;
}

"""Get the underlying memory dict."""
impl VolatileMemory.get_mem -> dict[UUID, Anchor] {
    return self.__mem__;
}

"""Commit - no-op for volatile memory."""
impl VolatileMemory.commit(anchor: (Anchor | None) = None) -> None {
# No persistence, nothing to commit
}

# =============================================================================
# LocalCacheMemory Implementation (L2)
# Inherits all Memory interface methods from VolatileMemory.
# Only implements CacheMemory-specific methods.
# =============================================================================
"""Check if a key exists in the cache without loading the value."""
impl LocalCacheMemory.exists(id: UUID) -> bool {
    return id in self.__mem__;
}

"""Store an anchor only if it already exists in the cache."""
impl LocalCacheMemory.put_if_exists(anchor: Anchor) -> bool {
    if anchor.id in self.__mem__ {
        self.__mem__[anchor.id] = anchor;
        return True;
    }
    return False;
}

"""Invalidate a cache entry by ID."""
impl LocalCacheMemory.invalidate(id: UUID) -> None {
    self.__mem__.pop(id, None);
}

# =============================================================================
# SqliteMemory Implementation (L3 Persistent)
# =============================================================================
"""Initialize SqliteMemory with a file path (lazy - no DB created yet)."""
impl SqliteMemory.postinit -> None {
    self.__mem__ = {};
    # Connection is lazily initialized on first write
    self.__conn__ = None;
    # Serializes access to the sqlite3 connection. The connection is opened
    # with check_same_thread=False so it can be reached from worker threads
    # via asyncio.to_thread (Memory.aget/acommit/etc). Python's sqlite3
    # module is not thread-safe for a shared connection — concurrent
    # sync() calls collide on BEGIN IMMEDIATE ("cannot start a transaction
    # within a transaction") and cursor state touched from multiple
    # threads can raise InterfaceError. RLock so that a caller already
    # holding the lock (e.g. sync() calling _quarantine) can re-enter.
    self.__lock__ = threading.RLock();
    self.l3_fetch_count = 0;
}

"""Lazily initialize SQLite connection when first needed.

Creates the new JSON-based schema. If an existing DB uses the legacy
pickle schema (id TEXT, data BLOB), migrates all rows in-place before
returning.
"""
impl SqliteMemory._ensure_connection -> None {
    if self.__conn__ is not None {
        return;
    }
    # Ensure parent directory exists for database file
    parent_dir = os.path.dirname(self.path);
    if parent_dir {
        os.makedirs(parent_dir, exist_ok=True);
    }
    # Open SQLite connection with WAL mode for better concurrency
    self.__conn__ = sqlite3.connect(self.path, check_same_thread=False);
    self.__conn__.execute("PRAGMA journal_mode=WAL");
    self.__conn__.execute("PRAGMA synchronous=NORMAL");
    # Detect schema state: new, legacy pickle, or empty.
    if _is_new_schema(self.__conn__) {
        # Already migrated — ensure quarantine + meta + aliases tables exist
        # in case the DB was opened by an older client before this version
        # (CREATE TABLE IF NOT EXISTS is idempotent).
        _create_new_schema(self.__conn__);
    } elif _is_legacy_schema(self.__conn__) {
        _migrate_legacy_pickle_db(self.__conn__);
    } else {
        _create_new_schema(self.__conn__);
    }
    # Merge DB-resident aliases into Serializer._aliases so CLI-managed
    # rescues apply automatically on the next read.
    _load_db_aliases(self.__conn__);
}

"""Check if database connection is available."""
impl SqliteMemory.is_available -> bool {
    return self.__conn__ is not None;
}

"""Get an anchor by ID. Check memory first, then database.

On deserialization failure, the row is moved to anchors_quarantine
(never deleted outright) so data can be inspected and recovered later.
Fingerprint drift is logged but does not block deserialization — the
Serializer tolerates added/removed fields by design.
"""
impl SqliteMemory.get(id: UUID) -> (Anchor | None) {
    # Check in-memory cache first
    if (anchor := self.__mem__.get(id)) {
        return anchor;
    }
    with self.__lock__ {
        # Lazily connect if DB file exists (for reading existing data)
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
        # Fingerprint drift check — informational only. The serializer already
        # tolerates added/removed fields; type changes will surface as
        # deserialize exceptions below.
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

"""Store an anchor: cache it in the working set and write the row through.
A direct backend put is a seeding/administrative write that bypasses the
unit-of-work; the runtime never calls l3.put() — its graph mutations flow
through commit() -> apply() exclusively (one merge-aware transaction per
unit of work; issues #5446, #6587)."""
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
            # Anchors that can't be serialized (e.g. transient test classes)
            # stay cache-only, matching the legacy skip.
            return;
        } except Exception as e {
            logger.warning(
                f"SqliteMemory.put: failed to persist {anchor.id}: "
                f"{type(e).__name__}: {e}"
            );
        }
    }
}

"""Drop an anchor from this store's working set. The database row is only
removed by apply() executing a delete intent, in dependency order with the
edge-list repairs that must precede it — never inline (issue #6587)."""
impl SqliteMemory.delete(id: UUID) -> None {
    self.__mem__.pop(id, None);
}

"""Close database connection. Flushing is the runtime's job (commit ->
apply); close must not write — a closed-but-uncommitted unit of work is
discarded, which is what abort semantics require."""
impl SqliteMemory.close -> None {
    if self.__conn__ {
        self.__conn__.close();
        self.__conn__ = None;
    }
    self.__mem__.clear();
}

"""Check if an anchor is in memory or database."""
impl SqliteMemory.`has(id: UUID) -> bool {
    if id in self.__mem__ {
        return True;
    }
    with self.__lock__ {
        # Lazily connect if DB file exists
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

"""Query all anchors with optional filter."""
impl SqliteMemory.query(
    filter: (Callable[[Anchor], bool] | None) = None
) -> Generator[Anchor, None, None] {
    for anchor in self.__mem__.values() {
        if filter is None or filter(anchor) {
            yield anchor;
        }
    }
}

"""Get all root anchors — the in-process working set plus rows on disk.

Scanning only `__mem__` would make a freshly-opened SqliteMemory (e.g. the L3
tier of a new server request) report only the roots it had itself loaded,
silently hiding every root persisted by other requests/users. The disk scan
reads anchor metadata cheaply, resolves Root (sub)classes without
deserializing payloads, and only loads the rows that are actually roots.
"""
impl SqliteMemory.get_roots -> Generator[Root, None, None] {
    seen: set[UUID] = set();
    # In-process working set: includes roots not yet synced to disk.
    for anchor in list(self.__mem__.values()) {
        if isinstance(anchor.archetype, Root) {
            seen.add(anchor.id);
            yield cast(Root, anchor.archetype);
        }
    }
    # Persisted rows on disk that have not been loaded into this session.
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

"""Find anchors by IDs with optional filter."""
impl SqliteMemory.find(
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

"""Find one anchor by ID(s) with optional filter."""
impl SqliteMemory.find_one(
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

"""Serialize an object to canonical JSON for equality comparison."""
def _canonical_json(val: object) -> str {
    return json.dumps(
        Serializer.serialize(val, include_type=True),
        sort_keys=True,
        default=lambda v: str : str(v)
    );
}

"""Flush a unit of work inside one BEGIN IMMEDIATE transaction.

A transactional backend: the staged order from the changeset is a no-op
for crash-safety here (the transaction is all-or-nothing), but executing
it keeps one code path with non-transactional backends. Access decisions
were made by the runtime's collect pass — this method only executes
intents. Per-intent serialization failures are skipped (with their
dependents poisoned) exactly like the legacy sync did for transient
classes; transaction-level failures roll the whole unit back.
"""
impl SqliteMemory.apply(changeset: ChangeSet) -> ApplyReport {
    apply_report = ApplyReport();
    if changeset.is_empty() {
        return apply_report;  # Nothing to flush, don't create the DB
    }
    with self.__lock__ {
        self._ensure_connection();
        assert self.__conn__ is not None;
        conn = self.__conn__;
        # Commit any implicit transaction first, then start an explicit one.
        conn.commit();
        try {
            conn.execute("BEGIN IMMEDIATE");
            poisoned: set[UUID] = set();
            for stage in changeset.staged() {
                for intent in stage {
                    if (deps := intent.depends_on & poisoned) {
                        # Proceeding would mint a dangling reference (e.g.
                        # a node delete after a failed edge delete).
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
                    } except (AttributeError, ModuleNotFoundError) as se {
                        # Anchors that can't be serialized (e.g. transient
                        # test classes) are skipped, not fatal.
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
            conn.commit();
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

"""Execute one intent: deletes remove the row; everything else is a
merge-aware write against the stored row."""
impl SqliteMemory._apply_one(conn: sqlite3.Connection, intent: WriteIntent) -> None {
    if intent.is_delete() {
        conn.execute("DELETE FROM anchors WHERE id = ?", (str(intent.anchor.id), ));
        return;
    }
    self._merge_write(conn, intent);
}

"""Merge-aware write (cross-process safety, issue #5446): read the stored
row, apply this unit's edge delta / dirty fields / access / topology-index
changes onto it, and write the merged result. A concurrent writer's edges
survive because the delta is applied to the DB-current list, not ours."""
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
            # apply() holds the BEGIN IMMEDIATE: the quarantine must ride
            # that transaction, not commit it mid-flush.
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
        # Merge edge lists: apply this unit's delta to the DB-current list
        # so a concurrent writer's edges survive.
        if (
            isinstance(stored_anchor, NodeAnchor)
            and isinstance(anchor, NodeAnchor)
            and stored_anchor.edges != anchor.edges
        ) {
            delta = anchor.edge_delta();
            if delta is not None {
                edges_added = set(delta[0]);
                edges_removed = set(delta[1]);
                stored_set = set(e.id for e in stored_anchor.edges);
                merged_ids = (stored_set | edges_added) - edges_removed;
                edge_by_id = {e.id: e for e in stored_anchor.edges};
                edge_by_id.update({e.id: e for e in anchor.edges});
                stored_anchor.edges = [
                    edge_by_id[eid]
                    for eid in merged_ids
                    if eid in edge_by_id
                ];
            } else {
                stored_anchor.edges = anchor.edges;
            }
            if (not stored_anchor.edges and not isinstance(anchor.archetype, Root)) {
                conn.execute("DELETE FROM anchors WHERE id = ?", (key, ));
                return;
            }
            changed = True;
        }
        # Topology index is a derived adjacency cache on root NodeAnchors,
        # updated by edges anywhere in the subtree — not an archetype field,
        # so the edge merge and field merge don't catch it.
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
        # Merge dirty fields. A full write (create intent) copies every
        # field; otherwise only the fields the collect pass flagged.
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
        # No stored row (or stored is a stub): write the anchor whole.
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

"""Get the underlying memory dict."""
impl SqliteMemory.get_mem -> dict[UUID, Anchor] {
    return self.__mem__;
}

"""Commit — a backend has no unit of work of its own; flushing happens via
apply() driven by the runtime (TieredMemory.commit)."""
impl SqliteMemory.commit(anchor: (Anchor | None) = None) -> None { }

# =============================================================================
# SqliteMemory: Layer 1+2+3 operator surface
# =============================================================================
"""Helper: attempt to re-deserialize one quarantined row, re-stamped with the
live class's identity + fingerprint on success. Returns (ok, reason)."""
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
    # Re-stamp with live class metadata so subsequent reads bypass alias
    # resolution and drift-detection logging.
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
    # Re-link: when recovering an EdgeAnchor that was cascade-quarantined, the
    # connected node(s)' data.edges was stripped. Re-add the edge ID to the
    # source (always) and also to the target for undirected edges.
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


"""Summary dict for `jac db inspect`."""
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


"""List recent quarantined rows."""
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


"""Full detail of one quarantined row (by id or unique prefix)."""
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


"""Recover a single quarantined row (or unique prefix)."""
impl SqliteMemory.recover_one(id_prefix: str) -> tuple {
    self._ensure_connection();
    assert self.__conn__ is not None;
    conn = self.__conn__;
    # Pull in DB-resident aliases so CLI-added rescues apply.
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


"""Recover every quarantined row; return (n_recovered, [(id, reason)...])."""
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
    # Process NodeAnchors before EdgeAnchors so re-link finds live nodes.
    rows.sort(key=lambda r : 0 if r[1] == 'NodeAnchor' else 1);
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


"""List DB-resident aliases."""
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


"""Add (or replace) an alias; merge into the in-process Serializer map."""
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


"""Remove an alias. Returns True if an entry was deleted."""
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

# =============================================================================
# TieredMemory Implementation (extends VolatileMemory with L2 + L3)
# Inherits L1 functionality (__mem__) from VolatileMemory.
# Only overrides methods that need tiering logic.
# =============================================================================
"""Initialize TieredMemory with optional cache and persistence."""
impl TieredMemory.postinit -> None {
    import from jaclang.runtimelib.memory { LocalCacheMemory, SqliteMemory }
    import from jaclang.runtimelib.utils { get_db_path }
    # Initialize L1 (inherited from VolatileMemory)
    self.__mem__ = {};
    # The request's unit of work (typed write intents).
    self.changes = ChangeSet();
    # Initialize L2 cache if requested
    if self.use_cache {
        self.l2 = LocalCacheMemory();
    } else {
        self.l2 = None;
    }
    # Initialize L3 persistence if base_path provided
    if self.base_path {
        # Use project.db for projects, filename.db for standalone apps.
        # `target_path` is the per-context app identity — without it,
        # `get_db_path` would fall back to `Jac.get_full_target_path()`
        # (the bootstrap seed), which can leak across in-process clients
        # (see context.impl.jac for the rationale).
        db_path = get_db_path(self.base_path, target_path=self.target_path);
        self.l3 = SqliteMemory(path=db_path);
    } else {
        self.l3 = None;
    }
}

"""Get anchor with read-through: L1 -> L2 -> L3 with promotion."""
impl TieredMemory.get(id: UUID) -> (Anchor | None) {
    # L1 hit (self.__mem__ inherited from VolatileMemory)
    if (anchor := self.__mem__.get(id)) {
        return anchor;
    }
    # L2 hit with promotion to L1
    if self.l2 and (anchor := self.l2.get(id)) {
        self.__mem__[anchor.id] = anchor;
        return anchor;
    }
    # L3 fallback with promotion to L1 (and L2 if enabled)
    if self.l3 and (anchor := self.l3.get(id)) {
        self.__mem__[anchor.id] = anchor;
        if self.l2 {
            self.l2.put(anchor);
        }
        return anchor;
    }
    return None;
}

"""Put anchor into L1 (and L2 cache). L3 is never written here: graph
mutations reach storage only through commit() -> apply(), where the
collect pass decides what changed and access control gates each intent."""
impl TieredMemory.put(anchor: Anchor) -> None {
    self.__mem__[anchor.id] = anchor;
    if self.l2 {
        self.l2.put(anchor);
    }
}

"""Enumerate roots across every tier — the basis for the `allroots()` builtin.

L1 (this request's working set) holds roots created or mutated in-flight; L3
(the shared persistent store) holds every root ever committed by any
request/user. Without merging L3 in, `allroots()` would see only the caller's
own root and every cross-user query would silently degrade to single-user.

L2 is intentionally skipped: it is a partial cache whose entries are always
also present in L1 or L3. Results are de-duplicated by archetype identity —
when a root is resident in more than one tier every tier hands back the same
anchor object, so the L1 copy (with any uncommitted mutations) wins.
"""
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

"""Delete becomes an intent, not an I/O call. The L3 row is removed at
commit, in dependency order with the edge-list repairs that must precede
it — never inline. An inline delete opens a crash window spanning the rest
of the request in which the persisted graph holds references to documents
that no longer exist (issue #6587), and it makes `del` the one mutation
that abandoning a failed request cannot undo."""
impl TieredMemory.delete(id: UUID) -> None {
    anchor: (Anchor | None) = self.__mem__.pop(id, None);
    if anchor is None and self.l3 is not None {
        # Deleting something never loaded this request: fetch the anchor so
        # the delete intent can wire its dependencies.
        anchor = self.l3.get(id);
    }
    if self.l3 is not None {
        # Drop the backend's cached copy so a re-get within this request
        # cannot resurrect the deleted anchor. Durable removal happens at
        # commit via apply(), never here.
        self.l3.delete(id);
    }
    if self.l2 {
        self.l2.invalidate(id);
    }
    if anchor is not None and anchor.persistent {
        self.changes.record_delete(anchor);
    }
}

"""Close all tiers. Pending work is committed first — this is the backstop
that persists CLI runs (`jac run` flows end at close, not at an explicit
commit). A failed request must abort() before close to discard its work."""
impl TieredMemory.close -> None {
    self.commit();
    if self.l3 {
        self.l3.close();
    }
    if self.l2 {
        self.l2.close();
    }
    # Clear L1 (inherited from VolatileMemory)
    self.__mem__.clear();
    self.changes.clear();
}

"""Check if anchor exists in any tier."""
impl TieredMemory.`has(id: UUID) -> bool {
    # Check L1 first
    if id in self.__mem__ {
        return True;
    }
    # Check L2 cache
    if self.l2 and self.l2.exists(id) {
        return True;
    }
    # Check L3 persistence
    if self.l3 and self.l3.`has(id) {
        return True;
    }
    return False;
}

"""Get L3 fetch count for testing/instrumentation."""
impl TieredMemory.get_l3_fetch_count -> int {
    import from jaclang.runtimelib.memory { SqliteMemory }
    if isinstance(self.l3, SqliteMemory) {
        return self.l3.l3_fetch_count;
    }
    return 0;
}

"""Reset L3 fetch count for testing/instrumentation."""
impl TieredMemory.reset_l3_fetch_count -> None {
    import from jaclang.runtimelib.memory { SqliteMemory }
    if isinstance(self.l3, SqliteMemory) {
        self.l3.l3_fetch_count = 0;
    }
}

"""Commit the unit of work: collect L1 dirtiness into intents, flush them
through the backend's apply(), then refresh change-tracking baselines."""
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
}

"""Collect the working set's dirtiness into the unit of work. This is the
single home of the WHAT-changed decision logic (whole-anchor hash gate,
edge deltas, per-field dirtiness) and of access control: creates and field
writes need WRITE access, edge-list changes need CONNECT access. Backends
never decide — they execute intents."""
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
            continue;  # Unchanged since last load/persist.
        }
        if anchor.hash == 0 {
            # Brand new. Edgeless non-root nodes are not persisted (legacy
            # rule: an unreachable node is garbage, not data).
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
            # An edge delta was recorded, but with no field-hash snapshot
            # derive_dirty_fields() is blind: "no dirty fields" cannot be
            # trusted (e.g. an anchor loaded through a tier that didn't
            # snapshot). Put every field on the intent so a mutation hiding
            # behind the edge delta isn't silently dropped — record_update
            # keeps the merge-aware EDGE_LIST_DELTA write (a record_create
            # upgrade would move this anchor to stage 0, ahead of the edge
            # docs its new edge list cites).
            changes.record_update(
                anchor, set(get_field_types(type(anchor.archetype)).keys())
            );
        }
        if not recorded {
            # Hash changed but no per-field/edge signal (access grants,
            # topology-index blob, containers without a snapshot): full
            # merged rewrite.
            if Jac.check_write_access(anchor, op_hint="field_write") {
                changes.record_create(anchor);
            }
        }
    }
}

"""After a flush, re-baseline change tracking for every applied intent so
the next commit sees these anchors as clean: whole-anchor hash, per-field
hash snapshot, and the edge-list baseline that feeds edge_delta()."""
impl TieredMemory._post_apply(apply_report: ApplyReport) -> None {
    applied = set(apply_report.applied);
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
            }
        } except Exception as e {
            logger.debug(f"post-apply re-baseline failed for {anchor.id}: {e}");
        }
    }
}

"""Discard the uncommitted unit of work: drop pending intents and evict
dirty anchors from L1/L2 so a later commit (or the close-time backstop)
cannot re-collect the failed request's mutations. Evicted anchors reload
clean from L3 on next touch."""
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
                # Drop the backend's cached copy too, so a re-get reloads
                # the committed state instead of the aborted mutation.
                self.l3.delete(id);
            }
        }
    }
}

"""TieredMemory capabilities mirror L3 — that's where pushdown lives. L1/L2
exist for cache hits, not for query planning."""
impl TieredMemory.capabilities -> set[str] {
    if self.l3 is not None {
        return self.l3.capabilities();
    }
    return set();
}

"""Delegate pushdown to L3 and promote loaded anchors into L1 so subsequent
gets are cache hits (same pattern as `batch_get`)."""
impl TieredMemory.execute_plan(plan: QueryPlan) -> Generator[Anchor, None, None] {
    if self.l3 is None {
        return;
    }
    for anchor in self.l3.execute_plan(plan) {
        # Promote to L1 unless already there
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

"""Batch get: check L1, then load L3 misses, promote all to L1/L2."""
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
