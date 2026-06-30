"""Bundled native ``bz2`` cross-backend equivalence fixture (#6978 Phase 2).

The SAME ``import from bz2 { compress, decompress }`` binds CPython's ``bz2`` on
the sv (Python) backend and the bundled ``na_stdlib/bz2.na.jac`` Mechanism-F
module -- a thin pure-Jac surface over the system ``libbz2`` (the FFI floor) --
on the na (native LLVM) backend. This is also the first link of the bundled
``libbz2.a`` floor archive (the static-archive link smoke test for #6978
Phase 2).

The fixture pins the two implementations congruent on the one-shot bzip2
surface: ``compress`` produces byte-identical output (asserted through a poly
digest + exact length of the compressed stream, at default and explicit levels),
``decompress`` round-trips, and the empty input is handled identically. ES/JS
opts out.
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
    return {
        "comp_digest": _digest(comp),
        "comp6_digest": _digest(comp6),
        "comp_len": len(comp),
        "comp_smaller": 1 if len(comp) < len(data) else 0,
        "roundtrip_ok": 1 if back == data else 0,
        "roundtrip_len": len(back),
        "back_digest": _digest(back),
        "empty_ok": 1 if empty_rt == b"" else 0,

    };
}


cl def bz2_cl() -> dict {
    return {};
}


na {
    def bz2_na() -> dict[str, any] {
        data = b"the quick brown fox jumps over the lazy dog. " * 40;
        comp = compress(data);
        comp6 = compress(data, 6);
        back = decompress(comp);
        empty_rt = decompress(compress(b""));
        return {
            "comp_digest": _digest(comp),
            "comp6_digest": _digest(comp6),
            "comp_len": len(comp),
            "comp_smaller": 1 if len(comp) < len(data) else 0,
            "roundtrip_ok": 1 if back == data else 0,
            "roundtrip_len": len(back),
            "back_digest": _digest(back),
            "empty_ok": 1 if empty_rt == b"" else 0,

        };
    }
}
