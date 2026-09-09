"""Fixture for root-bind fail-closed tests: whoami plus a fault injector that
corrupts a registered user's stored root_id with real SQL, simulating a store
reset or migration out from under the users db."""

def whoami -> dict {
    return {"root": jid(root)};
}

def:pub corrupt_root(username: str, new_root_id: str) -> dict {
    import from jaclang.server.shared_store { shared_store }
    store = shared_store();
    if store is None {
        return {"ok": False, "why": "no shared store"};
    }
    rows = store.rows(
        """
        UPDATE identity_users SET doc = doc || CAST(:p AS jsonb)
        WHERE user_id = (
            SELECT lk.user_id FROM identity_lookups lk
            WHERE lk.value_normalized = :v
        ) RETURNING user_id
        """,
        {"p": '{"root_id": "' + new_root_id + '"}', "v": username}
    );
    return {"ok": bool(rows), "updated": len(rows)};
}
