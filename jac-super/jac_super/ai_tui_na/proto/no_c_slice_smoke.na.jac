"""Smoke: binary str slice + concat for termios patch."""

import sys;

import from "/usr/lib/libc.so.6" {
    def write(fd: i32, buf: str, count: i32) -> i32;  def calloc(
        n: int, sz: int
    ) -> int;  def free(p: int) -> None;
}

def msg(s: str) {
    write(2, s, len(s));
}

def patch_u32(buf: str, off: int, val: int) -> str {
    prefix: str = buf[:off];
    mid: str = chr(val & 0xFF) + chr((val >> 8) & 0xFF) + chr((val >> 16) & 0xFF) + chr(
        (val >> 24) & 0xFF
    );
    suffix: str = buf[off + 4:];
    return prefix + mid + suffix;
}

glob buf: str = calloc(8, 1),
     buf = patch_u32(buf, 2, 0x1234),
     b0: int = ord(buf[2]),
     b1: int = ord(buf[3]),
     v: int = b0 | (b1 << 8);

with entry {
    msg(f"[slice-smoke] patched={v}\n");
    free(buf);
}
