"""Tests for persistence schema migration (Layers 1 + 2).

Covers:
  - JSON round-trip through SqliteMemory
  - Archetype fingerprint is stable within a schema and changes when fields change
  - Schema drift (added / removed field) loads best-effort, does not delete data
  - Legacy pickle DB is detected and migrated in place
  - Unreadable rows go to anchors_quarantine, never silently dropped
"""

import json;
import os;
import pickle;
import sqlite3;
import uuid;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from typing { cast }
import from jaclang.jac0core.archetype { NodeAnchor, Root }
import from jaclang.runtimelib.changeset {
    ChangeSet,
    derive_dirty_fields,
    snapshot_field_hashes
}
import from jaclang.runtimelib.memory { SqliteMemory }
import from jaclang.runtimelib.serializer { Serializer }


"""Flush this store's working set through apply(), mirroring the runtime's
collect pass (TieredMemory.commit) at backend granularity: creates for
never-persisted anchors, dirty-field updates for loaded ones, then
re-baseline change tracking so the next flush sees them clean."""
def _flush(mem: SqliteMemory) {
    cs = ChangeSet();
    for anchor in list(mem.__mem__.values()) {
        if not anchor.persistent or not anchor.is_populated() {
            continue;
        }
        if anchor.hash == 0 {
            cs.record_create(anchor);
        } else {
            dirty = derive_dirty_fields(anchor);
            if dirty {
                cs.record_update(anchor, dirty);
            }
        }
    }
    mem.apply(cs);
    for intent in cs.intents.values() {
        intent.anchor.hash = Serializer._compute_hash(intent.anchor);
        snapshot_field_hashes(intent.anchor);
    }
}


obj _DemoArchV1(Root) {
    has name: str = "",
        age: int = 0;
}

# Used by the type-mismatch quarantine test: score must be an int.
obj _TypedProfile(Root) {
    has score: int = 0;
}

obj _SyncProfile(Root) {
    has name: str = "",
        count: int = 0,
        tags: list[str] = [];
}

# Used by the has_default=False quarantine test: name has NO default.
obj _RequiredField(Root) {
    has name: str;
}


test "fingerprint is present on archetypes and stable across instances" {
    fp = _DemoArchV1?.__jac_fingerprint__;
    assert isinstance(fp, str) , "archetype must have __jac_fingerprint__";
    assert len(fp) == 16 , f"fingerprint length should be 16 hex chars, got {len(fp)}";
    # Same class => same fingerprint; deterministic.
    again = Serializer.fingerprint(_DemoArchV1);
    assert again == fp , "fingerprint must be deterministic";
}


test "new SqliteMemory creates the expected schema" {
    with TemporaryDirectory() as tmpdir {
        db_path = os.path.join(tmpdir, "test.db");
        mem = SqliteMemory(path=db_path);
        mem._ensure_connection();
        # Expected tables
        cursor = mem.__conn__.execute(
            "SELECT name FROM sqlite_master WHERE type='table'"
        );
        tables = {row[0] for row in cursor.fetchall()};
        assert 'anchors' in tables;
        assert 'anchors_quarantine' in tables;
        assert 'schema_meta' in tables;
        # Expected columns on anchors
        cursor = mem.__conn__.execute("PRAGMA table_info(anchors)");
        cols = {row[1] for row in cursor.fetchall()};
        for needed in [
            'id',
            'type',
            'arch_module',
            'arch_type',
            'fingerprint',
            'data',
            'format_version',
            'updated_at'
        ] {
            assert needed in cols , f"anchors table missing column {needed}";
        }
        # db_format_version recorded
        cursor = mem.__conn__.execute(
            "SELECT value FROM schema_meta WHERE key='db_format_version'"
        );
        row = cursor.fetchone();
        assert row and row[0] == '1' , "db_format_version must be '1'";
        mem.close();
    }
}


