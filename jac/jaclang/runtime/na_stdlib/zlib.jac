def:pub crc32(data: bytes, value: int = 0) -> int;


def:pub adler32(data: bytes, value: int = 1) -> int;


def:pub compress(data: bytes, level: int = -1) -> bytes;


def:pub decompress(data: bytes | bytearray) -> bytes;
