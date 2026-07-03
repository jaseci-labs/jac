"""Bundled native ``base64`` cross-backend equivalence fixture.

The SAME ``import from base64 { ... }`` binds CPython's ``base64`` on the sv
(Python) backend and the bundled ``na_stdlib/base64.na.jac`` Mechanism-B module
on the na (native LLVM) backend. This fixture pins the two congruent.

Outputs are compared via a custom FNV-1a digest (``_digest``) rather than as
raw bytes because the cross-backend harness marshals a returned
``dict[str, any]`` but cannot marshal raw ``bytes`` values across the sv/na
boundary -- so each encoding is hashed to an int and its length is recorded,
then the two backends are compared on those scalars. Round-trips (encode then
decode back to the original) are compared as boolean flags, and error paths
are compared on ``str(e)`` of the raised ``ValueError`` (``binascii.Error``
subclasses ``ValueError``, so one ``except`` arm covers both backends).

The case body is duplicated between the sv function and the ``na`` block
because the native pathway compiles only the ``na { }`` region of a fixture:
a module-level helper called from native code lowers to an unregistered
interop stub and crashes the harness. On the na side the body is further
split into small helpers, each mutating the shared result dict -- one
function carrying the whole case body exceeds what the na backend can
currently JIT reliably in a single function.

Case inputs use CPython 3.14 semantics throughout: every expected value and
error message below was probed against the embedded CPython 3.14.6 runtime
(the sv backend), including 3.14's non-strict ``a2b_base64`` end-of-input
padding rules (``Zg==Zg==`` concatenates data characters across padding;
``Zm8=Zm8=`` is ``Incorrect padding``).

ES/JS opts out (``base64_cl`` returns an empty dict).
"""

import from base64 {
    b16encode,
    b16decode,
    b32encode,
    b32decode,
    b64encode,
    b64decode,
    standard_b64encode,
    standard_b64decode,
    urlsafe_b64encode,
    urlsafe_b64decode,
    b85encode,
    b85decode
}


def _digest(data: bytes) -> int {
    acc: int = 2166136261;
    n: int = len(data);
    i: int = 0;
    while i < n {
        acc = (acc * 131 + data[i]) % 2147483647;
        i += 1;
    }
    return acc;
}


def _lower(data: bytes) -> bytes {
    out: list[int] = [];
    n: int = len(data);
    i: int = 0;
    while i < n {
        c: int = data[i];
        if c >= 65 and c <= 90 {
            c += 32;
        }
        out.append(c);
        i += 1;
    }
    return bytes(out);
}


