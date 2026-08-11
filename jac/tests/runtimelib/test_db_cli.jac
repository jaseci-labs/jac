"""End-to-end tests for the `jac db` CLI over the Postgres store.

Each test spawns real `jac ...` subprocesses so we exercise the full
subprocess + embedded-server + CLI argparse path — exactly the interface a
developer or operator uses.
"""

import os;
import subprocess;
import sys;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }


"""Run a subprocess and return (rc, stdout, stderr)."""
def _run(cwd: str, argv: list) -> tuple {
    import jaclang;
    # -m jaclang must resolve to the source tree under test, not a
    # launcher-embedded snapshot.
    env = dict(os.environ);
    src = str(Path(jaclang.__file__).parent.parent);
    env['PYTHONPATH'] = src + os.pathsep + env.get('PYTHONPATH', '');
    result = subprocess.run(
        argv, cwd=cwd, capture_output=True, text=True, timeout=300, env=env
    );
    return (result.returncode, result.stdout, result.stderr);
}


def _jac(cwd: str, args: list) -> tuple {
    return _run(cwd, [sys.executable, "-m", "jaclang"] + args);
}


"""Point the tmp project at the source tree under test (launcher binaries
otherwise serve their embedded jaclang snapshot for CLI dispatch)."""
def _seed_project(tmpdir: str, name: str) {
    import jaclang;
    src = str(Path(jaclang.__file__).parent.parent);
    (Path(tmpdir) / "jac.toml").write_text(
        f'[project]\nname = "{name}"\n\n[dev]\njaclang_source = "{src}"\n'
    );
}


def _stop_db(cwd: str) {
    _jac(cwd, ["db", "stop"]);
}


glob APP = "node Person { has name: str; }\n"
     "walker create {\n"
     "    can s with Root entry {\n"
     "        here ++> Person(name=\"alice\");\n"
     "        here ++> Person(name=\"bob\");\n"
     "    }\n"
     "}\n";


test "db status reports server state and row counts after a run" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        app = Path(tmpdir) / "app.jac";
        app.write_text(APP);
        _seed_project(tmpdir, "dbcli");
        try {
            (rc, _, err) = _jac(tmpdir, ["run", "--entry", "create", str(app)]);
            assert rc == 0 , f"create failed: {err}";
            (rc, out, err) = _jac(tmpdir, ["db", "status"]);
            assert rc == 0 , f"status failed: {err}";
            assert "running" in out;
            # root + 2 Person nodes, 2 edges
            assert "NodeAnchor" in out and "EdgeAnchor" in out , out;
        } finally {
            _stop_db(tmpdir);
        }
    }
}


test "db sql runs a statement against the project store" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        app = Path(tmpdir) / "app.jac";
        app.write_text(APP);
        _seed_project(tmpdir, "dbcli");
        try {
            (rc, _, err) = _jac(tmpdir, ["run", "--entry", "create", str(app)]);
            assert rc == 0 , f"create failed: {err}";
            (rc, out, err) = _jac(
                tmpdir,
                ["db", "sql", "SELECT count(*) FROM anchors WHERE kind = 'NodeAnchor'"]
            );
            assert rc == 0 , f"sql failed: {err}";
            assert "3" in out , f"expected 3 nodes in: {out!r}";
        } finally {
            _stop_db(tmpdir);
        }
    }
}


test "db rejects unknown actions" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        (rc, _, err) = _jac(tmpdir, ["db", "definitely-not-an-action"]);
        assert rc != 0;
    }
}
