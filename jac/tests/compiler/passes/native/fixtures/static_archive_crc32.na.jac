# Gate fixture for static C-archive linking (#6978 Phase 0.1a): call lzma_crc32
# (a 0-undefined leaf member of liblzma.a) and print its result. The CRC-32/ISO
# check value of "123456789" is 0xCBF43926 == 3421780262. The `& 0xFFFFFFFF`
# masks the 32-bit return into a clean positive i64 for printing.
import from lzma { def lzma_crc32(buf: bytes, size: u64, crc: u64) -> u64;  }

with entry {
    data = b"123456789";
    r: u64 = lzma_crc32(data, len(data), 0) & 0xFFFFFFFF;
    print(r);
}
