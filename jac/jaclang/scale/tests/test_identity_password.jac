"""Unit tests for IdentityStorage password hashing/verification."""

import hashlib;
import from jaclang.scale.identity.identity_storage { IdentityStorage }

test "verify_password rejects non-bcrypt hashes without raising" {
    sha256_digest = hashlib.sha256("test_password".encode()).hexdigest();
    assert IdentityStorage.verify_password("test_password", sha256_digest) == False;
    assert IdentityStorage.verify_password("wrong", sha256_digest) == False;
    assert IdentityStorage.verify_password("anything", "") == False;
    assert IdentityStorage.verify_password("anything", "not-a-hash") == False;
}

test "verify_password round-trips a real bcrypt hash" {
    hashed = IdentityStorage.hash_password("hunter2");
    assert hashed.startswith("$2b$");
    assert IdentityStorage.verify_password("hunter2", hashed) == True;
    assert IdentityStorage.verify_password("nope", hashed) == False;
}
