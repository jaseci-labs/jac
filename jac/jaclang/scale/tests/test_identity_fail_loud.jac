"""Guards #8000 (Part 4): identity storage is Postgres-only. When no store
resolves, the user manager must fail loudly instead of silently degrading to
a second credential store with divergent semantics (the old sqlite fallback).
"""

import unittest.mock;
import from jaclang.scale.identity.user_manager { JacScaleUserManager }


test "user manager refuses to start without a reachable database" {
    with unittest.mock.patch(
        "jaclang.scale.persistence.pg.shared_store", return_value=None
    ) {
        with testraises(RuntimeError) as exc {
            JacScaleUserManager(base_path=".");
        }
        assert "Postgres" in str(exc.value);
        assert "credential store" in str(exc.value);
    }
}


test "sqlite identity fallback is gone" {
    import jaclang.scale.identity.identity_storage as storage_mod;
    assert not hasattr(storage_mod, "SqliteIdentityStorage");
}
