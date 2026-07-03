"""Bundled native ``base64`` cross-backend equivalence fixture.

The SAME ``import from base64 { ... }`` binds CPython's ``base64`` on the sv
(Python) backend and the bundled ``na_stdlib/base64.na.jac`` Mechanism-B module
on the na (native LLVM) backend. This fixture pins the two congruent.

Outputs are compared via a custom FNV-1a digest (``_digest``) rather than as
raw bytes because the cross-backend harness marshals a returned
``dict[str, any]`` but cannot marshal raw ``bytes`` values across the sv/na
boundary -- so each encoding is hashed to an int and its length is recorded,
then the two backends are compared on those scalars. Round-trips (encode then
decode back to the original) are compared as boolean flags.

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


def _base64_cases() -> dict {
    data = b"the quick brown fox jumps over the lazy dog. " * 3;
    s1 = b"f";
    s2 = b"fo";
    s3 = b"foo";
    s4 = b"foob";
    s5 = b"fooba";
    sff = b"\xff\xff";

    e16 = b16encode(data);
    e32 = b32encode(data);
    e64 = b64encode(data);
    e64u = urlsafe_b64encode(data);
    e85 = b85encode(data);

    return {
        "e16_digest": _digest(e16),
        "e16_len": len(e16),
        "e32_digest": _digest(e32),
        "e32_len": len(e32),
        "e64_digest": _digest(e64),
        "e64_len": len(e64),
        "e64u_digest": _digest(e64u),
        "e85_digest": _digest(e85),
        "e85_len": len(e85),
        "rt16": 1 if b16decode(e16) == data else 0,
        "rt32": 1 if b32decode(e32) == data else 0,
        "rt64": 1 if b64decode(e64) == data else 0,
        "rt64u": 1 if urlsafe_b64decode(e64u) == data else 0,
        "rt85": 1 if b85decode(e85) == data else 0,
        "p1": _digest(b64encode(s1)),
        "p2": _digest(b64encode(s2)),
        "p3": _digest(b64encode(s3)),
        "p4": _digest(b32encode(s4)),
        "p5": _digest(b85encode(s5)),
        "rt_s1": 1 if b64decode(b64encode(s1)) == s1 else 0,
        "rt_s3": 1 if b64decode(b64encode(s3)) == s3 else 0,
        "rt_s5": 1 if b85decode(b85encode(s5)) == s5 else 0,
        "rt_s1_16": 1 if b16decode(b16encode(s1)) == s1 else 0,
        "empty64": 1 if b64encode(b"") == b"" else 0,
        "std_b64_rt": 1 if standard_b64decode(standard_b64encode(data)) == data else 0,
        "std_b64_eq": 1 if standard_b64encode(data) == b64encode(data) else 0,
        "alt_rt": 1 if b64decode(b64encode(sff, b"-_"), b"-_") == sff else 0,
        "alt_digest": _digest(b64encode(sff, b"-_")),
        "alt_ne_std": 1 if b64encode(sff, b"-_") != b64encode(sff) else 0,
        "alt_eq_urlsafe": 1 if b64encode(sff, b"-_") == urlsafe_b64encode(sff) else 0,
        "cf16": 1 if b16decode(e16.lower(), True) == data else 0,
        "cf32": 1 if b32decode(e32.lower(), True) == data else 0,
        "b85pad_digest": _digest(b85encode(s5, True)),
        "b85pad_eq_padded_input": 1
            if b85encode(s5, True) == b85encode(s5 + b"\x00\x00\x00")
            else 0,
        "b85pad_decode_padded": 1
            if b85decode(b85encode(s5, True)) == s5 + b"\x00\x00\x00"
            else 0,
        "b85pad_longer": 1 if len(b85encode(s5, True)) > len(b85encode(s5)) else 0,

    };
}


def base64_py() -> dict {
    return _base64_cases();
}


cl def base64_cl() -> dict {
    return {};
}


na {
    def base64_na() -> dict[str, any] {
        return _base64_cases();
    }
}
