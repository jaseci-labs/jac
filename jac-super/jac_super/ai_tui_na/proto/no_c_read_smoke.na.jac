"""Smoke: read(2) into calloc buffer via str pointer."""

import sys;

import from "/usr/lib/libc.so.6" {
    def write(fd: i32, buf: str, count: i32) -> i32;  def read(
        fd: i32, buf: str, count: i32
    ) -> i32;  def calloc(n: int, sz: int) -> int;  def free(p: int) -> None;
}

def msg(s: str) {
    write(2, s, len(s));
}

glob buf: str = calloc(4, 1);

with entry {
    msg("[read-smoke] type a char on stdin within 2s\n");
}

glob n: int = read(0, buf, 1);

with entry {
    msg(f"[read-smoke] n={n}\n");
    if n > 0 {
        c: int = ord(buf[0]);
        msg(f"[read-smoke] byte={c}\n");
    }
    free(buf);
    msg("[read-smoke] done\n");
}
