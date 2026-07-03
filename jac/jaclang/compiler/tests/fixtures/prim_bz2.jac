"""Bundled native ``bz2`` cross-backend equivalence fixture (#6978 Phase 2).

The SAME ``import from bz2 { compress, decompress }`` binds CPython's ``bz2`` on
the sv (Python) backend and the bundled ``na_stdlib/bz2.na.jac`` Mechanism-F
module -- a thin pure-Jac surface over ``libbz2`` (the FFI floor) -- on the na
(native LLVM) backend. Under this in-process JIT harness the floor dlopens the
system ``libbz2``; the bundled ``libbz2.a`` archive (staged by the generic
name-derived floor mechanics of #6990) is only consumed by the AOT
``nacompile`` pathway and is NOT linked by this fixture.

The fixture pins the two implementations congruent on the one-shot bzip2
surface: ``compress`` produces byte-identical output (poly digest + exact
length, at the default and an explicit level), ``decompress`` round-trips,
empty input is handled identically, and the error paths agree -- corrupt
input, a truncated stream, and out-of-range compresslevels all raise on both
backends (compared as flags: CPython raises OSError on corrupt data where the
native surface raises ValueError, and native exception messages are not
compared across the JIT boundary). The digest helper is duplicated inside the
``na`` block because a plain ``def`` is a Python symbol native code could only
reach through the JIT interop bridge. ES/JS opts out.
"""

import from bz2 { compress, decompress }


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


def bz2_py() -> dict {
    data = b"the quick brown fox jumps over the lazy dog. " * 40;
    comp = compress(data);
    comp6 = compress(data, 6);
    back = decompress(comp);
    empty_rt = decompress(compress(b""));
    empty_plain = decompress(b"");
    garbage_raises: int = 0;
    try {
        decompress(b"garbage");
    } except Exception {
        garbage_raises = 1;
    }
    trunc_raises: int = 0;
    try {
        decompress(comp[0:10]);
    } except Exception {
        trunc_raises = 1;
    }
    level0_raises: int = 0;
    try {
        compress(data, 0);
    } except Exception {
        level0_raises = 1;
    }
    level10_raises: int = 0;
    try {
        compress(data, 10);
    } except Exception {
        level10_raises = 1;
    }
    return {
        "comp_digest": _digest(comp),
        "comp6_digest": _digest(comp6),
        "comp_len": len(comp),
        "comp6_len": len(comp6),
        "comp_smaller": 1 if len(comp) < len(data) else 0,
        "roundtrip_ok": 1 if back == data else 0,
        "roundtrip_len": len(back),
        "back_digest": _digest(back),
        "empty_ok": 1 if empty_rt == b"" else 0,
        "empty_plain_ok": 1 if empty_plain == b"" else 0,
        "garbage_raises": garbage_raises,
        "trunc_raises": trunc_raises,
        "level0_raises": level0_raises,
        "level10_raises": level10_raises,

    };
}


cl def bz2_cl() -> dict {
    return {};
}


na {
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

    def bz2_na() -> dict[str, any] {
        data = b"the quick brown fox jumps over the lazy dog. " * 40;
        comp = compress(data);
        comp6 = compress(data, 6);
        back = decompress(comp);
        empty_rt = decompress(compress(b""));
        empty_plain = decompress(b"");
        garbage_raises: int = 0;
        try {
            decompress(b"garbage");
        } except Exception {
            garbage_raises = 1;
        }
        trunc_raises: int = 0;
        try {
            decompress(comp[0:10]);
        } except Exception {
            trunc_raises = 1;
        }
        level0_raises: int = 0;
        try {
            compress(data, 0);
        } except Exception {
            level0_raises = 1;
        }
        level10_raises: int = 0;
        try {
            compress(data, 10);
        } except Exception {
            level10_raises = 1;
        }
        return {
            "comp_digest": _digest_na(comp),
            "comp6_digest": _digest_na(comp6),
            "comp_len": len(comp),
            "comp6_len": len(comp6),
            "comp_smaller": 1 if len(comp) < len(data) else 0,
            "roundtrip_ok": 1 if back == data else 0,
            "roundtrip_len": len(back),
            "back_digest": _digest_na(back),
            "empty_ok": 1 if empty_rt == b"" else 0,
            "empty_plain_ok": 1 if empty_plain == b"" else 0,
            "garbage_raises": garbage_raises,
            "trunc_raises": trunc_raises,
            "level0_raises": level0_raises,
            "level10_raises": level10_raises,

        };
    }
}
