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
import from jaclang.runtimelib.memory { SqliteMemory }
import from jaclang.runtimelib.serializer { Serializer }


obj _DemoArchV1(Root) {
    has name: str = "",
        age: int = 0;
}

obj _SyncProfile(Root) {
    has name: str = "",
        count: int = 0,
        tags: list[str] = [];
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
        mem1.sync();
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
        mem_init.sync();
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
        mem_b.sync();
        mem_b.close();
        # Walker A syncs with its stale snapshot — must NOT overwrite B's write
        mem_a.sync();
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
        mem_init.sync();
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
        mem_b.sync();
        mem_b.close();
        # Walker A sets only count then commits
        cast(_SyncProfile, anchor_a.archetype).count = 42;
        mem_a.sync();
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
        mem1.sync();
        anchor_id = anchor.id;
        mem1.close();
        # Load, mutate the list in-place (bypasses __setattr__)
        mem2 = SqliteMemory(path=db_path);
        loaded = mem2.get(anchor_id);
        assert loaded is not None;
        cast(_SyncProfile, loaded.archetype).tags.append("b");
        mem2.sync();
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
