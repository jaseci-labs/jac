import from _csprng_native { csprng_bytes }
import from _directory_native { try_directory_names }
import from _file_native { read_file_bytes }
import from hashlib { md5, sha1 }
import time;

glob RESERVED_NCS: str = "reserved for NCS compatibility",
     RFC_4122: str = "specified in RFC 4122",
     RESERVED_MICROSOFT: str = "reserved for Microsoft compatibility",
     RESERVED_FUTURE: str = "reserved for future definition";

glob _HEXV: str = "0123456789abcdef";

glob _HEXB: bytes = b"0123456789abcdef";


def _hexval(c: str) -> int {
    i: int = 0;
    while i < 16 {
        if _HEXV[i] == c {
            return i;
        }
        i += 1;
    }
    if c == "A" {
        return 10;
    }
    if c == "B" {
        return 11;
    }
    if c == "C" {
        return 12;
    }
    if c == "D" {
        return 13;
    }
    if c == "E" {
        return 14;
    }
    if c == "F" {
        return 15;
    }
    return -1;
}


def _byte_hexval(c: int) -> int {
    if c >= 48 and c <= 57 {
        return c - 48;
    }
    if c >= 97 and c <= 102 {
        return c - 87;
    }
    if c >= 65 and c <= 70 {
        return c - 55;
    }
    return -1;
}


def _be(b: bytes, off: int, width: int) -> int {
    v: int = 0;
    i: int = 0;
    while i < width {
        v = (v << 8) | b[off + i];
        i += 1;
    }
    return v;
}


def _frozen(buf: bytearray, n: int) -> bytes {
    return bytes(buf[0:n]);
}


def:pub hex_concat(b: bytes) -> str {
    out: str = "";
    n: int = len(b);
    i: int = 0;
    while i < n {
        v: int = b[i];
        out += _HEXV[(v >> 4) & 15];
        out += _HEXV[v & 15];
        i += 1;
    }
    return out;
}


def:pub hex_buffer(b: bytes) -> str {
    return _hex_str(b);
}


def _hex_str(b: bytes) -> str {
    n: int = len(b);
    out: bytearray = bytearray(n * 2);
    i: int = 0;
    while i < n {
        v: int = b[i];
        out[i * 2] = _HEXB[(v >> 4) & 15];
        out[i * 2 + 1] = _HEXB[v & 15];
        i += 1;
    }
    return _frozen(out, n * 2).decode();
}


def _put(buf: bytearray, off: int, width: int, value: int) {
    i: int = 0;
    while i < width {
        buf[off + i] = (value >> ((width - 1 - i) * 8)) & 255;
        i += 1;
    }
}


