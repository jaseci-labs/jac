"""Smoke: poll(2) with Pollfd struct — does revents copy back?"""

import sys;

import from "/usr/lib/libc.so.6" {
    obj Pollfd {
        has fd: i32,
            events: i16,
            revents: i16;
    }  def write(fd: i32, buf: str, count: i32) -> i32;  def poll(
        fds: Pollfd, nfds: i32, timeout: i32
    ) -> i32;
}

def msg(s: str) {
    write(2, s, len(s));
}

glob POLLIN: int = 1,
     p: Pollfd = Pollfd(fd=0, events=POLLIN, revents=0);

with entry {
    msg("[poll-smoke] waiting on stdin 2s...\n");
}

glob r: int = poll(p, 1, 2000),
     rev: int = p.revents;

with entry {
    msg(f"[poll-smoke] r={r} revents={rev}\n");
}
