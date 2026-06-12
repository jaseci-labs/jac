"""Tests for SqliteMemory.schema_census / schema_migrate: eager DB-wide convergence + census gate."""

import json;
import os;
import from tempfile { TemporaryDirectory }
import from jaclang.jac0core.archetype { NodeAnchor, Root }
import from jaclang.runtimelib.memory { SqliteMemory }


"""Legacy comma-string tags -> list[str]; idempotent via the `when` guard."""
def _split_tags(doc: dict) -> dict {
    doc['tags'] = [
        t.strip()
        for t in doc['tags'].split(',')
        if t.strip()
    ];
    return doc;
}


obj _MigUser(Root) {
    has name: str = "",
        tags: list[str] = [],
        email: str = "";

    static def __jac_schema__ -> None;
}

impl _MigUser.__jac_schema__ -> None {
    schema_alias("name", stored="username");
    schema_drop("legacy_bio");
    schema_upgrade(
        _split_tags, when=(lambda doc: dict : isinstance(doc.get('tags'), str))
    );
}


obj _MigPlain(Root) {
    has title: str = "";
}


def _owner(cls: type) -> str {
    return f"{cls.__module__}.{cls.__name__}";
}


"""Store `arch`, then rewrite its row's archetype dict to `arch_overrides` to simulate a drifted document; returns the row id."""
def _store_drifted(mem: SqliteMemory, arch: object, arch_overrides: dict) -> str {
    anchor = NodeAnchor(archetype=arch, edges=[]);
    anchor.persistent = True;
    mem.put(anchor);
    mem.sync();
    rid = str(anchor.id);
    conn = mem.__conn__;
    row = conn.execute("SELECT data FROM anchors WHERE id = ?", (rid, )).fetchone();
    d = json.loads(row[0]);
    archd = d['archetype'];
    # Drop everything the override replaces (e.g. the canonical `name` and any
    # dual-written `username` shadow) so only the legacy shape remains.
    for k in ['name', 'username', 'tags', 'legacy_bio'] {
        archd.pop(k, None);
    }
    archd.update(arch_overrides);
    d['archetype'] = archd;
    conn.execute("UPDATE anchors SET data = ? WHERE id = ?", (json.dumps(d), rid));
    conn.commit();
    return rid;
}


def _arch_of(mem: SqliteMemory, rid: str) -> dict {
    row = mem.__conn__.execute(
        "SELECT data FROM anchors WHERE id = ?", (rid, )
    ).fetchone();
    return json.loads(row[0])['archetype'];
}


# --- census reports drift, migrate converges it -----------------------------
test "census counts load-bearing rules; migrate converges and zeroes them" {
    with TemporaryDirectory() as tmpdir {
        mem = SqliteMemory(path=os.path.join(tmpdir, "m.db"));
        rid = _store_drifted(
            mem,
            _MigUser(name="ada", tags=["x"], email="a@e.com"),
            {'username': 'ada', 'tags': 'math, cs', 'legacy_bio': 'first program'}
        );
        owner = _owner(_MigUser);
        before = mem.schema_census();
        b = before['archetypes'][owner];
        assert b['alias:username->name'] == 1 , f"alias not counted: {b}";
        assert b['drop:legacy_bio'] == 1 , f"drop not counted: {b}";
        assert b['upgrade:_split_tags'] == 1 , f"upgrade not counted: {b}";
        rep = mem.schema_migrate();
        assert rep['repaired'] == 1 , f"expected 1 repaired, got {rep}";
        assert rep['errors'] == 0;
        # The proof surface: every retireable label reads zero afterwards.
        after = mem.schema_census();
        a = after['archetypes'][owner];
        assert a['alias:username->name'] == 0 , f"alias not zeroed: {a}";
        assert a['drop:legacy_bio'] == 0 , f"drop not zeroed: {a}";
        assert a['upgrade:_split_tags'] == 0 , f"upgrade not zeroed: {a}";
        # And the data itself converged, with nothing lost.
        arch = _arch_of(mem, rid);
        assert 'username' not in arch , "dual-write shadow not stripped";
        assert arch['name'] == 'ada' , "rename not applied";
        assert arch['tags'] == ['math', 'cs'] , f"upgrade not applied: {arch['tags']}";
        attic = arch.get('__jac_attic__') or {};
        assert 'legacy_bio' in attic , "dropped field not preserved in attic";
        mem.close();
    }
}


# --- migration is idempotent ------------------------------------------------
test "a second migrate is a no-op (idempotent)" {
    with TemporaryDirectory() as tmpdir {
        mem = SqliteMemory(path=os.path.join(tmpdir, "m.db"));
        _store_drifted(
            mem, _MigUser(name="ada", tags=[], email=""), {'username': 'ada'}
        );
        first = mem.schema_migrate();
        assert first['repaired'] == 1;
        second = mem.schema_migrate();
        assert second['repaired'] == 0 , f"second run rewrote rows: {second}";
        assert second['clean'] >= 1;
        mem.close();
    }
}


# --- dry-run reports without writing ----------------------------------------
test "dry-run migrate reports drift but leaves the DB untouched" {
    with TemporaryDirectory() as tmpdir {
        mem = SqliteMemory(path=os.path.join(tmpdir, "m.db"));
        rid = _store_drifted(
            mem,
            _MigUser(name="ada", tags=[], email=""),
            {'username': 'ada', 'legacy_bio': 'x'}
        );
        rep = mem.schema_migrate(dry_run=True);
        assert rep['dry_run'] == True;
        assert rep['repaired'] == 1 , f"dry-run should still report drift: {rep}";
        # Nothing written: the old key is still on disk.
        arch = _arch_of(mem, rid);
        assert 'username' in arch , "dry-run must not modify the DB";
        # Census still shows the drift since no write happened.
        owner = _owner(_MigUser);
        assert mem.schema_census()['archetypes'][owner]['alias:username->name'] == 1;
        mem.close();
    }
}


# --- archetypes without rules are ignored -----------------------------------
test "a rule-free archetype contributes nothing to census or migration" {
    with TemporaryDirectory() as tmpdir {
        mem = SqliteMemory(path=os.path.join(tmpdir, "m.db"));
        anchor = NodeAnchor(archetype=_MigPlain(title="hi"), edges=[]);
        anchor.persistent = True;
        mem.put(anchor);
        mem.sync();
        census = mem.schema_census();
        assert _owner(_MigPlain) not in census['archetypes'];
        rep = mem.schema_migrate();
        assert rep['repaired'] == 0 , f"rule-free doc should not be rewritten: {rep}";
        mem.close();
    }
}
