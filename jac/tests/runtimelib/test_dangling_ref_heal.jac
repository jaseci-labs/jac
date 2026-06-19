"""Read-path dangling-reference healing (#6619, piece 4).

When a node's edge list cites an edge document that no longer exists -- the
legacy corruption minted by the pre-ChangeSet delete window (#6587) -- a
traversal must *skip and heal* the dangler, not raise a 500 on every read
shape. Concretely, after this feature lands:

  - `visit [-->]` over the corrupted node returns the surviving neighbours
    and does not raise (`jac enter` exits 0).
  - the stale citation is pruned from the node's edge list AND the repair is
    persisted through the normal commit path.
  - the dangler is filed into the existing quarantine store under a new
    `DANGLING_REF` reason code, so it surfaces via `jac db quarantine list`.

These tests drive the *real* read path end to end (a `jac enter` subprocess
against a DB corrupted out of band), exactly the production shape from #6587.
On `main` the `dump` walker raises `ValueError: ... is not a valid reference`,
so the exit-code and heal assertions below fail.
"""

import subprocess;
import sys;
import sqlite3;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }


"""Run `python -m jaclang <args>` in cwd; return (rc, stdout, stderr)."""
def _jac(cwd: str, args: list) -> tuple {
    result = subprocess.run(
        [sys.executable, "-m", "jaclang"] + args,
        cwd=cwd,
        capture_output=True,
        text=True,
        timeout=180
    );
    return (result.returncode, result.stdout, result.stderr);
}


glob APP = "node Thing { has name: str; }\n"
     "walker create {\n"
     "    can s with Root entry {\n"
     "        here ++> Thing(name=\"alice\");\n"
     "        here ++> Thing(name=\"bob\");\n"
     "    }\n"
     "}\n"
     "walker dump {\n"
     "    can r with Root entry { visit [-->]; }\n"
     "    can t with Thing entry { print(here.name); }\n"
     "}\n";


"""Path to the single on-disk SQLite DB an app created under cwd."""
def _db_path(tmpdir: str) -> str {
    dbs = sorted((Path(tmpdir) / ".jac" / "data").glob("*.db"));
    assert dbs , "expected a .jac/data/*.db after `jac enter`";
    return str(dbs[0]);
}


test "traversal heals a dangling edge citation instead of raising" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        app = Path(tmpdir) / "app.jac";
        app.write_text(APP);
        (rc, _, err) = _jac(tmpdir, ["enter", str(app), "create"]);
        assert rc == 0 , f"create failed: {err}";
        db = _db_path(tmpdir);
        # Corrupt out of band: delete ONE edge row while both its endpoints
        # still cite it in data.edges. This is the #6587 dangling reference.
        conn = sqlite3.connect(db);
        victim = [
            r[0] for r in conn.execute("SELECT id FROM anchors WHERE type='EdgeAnchor'")
        ][0];
        conn.execute("DELETE FROM anchors WHERE id=?", (victim, ));
        conn.commit();
        conn.close();
        # The dump walker visits [-->] from root: it MUST NOT 500 on the
        # dangler; the surviving edge resolves and its Thing is visited.
        (rc, out, err) = _jac(tmpdir, ["enter", str(app), "dump"]);
        assert rc == 0 , f"dump must not crash on a dangling ref (got rc={rc}): {err}";
        conn = sqlite3.connect(db);
        # The stale citation is pruned from root (2 edges -> 1) and persisted.
        root_edges = conn.execute(
            """
            SELECT COUNT(*) FROM json_each(json_extract(
                (SELECT data FROM anchors WHERE arch_type='Root'), '$.edges'))
            """
        ).fetchone()[0];
        still_cites_victim = conn.execute(
            """
            SELECT COUNT(*) FROM json_each(json_extract(
                (SELECT data FROM anchors WHERE arch_type='Root'), '$.edges'))
            WHERE value = ?
            """,
            (victim, )
        ).fetchone()[0];
        # The dangler is filed under the DANGLING_REF reason code.
        dangling_rows = conn.execute(
            "SELECT COUNT(*) FROM anchors_quarantine WHERE error LIKE 'DANGLING_REF%'"
        ).fetchone()[0];
        victim_recorded = conn.execute(
            "SELECT COUNT(*) FROM anchors_quarantine WHERE id=?", (victim, )
        ).fetchone()[0];
        conn.close();
        assert still_cites_victim == 0 , (
            "root must no longer cite the deleted edge after healing"
        );
        assert root_edges == 1 , f"root should have 1 surviving edge, got {root_edges}";
        assert dangling_rows >= 1 , "dangler must be filed under DANGLING_REF";
        assert victim_recorded == 1 , (
            "the missing edge id must be recorded in the quarantine store"
        );
    }
}


test "traversal heals an edge whose target node was deleted (ghost endpoint)" {
    # The secondary #6587 shape: the edge doc survives but cites a node that is
    # gone. resolve_ref files a DANGLING_REF for the missing endpoint; the
    # ghost-endpoint branch must still prune the now-dead edge from the citing
    # node. The is_recoverable_quarantine gate excludes DANGLING_REF rows, so
    # the row resolve_ref just filed does not poison the prune.
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        app = Path(tmpdir) / "app.jac";
        app.write_text(APP);
        (rc, _, err) = _jac(tmpdir, ["enter", str(app), "create"]);
        assert rc == 0 , f"create failed: {err}";
        db = _db_path(tmpdir);
        # Delete one leaf Thing node, leaving the edge that targets it intact:
        # an edge that now cites a missing node (the ghost endpoint).
        conn = sqlite3.connect(db);
        ghost = [
            r[0]
            for r in conn.execute(
                "SELECT id FROM anchors WHERE type='NodeAnchor' AND arch_type='Thing'"
            )
        ][0];
        conn.execute("DELETE FROM anchors WHERE id=?", (ghost, ));
        conn.commit();
        conn.close();
        (rc, out, err) = _jac(tmpdir, ["enter", str(app), "dump"]);
        assert rc == 0 , f"dump must not crash on a ghost-endpoint edge: {err}";
        conn = sqlite3.connect(db);
        # root drops the broken edge (2 -> 1, the surviving Thing remains).
        root_edges = conn.execute(
            """
            SELECT COUNT(*) FROM json_each(json_extract(
                (SELECT data FROM anchors WHERE arch_type='Root'), '$.edges'))
            """
        ).fetchone()[0];
        # The missing node is filed under DANGLING_REF.
        ghost_recorded = conn.execute(
            "SELECT COUNT(*) FROM anchors_quarantine "
            "WHERE id=? AND error LIKE 'DANGLING_REF%'",
            (ghost, )
        ).fetchone()[0];
        conn.close();
        assert root_edges == 1 , (
            f"root must drop the edge to the ghost node, got {root_edges} edges"
        );
        assert ghost_recorded == 1 , (
            "the missing node must be filed under DANGLING_REF"
        );
    }
}
