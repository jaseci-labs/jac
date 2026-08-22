"""Cross-process first-boot safety for the shared schema (#8166).

`_schema_gate` plus `_schema_ready` (PR #8132) exclude threads inside one
process. Replicas of a scaled app are separate processes, so they never see
each other's gate: against a fresh database they all read a null schema
stamp and all run the schema DDL. `CREATE ... IF NOT EXISTS` is not
concurrency-atomic -- two sessions pass the existence probe and then race
the catalog's unique indexes -- so the losers die with SQLSTATE 23505 on
`pg_type_typname_nsp_index` / `pg_class_relname_nsp_index`.

This suite pins the two halves of the answer:

  election -- one creator per database is elected through Postgres itself
              (a session-level advisory lock), so the DDL is serialized
              where every replica can see it, not just every thread;
  backstop -- a creator that is not part of the election (anything that is
              not this build of jac) can still win a catalog race, so
              23505 / 42P07 / 42710 are treated as "a concurrent winner
              exists" and re-checked rather than raised.

Each racer is its own `PgStore` with its own connection, which is what a
replica is from the server's point of view, and each calls `ensure_schema`
directly so the process-local gate is out of the picture.
"""

import threading;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.runtimelib.pgembed { PgRuntime }
import from jaclang.runtimelib.session { shared_pg_data_dir, project_db_name }
import from jaclang.runtimelib.store { PgStore }
import from jaclang.runtimelib.pgwire { PgWireError }

glob _RACERS = 8,
     _ROUNDS = 3,
     _CONCURRENT_CREATE_STATES = ['23505', '42P07', '42710'];


def _fresh_db(td: str) -> tuple {
    # One database per temp dir: every round races against a virgin schema,
    # which is the only state in which the bug can fire.
    target = str(Path(td) / 'app.jac');
    rt = PgRuntime(
        data_dir=shared_pg_data_dir(),
        database=project_db_name(td, target),
        owner_path=td
    );
    return (rt, rt.ensure());
}


def _sqlstate_of(e: Exception) -> str {
    for arg in getattr(e, 'args', ()) {
        if isinstance(arg, dict) and 'C' in arg {
            return str(arg.get('C') or '');
        }
    }
    return '';
}


def _advisory_locks(store: any, extra: str = '') -> int {
    # pg_locks is cluster-wide and this suite shares its cluster with every
    # other pg suite, so the count has to be scoped to this database or a
    # neighbour's election answers for ours.
    rows = store.rows(
        "SELECT count(*) FROM pg_locks WHERE locktype = 'advisory'"
        ' AND database = ('
        'SELECT oid FROM pg_database WHERE datname = current_database())'
            + extra,
        {}
    );
    return int(rows[0][0]);
}


