"""Bz2: compare native Python-object calls with the Python backend.

Both pathways use the bundled interpreter standard library. Native execution
must preserve its values, exceptions, signatures, and default arguments.
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


def bz2_py() -> dict[any, any] {
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


def bz2_cl() -> dict[any, any] {
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
