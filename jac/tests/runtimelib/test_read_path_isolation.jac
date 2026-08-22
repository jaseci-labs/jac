"""Read paths must not take SERIALIZABLE predicate locks (#8050).

SERIALIZABLE takes one SIReadLock per row/page read. A graph app reads many
rows per request, so running every request's reads at SERIALIZABLE overruns
`max_pred_locks_per_transaction * max_connections` and every statement then
fails with `53200 out of shared memory ... CreatePredicateLock` -- context
construction included, which is what took the fleet in #8050 down.

The rule these tests pin: isolation follows *declared* intent. A declared
read scope runs at `REPEATABLE READ READ ONLY` (zero predicate locks); a unit
of work runs at SERIALIZABLE. Intent is never guessed, and a transaction that
starts as a read can never carry a write: it is restarted at SERIALIZABLE
before the write is issued, and the server-side READ ONLY flag is the second,
mechanical guard behind that.
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { UUID, uuid4 }
import from jaclang.runtimelib.session { Session }
import from jaclang.runtimelib.store { TxnIsolation }


def _mk_session(td: str) -> Session {
    return Session(base_path=td, target_path=str(Path(td) / 'app.jac'));
}


def _server_txn_state(s: Session) -> list {
    r = s.store.rows(
        "SELECT current_setting('transaction_isolation'),"
        " current_setting('transaction_read_only')",
        {}
    );
    return [str(r[0][0]), str(r[0][1])];
}


def _sireads(s: Session) -> int {
    r = s.store.rows(
        "SELECT count(*) FROM pg_locks"
        " WHERE mode = 'SIReadLock' AND pid = pg_backend_pid()",
        {}
    );
    return int(r[0][0]);
}


test "isolation: a declared read scope takes zero predicate locks" {
    with TemporaryDirectory() as td {
        s = _mk_session(td);
        try {
            s.read_scope_enter();
            try {
                s.read_barrier();
                assert s.store.txn_isolation() is TxnIsolation.SNAPSHOT_READ_ONLY , (
                    'a declared read scope must not open a SERIALIZABLE '
                    f"transaction (got {s.store.txn_isolation()})"
                );
                state = _server_txn_state(s);
                assert state[0] == 'repeatable read' , (
                    f"server reports isolation '{state[0]}', expected "
                    "'repeatable read' (the tier that takes no SIReadLock)"
                );
                assert state[1] == 'on' , (
                    'the read tier must be READ ONLY at the server so a write '
                    'cannot silently run under-isolated'
                );
                s.batch_get([uuid4(), uuid4(), uuid4()]);
                s.store.rows('SELECT count(*) FROM anchors', {});
                assert _sireads(s) == 0 , (
                    f"read scope took {_sireads(s)} SIReadLocks, expected 0"
                );
            } finally {
                s.read_scope_exit();
            }
            assert not s.store.in_txn() , (
                'closing the last read scope must commit and close the '
                'read snapshot so predicate-lock reclamation is never pinned'
            );
        } finally {
            s.close();
        }
    }
}


test "isolation: a unit of work still runs at SERIALIZABLE" {
    with TemporaryDirectory() as td {
        s = _mk_session(td);
        try {
            s.unit_enter();
            try {
                s.read_barrier();
                assert s.store.txn_isolation() is TxnIsolation.SERIALIZABLE , (
                    'write transactions must keep SERIALIZABLE: SSI is the '
                    'only thing that makes check-then-create converge'
                );
                state = _server_txn_state(s);
                assert state[0] == 'serializable' , (
                    f"server reports isolation '{state[0]}', expected "
                    "'serializable' for a unit of work"
                );
                assert state[1] == 'off' , 'a unit of work must be read-write';
            } finally {
                s.unit_exit();
            }
        } finally {
            s.close();
        }
    }
}


test "isolation: entering a unit promotes an open read snapshot" {
    with TemporaryDirectory() as td {
        s = _mk_session(td);
        try {
            s.read_scope_enter();
            try {
                s.read_barrier();
                assert s.store.txn_isolation() is TxnIsolation.SNAPSHOT_READ_ONLY;
                s.unit_enter();
                try {
                    assert s.store.txn_isolation() is TxnIsolation.SERIALIZABLE , (
                        'a read snapshot must be restarted at SERIALIZABLE when '
                        'a unit of work begins, never carried into the write'
                    );
                    assert _server_txn_state(s)[1] == 'off' , (
                        'the promoted transaction must be read-write'
                    );
                } finally {
                    s.unit_exit();
                }
            } finally {
                s.read_scope_exit();
            }
        } finally {
            s.close();
        }
    }
}


test "isolation: a pending write inside a read scope forces SERIALIZABLE" {
    with TemporaryDirectory() as td {
        s = _mk_session(td);
        try {
            s.read_scope_enter();
            try {
                s.delete(uuid4());
                s.read_barrier();
                assert s.store.txn_isolation() is TxnIsolation.SERIALIZABLE , (
                    'a session with pending mutations must not open the read '
                    'tier: the flush inside read_barrier is a write'
                );
            } finally {
                s.read_scope_exit();
            }
        } finally {
            s.close();
        }
    }
}


test "isolation: scale context construction declares read intent" {
    import from jaclang.jac0core.constant { Constants as Con }
    with TemporaryDirectory() as td {
        s = _mk_session(td);
        try {
            s.read_scope_enter();
            try {
                s.get(UUID(Con.SUPER_ROOT_UUID));
                assert s.store.txn_isolation() is TxnIsolation.SNAPSHOT_READ_ONLY , (
                    'the root probe every request runs at context construction '
                    'must not open a SERIALIZABLE transaction'
                );
                assert _sireads(s) == 0 , (
                    'context construction must take no predicate locks: it runs '
                    'on every request, health probes included'
                );
            } finally {
                s.read_scope_exit();
            }
        } finally {
            s.close();
        }
    }
}


test "isolation: the read tier refuses writes at the server" {
    with TemporaryDirectory() as td {
        s = _mk_session(td);
        try {
            s.store.begin(TxnIsolation.SNAPSHOT_READ_ONLY);
            refused = False;
            try {
                s.store.rows(
                    "INSERT INTO kv_state (key, value) VALUES ('probe_8050', 'x')", {}
                );
            } except Exception {
                refused = True;
            }
            s.store.rollback();
            assert refused , (
                'the read tier must be READ ONLY at the server, so any write '
                'path that escapes the promotion logic fails loudly instead of '
                'committing under-isolated'
            );
        } finally {
            s.close();
        }
    }
}
