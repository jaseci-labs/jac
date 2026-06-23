"""Staged smoke test for libc-only tty — writes results to stderr, exits early."""

import sys;

import from "/usr/lib/libc.so.6" {
    def open(path: str, flags: i32, mode: i32) -> i32;  def close(fd: i32) -> i32;  def write(
        fd: i32, buf: str, count: i32
    ) -> i32;  def dup2(oldfd: i32, newfd: i32) -> i32;
}

def msg(s: str) {
    write(2, s, len(s));
}

glob O_RDWR: int = 2;

with entry {
    msg("[smoke] open /dev/tty\n");
}

glob fd: int = open("/dev/tty", O_RDWR, 0);

with entry {
    if fd < 0 {
        msg("[smoke] FAIL open\n");
        sys.exit(1);
    }
    msg("[smoke] PASS open\n");

    msg("[smoke] dup2 remap\n");
    if dup2(1, 3) < 0 {
        msg("[smoke] FAIL dup2(1,3)\n");
        close(fd);
        sys.exit(1);
    }
    if dup2(2, 1) < 0 {
        msg("[smoke] FAIL dup2(2,1)\n");
        close(fd);
        sys.exit(1);
    }
    msg("[smoke] PASS dup2\n");

    write(1, "smoke: hello on fd1 (terminal)\n", 32);
    msg("[smoke] PASS write fd1\n");

    dup2(3, 1);
    close(fd);
    msg("[smoke] ALL PASS\n");
}
