"""Concurrency and upgrade guarantees of the Postgres identity store (#9103).

The ownership rules themselves are covered in-process by
tests/runtimelib/test_serve_client.jac; these tests hold a second connection
open to prove what only shows under a concurrent transaction.
"""

import json;
import shutil;
import threading;
import time;
import uuid;
import from tempfile { mkdtemp }
import from jaclang.data.pgembed { PgRuntime }
import from jaclang.data.store { PgStore }
import from jaclang.server.identity.identity_storage { PgIdentityStorage }
import from jaclang.server.identity.user_manager { UserManager }


def _manager -> tuple[str, UserManager] {
    test_dir = mkdtemp();
    return (test_dir, UserManager(base_path=test_dir));
}


def _email_identity(value: str) -> dict[str, any] {
    return {
        'type': 'email',
        'value_raw': value,
        'value_normalized': value.lower().strip(),
        'verified': False,
        'is_recovery': False
    };
}


def _types_holding(users: UserManager, user_id: str, value: str) -> list[str] {
    user = users.get_user(user_id) or {};
    return [
        str(i.get('type'))
        for i in user.get('identities', [])
        if i.get('value_normalized') == value
    ];
}


def _wait_until_blocked(conn: any, table: str) {
    deadline = time.monotonic() + 10;
    while not conn.run(
        """
        SELECT 1 FROM pg_stat_activity
        WHERE wait_event_type = 'Lock' AND pid <> pg_backend_pid() AND query LIKE :q
        """,
        q=f"%{table}%"
    ) {
        assert time.monotonic() < deadline , f"nothing waited for the lock on {table}";
        time.sleep(0.05);
    }
}


test "a rename keeps an identity that lands while the rename waits for the row" {
    (test_dir, users) = _manager();
    storage = users._identity_storage;
    conn = storage.store._side();
    committed = False;
    try {
        tag = uuid.uuid4().hex[:8];
        addr = f"race_{tag}@example.com";
        user_id = str(users.create_user(addr, 'pw12345')['user_id']);
        outcome: dict[str, any] = {};

        def _rename {
            outcome['renamed'] = users.rename_username(user_id, f"raced_{tag}");
        }
        conn.run('BEGIN');
        conn.run(
            'SELECT doc FROM identity_users WHERE user_id = :u FOR NO KEY UPDATE',
            u=user_id
        );
        renamer = threading.Thread(target=_rename, daemon=True);
        renamer.start();
        _wait_until_blocked(conn, 'identity_users');
        conn.run(
            """
            UPDATE identity_users
            SET doc = jsonb_set(
                doc, '{identities}',
                doc->'identities' || jsonb_build_array(CAST(:i AS jsonb)), true
            )
            WHERE user_id = :u
            """,
            u=user_id,
            i=json.dumps(_email_identity(addr))
        );
        conn.run('COMMIT');
        committed = True;
        renamer.join(30);
        assert not renamer.is_alive() , 'the rename did not finish after the row was released';
        renamed = outcome.get('renamed') or {};
        assert 'error' not in renamed , renamed;
        user = users.get_user(user_id) or {};
        assert [str(i.get('type')) for i in user.get('identities', [])]
            == ['username', 'email'];
        assert _types_holding(users, user_id, addr) == ['email'];
        assert str((users.find_user_by_identity(addr) or {}).get('user_id')) == user_id;
        assert users.authenticate(addr, 'pw12345') is not None;
        assert users.authenticate(f"raced_{tag}", 'pw12345') is not None;
    } finally {
        if not committed {
            conn.run('ROLLBACK');
        }
        shutil.rmtree(test_dir, ignore_errors=True);
    }
}


