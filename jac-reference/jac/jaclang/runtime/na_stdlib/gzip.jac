glob _MASK32: int = 4294967295;


def:pub compress(data: bytes, compresslevel: int = 9, mtime: int = 0) -> bytes;


def:pub decompress(data: bytes) -> bytes;
