"""The scale db stack: pooled wire connections and read-only unit profiling.

Two mechanisms pinned here. First, `PgStore.close()` parks its wire
connections in a process-wide pool (jaclang.data.pgpool) keyed by conninfo,
so the per-request store churn of the scale serving path stops paying a TCP
connect + SCRAM handshake per request; parked connections come back
sanitized (no open transaction, no LISTEN state). Second, a unit of work
that declares a key runs optimistically at `REPEATABLE READ READ ONLY`
until the process observes it write; the first write raises `ReadOnlyRetry`
(the OCC loop re-runs the request), records the key as a writer, and every
later unit under that key runs at SERIALIZABLE from the start.
"""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { uuid4 }
import from jaclang.server.session { Session, unit_writes_recorded }
import from jaclang.runtime.exceptions { ReadOnlyRetry }
import from jaclang.data.store { PgStore, Store, TxnIsolation }
import from jaclang.data.pgpool { drain_all, pool_stats }


def _mk_session(td: str) -> Session {
    return Session(base_path=td, target_path=str(Path(td) / 'app.jac'));
}


def _store(s: Session) -> Store {
    st = s.store;
    assert st is not None;
    return st;
}


def _sireads(s: Session) -> int {
    r = _store(s).rows(
        "SELECT count(*) FROM pg_locks"
        " WHERE mode = 'SIReadLock' AND pid = pg_backend_pid()",
        {}
    );
    return int(r[0][0]);
}


test "ro units: a keyed unit with no writes runs on the read tier" {
    with TemporaryDirectory() as td {
        s = _mk_session(td);
        try {
            s.unit_enter('walker:test.ro_probe');
            try {
                s.read_barrier();
                assert _store(s).txn_isolation() is TxnIsolation.SNAPSHOT_READ_ONLY , (
                    'a keyed unit never seen writing must open the read tier, '
                    f"got {_store(s).txn_isolation()}"
                );
                s.batch_get([uuid4(), uuid4()]);
                assert _sireads(s) == 0 , (
                    f"read-only unit took {_sireads(s)} SIReadLocks, expected 0"
                );
            } finally {
                s.unit_exit();
            }
            assert not _store(s).in_txn();
        } finally {
            s.close();
        }
    }
}


test "ro units: an unkeyed unit keeps SERIALIZABLE" {
    with TemporaryDirectory() as td {
        s = _mk_session(td);
        try {
            s.unit_enter();
            try {
                s.read_barrier();
                assert _store(s).txn_isolation() is TxnIsolation.SERIALIZABLE;
            } finally {
                s.unit_exit();
            }
        } finally {
            s.close();
        }
    }
}


test "ro units: the first write raises ReadOnlyRetry and records the key" {
    key = 'walker:test.turncoat_writer';
    with TemporaryDirectory() as td {
        s = _mk_session(td);
        try {
            s.unit_enter(key);
            raised = False;
            resurfaced = False;
            try {
                s.read_barrier();
                assert _store(s).txn_isolation() is TxnIsolation.SNAPSHOT_READ_ONLY;
                s.delete(uuid4());
                try {
                    s.read_barrier();
                } except ReadOnlyRetry {
                    raised = True;
                }
            } finally {
                try {
                    s.unit_exit();
                } except ReadOnlyRetry {
                    resurfaced = True;
                }
            }
            assert raised , (
                'a write inside a read-tier unit must raise ReadOnlyRetry so '
                'the OCC loop re-runs the request at SERIALIZABLE'
            );
            assert resurfaced , (
                'a ReadOnlyRetry caught inside the unit must resurface at unit '
                'exit, or the unit would commit the rest of the attempt'
            );
            assert unit_writes_recorded(key) , (
                'the writing unit key must be recorded so later runs skip the '
                'read tier'
            );
            assert not _store(s).in_txn() , (
                'the aborted read snapshot must not stay open'
            );
            s.abort();
            s.unit_enter(key);
            try {
                s.read_barrier();
                assert _store(s).txn_isolation() is TxnIsolation.SERIALIZABLE , (
                    'a recorded writer must run at SERIALIZABLE from the start'
                );
            } finally {
                s.unit_exit();
            }
        } finally {
            s.close();
        }
    }
}


test "pool: closing a store parks its connection for the next store" {
    with TemporaryDirectory() as td {
        drain_all();
        s = _mk_session(td);
        st = _store(s);
        st.rows('SELECT 1', {});
        first = getattr(st, '_conn');
        assert first is not None;
        info = getattr(st, 'conninfo');
        s.close();
        assert sum(pool_stats().values()) >= 1 , (
            'close must park the healthy wire connection, not discard it'
        );
        st2 = PgStore(conninfo=info);
        st2.rows('SELECT 1', {});
        assert getattr(st2, '_conn') is first , (
            'the next store for the same conninfo must reuse the parked '
            'connection instead of dialing'
        );
        st2.close();
        drain_all();
    }
}


