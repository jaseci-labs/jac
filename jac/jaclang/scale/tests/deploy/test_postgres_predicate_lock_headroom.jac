"""The provisioned Postgres must be tuned for the isolation level jac uses (#8050).

jac opens SERIALIZABLE transactions for every write. SERIALIZABLE takes one
SIReadLock per row/page read, and the predicate-lock pool is exactly
`max_pred_locks_per_transaction * (max_connections + max_prepared_transactions)`
entries. Stock Postgres ships `max_pred_locks_per_transaction = 64`, so a stock
`max_connections = 100` yields a ~6,400-entry pool.

The fleet in #8050 held 17,406 SIReadLocks across 20 connections (~870 per
connection) before every statement started failing with
`53200 out of shared memory ... CreatePredicateLock`. The embedded runtime
already provisions headroom for that; the Kubernetes provisioner shipped the
stock defaults, which is the configuration the incident ran on.
"""

import from jaclang.scale.deploy.database.kubernetes_postgres {
    KubernetesPostgresProvider
}
import from jaclang.runtimelib.pgembed {
    PG_MAX_CONNECTIONS,
    PG_MAX_PRED_LOCKS_PER_TXN,
    pg_tuning_settings
}

glob OBSERVED_PEAK_SIREAD_LOCKS = 17406,
     OBSERVED_SIREAD_LOCKS_PER_CONN = 870;


def _pg_container -> dict {
    provider = KubernetesPostgresProvider(config={'app_name': 'headroom-test'});
    deployed = provider.deploy({});
    spec = deployed['statefulset']['spec']['template']['spec'];
    return spec['containers'][0];
}


test "provisioning: the tuning budget covers the isolation level jac uses" {
    assert PG_MAX_PRED_LOCKS_PER_TXN >= OBSERVED_SIREAD_LOCKS_PER_CONN , (
        f"max_pred_locks_per_transaction={PG_MAX_PRED_LOCKS_PER_TXN} is below the "
        f"{OBSERVED_SIREAD_LOCKS_PER_CONN} predicate locks a single connection was "
        'measured holding in #8050'
    );
    pool = PG_MAX_PRED_LOCKS_PER_TXN * PG_MAX_CONNECTIONS;
    assert pool >= OBSERVED_PEAK_SIREAD_LOCKS , (
        f"predicate-lock pool {PG_MAX_PRED_LOCKS_PER_TXN} x {PG_MAX_CONNECTIONS} "
        f"= {pool} cannot hold the {OBSERVED_PEAK_SIREAD_LOCKS} SIReadLocks the "
        'fleet in #8050 actually held'
    );
}


test "provisioning: one tuning source of truth feeds every Postgres jac starts" {
    settings = pg_tuning_settings();
    assert settings['max_pred_locks_per_transaction'] == str(PG_MAX_PRED_LOCKS_PER_TXN);
    assert settings['max_connections'] == str(PG_MAX_CONNECTIONS);
    import from jaclang.runtimelib.pgembed { PgRuntime }
    import from jaclang.runtimelib.session { shared_pg_data_dir }
    opts = PgRuntime(data_dir=shared_pg_data_dir(), database='postgres')._server_opts();
    for (key, value) in settings.items() {
        assert f"-c {key}={value}" in opts , (
            f"embedded server dropped the shared tuning setting {key}={value}"
        );
    }
}


test "provisioning: the Kubernetes Postgres carries the predicate-lock headroom" {
    container = _pg_container();
    args = [str(a) for a in (container.get('args') or [])];
    assert args , (
        'the provisioned Postgres runs on stock settings: no server arguments '
        'are passed, so max_pred_locks_per_transaction stays at 64'
    );
    assert args[0] == 'postgres' , (
        "the postgres image entrypoint is docker-entrypoint.sh, so args must "
        f"re-state the 'postgres' command (got {args[0]!r})"
    );
    joined = ' '.join(args);
    for (key, value) in pg_tuning_settings().items() {
        assert f"-c {key}={value}" in joined , (
            f"provisioned Postgres is missing {key}={value}; the Kubernetes "
            'instance must be tuned the same way the embedded one is'
        );
    }
}