def _race_round(td: str, racers: int) -> list[Exception] {
    (rt, info) = _fresh_db(td);
    stores = [PgStore(conninfo=info, ensure_cb=rt.ensure) for _ in range(racers)];
    # Connect and cache server_version before the barrier: otherwise the
    # SCRAM handshake staggers the racers and the DDL never overlaps.
    for s in stores {
        s.server_version();
    }
    failures: list[Exception] = [];
    sink = threading.Lock();
    gate = threading.Barrier(racers);

    def boot(store: any) {
        try {
            gate.`wait(60);
            store.ensure_schema({});
        } except Exception as e {
            with sink {
                failures.append(e);
            }
        }
    }
    threads = [
        threading.Thread(target=boot, args=(s, ), name='jac-schema-racer')
        for s in stores
    ];
    for t in threads {
        t.start();
    }
    for t in threads {
        t.join(180);
    }
    stamped = 0;
    for s in stores {
        try {
            if s._schema_stamp() {
                stamped += 1;
            }
        } except Exception { }
        try {
            s.close();
        } except Exception { }
    }
    if not failures {
        assert stamped == racers , (
            f"all {racers} racers returned without error but only {stamped}"
            ' can see a schema stamp'
        );
    }
    return failures;
}


test "replicas booting together against a fresh database all survive" {
    losers: list[Exception] = [];
    for _ in range(_ROUNDS) {
        with TemporaryDirectory() as td {
            losers += _race_round(td, _RACERS);
        }
    }
    states = sorted(set(_sqlstate_of(e) for e in losers));
    first = str(losers[0]) if losers else '';
    assert losers == [] , (
        f"{len(losers)} of {_RACERS * _ROUNDS} concurrent first boots died"
        f" against a fresh database (sqlstates {states}): schema creation is"
        f" not elected across processes. First: {first}"
    );
}


# --- election: the mutual exclusion lives in postgres, not in this process --
obj _LockProbeStore(PgStore) {
    has advisory_locks_held: int = -1;

    def _apply_schema_ddl {
        self.advisory_locks_held = _advisory_locks(self, ' AND pid = pg_backend_pid()');
        super._apply_schema_ddl();
    }
}


test "schema DDL runs under a lock every replica can see" {
    with TemporaryDirectory() as td {
        (rt, info) = _fresh_db(td);
        store = _LockProbeStore(conninfo=info, ensure_cb=rt.ensure);
        try {
            assert _advisory_locks(store) == 0 , (
                'a fresh database must start with no advisory locks held'
            );
            store.ensure_schema({});
            assert store.advisory_locks_held >= 1 , (
                'schema DDL ran holding no advisory lock (pg_locks saw'
                f" {store.advisory_locks_held}): a process-local lock cannot"
                ' exclude another replica'
            );
            # A lock left held would pin every later boot behind this session.
            assert _advisory_locks(store) == 0 , (
                'the schema election survived ensure_schema: it must be'
                ' released in a finally'
            );
        } finally {
            store.close();
        }
    }
}


# --- backstop: a winner outside the election is tolerated, not raised ------
obj _CatalogRaceStore(PgStore) {
    has fault_state: str = '23505',
        faults_left: int = 1,
        ddl_attempts: int = 0;

    def _apply_schema_ddl {
        self.ddl_attempts += 1;
        if self.faults_left > 0 {
            self.faults_left -= 1;
            raise PgWireError(
                {
                    'S': 'ERROR',
                    'C': self.fault_state,
                    'M': 'duplicate key value violates unique constraint'
                    ' "pg_type_typname_nsp_index"',
                    'D': 'Key (typname, typnamespace)=(anchors, 2200)'
                    ' already exists.'
                }
            );
        }
        super._apply_schema_ddl();
    }
}


test "a concurrent catalog winner is absorbed, not surfaced" {
    for state in _CONCURRENT_CREATE_STATES {
        with TemporaryDirectory() as td {
            (rt, info) = _fresh_db(td);
            store = _CatalogRaceStore(
                conninfo=info, ensure_cb=rt.ensure, fault_state=state
            );
            surfaced: (Exception | None) = None;
            try {
                store.ensure_schema({});
            } except Exception as e {
                surfaced = e;
            }
            try {
                assert surfaced is None , (
                    f"a peer winning the catalog race ({state}) surfaced as"
                    f" {type(surfaced).__name__}: {str(surfaced)}; jac cannot"
                    ' hold the election against creators outside it, so this'
                    ' state has to be re-checked and replayed'
                );
                assert store.ddl_attempts == 2 , (
                    'expected one faulted attempt plus one replay, got'
                    f" {store.ddl_attempts}"
                );
                assert store._schema_stamp() , (
                    'the schema was not stamped after absorbing the'
                    f" concurrent winner ({state})"
                );
                assert int(store.rows('SELECT count(*) FROM anchors', {})[0][0]) == 0 , (
                    'the replayed DDL did not leave a usable schema'
                );
            } finally {
                store.close();
            }
        }
    }
}


test "an unrelated sqlstate is still raised" {
    with TemporaryDirectory() as td {
        (rt, info) = _fresh_db(td);
        store = _CatalogRaceStore(
            conninfo=info, ensure_cb=rt.ensure, fault_state='42501'
        );
        raised: (Exception | None) = None;
        try {
            store.ensure_schema({});
        } except PgWireError as e {
            raised = e;
        } finally {
            store.close();
        }
        assert raised is not None , (
            'a permission error during schema DDL must not be mistaken for a'
            ' concurrent creator'
        );
    }
}
