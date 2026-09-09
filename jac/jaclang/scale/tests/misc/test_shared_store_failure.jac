"""The shared store reports why it is unavailable (#8166).

`shared_store()` used to collapse every failure to `None` and cache that
`None` under the current key, so (a) the cause was gone by the time any
caller saw the result, and (b) one bad moment at first touch was permanent
for the life of the process. The identity manager, which is the loudest
consumer, then blamed a missing database url -- even when a url had
resolved and the real failure was a connect error or a lost schema race.

Pinned here: the failure taxonomy `shared_store()` records, the identity
manager rendering it verbatim, and failures staying retryable.
"""

import os;
import tempfile;
import unittest.mock;
import jaclang.server.shared_store as pg_mod;
import from jaclang.scale.config.config_loader { get_scale_config, reset_scale_config }
import from jaclang.server.identity.user_manager { UserManager }
import from pathlib { Path }

glob _DEAD_URL = 'postgresql://jac:jac@127.0.0.1:1/jac';


def _arm(url: str) {
    # A fresh holder every time: these tests are about what the holder
    # remembers, so a leftover entry would answer for the code under test.
    pg_mod._holder.clear();
    if url {
        os.environ['JAC_DB_URL'] = url;
    } else {
        os.environ.pop('JAC_DB_URL', None);
    }
}


def _disarm {
    os.environ.pop('JAC_DB_URL', None);
    pg_mod._holder.clear();
}


test "a url that resolves but cannot be reached is reported as such" {
    _arm(_DEAD_URL);
    try {
        assert pg_mod.shared_store() is None , (
            'a database on a closed port must not yield a store'
        );
        reason = pg_mod.shared_store_failure();
        assert reason is not None , (
            'the store failed and told nobody why; the cause must survive'
        );
        assert '127.0.0.1:1' in reason , (
            f"the failure {reason!a} does not name the database it could not" ' reach'
        );
        assert 'JAC_DB_URL' in reason , (
            f"the failure {reason!a} does not name where the url came from"
        );
        assert 'no [scale.database] url' not in reason , (
            f"the failure {reason!a} claims no url resolved, but JAC_DB_URL"
            ' was set and parsed'
        );
    } finally {
        _disarm();
    }
}


obj _SchemaFailingStore {
    has conninfo: any = None;

    def rows(sql: str, params: dict) -> list {
        return [];
    }

    def ensure_schema_once(promotions: dict) {
        raise RuntimeError(
            'duplicate key value violates unique constraint'
            ' "pg_type_typname_nsp_index"'
        );
    }

    def close {}
}


def _schema_failing(**kwargs: any) -> any {
    return _SchemaFailingStore(conninfo=kwargs.get('conninfo'));
}


test "a store that connects but cannot set up the schema says so" {
    # The #8166 shape exactly: the database is there, the schema race is what
    # went wrong, and the operator has to be told which of the two it was.
    _arm(_DEAD_URL);
    try {
        with unittest.mock.patch('jaclang.data.store.PgStore', _schema_failing) {
            assert pg_mod.shared_store() is None;
            reason: str = str(pg_mod.shared_store_failure() or '');
            assert 'schema' in reason , (
                f"a schema failure is reported as {reason!a}, which does not"
                ' distinguish it from an unreachable database'
            );
            assert 'duplicate key' in reason , (
                f"the underlying error is missing from {reason!a}"
            );
            assert '127.0.0.1:1' in reason , (
                f"{reason!a} does not name the database that was reached"
            );
        }
    } finally {
        _disarm();
    }
}


test "the identity manager renders the real cause" {
    _arm(_DEAD_URL);
    try {
        with testraises(RuntimeError) as exc {
            UserManager(base_path='.');
        }
        msg = str(exc.value);
        assert 'no [scale.database] url' not in msg , (
            'the identity error still claims no database url resolved while'
            f" JAC_DB_URL was set: {msg}"
        );
        assert '127.0.0.1:1' in msg , (
            f"the identity error does not carry the underlying cause: {msg}"
        );
        # The refusal itself is still the contract from #8000 (Part 4).
        assert 'Postgres' in msg;
        assert 'credential store' in msg;
    } finally {
        _disarm();
    }
}


test "the no-url claim survives for the case that really has no url" {
    _arm('');
    try {
        with unittest.mock.patch(
            'jaclang.server.shared_store.shared_store', return_value=None
        ) {
            with testraises(RuntimeError) as exc {
                UserManager(base_path='.');
            }
            msg = str(exc.value);
            assert 'JAC_DB_URL' in msg , (
                'with nothing recorded the identity error must still name the'
                f" knobs that fix it: {msg}"
            );
        }
    } finally {
        _disarm();
    }
}


test "a failed store is retried, not pinned for the process lifetime" {
    _arm(_DEAD_URL);
    try {
        with unittest.mock.patch(
            'jaclang.data.store.PgStore', side_effect=RuntimeError('transient')
        ) as fake {
            assert pg_mod.shared_store() is None;
            assert pg_mod.shared_store() is None;
            assert fake.call_count == 2 , (
                f"the second call made {fake.call_count - 1} attempt(s): a"
                ' failed store must not pin None for the process lifetime,'
                ' or one bad moment at boot outlives the outage that caused'
                ' it'
            );
        }
    } finally {
        _disarm();
    }
}


test "a configured [scale.database] url is a real source, not just a message" {
    _arm('');
    try {
        stub = unittest.mock.MagicMock();
        stub.get_database_config.return_value = {
            'url': 'postgresql://u@example:5432/d'
        };
        with unittest.mock.patch(
            'jaclang.scale.config.config_loader.get_scale_config', return_value=stub
        ) {
            assert pg_mod.scale_db_url() == 'postgresql://u@example:5432/d' , (
                'the identity error offers [scale.database] url as the fix,'
                ' so scale_db_url must actually read it'
            );
        }
    } finally {
        _disarm();
    }
}


test "in a cluster with no url, the store refuses to embed a database" {
    # #8766: with no url resolved, shared_store() provisioned a server inside
    # the pod. One per replica, on the pod filesystem, gone on restart, at
    # debug level. In a cluster that is data loss, so it has to fail instead.
    # Off-cluster the embedded server is the point, hence the env scoping.
    _arm('');
    prior = os.environ.get('KUBERNETES_SERVICE_HOST');
    os.environ['KUBERNETES_SERVICE_HOST'] = '10.96.0.1';
    try {
        assert pg_mod._in_cluster();
        assert pg_mod.shared_store() is None;
        assert pg_mod.shared_store_failure() == pg_mod.NO_DATABASE_IN_CLUSTER;
    } finally {
        if prior is None {
            os.environ.pop('KUBERNETES_SERVICE_HOST', None);
        } else {
            os.environ['KUBERNETES_SERVICE_HOST'] = prior;
        }
        _disarm();
    }
    assert not pg_mod._in_cluster() , (
        'off-cluster this must stay false, or every laptop run loses its '
        'embedded database'
    );
}
