"""`jac db fsck` integrity scanner / collector (#6619, piece 5).

`fsck` completes the model the ChangeSet implicitly committed to: orphans
(unreferenced documents) are the *designed* worst case of a truncated flush,
so something must collect them; danglers (referenced-but-missing documents)
are corruption, so something must detect them proactively. It is read-only by
default (usable as a monitoring probe) and repairs with `--repair` / the
`repair` sub-action: danglers are pruned + filed under `DANGLING_REF`, orphans
are collected.

On `main` there is no `fsck` action, so `jac db fsck` exits non-zero with an
"Unknown action" error and these tests fail.
"""

import subprocess;
import sys;
import sqlite3;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }


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
     "}\n";


def _db_path(tmpdir: str) -> str {
    dbs = sorted((Path(tmpdir) / ".jac" / "data").glob("*.db"));
    assert dbs , "expected a .jac/data/*.db after `jac enter`";
    return str(dbs[0]);
}


test "fsck detects a dangling ref read-only, then repairs it" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        app = Path(tmpdir) / "app.jac";
        app.write_text(APP);
        (rc, _, err) = _jac(tmpdir, ["enter", str(app), "create"]);
        assert rc == 0 , f"create failed: {err}";
        db = _db_path(tmpdir);
        # Delete one edge row, leaving both endpoints citing it: a dangling
        # node -> edge reference (referenced-but-missing).
        conn = sqlite3.connect(db);
        victim = [
            r[0] for r in conn.execute("SELECT id FROM anchors WHERE type='EdgeAnchor'")
        ][0];
        conn.execute("DELETE FROM anchors WHERE id=?", (victim, ));
        conn.commit();
        conn.close();
        # Read-only scan reports the dangler and does not mutate the DB.
        (rc, out, err) = _jac(tmpdir, ["db", "fsck", "--app", str(app)]);
        assert rc == 0 , f"fsck scan failed: {err}";
        assert "dangling" in out.lower() , f"scan must report danglers: {out!r}";
        conn = sqlite3.connect(db);
        before = conn.execute(
            """
            SELECT COUNT(*) FROM json_each(json_extract(
                (SELECT data FROM anchors WHERE arch_type='Root'), '$.edges'))
            WHERE value = ?
            """,
            (victim, )
        ).fetchone()[0];
        conn.close();
        assert before == 1 , "read-only fsck must NOT prune the citation";
        # Repair prunes the citation and files DANGLING_REF.
        (rc, out, err) = _jac(tmpdir, ["db", "fsck", "repair", "--app", str(app)]);
        assert rc == 0 , f"fsck repair failed: {err}";
        # A second scan now comes back clean.
        (rc, out, err) = _jac(tmpdir, ["db", "fsck", "--app", str(app)]);
        assert rc == 0 , f"post-repair fsck failed: {err}";
        conn = sqlite3.connect(db);
        after = conn.execute(
            """
            SELECT COUNT(*) FROM json_each(json_extract(
                (SELECT data FROM anchors WHERE arch_type='Root'), '$.edges'))
            WHERE value = ?
            """,
            (victim, )
        ).fetchone()[0];
        dangling_rows = conn.execute(
            "SELECT COUNT(*) FROM anchors_quarantine WHERE error LIKE 'DANGLING_REF%'"
        ).fetchone()[0];
        conn.close();
        assert after == 0 , "repair must prune the dangling citation";
        assert dangling_rows >= 1 , "repair must file the dangler under DANGLING_REF";
    }
}