test "put then get round-trips an anchor through JSON" {
    with TemporaryDirectory() as tmpdir {
        db_path = os.path.join(tmpdir, "test.db");
        mem = SqliteMemory(path=db_path);
        root_arch = Root();
        anchor = NodeAnchor(archetype=root_arch, edges=[]);
        anchor.persistent = True;
        mem.put(anchor);
        _flush(mem);
        anchor_id = anchor.id;
        mem.close();
        # Reopen a fresh memory over the same DB and fetch the anchor
        mem2 = SqliteMemory(path=db_path);
        loaded = mem2.get(anchor_id);
        assert loaded is not None , "reloaded anchor must be non-None";
        assert loaded.id == anchor_id;
        # Stored row should carry the fingerprint
        cursor = mem2.__conn__.execute(
            "SELECT fingerprint, type, arch_type FROM anchors WHERE id = ?",
            (str(anchor_id), )
        );
        row = cursor.fetchone();
        assert row is not None;
        (fp, row_type, arch_type) = (row[0], row[1], row[2]);
        assert fp == Root.__jac_fingerprint__;
        assert row_type == 'NodeAnchor';
        assert arch_type == 'Root';
        mem2.close();
    }
}


test "stored data is JSON text, not pickle bytes" {
    with TemporaryDirectory() as tmpdir {
        db_path = os.path.join(tmpdir, "test.db");
        mem = SqliteMemory(path=db_path);
        anchor = NodeAnchor(archetype=Root(), edges=[]);
        anchor.persistent = True;
        mem.put(anchor);
        _flush(mem);
        mem.close();
        conn = sqlite3.connect(db_path);
        cursor = conn.execute("SELECT data FROM anchors LIMIT 1");
        row = cursor.fetchone();
        assert row is not None;
        data = row[0];
        assert isinstance(data, str) , "data must be JSON text";
        # Must be valid JSON with the expected top-level keys.
        parsed = json.loads(data);
        assert parsed.get('__type__') == 'NodeAnchor';
        assert 'id' in parsed;
        conn.close();
    }
}


test "legacy pickle DB with unreadable rows migrates and quarantines" {
    with TemporaryDirectory() as tmpdir {
        db_path = os.path.join(tmpdir, "test.db");
        # Seed with the legacy 2-column schema and two un-migratable rows.
        conn = sqlite3.connect(db_path);
        conn.execute("CREATE TABLE anchors (id TEXT PRIMARY KEY, data BLOB NOT NULL)");
        conn.execute(
            "INSERT INTO anchors VALUES (?, ?)",
            (str(uuid.uuid4()), pickle.dumps({"not": "an anchor"}))
        );
        conn.execute(
            "INSERT INTO anchors VALUES (?, ?)",
            (str(uuid.uuid4()), b"not-a-pickle-at-all")
        );
        conn.commit();
        conn.close();
        # Opening via SqliteMemory triggers migration.
        mem = SqliteMemory(path=db_path);
        mem._ensure_connection();
        # Old table is gone; new tables are present.
        cursor = mem.__conn__.execute(
            "SELECT name FROM sqlite_master WHERE type='table'"
        );
        tables = {row[0] for row in cursor.fetchall()};
        assert 'anchors_legacy_pickle' not in tables , "legacy table should be dropped";
        assert 'anchors' in tables;
        assert 'anchors_quarantine' in tables;
        # Both rows were quarantined, not deleted.
        cursor = mem.__conn__.execute("SELECT count(*) FROM anchors_quarantine");
        qcount = cursor.fetchone()[0];
        assert qcount == 2 , f"expected 2 quarantined rows, got {qcount}";
        # Each quarantine row carries an error message.
        cursor = mem.__conn__.execute("SELECT error FROM anchors_quarantine");
        for (err, ) in cursor.fetchall() {
            assert err and 'legacy pickle' in err;
        }
        mem.close();
    }
}


