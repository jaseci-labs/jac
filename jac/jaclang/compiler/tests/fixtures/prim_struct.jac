"""Native ``struct`` intercept cross-backend equivalence fixture.

The SAME ``import struct`` binds CPython's ``struct`` module on the sv
(Python) backend and the Mechanism-A compiler intercept
(``na_ir_gen_pass.impl/struct.impl.jac``) on the na (native LLVM) backend.
This fixture pins the two congruent across the full implemented format
surface: ``x b B h H i I l L q Q f d ? c s p e P`` with ``< > = ! @``
prefixes.

Packed results are compared via ``_digest`` of the packed ``bytes`` -- raw
``bytes`` cannot be marshalled across the sv/na boundary. Unpacked tuples are
destructured into scalar dict entries.

Known divergences NOT exercised here:
  - ``@``-mode alignment padding (the na intercept treats ``@`` as
    little-endian with no inter-field padding),
  - ``P`` in non-native modes (CPython restricts ``P`` to ``@``; the na
    intercept accepts it everywhere),
  - ``n``/``N`` native-size codes.

ES/JS opts out (``struct_cl`` returns an empty dict).
"""

import struct;


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


def struct_py -> dict[any, any] {
    r: dict[str, any] = {
        "cs_i": struct.calcsize("<i"),
        "cs_mix": struct.calcsize(">h?4s"),
        "cs_all": struct.calcsize("<bBhHiIlLqQ"),
        "cs_half": struct.calcsize("<e"),
        "cs_p": struct.calcsize("@P"),
        "cs_pascal": struct.calcsize(">5p"),
        "pk_i": _digest(struct.pack("<i", -12345)),
        "pk_big": _digest(struct.pack(">q", 123456789012345)),
        "pk_unsigned": _digest(struct.pack("<I", 4000000000)),
        "pk_f": _digest(struct.pack("<f", 1.5)),
        "pk_d": _digest(struct.pack(">d", -2.25)),
        "pk_e": _digest(struct.pack("<e", 1.5)),
        "pk_e_neg": _digest(struct.pack(">e", -0.0)),
        "pk_bool": _digest(struct.pack("<?", True)),
        "pk_bool_f": _digest(struct.pack("<?", False)),
        "pk_c": _digest(struct.pack("<c", b"Z")),
        "pk_s": _digest(struct.pack("<4s", b"ab")),
        "pk_p": _digest(struct.pack("<5p", b"hey")),
        "pk_pad": _digest(struct.pack("<bxh", 1, 2)),
        "pk_mix": _digest(struct.pack(">i?2s", 7, True, b"xy")),
        "pk_P": _digest(struct.pack("@P", 12345))
    };
    (vi, ) = struct.unpack("<i", struct.pack("<i", -12345));
    r["un_i"] = vi;
    (vb, vc, vs, vp) = struct.unpack(
        "<?c3s3p", struct.pack("<?c3s3p", True, b"x", b"ab", b"yz")
    );
    r["un_bool"] = 1 if vb else 0;
    r["un_c_digest"] = _digest(vc);
    r["un_s_digest"] = _digest(vs);
    r["un_p_digest"] = _digest(vp);
    (ve, ) = struct.unpack("<e", struct.pack("<e", 1.5));
    r["un_e"] = ve;
    (ve2, ) = struct.unpack("<e", b"\x00\x3e");
    r["un_e_lit"] = ve2;
    (vf, ) = struct.unpack(">f", struct.pack(">f", 0.5));
    r["un_f"] = vf;
    (vP, ) = struct.unpack("@P", struct.pack("@P", 12345));
    r["un_P"] = vP;
    buf = bytearray(16);
    struct.pack_into("<i", buf, 4, -777);
    struct.pack_into("<e", buf, 8, 2.5);
    struct.pack_into("<4s", buf, 10, b"qr");
    (ufi, ) = struct.unpack_from("<i", bytes(buf[4:8]));
    (ufe, ) = struct.unpack_from("<e", bytes(buf[8:10]));
    r["pi_i"] = ufi;
    r["pi_e"] = ufe;
    (ufs, ) = struct.unpack_from("<4s", bytes(buf[10:14]));
    r["pi_s_digest"] = _digest(ufs);
    (ufrom, ) = struct.unpack_from("<h", struct.pack("<xh", 42), 1);
    r["uf_h"] = ufrom;
    try {
        struct.unpack("<i", b"xx");
        r["err_short"] = "noraise";
    } except Exception as e {
        r["err_short"] = "raised";
    }
    return r;
}


