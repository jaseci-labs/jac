"""End-to-end tests for the `jac db` CLI over the Postgres store.

Each test spawns real `jac ...` subprocesses so we exercise the full
subprocess + embedded-server + CLI argparse path - exactly the interface a
developer or operator uses.
"""

import from tests.support { jac_command }

import os;
import subprocess;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.data.pgembed { PgRuntime }


"""Run a subprocess and return (rc, stdout, stderr)."""
def _run(
    cwd: str, argv: list[str], extra_env: (dict[str, str] | None) = None
) -> tuple[int, str, str] {
    import jaclang;
    # -m jaclang must resolve to the source tree under test, not a
    # launcher-embedded snapshot.
    env: dict[str, str] = dict(os.environ);
    cache_home = Path(cwd) / '.cache';
    env['JAC_PG_DIST'] = PgRuntime(
        data_dir=str(cache_home / 'pg' / 'main')
    ).fetch_dist();
    env['JAC_CACHE_HOME'] = str(cache_home);
    env.pop('JAC_DB_URL', None);
    src = str(Path(jaclang.__file__).parent.parent);
    env['PYTHONPATH'] = src + os.pathsep + env.get('PYTHONPATH', '');
    env.update(extra_env or {});
    result = subprocess.run(
        argv, cwd=cwd, capture_output=True, text=True, timeout=300, env=env
    );
    return (result.returncode, result.stdout, result.stderr);
}


def _jac(
    cwd: str, args: list[str], extra_env: (dict[str, str] | None) = None
) -> tuple[int, str, str] {
    return _run(cwd, jac_command() + args, extra_env);
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


"""A jac.toml that points at the source tree but sets no [project] name, so
each .jac file would name its own database."""
def _seed_unnamed_project(tmpdir: str) {
    import jaclang;
    src = str(Path(jaclang.__file__).parent.parent);
    (Path(tmpdir) / "jac.toml").write_text(f'[dev]\njaclang_source = "{src}"\n');
}


def _free_port -> int {
    import socket;
    with socket.socket() as sock {
        sock.bind(("127.0.0.1", 0));
        return int(sock.getsockname()[1]);
    }
}


glob COUNT_NODES = "SELECT count(*) FROM anchors WHERE kind = 'NodeAnchor'";


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


test "db status on a stopped cluster reports stopped without restarting it" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        app = Path(tmpdir) / "app.jac";
        app.write_text(APP);
        _seed_project(tmpdir, "dbcli");
        try {
            (rc, _, err) = _jac(tmpdir, ["run", "--entry", "create", str(app)]);
            assert rc == 0 , f"create failed: {err}";
            _stop_db(tmpdir);
            (rc, out, err) = _jac(tmpdir, ["db", "status"]);
            assert rc == 0 , f"status failed: {err}";
            assert "running  : False" in out and "stopped" in out , out;
            assert "NodeAnchor" not in out , (
                f"a status probe must not boot a stopped cluster: {out!r}"
            );
            (rc, out, err) = _jac(tmpdir, ["db", "list"]);
            assert rc == 0 , f"list failed: {err}";
            assert "not running" in out , out;
            # A probe that had secretly restarted postgres would show up here.
            (rc, out, err) = _jac(tmpdir, ["db", "status"]);
            assert rc == 0 , f"second status failed: {err}";
            assert "running  : False" in out , out;
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


# jac#9407: the server names its database from jac.toml's [project] name
# whatever else sits in the directory; `jac db` used to fall back to "main"
# as soon as a second .jac file appeared.
test "db opens the server's database when jac.toml names a project beside several files" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        (Path(tmpdir) / "main.jac").write_text(APP);
        (Path(tmpdir) / "seed.jac").write_text("with entry { print('seed'); }\n");
        _seed_project(tmpdir, "shop");
        try {
            (rc, _, err) = _jac(tmpdir, ["run", "--entry", "create", "main.jac"]);
            assert rc == 0 , f"create failed: {err}";
            (rc, out, err) = _jac(tmpdir, ["db", "status"]);
            assert rc == 0 , f"status failed: {err}";
            assert "database : jac_shop_" in out , out;
            (rc, out, err) = _jac(tmpdir, ["db", "sql", COUNT_NODES]);
            assert rc == 0 , f"sql failed: {err}";
            assert out.strip() == "3" , f"expected the server's 3 nodes, got {out!r}";
        } finally {
            _stop_db(tmpdir);
        }
    }
}


