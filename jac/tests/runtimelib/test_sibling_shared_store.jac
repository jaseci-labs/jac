"""Shared-store reads from a sibling service must not quarantine peer anchors.

In microservice mode every service shares one anchor store, but each process
only registers its own module's archetype classes. Reading a peer service's
anchor is therefore *expected* to be unresolvable in-process. Under
JAC_SV_SIBLING=1 such reads must be skipped without mutating the shared store
-- quarantining would poison the graph for the owning service too (one
curious reader, e.g. /graph/data, permanently breaks every service's view).

Outside sibling mode, quarantine-on-read stays intact: it is the designed
schema-rename workflow (`jac db alias add` + `jac db recover-all`).
"""

import json;
import os;
import sqlite3;
import unittest.mock;
import from tempfile { mkdtemp }
import from uuid { UUID, uuid4 }

import from jaclang.runtimelib.memory { SqliteMemory }


"""Insert a raw anchor row whose archetype class only a peer service has."""
def _seed_foreign_anchor(db: str) -> str {
    anchor_id = str(uuid4());
    payload = {
        "__type__": "NodeAnchor",
        "__module__": "jaclang.jac0core.archetype",
        "id": anchor_id,
        "root": anchor_id,
        "persistent": True,
        "access": {"all": -1, "roots": {"anchors": {}}},
        "archetype": {"__type__": "GhostNode", "__module__": "peer_service"},
        "edges": []
    };
    conn = sqlite3.connect(db);
    conn.execute(
        "INSERT INTO anchors (id, type, arch_module, arch_type, fingerprint,"
        " data, format_version) VALUES (?, ?, ?, ?, ?, ?, 1)",
        (
            anchor_id,
            "NodeAnchor",
            "peer_service",
            "GhostNode",
            "fp",
            json.dumps(payload)
        )
    );
    conn.commit();
    conn.close();
    return anchor_id;
}


def _table_ids(db: str, table: str) -> list {
    conn = sqlite3.connect(db);
    rows = [r[0] for r in conn.execute(f"SELECT id FROM {table}")];
    conn.close();
    return rows;
}


test "sibling read skips a peer's unresolvable anchor without quarantining" {
    tmp = mkdtemp();
    db = os.path.join(tmp, "anchor_store.db");
    be: any = SqliteMemory(path=db);
    be._ensure_connection();
    anchor_id = _seed_foreign_anchor(db);

    with unittest.mock.patch.dict(os.environ, {"JAC_SV_SIBLING": "1"}) {
        got = be.get(UUID(anchor_id));
    }

    assert got is None;
    assert _table_ids(db, "anchors") == [anchor_id] , (
        "the anchor must remain in the shared store for the owning service"
    );
    assert _table_ids(db, "anchors_quarantine") == [] , (
        "a sibling's inability to resolve a peer's class is expected, "
        "not corruption; it must never quarantine the shared anchor"
    );
}

test "sibling resolve_ref skips a peer's ref without heal-pruning" {
    import from uuid { uuid4 as _uuid4 }
    import from jaclang.jac0core.archetype { EdgeAnchor }
    import from jaclang.jac0core.runtime { JacRuntimeInterface, resolve_ref }

    stub: any = EdgeAnchor.__new__(EdgeAnchor);
    stub.id = _uuid4();

    fake_ctx = unittest.mock.MagicMock();
    fake_ctx.mem.get = unittest.mock.MagicMock(return_value=None);
    fake_ctx.mem.is_recoverable_quarantine = unittest.mock.MagicMock(
        return_value=False
    );

    with unittest.mock.patch.object(
        JacRuntimeInterface, "get_context", return_value=fake_ctx
    ) {
        with unittest.mock.patch.dict(os.environ, {"JAC_SV_SIBLING": "1"}) {
            got = resolve_ref(stub, None);
        }
    }

    assert got is None;
    fake_ctx.mem.quarantine_ref.assert_not_called();
}

test "non-sibling resolve_ref still heals a genuine dangler" {
    import from uuid { uuid4 as _uuid4 }
    import from jaclang.jac0core.archetype { EdgeAnchor }
    import from jaclang.jac0core.runtime { JacRuntimeInterface, resolve_ref }

    stub: any = EdgeAnchor.__new__(EdgeAnchor);
    stub.id = _uuid4();

    fake_ctx = unittest.mock.MagicMock();
    fake_ctx.mem.get = unittest.mock.MagicMock(return_value=None);
    fake_ctx.mem.is_recoverable_quarantine = unittest.mock.MagicMock(
        return_value=False
    );

    os.environ.pop("JAC_SV_SIBLING", None);
    with unittest.mock.patch.object(
        JacRuntimeInterface, "get_context", return_value=fake_ctx
    ) {
        got = resolve_ref(stub, None);
    }

    assert got is None;
    fake_ctx.mem.quarantine_ref.assert_called_once();
}

test "non-sibling read still quarantines an unresolvable class (rename workflow)" {
    tmp = mkdtemp();
    db = os.path.join(tmp, "anchor_store.db");
    be: any = SqliteMemory(path=db);
    be._ensure_connection();
    anchor_id = _seed_foreign_anchor(db);

    os.environ.pop("JAC_SV_SIBLING", None);
    got = be.get(UUID(anchor_id));

    assert got is None;
    assert _table_ids(db, "anchors") == [];
    assert _table_ids(db, "anchors_quarantine") == [anchor_id] , (
        "outside sibling mode the quarantine + `jac db recover-all` "
        "rename workflow must keep working"
    );
}
