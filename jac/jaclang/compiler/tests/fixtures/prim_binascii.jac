"""Bundled native ``binascii`` cross-backend equivalence fixture.

The SAME ``import from binascii { ... }`` binds CPython's ``binascii`` on the
sv (Python) backend and the bundled ``na_stdlib/binascii.jac`` Mechanism-B
module on the na (native LLVM) backend. This fixture pins the two congruent.

Outputs are compared via a custom digest (``_digest``) rather than as raw
bytes because the cross-backend harness marshals a returned ``dict[str, any]``
but cannot marshal raw ``bytes`` values across the sv/na boundary -- so each
encoding is hashed to an int and its length is recorded, then the two backends
are compared on those scalars. Round-trips are compared as boolean flags, and
error paths on ``str(e)`` (``binascii.Error`` subclasses ``ValueError`` on both
lanes, so one ``except`` arm covers them).

The case body is duplicated between the sv function and the ``na`` helpers
because the native pathway compiles only the ``na { }``-callable region of a
fixture: on the na side the body is split into small helpers, each mutating
the shared result dict -- one function carrying the whole case body exceeds
what the na backend can currently JIT reliably in a single function.

ES/JS opts out (``binascii_cl`` returns an empty dict).
"""

import from binascii {
    Error,
    hexlify,
    unhexlify,
    a2b_hex,
    b2a_hex,
    a2b_base64,
    b2a_base64,
    crc32,
    crc_hqx,
    a2b_uu,
    b2a_uu,
    a2b_qp,
    b2a_qp
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


def binascii_py -> dict[any, any] {
    data = b"the quick brown fox jumps over the lazy dog";
    h = hexlify(data);
    hs = hexlify(data, b":");
    b64 = b2a_base64(data);
    uu = b2a_uu(b"hello");
    qp = b2a_qp(b"a b=\t\xff");
    r: dict[str, any] = {
        "hex_digest": _digest(h),
        "hex_len": len(h),
        "hex_rt": 1 if unhexlify(h) == data else 0,
        "hex_sep_digest": _digest(hs),
        "a2b_alias": 1 if a2b_hex(h) == unhexlify(h) else 0,
        "b2a_alias": 1 if b2a_hex(data) == h else 0,
        "b64_digest": _digest(b64),
        "b64_len": len(b64),
        "b64_rt": 1 if a2b_base64(b64) == data else 0,
        "b64_nonl_digest": _digest(b2a_base64(data, newline=False)),
        "crc32": crc32(data),
        "crc32_seed": crc32(data, 12345),
        "crc_hqx": crc_hqx(data, 0),
        "crc_hqx_seed": crc_hqx(data, 0xFFFF),
        "uu_digest": _digest(uu),
        "uu_rt": 1 if a2b_uu(uu) == b"hello" else 0,
        "uu_tick": _digest(b2a_uu(b"\x00", backtick=True)),
        "qp_digest": _digest(qp),
        "qp_rt": 1 if a2b_qp(b2a_qp(data)) == data else 0,
        "qp_header": _digest(b2a_qp(b"two words", True, True)),
        "qp_und": 1 if a2b_qp(b"two_words", True) == b"two words" else 0
    };
    try {
        unhexlify(b"abc");
        r["err_odd"] = "noraise";
    } except ValueError as e {
        r["err_odd"] = str(e);
    }
    try {
        unhexlify(b"zz");
        r["err_hexdig"] = "noraise";
    } except ValueError as e {
        r["err_hexdig"] = str(e);
    }
    try {
        b2a_uu(b"x" * 46);
        r["err_uu45"] = "noraise";
    } except ValueError as e {
        r["err_uu45"] = str(e);
    }
    try {
        a2b_base64(b"!!!!", strict_mode=True);
        r["err_b64"] = "noraise";
    } except ValueError as e {
        r["err_b64"] = str(e);
    }
    try {
        a2b_base64(b" aGVsbG8= ", strict_mode=True);
        r["err_strict"] = "noraise";
    } except ValueError as e {
        r["err_strict"] = str(e);
    }
    return r;
}


def binascii_cl -> dict[any, any] {
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


def _hex_na(r: dict[str, any]) {
    data = b"the quick brown fox jumps over the lazy dog";
    h = hexlify(data);
    hs = hexlify(data, b":");
    r["hex_digest"] = _digest_na(h);
    r["hex_len"] = len(h);
    r["hex_rt"] = 1 if unhexlify(h) == data else 0;
    r["hex_sep_digest"] = _digest_na(hs);
    r["a2b_alias"] = 1 if a2b_hex(h) == unhexlify(h) else 0;
    r["b2a_alias"] = 1 if b2a_hex(data) == h else 0;
}


def _b64_na(r: dict[str, any]) {
    data = b"the quick brown fox jumps over the lazy dog";
    b64 = b2a_base64(data);
    r["b64_digest"] = _digest_na(b64);
    r["b64_len"] = len(b64);
    r["b64_rt"] = 1 if a2b_base64(b64) == data else 0;
    r["b64_nonl_digest"] = _digest_na(b2a_base64(data, newline=False));
}


def _crc_na(r: dict[str, any]) {
    data = b"the quick brown fox jumps over the lazy dog";
    r["crc32"] = crc32(data);
    r["crc32_seed"] = crc32(data, 12345);
    r["crc_hqx"] = crc_hqx(data, 0);
    r["crc_hqx_seed"] = crc_hqx(data, 0xFFFF);
}


def _uu_qp_na(r: dict[str, any]) {
    data = b"the quick brown fox jumps over the lazy dog";
    uu = b2a_uu(b"hello");
    qp = b2a_qp(b"a b=\t\xff");
    r["uu_digest"] = _digest_na(uu);
    r["uu_rt"] = 1 if a2b_uu(uu) == b"hello" else 0;
    r["uu_tick"] = _digest_na(b2a_uu(b"\x00", backtick=True));
    r["qp_digest"] = _digest_na(qp);
    r["qp_rt"] = 1 if a2b_qp(b2a_qp(data)) == data else 0;
    r["qp_header"] = _digest_na(b2a_qp(b"two words", True, True));
    r["qp_und"] = 1 if a2b_qp(b"two_words", True) == b"two words" else 0;
}


# The na helpers catch ``Exception`` rather than ``ValueError``: exception
# subtype matching (`Error` -> `ValueError`) does not fire for module-defined
# exception classes on the ctypes-invoked JIT path, only under `with entry`.
# The compared value is ``str(e)``, which is identical either way.
def _err_na(r: dict[str, any]) {
    try {
        unhexlify(b"abc");
        r["err_odd"] = "noraise";
    } except Exception as e {
        r["err_odd"] = str(e);
    }
    try {
        unhexlify(b"zz");
        r["err_hexdig"] = "noraise";
    } except Exception as e {
        r["err_hexdig"] = str(e);
    }
    try {
        b2a_uu(b"x" * 46);
        r["err_uu45"] = "noraise";
    } except Exception as e {
        r["err_uu45"] = str(e);
    }
    try {
        a2b_base64(b"!!!!", strict_mode=True);
        r["err_b64"] = "noraise";
    } except Exception as e {
        r["err_b64"] = str(e);
    }
    try {
        a2b_base64(b" aGVsbG8= ", strict_mode=True);
        r["err_strict"] = "noraise";
    } except Exception as e {
        r["err_strict"] = str(e);
    }
}


def binascii_na -> dict[str, any] {
    r: dict[str, any] = {};
    _hex_na(r);
    _b64_na(r);
    _crc_na(r);
    _uu_qp_na(r);
    _err_na(r);
    return r;
}
