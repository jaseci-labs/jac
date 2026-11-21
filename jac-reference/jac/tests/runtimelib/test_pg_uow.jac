"""Unit-of-work lifecycle for the pg-native Session.

The invariant: a jac process at rest holds no open transaction. Sessions
are shared across request contexts, so closure is refcounted — the last
active unit out commits and closes the store transaction. Read-only
transactions are available as a tier that takes no SIREAD predicate
locks. The embedded server carries an idle-in-transaction backstop so any
process that regresses on the invariant is disconnected (and heals)
instead of pinning SIREAD reclamation for the whole cluster.
"""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.data.pgembed { PgRuntime }
import from jaclang.server.session { Session, shared_pg_data_dir, project_db_name }
import from jaclang.data.store { PgStore, Store, TxnIsolation }
import from jaclang.data.pgwire { PgWireError }


def _mk_session(td: str) -> Session {
    return Session(base_path=td, target_path=str(Path(td) / 'app.jac'));
}


def _as_any(v: any) -> any {
    return v;
}


def _store(s: Session) -> Store {
    st = s.store;
    assert st is not None;
    return st;
}


test "uow: last unit out closes the store transaction" {
    with TemporaryDirectory() as td {
        s = _mk_session(td);
        try {
            s.unit_enter();
            s.unit_enter();  # overlapping request on the shared session
            s.read_barrier();  # opens the serializable txn
            assert _store(s).in_txn() , 'txn must be open inside a unit';
            s.unit_exit();
            assert _store(s).in_txn() , 'txn must survive while a unit is active';
            s.unit_exit();
            assert not _store(s).in_txn() , (
                'last unit out must commit and close the transaction'
            );
            backend_pid = int(_store(s).rows('SELECT pg_backend_pid()', {})[0][0]);
            import from jaclang.data.pgload { connect as pg_connect }
            info = _as_any(s.store).conninfo;
            probe = _as_any(
                pg_connect(
                    info.user,
                    unix_socket_dir=info.unix_socket_dir,
                    port=info.port,
                    database=info.database
                )
            );
            try {
                rows = probe.run(
                    'SELECT xact_start FROM pg_stat_activity WHERE pid = :p',
                    p=backend_pid
                );
                assert rows and rows[0][0] is None , (
                    'backend must show no open transaction at rest'
                );
            } finally {
                probe.close();
            }
        } finally {
            s.close();
        }
    }
}


test "uow: read-only transactions take zero SIREAD predicate locks" {
    with TemporaryDirectory() as td {
        target = str(Path(td) / 'app.jac');
        rt = PgRuntime(
            data_dir=shared_pg_data_dir(),
            database=project_db_name(td, target),
            owner_path=td
        );
        store = PgStore(conninfo=rt.ensure(), ensure_cb=rt.ensure);
        try {
            store.ensure_schema({});
            store.begin(TxnIsolation.SNAPSHOT_READ_ONLY);  # the declared read tier, not the serializable default
            store.rows('SELECT count(*) FROM anchors', {});
            si = store.rows(
                "SELECT count(*) FROM pg_locks"
                " WHERE mode = 'SIReadLock' AND pid = pg_backend_pid()",
                {}
            );
            store.commit();
            assert int(si[0][0]) == 0 , (
                f"read-only txn took {si[0][0]} SIREAD locks, expected 0"
            );
        } finally {
            store.close();
        }
    }
}


test "uow: embedded server carries the idle-in-transaction backstop" {
    import from jaclang.data.pgembed { PG_MAX_CONNECTIONS }
    rt = PgRuntime(data_dir=shared_pg_data_dir(), database='postgres');
    opts = rt._server_opts();
    assert 'idle_in_transaction_session_timeout' in opts , (
        'server must disconnect sessions that idle in a transaction'
    );
    assert 'max_pred_locks_per_transaction' in opts , (
        'server must provision SIREAD headroom above the default'
    );
}


test "uow: idle-in-transaction disconnect heals like a dead connection" {
    import from jaclang.data.store { _conn_dead }
    assert _conn_dead(
        PgWireError(
            {
                'C': '25P03',
                'M': 'terminating connection due to idle-in-transaction timeout'
            }
        )
    ) , '25P03 must count as a healable dead-connection signature';
}


test "uow: predicate-lock exhaustion maps to an actionable message" {
    import from jaclang.cli.errmap { humanize_error }
    m = humanize_error(PgWireError({'C': '53200', 'M': 'out of shared memory'}));
    assert m is not None , '53200 must be mapped';
    joined = m[0] + ' ' + (m[1] or '');
    assert 'predicate' in joined.lower() or 'serializable' in joined.lower();
}
