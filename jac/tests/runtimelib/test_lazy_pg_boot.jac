"""Lazy embedded-Postgres boot and a runnable official image (#8045).

The stock jaseci/jaclang image could not run `with entry { print("hello"); }`:
the Session booted an embedded Postgres for every program, the image shipped
no PG binaries (so the ~40MB distribution was fetched over the network at
container start), and the image ran as root, where initdb hard-fails. These
tests pin the four invariants that make the image runnable as shipped:

  1. constructing a Session costs nothing; a program that never touches
     persistent state never invokes the embedded-PG bootstrap
  2. the first real store access boots it, exactly once
  3. when euid is 0 the embedded engine drops privileges to a resolvable
     unprivileged account, or refuses with an actionable diagnostic
  4. the official image bakes the PG distribution and defaults to a real
     non-root account, and run/server mode does not block-buffer stdout
"""

import os;
import re;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { UUID }
import from jaclang { JacRuntime as Jac }
import from jaclang.cli.commands { execution }
import from jaclang.compiler.frontend.constant { Constants as Con }
import from jaclang.data.pgembed { PgRuntime }
import from jaclang.server.session { Session }
import from jaclang.data.store { PgStore }

glob FIXTURES = str(Path(__file__).parent / "fixtures"),
     REPO_ROOT = Path(__file__).resolve().parents[3],
     DOCKERFILE = REPO_ROOT / "docker" / "jaclang.Dockerfile";


def _as_any(v: any) -> any {
    return v;
}

obj _BootProbe {
    has calls: list[str] = [],
        _orig: any = None;

    def install {
        self._orig = PgRuntime.ensure;
        calls = self.calls;
        orig = self._orig;

        def _probe(rt: any) -> any {
            calls.append(str(rt.database));
            return orig(rt);
        }
        PgRuntime.ensure = _as_any(_probe);
    }

    def remove {
        if self._orig is not None {
            PgRuntime.ensure = self._orig;
        }
    }
}


test "a stateless program never boots the embedded postgres" {
    probe = _BootProbe();
    probe.install();
    orig_base = Jac.get_base_path_dir();
    try {
        Jac.set_base_path(FIXTURES);
        rc = execution.run(target=os.path.join(FIXTURES, "stateless_hello.jac"));
        assert rc == 0 , f"stateless_hello.jac exited {rc}";
        assert probe.calls == [] , (
            f"a program that touches no graph state booted embedded postgres "
            f"{len(probe.calls)} time(s) (databases: {probe.calls})"
        );
    } finally {
        probe.remove();
        Jac.set_base_path(orig_base);
    }
}


