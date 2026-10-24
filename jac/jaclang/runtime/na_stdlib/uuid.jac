import from hashlib { md5, sha1 }
import time;

glob RESERVED_NCS: str = "reserved for NCS compatibility",
     RFC_4122: str = "specified in RFC 4122",
     RESERVED_MICROSOFT: str = "reserved for Microsoft compatibility",
     RESERVED_FUTURE: str = "reserved for future definition";

glob _HEXV: str = "0123456789abcdef";

glob _HEXB: bytes = b"0123456789abcdef";


def _hexval(c: str) -> int;


def _byte_hexval(c: int) -> int;


def _be(b: bytes, off: int, width: int) -> int;


def _frozen(buf: bytearray, n: int) -> bytes;


def hex_concat(b: bytes) -> str;


def hex_buffer(b: bytes) -> str;


def _hex_str(b: bytes) -> str;


def _put(buf: bytearray, off: int, width: int, value: int);


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
    );

    def __str__ -> str;
    def __repr__ -> str;
    def __eq__(other: UUID) -> bool;
    def __ne__(other: UUID) -> bool;
    def __lt__(other: UUID) -> bool;
    def __gt__(other: UUID) -> bool;
    def __le__(other: UUID) -> bool;
    def __ge__(other: UUID) -> bool;
    def __hash__ -> int;
    def _to_bytes -> bytes;
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


def _from_bytes(raw: bytes, version: int) -> UUID;


def:pub getnode -> int;


obj _Cell {
    has value: int = 0;
}

glob _NODE: _Cell = _Cell(),
     _LAST_V1: _Cell = _Cell(),
     _LAST_V6: _Cell = _Cell(),
     _LAST_V7: _Cell = _Cell(),
     _CNT_V7: _Cell = _Cell(),
     _UUID_EPOCH: int = 122192928000000000;


def _rand_bits(nbits: int) -> int;


def:pub uuid1(`node: int = -1, clock_seq: int = -1) -> UUID;


def:pub uuid3(namespace: UUID, name: str) -> UUID;


def:pub uuid4 -> UUID;


def uuid4_fresh_buffer -> UUID;


def:pub uuid5(namespace: UUID, name: str) -> UUID;


def:pub uuid6(`node: int = -1, clock_seq: int = -1) -> UUID;


def:pub uuid7 -> UUID;


def:pub uuid8(a: int = -1, b: int = -1, c: int = -1) -> UUID;


glob:pub NAMESPACE_DNS: UUID = UUID(hex="6ba7b810-9dad-11d1-80b4-00c04fd430c8"),
     NAMESPACE_URL: UUID = UUID(hex="6ba7b811-9dad-11d1-80b4-00c04fd430c8"),
     NAMESPACE_OID: UUID = UUID(hex="6ba7b812-9dad-11d1-80b4-00c04fd430c8"),
     NAMESPACE_X500: UUID = UUID(hex="6ba7b814-9dad-11d1-80b4-00c04fd430c8"),
     NIL: UUID = UUID(hex="00000000-0000-0000-0000-000000000000"),
     MAX: UUID = UUID(hex="ffffffff-ffff-ffff-ffff-ffffffffffff");
