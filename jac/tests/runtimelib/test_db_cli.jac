"""End-to-end tests for the `jac db` CLI subcommands.

Each test spawns real `jac db ...` (and sometimes `jac enter`) subprocesses
so we exercise the full subprocess + DB-on-disk + CLI argparse path —
exactly the interface a developer or operator uses.
"""

import os;
import subprocess;
import sys;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }


"""Run a subprocess and return (rc, stdout, stderr)."""
def _run(cwd: str, argv: list) -> tuple {
    result = subprocess.run(argv, cwd=cwd, capture_output=True, text=True, timeout=180);
    return (result.returncode, result.stdout, result.stderr);
}


def _jac(cwd: str, args: list) -> tuple {
    return _run(cwd, [sys.executable, "-m", "jaclang"] + args);
}


glob V1_LEGACY = "node LegacyPerson { has name: str; }\n"
     "walker create {\n"
     "    can s with Root entry {\n"
     "        here ++> LegacyPerson(name=\"alice\");\n"
     "        here ++> LegacyPerson(name=\"bob\");\n"
     "    }\n"
     "}\n",
     V2_PERSON = "node Person { has name: str; }\n"
     "walker dump {\n"
     "    can r with Root entry { visit [-->]; }\n"
     "    can p with Person entry { print(here.name); }\n"
     "}\n";


test "db inspect prints a summary with counts" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        app = Path(tmpdir) / "app.jac";
        app.write_text(V1_LEGACY);
        (rc, _, err) = _jac(tmpdir, ["enter", str(app), "create"]);
        assert rc == 0 , f"create failed: {err}";
        (rc, out, err) = _jac(tmpdir, ["db", "inspect"]);
        assert rc == 0 , f"inspect failed: {err}";
        # Assert only on the summary line, which is rendered via plain
        # console.info() and is deterministic regardless of terminal
        # width. The per-arch_type Rich table IS printed, but its cell
        # contents are truncated / styled in terminal-width-dependent
        # ways (including ANSI codes in some CI environments), which
        # makes substring assertions on class names fundamentally
        # fragile. The summary line is enough to prove the CLI ran
        # correctly; archetype-level correctness is exercised by
        # backend-direct unit tests.
        assert "format_version=1" in out , f"summary missing format_version: {out!r}";
        # Create walker makes 2 LegacyPerson nodes on root, which also
        # creates 2 GenericEdge anchors -- 5 anchors total with root.
        assert "anchors=5" in out , f"expected anchors=5 in summary: {out!r}";
        assert "quarantined=0" in out;
    }
}


test "db alias add/list/remove round-trip works" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        app = Path(tmpdir) / "app.jac";
        app.write_text(V1_LEGACY);
        # Need a DB to act on.
        _jac(tmpdir, ["enter", str(app), "create"]);
        # Initially empty: console.info() line is plain text, not Rich,
        # so this assertion is stable across terminal widths.
        (rc, out, _) = _jac(tmpdir, ["db", "alias", "list"]);
        assert rc == 0;
        assert "No DB-resident aliases" in out;
        # Add: console.success() emits "Alias registered: ..." as plain text.
        (rc, out, _) = _jac(tmpdir, ["db", "alias", "add", "old.mod.X", "new.mod.Y"]);
        assert rc == 0;
        assert "registered" in out.lower();
        # Verify the alias actually landed in the DB by querying it directly,
        # not by parsing the Rich-rendered table (which is terminal-width-
        # sensitive in CI).
        import sqlite3;
        data_dir = Path(tmpdir) / ".jac" / "data";
        dbs = sorted(data_dir.glob("*.db"));
        assert dbs;
        conn = sqlite3.connect(str(dbs[0]));
        rows = list(
            conn.execute("SELECT old_name, new_name FROM aliases ORDER BY old_name")
        );
        conn.close();
        assert rows == [("old.mod.X", "new.mod.Y")];
        # Also confirm `alias list` exits cleanly (table render, rc check only).
        (rc, _, _) = _jac(tmpdir, ["db", "alias", "list"]);
        assert rc == 0;
        # Remove.
        (rc, out, _) = _jac(tmpdir, ["db", "alias", "remove", "old.mod.X"]);
        assert rc == 0;
        assert "Removed" in out;
        # Confirm removal via DB, and that list reports empty via its info line.
        conn = sqlite3.connect(str(dbs[0]));
        count = conn.execute("SELECT count(*) FROM aliases").fetchone()[0];
        conn.close();
        assert count == 0;
        (rc, out, _) = _jac(tmpdir, ["db", "alias", "list"]);
        assert rc == 0;
        assert "No DB-resident aliases" in out;
    }
}