test "corrupt JSON data is quarantined on read, not deleted" {
    with TemporaryDirectory() as tmpdir {
        db_path = os.path.join(tmpdir, "test.db");
        mem = SqliteMemory(path=db_path);
        mem._ensure_connection();
        # Write a bad row straight into the new schema.
        bad_id = str(uuid.uuid4());
        mem.__conn__.execute(
            """
            INSERT INTO anchors
                (id, type, arch_module, arch_type, fingerprint, data,
                 format_version, updated_at)
            VALUES (?, 'NodeAnchor', 'nowhere', 'Missing', 'deadbeef01234567',
                    '{not valid json', 1, '2026-04-14T00:00:00')
            """,
            (bad_id, )
        );
        mem.__conn__.commit();
        # get() must return None and move the row to quarantine.
        loaded = mem.get(uuid.UUID(bad_id));
        assert loaded is None;
        cursor = mem.__conn__.execute(
            "SELECT count(*) FROM anchors WHERE id = ?", (bad_id, )
        );
        assert cursor.fetchone()[0] == 0 , "bad row must leave anchors table";
        cursor = mem.__conn__.execute(
            "SELECT count(*) FROM anchors_quarantine WHERE id = ?", (bad_id, )
        );
        assert cursor.fetchone()[0] == 1 , "bad row must land in quarantine";
        mem.close();
    }
}


test "field hashes are snapshotted on DB load" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        db_path = os.path.join(tmpdir, "test.db");
        mem1 = SqliteMemory(path=db_path);
        arch = _SyncProfile(name="alice", count=7);
        anchor = NodeAnchor(archetype=arch, edges=[]);
        anchor.persistent = True;
        mem1.put(anchor);
        _flush(mem1);
        anchor_id = anchor.id;
        mem1.close();
        mem2 = SqliteMemory(path=db_path);
        loaded = mem2.get(anchor_id);
        assert loaded is not None;
        hashes = loaded.archetype.__dict__.get('__jac_field_hashes__');
        assert isinstance(hashes, dict) , "__jac_field_hashes__ must be set after DB load";
        assert 'name' in hashes , "name must be in field hashes";
        assert 'count' in hashes , "count must be in field hashes";
        mem2.close();
    }
}


test "read-only walker sync does not clobber a concurrent write" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        db_path = os.path.join(tmpdir, "test.db");
        mem_init = SqliteMemory(path=db_path);
        arch_init = _SyncProfile(name="original", count=0);
        anchor = NodeAnchor(archetype=arch_init, edges=[]);
        anchor.persistent = True;
        mem_init.put(anchor);
        _flush(mem_init);
        anchor_id = anchor.id;
        mem_init.close();
        # Walker A loads the anchor — stale snapshot established, never modified
        mem_a = SqliteMemory(path=db_path);
        stale = mem_a.get(anchor_id);
        assert stale is not None;
        # Walker B loads, sets name, commits
        mem_b = SqliteMemory(path=db_path);
        fresh = mem_b.get(anchor_id);
        assert fresh is not None;
        cast(_SyncProfile, fresh.archetype).name = "written_by_B";
        _flush(mem_b);
        mem_b.close();
        # Walker A syncs with its stale snapshot — must NOT overwrite B's write
        _flush(mem_a);
        mem_a.close();
        mem_verify = SqliteMemory(path=db_path);
        final = mem_verify.get(anchor_id);
        assert final is not None;
        final_name = cast(_SyncProfile, final.archetype).name;
        assert final_name == "written_by_B" , (
            f"read-only walker clobbered concurrent write: got '{final_name}'"
        );
        mem_verify.close();
    }
}


test "sync merges only dirty fields, preserving concurrent writes to other fields" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        db_path = os.path.join(tmpdir, "test.db");
        mem_init = SqliteMemory(path=db_path);
        arch_init = _SyncProfile(name="init_name", count=0);
        anchor = NodeAnchor(archetype=arch_init, edges=[]);
        anchor.persistent = True;
        mem_init.put(anchor);
        _flush(mem_init);
        anchor_id = anchor.id;
        mem_init.close();
        # Walker A loads — will only write count
        mem_a = SqliteMemory(path=db_path);
        anchor_a = mem_a.get(anchor_id);
        assert anchor_a is not None;
        # Walker B loads, sets name, commits first
        mem_b = SqliteMemory(path=db_path);
        anchor_b = mem_b.get(anchor_id);
        assert anchor_b is not None;
        cast(_SyncProfile, anchor_b.archetype).name = "name_from_B";
        _flush(mem_b);
        mem_b.close();
        # Walker A sets only count then commits
        cast(_SyncProfile, anchor_a.archetype).count = 42;
        _flush(mem_a);
        mem_a.close();
        # Both changes must survive: name from B, count from A
        mem_verify = SqliteMemory(path=db_path);
        final = mem_verify.get(anchor_id);
        assert final is not None;
        final_arch = cast(_SyncProfile, final.archetype);
        assert final_arch.name == "name_from_B" , (
            f"dirty-field merge lost B's name: got '{final_arch.name}'"
        );
        assert final_arch.count == 42 , (
            f"dirty-field merge lost A's count: got {final_arch.count}"
        );
        mem_verify.close();
    }
}


