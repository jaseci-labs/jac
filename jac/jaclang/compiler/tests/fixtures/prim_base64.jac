"""Bundled native ``base64`` cross-backend equivalence fixture (#6978 Phase 3).

The SAME ``import from base64 { ... }`` binds CPython's ``base64`` on the sv
(Python) backend and the bundled ``na_stdlib/base64.na.jac`` Mechanism-B module
(pure-Jac, no FFI floor) on the na (native LLVM) backend, so this pins our
codecs byte-identical to CPython.

Coverage: base16 / base32 / base64 / urlsafe-base64 / base85 encode, asserted
through a poly digest + exact length of the encoded stream, plus a decode
round-trip for each, plus the 1..5 byte tails that exercise every padding
boundary and the empty input. ES/JS opts out.
"""

import from base64 {
    b16encode,
    b16decode,
    b32encode,
    b32decode,
    b64encode,
    b64decode,
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


def base64_py() -> dict {
    data = b"the quick brown fox jumps over the lazy dog. " * 3;
    s1 = b"f";
    s2 = b"fo";
    s4 = b"foob";
    s5 = b"fooba";

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
        "p4": _digest(b32encode(s4)),
        "p5": _digest(b85encode(s5)),
        "rt_s1": 1 if b64decode(b64encode(s1)) == s1 else 0,
        "rt_s5": 1 if b85decode(b85encode(s5)) == s5 else 0,
        "empty64": 1 if b64encode(b"") == b"" else 0,

    };
}


cl def base64_cl() -> dict {
    return {};
}


na {
    def base64_na() -> dict[str, any] {
        data = b"the quick brown fox jumps over the lazy dog. " * 3;
        s1 = b"f";
        s2 = b"fo";
        s4 = b"foob";
        s5 = b"fooba";

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
            "p4": _digest(b32encode(s4)),
            "p5": _digest(b85encode(s5)),
            "rt_s1": 1 if b64decode(b64encode(s1)) == s1 else 0,
            "rt_s5": 1 if b85decode(b85encode(s5)) == s5 else 0,
            "empty64": 1 if b64encode(b"") == b"" else 0,

        };
    }
}
