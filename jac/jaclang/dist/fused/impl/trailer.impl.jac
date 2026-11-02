impl build_region_desc(off: int, length: int) -> bytes {
    return (
        REGION_MAGIC
        + off.to_bytes(8, "little")
        + length.to_bytes(8, "little")
        + b"\x00\x00\x00\x00\x00\x00\x00\x00"
    );
}

impl parse_region_desc(raw: bytes) -> Region | None {
    if len(raw) != REGION_DESC_LEN or raw[0:MAGIC_LEN] != REGION_MAGIC {
        return None;
    }
    return Region(
        off=int.from_bytes(raw[MAGIC_LEN:MAGIC_LEN + 8], "little"),
        length=int.from_bytes(raw[MAGIC_LEN + 8:MAGIC_LEN + 16], "little")
    );
}

impl Trailer.hash16 -> str {
    return self.hash_hex[0:16];
}

impl build_trailer(magic: bytes, payload_len: int, sha256_hex: str) -> bytes {
    return magic + payload_len.to_bytes(8, "little") + sha256_hex.encode();
}

impl parse_trailer(raw: bytes, magic: bytes) -> Trailer | None {
    if len(raw) != TRAILER_LEN or raw[0:MAGIC_LEN] != magic {
        return None;
    }
    return Trailer(
        payload_len=int.from_bytes(raw[MAGIC_LEN:MAGIC_LEN + 8], "little"),
        hash_hex=raw[MAGIC_LEN + 8:TRAILER_LEN].decode()
    );
}

impl region_start(end: int, payload_len: int) -> int {
    start = end - TRAILER_LEN - payload_len;
    return start if start >= 0 else -1;
}

impl rt_key(hash16: str) -> str {
    return hash16[0:RT_KEY_LEN];
}
