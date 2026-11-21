"""Bundled native `secrets` cross-backend equivalence fixture (#6978 Phase 1).

The SAME `import secrets` binds CPython's `secrets` on the sv (Python) backend
and the bundled `na_stdlib/secrets.jac` Mechanism-F module -- a thin pure-Jac
surface over OpenSSL's `RAND_bytes` (the `_csprng_native.jac` FFI floor on the
same bundled `libcrypto.a` as hashlib) -- on the na (native LLVM) backend.

Because the outputs are RANDOM, this fixture pins the two implementations
congruent on their deterministic *properties* rather than exact bytes: token
lengths (`token_bytes`/`token_hex`/`token_urlsafe` sizes, including the empty
case), `randbelow`'s degenerate `randbelow(1) == 0` and in-range bound, and that
two draws differ. ES/JS opts out.
"""

import secrets;


def secrets_py -> dict[any, any] {
    rb1000 = secrets.randbelow(1000);
    tok = secrets.token_urlsafe(64);
    tok_ok = 1;
    ti: int = 0;
    while ti < len(tok) {
        oc: int = ord(tok[ti]);
        in_alpha: bool = (oc >= 65 and oc <= 90)
            or (oc >= 97 and oc <= 122)
            or (oc >= 48 and oc <= 57)
            or oc == 45
            or oc == 95;
        if not in_alpha {
            tok_ok = 0;
        }
        ti += 1;
    }
    tb_neg = "?";
    try {
        secrets.token_bytes(-1);
    } except ValueError as e {
        tb_neg = str(e);
    }
    tb_str = "?";
    try {
        bad_n: any = "x";
        secrets.token_bytes(bad_n);
    } except TypeError as e {
        tb_str = str(e);
    }
    tb_flt = "?";
    try {
        bad_f: any = 1.5;
        secrets.token_bytes(bad_f);
    } except TypeError as e {
        tb_flt = str(e);
    }
    return {
        "tb16_len": len(secrets.token_bytes(16)),
        "tb0_len": len(secrets.token_bytes(0)),
        "tb_none_len": len(secrets.token_bytes(None)),
        "tb_neg": tb_neg,
        "tb_str": tb_str,
        "tb_flt": tb_flt,
        "tb_bool_len": len(secrets.token_bytes(True)),
        "th16_len": len(secrets.token_hex(16)),
        "th0_len": len(secrets.token_hex(0)),
        "th_none_len": len(secrets.token_hex(None)),
        "tu16_len": len(secrets.token_urlsafe(16)),
        "tu_none_len": len(secrets.token_urlsafe(None)),
        "tu64_urlsafe": tok_ok,
        "default_entropy": secrets.DEFAULT_ENTROPY,
        "cd_eq": 1 if secrets.compare_digest(b"aa", b"aa") else 0,
        "cd_neq": 1 if secrets.compare_digest(b"aa", b"bb") else 0,
        "rb1": secrets.randbelow(1),
        "rb1000_ok": 1 if (rb1000 >= 0 and rb1000 < 1000) else 0,
        "two_differ": 1 if secrets.token_bytes(16) != secrets.token_bytes(16) else 0,

    };
}


def secrets_cl -> dict[any, any] {
    return {};
}


def secrets_na -> dict[str, any] {
    rb1000 = secrets.randbelow(1000);
    tok = secrets.token_urlsafe(64);
    tok_ok = 1;
    ti: int = 0;
    while ti < len(tok) {
        oc: int = ord(tok[ti]);
        in_alpha: bool = (oc >= 65 and oc <= 90)
            or (oc >= 97 and oc <= 122)
            or (oc >= 48 and oc <= 57)
            or oc == 45
            or oc == 95;
        if not in_alpha {
            tok_ok = 0;
        }
        ti += 1;
    }
    tb_neg = "?";
    try {
        secrets.token_bytes(-1);
    } except ValueError as e {
        tb_neg = str(e);
    }
    tb_str = "?";
    try {
        bad_n: any = "x";
        secrets.token_bytes(bad_n);
    } except TypeError as e {
        tb_str = str(e);
    }
    tb_flt = "?";
    try {
        bad_f: any = 1.5;
        secrets.token_bytes(bad_f);
    } except TypeError as e {
        tb_flt = str(e);
    }
    return {
        "tb16_len": len(secrets.token_bytes(16)),
        "tb0_len": len(secrets.token_bytes(0)),
        "tb_none_len": len(secrets.token_bytes(None)),
        "tb_neg": tb_neg,
        "tb_str": tb_str,
        "tb_flt": tb_flt,
        "tb_bool_len": len(secrets.token_bytes(True)),
        "th16_len": len(secrets.token_hex(16)),
        "th0_len": len(secrets.token_hex(0)),
        "th_none_len": len(secrets.token_hex(None)),
        "tu16_len": len(secrets.token_urlsafe(16)),
        "tu_none_len": len(secrets.token_urlsafe(None)),
        "tu64_urlsafe": tok_ok,
        "default_entropy": secrets.DEFAULT_ENTROPY,
        "cd_eq": 1 if secrets.compare_digest(b"aa", b"aa") else 0,
        "cd_neq": 1 if secrets.compare_digest(b"aa", b"bb") else 0,
        "rb1": secrets.randbelow(1),
        "rb1000_ok": 1 if (rb1000 >= 0 and rb1000 < 1000) else 0,
        "two_differ": 1 if secrets.token_bytes(16) != secrets.token_bytes(16) else 0,

    };
}