def base64_py() -> dict {
    data = b"the quick brown fox jumps over the lazy dog. " * 3;
    s1 = b"f";
    s2 = b"fo";
    s3 = b"foo";
    s4 = b"foob";
    s5 = b"fooba";
    sff = b"\xff\xff";

    fl: list[int] = [];
    k: int = 0;
    while k < 256 {
        fl.append(k);
        k += 1;
    }
    full = bytes(fl);

    e16 = b16encode(data);
    e32 = b32encode(data);
    e64 = b64encode(data);
    e64u = urlsafe_b64encode(data);
    e85 = b85encode(data);

    f16 = b16encode(full);
    f32 = b32encode(full);
    f64 = b64encode(full);
    f64u = urlsafe_b64encode(full);
    f85 = b85encode(full);

    r: dict[str, any] = {
        "e16_digest": _digest(e16),
        "e16_len": len(e16),
        "e32_digest": _digest(e32),
        "e32_len": len(e32),
        "e64_digest": _digest(e64),
        "e64_len": len(e64),
        "e64u_digest": _digest(e64u),
        "e64u_len": len(e64u),
        "e85_digest": _digest(e85),
        "e85_len": len(e85),
        "rt16": 1 if b16decode(e16) == data else 0,
        "rt32": 1 if b32decode(e32) == data else 0,
        "rt64": 1 if b64decode(e64) == data else 0,
        "rt64u": 1 if urlsafe_b64decode(e64u) == data else 0,
        "rt85": 1 if b85decode(e85) == data else 0,
        "f16_digest": _digest(f16),
        "f16_len": len(f16),
        "rt_f16": 1 if b16decode(f16) == full else 0,
        "f32_digest": _digest(f32),
        "f32_len": len(f32),
        "rt_f32": 1 if b32decode(f32) == full else 0,
        "f64_digest": _digest(f64),
        "f64_len": len(f64),
        "rt_f64": 1 if b64decode(f64) == full else 0,
        "f64u_digest": _digest(f64u),
        "rt_f64u": 1 if urlsafe_b64decode(f64u) == full else 0,
        "f85_digest": _digest(f85),
        "f85_len": len(f85),
        "rt_f85": 1 if b85decode(f85) == full else 0,
        "p1": _digest(b64encode(s1)),
        "p2": _digest(b64encode(s2)),
        "p3": _digest(b64encode(s3)),
        "p4": _digest(b32encode(s4)),
        "p5": _digest(b85encode(s5)),
        "p32_1": _digest(b32encode(s1)),
        "rt32_1": 1 if b32decode(b32encode(s1)) == s1 else 0,
        "p32_2": _digest(b32encode(s2)),
        "rt32_2": 1 if b32decode(b32encode(s2)) == s2 else 0,
        "p32_3": _digest(b32encode(s3)),
        "rt32_3": 1 if b32decode(b32encode(s3)) == s3 else 0,
        "rt32_4": 1 if b32decode(b32encode(s4)) == s4 else 0,
        "p85_2": _digest(b85encode(s2)),
        "rt85_2": 1 if b85decode(b85encode(s2)) == s2 else 0,
        "p85_3": _digest(b85encode(s3)),
        "rt85_3": 1 if b85decode(b85encode(s3)) == s3 else 0,
        "rt_s1": 1 if b64decode(b64encode(s1)) == s1 else 0,
        "rt_s3": 1 if b64decode(b64encode(s3)) == s3 else 0,
        "rt_s5": 1 if b85decode(b85encode(s5)) == s5 else 0,
        "rt_s1_16": 1 if b16decode(b16encode(s1)) == s1 else 0,
        "empty64": 1 if b64encode(b"") == b"" else 0,
        "emp16e": len(b16encode(b"")),
        "emp16d": len(b16decode(b"")),
        "emp32e": len(b32encode(b"")),
        "emp32d": len(b32decode(b"")),
        "emp64e": len(b64encode(b"")),
        "emp64d": len(b64decode(b"")),
        "emp64ud": len(urlsafe_b64decode(b"")),
        "emp85e": len(b85encode(b"")),
        "emp85d": len(b85decode(b"")),
        "std_b64_rt": 1 if standard_b64decode(standard_b64encode(data)) == data else 0,
        "std_b64_eq": 1 if standard_b64encode(data) == b64encode(data) else 0,
        "alt_rt": 1 if b64decode(b64encode(sff, b"-_"), b"-_") == sff else 0,
        "alt_digest": _digest(b64encode(sff, b"-_")),
        "alt_ne_std": 1 if b64encode(sff, b"-_") != b64encode(sff) else 0,
        "alt_eq_urlsafe": 1 if b64encode(sff, b"-_") == urlsafe_b64encode(sff) else 0,
        "cf16": 1 if b16decode(_lower(e16), True) == data else 0,
        "cf32": 1 if b32decode(_lower(e32), True) == data else 0,
        "b85pad_digest": _digest(b85encode(s5, True)),
        "b85pad_eq_padded_input": 1
            if b85encode(s5, True) == b85encode(s5 + b"\x00\x00\x00")
            else 0,
        "b85pad_decode_padded": 1
            if b85decode(b85encode(s5, True)) == s5 + b"\x00\x00\x00"
            else 0,
        "b85pad_longer": 1 if len(b85encode(s5, True)) > len(b85encode(s5)) else 0,
        "ws64": 1 if b64decode(b"aGVs\nbG8=") == b"hello" else 0,
        "junk64": 1 if b64decode(b"Zm9%vYg==") == b"foob" else 0,
        "tail64": 1 if b64decode(b"Zm8=x") == b"fo1" else 0,
        "cat64": _digest(b64decode(b"Zg==Zg==")),
        "part64": 1 if b64decode(b"Zm==") == b"f" else 0,
        "u64_plus": _digest(urlsafe_b64decode(b"+/A=")),
        "u64_mixed": _digest(urlsafe_b64decode(b"-_+/AA==")),
        "u64_ws": 1 if urlsafe_b64decode(b"aGVs\nbG8=") == b"hello" else 0,
        "v64_ok": 1 if b64decode(b"Zm9vYmFy", b"-_", True) == b"foobar" else 0,
        "v64_alt": _digest(b64decode(b"+/A=", b"-_", True)),
        "m01_zero": 1 if b32decode(b"MZXW0===", False, b"L") == b"fog" else 0,
        "m01_one": 1 if b32decode(b"MZXW1===", False, b"L") == b"foe" else 0,
        "m01_i": 1 if b32decode(b"MZXW1===", False, b"I") == b"fod" else 0,
        "m01_cf": 1 if b32decode(b"mzxw1===", True, b"L") == b"foe" else 0
    };

    r["err64_pad"] = "?";
    try {
        b64decode(b"Zm8");
    } except ValueError as e {
        r["err64_pad"] = str(e);
    }
    r["err64_one"] = "?";
    try {
        b64decode(b"Zm888");
    } except ValueError {
        r["err64_one"] = "raised";
    }
    r["err64_mid"] = "?";
    try {
        b64decode(b"Zm8=Zm8=");
    } except ValueError as e {
        r["err64_mid"] = str(e);
    }
    r["errv64_junk"] = "?";
    try {
        b64decode(b"aGVs\nbG8=", b"-_", True);
    } except ValueError as e {
        r["errv64_junk"] = str(e);
    }
    r["errv64_lead"] = "?";
    try {
        b64decode(b"=Zm9v", b"-_", True);
    } except ValueError as e {
        r["errv64_lead"] = str(e);
    }
    r["errv64_data"] = "?";
    try {
        b64decode(b"Zm8=Zm8=", b"-_", True);
    } except ValueError as e {
        r["errv64_data"] = str(e);
    }
    r["errv64_pad"] = "?";
    try {
        b64decode(b"Zm9v=", b"-_", True);
    } except ValueError as e {
        r["errv64_pad"] = str(e);
    }
    r["errv64_disc"] = "?";
    try {
        b64decode(b"Zm=8", b"-_", True);
    } except ValueError as e {
        r["errv64_disc"] = str(e);
    }
    r["err16_digit"] = "?";
    try {
        b16decode(b"6G");
    } except ValueError as e {
        r["err16_digit"] = str(e);
    }
    r["err16_lower"] = "?";
    try {
        b16decode(b"666f");
    } except ValueError as e {
        r["err16_lower"] = str(e);
    }
    r["err16_odd"] = "?";
    try {
        b16decode(b"666");
    } except ValueError as e {
        r["err16_odd"] = str(e);
    }
    r["err32_digit"] = "?";
    try {
        b32decode(b"M!XW6===");
    } except ValueError as e {
        r["err32_digit"] = str(e);
    }
    r["err32_len"] = "?";
    try {
        b32decode(b"MZXW6");
    } except ValueError as e {
        r["err32_len"] = str(e);
    }
    r["err32_pad2"] = "?";
    try {
        b32decode(b"MZXW6Y==");
    } except ValueError as e {
        r["err32_pad2"] = str(e);
    }
    r["err85_char"] = "?";
    try {
        b85decode(b"ab c");
    } except ValueError {
        r["err85_char"] = "raised";
    }
    r["err85_over"] = "?";
    try {
        b85decode(b"~~~~");
    } except ValueError {
        r["err85_over"] = "raised";
    }
    return r;
}


