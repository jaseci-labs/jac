import struct;

glob JV_NIL = 0,
     JV_BOOL = 1,
     JV_INT = 2,
     JV_UINT = 3,
     JV_FLOAT = 4,
     JV_STR = 5,
     JV_ARRAY = 8,
     JV_MAP = 9;

glob MP_MAX_DEPTH = 64;


obj JacValue {
    has kind: int = 0,
        i: int = 0,
        s: str = "",
        b: bool = False,
        items: list[JacValue] = [],
        entries: dict[str, JacValue] = {};
}


def jv_nil -> JacValue {
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


obj MsgpackDecoder {
    has base: int = 0,
        total: int = 0,
        off: int = 0,
        depth: int = 0;

    def _u8 -> int {
        if self.off + 1 > self.total {
            raise ValueError("msgpack decode: truncated payload");
        }
        chunk = __jac_bytes_from_raw(self.base + self.off, 1);
        self.off += 1;
        return struct.unpack(">B", chunk)[0];
    }

    def _u16 -> int {
        if self.off + 2 > self.total {
            raise ValueError("msgpack decode: truncated payload");
        }
        chunk = __jac_bytes_from_raw(self.base + self.off, 2);
        self.off += 2;
        return struct.unpack(">H", chunk)[0];
    }

    def _u32 -> int {
        if self.off + 4 > self.total {
            raise ValueError("msgpack decode: truncated payload");
        }
        chunk = __jac_bytes_from_raw(self.base + self.off, 4);
        self.off += 4;
        return struct.unpack(">I", chunk)[0];
    }

    def _str(slen: int) -> str {
        if self.off + slen > self.total {
            raise ValueError("msgpack decode: truncated str");
        }
        out = __jac_str_from_raw(self.base + self.off, slen);
        self.off += slen;
        return out;
    }

    def decode_one -> JacValue {
        self.depth += 1;
        if self.depth > MP_MAX_DEPTH {
            raise ValueError("msgpack decode: recursion depth exceeded");
        }
        lead = self._u8();

        if lead < 0x80 {
            self.depth -= 1;
            return jv_int(lead);
        }

        if lead >= 0xe0 {
            self.depth -= 1;
            return jv_int(lead - 256);
        }

        if lead >= 0xa0 and lead < 0xc0 {
            r = jv_str(self._str(lead - 0xa0));
            self.depth -= 1;
            return r;
        }

        if lead >= 0x80 and lead < 0x90 {
            r = self._decode_map(lead - 0x80);
            self.depth -= 1;
            return r;
        }

        if lead >= 0x90 and lead < 0xa0 {
            r = self._decode_array(lead - 0x90);
            self.depth -= 1;
            return r;
        }

        r2 = self._decode_tagged(lead);
        self.depth -= 1;
        return r2;
    }

    def _decode_tagged(lead: int) -> JacValue {
        if lead == 0xc0 {
            return jv_nil();
        }
        if lead == 0xc2 {
            return jv_bool(False);
        }
        if lead == 0xc3 {
            return jv_bool(True);
        }

        if lead == 0xcc {
            return jv_int(self._u8());
        }
        if lead == 0xcd {
            return jv_int(self._u16());
        }
        if lead == 0xce {
            return jv_int(self._u32());
        }
        if lead == 0xcf {
            if self.off + 8 > self.total {
                raise ValueError("msgpack decode: truncated u64");
            }
            chunk = __jac_bytes_from_raw(self.base + self.off, 8);
            self.off += 8;
            uv = struct.unpack(">Q", chunk)[0];
            if uv >= 0x8000000000000000 {
                return jv_uint(uv);
            }
            return jv_int(uv);
        }

        if lead == 0xd0 {
            if self.off + 1 > self.total {
                raise ValueError("msgpack decode: truncated i8");
            }
            chunk = __jac_bytes_from_raw(self.base + self.off, 1);
            self.off += 1;
            return jv_int(struct.unpack(">b", chunk)[0]);
        }
        if lead == 0xd1 {
            if self.off + 2 > self.total {
                raise ValueError("msgpack decode: truncated i16");
            }
            chunk = __jac_bytes_from_raw(self.base + self.off, 2);
            self.off += 2;
            return jv_int(struct.unpack(">h", chunk)[0]);
        }
        if lead == 0xd2 {
            if self.off + 4 > self.total {
                raise ValueError("msgpack decode: truncated i32");
            }
            chunk = __jac_bytes_from_raw(self.base + self.off, 4);
            self.off += 4;
            return jv_int(struct.unpack(">i", chunk)[0]);
        }
        if lead == 0xd3 {
            if self.off + 8 > self.total {
                raise ValueError("msgpack decode: truncated i64");
            }
            chunk = __jac_bytes_from_raw(self.base + self.off, 8);
            self.off += 8;
            return jv_int(struct.unpack(">q", chunk)[0]);
        }

        if lead == 0xca {
            if self.off + 4 > self.total {
                raise ValueError("msgpack decode: truncated f32");
            }
            chunk = __jac_bytes_from_raw(self.base + self.off, 4);
            self.off += 4;
            fv = struct.unpack(">f", chunk)[0];
            return jv_float_bits(struct.unpack(">Q", struct.pack(">d", fv))[0]);
        }
        if lead == 0xcb {
            if self.off + 8 > self.total {
                raise ValueError("msgpack decode: truncated f64");
            }
            chunk = __jac_bytes_from_raw(self.base + self.off, 8);
            self.off += 8;
            return jv_float_bits(struct.unpack(">Q", chunk)[0]);
        }

        if lead == 0xd9 {
            return jv_str(self._str(self._u8()));
        }
        if lead == 0xda {
            return jv_str(self._str(self._u16()));
        }
        if lead == 0xdb {
            return jv_str(self._str(self._u32()));
        }

        if lead == 0xdc {
            return self._decode_array(self._u16());
        }
        if lead == 0xdd {
            return self._decode_array(self._u32());
        }

        if lead == 0xde {
            return self._decode_map(self._u16());
        }
        if lead == 0xdf {
            return self._decode_map(self._u32());
        }
        raise ValueError("msgpack decode: unsupported lead byte " + str(lead));
    }

    def _decode_array(count: int) -> JacValue {
        items: list[JacValue] = [];
        ci = 0;
        while ci < count {
            items.append(self.decode_one());
            ci += 1;
        }
        return jv_array(items);
    }

    def _decode_map(count: int) -> JacValue {
        entries: dict[str, JacValue] = {};
        ci = 0;
        while ci < count {
            key = self.decode_one();
            kv: JacValue = key;
            if kv.kind != JV_STR {
                raise ValueError("msgpack decode: non-string map key");
            }
            entries[kv.s] = self.decode_one();
            ci += 1;
        }
        return jv_map(entries);
    }
}


def msgpack_decode(base: int, total: int) -> JacValue {
    d = MsgpackDecoder();
    d.base = base;
    d.total = total;
    d.off = 0;
    d.depth = 0;
    return d.decode_one();
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