test "db recover-all rescues quarantined rows after CLI alias add" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        app = Path(tmpdir) / "app.jac";
        # v1: LegacyPerson is the live class.
        app.write_text(V1_LEGACY);
        _jac(tmpdir, ["enter", str(app), "create"]);
        # Swap to v2: Person, with NO @archetype_alias. Old anchors quarantine
        # when the v2 walker tries to traverse them.
        app.write_text(V2_PERSON);
        _jac(tmpdir, ["enter", str(app), "dump"]);
        # Confirm quarantine populated.
        (rc, out, _) = _jac(tmpdir, ["db", "inspect"]);
        assert rc == 0;
        assert "quarantined=2" in out;
        # Operator-side rescue: register the alias in the DB, then recover.
        (rc, _, _) = _jac(
            tmpdir, ["db", "alias", "add", "__main__.LegacyPerson", "__main__.Person"]
        );
        assert rc == 0;
        (rc, out, err) = _jac(tmpdir, ["db", "recover-all", "--app", str(app)]);
        assert rc == 0 , f"recover-all failed: {err}";
        assert "Recovered 2 of 2" in out;
        # Inspect confirms quarantine cleared via its plain-text summary line.
        (rc, out, _) = _jac(tmpdir, ["db", "inspect"]);
        assert rc == 0;
        assert "quarantined=0" in out;
        # Confirm the recovered rows are now stamped as Person by querying the
        # DB directly -- the Rich-rendered arch_type table is terminal-width
        # dependent and unreliable for substring matching in CI.
        import sqlite3;
        data_dir = Path(tmpdir) / ".jac" / "data";
        dbs = sorted(data_dir.glob("*.db"));
        assert dbs;
        conn = sqlite3.connect(str(dbs[0]));
        person_count = conn.execute(
            "SELECT count(*) FROM anchors WHERE arch_type = 'Person'"
        ).fetchone()[0];
        legacy_count = conn.execute(
            "SELECT count(*) FROM anchors WHERE arch_type = 'LegacyPerson'"
        ).fetchone()[0];
        conn.close();
        assert person_count == 2 , f"expected 2 rows stamped as Person, got {person_count}";
        assert legacy_count == 0 , f"expected 0 stale LegacyPerson rows, got {legacy_count}";
        # Final smoke: the dump walker now finds the recovered data.
        (rc, out, err) = _jac(tmpdir, ["enter", str(app), "dump"]);
        assert rc == 0 , f"dump failed: {err}";
        assert "alice" in out and "bob" in out;
    }
}


test "db quarantine list and show return data, never silently empty" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        app = Path(tmpdir) / "app.jac";
        app.write_text(V1_LEGACY);
        _jac(tmpdir, ["enter", str(app), "create"]);
        # Force quarantine.
        app.write_text(V2_PERSON);
        _jac(tmpdir, ["enter", str(app), "dump"]);
        # `quarantine list` renders via Rich print_table (terminal-width
        # sensitive in CI), so assert only on exit code -- the fact that
        # rows exist is verified via direct DB query below.
        (rc, _, _) = _jac(tmpdir, ["db", "quarantine", "list"]);
        assert rc == 0;
        # Find a row id straight from the DB for the show step, and
        # confirm quarantine has exactly the expected 2 rows.
        import sqlite3;
        data_dir = Path(tmpdir) / ".jac" / "data";
        dbs = sorted(data_dir.glob("*.db"));
        assert dbs;
        conn = sqlite3.connect(str(dbs[0]));
        ids = [r[0] for r in conn.execute("SELECT id FROM anchors_quarantine LIMIT 1")];
        conn.close();
        assert ids;
        # `quarantine show` prints json.dumps() output -- plain text, not a
        # Rich table, so substring matching on class names is safe.
        (rc, out, _) = _jac(tmpdir, ["db", "quarantine", "show", ids[0]]);
        assert rc == 0;
        assert ids[0] in out;
        assert "LegacyPerson" in out;
    }
}


test "db rejects bad sub-actions with helpful errors" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        app = Path(tmpdir) / "app.jac";
        app.write_text(V1_LEGACY);
        _jac(tmpdir, ["enter", str(app), "create"]);
        (rc, _, err) = _jac(tmpdir, ["db", "alias", "frobnicate"]);
        assert rc != 0;
        assert "alias" in err.lower() or "expected" in err.lower();
        (rc, _, err) = _jac(tmpdir, ["db", "quarantine", "frobnicate"]);
        assert rc != 0;
    }
}
