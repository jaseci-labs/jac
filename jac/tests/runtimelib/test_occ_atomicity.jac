"""Atomicity of the OCC loser + `jac db fsck` reclamation (#6266 long-term fix).

Two guarantees beyond bare conflict detection:

  1. A walker is one atomic unit of work. When its root edge-list CAS loses a
     race, `SqliteMemory.apply()` rolls the WHOLE transaction back instead of
     committing the child/edge it had already staged -- so a lost race leaves
     the store byte-for-byte unchanged, *no orphan*. (Mongo, which has no
     cross-document rollback, prevents the orphan with an apply()-time version
     precheck and falls back to fsck for the residual; covered in jac-scale.)

  2. `fsck` reclaims a *half-linked* edge -- one cited by only one of its two
     endpoints -- and the node it strands. That is the residual orphan
     signature (a loser's child + edge whose root-side citation was refused),
     and it is what makes "collected by jac db fsck" true rather than aspirational.

Anchor handles are typed `any`: the checker has no stub for `.__jac__`.
"""

import os;
import shutil;
import sqlite3;
import json;
import from tempfile { mkdtemp }
import from uuid { UUID }

import from jaclang.jac0core.archetype { GenericEdge, Root }
import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.runtimelib.changeset { ChangeSet }
import from jaclang.runtimelib.context { ExecutionContext }
import from jaclang.runtimelib.memory { SqliteMemory }
import from jaclang.project.config { JacConfig, set_config }
import from jaclang { JacRuntimeInterface as Jac }


node Child {
    has uid: str = "";
}

edge Link {}


walker MakeKid {
    has uid: str = "";

    can go with entry {
        here +>:Link:+> Child(uid=self.uid);
    }
}


def _seed_root(db: str) -> any {
    be: any = SqliteMemory(path=db);
    r0: any = Root().__jac__;
    r0.persistent = True;
    r0.root = r0.id;
    cs: any = ChangeSet();
    cs.record_create(r0);
    be.apply(cs);
    return r0.id;
}


"""Stage a full find-or-create unit (child NODE_CREATE + edge EDGE_CREATE +
root EDGE_LIST_DELTA) against `rid`, CASing on `cas_ver`. Models build_edge by
citing the edge on both endpoints. Returns (ApplyReport, child_id, edge_id)."""
def _commit_child(db: str, rid: any, uid: str, cas_ver: any) -> any {
    be: any = SqliteMemory(path=db);
    r: any = be.get(rid);
    child: any = Child(uid=uid).__jac__;
    child.persistent = True;
    child.root = rid;
    e: any = GenericEdge().__jac__;
    e.persistent = True;
    e.root = rid;
    e.source = r;
    e.target = child;
    r.edges.append(e);
    child.edges.append(e);
    cs: any = ChangeSet();
    cs.record_create(child);
    cs.record_create(e);
    cs.record_edge_delta(r, [e.id], []);
    cs.intents[r.id].cas_version = cas_ver;
    return (be.apply(cs), child.id, e.id);
}


test "OCC (SQLite): a lost race leaves NO orphan (whole-unit rollback)" {
    db = os.path.join(mkdtemp(), "g.db");
    rid = _seed_root(db);

    (repA, cAid, eAid) = _commit_child(db, rid, "winner", 0);  # wins, root -> v1
    assert not repA.conflicts , "winner must not conflict";

    (repB, cBid, eBid) = _commit_child(db, rid, "loser", 0);  # stale v0 -> conflict
    assert len(repB.conflicts) == 1 , f"loser must conflict, got {repB.conflicts}";

    # The whole losing unit rolled back: its child + edge are NOT in the store,
    # and the root carries only the winner's edge.
    chk: any = SqliteMemory(path=db);
    assert not chk.`has(cBid) , "loser's child must not persist (rollback)";
    assert not chk.`has(eBid) , "loser's edge must not persist (rollback)";
    root_after: any = chk.get(rid);
    assert len(root_after.edges) == 1 , f"root keeps only the winner edge, got {len(
        root_after.edges
    )}";

    # The winner is intact.
    assert chk.`has(cAid) , "winner's child must persist";
}


test "fsck (SQLite): a half-linked edge + its stranded child are collected" {
    tmp = mkdtemp();
    orig = JacRuntime.get_base_path_dir();
    try {
        cfg = JacConfig();
        cfg.run.topology_index = True;
        set_config(cfg);
        JacRuntime.set_base_path(tmp);
        ctx0: any = ExecutionContext();
        JacRuntime.set_context(ctx0);
        # Real runtime so the edge persists as a true EdgeAnchor row.
        p: any = Child(uid="parent");
        Jac.root() ++> p;
        Jac.commit();
        pid = str(p.__jac__.id);
        p spawn MakeKid(uid="kid");
        Jac.commit();
        dbp = ctx0.mem.l3.path;
        ctx0.close();

        # Find the parent->kid edge (cited by the kid) and surgically remove it
        # from the parent's edge list, recreating the residual orphan shape that
        # an OCC reject would leave on a non-transactional backend.
        c = sqlite3.connect(dbp);
        prow = c.execute("SELECT data FROM anchors WHERE id=?", (pid, )).fetchone();
        pdata = json.loads(prow[0]);
        krow = c.execute(
            "SELECT id, data FROM anchors WHERE arch_type='Child' AND id!=?", (pid, )
        ).fetchone();
        kid = str(krow[0]);
        link_eid = [str(e) for e in json.loads(krow[1]).get('edges', [])][0];
        pdata['edges'] = [
            str(e)
            for e in pdata.get('edges', [])
            if str(e) != link_eid
        ];
        c.execute("UPDATE anchors SET data=? WHERE id=?", (json.dumps(pdata), pid));
        c.commit();
        c.close();

        JacRuntime.set_context(ctx0);
        rpt: any = ExecutionContext().mem.l3.fsck(repair=False);
        assert any(str(e[0]) == link_eid for e in rpt['half_linked_edges']) , f"link edge must be flagged half-linked, got {rpt[
            'half_linked_edges'
        ]}";
        assert kid in [str(n) for n in rpt['orphan_nodes']] , f"stranded kid must be flagged orphan_node, got {rpt[
            'orphan_nodes'
        ]}";

        rep: any = ExecutionContext().mem.l3.fsck(repair=True);
        assert rep['repaired_counts']['collected'] >= 2 , f"edge + child collected, got {rep[
            'repaired_counts'
        ]}";
        after: any = ExecutionContext();
        assert not after.mem.l3.`has(UUID(kid)) , "stranded kid must be collected";
        assert not after.mem.l3.`has(UUID(link_eid)) , "half-linked edge must be collected";
    } finally {
        JacRuntime.set_base_path(orig);
        set_config(JacConfig());
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
