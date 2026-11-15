"""Bundled native `select` cross-backend equivalence fixture.

`import select` binds CPython's `select` on sv and the bundled
`na_stdlib/select.jac` on na. Pipe fds: `os.pipe()` on sv, libc `pipe(2)`
on na. Pins: a written pipe end answers readable, a pipe's write end
answers writable at timeout 0.0, the empty probe answers three empty
lists, and the block-forever sentinel answers immediately for a ready fd
(spelled `None` on sv -- CPython's sentinel -- and `-1.0` on na: the
documented divergence, so each lane pins its own spelling of the same
observable). Each result list follows its own input list: a repeated
ready fd comes back once per occurrence, in input order, and a not-ready
fd is skipped wherever it appears. A signal with a handler that returns
normally (SIGALRM from a one-shot 50 ms `setitimer`) arriving during a
0.5 s wait on an empty pipe must not raise: as CPython does (PEP 475), the
wait is retried for the time left, so it answers three empty lists after
the full timeout. ES/JS opts out (POSIX-only).
"""

import os;
import select;
import time;
import from c {
    def pipe(fds: bytes) -> i32;  def write(fd: i32, buf: bytes, n: u64) -> i64;  def close(
        fd: i32
    ) -> i32;  def signal(signum: i32, handler: int) -> int;  def setitimer(
        which: i32, new_value: bytes, old_value: int
    ) -> i32;
}


def _pipe_na -> tuple[(int, int)] {
    fds: bytes = b"\x00" * 8;
    pipe(fds);
    r: int = int.from_bytes(fds[0:4], "little");
    w: int = int.from_bytes(fds[4:8], "little");
    return (r, w);
}


def select_py -> dict[any, any] {
    d: dict[any, any] = {};
    (rfd, wfd) = os.pipe();
    os.write(wfd, b"x");
    (rr, _wr, _xr) = select.select([rfd], [], [], 0.0);
    d["read_ready"] = 1 if len(rr) > 0 else 0;
    (_r2, wlist, _x2) = select.select([], [wfd], [], 0.0);
    d["write_ready"] = 1 if len(wlist) > 0 else 0;
    (br, _bw, _bx) = select.select([rfd], [], [], None);
    d["block_ready"] = 1 if len(br) > 0 else 0;
    (er, ew, ex) = select.select([], [], [], 0.0);
    d["empty_ok"] = 1 if (len(er) == 0 and len(ew) == 0 and len(ex) == 0) else 0;
    (r3, w3, x3) = select.select([rfd], [wfd], [], 0.0);
    d["both_ready"] = 1 if (len(r3) == 1 and len(w3) == 1 and len(x3) == 0) else 0;
    d["repeats"] = _repeats_py(rfd, wfd);
    d["eintr"] = _eintr_py();
    d["pollin"] = select.POLLIN;
    d["pollout"] = select.POLLOUT;
    os.close(rfd);
    os.close(wfd);
    return d;
}


def select_cl -> dict[any, any] {
    return {};
}


def select_na -> dict[str, any] {
    d: dict[str, any] = {};
    (rfd, wfd) = _pipe_na();
    payload: bytes = b"x";
    write(i32(wfd), payload, u64(1));
    (rr, _wr, _xr) = select.select([rfd], [], [], 0.0);
    d["read_ready"] = 1 if len(rr) > 0 else 0;
    (_r2, wlist, _x2) = select.select([], [wfd], [], 0.0);
    d["write_ready"] = 1 if len(wlist) > 0 else 0;
    (br, _bw, _bx) = select.select([rfd], [], [], -1.0);
    d["block_ready"] = 1 if len(br) > 0 else 0;
    (er, ew, ex) = select.select([], [], [], 0.0);
    d["empty_ok"] = 1 if (len(er) == 0 and len(ew) == 0 and len(ex) == 0) else 0;
    (r3, w3, x3) = select.select([rfd], [wfd], [], 0.0);
    d["both_ready"] = 1 if (len(r3) == 1 and len(w3) == 1 and len(x3) == 0) else 0;
    d["repeats"] = _repeats_na(rfd, wfd);
    d["eintr"] = _eintr_na();
    d["pollin"] = select.POLLIN;
    d["pollout"] = select.POLLOUT;
    close(i32(rfd));
    close(i32(wfd));
    return d;
}


