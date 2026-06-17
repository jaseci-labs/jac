"""Smoke: ioctl via ptr buffer."""

import sys;

import from "/usr/lib/libc.so.6" {
    def open(path: str, flags: i32, mode: i32) -> i32;  def close(fd: i32) -> i32;  def write(
        fd: i32, buf: str, count: i32
    ) -> i32;  def ioctl(fd: i32, request: i64, arg: ptr) -> i32;  def calloc(
        n: int, sz: int
    ) -> ptr;  def free(p: ptr) -> None;
}

def msg(s: str) {
    write(2, s, len(s));
}

glob O_RDWR: int = 2,
     TIOCGWINSZ: int = 0x5413;

glob fd: int = open("/dev/tty", O_RDWR, 0);

with entry {
    if fd < 0 {
        msg("[ioctl-smoke] FAIL open\n");
        sys.exit(1);
    }
}

glob mem: ptr = calloc(8, 1),
     req: int = TIOCGWINSZ,
     rc: int = ioctl(fd, req, mem);

with entry {
    msg(f"[ioctl-smoke] rc={rc}\n");
    if rc != 0 {
        free(mem);
        close(fd);
        sys.exit(1);
    }
}

glob b0: int = mem[0],
     b1: int = mem[1],
     b2: int = mem[2],
     b3: int = mem[3],
     row: int = b0 | (b1 << 8),
     col: int = b2 | (b3 << 8);

with entry {
    msg(f"[ioctl-smoke] size {col}x{row}\n");
    free(mem);
    close(fd);
    msg("[ioctl-smoke] ALL PASS\n");
}