obj:pub UUID {
    has _b: bytes = b"";
    has hex: str { getter; }
    has fields: tuple[int, int, int, int, int, int] { getter; }
    has time_low: int { getter; }
    has time_mid: int { getter; }
    has time_hi_version: int { getter; }
    has clock_seq_hi_variant: int { getter; }
    has clock_seq_low: int { getter; }
    has clock_seq: int { getter; }
    has `node: int { getter; }
    has time: int { getter; }
    has urn: str { getter; }
    has variant: str { getter; }
    has version: (int | None) { getter; }
    has bytes_le: bytes { getter; }

    def init(
        hex: str = "",
        bytes: bytes = b"",
        bytes_le: bytes = b"",
        fields: (list[int] | None) = None,
        version: int = 0
    ) {
        given: int = 0;
        if hex != "" {
            given += 1;
        }
        if len(bytes) > 0 {
            given += 1;
        }
        if len(bytes_le) > 0 {
            given += 1;
        }
        if fields is not None {
            given += 1;
        }
        if given != 1 {
            raise TypeError(
                "one of the hex, bytes, bytes_le, fields, or int arguments"
                " must be given"
            );
        }
        raw: bytearray = bytearray(16);
        if hex != "" {
            h: str = hex;
            if h.startswith("urn:") {
                h = h[4:];
            }
            if h.startswith("uuid:") {
                h = h[5:];
            }
            while h.startswith("{") {
                h = h[1:];
            }
            while h.endswith("}") {
                h = h[0:len(h) - 1];
            }
            h = "".join(h.split("-"));
            if len(h) != 32 {
                raise ValueError("badly formed hexadecimal UUID string");
            }
            i: int = 0;
            while i < 16 {
                hi: int = _hexval(h[i * 2]);
                lo: int = _hexval(h[i * 2 + 1]);
                if hi < 0 or lo < 0 {
                    raise ValueError("badly formed hexadecimal UUID string");
                }
                raw[i] = hi * 16 + lo;
                i += 1;
            }
        } elif len(bytes) > 0 {
            if len(bytes) != 16 {
                raise ValueError("bytes is not a 16-char string");
            }
            i = 0;
            while i < 16 {
                raw[i] = bytes[i];
                i += 1;
            }
        } elif len(bytes_le) > 0 {
            if len(bytes_le) != 16 {
                raise ValueError("bytes_le is not a 16-char string");
            }
            order: list[int] = [3, 2, 1, 0, 5, 4, 7, 6, 8, 9, 10, 11, 12, 13, 14, 15];
            i = 0;
            while i < 16 {
                raw[i] = bytes_le[order[i]];
                i += 1;
            }
        } else {
            fl: list[int] = [];
            if fields is not None {
                fl = fields;
            }
            if len(fl) != 6 {
                raise ValueError("fields is not a 6-tuple");
            }
            if fl[0] < 0 or fl[0] > 4294967295 {
                raise ValueError("field 1 out of range (need a 32-bit value)");
            }
            if fl[1] < 0 or fl[1] > 65535 {
                raise ValueError("field 2 out of range (need a 16-bit value)");
            }
            if fl[2] < 0 or fl[2] > 65535 {
                raise ValueError("field 3 out of range (need a 16-bit value)");
            }
            if fl[3] < 0 or fl[3] > 255 {
                raise ValueError("field 4 out of range (need an 8-bit value)");
            }
            if fl[4] < 0 or fl[4] > 255 {
                raise ValueError("field 5 out of range (need an 8-bit value)");
            }
            if fl[5] < 0 or fl[5] > 281474976710655 {
                raise ValueError("field 6 out of range (need a 48-bit value)");
            }
            _put(raw, 0, 4, fl[0]);
            _put(raw, 4, 2, fl[1]);
            _put(raw, 6, 2, fl[2]);
            raw[8] = fl[3];
            raw[9] = fl[4];
            _put(raw, 10, 6, fl[5]);
        }
        if version != 0 {
            if version < 1 or version > 8 {
                raise ValueError("illegal version number");
            }
            raw[8] = (raw[8] & 63) | 128;
            raw[6] = (raw[6] & 15) | (version << 4);
        }
        self._b = _frozen(raw, 16);
    }

    def __str__ -> str {
        raw: bytes = self._b;
        out: bytearray = bytearray(36);
        pos: int = 0;
        i: int = 0;
        while i < 16 {
            if i == 4 or i == 6 or i == 8 or i == 10 {
                out[pos] = 45;
                pos += 1;
            }
            v: int = raw[i];
            out[pos] = _HEXB[(v >> 4) & 15];
            out[pos + 1] = _HEXB[v & 15];
            pos += 2;
            i += 1;
        }
        return _frozen(out, 36).decode();
    }

    def __repr__ -> str {
        return "UUID('" + self.__str__() + "')";
    }

    def __eq__(other: UUID) -> bool {
        i: int = 0;
        while i < 16 {
            if self._b[i] != other._b[i] {
                return False;
            }
            i += 1;
        }
        return True;
    }

    def __ne__(other: UUID) -> bool {
        return not self.__eq__(other);
    }

    def __lt__(other: UUID) -> bool {
        i: int = 0;
        while i < 16 {
            a: int = self._b[i];
            b: int = other._b[i];
            if a != b {
                return a < b;
            }
            i += 1;
        }
        return False;
    }

    def __gt__(other: UUID) -> bool {
        return other.__lt__(self);
    }

    def __le__(other: UUID) -> bool {
        return not other.__lt__(self);
    }

    def __ge__(other: UUID) -> bool {
        return not self.__lt__(other);
    }

    def __hash__ -> int {
        acc: int = 0;
        i: int = 0;
        while i < 16 {
            acc = (acc * 131 + self._b[i]) % 2147483647;
            i += 1;
        }
        return acc;
    }

    def to_bytes -> bytes {
        return self._b;
    }
}


impl UUID.hex.getter -> str {
    return _hex_str(self._b);
}


impl UUID.bytes_le.getter -> bytes {
    out: bytearray = bytearray(16);
    order: list[int] = [3, 2, 1, 0, 5, 4, 7, 6, 8, 9, 10, 11, 12, 13, 14, 15];
    i: int = 0;
    while i < 16 {
        out[i] = self._b[order[i]];
        i += 1;
    }
    return _frozen(out, 16);
}


impl UUID.time_low.getter -> int {
    return _be(self._b, 0, 4);
}


impl UUID.time_mid.getter -> int {
    return _be(self._b, 4, 2);
}


impl UUID.time_hi_version.getter -> int {
    return _be(self._b, 6, 2);
}


impl UUID.clock_seq_hi_variant.getter -> int {
    return self._b[8];
}


impl UUID.clock_seq_low.getter -> int {
    return self._b[9];
}


impl UUID.clock_seq.getter -> int {
    return ((self._b[8] & 63) << 8) | self._b[9];
}


impl UUID.`node.getter -> int {
    return _be(self._b, 10, 6);
}


impl UUID.fields.getter -> tuple[int, int, int, int, int, int] {
    return (
        _be(self._b, 0, 4),
        _be(self._b, 4, 2),
        _be(self._b, 6, 2),
        self._b[8],
        self._b[9],
        _be(self._b, 10, 6)
    );
}


impl UUID.variant.getter -> str {
    flag: int = self._b[8];
    if (flag & 128) == 0 {
        return RESERVED_NCS;
    }
    if (flag & 64) == 0 {
        return RFC_4122;
    }
    if (flag & 32) == 0 {
        return RESERVED_MICROSOFT;
    }
    return RESERVED_FUTURE;
}


impl UUID.version.getter -> int | None {
    if self.variant == RFC_4122 {
        return (self._b[6] >> 4) & 15;
    }
    return None;
}


impl UUID.time.getter -> int {
    ver: int | None = self.version;
    vnum: int = -1;
    if ver is not None {
        vnum = ver;
    }
    if vnum == 6 {
        return (_be(self._b, 0, 4) << 28)
            | (_be(self._b, 4, 2) << 12)
            | (_be(self._b, 6, 2) & 4095);
    }
    if vnum == 7 {
        return _be(self._b, 0, 6);
    }
    return ((_be(self._b, 6, 2) & 4095) << 48)
        | (_be(self._b, 4, 2) << 32)
        | _be(self._b, 0, 4);
}


impl UUID.urn.getter -> str {
    return "urn:uuid:" + self.__str__();
}


def _from_bytes(raw: bytes, version: int) -> UUID {
    buf: bytearray = bytearray(16);
    i: int = 0;
    while i < 16 {
        buf[i] = raw[i];
        i += 1;
    }
    buf[8] = (buf[8] & 63) | 128;
    buf[6] = (buf[6] & 15) | (version << 4);
    return UUID(bytes=_frozen(buf, 16));
}


def:pub getnode -> int {
    cached: int = _NODE.value;
    if cached != 0 {
        return cached;
    }
    names: list[str] = try_directory_names("/sys/class/net");
    for nm in names {
        if nm == "lo" {
            continue;
        }
        raw: bytes = read_file_bytes("/sys/class/net/" + nm + "/address");
        if len(raw) < 17 {
            continue;
        }
        acc: int = 0;
        ok: bool = True;
        i: int = 0;
        while i < 6 {
            hi: int = _byte_hexval(raw[i * 3]);
            lo: int = _byte_hexval(raw[i * 3 + 1]);
            if hi < 0 or lo < 0 {
                ok = False;
            } else {
                acc = (acc << 8) | (hi * 16 + lo);
            }
            i += 1;
        }
        if ok and acc != 0 {
            _NODE.value = acc;
            return acc;
        }
    }
    rb: bytes = csprng_bytes(6);
    acc = 0;
    i = 0;
    while i < 6 {
        acc = (acc << 8) | rb[i];
        i += 1;
    }
    acc = acc | 1099511627776;
    _NODE.value = acc;
    return acc;
}


obj _Cell {
    has value: int = 0;
}

glob _NODE: _Cell = _Cell(),
     _LAST_V1: _Cell = _Cell(),
     _LAST_V6: _Cell = _Cell(),
     _LAST_V7: _Cell = _Cell(),
     _CNT_V7: _Cell = _Cell(),
     _UUID_EPOCH: int = 122192928000000000;


def _rand_bits(nbits: int) -> int {
    nbytes: int = (nbits + 7) // 8;
    rb: bytes = csprng_bytes(nbytes);
    acc: int = 0;
    i: int = 0;
    while i < nbytes {
        acc = (acc << 8) | rb[i];
        i += 1;
    }
    return acc >> (nbytes * 8 - nbits);
}


def:pub uuid1(`node: int = -1, clock_seq: int = -1) -> UUID {
    timestamp: int = time.time_ns() // 100 + _UUID_EPOCH;
    if _LAST_V1.value != 0 and timestamp <= _LAST_V1.value {
        timestamp = _LAST_V1.value + 1;
    }
    _LAST_V1.value = timestamp;
    cs: int = clock_seq;
    if cs < 0 {
        cs = _rand_bits(14);
    }
    nd: int = `node;
    if nd < 0 {
        nd = getnode();
    }
    fields: list[int] = [
        timestamp & 4294967295,
        (timestamp >> 32) & 65535,
        (timestamp >> 48) & 4095,
        (cs >> 8) & 63,
        cs & 255,
        nd & 281474976710655
    ];
    return UUID(fields=fields, version=1);
}


def:pub uuid3(namespace: UUID, name: str) -> UUID {
    h = md5(namespace.to_bytes() + name.encode());
    return _from_bytes(h.digest(), 3);
}


def:pub uuid4 -> UUID {
    return _from_bytes(csprng_bytes(16), 4);
}


def:pub uuid4_fresh_buffer -> UUID {
    buf: bytearray = bytearray(16);
    i: int = 0;
    while i < 16 {
        rb: bytes = csprng_bytes(1);
        buf[i] = rb[0];
        i += 1;
    }
    buf[8] = (buf[8] & 63) | 128;
    buf[6] = (buf[6] & 15) | 64;
    return UUID(bytes=_frozen(buf, 16));
}


def:pub uuid5(namespace: UUID, name: str) -> UUID {
    h = sha1(namespace.to_bytes() + name.encode());
    return _from_bytes(h.digest()[0:16], 5);
}


def:pub uuid6(`node: int = -1, clock_seq: int = -1) -> UUID {
    timestamp: int = time.time_ns() // 100 + _UUID_EPOCH;
    if _LAST_V6.value != 0 and timestamp <= _LAST_V6.value {
        timestamp = _LAST_V6.value + 1;
    }
    _LAST_V6.value = timestamp;
    cs: int = clock_seq;
    if cs < 0 {
        cs = _rand_bits(14);
    }
    nd: int = `node;
    if nd < 0 {
        nd = getnode();
    }
    time_hi_and_mid: int = (timestamp >> 12) & 281474976710655;
    time_lo: int = timestamp & 4095;
    clock_s: int = cs & 16383;
    buf: bytearray = bytearray(16);
    _put(buf, 0, 6, time_hi_and_mid);
    _put(buf, 6, 2, time_lo);
    _put(buf, 8, 2, clock_s);
    _put(buf, 10, 6, nd & 281474976710655);
    return _from_bytes(_frozen(buf, 16), 6);
}


def:pub uuid7 -> UUID {
    ts_ms: int = time.time_ns() // 1000000;
    counter: int = 0;
    tail: int = 0;
    last: int = _LAST_V7.value;
    if last == 0 or ts_ms > last {
        counter = _rand_bits(42) & 2199023255551;
        tail = _rand_bits(32);
    } else {
        if ts_ms < last {
            ts_ms = last + 1;
        }
        counter = _CNT_V7.value + 1;
        if counter > 4398046511103 {
            ts_ms += 1;
            counter = _rand_bits(42) & 2199023255551;
            tail = _rand_bits(32);
        } else {
            tail = _rand_bits(32);
        }
    }
    counter_hi: int = (counter >> 30) & 4095;
    counter_lo: int = counter & 1073741823;
    buf: bytearray = bytearray(16);
    _put(buf, 0, 6, ts_ms & 281474976710655);
    _put(buf, 6, 2, counter_hi);
    _put(buf, 8, 4, counter_lo);
    _put(buf, 12, 4, tail & 4294967295);
    _LAST_V7.value = ts_ms;
    _CNT_V7.value = counter;
    return _from_bytes(_frozen(buf, 16), 7);
}


def:pub uuid8(a: int = -1, b: int = -1, c: int = -1) -> UUID {
    av: int = a;
    bv: int = b;
    cv: int = c;
    if av < 0 {
        av = _rand_bits(48);
    }
    if bv < 0 {
        bv = _rand_bits(12);
    }
    if cv < 0 {
        cv = _rand_bits(62);
    }
    buf: bytearray = bytearray(16);
    _put(buf, 0, 6, av & 281474976710655);
    _put(buf, 6, 2, bv & 4095);
    _put(buf, 8, 8, cv & 4611686018427387903);
    return _from_bytes(_frozen(buf, 16), 8);
}


glob:pub NAMESPACE_DNS: UUID = UUID(hex="6ba7b810-9dad-11d1-80b4-00c04fd430c8"),
     NAMESPACE_URL: UUID = UUID(hex="6ba7b811-9dad-11d1-80b4-00c04fd430c8"),
     NAMESPACE_OID: UUID = UUID(hex="6ba7b812-9dad-11d1-80b4-00c04fd430c8"),
     NAMESPACE_X500: UUID = UUID(hex="6ba7b814-9dad-11d1-80b4-00c04fd430c8"),
     NIL: UUID = UUID(hex="00000000-0000-0000-0000-000000000000"),
     MAX: UUID = UUID(hex="ffffffff-ffff-ffff-ffff-ffffffffffff");
