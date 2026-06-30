"""Bundled native ``gzip`` cross-backend equivalence fixture (#6978 Phase 2).

The SAME ``import from gzip { compress, decompress }`` binds CPython's ``gzip``
on the sv (Python) backend and the bundled ``na_stdlib/gzip.na.jac`` Mechanism-B
module -- a pure-Jac surface that frames the raw DEFLATE body of the existing
``zlib`` floor with the RFC 1952 gzip header/CRC-32/ISIZE wrapper (no new FFI) --
on the na (native LLVM) backend.

``mtime=0`` is pinned on both sides so the 10-byte header is deterministic and
the whole stream is compared byte-for-byte (poly digest + exact length, at the
default and an explicit level). ``decompress`` round-trips, and empty input is
handled identically. ES/JS opts out.
"""

import from gzip { compress, decompress }


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


def gzip_py() -> dict {
    data = b"the quick brown fox jumps over the lazy dog. " * 40;
    comp = compress(data, mtime=0);
    comp1 = compress(data, 1, mtime=0);
    back = decompress(comp);
    empty_rt = decompress(compress(b"", mtime=0));
    return {
        "comp_digest": _digest(comp),
        "comp1_digest": _digest(comp1),
        "comp_len": len(comp),
        "magic_ok": 1 if comp[0] == 31 and comp[1] == 139 else 0,
        "comp_smaller": 1 if len(comp) < len(data) else 0,
        "roundtrip_ok": 1 if back == data else 0,
        "roundtrip_len": len(back),
        "back_digest": _digest(back),
        "empty_ok": 1 if empty_rt == b"" else 0,
    };
}


cl def gzip_cl() -> dict {
    return {};
}


na {
    def gzip_na() -> dict[str, any] {
        data = b"the quick brown fox jumps over the lazy dog. " * 40;
        comp = compress(data, mtime=0);
        comp1 = compress(data, 1, mtime=0);
        back = decompress(comp);
        empty_rt = decompress(compress(b"", mtime=0));
        return {
            "comp_digest": _digest(comp),
            "comp1_digest": _digest(comp1),
            "comp_len": len(comp),
            "magic_ok": 1 if comp[0] == 31 and comp[1] == 139 else 0,
            "comp_smaller": 1 if len(comp) < len(data) else 0,
            "roundtrip_ok": 1 if back == data else 0,
            "roundtrip_len": len(back),
            "back_digest": _digest(back),
            "empty_ok": 1 if empty_rt == b"" else 0,
        };
    }
}
