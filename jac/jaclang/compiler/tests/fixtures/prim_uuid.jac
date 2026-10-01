"""Bundled native `uuid` cross-backend equivalence fixture (#6978 Phase 1).

The SAME `import uuid` binds CPython's `uuid` on the sv (Python) backend and the
bundled `na_stdlib/uuid.jac` module -- a pure-Jac RFC 4122/9562 surface over
OpenSSL's `RAND_bytes` (the `_csprng_native.jac` floor) and the bundled
`hashlib` -- on the na (native LLVM) backend.

`uuid4` output is RANDOM, so those keys pin the deterministic *structure* of a
v4 UUID: `hex`/`str()` lengths, the `8-4-4-4-12` hyphen layout, the version
nibble, the RFC-4122 variant nibble, and that two draws differ. Everything else
is exact: parsing (hyphens, braces, and the `urn:uuid:` prefix), the six
`fields`, the derived `time`/`clock_seq`/`node` accessors, `bytes_le` byte
order, `variant`/`version` (including the `None` version of a non-RFC-4122
UUID), ordering, and the namespace digests for `uuid3` (MD5) and `uuid5`
(SHA-1). The 128-bit `.int` attribute has no native representation (ints are
i64) and is not pinned; the native accessor for the raw 16 bytes is
`to_bytes()` rather than the `.bytes` property, so each lane reads its own.
ES/JS opts out.
"""

import uuid;


def uuid_py -> dict[any, any] {
    u = uuid.uuid4();
    s = str(u);
    var = s[19];
    fixed = uuid.UUID("12345678-1234-5678-1234-567812345678");
    braced = uuid.UUID("{12345678-1234-5678-1234-567812345678}");
    urned = uuid.UUID("urn:uuid:12345678-1234-5678-1234-567812345678");
    flat = uuid.UUID("12345678123456781234567812345678");
    rfc = uuid.UUID("6ba7b810-9dad-11d1-80b4-00c04fd430c8");
    fields = fixed.fields;
    le = fixed.bytes_le;
    n3 = uuid.uuid3(uuid.NAMESPACE_DNS, "example.com");
    n5 = uuid.uuid5(uuid.NAMESPACE_DNS, "example.com");
    n5u = uuid.uuid5(uuid.NAMESPACE_URL, "example.com");
    bad = "";
    try {
        uuid.UUID("nope");
    } except Exception as e {
        bad = str(e);
    }
    return {
        "hex_len": len(u.hex),
        "str_len": len(s),
        "version": u.version,
        "dash8": 1 if s[8] == "-" else 0,
        "dash13": 1 if s[13] == "-" else 0,
        "dash18": 1 if s[18] == "-" else 0,
        "dash23": 1 if s[23] == "-" else 0,
        "ver4": 1 if s[14] == "4" else 0,
        "variant_ok": 1
            if (var == "8" or var == "9" or var == "a" or var == "b")
            else 0,
        "two_differ": 1 if uuid.uuid4().hex != uuid.uuid4().hex else 0,
        "fixed_str": str(fixed),
        "fixed_hex": fixed.hex,
        "fixed_urn": fixed.urn,
        "braced_same": 1 if braced == fixed else 0,
        "urned_same": 1 if urned == fixed else 0,
        "flat_same": 1 if flat == fixed else 0,
        "fixed_variant": fixed.variant,
        "fixed_version_is_none": 1 if fixed.version is None else 0,
        "rfc_variant": rfc.variant,
        "rfc_version": rfc.version,
        "rfc_node": rfc.node,
        "rfc_clock_seq": rfc.clock_seq,
        "rfc_time": rfc.time,
        "f0": fields[0],
        "f1": fields[1],
        "f2": fields[2],
        "f3": fields[3],
        "f4": fields[4],
        "f5": fields[5],
        "le0": le[0],
        "le1": le[1],
        "le2": le[2],
        "le3": le[3],
        "le8": le[8],
        "time_low": fixed.time_low,
        "time_mid": fixed.time_mid,
        "time_hi_version": fixed.time_hi_version,
        "csq_hi": fixed.clock_seq_hi_variant,
        "csq_lo": fixed.clock_seq_low,
        "uuid3_str": str(n3),
        "uuid3_version": n3.version,
        "uuid5_str": str(n5),
        "uuid5_version": n5.version,
        "uuid5_url_str": str(n5u),
        "nil_str": str(uuid.NIL),
        "max_str": str(uuid.MAX),
        "ns_dns": str(uuid.NAMESPACE_DNS),
        "ns_oid": str(uuid.NAMESPACE_OID),
        "ns_x500": str(uuid.NAMESPACE_X500),
        "lt": 1 if uuid.NIL < uuid.MAX else 0,
        "gt": 1 if uuid.MAX > uuid.NIL else 0,
        "bad": bad,

    };
}