test "session construction is free and the first store read boots once" {
    probe = _BootProbe();
    probe.install();
    try {
        with TemporaryDirectory() as td {
            sess = Session(base_path=td, target_path=str(Path(td) / "app.jac"));
            try {
                assert sess.store is not None , (
                    "a Session with a base path still owns a persistent store"
                );
                assert probe.calls == [] , (
                    f"constructing a Session booted postgres: {probe.calls}"
                );
                sess.get(UUID(Con.SUPER_ROOT_UUID));
                assert len(probe.calls) == 1 , (
                    f"the first real store read must boot exactly once, "
                    f"got {len(probe.calls)}"
                );
                sess.get(UUID(Con.SUPER_ROOT_UUID));
                sess.`has(UUID(Con.SUPER_ROOT_UUID));
                assert len(probe.calls) == 1 , (
                    f"later reads must reuse the booted server, "
                    f"got {len(probe.calls)} boots"
                );
            } finally {
                sess.close();
            }
        }
    } finally {
        probe.remove();
    }
}


test "an unprivileged euid runs the embedded engine as-is" {
    import from jaclang.data.pgembed { PgPrivMode, pg_priv_plan }

    plan = pg_priv_plan(1000, []);
    assert plan.mode == PgPrivMode.AS_IS;
    assert plan.run_as is None;
}


test "euid 0 drops privileges to a resolvable unprivileged account" {
    import from jaclang.data.pgembed { PgPrivMode, PgRunAs, pg_priv_plan }

    plan = pg_priv_plan(
        0,
        [
            PgRunAs(name="root", uid=0, gid=0),
            PgRunAs(name="nobody", uid=65534, gid=65534)
        ]
    );
    assert plan.mode == PgPrivMode.DROP;
    assert plan.run_as is not None;
    target = plan.run_as;
    assert target.uid == 65534 , f"picked uid {target.uid}, want the non-root account";
    assert target.name == "nobody";
}


test "euid 0 with no unprivileged account fails with an actionable diagnostic" {
    import from jaclang.data.pgembed { PgPrivMode, pg_priv_plan }

    plan = pg_priv_plan(0, []);
    assert plan.mode == PgPrivMode.BLOCKED;
    assert plan.run_as is None;
    for hint in ["JAC_PG_USER", "JAC_DB_URL", "root"] {
        assert hint in plan.reason , f"diagnostic must mention {hint}: {plan.reason}";
    }
}


test "candidate discovery never offers a privileged account" {
    import from jaclang.data.pgembed { pg_run_candidates }

    for cand in pg_run_candidates() {
        assert cand.uid != 0 , f"candidate {cand.name} is privileged";
        assert cand.name , "candidate must carry a name initdb can look up";
    }
}


test "the official image bakes the embedded postgres distribution" {
    text = DOCKERFILE.read_text();
    pinned = re.search(r"(?m)^ENV\s+JAC_PG_DIST=(\S+)", text);
    assert pinned is not None , (
        "the image must pin JAC_PG_DIST so no distribution is fetched at boot"
    );
    dist = pinned.group(1);
    assert f"{dist}" in text.split("ENV JAC_PG_DIST=")[0] , (
        f"nothing in the build populates {dist}; the image would still "
        f"download postgres at container start"
    );
}


test "the official image defaults to a real non-root account" {
    text = DOCKERFILE.read_text();
    users = re.findall(r"(?m)^USER\s+(\S+)", text);
    assert users , "the image must declare a USER";
    who = users[-1];
    assert who not in ("root", "0") , f"the image still defaults to {who}";
    created = re.search(rf"(useradd|adduser)[^\n]*\b{re.escape(who)}\b", text);
    assert created is not None , (
        f"USER {who} has no /etc/passwd entry; initdb refuses a uid it "
        f"cannot look up"
    );
    assert re.search(r"--uid\s+\d+|--gid\s+\d+", text) is not None , (
        "pin the account's uid so an explicit runAsUser matches it"
    );
}


# --- First-use schema DDL has exactly one gate (#8117 item 2) --------------
obj _CountingStore(PgStore) {
    has ddl_runs: int = 0;

    def ensure_schema(promotions: dict[str, list[str]]) {
        self.ddl_runs += 1;
    }
}


test "first-use schema DDL runs once per database, even from many threads" {
    import threading;
    import from uuid { uuid4 }
    import from jaclang.data.store { ConnInfo }

    store = _CountingStore(
        conninfo=ConnInfo(
            host="127.0.0.1", port=1, database=f"jac_gate_{uuid4().hex[:8]}"
        )
    );
    racers = 8;
    ready = threading.Barrier(racers);

    def race {
        ready.`wait(10);
        store.ensure_schema_once({});
    }
    threads = [
        threading.Thread(target=race, name="jac-gate-racer") for _ in range(racers)
    ];
    for t in threads {
        t.start();
    }
    for t in threads {
        t.join(30);
    }
    assert store.ddl_runs == 1 , (
        f"{racers} concurrent first uses ran schema DDL {store.ddl_runs} time(s); "
        "each one past the first can take the DDL lock timeout and surface a "
        "SessionConflictError on an ordinary first request"
    );
    store.ensure_schema_once({});
    assert store.ddl_runs == 1 , "the gate forgot that the schema was already up";
}


# --- The schema gate is safe on a store nobody has readied (#8982 item 16) ---
obj _FirstUseStore(PgStore) {
    has ddl_runs: int = 0;

    def _run(sql: str, params: dict) -> list {
        self._ensure_ready();
        return [("170000", )];
    }

    def ensure_schema(promotions: dict[str, list[str]]) {
        self.ddl_runs += 1;
        self.server_version();
    }
}


test "the schema gate readies the store instead of deadlocking on first use" {
    import threading;
    import from uuid { uuid4 }
    import from jaclang.data.store { ConnInfo }

    store = _FirstUseStore(
        conninfo=ConnInfo(
            host="127.0.0.1", port=1, database=f"jac_gate_{uuid4().hex[:8]}"
        ),
        auto_schema=True
    );
    outcome: list = [];

    def first_use {
        store.ensure_schema_once({});
        outcome.append(store.ddl_runs);
    }
    t = threading.Thread(target=first_use, name="jac-gate-first-use", daemon=True);
    t.start();
    t.join(10);
    assert not t.is_alive() , (
        "ensure_schema_once on an un-readied auto_schema store deadlocked: the "
        "gate was held while the schema DDL's first query readied the store, "
        "and readiness asked for the gate again"
    );
    assert outcome == [1] , f"schema DDL ran {outcome} time(s); expected exactly once";
    assert store._ready , "first use through the schema gate left the store un-readied";
}


test "no production module runs first-use schema DDL outside the gate" {
    # PgStore.ensure_schema_once owns the _schema_gate + _schema_ready pair.
    # A second caller that reaches straight for ensure_schema races it, and
    # whichever side loses the DDL lock raises SessionConflictError at what is,
    # to the operator, a plain first request against a fresh database.
    src = REPO_ROOT / "jac" / "jaclang";
    owner = {"data/store.jac", "data/impl/store.impl.jac"};
    offenders: list[str] = [];
    for path in sorted(src.rglob("*.jac")) {
        if not path.is_file() {
            continue;
        }
        rel = path.relative_to(src).as_posix();
        if rel in owner or "tests/" in rel {
            continue;
        }
        if ".ensure_schema(" in path.read_text() {
            offenders.append(rel);
        }
    }
    assert offenders == [] , (
        f"these call first-use schema DDL past the gate: {offenders}; call "
        "PgStore.ensure_schema_once instead"
    );
}


test "run and server mode line-buffer their output streams" {
    import from jaclang.cli.console { use_line_buffered_output }

    with TemporaryDirectory() as td {
        path = os.path.join(td, "out.log");
        with open(path, "w") as f {
            assert not f.line_buffering , "fixture stream starts block-buffered";
            switched = use_line_buffered_output([f]);
            assert switched == 1 , f"expected 1 stream switched, got {switched}";
            assert f.line_buffering , "stream must be line-buffered";
            f.write("first line\n");
            with open(path) as probe {
                assert probe.read() == "first line\n" , (
                    "a line written before exit must already be on disk"
                );
            }
        }
    }
}
