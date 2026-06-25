"""Test fixture: a `bytes` argument to a clib function lowers to a raw data
pointer (#6940 Phase 2).

A foreign signature taking `buf: bytes` is the C buffer-protocol convention: the
parameter is a raw `i8*` to the element data, and the call site passes the
pointer to the first data byte — NOT the internal jacbytes
`{ i64 len, [n x i8] }` struct pointer (whose 8-byte length header C would
otherwise read as leading data). The element count travels through the separate
explicit length parameter. This is the FFI floor under the bundled na_stdlib
zlib/zipfile tier.
"""

import from z {
    def crc32_z(crc: u64, buf: bytes, len: u64) -> u64;
}

def checksum(data: bytes) -> int {
    return crc32_z(0, data, len(data));
}
