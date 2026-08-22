"""Read-path resilience to dangling references (#6619 piece 4, ported to PG).

The legacy corruption shapes were: (a) a node's edge list citing an edge row
that no longer exists, and (b) an edge row whose endpoint node is gone. Under
the Postgres store (epic #7945) shape (a) is structurally impossible — node
adjacency derives from the edge rows' src/dst, so a deleted edge row simply
disappears from every traversal. Shape (b) is filtered at query time: the
traversal join only yields endpoints that exist. Either way a `jac run` over
a corrupted database must exit 0 and return the surviving neighbours; these
tests corrupt the store out of band and drive the real read path end to end.
"""

import subprocess;
import sys;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { UUID }
import from jaclang.runtimelib.pgembed { PgRuntime }
import from jaclang.runtimelib.session { shared_pg_data_dir }
import from jaclang.runtimelib.store { PgStore, TxnIsolation }


"""Run `python -m jaclang <args>` in cwd; return (rc, stdout, stderr)."""
def _jac(cwd: str, args: list) -> tuple[int, str, str] {
    result = subprocess.run(
        [sys.executable, "-m", "jaclang"] + args,
        cwd=cwd,
        capture_output=True,
        text=True,
        timeout=180
    );
    return (int(result.returncode), str(result.stdout), str(result.stderr));
}


def _seed_project(tmpdir: str, name: str) {
    import jaclang;
    src = str(Path(str(jaclang.__file__)).parent.parent);
    (Path(tmpdir) / "jac.toml").write_text(
        f'[project]\nname = "{name}"\n\n[dev]\njaclang_source = "{src}"\n'
    );
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


"""Open a store on the project database `jac run` used under tmpdir.

The runtime derives the database name from its own base/target resolution;
rather than re-deriving it, find the one database whose name carries the
base-path digest."""
def _store_for(tmpdir: str, app: str) -> PgStore {
    import hashlib;
    import os;
    digest = hashlib.sha1(os.path.abspath(tmpdir).encode('utf-8')).hexdigest()[:8];
    admin_rt = PgRuntime(data_dir=shared_pg_data_dir(), database='postgres');
    admin = PgStore(conninfo=admin_rt.ensure());
    admin.begin(TxnIsolation.READ_COMMITTED);
    names = [
        str(r[0])
        for r in admin.rows(
            "SELECT datname FROM pg_database WHERE datname LIKE :p",
            {'p': f"%_{digest}"}
        )
    ];
    admin.commit();
    admin.close();
    assert names , f"no project database found for digest {digest}";
    rt = PgRuntime(data_dir=shared_pg_data_dir(), database=names[0]);
    return PgStore(conninfo=rt.ensure());
}


test "traversal skips a deleted edge row instead of raising" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        app = Path(tmpdir) / "app.jac";
        app.write_text(APP);
        _seed_project(tmpdir, "dangling_edge");
        (rc, _, err) = _jac(tmpdir, ["run", "--entry", "create", str(app)]);
        assert rc == 0 , f"create failed: {err}";
        st = _store_for(tmpdir, str(app));
        victim = str(
            st.rows("SELECT id FROM anchors WHERE kind = 'EdgeAnchor' LIMIT 1", {})[0][
                0
            ]
        );
        st.rows("DELETE FROM anchors WHERE id = CAST(:i AS uuid)", {'i': victim});
        # The dump walker visits [-->] from root: the deleted edge is simply
        # absent from adjacency; the surviving edge resolves and its Thing
        # is visited.
        (rc, out, err) = _jac(tmpdir, ["run", "--entry", "dump", str(app)]);
        assert rc == 0 , f"dump must not crash on a deleted edge (got rc={rc}): {err}";
        survivors = [
            ln
            for ln in out.splitlines()
            if ln.strip() in ("alice", "bob")
        ];
        assert len(survivors) == 1 , (
            f"exactly the surviving Thing must be visited, got: {out!r}"
        );
        remaining = st.rows(
            "SELECT COUNT(*) FROM anchors WHERE kind = 'EdgeAnchor'", {}
        )[0][0];
        assert remaining == 1 , f"one edge row should remain, got {remaining}";
        st.close();
    }
}


test "traversal skips an edge whose target node was deleted (ghost endpoint)" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        app = Path(tmpdir) / "app.jac";
        app.write_text(APP);
        _seed_project(tmpdir, "ghost_endpoint");
        (rc, _, err) = _jac(tmpdir, ["run", "--entry", "create", str(app)]);
        assert rc == 0 , f"create failed: {err}";
        st = _store_for(tmpdir, str(app));
        ghost = str(
            st.rows(
                """
                SELECT id FROM anchors
                WHERE kind = 'NodeAnchor' AND arch_type = 'Thing' LIMIT 1
                """,
                {}
            )[0][0]
        );
        st.rows("DELETE FROM anchors WHERE id = CAST(:i AS uuid)", {'i': ghost});
        # The traversal join only yields endpoints that exist: the ghost
        # edge contributes nothing and the walk completes on the survivor.
        (rc, out, err) = _jac(tmpdir, ["run", "--entry", "dump", str(app)]);
        assert rc == 0 , f"dump must not crash on a ghost-endpoint edge: {err}";
        survivors = [
            ln
            for ln in out.splitlines()
            if ln.strip() in ("alice", "bob")
        ];
        assert len(survivors) == 1 , (
            f"exactly the surviving Thing must be visited, got: {out!r}"
        );
        st.close();
    }
}
