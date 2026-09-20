"""Explicit C FFI borrows byte buffers with their declared length, including NUL bytes."""

import from z { def crc32_z(crc: u64, buf: bytes, len: u64) -> u64;  }

def checksum(data: bytes) -> int {
    return int(crc32_z(0, data, u64(len(data))));
}