cl def base64_cl() -> dict {
    return {};
}


na {
    # The native body is split into small helpers, each mutating the shared
    # result dict: one function carrying the whole case body exceeds what the
    # na backend can currently JIT reliably in a single function.
    def _digest_na(data: bytes) -> int {
        acc: int = 2166136261;
        n: int = len(data);
        i: int = 0;
        while i < n {
            acc = (acc * 131 + data[i]) % 2147483647;
            i += 1;
        }
        return acc;
    }

    def _lower_na(data: bytes) -> bytes {
        out: list[int] = [];
        n: int = len(data);
        i: int = 0;
        while i < n {
            c: int = data[i];
            if c >= 65 and c <= 90 {
                c += 32;
            }
            out.append(c);
            i += 1;
        }
        return bytes(out);
    }

    def _enc_core_na(r: dict[str, any]) {
        data = b"the quick brown fox jumps over the lazy dog. " * 3;
        e16 = b16encode(data);
        e32 = b32encode(data);
        e64 = b64encode(data);
        e64u = urlsafe_b64encode(data);
        e85 = b85encode(data);
        r["e16_digest"] = _digest_na(e16);
        r["e16_len"] = len(e16);
        r["e32_digest"] = _digest_na(e32);
        r["e32_len"] = len(e32);
        r["e64_digest"] = _digest_na(e64);
        r["e64_len"] = len(e64);
        r["e64u_digest"] = _digest_na(e64u);
        r["e64u_len"] = len(e64u);
        r["e85_digest"] = _digest_na(e85);
        r["e85_len"] = len(e85);
        r["rt16"] = 1 if b16decode(e16) == data else 0;
        r["rt32"] = 1 if b32decode(e32) == data else 0;
        r["rt64"] = 1 if b64decode(e64) == data else 0;
        r["rt64u"] = 1 if urlsafe_b64decode(e64u) == data else 0;
        r["rt85"] = 1 if b85decode(e85) == data else 0;
    }

    def _full_range_na(r: dict[str, any]) {
        fl: list[int] = [];
        k: int = 0;
        while k < 256 {
            fl.append(k);
            k += 1;
        }
        full = bytes(fl);
        f16 = b16encode(full);
        f32 = b32encode(full);
        f64 = b64encode(full);
        f64u = urlsafe_b64encode(full);
        f85 = b85encode(full);
        r["f16_digest"] = _digest_na(f16);
        r["f16_len"] = len(f16);
        r["rt_f16"] = 1 if b16decode(f16) == full else 0;
        r["f32_digest"] = _digest_na(f32);
        r["f32_len"] = len(f32);
        r["rt_f32"] = 1 if b32decode(f32) == full else 0;
        r["f64_digest"] = _digest_na(f64);
        r["f64_len"] = len(f64);
        r["rt_f64"] = 1 if b64decode(f64) == full else 0;
        r["f64u_digest"] = _digest_na(f64u);
        r["rt_f64u"] = 1 if urlsafe_b64decode(f64u) == full else 0;
        r["f85_digest"] = _digest_na(f85);
        r["f85_len"] = len(f85);
        r["rt_f85"] = 1 if b85decode(f85) == full else 0;
    }

    def _pad_small_na(r: dict[str, any]) {
        s1 = b"f";
        s2 = b"fo";
        s3 = b"foo";
        s4 = b"foob";
        s5 = b"fooba";
        r["p1"] = _digest_na(b64encode(s1));
        r["p2"] = _digest_na(b64encode(s2));
        r["p3"] = _digest_na(b64encode(s3));
        r["p4"] = _digest_na(b32encode(s4));
        r["p5"] = _digest_na(b85encode(s5));
        r["rt_s1"] = 1 if b64decode(b64encode(s1)) == s1 else 0;
        r["rt_s3"] = 1 if b64decode(b64encode(s3)) == s3 else 0;
        r["rt_s5"] = 1 if b85decode(b85encode(s5)) == s5 else 0;
        r["rt_s1_16"] = 1 if b16decode(b16encode(s1)) == s1 else 0;
    }

    def _pad_bounds_na(r: dict[str, any]) {
        s1 = b"f";
        s2 = b"fo";
        s3 = b"foo";
        s4 = b"foob";
        r["p32_1"] = _digest_na(b32encode(s1));
        r["rt32_1"] = 1 if b32decode(b32encode(s1)) == s1 else 0;
        r["p32_2"] = _digest_na(b32encode(s2));
        r["rt32_2"] = 1 if b32decode(b32encode(s2)) == s2 else 0;
        r["p32_3"] = _digest_na(b32encode(s3));
        r["rt32_3"] = 1 if b32decode(b32encode(s3)) == s3 else 0;
        r["rt32_4"] = 1 if b32decode(b32encode(s4)) == s4 else 0;
        r["p85_2"] = _digest_na(b85encode(s2));
        r["rt85_2"] = 1 if b85decode(b85encode(s2)) == s2 else 0;
        r["p85_3"] = _digest_na(b85encode(s3));
        r["rt85_3"] = 1 if b85decode(b85encode(s3)) == s3 else 0;
    }

    def _empty_na(r: dict[str, any]) {
        r["empty64"] = 1 if b64encode(b"") == b"" else 0;
        r["emp16e"] = len(b16encode(b""));
        r["emp16d"] = len(b16decode(b""));
        r["emp32e"] = len(b32encode(b""));
        r["emp32d"] = len(b32decode(b""));
        r["emp64e"] = len(b64encode(b""));
        r["emp64d"] = len(b64decode(b""));
        r["emp64ud"] = len(urlsafe_b64decode(b""));
        r["emp85e"] = len(b85encode(b""));
        r["emp85d"] = len(b85decode(b""));
    }

    def _alt_std_na(r: dict[str, any]) {
        data = b"the quick brown fox jumps over the lazy dog. " * 3;
        sff = b"\xff\xff";
        s5 = b"fooba";
        e16 = b16encode(data);
        e32 = b32encode(data);
        r["std_b64_rt"] = 1
            if standard_b64decode(standard_b64encode(data)) == data
            else 0;
        r["std_b64_eq"] = 1 if standard_b64encode(data) == b64encode(data) else 0;
        r["alt_rt"] = 1 if b64decode(b64encode(sff, b"-_"), b"-_") == sff else 0;
        r["alt_digest"] = _digest_na(b64encode(sff, b"-_"));
        r["alt_ne_std"] = 1 if b64encode(sff, b"-_") != b64encode(sff) else 0;
        r["alt_eq_urlsafe"] = 1
            if b64encode(sff, b"-_") == urlsafe_b64encode(sff)
            else 0;
        r["cf16"] = 1 if b16decode(_lower_na(e16), True) == data else 0;
        r["cf32"] = 1 if b32decode(_lower_na(e32), True) == data else 0;
        r["b85pad_digest"] = _digest_na(b85encode(s5, True));
        r["b85pad_eq_padded_input"] = 1
            if b85encode(s5, True) == b85encode(s5 + b"\x00\x00\x00")
            else 0;
        r["b85pad_decode_padded"] = 1
            if b85decode(b85encode(s5, True)) == s5 + b"\x00\x00\x00"
            else 0;
        r["b85pad_longer"] = 1 if len(b85encode(s5, True)) > len(b85encode(s5)) else 0;
    }

    def _loose_na(r: dict[str, any]) {
        r["ws64"] = 1 if b64decode(b"aGVs\nbG8=") == b"hello" else 0;
        r["junk64"] = 1 if b64decode(b"Zm9%vYg==") == b"foob" else 0;
        r["tail64"] = 1 if b64decode(b"Zm8=x") == b"fo1" else 0;
        r["cat64"] = _digest_na(b64decode(b"Zg==Zg=="));
        r["part64"] = 1 if b64decode(b"Zm==") == b"f" else 0;
        r["u64_plus"] = _digest_na(urlsafe_b64decode(b"+/A="));
        r["u64_mixed"] = _digest_na(urlsafe_b64decode(b"-_+/AA=="));
        r["u64_ws"] = 1 if urlsafe_b64decode(b"aGVs\nbG8=") == b"hello" else 0;
    }

    def _validate_na(r: dict[str, any]) {
        r["v64_ok"] = 1 if b64decode(b"Zm9vYmFy", b"-_", True) == b"foobar" else 0;
        r["v64_alt"] = _digest_na(b64decode(b"+/A=", b"-_", True));
        r["m01_zero"] = 1 if b32decode(b"MZXW0===", False, b"L") == b"fog" else 0;
        r["m01_one"] = 1 if b32decode(b"MZXW1===", False, b"L") == b"foe" else 0;
        r["m01_i"] = 1 if b32decode(b"MZXW1===", False, b"I") == b"fod" else 0;
        r["m01_cf"] = 1 if b32decode(b"mzxw1===", True, b"L") == b"foe" else 0;
    }

    # Error paths whose CPython message embeds a computed number
    # (err64_one, err85_char, err85_over) are pinned as raise-flags only:
    # the na runtime does not yet keep a heap-built (concatenated) exception
    # message alive reliably across unwinding, so str(e) for those is
    # luck-dependent. Static messages are compared verbatim.
    def _err64_na(r: dict[str, any]) {
        r["err64_pad"] = "?";
        try {
            b64decode(b"Zm8");
        } except ValueError as e {
            r["err64_pad"] = str(e);
        }
        r["err64_one"] = "?";
        try {
            b64decode(b"Zm888");
        } except ValueError {
            r["err64_one"] = "raised";
        }
        r["err64_mid"] = "?";
        try {
            b64decode(b"Zm8=Zm8=");
        } except ValueError as e {
            r["err64_mid"] = str(e);
        }
        r["errv64_junk"] = "?";
        try {
            b64decode(b"aGVs\nbG8=", b"-_", True);
        } except ValueError as e {
            r["errv64_junk"] = str(e);
        }
        r["errv64_lead"] = "?";
        try {
            b64decode(b"=Zm9v", b"-_", True);
        } except ValueError as e {
            r["errv64_lead"] = str(e);
        }
        r["errv64_data"] = "?";
        try {
            b64decode(b"Zm8=Zm8=", b"-_", True);
        } except ValueError as e {
            r["errv64_data"] = str(e);
        }
        r["errv64_pad"] = "?";
        try {
            b64decode(b"Zm9v=", b"-_", True);
        } except ValueError as e {
            r["errv64_pad"] = str(e);
        }
        r["errv64_disc"] = "?";
        try {
            b64decode(b"Zm=8", b"-_", True);
        } except ValueError as e {
            r["errv64_disc"] = str(e);
        }
    }

    def _err_rest_na(r: dict[str, any]) {
        r["err16_digit"] = "?";
        try {
            b16decode(b"6G");
        } except ValueError as e {
            r["err16_digit"] = str(e);
        }
        r["err16_lower"] = "?";
        try {
            b16decode(b"666f");
        } except ValueError as e {
            r["err16_lower"] = str(e);
        }
        r["err16_odd"] = "?";
        try {
            b16decode(b"666");
        } except ValueError as e {
            r["err16_odd"] = str(e);
        }
        r["err32_digit"] = "?";
        try {
            b32decode(b"M!XW6===");
        } except ValueError as e {
            r["err32_digit"] = str(e);
        }
        r["err32_len"] = "?";
        try {
            b32decode(b"MZXW6");
        } except ValueError as e {
            r["err32_len"] = str(e);
        }
        r["err32_pad2"] = "?";
        try {
            b32decode(b"MZXW6Y==");
        } except ValueError as e {
            r["err32_pad2"] = str(e);
        }
        r["err85_char"] = "?";
        try {
            b85decode(b"ab c");
        } except ValueError {
            r["err85_char"] = "raised";
        }
        r["err85_over"] = "?";
        try {
            b85decode(b"~~~~");
        } except ValueError {
            r["err85_over"] = "raised";
        }
    }

    def base64_na() -> dict[str, any] {
        r: dict[str, any] = {};
        _enc_core_na(r);
        _full_range_na(r);
        _pad_small_na(r);
        _pad_bounds_na(r);
        _empty_na(r);
        _alt_std_na(r);
        _loose_na(r);
        _validate_na(r);
        _err64_na(r);
        _err_rest_na(r);
        return r;
    }
}