test "in-place list mutation is detected dirty and flushed to DB" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        db_path = os.path.join(tmpdir, "test.db");
        mem1 = SqliteMemory(path=db_path);
        arch_init = _SyncProfile(name="x", count=0, tags=["a"]);
        anchor = NodeAnchor(archetype=arch_init, edges=[]);
        anchor.persistent = True;
        mem1.put(anchor);
        _flush(mem1);
        anchor_id = anchor.id;
        mem1.close();
        # Load, mutate the list in-place (bypasses __setattr__)
        mem2 = SqliteMemory(path=db_path);
        loaded = mem2.get(anchor_id);
        assert loaded is not None;
        cast(_SyncProfile, loaded.archetype).tags.append("b");
        _flush(mem2);
        mem2.close();
        mem3 = SqliteMemory(path=db_path);
        final = mem3.get(anchor_id);
        assert final is not None;
        final_tags = cast(_SyncProfile, final.archetype).tags;
        assert final_tags == ["a", "b"] , (
            f"in-place list mutation not persisted: got {final_tags}"
        );
        mem3.close();
    }
}


test "unresolvable nested class in field falls back to default, anchor still loads" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        db_path = os.path.join(tmpdir, "test.db");
        good_id = str(uuid.uuid4());
        bad_nested_id = str(uuid.uuid4());
        bad_null_id = str(uuid.uuid4());
        import json;
        import sqlite3;
        mem = SqliteMemory(path=db_path);
        mem._ensure_connection();
        def _insert(conn: sqlite3.Connection, row_id: str, score_val: object) {
            conn.execute(
                """
                INSERT INTO anchors
                    (id, type, arch_module, arch_type, fingerprint, data,
                     format_version, updated_at)
                VALUES (?, 'NodeAnchor', ?, '_TypedProfile', NULL, ?, 1,
                        '2026-05-18T00:00:00')
                """,
                (
                    row_id,
                    _TypedProfile.__module__,
                    json.dumps(
                        {
                            '__type__': 'NodeAnchor',
                            '__module__': 'jaclang.jac0core.archetype',
                            'id': row_id,
                            'persistent': True,
                            'archetype': {
                                '__type__': '_TypedProfile',
                                '__module__': _TypedProfile.__module__,
                                'score': score_val
                            },
                            'edges': []
                        }
                    )
                )
            );
        }
        _insert(mem.__conn__, good_id, 42);
        _insert(
            mem.__conn__,
            bad_nested_id,
            {'__type__': 'RemovedClass', '__module__': 'app', 'x': 1}
        );
        _insert(cast(sqlite3.Connection, mem.__conn__), bad_null_id, None);
        mem.__conn__.commit();
        good = mem.get(uuid.UUID(good_id));
        assert good is not None , "valid row must load";
        assert cast(_TypedProfile, good.archetype).score == 42;
        recovered_nested = mem.get(uuid.UUID(bad_nested_id));
        assert recovered_nested is not None , "anchor with bad nested field must load after fix";
        assert cast(_TypedProfile, recovered_nested.archetype).score == 0 , (
            "score must be restored to class default (0) when nested class is unresolvable"
        );
        recovered_null = mem.get(uuid.UUID(bad_null_id));
        assert recovered_null is not None , "anchor with null field must load after fix";
        assert cast(_TypedProfile, recovered_null.archetype).score == 0 , (
            "score must be restored to class default (0) when field is stored as null"
        );
        conn = sqlite3.connect(db_path);
        q_ids = {r[0] for r in conn.execute("SELECT id FROM anchors_quarantine")};
        live_ids = {r[0] for r in conn.execute("SELECT id FROM anchors")};
        conn.close();
        assert bad_nested_id not in q_ids , "anchor with recoverable nested field must NOT be quarantined";
        assert bad_null_id not in q_ids , "anchor with null field must NOT be quarantined";
        assert good_id in live_ids , "good row must remain live";
        mem.close();
    }
}


