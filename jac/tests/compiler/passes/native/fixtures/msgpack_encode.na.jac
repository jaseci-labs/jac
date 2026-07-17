import struct;

glob JV_NIL = 0,
     JV_BOOL = 1,
     JV_INT = 2,
     JV_UINT = 3,
     JV_FLOAT = 4,
     JV_STR = 5,
     JV_ARRAY = 8,
     JV_MAP = 9;


obj JacValue {
    has kind: int = 0;
    has i: int = 0;
    has s: str = "";
    has b: bool = False;
    has items: list[JacValue] = [];
    has entries: dict[str, JacValue] = {};
}


def jv_nil() -> JacValue {
    v = JacValue();
    v.kind = JV_NIL;
    return v;
}


def jv_bool(x: bool) -> JacValue {
    v = JacValue();
    v.kind = JV_BOOL;
    v.b = x;
    return v;
}


def jv_int(x: int) -> JacValue {
    v = JacValue();
    v.kind = JV_INT;
    v.i = x;
    return v;
}


def jv_uint(x: int) -> JacValue {
    v = JacValue();
    v.kind = JV_UINT;
    v.i = x;
    return v;
}


def jv_float_bits(bits: int) -> JacValue {
    v = JacValue();
    v.kind = JV_FLOAT;
    v.i = bits;
    return v;
}


def jv_str(x: str) -> JacValue {
    v = JacValue();
    v.kind = JV_STR;
    v.s = x;
    return v;
}


def jv_array(xs: list[JacValue]) -> JacValue {
    v = JacValue();
    v.kind = JV_ARRAY;
    v.items = xs;
    return v;
}


def jv_map(xs: dict[str, JacValue]) -> JacValue {
    v = JacValue();
    v.kind = JV_MAP;
    v.entries = xs;
    return v;
}


def _encode_str(s: str) -> bytes {
    sl: str = s;
    eb = sl.encode();
    el = len(eb);
    if el < 32 {
        return struct.pack(">B", 0xa0 + el) + eb;
    }
    if el < 256 {
        return struct.pack(">B", 0xd9) + struct.pack(">B", el) + eb;
    }
    if el < 65536 {
        return struct.pack(">B", 0xda) + struct.pack(">H", el) + eb;
    }
    return struct.pack(">B", 0xdb) + struct.pack(">I", el) + eb;
}


def _encode_array_header(count: int) -> bytes {
    if count < 16 {
        return struct.pack(">B", 0x90 + count);
    }
    if count < 65536 {
        return struct.pack(">B", 0xdc) + struct.pack(">H", count);
    }
    return struct.pack(">B", 0xdd) + struct.pack(">I", count);
}


def _encode_map_header(count: int) -> bytes {
    if count < 16 {
        return struct.pack(">B", 0x80 + count);
    }
    if count < 65536 {
        return struct.pack(">B", 0xde) + struct.pack(">H", count);
    }
    return struct.pack(">B", 0xdf) + struct.pack(">I", count);
}


def msgpack_encode(vin: JacValue) -> bytes {
    v: JacValue = vin;

    if v.kind == JV_NIL {
        return struct.pack(">B", 0xc0);
    }
    if v.kind == JV_BOOL {
        if v.b {
            return struct.pack(">B", 0xc3);
        }
        return struct.pack(">B", 0xc2);
    }
    if v.kind == JV_INT {
        n = v.i;
        if n >= 0 and n < 0x80 {
            return struct.pack(">B", n);
        }
        if n < 0 and n >= -32 {
            return struct.pack(">B", n + 256);
        }
        return struct.pack(">B", 0xd3) + struct.pack(">q", n);
    }
    if v.kind == JV_UINT {
        return struct.pack(">B", 0xcf) + struct.pack(">Q", v.i);
    }
    if v.kind == JV_FLOAT {
        return struct.pack(">B", 0xcb) + struct.pack(">Q", v.i);
    }
    if v.kind == JV_STR {
        return _encode_str(v.s);
    }
    if v.kind == JV_ARRAY {
        kids: list[JacValue] = v.items;
        out = _encode_array_header(len(kids));
        for child in kids {
            out = out + msgpack_encode(child);
        }
        return out;
    }
    if v.kind == JV_MAP {
        ent: dict[str, JacValue] = v.entries;
        out = _encode_map_header(len(ent));
        for k in ent.keys() {
            out = out + _encode_str(k);
            out = out + msgpack_encode(ent[k]);
        }
        return out;
    }
    raise ValueError("msgpack encode: unsupported JacValue kind " + str(v.kind));
}


# Build   [ 1, "hi", { "k": [ true, nil ] } ]
# msgpack  93 01 a2 68 69 81 a1 6b 92 c3 c0   (len 11)
def _tree() -> JacValue {
    inner: list[JacValue] = [];
    inner.append(jv_bool(True));
    inner.append(jv_nil());
    m: dict[str, JacValue] = {};
    m["k"] = jv_array(inner);
    top: list[JacValue] = [];
    top.append(jv_int(1));
    top.append(jv_str("hi"));
    top.append(jv_map(m));
    return jv_array(top);
}


def enc_len() -> int {
    blob = msgpack_encode(_tree());
    return len(blob);
}


def enc_byte(idx: int) -> int {
    blob = msgpack_encode(_tree());
    return blob[idx];
}


# A single deep integer: negative i64 uses the 0xd3 wide form.
def enc_int_wide_byte(idx: int) -> int {
    blob = msgpack_encode(jv_int(-1000));
    return blob[idx];
}


def enc_int_wide_len() -> int {
    blob = msgpack_encode(jv_int(-1000));
    return len(blob);
}
