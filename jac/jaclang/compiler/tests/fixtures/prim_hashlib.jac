"""Bundled native `hashlib`/`hmac` cross-backend equivalence fixture (#6978 Phase 1).

The SAME `import hashlib; import hmac;` binds CPython's `hashlib`/`hmac` on the sv
(Python) backend and the bundled `na_stdlib/hashlib.na.jac` / `hmac.na.jac`
Mechanism-F modules -- thin pure-Jac surfaces over OpenSSL's `libcrypto` (the FFI
floor) -- on the na (native LLVM) backend. Module-qualified `hashlib.sha256(...)`
access on the native pathway is the whole-module-import support added in #6978
(the bundled module links and `mod.func(...)` routes to its function exactly like
`import from hashlib { sha256 }`); the sv side reads the same `hashlib` attribute,
which `install_native_wrappers` never shadows (it only rebinds top-level names),
pinning the reference to CPython.

The message/key are function-LOCAL byte literals, not module `glob`s: a
module-level `glob x: bytes = b"..."` is currently not initialized along the na
JIT path (it reads empty), so a shared glob would feed an empty buffer to the
digests here -- tracked as a separate native-glob-init follow-up. Locals sidestep
it and keep the two backends fed identical input.

The harness then asserts byte-for-byte: every algorithm's `hexdigest` matches
CPython, incremental `update` matches a one-shot hash, `digest()` is
non-consuming, the `digest_size`/`block_size`/`name` attributes agree, and HMAC
matches CPython's `hmac`. ES/JS opts out.

This is the first F-module over the large bundled `libcrypto.a` (staged into the
payload in #6978 Phase 0.2), proving the archive links and runs before the
security-critical `ssl` floor is layered on the same archive (Phase 1 proper).
"""

import hashlib;
import hmac;


def hashlib_py -> dict {
    msg = b"The quick brown fox jumps over the lazy dog";
    key = b"a-secret-hmac-key";

    inc = hashlib.sha256(b"");
    inc.update(b"The quick brown fox ");
    inc.update(b"jumps over the lazy dog");

    nc = hashlib.sha256(b"abc");
    nc_first = nc.hexdigest();
    nc.update(b"def");
    nc_second = nc.hexdigest();

    return {
        "md5": hashlib.md5(msg).hexdigest(),
        "sha1": hashlib.sha1(msg).hexdigest(),
        "sha224": hashlib.sha224(msg).hexdigest(),
        "sha256": hashlib.sha256(msg).hexdigest(),
        "sha384": hashlib.sha384(msg).hexdigest(),
        "sha512": hashlib.sha512(msg).hexdigest(),
        "sha3_256": hashlib.sha3_256(msg).hexdigest(),
        "sha256_empty": hashlib.sha256(b"").hexdigest(),
        "sha256_incremental": inc.hexdigest(),
        "sha256_nc_first": nc_first,
        "sha256_nc_second": nc_second,
        "sha256_size": hashlib.sha256(b"").digest_size,
        "sha256_block": hashlib.sha256(b"").block_size,
        "sha256_name": hashlib.sha256(b"").name,
        "sha512_size": hashlib.sha512(b"").digest_size,
        "hmac_sha256": hmac.new(key, msg, "sha256").hexdigest(),
        "hmac_sha1": hmac.new(key, msg, "sha1").hexdigest(),
        "hmac_sha512": hmac.new(key, msg, "sha512").hexdigest(),
        "hmac_name": hmac.new(key, msg, "sha256").name,
        "hmac_size": hmac.new(key, msg, "sha256").digest_size,

    };
}


cl def hashlib_cl -> dict {
    return {};
}


na {
    def hashlib_na -> dict[str, any] {
        msg = b"The quick brown fox jumps over the lazy dog";
        key = b"a-secret-hmac-key";

        inc = hashlib.sha256(b"");
        inc.update(b"The quick brown fox ");
        inc.update(b"jumps over the lazy dog");

        nc = hashlib.sha256(b"abc");
        nc_first = nc.hexdigest();
        nc.update(b"def");
        nc_second = nc.hexdigest();

        return {
            "md5": hashlib.md5(msg).hexdigest(),
            "sha1": hashlib.sha1(msg).hexdigest(),
            "sha224": hashlib.sha224(msg).hexdigest(),
            "sha256": hashlib.sha256(msg).hexdigest(),
            "sha384": hashlib.sha384(msg).hexdigest(),
            "sha512": hashlib.sha512(msg).hexdigest(),
            "sha3_256": hashlib.sha3_256(msg).hexdigest(),
            "sha256_empty": hashlib.sha256(b"").hexdigest(),
            "sha256_incremental": inc.hexdigest(),
            "sha256_nc_first": nc_first,
            "sha256_nc_second": nc_second,
            "sha256_size": hashlib.sha256(b"").digest_size,
            "sha256_block": hashlib.sha256(b"").block_size,
            "sha256_name": hashlib.sha256(b"").name,
            "sha512_size": hashlib.sha512(b"").digest_size,
            "hmac_sha256": hmac.new(key, msg, "sha256").hexdigest(),
            "hmac_sha1": hmac.new(key, msg, "sha1").hexdigest(),
            "hmac_sha512": hmac.new(key, msg, "sha512").hexdigest(),
            "hmac_name": hmac.new(key, msg, "sha256").name,
            "hmac_size": hmac.new(key, msg, "sha256").digest_size,

        };
    }
}