test "an account deleted while a claim is in flight leaves nothing behind" {
    (test_dir, users) = _manager();
    storage = users._identity_storage;
    conn = storage.store._side();
    committed = False;
    try {
        tag = uuid.uuid4().hex[:8];
        addr = f"gone_{tag}@example.com";
        user_id = str(users.create_user(f"gone_{tag}", 'pw12345')['user_id']);
        outcome: dict[str, any] = {};

        def _attach {
            outcome['added'] = users.add_identity(user_id, _email_identity(addr));
        }
        conn.run('BEGIN');
        conn.run('DELETE FROM identity_users WHERE user_id = :u', u=user_id);
        attacher = threading.Thread(target=_attach, daemon=True);
        attacher.start();
        _wait_until_blocked(conn, 'identity_lookups');
        conn.run('COMMIT');
        committed = True;
        attacher.join(30);
        assert not attacher.is_alive() , 'the claim did not finish after the delete committed';
        assert outcome.get('added') is False , outcome;
        assert not storage.identity_taken(addr);
        assert users.find_user_by_identity(addr) is None;
        other = users.create_user(addr, 'pw12345');
        assert 'error' not in other , other;
        assert users.authenticate(addr, 'pw12345') is not None;
    } finally {
        if not committed {
            conn.run('ROLLBACK');
        }
        shutil.rmtree(test_dir, ignore_errors=True);
    }
}


test "an existing database gains the account foreign key without waiting for in-flight writes" {
    store = None;
    try {
        rt = PgRuntime(data_dir=mkdtemp(prefix='jacfk_') + '/data');
        store = PgStore(conninfo=rt.ensure());
    } except Exception as e {
        print(f"[skip] embedded postgres unavailable: {e}");
        return;
    }
    store.rows(
        'CREATE TABLE identity_users (user_id text PRIMARY KEY, doc jsonb NOT NULL)', {}
    );
    store.rows(
        'CREATE TABLE identity_lookups '
        '(value_normalized text PRIMARY KEY, user_id text NOT NULL)',
        {}
    );
    store.rows(
        'CREATE TABLE sso_lookups (provider text NOT NULL, external_id text NOT NULL, '
        'user_id text NOT NULL, PRIMARY KEY (provider, external_id))',
        {}
    );
    store.rows(
        "INSERT INTO identity_users (user_id, doc) VALUES ('kept', CAST(:d AS jsonb))",
        {'d': json.dumps({'user_id': 'kept', 'identities': []})}
    );
    store.rows(
        "INSERT INTO identity_lookups (value_normalized, user_id) "
        "VALUES ('kept@example.com', 'kept'), ('ghost@example.com', 'ghost')",
        {}
    );
    store.rows(
        "INSERT INTO sso_lookups (provider, external_id, user_id) "
        "VALUES ('github', 'kept-ext', 'kept'), ('github', 'ghost-ext', 'ghost')",
        {}
    );
    storage = PgIdentityStorage(store=store);
    constraints = store.rows(
        "SELECT conname FROM pg_constraint WHERE conname IN "
        "('identity_lookups_user_id_fkey', 'sso_lookups_user_id_fkey')",
        {}
    );
    assert len(constraints) == 2 , constraints;
    assert storage.identity_taken('kept@example.com');
    assert not storage.identity_taken('ghost@example.com');
    assert store.rows("SELECT 1 FROM sso_lookups WHERE user_id = 'kept'", {});
    assert not store.rows("SELECT 1 FROM sso_lookups WHERE user_id = 'ghost'", {});
    assert storage._claim_lookup('ghost@example.com', 'kept');
    assert not storage._claim_lookup('later@example.com', 'ghost');

    conn = store._side();
    outcome: dict[str, any] = {};

    def _boot {
        PgIdentityStorage(store=store);
        outcome['booted'] = True;
    }
    conn.run('BEGIN');
    try {
        conn.run(
            "INSERT INTO identity_lookups (value_normalized, user_id) "
            "VALUES ('busy@example.com', 'kept')"
        );
        conn.run(
            "INSERT INTO sso_lookups (provider, external_id, user_id) "
            "VALUES ('github', 'busy-ext', 'kept')"
        );
        booter = threading.Thread(target=_boot, daemon=True);
        booter.start();
        booter.join(10);
        assert not booter.is_alive() , 'the boot waited for the open transaction';
        assert outcome.get('booted') is True , outcome;
    } finally {
        conn.run('ROLLBACK');
    }
    assert storage.identity_taken('ghost@example.com');
}