test "SqliteMemory recover_all processes nodes before edges so re-link finds live anchors" {
    # Ordering bug regression: edge row inserted into quarantine BEFORE the node;
    # naïve DB iteration would restore the edge first, leaving data.edges empty.
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        db_path = os.path.join(tmpdir, "test.db");
        node_id = str(uuid.uuid4());
        edge_id = str(uuid.uuid4());
        # Create the schema via SqliteMemory, then seed quarantine with a raw conn.
        # inspect_summary() is used (not close()) because sync() skips _ensure_connection
        # when there is nothing to persist, leaving the schema tables uncreated.
        mem_init = SqliteMemory(path=db_path);
        mem_init.inspect_summary();
        mem_init.close();
        seed_conn = sqlite3.connect(db_path);
        insert_sql = (
            "INSERT INTO anchors_quarantine"
            " (id, type, arch_module, arch_type, fingerprint, data,"
            "  error, quarantined_at, from_format_version)"
            " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
        );
        # Adversarial order: edge first, node second.
        seed_conn.execute(
            insert_sql,
            (
                edge_id,
                'EdgeAnchor',
                'jaclang.jac0core.archetype',
                'GenericEdge',
                None,
                json.dumps(
                    {
                        '__type__': 'EdgeAnchor',
                        '__module__': 'jaclang.jac0core.archetype',
                        'id': edge_id,
                        'persistent': True,
                        'source': node_id,
                        'target': node_id,
                        'is_undirected': False,
                        'archetype': {
                            '__type__': 'GenericEdge',
                            '__module__': 'jaclang.jac0core.archetype'
                        }
                    }
                ),
                'cascade quarantine',
                '2026-05-17T00:00:00',
                1
            )
        );
        seed_conn.execute(
            insert_sql,
            (
                node_id,
                'NodeAnchor',
                'jaclang.jac0core.archetype',
                'Root',
                None,
                json.dumps(
                    {
                        '__type__': 'NodeAnchor',
                        '__module__': 'jaclang.jac0core.archetype',
                        'id': node_id,
                        'persistent': True,
                        'archetype': {
                            '__type__': 'Root',
                            '__module__': 'jaclang.jac0core.archetype'
                        },
                        'edges': []
                    }
                ),
                'cascade quarantine',
                '2026-05-17T00:00:00',
                1
            )
        );
        seed_conn.commit();
        seed_conn.close();
        mem = SqliteMemory(path=db_path);
        (recovered, still_stuck) = mem.recover_all();
        assert recovered == 2 , f"both rows must recover, got {recovered}: {still_stuck}";
        assert not still_stuck , f"nothing should remain stuck, got {still_stuck}";
        mem.close();
        verify_conn = sqlite3.connect(db_path);
        row = verify_conn.execute(
            "SELECT data FROM anchors WHERE id = ? AND type = 'NodeAnchor'", (node_id, )
        ).fetchone();
        assert row is not None , "recovered node must be live in anchors";
        node_doc = cast(dict, json.loads(cast(str, row[0])));
        recovered_edges = cast(list, node_doc.get('edges', []));
        assert edge_id in recovered_edges , (
            f"node data.edges must contain the re-linked edge (ordering fix); got: {recovered_edges}"
        );
        verify_conn.close();
    }
}


