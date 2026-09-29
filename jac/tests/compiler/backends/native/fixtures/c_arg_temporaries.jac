"""Owned bytes and str temporaries passed straight to C functions."""

import from c {
    def strnlen(s: str, n: u64) -> u64;  def memchr(
        s: bytes, c: i32, n: u64
    ) -> ptr[u8];  def strchr(s: str, c: i32) -> ptr[u8];
}

obj Box {
    has data: bytes,
        text: str = "hello world";
}

def probe(b: Box, i: int) -> int {
    p = memchr(b.data[1:4 + i % 3], i32(0x7a), u64(3));
    q = strchr(b.text + str(i), i32(0x7a));
    return (1 if int(p) == 0 else 0) + (1 if int(q) == 0 else 0);
}

with entry {
    b = Box(data=b"abcdefghijkl");
    total = 0;
    for i in range(300) {
        total += probe(b, i);
    }
    print(total);
}
