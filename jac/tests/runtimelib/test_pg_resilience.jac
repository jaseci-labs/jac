"""Startup resilience for the pg-native Session.

Every jac process holds a long-lived transaction by design (transaction as
the single source of truth), so two processes touching the same project
database is the normal case, not an edge case. This suite pins the four
behaviors that make that survivable:

  layer 1 — ensure_schema skips DDL entirely when the schema is current,
            so the common boot path never competes for table locks;
  layer 2 — connections carry a jac:<pid>:<cmd> identity, backends whose
            owning process died are reaped automatically, live conflicts
            surface as SessionConflictError, and takeover_project() evicts
            every other session on the project database;
  layer 3 — known SQLSTATEs map to actionable CLI messages;
  layer 4 — the embedded server is provisioned with enough connection
            headroom for a default test-runner fan-out.

New APIs are imported inside test bodies on purpose: each test must fail on
its own missing behavior, not on a shared import error.

These tests share the CI cluster with suites that stop/restart it, so every
raw connection retries through the restart window (57P03/57P01/08006) and
the lock-contention scenarios re-arm themselves if a restart drops the
blocking transaction mid-scenario. PgStore instances get ensure_cb so the
store's own reconnect path handles the same window.
"""

import os;
import time;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.runtimelib.pgembed { PgRuntime }
import from jaclang.runtimelib.session { shared_pg_data_dir, project_db_name }
import from jaclang.runtimelib.store { ConnInfo, PgStore }
import from jaclang.runtimelib.pgwire { PgWireError }
import from jaclang.vendor.pgload { connect as pg_connect }

glob STAMP_KEY = 'schema_fingerprint';


def _restartish(e: Exception) -> bool {
    # The shared CI cluster is stopped/restarted by other suites; these are
    # the signatures of hitting that window.
    if isinstance(e, (ConnectionError, BrokenPipeError, EOFError, OSError)) {
        return True;
    }
    for arg in getattr(e, 'args', ()) {
        if isinstance(arg, dict)
            and arg.get('C') in ('57P03', '57P01', '08006', '08003') {
            return True;
        }
    }
    return False;
}


def _mk_store(td: str) -> tuple {
    target = str(Path(td) / 'app.jac');
    rt = PgRuntime(
        data_dir=shared_pg_data_dir(),
        database=project_db_name(td, target),
        owner_path=td
    );
    info = rt.ensure();
    return (PgStore(conninfo=info, ensure_cb=rt.ensure), info, target, rt);
}


def _peer(info: ConnInfo, app_name: str) -> any {
    last: any = None;
    for _ in range(30) {
        try {
            return pg_connect(
                info.user,
                host=(info.host or None),
                port=info.port,
                unix_socket_dir=info.unix_socket_dir,
                database=info.database,
                password=(info.password or None),
                startup_params={'application_name': app_name}
            );
        } except Exception as e {
            if not _restartish(e) {
                raise;
            }
            last = e;
            time.sleep(1.0);
        }
    }
    raise last;
}


def _hold_write(peer: any) {
    # An open transaction that has written to anchors: RowExclusiveLock,
    # which any CREATE INDEX [IF NOT EXISTS] replay must wait behind.
    peer.run('BEGIN');
    peer.run(
        """
        INSERT INTO anchors (id, kind)
        VALUES ('11111111-1111-1111-1111-111111111111', 'NodeAnchor')
        """
    );
}


def _release(peer: any) {
    try {
        peer.run('ROLLBACK');
    } except Exception { }
    try {
        peer.close();
    } except Exception { }
}


def _armed_peer(info: ConnInfo, app_name: str) -> any {
    # Peer with an open write transaction, re-armed through restarts.
    last: any = None;
    for _ in range(10) {
        peer = _peer(info, app_name);
        try {
            _hold_write(peer);
            return peer;
        } except Exception as e {
            _release(peer);
            if not _restartish(e) {
                raise;
            }
            last = e;
            time.sleep(1.0);
        }
    }
    raise last;
}


test "layer1: current schema boots without waiting on DDL locks" {
    with TemporaryDirectory() as td {
        (s1, info, _, rt) = _mk_store(td);
        s1.ensure_schema({});
        peer = _armed_peer(info, 'jac:0:peer');
        s2 = PgStore(conninfo=info, ensure_cb=rt.ensure);
        try {
            t0 = time.monotonic();
            s2.ensure_schema({});
            elapsed = time.monotonic() - t0;
            assert elapsed < 3.0 , (
                f"ensure_schema took {elapsed:.1f}s with the schema already "
                "current: it competed for DDL locks instead of fast-pathing"
            );
        } finally {
            _release(peer);
            s2.close();
            s1.close();
        }
    }
}


test "layer2: connections carry a jac:<pid>:<cmd> identity" {
    with TemporaryDirectory() as td {
        (s1, _, _, _) = _mk_store(td);
        try {
            s1.ensure_schema({});
            rows = s1.rows(
                'SELECT application_name FROM pg_stat_activity'
                ' WHERE pid = pg_backend_pid()',
                {}
            );
            app = str(rows[0][0]);
            assert app.startswith('jac:') , (
                f"expected application_name 'jac:<pid>:<cmd>', got {app!r}"
            );
            assert str(os.getpid()) in app , (
                f"identity {app!r} does not name the owning os pid"
            );
        } finally {
            s1.close();
        }
    }
}