test "db keeps the file-named database for a single file without a project name" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        (Path(tmpdir) / "app.jac").write_text(APP);
        _seed_unnamed_project(tmpdir);
        try {
            (rc, _, err) = _jac(tmpdir, ["run", "--entry", "create", "app.jac"]);
            assert rc == 0 , f"create failed: {err}";
            (rc, out, err) = _jac(tmpdir, ["db", "status"]);
            assert rc == 0 , f"status failed: {err}";
            assert "database : jac_app_" in out , out;
            (rc, out, err) = _jac(tmpdir, ["db", "sql", COUNT_NODES]);
            assert rc == 0 , f"sql failed: {err}";
            assert out.strip() == "3" , out;
        } finally {
            _stop_db(tmpdir);
        }
    }
}


test "db refuses to guess between several files with no project name, and --entry picks" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        (Path(tmpdir) / "alpha.jac").write_text(APP);
        (Path(tmpdir) / "beta.jac").write_text(APP);
        _seed_unnamed_project(tmpdir);
        try {
            (rc, out, err) = _jac(tmpdir, ["db", "status"]);
            assert rc == 1 , f"expected a refusal, got rc={rc}: {out}{err}";
            said = out + err;
            assert "alpha.jac" in said and "beta.jac" in said , said;
            assert "--entry" in said , said;
            (rc, _, err) = _jac(tmpdir, ["run", "--entry", "create", "alpha.jac"]);
            assert rc == 0 , f"create failed: {err}";
            (rc, out, err) = _jac(
                tmpdir, ["db", "sql", COUNT_NODES, "--entry", "alpha.jac"]
            );
            assert rc == 0 , f"sql failed: {err}";
            assert out.strip() == "3" , out;
            (rc, out, err) = _jac(tmpdir, ["db", "status", "--entry", "beta.jac"]);
            assert rc == 0 , f"status failed: {err}";
            assert "database : jac_beta_" in out , out;
            (rc, out, err) = _jac(tmpdir, ["db", "status", "--entry", "gamma.jac"]);
            assert rc == 1 and "gamma.jac" in out + err , out + err;
        } finally {
            _stop_db(tmpdir);
        }
    }
}


test "db reads JAC_DB_URL ahead of any project naming" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        (Path(tmpdir) / "alpha.jac").write_text(APP);
        (Path(tmpdir) / "beta.jac").write_text(APP);
        _seed_unnamed_project(tmpdir);
        # A second cluster on TCP stands in for an external Postgres.
        port = _free_port();
        external = PgRuntime(
            data_dir=str(Path(tmpdir) / "external" / "pg"),
            tcp=True,
            port=port,
            database="jac_external"
        );
        external.ensure();
        url = {"JAC_DB_URL": f"postgresql://jac@127.0.0.1:{port}/jac_external"};
        try {
            (rc, _, err) = _jac(tmpdir, ["run", "--entry", "create", "alpha.jac"], url);
            assert rc == 0 , f"create failed: {err}";
            (rc, out, err) = _jac(tmpdir, ["db", "status"], url);
            assert rc == 0 , f"status failed: {out}{err}";
            assert "jac_external" in out , out;
            (rc, out, err) = _jac(tmpdir, ["db", "sql", COUNT_NODES], url);
            assert rc == 0 , f"sql failed: {err}";
            assert out.strip() == "3" , out;
        } finally {
            external.stop();
            _stop_db(tmpdir);
        }
    }
}
