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

def:pub build_region_desc(off: int, length: int) -> bytes;

def:pub parse_region_desc(raw: bytes) -> Region | None;

obj Trailer {
    has payload_len: int = 0,
        hash_hex: str = "";

    def hash16 -> str;
}

def:pub build_trailer(magic: bytes, payload_len: int, sha256_hex: str) -> bytes;

def:pub parse_trailer(raw: bytes, magic: bytes) -> Trailer | None;

def:pub region_start(end: int, payload_len: int) -> int;

def:pub rt_key(hash16: str) -> str;
