"""Bundled native `secrets` cross-backend equivalence fixture (#6978 Phase 1).

The SAME `import secrets` binds CPython's `secrets` on the sv (Python) backend
and the bundled `na_stdlib/secrets.na.jac` Mechanism-F module -- a thin pure-Jac
surface over OpenSSL's `RAND_bytes` (the `_csprng_native.na.jac` FFI floor on the
same bundled `libcrypto.a` as hashlib) -- on the na (native LLVM) backend.

Because the outputs are RANDOM, this fixture pins the two implementations
congruent on their deterministic *properties* rather than exact bytes: token
lengths (`token_bytes`/`token_hex`/`token_urlsafe` sizes, including the empty
case), `randbelow`'s degenerate `randbelow(1) == 0` and in-range bound, and that
two draws differ. ES/JS opts out.
"""

import secrets;


def secrets_py -> dict {
    rb1000 = secrets.randbelow(1000);
    return {
        "tb16_len": len(secrets.token_bytes(16)),
        "tb0_len": len(secrets.token_bytes(0)),
        "th16_len": len(secrets.token_hex(16)),
        "th0_len": len(secrets.token_hex(0)),
        "tu16_len": len(secrets.token_urlsafe(16)),
        "rb1": secrets.randbelow(1),
        "rb1000_ok": 1 if (rb1000 >= 0 and rb1000 < 1000) else 0,
        "two_differ": 1 if secrets.token_bytes(16) != secrets.token_bytes(16) else 0,

    };
}


cl def secrets_cl -> dict {
    return {};
}


na {
    def secrets_na -> dict[str, any] {
        rb1000 = secrets.randbelow(1000);
        return {
            "tb16_len": len(secrets.token_bytes(16)),
            "tb0_len": len(secrets.token_bytes(0)),
            "th16_len": len(secrets.token_hex(16)),
            "th0_len": len(secrets.token_hex(0)),
            "tu16_len": len(secrets.token_urlsafe(16)),
            "rb1": secrets.randbelow(1),
            "rb1000_ok": 1 if (rb1000 >= 0 and rb1000 < 1000) else 0,
            "two_differ": 1
                if secrets.token_bytes(16) != secrets.token_bytes(16)
                else 0,

        };
    }
}