def uuid_cl -> dict[any, any] {
    return {};
}


def uuid_na -> dict[str, any] {
    u = uuid.uuid4();
    s = str(u);
    var = s[19];
    fixed = uuid.UUID(hex="12345678-1234-5678-1234-567812345678");
    braced = uuid.UUID(hex="{12345678-1234-5678-1234-567812345678}");
    urned = uuid.UUID(hex="urn:uuid:12345678-1234-5678-1234-567812345678");
    flat = uuid.UUID(hex="12345678123456781234567812345678");
    rfc = uuid.UUID(hex="6ba7b810-9dad-11d1-80b4-00c04fd430c8");
    fields = fixed.fields;
    le = fixed.bytes_le;
    n3 = uuid.uuid3(uuid.NAMESPACE_DNS, "example.com");
    n5 = uuid.uuid5(uuid.NAMESPACE_DNS, "example.com");
    n5u = uuid.uuid5(uuid.NAMESPACE_URL, "example.com");
    bad = "";
    try {
        uuid.UUID(hex="nope");
    } except Exception as e {
        bad = str(e);
    }
    fixed_ver: int | None = fixed.version;
    uv: int = -1;
    uver: int | None = u.version;
    if uver is not None {
        uv = uver;
    }
    rv: int = -1;
    rver: int | None = rfc.version;
    if rver is not None {
        rv = rver;
    }
    v3: int = -1;
    v3o: int | None = n3.version;
    if v3o is not None {
        v3 = v3o;
    }
    v5: int = -1;
    v5o: int | None = n5.version;
    if v5o is not None {
        v5 = v5o;
    }
    return {
        "hex_len": len(u.hex),
        "str_len": len(s),
        "version": uv,
        "dash8": 1 if s[8] == "-" else 0,
        "dash13": 1 if s[13] == "-" else 0,
        "dash18": 1 if s[18] == "-" else 0,
        "dash23": 1 if s[23] == "-" else 0,
        "ver4": 1 if s[14] == "4" else 0,
        "variant_ok": 1
            if (var == "8" or var == "9" or var == "a" or var == "b")
            else 0,
        "two_differ": 1 if uuid.uuid4().hex != uuid.uuid4().hex else 0,
        "fixed_str": str(fixed),
        "fixed_hex": fixed.hex,
        "fixed_urn": fixed.urn,
        "braced_same": 1 if braced.__eq__(fixed) else 0,
        "urned_same": 1 if urned.__eq__(fixed) else 0,
        "flat_same": 1 if flat.__eq__(fixed) else 0,
        "fixed_variant": fixed.variant,
        "fixed_version_is_none": 1 if fixed_ver is None else 0,
        "rfc_variant": rfc.variant,
        "rfc_version": rv,
        "rfc_node": rfc.`node,
        "rfc_clock_seq": rfc.clock_seq,
        "rfc_time": rfc.time,
        "f0": fields[0],
        "f1": fields[1],
        "f2": fields[2],
        "f3": fields[3],
        "f4": fields[4],
        "f5": fields[5],
        "le0": le[0],
        "le1": le[1],
        "le2": le[2],
        "le3": le[3],
        "le8": le[8],
        "time_low": fixed.time_low,
        "time_mid": fixed.time_mid,
        "time_hi_version": fixed.time_hi_version,
        "csq_hi": fixed.clock_seq_hi_variant,
        "csq_lo": fixed.clock_seq_low,
        "uuid3_str": str(n3),
        "uuid3_version": v3,
        "uuid5_str": str(n5),
        "uuid5_version": v5,
        "uuid5_url_str": str(n5u),
        "nil_str": str(uuid.NIL),
        "max_str": str(uuid.MAX),
        "ns_dns": str(uuid.NAMESPACE_DNS),
        "ns_oid": str(uuid.NAMESPACE_OID),
        "ns_x500": str(uuid.NAMESPACE_X500),
        "lt": 1 if uuid.NIL.__lt__(uuid.MAX) else 0,
        "gt": 1 if uuid.MAX.__gt__(uuid.NIL) else 0,
        "bad": bad,

    };
}
