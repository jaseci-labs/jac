"""Guards #8000 (Part 4): identity storage is Postgres-only. When no store
resolves, the user manager must fail loudly instead of silently degrading to
a second credential store with divergent semantics (the old sqlite fallback).

Also guards the way a server could reach a request while its identity is
wrong: a signing secret that cannot be kept, or a system principal that was
never provisioned (the one scheduled jobs and webhooks run as).
"""

import os;
import unittest.mock;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.server.identity.user_manager { SYSTEM_USER, UserManager, UserRole }


"""Apply `values` over the environment, returning what was there before."""
def _set_env(values: dict[str, str | None]) -> dict[str, str | None] {
    previous: dict[str, str | None] = {};
    for (key, value) in values.items() {
        previous[key] = os.environ.get(key);
        if value is None {
            os.environ.pop(key, None);
        } else {
            os.environ[key] = value;
        }
    }
    return previous;
}


test "user manager refuses to start without a reachable database" {
    with unittest.mock.patch(
        "jaclang.server.shared_store.shared_store", return_value=None
    ) {
        with testraises(RuntimeError) as exc {
            UserManager(base_path=".");
        }
        assert "Postgres" in str(exc.value);
        assert "credential store" in str(exc.value);
    }
}


test "sqlite identity fallback is gone" {
    import jaclang.server.identity.identity_storage as storage_mod;
    assert not hasattr(storage_mod, "SqliteIdentityStorage");
}


test "a signing secret that cannot be kept fails the boot, not a request" {
    import from jaclang.server.server { JacAPIServer }
    with TemporaryDirectory() as tmpdir {
        # A regular file where the .jac data directory has to go.
        wall = os.path.join(tmpdir, "wall");
        Path(wall).write_text("", encoding="utf-8");
        previous = _set_env(
            {
                "JAC_DATA_PATH": wall,
                "KUBERNETES_SERVICE_HOST": None,
                "JAC_SERVE_AUTH_SECRET": None
            }
        );
        try {
            with testraises(RuntimeError) as exc {
                JacAPIServer(module_name="app", port=0, base_path=tmpdir);
            }
            message = str(exc.value);
            assert "[serve.auth] secret" in message;
            assert "keep to" in message;
        } finally {
            _set_env(previous);
        }
    }
}


"""Remove every trace of the system principal from the identity tables."""
def _wipe_system_user(srv: any) {
    store = srv.user_manager._identity_storage.store;
    store.rows(
        "DELETE FROM identity_users WHERE user_id IN "
        "(SELECT user_id FROM identity_lookups WHERE value_normalized = :v)",
        {"v": SYSTEM_USER}
    );
    store.rows(
        "DELETE FROM identity_lookups WHERE value_normalized = :v", {"v": SYSTEM_USER}
    );
}


"""A lookup row for the system identity whose user document is gone, as a
partially migrated identity table leaves it: the identity reads as absent, yet
creating it collides."""
def _orphan_system_lookup(srv: any) {
    srv.user_manager._identity_storage.store.rows(
        "INSERT INTO identity_lookups (value_normalized, user_id) VALUES (:v, :u)",
        {"v": SYSTEM_USER, "u": "orphaned-system-user"}
    );
}


"""Make every write to a user document a silent no-op, so a role cannot be
stored although the user reads back: the UPDATE matches no row to return."""
def _freeze_user_updates(srv: any) {
    store = srv.user_manager._identity_storage.store;
    store.rows(
        "CREATE OR REPLACE FUNCTION freeze_user_updates() RETURNS trigger AS "
        "'BEGIN RETURN NULL; END' LANGUAGE plpgsql",
        {}
    );
    store.rows(
        "CREATE TRIGGER freeze_user_updates BEFORE UPDATE ON identity_users "
        "FOR EACH ROW EXECUTE FUNCTION freeze_user_updates()",
        {}
    );
}


def _thaw_user_updates(srv: any) {
    srv.user_manager._identity_storage.store.rows(
        "DROP TRIGGER IF EXISTS freeze_user_updates ON identity_users", {}
    );
}


test "a boot refuses to continue without a verified system principal" {
    import from jaclang.server.server { JacAPIServer }
    with TemporaryDirectory() as tmpdir {
        try {
            srv = JacAPIServer(module_name="app", port=0, base_path=tmpdir);
        } except Exception as e {
            print(f"[skip] embedded postgres unavailable: {e}");
            return;
        }
        _wipe_system_user(srv);
        # (label, wipe first, prepare, boot must fail)
        cases = [
            ("first boot provisions it", True, None, False),
            ("a restart finds it already provisioned", False, None, False),
            (
                "an identity that is taken but unreadable",
                True,
                _orphan_system_lookup,
                True
            ),
            ("a role that cannot be applied", True, _freeze_user_updates, True)
        ];
        try {
            for (label, wipe, prepare, must_fail) in cases {
                if wipe {
                    _wipe_system_user(srv);
                }
                if prepare is not None {
                    prepare(srv);
                }
                try {
                    if must_fail {
                        with testraises(RuntimeError) as exc {
                            srv._ensure_internal_users();
                        }
                        assert SYSTEM_USER in str(exc.value) , label;
                    } else {
                        srv._ensure_internal_users();
                        found = srv.user_manager.find_user_by_identity(SYSTEM_USER);
                        assert found is not None , label;
                        assert (
                            srv.user_manager.get_user_role(str(found["user_id"]))
                            == UserRole.SYSTEM.value
                        ) , label;
                    }
                } finally {
                    _thaw_user_updates(srv);
                }
            }
        } finally {
            _thaw_user_updates(srv);
            _wipe_system_user(srv);
            srv._ensure_internal_users();
        }
    }
}
