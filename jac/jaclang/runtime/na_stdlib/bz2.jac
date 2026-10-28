glob BZ_OK: int = 0,
     BZ_OUTBUFF_FULL: int = -8;


def:pub compress(data: bytes, compresslevel: int = 9) -> bytes;


def:pub decompress(data: bytes) -> bytes;
