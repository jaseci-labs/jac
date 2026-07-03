"""Bundled native ``gzip`` cross-backend equivalence fixture (#6978 Phase 2).

The SAME ``import from gzip { compress, decompress }`` binds CPython's ``gzip``
on the sv (Python) backend and the bundled ``na_stdlib/gzip.na.jac`` Mechanism-B
module -- a pure-Jac surface that frames the raw DEFLATE body of the existing
``zlib`` floor with the RFC 1952 gzip header/CRC-32/ISIZE wrapper (no new FFI) --
on the na (native LLVM) backend.

``mtime=0`` is pinned on both sides so the 10-byte header is deterministic and
whole streams compare byte-for-byte (poly digest + exact length + XFL byte, at
levels 0/1/6/9 and the default). ``decompress`` round-trips (including a
level-0 stored-block stream), concatenates multi-member input like CPython,
handles empty and header-flagged (FEXTRA/FNAME/FCOMMENT/FHCRC) input
identically, and the error paths agree -- bad magic, a truncated stream, a
bare header glued onto a trailer, a corrupt body, a bad CRC, a bad ISIZE, and
trailing garbage all raise on both backends (compared as flags: CPython raises
``gzip.BadGzipFile`` / ``EOFError`` / ``zlib.error`` where the native surface
raises ``ValueError``, and native exception messages are not compared across
the JIT boundary). The flagged inputs are hand-spliced the same way on both
backends from ``compress`` output; the FHCRC bytes are the real
``crc32(header) & 0xffff`` (0xab12 for this header), which neither backend
verifies. The digest helper is duplicated inside the ``na`` block because a
plain ``def`` is a Python symbol native code could only reach through the JIT
interop bridge. ES/JS opts out.
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
    comp0 = compress(data, 0, mtime=0);
    comp1 = compress(data, 1, mtime=0);
    comp6 = compress(data, 6, mtime=0);
    back = decompress(comp);
    back0 = decompress(comp0);
    empty_rt = decompress(compress(b"", mtime=0));
    empty_plain = decompress(b"");
    multi = decompress(comp + comp);
    small = compress(b"payload", mtime=0);
    mixed = decompress(compress(b"first", mtime=0) + compress(b"second", mtime=0));

    garbage_raises: int = 0;
    try {
        decompress(comp + b"garbage");
    } except Exception {
        garbage_raises = 1;
    }
    bad_magic_raises: int = 0;
    try {
        decompress(b"\x00\x00" + comp[2:]);
    } except Exception {
        bad_magic_raises = 1;
    }
    trunc_raises: int = 0;
    try {
        decompress(comp[0:5]);
    } except Exception {
        trunc_raises = 1;
    }
    bodyless_raises: int = 0;
    try {
        decompress(comp[0:10] + b"\x00" * 8);
    } except Exception {
        bodyless_raises = 1;
    }
    corrupt_raises: int = 0;
    try {
        decompress(comp[0:12] + b"\xff\xff\xff\xff" + comp[16:]);
    } except Exception {
        corrupt_raises = 1;
    }
    bad_crc_raises: int = 0;
    try {
        decompress(
            small[0:len(small) - 8] + b"\xde\xad\xbe\xef" + small[len(small) - 4:]
        );
    } except Exception {
        bad_crc_raises = 1;
    }
    bad_isize_raises: int = 0;
    try {
        decompress(small[0:len(small) - 4] + b"\xff\xff\xff\xff");
    } except Exception {
        bad_isize_raises = 1;
    }

    # Hand-spliced header flags over compress output (same splice, both backends).
    hdr = small[0:10];
    rest = small[10:];
    fname = hdr[0:3] + (hdr[3] | 8).to_bytes(1, "little") + hdr[4:10] + b"name.txt\x00" + rest;
    fextra = hdr[0:3] + (hdr[3] | 4).to_bytes(1, "little") + hdr[4:10] + b"\x04\x00abcd" + rest;
    fcomment = hdr[0:3] + (hdr[3] | 16).to_bytes(1, "little") + hdr[4:10] + b"a comment\x00" + rest;
    fhcrc = hdr[0:3] + (hdr[3] | 2).to_bytes(1, "little") + hdr[4:10] + b"\x12\xab" + rest;
    allflags = hdr[0:3] + (hdr[3] | 28).to_bytes(1, "little") + hdr[4:10] + b"\x04\x00abcd" + b"n\x00" + b"c\x00" + rest;

    return {
        "comp_digest": _digest(comp),
        "comp0_digest": _digest(comp0),
        "comp1_digest": _digest(comp1),
        "comp6_digest": _digest(comp6),
        "comp_len": len(comp),
        "comp0_len": len(comp0),
        "comp1_len": len(comp1),
        "comp6_len": len(comp6),
        "xfl_default": comp[8],
        "xfl_0": comp0[8],
        "xfl_1": comp1[8],
        "xfl_6": comp6[8],
        "magic_ok": 1 if comp[0] == 31 and comp[1] == 139 else 0,
        "comp_smaller": 1 if len(comp) < len(data) else 0,
        "roundtrip_ok": 1 if back == data else 0,
        "roundtrip_len": len(back),
        "back_digest": _digest(back),
        "roundtrip0_ok": 1 if back0 == data else 0,
        "empty_ok": 1 if empty_rt == b"" else 0,
        "empty_plain_ok": 1 if empty_plain == b"" else 0,
        "multi_ok": 1 if multi == data + data else 0,
        "multi_len": len(multi),
        "mixed_ok": 1 if mixed == b"firstsecond" else 0,
        "garbage_raises": garbage_raises,
        "bad_magic_raises": bad_magic_raises,
        "trunc_raises": trunc_raises,
        "bodyless_raises": bodyless_raises,
        "corrupt_raises": corrupt_raises,
        "bad_crc_raises": bad_crc_raises,
        "bad_isize_raises": bad_isize_raises,
        "fname_ok": 1 if decompress(fname) == b"payload" else 0,
        "fextra_ok": 1 if decompress(fextra) == b"payload" else 0,
        "fcomment_ok": 1 if decompress(fcomment) == b"payload" else 0,
        "fhcrc_ok": 1 if decompress(fhcrc) == b"payload" else 0,
        "allflags_ok": 1 if decompress(allflags) == b"payload" else 0,

    };
}


cl def gzip_cl() -> dict {
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

    def gzip_na() -> dict[str, any] {
        data = b"the quick brown fox jumps over the lazy dog. " * 40;
        comp = compress(data, mtime=0);
        comp0 = compress(data, 0, mtime=0);
        comp1 = compress(data, 1, mtime=0);
        comp6 = compress(data, 6, mtime=0);
        back = decompress(comp);
        back0 = decompress(comp0);
        empty_rt = decompress(compress(b"", mtime=0));
        empty_plain = decompress(b"");
        multi = decompress(comp + comp);
        small = compress(b"payload", mtime=0);
        mixed = decompress(compress(b"first", mtime=0) + compress(b"second", mtime=0));

        garbage_raises: int = 0;
        try {
            decompress(comp + b"garbage");
        } except Exception {
            garbage_raises = 1;
        }
        bad_magic_raises: int = 0;
        try {
            decompress(b"\x00\x00" + comp[2:]);
        } except Exception {
            bad_magic_raises = 1;
        }
        trunc_raises: int = 0;
        try {
            decompress(comp[0:5]);
        } except Exception {
            trunc_raises = 1;
        }
        bodyless_raises: int = 0;
        try {
            decompress(comp[0:10] + b"\x00" * 8);
        } except Exception {
            bodyless_raises = 1;
        }
        corrupt_raises: int = 0;
        try {
            decompress(comp[0:12] + b"\xff\xff\xff\xff" + comp[16:]);
        } except Exception {
            corrupt_raises = 1;
        }
        bad_crc_raises: int = 0;
        try {
            decompress(
                small[0:len(small) - 8] + b"\xde\xad\xbe\xef" + small[len(small) - 4:]
            );
        } except Exception {
            bad_crc_raises = 1;
        }
        bad_isize_raises: int = 0;
        try {
            decompress(small[0:len(small) - 4] + b"\xff\xff\xff\xff");
        } except Exception {
            bad_isize_raises = 1;
        }

        hdr = small[0:10];
        rest = small[10:];
        fname = hdr[0:3] + (hdr[3] | 8).to_bytes(1, "little") + hdr[4:10] + b"name.txt\x00" + rest;
        fextra = hdr[0:3] + (hdr[3] | 4).to_bytes(1, "little") + hdr[4:10] + b"\x04\x00abcd" + rest;
        fcomment = hdr[0:3] + (hdr[3] | 16).to_bytes(1, "little") + hdr[4:10] + b"a comment\x00" + rest;
        fhcrc = hdr[0:3] + (hdr[3] | 2).to_bytes(1, "little") + hdr[4:10] + b"\x12\xab" + rest;
        allflags = hdr[0:3] + (hdr[3] | 28).to_bytes(1, "little") + hdr[4:10] + b"\x04\x00abcd" + b"n\x00" + b"c\x00" + rest;

        return {
            "comp_digest": _digest_na(comp),
            "comp0_digest": _digest_na(comp0),
            "comp1_digest": _digest_na(comp1),
            "comp6_digest": _digest_na(comp6),
            "comp_len": len(comp),
            "comp0_len": len(comp0),
            "comp1_len": len(comp1),
            "comp6_len": len(comp6),
            "xfl_default": comp[8],
            "xfl_0": comp0[8],
            "xfl_1": comp1[8],
            "xfl_6": comp6[8],
            "magic_ok": 1 if comp[0] == 31 and comp[1] == 139 else 0,
            "comp_smaller": 1 if len(comp) < len(data) else 0,
            "roundtrip_ok": 1 if back == data else 0,
            "roundtrip_len": len(back),
            "back_digest": _digest_na(back),
            "roundtrip0_ok": 1 if back0 == data else 0,
            "empty_ok": 1 if empty_rt == b"" else 0,
            "empty_plain_ok": 1 if empty_plain == b"" else 0,
            "multi_ok": 1 if multi == data + data else 0,
            "multi_len": len(multi),
            "mixed_ok": 1 if mixed == b"firstsecond" else 0,
            "garbage_raises": garbage_raises,
            "bad_magic_raises": bad_magic_raises,
            "trunc_raises": trunc_raises,
            "bodyless_raises": bodyless_raises,
            "corrupt_raises": corrupt_raises,
            "bad_crc_raises": bad_crc_raises,
            "bad_isize_raises": bad_isize_raises,
            "fname_ok": 1 if decompress(fname) == b"payload" else 0,
            "fextra_ok": 1 if decompress(fextra) == b"payload" else 0,
            "fcomment_ok": 1 if decompress(fcomment) == b"payload" else 0,
            "fhcrc_ok": 1 if decompress(fhcrc) == b"payload" else 0,
            "allflags_ok": 1 if decompress(allflags) == b"payload" else 0,

        };
    }
}
