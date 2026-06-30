"""Read-set optimistic-concurrency tests for the SQLite backend (#6266).

The version-CAS that stops concurrent check-then-create from minting duplicate
child nodes is *read-gated*: the backend CASes on a node's version only when
the request actually read a traversal from it (modelled here by setting
`WriteIntent.cas_version`). A blind append (no read, `cas_version` None) merges
lock-free, preserving #5644. Two SqliteMemory instances on one db file model
two workers sharing a SQLite database; no Docker needed.

Anchor handles are typed `any`: the checker has no stub for `.__jac__` /
anchor metadata, and these tests poke the persistence layer directly.
"""

import os;
import from tempfile { mkdtemp }

import from jaclang.jac0core.archetype { GenericEdge, Root }
import from jaclang.runtimelib.changeset { ChangeSet }
import from jaclang.runtimelib.exceptions { WriteConflict }
import from jaclang.runtimelib.memory { SqliteMemory }


"""A fresh persistent edge anchor (only its id matters for these tests)."""
def _edge -> any {
    edge_arch: any = GenericEdge();
    e: any = edge_arch.__jac__;
    e.persistent = True;
    return e;
}


"""Seed a fresh Root at version 0 in `db`; return its id."""
def _seed_root(db: str) -> any {
    backend: any = SqliteMemory(path=db);
    root_arch: any = Root();
    r0: any = root_arch.__jac__;
    r0.persistent = True;
    r0.root = r0.id;
    cs0: any = ChangeSet();
    cs0.record_create(r0);
    backend.apply(cs0);
    return r0.id;
}


"""Add one child edge to `rid` via a fresh worker. `read` models a
check-then-create (records a read dependency -> version-CAS); when False it is
a blind append (no dependency -> lock-free merge). Returns the ApplyReport."""
def _add_child(db: str, rid: any, read: bool) -> any {
    be: any = SqliteMemory(path=db);
    r: any = be.get(rid);
    e: any = _edge();
    r.edges.append(e);
    cs: any = ChangeSet();
    cs.record_edge_delta(r, [e.id], []);
    if read {
        cs.intents[r.id].cas_version = r.version;
    }
    return be.apply(cs);
}


"""find-or-create with replay on conflict (read-gated); 'created' or 'found'."""
def _find_or_create(db: str, rid: any) -> str {
    attempt = 0;
    while attempt < 5 {
        attempt += 1;
        # Fresh worker each attempt = reload from L3 (models abort + replay).
        be: any = SqliteMemory(path=db);
        r: any = be.get(rid);
        if len(r.edges) > 0 {
            return "found";
        }
        e: any = _edge();
        r.edges.append(e);
        cs: any = ChangeSet();
        cs.record_edge_delta(r, [e.id], []);
        cs.intents[r.id].cas_version = r.version;  # the walker read root
        rep: any = be.apply(cs);
        if rep.conflicts {
            continue;
        }
        return "created";
    }
    return "exhausted";
}


test "OCC (SQLite): a read-gated stale write conflicts" {
    db = os.path.join(mkdtemp(), "g.db");
    rid = _seed_root(db);

    b1: any = SqliteMemory(path=db);
    b2: any = SqliteMemory(path=db);
    h1: any = b1.get(rid);
    h2: any = b2.get(rid);
    assert h1.version == 0 and h2.version == 0;

    # Worker 1 read root then writes -> CAS on v0 -> wins, bumps to v1.
    e1: any = _edge();
    h1.edges.append(e1);
    cs1: any = ChangeSet();
    cs1.record_edge_delta(h1, [e1.id], []);
    cs1.intents[h1.id].cas_version = h1.version;
    r1: any = b1.apply(cs1);
    assert not r1.conflicts and not r1.failed;
    assert h1.version == 1;

    # Worker 2 also read root at v0 -> CAS miss -> recorded WriteConflict.
    e2: any = _edge();
    h2.edges.append(e2);
    cs2: any = ChangeSet();
    cs2.record_edge_delta(h2, [e2.id], []);
    cs2.intents[h2.id].cas_version = h2.version;
    r2: any = b2.apply(cs2);
    assert len(r2.conflicts) == 1 , f"expected 1 conflict, got {r2.conflicts}";
    wc: any = r2.conflicts[0];
    assert wc.expected_version == 0 and wc.actual_version == 1;
}


test "OCC (SQLite): a blind append (no read) merges lock-free" {
    db = os.path.join(mkdtemp(), "g.db");
    rid = _seed_root(db);

    # Two workers append without reading root first -> no dependency -> both
    # land via the edge-merge, no conflict (the #5644 guarantee, restored).
    rep_a: any = _add_child(db, rid, False);
    rep_b: any = _add_child(db, rid, False);
    assert not rep_a.conflicts and not rep_b.conflicts , "blind appends must not conflict";

    final: any = SqliteMemory(path=db).get(rid);
    assert len(final.edges) == 2 , f"both blind appends merge, got {len(final.edges)}";
}


test "OCC (SQLite) + replay converges concurrent find-or-create to one child" {
    db = os.path.join(mkdtemp(), "g.db");
    rid = _seed_root(db);

    # Both workers read the empty root before either commits (#6266 A/B).
    bA: any = SqliteMemory(path=db);
    bB: any = SqliteMemory(path=db);
    rA: any = bA.get(rid);
    rB: any = bB.get(rid);
    assert len(rA.edges) == 0 and len(rB.edges) == 0;

    # A wins (read-gated CAS on v0).
    eA: any = _edge();
    rA.edges.append(eA);
    csA: any = ChangeSet();
    csA.record_edge_delta(rA, [eA.id], []);
    csA.intents[rA.id].cas_version = rA.version;
    repA: any = bA.apply(csA);
    assert not repA.conflicts;

    # B's stale read-gated commit conflicts...
    eB: any = _edge();
    rB.edges.append(eB);
    csB: any = ChangeSet();
    csB.record_edge_delta(rB, [eB.id], []);
    csB.intents[rB.id].cas_version = rB.version;
    repB: any = bB.apply(csB);
    assert len(repB.conflicts) == 1;

    # ...so B replays, re-reads, and converges on the find branch.
    outB = _find_or_create(db, rid);
    assert outB == "found" , f"replay should converge to found, got {outB}";

    final: any = SqliteMemory(path=db).get(rid);
    assert len(final.edges) == 1 , f"expected 1 linked child, got {len(final.edges)}";
}