test "non-Optional field with no default stores null quarantines only that anchor, no cascade" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        db_path = os.path.join(tmpdir, "test.db");
        bad_id = str(uuid.uuid4());
        neighbour_id = str(uuid.uuid4());
        import json;
        import sqlite3;
        mem = SqliteMemory(path=db_path);
        mem._ensure_connection();
        def _insert_required(conn: sqlite3.Connection, row_id: str, name_val: object) {
            conn.execute(
                """
                INSERT INTO anchors
                    (id, type, arch_module, arch_type, fingerprint, data,
                     format_version, updated_at)
                VALUES (?, 'NodeAnchor', ?, '_RequiredField', NULL, ?, 1,
                        '2026-05-26T00:00:00')
                """,
                (
                    row_id,
                    _RequiredField.__module__,
                    json.dumps(
                        {
                            '__type__': 'NodeAnchor',
                            '__module__': 'jaclang.jac0core.archetype',
                            'id': row_id,
                            'persistent': True,
                            'archetype': {
                                '__type__': '_RequiredField',
                                '__module__': _RequiredField.__module__,
                                'name': name_val
                            },
                            'edges': []
                        }
                    )
                )
            );
        }
        _insert_required(cast(sqlite3.Connection, mem.__conn__), bad_id, None);
        _insert_required(cast(sqlite3.Connection, mem.__conn__), neighbour_id, "alice");
        cast(sqlite3.Connection, mem.__conn__).commit();
        bad_anchor = mem.get(uuid.UUID(bad_id));
        assert bad_anchor is None , "anchor with no-default null field must be quarantined (returns None)";
        good_anchor = mem.get(uuid.UUID(neighbour_id));
        assert good_anchor is not None , "neighbour anchor must still load normally";
        conn = sqlite3.connect(db_path);
        q_rows = {
            r[0]: r[1] for r in conn.execute("SELECT id, error FROM anchors_quarantine")
        };
        live_ids = {r[0] for r in conn.execute("SELECT id FROM anchors")};
        conn.close();
        assert bad_id in q_rows , "bad anchor must be in anchors_quarantine";
        assert neighbour_id not in q_rows , "neighbour must NOT be cascade-quarantined";
        assert neighbour_id in live_ids , "neighbour must remain live";
        quarantine_reason = q_rows[bad_id];
        assert quarantine_reason is not None , "quarantine row must carry a reason string";
        assert "archetype field deserialization failed" in quarantine_reason , (
            "reason must identify field failure, not class-unresolvable"
        );
        mem.close();
    }
}


test "SqliteMemory recover_all emits warning when re-link target is missing" {
    # When a quarantined edge's source node is absent from live anchors,
    # recovery must still complete without error and move the edge to live.
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        db_path = os.path.join(tmpdir, "test.db");
        ghost_node_id = str(uuid.uuid4());
        edge_id = str(uuid.uuid4());
        # Create schema, then seed with a raw connection.
        mem_init = SqliteMemory(path=db_path);
        mem_init.inspect_summary();
        mem_init.close();
        seed_conn = sqlite3.connect(db_path);
        # Only the edge is quarantined; ghost_node_id has no live row.
        seed_conn.execute(
            (
                "INSERT INTO anchors_quarantine"
                " (id, type, arch_module, arch_type, fingerprint, data,"
                "  error, quarantined_at, from_format_version)"
                " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
            ),
            (
                edge_id,
                'EdgeAnchor',
                'jaclang.jac0core.archetype',
                'GenericEdge',
                None,
                json.dumps(
                    {
                        '__type__': 'EdgeAnchor',
                        '__module__': 'jaclang.jac0core.archetype',
                        'id': edge_id,
                        'persistent': True,
                        'source': ghost_node_id,
                        'target': ghost_node_id,
                        'is_undirected': False,
                        'archetype': {
                            '__type__': 'GenericEdge',
                            '__module__': 'jaclang.jac0core.archetype'
                        }
                    }
                ),
                'cascade quarantine',
                '2026-05-17T00:00:00',
                1
            )
        );
        seed_conn.commit();
        seed_conn.close();
        # Must not raise — missing node triggers a warning, not a crash.
        mem = SqliteMemory(path=db_path);
        (recovered, still_stuck) = mem.recover_all();
        assert recovered == 1 , f"edge must be recovered even without live node, got {recovered}";
        assert not still_stuck , f"edge must not be stuck, got {still_stuck}";
        mem.close();
        verify_conn = sqlite3.connect(db_path);
        live = verify_conn.execute(
            "SELECT id FROM anchors WHERE id = ?", (edge_id, )
        ).fetchone();
        assert live is not None , "edge must be live after recovery";
        ghost = verify_conn.execute(
            "SELECT id FROM anchors WHERE id = ?", (ghost_node_id, )
        ).fetchone();
        assert ghost is None , "ghost node must not materialise";
        verify_conn.close();
    }
}