test "pool: a parked connection comes back with no open transaction" {
    with TemporaryDirectory() as td {
        drain_all();
        s = _mk_session(td);
        st = _store(s);
        st.begin(TxnIsolation.SERIALIZABLE);
        st.rows('SELECT 1', {});
        first = getattr(st, '_conn');
        info = getattr(st, 'conninfo');
        st.close();
        st2 = PgStore(conninfo=info);
        got = st2.rows("SELECT current_setting('transaction_isolation')", {});
        assert getattr(st2, '_conn') is first;
        assert not st2.in_txn();
        assert str(got[0][0]) in ('read committed', 'default') , (
            f"parked connection kept transaction state: {got[0][0]}"
        );
        st2.close();
        s.close();
        drain_all();
    }
}


test "pool: a parked connection comes back with session settings reset" {
    with TemporaryDirectory() as td {
        drain_all();
        s = _mk_session(td);
        st = _store(s);
        st.rows("SET lock_timeout = '5s'", {});
        st.rows('LISTEN jac_pool_probe', {});
        first = getattr(st, '_conn');
        info = getattr(st, 'conninfo');
        st.close();
        st2 = PgStore(conninfo=info);
        got = st2.rows("SELECT current_setting('lock_timeout')", {});
        assert getattr(st2, '_conn') is first;
        assert str(got[0][0]) == '0' , (
            'a session setting left by the previous borrower leaked through '
            f"the pool: lock_timeout={got[0][0]}"
        );
        listening = st2.rows('SELECT count(*) FROM pg_listening_channels()', {});
        assert int(listening[0][0]) == 0 , (
            'a LISTEN registered by the previous borrower survived parking'
        );
        st2.close();
        s.close();
        drain_all();
    }
}


test "pool: a parked connection keeps its prepared statements" {
    with TemporaryDirectory() as td {
        drain_all();
        s = _mk_session(td);
        st = _store(s);
        st.rows("SELECT :x::int AS park_marker", {'x': 1});
        first = getattr(st, '_conn');
        info = getattr(st, 'conninfo');
        st.close();
        st2 = PgStore(conninfo=info);
        held = st2.rows(
            "SELECT count(*) FROM pg_prepared_statements WHERE statement LIKE :m",
            {'m': '%park_marker%'}
        );
        assert getattr(st2, '_conn') is first;
        assert int(held[0][0]) == 1 , (
            'parking the connection threw away its prepared statements, so the '
            'next borrower parses and plans every statement again'
        );
        st2.close();
        s.close();
        drain_all();
    }
}


test "pool: a parked connection comes back with advisory locks and temp tables gone" {
    with TemporaryDirectory() as td {
        drain_all();
        s = _mk_session(td);
        st = _store(s);
        st.rows('SELECT pg_advisory_lock(424242)', {});
        st.rows('CREATE TEMP TABLE park_probe (k int)', {});
        first = getattr(st, '_conn');
        info = getattr(st, 'conninfo');
        st.close();
        st2 = PgStore(conninfo=info);
        locks = st2.rows(
            "SELECT count(*) FROM pg_locks WHERE locktype = 'advisory' AND pid = pg_backend_pid()",
            {}
        );
        temps = st2.rows(
            "SELECT count(*) FROM pg_class WHERE relname = 'park_probe' AND relpersistence = 't'",
            {}
        );
        assert getattr(st2, '_conn') is first;
        assert int(locks[0][0]) == 0 , 'an advisory lock survived parking';
        assert int(temps[0][0]) == 0 , 'a temp table survived parking';
        st2.close();
        s.close();
        drain_all();
    }
}


test "pool: JAC_DB_POOL=0 disables parking" {
    with TemporaryDirectory() as td {
        drain_all();
        os.environ['JAC_DB_POOL'] = '0';
        try {
            s = _mk_session(td);
            st = _store(s);
            st.rows('SELECT 1', {});
            s.close();
            assert sum(pool_stats().values()) == 0 , (
                'with pooling disabled, close must not park connections'
            );
        } finally {
            os.environ.pop('JAC_DB_POOL', None);
        }
    }
}


test "ro units: marking the whole unit stack bounds the read-tier retry at two passes" {
    outer = 'walker:test.nested_outer';
    inner = 'walker:test.nested_inner';
    with TemporaryDirectory() as td {
        s = _mk_session(td);
        try {
            s.unit_enter(outer);
            s.unit_enter(inner);
            raised = False;
            resurfaced = False;
            try {
                s.read_barrier();
                assert _store(s).txn_isolation() is TxnIsolation.SNAPSHOT_READ_ONLY;
                s.delete(uuid4());
                try {
                    s.read_barrier();
                } except ReadOnlyRetry {
                    raised = True;
                }
            } finally {
                s.unit_exit();
                try {
                    s.unit_exit();
                } except ReadOnlyRetry {
                    resurfaced = True;
                }
            }
            assert raised;
            assert resurfaced , 'the caught retry resurfaces when the outer unit exits';
            assert unit_writes_recorded(inner);
            assert unit_writes_recorded(outer) , (
                'the outer unit must be recorded as a writer too: the re-run '
                'enters it first, and an outer unit still classified read-only '
                'would reopen the read tier and trip a second ReadOnlyRetry, so '
                'marking only the writing unit would not bound the retry at two '
                'passes'
            );
            s.abort();
            s.unit_enter(outer);
            try {
                s.read_barrier();
                assert _store(s).txn_isolation() is TxnIsolation.SERIALIZABLE , (
                    'the second pass must open SERIALIZABLE from the first read'
                );
            } finally {
                s.unit_exit();
            }
        } finally {
            s.close();
        }
    }
}