"""Result lists for repeated and mixed-order inputs, flattened as positions
(0 for the read end, 1 for the write end) with -1 closing each list. `rfd`
is readable and `wfd` writable; `wfd` is never readable, so it drops out of
the read result. (`rfd` is kept out of the write list: whether a pipe's
read end polls writable differs by OS.)"""
def _repeats_py(rfd: int, wfd: int) -> list[int] {
    (r1, w1, _x1) = select.select([rfd, rfd], [wfd, wfd], [], 0.0);
    (r2, w2, _x2) = select.select([wfd, rfd, wfd, rfd], [wfd, wfd, wfd], [], 0.0);
    out: list[int] = [];
    for lst in [r1, w1, r2, w2] {
        for fd in lst {
            out.append(0 if fd == rfd else 1);
        }
        out.append(-1);
    }
    return out;
}


def _repeats_na(rfd: int, wfd: int) -> list[int] {
    (r1, w1, _x1) = select.select([rfd, rfd], [wfd, wfd], [], 0.0);
    (r2, w2, _x2) = select.select([wfd, rfd, wfd, rfd], [wfd, wfd, wfd], [], 0.0);
    out: list[int] = [];
    _flatten_na(out, r1, rfd);
    _flatten_na(out, w1, rfd);
    _flatten_na(out, r2, rfd);
    _flatten_na(out, w2, rfd);
    return out;
}


def _flatten_na(out: list[int], lst: list[int], rfd: int) {
    for fd in lst {
        if fd == rfd {
            out.append(0);
        } else {
            out.append(1);
        }
    }
    out.append(-1);
}


def _on_alarm_py(signum: int, frame: any) {}


"""A 0.5 s select on an empty pipe with a SIGALRM handler installed and the
alarm due after 50 ms: [raised, ready count, waited at least 0.35 s]."""
def _eintr_py -> list[int] {
    pysignal: any = __import__("signal");
    (rfd, wfd) = os.pipe();
    old = pysignal.signal(14, _on_alarm_py);
    raised = 0;
    ready = -1;
    t0 = time.monotonic();
    pysignal.setitimer(0, 0.05);
    try {
        (r, w, x) = select.select([rfd], [], [], 0.5);
        ready = len(r) + len(w) + len(x);
    } except Exception {
        raised = 1;
    }
    waited = 1 if time.monotonic() - t0 >= 0.35 else 0;
    pysignal.setitimer(0, 0.0);
    pysignal.signal(14, old);
    os.close(rfd);
    os.close(wfd);
    return [raised, ready, waited];
}


def _on_alarm_na(signum: int) {}


"""`struct itimerval` arming a one-shot timer `usec` microseconds out (all
zeros disarms). Both OSes lay it out as two 16-byte timevals (macOS pads
its 4-byte tv_usec), so one little-endian image serves both."""
def _itimer_na(usec: int) -> bytes {
    return b"\x00" * 16 + (0).to_bytes(8, "little") + usec.to_bytes(8, "little");
}


"""As `_eintr_py`, through libc: SIGALRM is 14 and ITIMER_REAL is 0 on both
Linux and macOS."""
def _eintr_na -> list[int] {
    (rfd, wfd) = _pipe_na();
    old: int = signal(i32(14), _on_alarm_na);
    raised: int = 0;
    ready: int = -1;
    t0: float = time.monotonic();
    setitimer(i32(0), _itimer_na(50000), 0);
    try {
        (r, w, x) = select.select([rfd], [], [], 0.5);
        ready = len(r) + len(w) + len(x);
    } except Exception {
        raised = 1;
    }
    waited: int = 1 if time.monotonic() - t0 >= 0.35 else 0;
    setitimer(i32(0), _itimer_na(0), 0);
    signal(i32(14), old);
    close(i32(rfd));
    close(i32(wfd));
    return [raised, ready, waited];
}
