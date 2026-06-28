"""Bundled native `hashlib` — pure-Jac surface over the libcrypto FFI floor.

Part of the native standard library shipped under
`jaclang/runtimelib/na_stdlib` (issue #6978 Phase 1). On the native (na) pathway
`import from hashlib { sha256, new, ... }` resolves to this module through the
shared bundled-stdlib resolver; on the sv/Python pathway the identical import
binds CPython's real `hashlib`. The two are held congruent by the tri-backend
equivalence suite (prim_hashlib.jac), which hashes the same inputs through this
module on na and CPython on sv and asserts byte-identical `hexdigest`s.

Mechanism-F architecture (#6978): the digest engines are never reimplemented —
they are OpenSSL's `libcrypto`, reached through the thin FFI floor in
`_hashlib_native.na.jac`. This module is the stable, Python-shaped API on top: a
hash object with `update`/`digest`/`hexdigest`/`copy`, the per-algorithm
constructors (`sha256`, `sha1`, `md5`, ...), and `new(name)`, mirroring CPython's
argument shapes and `digest_size`/`block_size`/`name` attributes.

PORTABILITY: native-host-only (inherited from the libcrypto floor).

Coverage (issue #6978 partial-coverage policy): the always-built OpenSSL digests
`md5`/`sha1`/`sha224`/`sha256`/`sha384`/`sha512` plus `sha3_256`/`sha3_512`.
`blake2`/`shake`/`pbkdf2`/`scrypt` and the `usedforsecurity=` flag are follow-ups.
"""

import from _hashlib_native {
    evp_md_for,
    digest_size_for,
    block_size_for,
    evp_digest,
    to_hex
}


"""A hash object congruent with CPython's `hashlib` objects.

Accumulates fed data as a list of `bytes` chunks (`update`) and digests them in
one shot through the libcrypto floor (`digest`/`hexdigest`), so `.digest()` is
non-consuming and further `update`s extend the message — matching CPython."""
obj:pub Hash {
    has _md: int,
        _chunks: list[bytes],
        digest_size: int,
        block_size: int,
        name: str;

    """Feed more data into the running hash (CPython `Hash.update`)."""
    def update(data: bytes) {
        self._chunks.append(data);
    }

    """The raw digest of the data fed so far (CPython `Hash.digest`)."""
    def digest -> bytes {
        return evp_digest(self._md, self._chunks, self.digest_size);
    }

    """The digest as a lowercase hex string (CPython `Hash.hexdigest`)."""
    def hexdigest -> str {
        return to_hex(self.digest());
    }

    """An independent copy of the hash state (CPython `Hash.copy`)."""
    def copy -> Hash {
        cp: list[bytes] = [];
        for c in self._chunks {
            cp.append(c);
        }
        return Hash(
            _md=self._md,
            _chunks=cp,
            digest_size=self.digest_size,
            block_size=self.block_size,
            name=self.name
        );
    }
}


"""Construct a hash object for algorithm `name`, optionally seeded with `data`.

CPython exposes this as the public `hashlib.new`, but on the native pathway a
`:pub` symbol has external linkage and would collide at link time with `hmac`'s
own public `new` whenever a program imports both modules (E5026 -- module-scoped
symbol qualification is a follow-up). It is `:priv` here: the named constructors
below (`sha256`, ...) -- the common API -- call it within the module, so the
bundled-`new` congruence gap is limited to the dynamic `hashlib.new("name")`
form. Raises `ValueError` for an unsupported algorithm."""
def:priv new(name: str, data: bytes = b"") -> Hash {
    md: int = evp_md_for(name);
    if md == 0 {
        raise ValueError("unsupported hash type " + name);
    }
    h = Hash(
        _md=md,
        _chunks=[],
        digest_size=digest_size_for(name),
        block_size=block_size_for(name),
        name=name
    );
    h.update(data);
    return h;
}


"""MD5 hash object, optionally seeded with `data` (CPython `hashlib.md5`)."""
def:pub md5(data: bytes = b"") -> Hash {
    return new("md5", data);
}


"""SHA-1 hash object, optionally seeded with `data` (CPython `hashlib.sha1`)."""
def:pub sha1(data: bytes = b"") -> Hash {
    return new("sha1", data);
}


"""SHA-224 hash object, optionally seeded with `data` (CPython `hashlib.sha224`)."""
def:pub sha224(data: bytes = b"") -> Hash {
    return new("sha224", data);
}


"""SHA-256 hash object, optionally seeded with `data` (CPython `hashlib.sha256`)."""
def:pub sha256(data: bytes = b"") -> Hash {
    return new("sha256", data);
}


"""SHA-384 hash object, optionally seeded with `data` (CPython `hashlib.sha384`)."""
def:pub sha384(data: bytes = b"") -> Hash {
    return new("sha384", data);
}


"""SHA-512 hash object, optionally seeded with `data` (CPython `hashlib.sha512`)."""
def:pub sha512(data: bytes = b"") -> Hash {
    return new("sha512", data);
}


"""SHA3-256 hash object, optionally seeded with `data` (CPython `hashlib.sha3_256`)."""
def:pub sha3_256(data: bytes = b"") -> Hash {
    return new("sha3_256", data);
}


"""SHA3-512 hash object, optionally seeded with `data` (CPython `hashlib.sha3_512`)."""
def:pub sha3_512(data: bytes = b"") -> Hash {
    return new("sha3_512", data);
}