def struct_cl -> dict[any, any] {
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


def _sizes_na(r: dict[str, any]) {
    r["cs_i"] = struct.calcsize("<i");
    r["cs_mix"] = struct.calcsize(">h?4s");
    r["cs_all"] = struct.calcsize("<bBhHiIlLqQ");
    r["cs_half"] = struct.calcsize("<e");
    r["cs_p"] = struct.calcsize("@P");
    r["cs_pascal"] = struct.calcsize(">5p");
}


def _pack_na(r: dict[str, any]) {
    r["pk_i"] = _digest_na(struct.pack("<i", -12345));
    r["pk_big"] = _digest_na(struct.pack(">q", 123456789012345));
    r["pk_unsigned"] = _digest_na(struct.pack("<I", 4000000000));
    r["pk_f"] = _digest_na(struct.pack("<f", 1.5));
    r["pk_d"] = _digest_na(struct.pack(">d", -2.25));
    r["pk_e"] = _digest_na(struct.pack("<e", 1.5));
    r["pk_e_neg"] = _digest_na(struct.pack(">e", -0.0));
    r["pk_bool"] = _digest_na(struct.pack("<?", True));
    r["pk_bool_f"] = _digest_na(struct.pack("<?", False));
    r["pk_c"] = _digest_na(struct.pack("<c", b"Z"));
    r["pk_s"] = _digest_na(struct.pack("<4s", b"ab"));
    r["pk_p"] = _digest_na(struct.pack("<5p", b"hey"));
    r["pk_pad"] = _digest_na(struct.pack("<bxh", 1, 2));
    r["pk_mix"] = _digest_na(struct.pack(">i?2s", 7, True, b"xy"));
    r["pk_P"] = _digest_na(struct.pack("@P", 12345));
}


def _unpack_na(r: dict[str, any]) {
    (vi, ) = struct.unpack("<i", struct.pack("<i", -12345));
    r["un_i"] = vi;
    (vb, vc, vs, vp) = struct.unpack(
        "<?c3s3p", struct.pack("<?c3s3p", True, b"x", b"ab", b"yz")
    );
    r["un_bool"] = 1 if vb else 0;
    r["un_c_digest"] = _digest_na(vc);
    r["un_s_digest"] = _digest_na(vs);
    r["un_p_digest"] = _digest_na(vp);
    (ve, ) = struct.unpack("<e", struct.pack("<e", 1.5));
    r["un_e"] = ve;
    (ve2, ) = struct.unpack("<e", b"\x00\x3e");
    r["un_e_lit"] = ve2;
    (vf, ) = struct.unpack(">f", struct.pack(">f", 0.5));
    r["un_f"] = vf;
    (vP, ) = struct.unpack("@P", struct.pack("@P", 12345));
    r["un_P"] = vP;
}


def _into_na(r: dict[str, any]) {
    buf = bytearray(16);
    struct.pack_into("<i", buf, 4, -777);
    struct.pack_into("<e", buf, 8, 2.5);
    struct.pack_into("<4s", buf, 10, b"qr");
    (ufi, ) = struct.unpack_from("<i", bytes(buf[4:8]));
    (ufe, ) = struct.unpack_from("<e", bytes(buf[8:10]));
    r["pi_i"] = ufi;
    r["pi_e"] = ufe;
    (ufs, ) = struct.unpack_from("<4s", bytes(buf[10:14]));
    r["pi_s_digest"] = _digest_na(ufs);
    (ufrom, ) = struct.unpack_from("<h", struct.pack("<xh", 42), 1);
    r["uf_h"] = ufrom;
}


def _err_na(r: dict[str, any]) {
    try {
        struct.unpack("<i", b"xx");
        r["err_short"] = "noraise";
    } except Exception as e {
        r["err_short"] = "raised";
    }
}


def struct_na -> dict[str, any] {
    r: dict[str, any] = {};
    _sizes_na(r);
    _pack_na(r);
    _unpack_na(r);
    _into_na(r);
    _err_na(r);
    return r;
}
