"""Guards #8000 (Part 4): identity storage is Postgres-only. When no store
resolves, the user manager must fail loudly instead of silently degrading to
a second credential store with divergent semantics (the old sqlite fallback).

Also guards the way a server could reach a request while its identity is
wrong: a signing secret that cannot be kept.
"""

import os;
import unittest.mock;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.server.identity.user_manager { UserManager }


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
