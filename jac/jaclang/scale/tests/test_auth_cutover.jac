"""Guards #8000 follow-up 1: the scrypt cutover must fail loudly, not silently.

Pre-0.36 credentials are bcrypt-format; verify_password can never accept them.
The failure must produce a distinguishable server-side WARNING (never a client
oracle), the cost knob must not be a memory-DoS knob (effective scrypt n is
capped and hashlib.scrypt gets an explicit maxmem), and operators get a
bulk/per-user flow that flags pre-scrypt accounts for password reset.
"""

import logging;
import from unittest.mock { patch }
import from logging.handlers { MemoryHandler }
import from jaclang.runtimelib.serving.authcrypt {
    SCRYPT_MAX_N,
    SCRYPT_MAXMEM,
    hash_password,
    is_prescrypt_hash,
    verify_password
}

# A real bcrypt vector: bcrypt.hashpw(b"correcthorse", gensalt(12)).
glob BCRYPT_VECTOR = "$2b$12$R9h/cIPz0gi.URNNX3kh2OPST9/PgBkqquzi.Ss7KIUgO2t0jWMUW";


def _capture_warnings(fn: any) -> list[str] {
    capture = MemoryHandler(1000);
    logger = logging.getLogger("jaclang.runtimelib.serving.authcrypt");
    logger.addHandler(capture);
    try {
        fn();
        return [
            r.getMessage()
            for r in capture.buffer
            if r.levelno >= logging.WARNING
        ];
    } finally {
        logger.removeHandler(capture);
    }
}


test "bcrypt-format hash fails with one distinguishable warning" {
    import jaclang.runtimelib.serving.authcrypt as ac;
    ac._legacy_warned.clear();
    seen: list[str] = [];

    def attempt {
        assert verify_password("correcthorse", BCRYPT_VECTOR) is False;
        assert verify_password("wrongpassword", BCRYPT_VECTOR) is False;
    }
    seen = _capture_warnings(attempt);
    assert len(seen) == 1 , f"expected exactly one rate-limited warning, got {seen}";
    assert "scrypt migration" in seen[0];
    assert "reset" in seen[0];
}


test "prefix detection covers all bcrypt variants and nothing else" {
    for prefix in ["$2a$", "$2b$", "$2y$"] {
        assert is_prescrypt_hash(prefix + "12$abcdefghijk") is True;
    }
    assert is_prescrypt_hash(hash_password("x")) is False;
    assert is_prescrypt_hash("") is False;
    assert is_prescrypt_hash("plaintext") is False;
}


test "effective scrypt n is capped and maxmem bounds every attempt" {
    # cost 17 used to mean n=131072 (~134 MB per unauthenticated login
    # attempt); the cap folds it back to SCRYPT_MAX_N under ~32 MB.
    capped = hash_password("hunter2", n=131072);
    assert capped.split("$")[1] == str(SCRYPT_MAX_N);
    assert verify_password("hunter2", capped) is True;
    assert 128 * SCRYPT_MAX_N * 8 <= SCRYPT_MAXMEM;
    assert SCRYPT_MAXMEM <= 64 * 1024 * 1024;
}


test "stored hash with oversized parameters refuses to verify, with a warning" {
    import jaclang.runtimelib.serving.authcrypt as ac;
    ac._legacy_warned.clear();
    # Forge a stored hash claiming n=2**20 (needs ~1 GB): must refuse cleanly.
    good = hash_password("pw");
    parts = good.split("$");
    parts[1] = str(2 ** 20);
    oversized = "$".join(parts);

    def attempt {
        assert verify_password("pw", oversized) is False;
    }
    seen = _capture_warnings(attempt);
    assert len(seen) == 1 , f"expected a memory-budget warning, got {seen}";
    assert "memory budget" in seen[0];
}


test "resolve_password_hash_cost clamps to the capped range" {
    import os;
    import from jaclang.scale.config.config_loader { resolve_password_hash_cost }
    with patch.dict(os.environ, {}, clear=False) {
        os.environ.pop("JAC_SCALE_PASSWORD_HASH_COST", None);
        assert resolve_password_hash_cost(17) == 15;
        assert resolve_password_hash_cost(14) == 14;
        assert resolve_password_hash_cost(5) == 10;
    }
}


test "expire_legacy_credentials flags pre-scrypt accounts (bulk and per-user)" {
    import json;
    import from tempfile { mkdtemp }
    import from jaclang.runtimelib.pgembed { PgRuntime }
    import from jaclang.runtimelib.store { PgStore }
    import from jaclang.scale.identity.identity_storage { PgIdentityStorage }

    store = None;
    try {
        rt = PgRuntime(data_dir=mkdtemp(prefix='jacauth_') + '/data');
        store = PgStore(conninfo=rt.ensure());
    } except Exception as e {
        print(f"[skip] embedded postgres unavailable: {e}");
        return;
    }
    storage = PgIdentityStorage(store=store);

    legacy = storage.create_user(
        identities=[{'type': 'username', 'value': 'legacy_lockout_user'}],
        credential={'type': 'password', 'password': 'irrelevant'}
    );
    fresh = storage.create_user(
        identities=[{'type': 'username', 'value': 'fresh_scrypt_user'}],
        credential={'type': 'password', 'password': 'stillgood'}
    );
    legacy_id = legacy['user_id'];
    # Rewrite the legacy user's credential to a real bcrypt vector, simulating
    # a pre-0.36 database.
    storage._update_credentials(
        legacy_id, [{'type': 'password', 'password_hash': BCRYPT_VECTOR}]
    );

    expired = storage.expire_legacy_credentials();
    assert expired == [legacy_id] , f"expected only the legacy account, got {expired}";
    flagged = storage.get_user_by_id(legacy_id);
    assert flagged.get('requires_password_reset') is True;
    untouched = storage.get_user_by_id(fresh['user_id']);
    assert not untouched.get('requires_password_reset');

    # Per-user targeting: idempotent on the already-flagged account.
    assert storage.expire_legacy_credentials(legacy_id) == [legacy_id];
    assert storage.expire_legacy_credentials(fresh['user_id']) == [];

    # The reset flow recovers the account with a verifiable scrypt hash.
    reset = storage.reset_password(legacy_id, 'brand-new-password');
    assert 'error' not in reset;
    assert storage.authenticate('legacy_lockout_user', 'brand-new-password')
        is not None;
}
