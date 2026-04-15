"""Layer 3 end-to-end tests: archetype rename via alias, plus type-change drift.

Each test writes a v1 .jac file, runs `jac enter` to persist data, then
rewrites the file to a v2 that either (a) renames the archetype class but
keeps an alias to the old name, or (b) changes a field's declared type and
relies on the coercion table to load the stored value correctly.

Mirrors the subprocess-per-invocation pattern from
test_persistence_migration_e2e.jac so each run is a fresh Python process
with a fresh class registry.
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


# --- Alias: class rename ----------------------------------------------------
glob V1_RENAME = "node LegacyPerson {\n"
     "    has name: str;\n"
     "}\n"
     "walker create {\n"
     "    can s with Root entry {\n"
     "        here ++> LegacyPerson(name=\"alice\");\n"
     "        here ++> LegacyPerson(name=\"bob\");\n"
     "    }\n"
     "}\n",
     # v2: renames LegacyPerson -> Person, declares an alias so old
     # stored anchors resolve instead of quarantining. `archetype_alias`
     # is an ambient Jac builtin; no import needed.
     V2_RENAME_WITH_ALIAS = "@archetype_alias(\"__main__.LegacyPerson\")\n"
     "node Person {\n"
     "    has name: str;\n"
     "}\n"
     "walker dump {\n"
     "    can r with Root entry { visit [-->]; }\n"
     "    can p with Person entry { print(f\"renamed:{here.name}\"); }\n"
     "}\n",
     # v2_no_alias: same rename but WITHOUT an alias — stored anchors
     # should fall through to quarantine, and the dump walker finds nothing.
     V2_RENAME_WITHOUT_ALIAS = "node Person {\n"
     "    has name: str;\n"
     "}\n"
     "walker dump {\n"
     "    can r with Root entry { visit [-->]; }\n"
     "    can p with Person entry { print(f\"renamed:{here.name}\"); }\n"
     "}\n";


test "archetype_alias resolves a renamed class back to the new class" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        app = Path(tmpdir) / "app.jac";
        app.write_text(V1_RENAME);
        (rc, _, err) = _jac_enter(tmpdir, str(app), "create");
        assert rc == 0 , f"v1 create failed: {err}";
        app.write_text(V2_RENAME_WITH_ALIAS);
        (rc, out, err) = _jac_enter(tmpdir, str(app), "dump");
        assert rc == 0 , f"v2 dump failed: {err}";
        assert "renamed:alice" in out , f"alice lost on rename: {out}";
        assert "renamed:bob" in out , f"bob lost on rename: {out}";
        # No row should have been quarantined — the alias covers the rename.
        import sqlite3;
        data_dir = Path(tmpdir) / ".jac" / "data";
        for db in sorted(data_dir.glob("*.db")) {
            conn = sqlite3.connect(str(db));
            q = conn.execute("SELECT count(*) FROM anchors_quarantine").fetchone()[0];
            conn.close();
            assert q == 0 , f"aliased rename should not quarantine; got {q} in {db.name}";
        }
    }
}


test "rename without alias quarantines the stored anchors (control)" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        app = Path(tmpdir) / "app.jac";
        app.write_text(V1_RENAME);
        (rc, _, err) = _jac_enter(tmpdir, str(app), "create");
        assert rc == 0 , f"v1 create failed: {err}";
        # v2 has Person but NO alias back to LegacyPerson. Running the dump
        # walker may exit non-zero when it encounters an unresolvable stub
        # (orphan traversal semantics aren't in scope for Layer 3 — what
        # matters is that the data IS quarantined, not silently deleted).
        app.write_text(V2_RENAME_WITHOUT_ALIAS);
        _jac_enter(tmpdir, str(app), "dump");
        # Without alias: old data must NOT silently disappear; it lands
        # in the quarantine table instead. This is the core invariant.
        import sqlite3;
        data_dir = Path(tmpdir) / ".jac" / "data";
        total_q = 0;
        for db in sorted(data_dir.glob("*.db")) {
            conn = sqlite3.connect(str(db));
            total_q += conn.execute(
                "SELECT count(*) FROM anchors_quarantine"
            ).fetchone()[0];
            conn.close();
        }
        assert total_q >= 2 , (
            "expected at least 2 quarantined anchors (alice, bob) after "
            f"un-aliased rename; got {total_q}"
        );
    }
}


# --- Coercion: field type change -------------------------------------------
glob V1_TYPED = "node Item {\n"
     "    has label: str;\n"
     "    has count: int = 0;\n"
     "}\n"
     "walker create {\n"
     "    can s with Root entry {\n"
     "        here ++> Item(label=\"one\", count=1);\n"
     "        here ++> Item(label=\"two\", count=2);\n"
     "    }\n"
     "}\n",
     # v2: `count` changed from int to str. Coercion must bring the stored
     # int values back in as strings so dump() works without failure.
     V2_INT_TO_STR = "node Item {\n"
     "    has label: str;\n"
     "    has count: str = \"0\";\n"
     "}\n"
     "walker dump {\n"
     "    can r with Root entry { visit [-->]; }\n"
     "    can p with Item entry {\n"
     "        print(f\"coerced:{here.label}:{here.count}:{type(here.count).__name__}\");\n"
     "    }\n"
     "}\n";


test "field type int->str coerces on load without quarantine" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        app = Path(tmpdir) / "app.jac";
        app.write_text(V1_TYPED);
        (rc, _, err) = _jac_enter(tmpdir, str(app), "create");
        assert rc == 0 , f"v1 create failed: {err}";
        app.write_text(V2_INT_TO_STR);
        (rc, out, err) = _jac_enter(tmpdir, str(app), "dump");
        assert rc == 0 , f"v2 dump failed: {err}";
        assert "coerced:one:1:str" in out , (
            f"int->str coercion did not apply to count for item 'one': {out}"
        );
        assert "coerced:two:2:str" in out , (
            f"int->str coercion did not apply to count for item 'two': {out}"
        );
        # No quarantine expected for type-change handled by coercion.
        import sqlite3;
        data_dir = Path(tmpdir) / ".jac" / "data";
        for db in sorted(data_dir.glob("*.db")) {
            conn = sqlite3.connect(str(db));
            q = conn.execute("SELECT count(*) FROM anchors_quarantine").fetchone()[0];
            conn.close();
            assert q == 0 , (
                f"coercible type change should not quarantine; got {q} in {db.name}"
            );
        }
    }
}
