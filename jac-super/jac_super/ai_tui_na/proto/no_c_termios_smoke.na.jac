"""Smoke: tcgetattr via 60-byte calloc buffer (glibc termios layout)."""

import sys;

import from "/usr/lib/libc.so.6" {
    def open(path: str, flags: i32, mode: i32) -> i32;  def close(fd: i32) -> i32;  def write(
        fd: i32, buf: str, count: i32
    ) -> i32;  def tcgetattr(fd: i32, term: str) -> i32;  def tcsetattr(
        fd: i32, opt: i32, term: str
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

def write_u32(buf: str, off: int, val: int) {
    buf[off] = chr(val & 0xFF);
    buf[off + 1] = chr((val >> 8) & 0xFF);
    buf[off + 2] = chr((val >> 16) & 0xFF);
    buf[off + 3] = chr((val >> 24) & 0xFF);
}

glob O_RDWR: int = 2,
     TCSANOW: int = 0,
     ICANON: int = 2,
     ECHO: int = 8;

glob fd: int = open("/dev/tty", O_RDWR, 0);

with entry {
    if fd < 0 {
        msg("[termios-smoke] FAIL open\n");
        sys.exit(1);
    }
}

glob saved: str = calloc(60, 1);

with entry {
    if tcgetattr(fd, saved) != 0 {
        msg("[termios-smoke] FAIL tcgetattr\n");
        free(saved);
        close(fd);
        sys.exit(1);
    }
    msg("[termios-smoke] PASS tcgetattr\n");
}

glob lflag: int = read_u32(saved, 12),
     lflag = lflag & ~(ICANON | ECHO);

with entry {
    write_u32(saved, 12, lflag);

    if tcsetattr(fd, TCSANOW, saved) != 0 {
        msg("[termios-smoke] FAIL tcsetattr raw\n");
        free(saved);
        close(fd);
        sys.exit(1);
    }
    msg("[termios-smoke] PASS tcsetattr raw\n");

    close(fd);
    free(saved);
    msg("[termios-smoke] ALL PASS\n");
}
