"""End-to-end persistence-migration tests — the developer-workflow layer.

These tests spawn real `jac enter` subprocesses so each run is a fresh
Python process with a fresh module registry — exactly matching the
"edit file, rerun app" workflow that Layer 1+2 is built to support.

Complements test_persistence_migration.jac which is the unit-level suite
for SqliteMemory internals (schema, quarantine, legacy pickle migration).
"""

import os;
import subprocess;
import sys;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }


"""Run `jac enter <file> <entrypoint>` and return (rc, stdout, stderr)."""
def _jac_enter(cwd: str, app_path: str, entrypoint: str) -> tuple {
    result = subprocess.run(
        [sys.executable, "-m", "jaclang", "enter", app_path, entrypoint],
        cwd=cwd,
        capture_output=True,
        text=True,
        timeout=180
    );
    return (result.returncode, result.stdout, result.stderr);
}


glob V1_SOURCE = "node Person {\n"
     "    has name: str;\n"
     "    has age: int = 0;\n"
     "}\n"
     "\n"
     "walker create {\n"
     "    can s with Root entry {\n"
     "        here ++> Person(name=\"alice\", age=30);\n"
     "        here ++> Person(name=\"bob\", age=25);\n"
     "    }\n"
     "}\n"
     "\n"
     "walker dump {\n"
     "    can r with Root entry { visit [-->]; }\n"
     "    can p with Person entry { print(f\"v1:{here.name}:{here.age}\"); }\n"
     "}\n",
     # v2: adds `email` with a default.
     V2_SOURCE_ADD_FIELD = "node Person {\n"
     "    has name: str;\n"
     "    has age: int = 0;\n"
     "    has email: str = \"unknown@example.com\";\n"
     "}\n"
     "\n"
     "walker dump {\n"
     "    can r with Root entry { visit [-->]; }\n"
     "    can p with Person entry {\n"
     "        print(f\"v2:{here.name}:{here.age}:{here.email}\");\n"
     "    }\n"
     "}\n",
     # v3: removes `age`.
     V3_SOURCE_REMOVE_FIELD = "node Person {\n"
     "    has name: str;\n"
     "    has email: str = \"unknown@example.com\";\n"
     "}\n"
     "\n"
     "walker dump {\n"
     "    can r with Root entry { visit [-->]; }\n"
     "    can p with Person entry {\n"
     "        print(f\"v3:{here.name}:{here.email}\");\n"
     "    }\n"
     "}\n";


test "added field survives schema drift end-to-end" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        app = Path(tmpdir) / "app.jac";
        # v1: create two persons.
        app.write_text(V1_SOURCE);
        (rc, _, err) = _jac_enter(tmpdir, str(app), "create");
        assert rc == 0 , f"v1 create failed: {err}";
        # v2: swap the schema (adds `email` with default) and read back.
        app.write_text(V2_SOURCE_ADD_FIELD);
        (rc, out, err) = _jac_enter(tmpdir, str(app), "dump");
        assert rc == 0 , f"v2 dump failed: {err}";
        assert "v2:alice:30:unknown@example.com" in out , (
            f"alice lost across schema drift: {out}"
        );
        assert "v2:bob:25:unknown@example.com" in out , (
            f"bob lost across schema drift: {out}"
        );
        # Drift should be logged but cause zero data loss: quarantine empty.
        # The exact DB filename depends on get_db_path() (jaclang default is
        # `<stem>.db`; jac-scale plugin overrides to `anchor_store.db`), so
        # glob rather than hard-coding.
        import sqlite3;
        data_dir = Path(tmpdir) / ".jac" / "data";
        dbs = sorted(data_dir.glob("*.db"));
        assert dbs , f"no .db files in {data_dir}";
        for db in dbs {
            conn = sqlite3.connect(str(db));
            q = conn.execute("SELECT count(*) FROM anchors_quarantine").fetchone()[0];
            conn.close();
            assert q == 0 , (
                f"expected no quarantined anchors in {db.name} after tolerated drift, got {q}"
            );
        }
    }
}


test "removed field survives schema drift end-to-end" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        app = Path(tmpdir) / "app.jac";
        app.write_text(V1_SOURCE);
        (rc, _, err) = _jac_enter(tmpdir, str(app), "create");
        assert rc == 0 , f"v1 create failed: {err}";
        # v3 removes `age`. The stored `age` value is dropped; `name` and
        # the new `email` default come through.
        app.write_text(V3_SOURCE_REMOVE_FIELD);
        (rc, out, err) = _jac_enter(tmpdir, str(app), "dump");
        assert rc == 0 , f"v3 dump failed: {err}";
        assert "v3:alice:unknown@example.com" in out , (
            f"alice lost on field removal: {out}"
        );
        assert "v3:bob:unknown@example.com" in out , (
            f"bob lost on field removal: {out}"
        );
    }
}


test "same-schema reruns do not drift or quarantine anything" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        app = Path(tmpdir) / "app.jac";
        app.write_text(V1_SOURCE);
        (rc, _, err) = _jac_enter(tmpdir, str(app), "create");
        assert rc == 0 , f"create failed: {err}";
        (rc, out, err) = _jac_enter(tmpdir, str(app), "dump");
        assert rc == 0 , f"dump failed: {err}";
        assert "v1:alice:30" in out;
        assert "v1:bob:25" in out;
        # Identical schema on replay — no drift warnings expected.
        assert "schema drift" not in err , (
            f"unexpected drift logged on identical schema: {err}"
        );
    }
}
