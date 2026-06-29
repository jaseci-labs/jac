"""Bundled native `uuid` (v4) cross-backend equivalence fixture (#6978 Phase 1).

The SAME `import uuid` binds CPython's `uuid` on the sv (Python) backend and the
bundled `na_stdlib/uuid.na.jac` Mechanism-F module -- a thin pure-Jac surface
over OpenSSL's `RAND_bytes` (the `_csprng_native.na.jac` floor on the same
bundled `libcrypto.a` as hashlib/secrets) -- on the na (native LLVM) backend.

Because the output is RANDOM, this fixture pins the two implementations congruent
on the deterministic *structure* of a v4 UUID rather than exact bytes: the
`hex`/`str()` lengths, the `8-4-4-4-12` hyphen layout, the version nibble (`4`),
the RFC-4122 variant nibble (`8`/`9`/`a`/`b`), `.version == 4`, and that two
draws differ. It exercises native `str(obj)`/`__str__` dispatch (#7003). ES/JS
opts out.
"""

import uuid;


def uuid_py -> dict {
    u = uuid.uuid4();
    s = str(u);
    var = s[19];
    return {
        "hex_len": len(u.hex),
        "str_len": len(s),
        "version": u.version,
        "dash8": 1 if s[8] == "-" else 0,
        "dash13": 1 if s[13] == "-" else 0,
        "dash18": 1 if s[18] == "-" else 0,
        "dash23": 1 if s[23] == "-" else 0,
        "ver4": 1 if s[14] == "4" else 0,
        "variant_ok": 1
            if (var == "8" or var == "9" or var == "a" or var == "b")
            else 0,
        "two_differ": 1 if uuid.uuid4().hex != uuid.uuid4().hex else 0,

    };
}


cl def uuid_cl -> dict {
    return {};
}


na {
    def uuid_na -> dict[str, any] {
        u = uuid.uuid4();
        s = str(u);
        var = s[19];
        return {
            "hex_len": len(u.hex),
            "str_len": len(s),
            "version": u.version,
            "dash8": 1 if s[8] == "-" else 0,
            "dash13": 1 if s[13] == "-" else 0,
            "dash18": 1 if s[18] == "-" else 0,
            "dash23": 1 if s[23] == "-" else 0,
            "ver4": 1 if s[14] == "4" else 0,
            "variant_ok": 1
                if (var == "8" or var == "9" or var == "a" or var == "b")
                else 0,
            "two_differ": 1 if uuid.uuid4().hex != uuid.uuid4().hex else 0,

        };
    }
}
