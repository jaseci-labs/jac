"""Smoke: ioctl + tcgetattr using calloc str buffers and ord() reads."""

import sys;

import from "/usr/lib/libc.so.6" {
    def open(path: str, flags: i32, mode: i32) -> i32;  def close(fd: i32) -> i32;  def write(
        fd: i32, buf: str, count: i32
    ) -> i32;  def ioctl(fd: i32, request: i64, arg: str) -> i32;  def tcgetattr(
        fd: i32, term: str
    ) -> i32;  def calloc(n: int, sz: int) -> int;  def free(p: int) -> None;
}

def msg(s: str) {
    write(2, s, len(s));
}

def read_u32(buf: str, off: int) -> int {
    b0: int = ord(buf[off]);
    b1: int = ord(buf[off + 1]);
    b2: int = ord(buf[off + 2]);
    b3: int = ord(buf[off + 3]);
    return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24);
}

def u16le(buf: str, off: int) -> int {
    lo: int = ord(buf[off]);
    hi: int = ord(buf[off + 1]);
    return lo | (hi << 8);
}

glob O_RDWR: int = 2,
     TIOCGWINSZ: int = 0x5413;

glob fd: int = open("/dev/tty", O_RDWR, 0);

with entry {
    if fd < 0 {
        msg("[buf-smoke] FAIL open\n");
        sys.exit(1);
    }
}

glob ws: str = calloc(8, 1),
     irc: int = ioctl(fd, TIOCGWINSZ, ws);

with entry {
    msg(f"[buf-smoke] ioctl rc={irc}\n");
    if irc == 0 {
        row: int = u16le(ws, 0);
        col: int = u16le(ws, 2);
        msg(f"[buf-smoke] ioctl size {col}x{row}\n");
    }
}

glob term: str = calloc(60, 1),
     trc: int = tcgetattr(fd, term);

with entry {
    msg(f"[buf-smoke] tcgetattr rc={trc}\n");
    if trc == 0 {
        iflag: int = read_u32(term, 0);
        lflag: int = read_u32(term, 12);
        msg(f"[buf-smoke] iflag={iflag} lflag={lflag}\n");
    }

    free(ws);
    free(term);
    close(fd);
    msg("[buf-smoke] done\n");
}
