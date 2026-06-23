"""Smoke: poll via packed 8-byte string (pollfd layout)."""

import sys;

import from "/usr/lib/libc.so.6" {
    def write(fd: i32, buf: str, count: i32) -> i32;  def poll(
        fds: str, nfds: i32, timeout: i32
    ) -> i32;
}

def msg(s: str) {
    write(2, s, len(s));
}

def pack_pollfd(fd: int, events: int) -> str {
    b0: str = chr(fd & 0xFF);
    b1: str = chr((fd >> 8) & 0xFF);
    b2: str = chr((fd >> 16) & 0xFF);
    b3: str = chr((fd >> 24) & 0xFF);
    b4: str = chr(events & 0xFF);
    b5: str = chr((events >> 8) & 0xFF);
    z0: str = chr(0);
    return b0 + b1 + b2 + b3 + b4 + b5 + z0 + z0;
}

def u16le(buf: str, off: int) -> int {
    lo: int = ord(buf[off]);
    hi: int = ord(buf[off + 1]);
    return lo | (hi << 8);
}

glob POLLIN: int = 1,
     fds: str = pack_pollfd(0, POLLIN);

with entry {
    msg("[poll-pack] waiting stdin 2s...\n");
}

glob r: int = poll(fds, 1, 2000),
     rev: int = u16le(fds, 6);

with entry {
    msg(f"[poll-pack] r={r} revents={rev}\n");
}
