"""AuthTokenStore must fail closed when its database errors.

The consume decision is single-winner only because the database DELETE is
atomic; a database error that silently falls back to the per-worker in-memory
dict makes a token consumable once per replica. These tests drive the real
store object with a hand-rolled broken-database boundary stub at the API edge.
"""

import from jaclang.server.identity.auth_tokens {
    AuthTokenStore,
    reset_auth_token_store
}

obj BrokenDb {
    def rows(sql: str, params: dict) -> list {
        raise RuntimeError("db down");
    }

    def kv_get(key: str) -> any {
        raise RuntimeError("db down");
    }
}

def _store_with_memory_token -> tuple {
    reset_auth_token_store();
    store = AuthTokenStore();
    store._db = None;
    tok = store.create_token(user_id="alice", purpose="app:t", ttl_seconds=60);
    return (store, tok);
}

test "a db error at consume time loses instead of consulting worker memory" {
    (store, tok) = _store_with_memory_token();
    store._db = BrokenDb();
    got = store.consume_token(tok, "app:t");
    assert got is None , (
        "consume must fail closed on a db error, not redeem from per-worker "
        f"memory: {got!r}"
    );
}

test "a db error at peek time reads as not found" {
    (store, tok) = _store_with_memory_token();
    store._db = BrokenDb();
    assert store.peek_token(tok, "app:t") is None;
}

test "a db error at mint time refuses loudly" {
    reset_auth_token_store();
    store = AuthTokenStore();
    store._db = BrokenDb();
    raised = False;
    try {
        store.create_token(user_id="alice", purpose="app:t", ttl_seconds=60);
    } except RuntimeError {
        raised = True;
    }
    assert raised , "minting a token only one worker could redeem must raise";
}

test "in-memory mode still works when no database is configured at all" {
    (store, tok) = _store_with_memory_token();
    got = store.consume_token(tok, "app:t");
    assert got is not None and got.get("user_id") == "alice";
    assert store.consume_token(tok, "app:t") is None , "second redeem won";
}
