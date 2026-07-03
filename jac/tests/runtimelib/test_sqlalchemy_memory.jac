"""Tier 1 tests for SqlAlchemyMemory (the eject `[eject.db]` persistence
backend, vendored into ejected apps). Round-trips anchors through an
in-memory SQLite engine so interface drift against PersistentMemory /
Serializer breaks here, in CI — not inside someone's ejected app."""

import pytest;

import from jaclang.jac0core.archetype { Root }
import from jaclang.runtimelib.changeset { ChangeSet }


node SqlItem {
    has name: str = "";
}


"""Skip when the optional sqlalchemy dep is absent (CI installs it)."""
def _require_sqlalchemy {
    import from importlib.util { find_spec }
    if find_spec("sqlalchemy") is None {
        pytest.skip("sqlalchemy not installed (pip install 'SQLAlchemy>=2.0')");
    }
}


def _mem -> object {
    import from jaclang.runtimelib.storage.sqlalchemy_memory { SqlAlchemyMemory }
    return SqlAlchemyMemory(url="sqlite://");
}


test "put/get round-trips an anchor through the database" {
    _require_sqlalchemy();
    mem = _mem();
    item = SqlItem(name="alice");
    anchor = item.__jac__;
    anchor.persistent = True;
    mem.put(anchor);
    # Drop the L1 copy so get() must deserialize from the DB row.
    mem.invalidate(anchor.id);
    assert anchor.id not in mem.get_mem();
    back = mem.get(anchor.id);
    assert back is not None;
    assert back.archetype.name == "alice";
    assert mem.`has(anchor.id);
    assert mem.exists(anchor.id);
    mem.close();
}


test "apply persists creates and deletes as a unit" {
    _require_sqlalchemy();
    mem = _mem();
    item = SqlItem(name="staged");
    anchor = item.__jac__;
    anchor.persistent = True;
    cs = ChangeSet();
    cs.record_create(anchor);
    outcome = mem.apply(cs);
    assert outcome.ok();
    assert anchor.id in outcome.applied;
    mem.invalidate(anchor.id);
    assert mem.`has(anchor.id);

    cs2 = ChangeSet();
    cs2.record_delete(anchor);
    outcome2 = mem.apply(cs2);
    assert outcome2.ok();
    mem.invalidate(anchor.id);
    assert not mem.`has(anchor.id);
    mem.close();
}


test "get_roots yields persisted Root anchors" {
    _require_sqlalchemy();
    mem = _mem();
    ranch = Root().__jac__;
    ranch.persistent = True;
    mem.put(ranch);
    mem.invalidate(ranch.id);
    roots = list(mem.get_roots());
    assert len(roots) == 1;
    assert isinstance(roots[0], Root);
    mem.close();
}


test "unpersisted anchors stay in L1 only" {
    _require_sqlalchemy();
    mem = _mem();
    item = SqlItem(name="volatile");
    anchor = item.__jac__;
    anchor.persistent = False;
    mem.put(anchor);
    assert anchor.id in mem.get_mem();
    mem.invalidate(anchor.id);
    assert mem.get(anchor.id) is None;
    mem.close();
}
