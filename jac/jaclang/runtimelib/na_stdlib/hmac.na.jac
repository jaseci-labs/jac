"""Bundled native `hmac` — pure-Jac surface over the libcrypto FFI floor.

Part of the native standard library shipped under
`jaclang/runtimelib/na_stdlib` (issue #6978 Phase 1). On the native (na) pathway
`import from hmac { new }` resolves to this module through the shared
bundled-stdlib resolver; on the sv/Python pathway the identical import binds
CPython's real `hmac`. The two are held congruent by the tri-backend equivalence
suite (prim_hashlib.jac).

Mechanism-F architecture (#6978): the HMAC construction is never reimplemented —
it is OpenSSL's `libcrypto` `HMAC_*` API, reached through the thin FFI floor in
`_hashlib_native.na.jac`. This module is the Python-shaped API on top: an HMAC
object with `update`/`digest`/`hexdigest`/`copy` and CPython's
`digest_size`/`block_size`/`name` (`"hmac-<algo>"`) attributes.

`digestmod` is accepted as an algorithm-name string (e.g. `"sha256"`), the form
CPython recommends; module/callable digestmods are a follow-up. Like the bundled
`hashlib`, the message is accumulated as `bytes` chunks and HMACed in one shot, so
`.digest()` is non-consuming. PORTABILITY: native-host-only (libcrypto floor).
"""

import from _hashlib_native {
    evp_md_for,
    digest_size_for,
    block_size_for,
    hmac_digest,
    to_hex
}


"""An HMAC object congruent with CPython's `hmac.HMAC`.

Holds the key and the fed message chunks; `digest`/`hexdigest` recompute the MAC
in one shot through the libcrypto floor, so `.digest()` is non-consuming and
further `update`s extend the message — matching CPython."""
obj:pub HMAC {
    has _md: int,
        _key: bytes,
        _chunks: list[bytes],
        digest_size: int,
        block_size: int,
        name: str;

    """Feed more data into the running MAC (CPython `HMAC.update`)."""
    def update(data: bytes) {
        self._chunks.append(data);
    }

    """The raw MAC of the data fed so far (CPython `HMAC.digest`)."""
    def digest -> bytes {
        return hmac_digest(self._md, self._key, self._chunks, self.digest_size);
    }

    """The MAC as a lowercase hex string (CPython `HMAC.hexdigest`)."""
    def hexdigest -> str {
        return to_hex(self.digest());
    }

    """An independent copy of the MAC state (CPython `HMAC.copy`)."""
    def copy -> HMAC {
        cp: list[bytes] = [];
        for c in self._chunks {
            cp.append(c);
        }
        return HMAC(
            _md=self._md,
            _key=self._key,
            _chunks=cp,
            digest_size=self.digest_size,
            block_size=self.block_size,
            name=self.name
        );
    }
}


"""Construct an HMAC object keyed by `key`, optionally seeded with `msg`, using
the digest named by `digestmod` (CPython `hmac.new`). Raises `ValueError` for an
unsupported digest."""
def:pub new(key: bytes, msg: bytes = b"", digestmod: str = "sha256") -> HMAC {
    md: int = evp_md_for(digestmod);
    if md == 0 {
        raise ValueError("unsupported hash type " + digestmod);
    }
    hm = HMAC(
        _md=md,
        _key=key,
        _chunks=[],
        digest_size=digest_size_for(digestmod),
        block_size=block_size_for(digestmod),
        name="hmac-" + digestmod
    );
    hm.update(msg);
    return hm;
}


"""Compute an HMAC digest in one call (CPython `hmac.digest(key, msg, digest)`)."""
def:pub digest(key: bytes, msg: bytes, digest: str) -> bytes {
    return new(key, msg, digest).digest();
}
