glob MAGIC: bytes = b"JACBIN01",
     OVERLAY_MAGIC: bytes = b"JABOVL01",
     MAGIC_LEN: int = 8,
     HASH_LEN: int = 64,
     TRAILER_LEN: int = 80,
     RT_KEY_LEN: int = 16,
     REGION_MAGIC: bytes = b"JSCATRG1",
     REGION_DESC_LEN: int = 32,
     REGION_ALIGN: int = 16384;

obj Region {
    has off: int = 0,
        length: int = 0;
}

def:pub build_region_desc(off: int, length: int) -> bytes {
    return (
        REGION_MAGIC
        + off.to_bytes(8, "little")
        + length.to_bytes(8, "little")
        + b"\x00\x00\x00\x00\x00\x00\x00\x00"
    );
}

def:pub parse_region_desc(raw: bytes) -> Region | None {
    if len(raw) != REGION_DESC_LEN or raw[0:MAGIC_LEN] != REGION_MAGIC {
        return None;
    }
    return Region(
        off=int.from_bytes(raw[MAGIC_LEN:MAGIC_LEN + 8], "little"),
        length=int.from_bytes(raw[MAGIC_LEN + 8:MAGIC_LEN + 16], "little")
    );
}

obj Trailer {
    has payload_len: int = 0,
        hash_hex: str = "";

    def hash16 -> str {
        return self.hash_hex[0:16];
    }
}

def:pub build_trailer(magic: bytes, payload_len: int, sha256_hex: str) -> bytes {
    return magic + payload_len.to_bytes(8, "little") + sha256_hex.encode();
}

def:pub parse_trailer(raw: bytes, magic: bytes) -> Trailer | None {
    if len(raw) != TRAILER_LEN or raw[0:MAGIC_LEN] != magic {
        return None;
    }
    return Trailer(
        payload_len=int.from_bytes(raw[MAGIC_LEN:MAGIC_LEN + 8], "little"),
        hash_hex=raw[MAGIC_LEN + 8:TRAILER_LEN].decode()
    );
}

def:pub region_start(end: int, payload_len: int) -> int {
    start = end - TRAILER_LEN - payload_len;
    return start if start >= 0 else -1;
}

def:pub rt_key(hash16: str) -> str {
    return hash16[0:RT_KEY_LEN];
}
