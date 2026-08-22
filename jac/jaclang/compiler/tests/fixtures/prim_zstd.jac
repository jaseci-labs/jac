"""Bundled native ``compression.zstd`` cross-backend equivalence fixture.

The SAME ``import from compression.zstd { ... }`` binds CPython's real
``compression.zstd`` (zstd 1.5.7) on the sv (Python) backend and the bundled
``na_stdlib/compression/zstd.jac`` Mechanism-F surface -- a pure-Jac layer over
the ``libzstd`` FFI floor (``_zstd_native.jac``) -- on the na (native LLVM)
backend. ``io.BytesIO`` binds CPython's ``io`` on sv and the bundled
``na_stdlib/io.jac`` on na.

The fixture round-trips ``compress`` -> ``decompress`` at several levels, decodes
a stream of TWO concatenated frames (as the single-binary launcher payload is)
both one-shot and incrementally through ``ZstdDecompressor``, and streams the
same two-frame payload through ``ZstdFile(BytesIO(...)).read(chunk)``. Outputs
are pinned as lengths, a poly digest of decompressed bytes, and the incremental
decompressor's ``eof``/``needs_input``/``unused_data`` flags -- all deterministic
and byte-identical across backends. The digest helper is duplicated inside the
``na`` variant because a plain ``def`` called from native code must itself be
native. ES/JS opts out (no zstd floor)."""

import from io { BytesIO }
import from compression.zstd {
    compress,
    decompress,
    ZstdDecompressor,
    ZstdFile,
    get_frame_info
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


def _unopt(v: (int | None)) -> int {
    if v is None {
        return -1;
    }
    return v;
}


def zstd_py() -> dict {
    data = b"the quick brown fox jumps over the lazy dog. " * 400;
    c3 = compress(data, 3);
    c1 = compress(data, 1);
    c9 = compress(data, 9);
    c19 = compress(data, 19);
    rt3 = decompress(c3);
    rt19 = decompress(c19);

    a = b"first frame payload " * 100;
    b = b"second frame payload " * 100;
    two = compress(a, 19) + compress(b, 19);
    two_out = decompress(two);

    dec = ZstdDecompressor();
    part1 = dec.decompress(two, 500);
    eof1 = 1 if dec.eof else 0;
    needs1 = 1 if dec.needs_input else 0;
    part2 = dec.decompress(b"");
    eof2 = 1 if dec.eof else 0;
    unused2 = len(dec.unused_data);
    total_inc = len(part1) + len(part2);

    zf = ZstdFile(BytesIO(two));
    chunks_total = 0;
    stream_digest_src = b"";
    chunk = zf.read(7);
    while len(chunk) > 0 {
        chunks_total += len(chunk);
        stream_digest_src = stream_digest_src + chunk;
        chunk = zf.read(7);
    }
    zf.close();

    info = get_frame_info(c3);

    empty_rt = decompress(compress(b"", 3));

    return {
        "rt3_ok": 1 if rt3 == data else 0,
        "rt19_ok": 1 if rt19 == data else 0,
        "rt3_digest": _digest(rt3),
        "c1_len": len(c1),
        "c3_len": len(c3),
        "c9_len": len(c9),
        "c19_len": len(c19),
        "c3_smaller": 1 if len(c3) < len(data) else 0,
        "two_ok": 1 if two_out == a + b else 0,
        "two_len": len(two_out),
        "two_digest": _digest(two_out),
        "inc_ok": 1 if total_inc == len(a) else 0,
        "inc_total": total_inc,
        "eof1": eof1,
        "needs1": needs1,
        "eof2": eof2,
        "unused2": unused2,
        "stream_total": chunks_total,
        "stream_ok": 1 if stream_digest_src == a + b else 0,
        "stream_digest": _digest(stream_digest_src),
        "frame_size": _unopt(info.decompressed_size),
        "empty_ok": 1 if empty_rt == b"" else 0
    };
}


def zstd_cl() -> dict {
    return {};
}


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


def zstd_na() -> dict[str, any] {
    data = b"the quick brown fox jumps over the lazy dog. " * 400;
    c3 = compress(data, 3);
    c1 = compress(data, 1);
    c9 = compress(data, 9);
    c19 = compress(data, 19);
    rt3 = decompress(c3);
    rt19 = decompress(c19);

    a = b"first frame payload " * 100;
    b = b"second frame payload " * 100;
    two = compress(a, 19) + compress(b, 19);
    two_out = decompress(two);

    dec = ZstdDecompressor();
    part1 = dec.decompress(two, 500);
    eof1 = 1 if dec.eof else 0;
    needs1 = 1 if dec.needs_input else 0;
    part2 = dec.decompress(b"");
    eof2 = 1 if dec.eof else 0;
    unused2 = len(dec.unused_data);
    total_inc = len(part1) + len(part2);

    zf = ZstdFile(BytesIO(two));
    chunks_total = 0;
    stream_digest_src = b"";
    chunk = zf.read(7);
    while len(chunk) > 0 {
        chunks_total += len(chunk);
        stream_digest_src = stream_digest_src + chunk;
        chunk = zf.read(7);
    }
    zf.close();

    info = get_frame_info(c3);

    empty_rt = decompress(compress(b"", 3));

    out: dict[str, any] = {
        "rt3_ok": 1 if rt3 == data else 0,
        "rt19_ok": 1 if rt19 == data else 0,
        "rt3_digest": _digest_na(rt3),
        "c1_len": len(c1),
        "c3_len": len(c3),
        "c9_len": len(c9),
        "c19_len": len(c19),
        "c3_smaller": 1 if len(c3) < len(data) else 0,
        "two_ok": 1 if two_out == a + b else 0,
        "two_len": len(two_out),
        "two_digest": _digest_na(two_out),
        "inc_ok": 1 if total_inc == len(a) else 0,
        "inc_total": total_inc,
        "eof1": eof1,
        "needs1": needs1,
        "eof2": eof2,
        "unused2": unused2,
        "stream_total": chunks_total,
        "stream_ok": 1 if stream_digest_src == a + b else 0,
        "stream_digest": _digest_na(stream_digest_src),
        "frame_size": _unopt(info.decompressed_size),
        "empty_ok": 1 if empty_rt == b"" else 0
    };
    return out;
}
