"""Unit tests for IdentityStorage password hashing/verification."""

import hashlib;
import from jaclang.server.identity.identity_storage { IdentityStorage }


"""An IdentityStorage whose three storage primitives live in memory."""
obj FakeIdentityStorage(IdentityStorage) {
    has user: dict[str, any] = {},
        credentials: list[dict[str, any]] = [];

    def find_user_by_identity(value: str) -> dict[str, any] | None {
        return self.user if value == self.user.get("username") else None;
    }

    def _get_credentials(user_id: str) -> list[dict[str, any]] {
        return self.credentials;
    }

    def _update_credentials(user_id: str, credentials: list[dict[str, any]]) {
        self.credentials = credentials;
    }
}


"""A store holding one account whose credential is `password_hash`."""
def _store_with(password_hash: str) -> FakeIdentityStorage {
    return FakeIdentityStorage(
        user={"user_id": "u1", "root_id": "r1", "role": "user", "username": "alice"},
        credentials=[{"type": "password", "password_hash": password_hash}]
    );
}

test "verify_password accepts a legacy sha256 hash so accounts survive a move" {
    sha256_digest = hashlib.sha256("test_password".encode()).hexdigest();
    assert IdentityStorage.verify_password("test_password", sha256_digest) == True;
    assert IdentityStorage.verify_password("wrong", sha256_digest) == False;
}

test "verify_password rejects malformed hashes without raising" {
    assert IdentityStorage.verify_password("anything", "") == False;
    assert IdentityStorage.verify_password("anything", "not-a-hash") == False;
    assert IdentityStorage.verify_password("anything", "$2b$12$abc") == False;
}

test "verify_password round-trips a real scrypt hash" {
    hashed = IdentityStorage.hash_password("hunter2");
    assert hashed.startswith("scrypt$");
    assert IdentityStorage.verify_password("hunter2", hashed) == True;
    assert IdentityStorage.verify_password("nope", hashed) == False;
}


test "a legacy sha256 credential is rehashed on the login that verifies it" {
    legacy = hashlib.sha256("hunter2".encode()).hexdigest();
    store = _store_with(legacy);

    assert store.authenticate("alice", "nope") is None;
    assert store.credentials[0]["password_hash"] == legacy;

    result = store.authenticate("alice", "hunter2");
    assert result is not None;
    assert result["user_id"] == "u1";
    assert result["root_id"] == "r1";

    rehashed = store.credentials[0]["password_hash"];
    assert rehashed.startswith("scrypt$");
    assert store.authenticate("alice", "hunter2") is not None;
    assert store.credentials[0]["password_hash"] == rehashed;
    assert store.authenticate("alice", "nope") is None;
}


test "a scrypt credential is left alone by a successful login" {
    hashed = IdentityStorage.hash_password("hunter2");
    store = _store_with(hashed);
    assert store.authenticate("alice", "hunter2") is not None;
    assert store.credentials[0]["password_hash"] == hashed;
}