test "layer2: blocker owned by a dead process is reaped automatically" {
    with TemporaryDirectory() as td {
        (s1, info, _, rt) = _mk_store(td);
        s1.ensure_schema({});
        # pid 999999999 exceeds pid_max on any linux box: provably dead owner
        peer = _armed_peer(info, 'jac:999999999:start');
        s1.kv_delete(STAMP_KEY);  # force the DDL path on the next boot
        s2 = PgStore(conninfo=info, ensure_cb=rt.ensure);
        try {
            s2.ensure_schema({});
            zombies = s2.rows(
                'SELECT count(*) FROM pg_stat_activity'
                " WHERE datname = current_database()"
                " AND application_name = 'jac:999999999:start'",
                {}
            );
            assert int(zombies[0][0]) == 0 , (
                'the dead-owner backend survived: it was not reaped'
            );
        } finally {
            _release(peer);
            s2.close();
            s1.close();
        }
    }
}


test "layer2: blocker owned by a live process raises a structured conflict" {
    with TemporaryDirectory() as td {
        import from jaclang.runtimelib.store { SessionConflictError }
        (s1, info, _, rt) = _mk_store(td);
        s1.ensure_schema({});
        got: any = None;
        # A cluster restart mid-scenario silently drops the blocking
        # transaction; re-arm and try the whole scenario again.
        for attempt in range(3) {
            peer = _armed_peer(info, f"jac:{os.getpid()}:serve");
            s1.kv_delete(STAMP_KEY);
            s2 = PgStore(conninfo=info, ensure_cb=rt.ensure);
            try {
                s2.ensure_schema({});
            } except SessionConflictError as e {
                got = e;
            } finally {
                _release(peer);
                s2.close();
            }
            if got is not None {
                break;
            }
        }
        s1.close();
        assert got is not None , (
            'a live blocker must surface as SessionConflictError,'
            ' not a raw lock timeout'
        );
        assert str(os.getpid()) in str(got) , (
            f"conflict error {str(got)!r} does not name the blocking pid"
        );
    }
}


test "layer2: takeover_project evicts every other session on the db" {
    with TemporaryDirectory() as td {
        import from jaclang.runtimelib.session { takeover_project }
        (s1, info, target, _) = _mk_store(td);
        s1.ensure_schema({});
        n = 0;
        # Re-arm if a cluster restart evicts the peer before takeover does.
        for attempt in range(3) {
            peer = _armed_peer(info, f"jac:{os.getpid()}:serve");
            n = takeover_project(td, target);
            evicted = False;
            try {
                peer.run('SELECT 1');
            } except Exception {
                evicted = True;
            }
            _release(peer);
            if n >= 1 and evicted {
                break;
            }
        }
        s1.close();
        assert n >= 1 , f"takeover reported {n} evictions, expected >= 1";
        assert evicted , 'the blocking session survived takeover';
    }
}


test "layer3: known sqlstates map to actionable messages" {
    import from jaclang.cli.errmap { humanize_error }
    import from jaclang.runtimelib.store { SessionConflictError }

    full = humanize_error(
        PgWireError({'C': '53300', 'M': 'sorry, too many clients already'})
    );
    assert full is not None , '53300 (too many connections) must be mapped';
    (msg, hint) = full;
    assert 'connection' in msg.lower();
    assert 'JAC_TEST_JOBS' in (hint or '') , (
        'the 53300 hint must name the likely culprit fix (JAC_TEST_JOBS)'
    );

    locked = humanize_error(
        PgWireError({'C': '55P03', 'M': 'canceling statement due to lock timeout'})
    );
    assert locked is not None , '55P03 (lock timeout) must be mapped';

    conflict = humanize_error(
        SessionConflictError(
            database='jac_x_00000000',
            blockers=[{'owner_pid': 4242, 'cmd': 'start', 'started': 'today'}]
        )
    );
    assert conflict is not None;
    joined = conflict[0] + ' ' + (conflict[1] or '');
    assert '--takeover' in joined , (
        'the conflict message must teach the --takeover escape hatch'
    );
    assert '4242' in joined , 'the conflict message must name the blocking pid';

    assert humanize_error(ValueError('nope')) is None , (
        'unknown errors must fall through to the generic path'
    );
}


test "layer4: embedded server provisioned with connection headroom" {
    import from jaclang.runtimelib.pgembed { PG_MAX_CONNECTIONS }
    assert PG_MAX_CONNECTIONS >= 256 , (
        f"max_connections={PG_MAX_CONNECTIONS} cannot absorb a default"
        ' 128-worker test fan-out'
    );
    rt = PgRuntime(data_dir=shared_pg_data_dir(), database='postgres');
    assert f"max_connections={PG_MAX_CONNECTIONS}" in rt._server_opts() , (
        'the provisioned server options must carry the headroom constant'
    );
}
